"""Migrazione da Windows: documenti, foto, sfondo, preferiti del browser e reti Wi-Fi.

Le password Wi-Fi in Windows sono cifrate (DPAPI): il metodo affidabile è eseguire su
Windows lo strumento «esporta-wifi.bat» (copiato sulla chiavetta) che salva le reti
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


class BackendMigrazione(Backend):
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
                 f"<DT><H3>{html.escape(T('Importati da Windows'))}</H3>", "<DL><p>"]
        adesso = int(time.time())
        for origine, titolo, url in voci:
            righe.append(f'<DT><A HREF="{html.escape(url)}" ADD_DATE="{adesso}">{html.escape(titolo)} ({origine})</A>')
        righe += ["</DL><p>", "</DL><p>"]
        file = cartella_utente("DOCUMENTS", "Documenti") / T("Preferiti importati da Windows.html")
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
