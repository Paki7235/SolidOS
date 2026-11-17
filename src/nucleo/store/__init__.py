"""Store «<OS_NAME> App»: catalogo unico sopra apt (Debian) e Flatpak (Flathub).

Preferenza predefinita: Flatpak per le app desktop (aggiornate e isolate),
apt per strumenti di sistema. Le installazioni Flatpak sono per l'utente e
non richiedono password; quelle apt passano dall'helper con snapshot.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

from ..i18n import T
from ..installa import prepara_flathub
from ..sistema import esegui, esiste, helper, uscita

VETRINA = Path("/usr/share/nucleo/store/vetrina.json")


def vetrina() -> list[dict]:
    try:
        return json.loads(VETRINA.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return []


def cerca(testo: str) -> list[dict]:
    testo = testo.strip()
    if len(testo) < 2:
        return []
    risultati: list[dict] = []
    if esiste("flatpak"):
        prepara_flathub()
        for riga in uscita(["flatpak", "search", "--columns=name,description,application,version", testo],
                           timeout=60).splitlines():
            parti = riga.split("\t")
            if len(parti) >= 3 and "." in parti[2]:
                risultati.append({"id": parti[2], "nome": parti[0], "descrizione": parti[1],
                                  "versione": parti[3] if len(parti) > 3 else "", "origine": "flatpak"})
    for riga in uscita(["apt-cache", "search", "--names-only", testo], timeout=30).splitlines()[:25]:
        nome, _, descr = riga.partition(" - ")
        if nome and not re.search(r"-(dev|dbg|doc|data|common|l10n)(-|$)|^lib", nome):
            risultati.append({"id": nome, "nome": nome, "descrizione": descr, "versione": "", "origine": "apt"})
    installati = set(installate_id())
    for r in risultati:
        r["installata"] = r["id"] in installati
    parole = testo.lower()
    risultati.sort(key=lambda r: (parole not in r["nome"].lower(), r["origine"] != "flatpak", r["nome"].lower()))
    return risultati[:50]


def installate_id() -> list[str]:
    ids = uscita(["flatpak", "list", "--app", "--columns=application"]).split() if esiste("flatpak") else []
    return ids + uscita(["dpkg-query", "-W", "-f=${Package}\n"]).split()


def installate() -> list[dict]:
    risultato = []
    if esiste("flatpak"):
        for riga in uscita(["flatpak", "list", "--app", "--columns=name,application,version,installation"]).splitlines():
            p = riga.split("\t")
            if len(p) >= 2:
                risultato.append({"id": p[1], "nome": p[0], "versione": p[2] if len(p) > 2 else "",
                                  "origine": "flatpak", "sistema": len(p) > 3 and p[3] == "system",
                                  "descrizione": "Flatpak", "installata": True})
    for f in sorted(Path.home().glob("Applicazioni/*.AppImage")) + sorted(Path.home().glob("Applicazioni/*.appimage")):
        risultato.append({"id": str(f), "nome": f.stem, "versione": "", "origine": "appimage",
                          "descrizione": "AppImage", "installata": True})
    return risultato


def installa(ident: str, origine: str) -> dict:
    if origine == "flatpak":
        prepara_flathub()
        r = esegui(["flatpak", "install", "--user", "-y", "--noninteractive", "flathub", ident], timeout=3600)
    elif origine == "apt":
        r = helper("apt-installa", ident, timeout=3600)
    else:
        return {"ok": False, "messaggio": T("Origine sconosciuta")}
    if r.returncode == 0:
        return {"ok": True, "messaggio": T("Installata: la trovi nel menu delle app")}
    return {"ok": False, "messaggio": spiega_errore(r.stderr or r.stdout or "")}


def spiega_errore(testo: str) -> str:
    """Gli errori di Flatpak e apt in parole semplici (il testo originale resta in fondo)."""
    t = testo.lower()
    if "no remote refs" in t or "nothing matches" in t or "no matches found" in t:
        return T("Questa app non è disponibile per questo computer (tipo di processore). Cerca un'alternativa.")
    if "could not resolve" in t or "unable to connect" in t or "network" in t or "timed out" in t:
        return T("Nessuna connessione a Internet: collegati alla rete e riprova.")
    if "no space" in t or "not enough" in t:
        return T("Spazio su disco esaurito: libera un po' di spazio e riprova.")
    if "unable to locate package" in t:
        return T("Pacchetto non trovato: prova ad aggiornare l'elenco dei programmi e riprova.")
    righe = [r for r in testo.strip().splitlines() if r.strip()]
    return T("Installazione non riuscita") + (": " + righe[-1][-200:] if righe else "")


def rimuovi(ident: str, origine: str, sistema: bool = False) -> dict:
    if origine == "flatpak":
        if sistema:
            r = helper("flatpak-sistema", "uninstall", ident)
        else:
            r = esegui(["flatpak", "uninstall", "--user", "-y", "--noninteractive", ident], timeout=600)
    elif origine == "apt":
        r = helper("apt-rimuovi", ident, timeout=1800)
    elif origine == "appimage":
        p = Path(ident)
        p.unlink(missing_ok=True)
        (Path.home() / f".local/share/applications/appimage-{p.stem}.desktop").unlink(missing_ok=True)
        return {"ok": True, "messaggio": ""}
    else:
        return {"ok": False, "messaggio": T("Origine sconosciuta")}
    return {"ok": r.returncode == 0, "messaggio": "" if r.returncode == 0 else r.stderr.strip()[-300:]}


def aggiornamenti_flatpak() -> dict:
    r = esegui(["flatpak", "update", "--user", "-y", "--noninteractive"], timeout=3600)
    return {"ok": r.returncode == 0, "messaggio": ""}


def trova_per_nome(nome: str) -> dict | None:
    """Usato dalla Barra Unica: «installa vlc» → risultato migliore."""
    risultati = cerca(nome)
    esatti = [r for r in risultati if r["nome"].lower() == nome.lower()]
    return (esatti or risultati or [None])[0]
