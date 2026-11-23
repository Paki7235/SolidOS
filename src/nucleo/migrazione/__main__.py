"""Migrazione dal computer di prima: documenti, foto, sfondo, preferiti del browser e reti Wi-Fi.

Le password Wi-Fi nell'altro sistema sono cifrate (DPAPI): il metodo affidabile è eseguire lì
lo strumento «esporta-wifi.bat» (copiato sulla chiavetta) che salva le reti
in file XML; la migrazione li cerca su tutti i dischi collegati.
"""

import html
import json
import shutil
import sqlite3
import sys
import tempfile
import time
import xml.etree.ElementTree as ET
from pathlib import Path

from .. import windows
from ..copia import copia
from ..i18n import T
from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app
from ..sistema import cartella_utente, config_utente, esegui

BROWSER = {
    "Edge": "AppData/Local/Microsoft/Edge/User Data/Default/Bookmarks",
    "Chrome": "AppData/Local/Google/Chrome/User Data/Default/Bookmarks",
}


def _preferiti_chromium(file: Path) -> list[tuple[str, str]]:
    try:
        dati = json.loads(file.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return []
    risultato = []

    def visita(nodo):
        if nodo.get("type") == "url":
            risultato.append((nodo.get("name", ""), nodo.get("url", "")))
        for figlio in nodo.get("children", []):
            visita(figlio)

    for radice in dati.get("roots", {}).values():
        if isinstance(radice, dict):
            visita(radice)
    return risultato


def _preferiti_firefox(utente: Path) -> list[tuple[str, str]]:
    risultato = []
    for places in utente.glob("AppData/Roaming/Mozilla/Firefox/Profiles/*/places.sqlite"):
        with tempfile.NamedTemporaryFile(suffix=".sqlite") as copia_db:
            shutil.copy(places, copia_db.name)
            try:
                con = sqlite3.connect(copia_db.name)
                for titolo, url in con.execute(
                        "SELECT b.title, p.url FROM moz_bookmarks b JOIN moz_places p ON b.fk = p.id "
                        "WHERE b.type = 1 AND p.url LIKE 'http%'"):
                    risultato.append((titolo or url, url))
                con.close()
            except sqlite3.Error:
                pass
    return risultato


# Cartelle tipiche di un utente sui vari sistemi operativi (inglese e italiano) → cartella di qui
CARTELLE_NOTE = [
    (("Documents", "Documenti", "My Documents"), "Documenti", "DOCUMENTS"),
    (("Pictures", "Immagini", "Foto", "Photos", "My Pictures"), "Immagini", "PICTURES"),
    (("Music", "Musica", "My Music"), "Musica", "MUSIC"),
    (("Videos", "Movies", "Video", "Filmati", "My Videos"), "Video", "VIDEOS"),
    (("Desktop", "Scrivania"), "Scrivania", "DESKTOP"),
    (("Downloads", "Scaricati", "Download"), "Scaricati", "DOWNLOAD"),
]


def _dimensione_mb(p: Path, limite_s: float = 6.0) -> int:
    totale, fine = 0, time.monotonic() + limite_s
    for radice, _cartelle, file in __import__("os").walk(p):
        for f in file:
            try:
                totale += (Path(radice) / f).stat().st_size
            except OSError:
                pass
        if time.monotonic() > fine:
            break
    return round(totale / 1048576)


def _dischi_esterni() -> list[dict]:
    """Chiavette, dischi esterni e partizioni montate (esclusa quella di sistema)."""
    risultato = []
    for base in (Path("/media") / Path.home().name, Path("/run/media") / Path.home().name, Path("/media")):
        if not base.is_dir():
            continue
        for punto in sorted(base.iterdir()):
            if punto.is_dir() and not any(r["percorso"] == str(punto) for r in risultato) and punto.name != Path.home().name:
                risultato.append({"nome": punto.name, "percorso": str(punto)})
    return risultato


def _utenti_in(cartella: Path) -> list[dict]:
    """Utenti dentro un disco: Users/, Utenti/, home/."""
    utenti = []
    for nome in ("Users", "Utenti", "home"):
        base = cartella / nome
        if base.is_dir():
            for u in sorted(base.iterdir()):
                if u.is_dir() and u.name not in ("Public", "Default", "Default User", "All Users", "Shared", "Guest", "lost+found") \
                        and not u.name.startswith("."):
                    utenti.append({"nome": u.name, "percorso": str(u)})
    return utenti


class BackendMigrazione(Backend):
    # ── Sorgenti (passo 1) ────────────────────────────────────────────────
    def sorgenti(self) -> dict:
        return {"windows": self.partizioni(), "dischi": _dischi_esterni()}

    def utentiIn(self, percorso: str) -> list:
        return _utenti_in(Path(percorso))

    def analizza(self, percorso: str) -> list:
        """Cosa si può portare da una cartella qualsiasi (utente di un qualsiasi sistema operativo,
        oppure una cartella di backup): le cartelle note, oppure tutto il contenuto."""
        base = Path(percorso)
        utenti = _utenti_in(base)
        if len(utenti) == 1:
            base = Path(utenti[0]["percorso"])
        voci = []
        for nomi, italiano, xdg in CARTELLE_NOTE:
            for n in nomi:
                p = base / n
                if p.is_dir():
                    voci.append({"id": italiano, "nome": italiano, "xdg": xdg, "tipo": "cartella", "percorso": str(p),
                                 "dimensione": _dimensione_mb(p)})
                    break
        # dal sistema di prima anche sfondo e preferiti del browser
        if (base / "AppData").is_dir():
            voci += [v for v in self.elementi(str(base)) if v["tipo"] != "cartella"]
        if not voci and base.is_dir():
            voci.append({"id": "tutto", "nome": T("Tutto il contenuto di «{n}»", n=base.name), "xdg": "DOCUMENTS",
                         "tipo": "cartella", "percorso": str(base), "dimensione": _dimensione_mb(base), "sottocartella": base.name})
        return voci

    def apriCondivisione(self) -> None:
        from .. import branding
        from ..sistema import avvia

        avvia([branding.comando("condividi")])

    def apriRete(self) -> None:
        from .. import branding
        from ..sistema import avvia

        avvia([branding.comando("file"), "network:///"])

    def apriCartella(self, xdg: str) -> None:
        from .. import branding
        from ..sistema import avvia

        avvia([branding.comando("file"), str(cartella_utente(xdg or "DOCUMENTS", "Documenti"))])

    def partizioni(self) -> list:
        return [p for p in windows.partizioni() if not p["bitlocker"]]

    def apri(self, percorso: str) -> dict:
        r = windows.monta(percorso, sola_lettura=True)
        if r["ok"]:
            r["windows"] = windows.e_windows(r["punto"])
            r["utenti"] = windows.utenti(r["punto"])
        return r

    def elementi(self, percorso_utente: str) -> list:
        utente = Path(percorso_utente)
        voci = [dict(c, tipo="cartella") for c in windows.cartelle_utente(percorso_utente)]
        sfondo = utente / "AppData/Roaming/Microsoft/Windows/Themes/TranscodedWallpaper"
        if sfondo.exists():
            voci.append({"id": "sfondo", "nome": T("Sfondo del desktop"), "tipo": "sfondo", "percorso": str(sfondo), "dimensione": 0})
        n_pref = sum(len(_preferiti_chromium(utente / p)) for p in BROWSER.values()) + len(_preferiti_firefox(utente))
        if n_pref:
            voci.append({"id": "preferiti", "nome": T("Preferiti del browser ({n})", n=n_pref), "tipo": "preferiti",
                         "percorso": str(utente), "dimensione": 0})
        reti = self._reti_esportate()
        if reti:
            voci.append({"id": "wifi", "nome": T("Reti Wi-Fi esportate ({n})", n=len(reti)), "tipo": "wifi",
                         "percorso": "", "dimensione": 0})
        return voci

    def _reti_esportate(self) -> list[Path]:
        trovate = []
        for base in (Path("/media"), Path("/run/media")):
            if base.is_dir():
                trovate += list(base.glob("*/*/Reti Wi-Fi esportate/*.xml"))
                trovate += list(base.glob("*/*/Users/*/Desktop/Reti Wi-Fi esportate/*.xml"))
                trovate += list(base.glob("*/*/Users/*/OneDrive/Desktop/Reti Wi-Fi esportate/*.xml"))
        return trovate

    def importa(self, voci: list) -> dict:
        riepilogo = []
        cartelle = [v for v in voci if v["tipo"] == "cartella"]
        totale_copiati = 0
        for c in cartelle:
            destinazione = cartella_utente(c["xdg"], c["nome"])
            if c.get("sottocartella"):
                destinazione = destinazione / c["sottocartella"]
                destinazione.mkdir(parents=True, exist_ok=True)
            r = copia([str(Path(c["percorso"]) / f.name) for f in Path(c["percorso"]).iterdir()
                       if not f.name.lower().startswith(("desktop.ini", "my ", "thumbs.db"))],
                      str(destinazione), lambda f, t, n: self.emetti("avanzamento", {"fatto": f, "totale": t, "nome": n}))
            totale_copiati += r["copiati"]
        if cartelle:
            riepilogo.append(T("{n} file copiati", n=totale_copiati))
        for v in voci:
            if v["tipo"] == "sfondo":
                dest = Path.home() / ".local/share/backgrounds" / "sfondo-windows.jpg"
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy(v["percorso"], dest)
                from ..sistema import imposta_sfondo

                imposta_sfondo(str(dest))
                riepilogo.append(T("Sfondo importato"))
            elif v["tipo"] == "preferiti":
                riepilogo.append(self._importa_preferiti(Path(v["percorso"])))
            elif v["tipo"] == "wifi":
                riepilogo.append(self._importa_wifi())
        return {"ok": True, "riepilogo": riepilogo}

    def _importa_preferiti(self, utente: Path) -> str:
        voci = []
        for nome, relativo in BROWSER.items():
            voci += [(nome, t, u) for t, u in _preferiti_chromium(utente / relativo)]
        voci += [("Firefox", t, u) for t, u in _preferiti_firefox(utente)]
        if not voci:
            return T("Nessun preferito trovato")
        righe = ["<!DOCTYPE NETSCAPE-Bookmark-file-1>", '<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">',
                 "<TITLE>Preferiti</TITLE>", "<H1>Preferiti</H1>", "<DL><p>",
                 f"<DT><H3>{html.escape(T('Importati dal computer di prima'))}</H3>", "<DL><p>"]
        adesso = int(time.time())
        for origine, titolo, url in voci:
            righe.append(f'<DT><A HREF="{html.escape(url)}" ADD_DATE="{adesso}">{html.escape(titolo)} ({origine})</A>')
        righe += ["</DL><p>", "</DL><p>"]
        file = cartella_utente("DOCUMENTS", "Documenti") / T("Preferiti importati.html")
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text("\n".join(righe), encoding="utf-8")
        return T("{n} preferiti salvati in «{f}»: in Firefox usa Segnalibri → Importa da HTML", n=len(voci), f=file.name)

    def _importa_wifi(self) -> str:
        importate = 0
        for xml in self._reti_esportate():
            try:
                radice = ET.parse(xml).getroot()
            except ET.ParseError:
                continue
            ns = {"w": radice.tag.split("}")[0].strip("{")} if radice.tag.startswith("{") else {}
            trova = (lambda p: radice.find(".//w:" + p, ns)) if ns else (lambda p: radice.find(".//" + p))
            ssid, chiave = trova("name"), trova("keyMaterial")
            if ssid is None:
                continue
            cmd = ["nmcli", "connection", "add", "type", "wifi", "con-name", ssid.text, "ssid", ssid.text]
            if chiave is not None and chiave.text:
                cmd += ["wifi-sec.key-mgmt", "wpa-psk", "wifi-sec.psk", chiave.text]
            if esegui(cmd).returncode == 0:
                importate += 1
        return T("{n} reti Wi-Fi importate", n=importate)


def main() -> int:
    return esegui_app("migrazione", "Migrazione/Main.qml", lambda app: {"ponte": crea_ponte(BackendMigrazione())})


if __name__ == "__main__":
    sys.exit(main())
