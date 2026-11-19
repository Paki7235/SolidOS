"""Libreria dell'app Foto, comune a PC e telefono: le foto di Immagini, DCIM e Scaricati
più quelle degli account collegati (nucleo/fotoaccount.py), con giorno, album e preferite."""

from __future__ import annotations

import time
import urllib.parse
from pathlib import Path

from .i18n import T
from .sistema import cartella_utente, config_utente, leggi_json, scrivi_json

IMMAGINI = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".heic", ".heif", ".avif", ".tif", ".tiff"}


def _uri(p: Path) -> str:
    return "file://" + urllib.parse.quote(str(p))


def foto() -> list:
    radici = {cartella_utente("PICTURES", "Immagini"), Path.home() / "DCIM", cartella_utente("DOWNLOAD", "Scaricati")}
    trovate = []
    for r in radici:
        if not r.is_dir():
            continue
        for f in r.rglob("*"):
            if f.suffix.lower() in IMMAGINI and not any(x.startswith(".") for x in f.parts):
                try:
                    trovate.append((f.stat().st_mtime, f))
                except OSError:
                    pass
    scaricati = cartella_utente("DOWNLOAD", "Scaricati")
    elenco = []
    for t, f in trovate[:2000]:
        album = "scaricati" if scaricati in f.parents else ("schermate" if "screenshot" in f.name.lower() or "schermata" in f.name.lower() else "fotocamera")
        elenco.append({"percorso": str(f), "uri": _uri(f), "nome": f.name, "quando": t, "fonte": "computer", "album": album})
    # Le foto degli account collegati (Nextcloud…), con il simbolino del servizio
    from . import fotoaccount

    elenco += [dict(x, album="account") for x in fotoaccount.foto()]
    elenco.sort(key=lambda x: -x["quando"])
    preferite = set(leggi_json(config_utente("foto-preferite.json"), []))
    for x in elenco:
        x["preferita"] = x["percorso"] in preferite
    oggi = time.strftime("%Y-%m-%d")
    ieri = time.strftime("%Y-%m-%d", time.localtime(time.time() - 86400))
    mesi = ["gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno", "luglio", "agosto", "settembre",
            "ottobre", "novembre", "dicembre"]
    for x in elenco:
        lt = time.localtime(x["quando"])
        g = time.strftime("%Y-%m-%d", lt)
        x["giorno"] = T("Oggi") if g == oggi else (T("Ieri") if g == ieri else f"{lt.tm_mday} {T(mesi[lt.tm_mon - 1])}" + (f" {lt.tm_year}" if lt.tm_year != time.localtime().tm_year else ""))
        x["data"] = time.strftime("%d/%m/%Y %H:%M", lt)
    return elenco


def foto_preferita(percorso: str, si: bool) -> None:
    f = config_utente("foto-preferite.json")
    elenco = [p for p in leggi_json(f, []) if p != percorso]
    if si:
        elenco.append(percorso)
    scrivi_json(f, elenco[-5000:])
