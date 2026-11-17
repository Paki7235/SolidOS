"""«Installa con <OS_NAME>»: installa programmi da .deb, .rpm, .AppImage, Flatpak, .exe e .msi.

Ogni formato ha un backend; le app vengono isolate quando possibile:
- .deb       → apt (pacchetto di sistema; snapshot automatico prima)
- .rpm       → distrobox (contenitore Fedora), lanciatore esportato nel menu
- .AppImage  → ~/Applicazioni + voce di menu
- Flatpak    → flatpak --user (sandbox)
- .exe/.msi  → Wine, un prefisso separato per ogni programma
- .dmg/.pkg  → non supportati (app macOS)
"""

from __future__ import annotations

import configparser
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from .. import branding
from ..formati import tipo_installabile
from ..i18n import T
from ..sistema import esegui, esiste, helper, uscita

CARTELLA_APPIMAGE = Path.home() / "Applicazioni"
PREFISSI_WINE = Path.home() / ".local/share/wineprefixes"
APPS = Path.home() / ".local/share/applications"
FLATHUB = "https://dl.flathub.org/repo/flathub.flatpakrepo"


def _processore_arm() -> bool:
    import platform

    return platform.machine().lower() in ("aarch64", "arm64", "armv7l", "armv8l")


def analizza(percorso: str) -> dict:
    """Informazioni da mostrare prima dell'installazione."""
    percorso = percorso.removeprefix("file://")
    tipo = tipo_installabile(percorso)
    nome = Path(percorso).stem
    info = {"file": percorso, "tipo": tipo, "nome": nome, "versione": "", "descrizione": "",
            "isolamento": "", "supportato": tipo not in ("", "mac"), "dimensione": 0}
    try:
        info["dimensione"] = round(Path(percorso).stat().st_size / 1048576, 1)
    except OSError:
        pass
    if tipo == "deb":
        campi = uscita(["dpkg-deb", "-f", percorso, "Package", "Version", "Description"])
        for riga in campi.splitlines():
            if riga.startswith("Package:"):
                info["nome"] = riga.split(":", 1)[1].strip()
            elif riga.startswith("Version:"):
                info["versione"] = riga.split(":", 1)[1].strip()
            elif riga.startswith("Description:"):
                info["descrizione"] = riga.split(":", 1)[1].strip()
        info["isolamento"] = T("Pacchetto di sistema: prima dell'installazione viene creato un punto di ripristino.")
    elif tipo == "rpm":
        info["isolamento"] = T("Installato in un contenitore Fedora separato dal sistema.")
    elif tipo == "appimage":
        info["isolamento"] = T("Resta un singolo file nella cartella Applicazioni: per rimuoverlo basta cancellarlo.")
    elif tipo in ("flatpak", "flatpakref"):
        info["isolamento"] = T("Gira in una sandbox con accesso limitato ai tuoi file.")
    elif tipo in ("exe", "msi") and _processore_arm():
        info["supportato"] = False
        info["descrizione"] = T("Questo computer ha un processore ARM (come i Mac con processore Apple e le loro "
                                "macchine virtuali): i programmi per Windows sono fatti per processori Intel o AMD e "
                                "qui non possono funzionare. Cerca la stessa app nello Store: spesso c'è la versione per Linux.")
    elif tipo in ("exe", "msi"):
        info["isolamento"] = T("Programma Windows: gira con Wine in un ambiente separato. Non tutti i programmi funzionano.")
    elif tipo == "mac":
        info["descrizione"] = T("Le app per macOS non possono funzionare su {s}. Cerca un'alternativa nello store.",
                                s=branding.nome())
    else:
        info["descrizione"] = T("Formato non riconosciuto come programma installabile.")
    return info


def installa(percorso: str, avanzamento=lambda testo: None) -> dict:
    percorso = percorso.removeprefix("file://")
    tipo = tipo_installabile(percorso)
    funzioni = {"deb": _deb, "rpm": _rpm, "appimage": _appimage, "flatpak": _flatpak,
                "flatpakref": _flatpak, "exe": _wine, "msi": _wine}
    if tipo not in funzioni:
        return {"ok": False, "messaggio": T("Formato non supportato")}
    return funzioni[tipo](percorso, avanzamento)


def _deb(percorso, avanzamento):
    avanzamento(T("Installazione del pacchetto…"))
    r = helper("installa-deb", percorso, timeout=1800)
    return {"ok": r.returncode == 0, "messaggio": "" if r.returncode == 0 else r.stderr.strip()[-400:]}


def _rpm(percorso, avanzamento):
    if not esiste("distrobox"):
        return {"ok": False, "messaggio": T("distrobox non è installato")}
    contenitore = "app-fedora"
    if contenitore not in uscita(["distrobox", "list", "--no-color"], timeout=60):
        avanzamento(T("Preparazione del contenitore Fedora (solo la prima volta, qualche minuto)…"))
        r = esegui(["distrobox", "create", "--yes", "--name", contenitore,
                    "--image", "registry.fedoraproject.org/fedora:latest"], timeout=1800)
        if r.returncode != 0:
            return {"ok": False, "messaggio": r.stderr.strip()[-400:]}
    avanzamento(T("Installazione nel contenitore…"))
    r = esegui(["distrobox", "enter", contenitore, "--", "sudo", "dnf", "install", "-y", percorso], timeout=1800)
    if r.returncode != 0:
        return {"ok": False, "messaggio": r.stderr.strip()[-400:]}
    voci = uscita(["rpm", "-qpl", percorso]).splitlines() if esiste("rpm") else []
    desktop = [Path(v).stem for v in voci if v.startswith("/usr/share/applications/") and v.endswith(".desktop")]
    for app in desktop:
        esegui(["distrobox", "enter", contenitore, "--", "distrobox-export", "--app", app], timeout=120)
    return {"ok": True, "messaggio": T("Installato. Lo trovi nel menu delle app.")}


def _appimage(percorso, avanzamento):
    CARTELLA_APPIMAGE.mkdir(parents=True, exist_ok=True)
    destinazione = CARTELLA_APPIMAGE / Path(percorso).name
    if Path(percorso).resolve() != destinazione.resolve():
        shutil.copy2(percorso, destinazione)
    destinazione.chmod(0o755)
    avanzamento(T("Creazione della voce di menu…"))
    nome, icona = destinazione.stem.split("-")[0], "application-x-executable"
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run([str(destinazione), "--appimage-extract", "*.desktop"], cwd=tmp,
                       capture_output=True, timeout=60, check=False)
        subprocess.run([str(destinazione), "--appimage-extract", ".DirIcon"], cwd=tmp,
                       capture_output=True, timeout=60, check=False)
        radice = Path(tmp) / "squashfs-root"
        for d in radice.glob("*.desktop"):
            c = configparser.RawConfigParser(strict=False, interpolation=None)
            try:
                c.read(d, encoding="utf-8")
                nome = c["Desktop Entry"].get("Name", nome)
            except (configparser.Error, KeyError):
                pass
            break
        diricon = radice / ".DirIcon"
        if diricon.exists():
            icone = Path.home() / ".local/share/icons"
            icone.mkdir(parents=True, exist_ok=True)
            file_icona = icone / f"appimage-{destinazione.stem}.png"
            shutil.copy(diricon.resolve() if diricon.is_symlink() and diricon.resolve().exists() else diricon, file_icona)
            icona = str(file_icona)
    APPS.mkdir(parents=True, exist_ok=True)
    (APPS / f"appimage-{destinazione.stem}.desktop").write_text(
        "[Desktop Entry]\nType=Application\n"
        f"Name={nome}\nExec=\"{destinazione}\" %U\nIcon={icona}\nTerminal=false\n"
        "Categories=Utility;\nX-AppImage=true\n", encoding="utf-8")
    return {"ok": True, "messaggio": T("Installato in {c}", c=str(CARTELLA_APPIMAGE))}


def prepara_flathub(catalogo: bool = True) -> None:
    """Flathub per l'utente e il suo catalogo (appstream). Senza catalogo «flatpak search»
    non trova niente: si scarica la prima volta e si aggiorna se ha più di un giorno."""
    esegui(["flatpak", "remote-add", "--user", "--if-not-exists", "flathub", FLATHUB], timeout=120)
    if not catalogo:
        return
    import time

    base = Path.home() / ".local/share/flatpak/appstream/flathub"
    file = sorted(base.glob("*/active/appstream.xml*")) if base.is_dir() else []
    if not file or time.time() - file[0].stat().st_mtime > 86400:
        esegui(["flatpak", "update", "--user", "--appstream", "flathub"], timeout=600)


def _flatpak(percorso, avanzamento):
    prepara_flathub()
    avanzamento(T("Download e installazione (può richiedere qualche minuto)…"))
    if percorso.endswith(".flatpakref"):
        cmd = ["flatpak", "install", "--user", "-y", "--noninteractive", "--from", percorso]
    else:
        cmd = ["flatpak", "install", "--user", "-y", "--noninteractive", "--bundle", percorso]
    r = esegui(cmd, timeout=3600)
    return {"ok": r.returncode == 0, "messaggio": "" if r.returncode == 0 else r.stderr.strip()[-400:]}


def nome_prefisso(percorso: str) -> str:
    base = re.sub(r"(?i)(setup|install(er)?|x64|x86|win(32|64)?|[-_. ]?v?\d+(\.\d+)*)", "", Path(percorso).stem)
    return re.sub(r"[^A-Za-z0-9]+", "-", base).strip("-").lower() or "programma"


def _wine(percorso, avanzamento):
    if _processore_arm():
        return {"ok": False, "messaggio": T("I programmi per Windows non funzionano sui computer con processore ARM: "
                                            "cerca la stessa app nello Store.")}
    if not esiste("wine"):
        return {"ok": False, "messaggio": T("Per i programmi Windows serve Wine: installalo dallo Store o con «sudo apt install wine».")}
    prefisso = PREFISSI_WINE / nome_prefisso(percorso)
    prefisso.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, WINEPREFIX=str(prefisso), WINEDEBUG="-all", WINEDLLOVERRIDES="winemenubuilder.exe=e")
    if not (prefisso / "system.reg").exists():
        avanzamento(T("Preparazione dell'ambiente Windows (solo la prima volta)…"))
        subprocess.run(["wineboot", "--init"], env=env, capture_output=True, timeout=600, check=False)
    avanzamento(T("Avvio del programma di installazione: segui le istruzioni nella sua finestra."))
    cmd = ["wine", "msiexec", "/i", percorso] if percorso.lower().endswith(".msi") else ["wine", percorso]
    r = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=7200, check=False)
    ok = r.returncode == 0
    return {"ok": ok, "messaggio": T("Installazione terminata. Il programma compare nel menu delle app (sezione Wine).")
            if ok else T("Il programma di installazione si è chiuso con un errore.")}


def esegui_senza_installare(percorso: str) -> None:
    prefisso = PREFISSI_WINE / "portabili"
    prefisso.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, WINEPREFIX=str(prefisso), WINEDEBUG="-all")
    subprocess.Popen(["wine", percorso], env=env, start_new_session=True)
