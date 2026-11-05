"""Accesso agli snapshot di snapper per la Linea del Tempo."""

from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from pathlib import Path

from ..sistema import parametro_avvio, uscita

RADICI = {"root": Path("/.snapshots"), "home": Path("/home/.snapshots")}


def snapshot_disponibili() -> bool:
    return Path("/etc/snapper/configs/root").exists()


def _data_locale(testo: str) -> str:
    try:
        dt = datetime.strptime(testo[:19], "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc).astimezone()
        return dt.strftime("%d/%m/%Y %H:%M")
    except ValueError:
        return testo


def elenco_snapshot(config: str = "root") -> list[dict]:
    """Snapshot dal più recente al più vecchio (escluso lo stato attuale, numero 0)."""
    testo = uscita(["snapper", "--jsonout", "-c", config, "list"], timeout=30)
    risultato = []
    try:
        dati = json.loads(testo).get(config, [])
        for s in dati:
            if s.get("number", 0) == 0:
                continue
            risultato.append({"numero": s["number"], "dataUtc": s.get("date", ""), "data": _data_locale(s.get("date", "")),
                              "descrizione": s.get("description", "") or "", "tipo": s.get("type", ""),
                              "pulizia": s.get("cleanup", "")})
    except (json.JSONDecodeError, AttributeError):
        # Ripiego: lettura diretta di info.xml (richiede permessi di lettura)
        for info in RADICI[config].glob("*/info.xml"):
            try:
                xml = info.read_text()
            except OSError:
                continue
            numero = int(info.parent.name)
            data = re.search(r"<date>(.*?)</date>", xml)
            descr = re.search(r"<description>(.*?)</description>", xml)
            risultato.append({"numero": numero, "dataUtc": data.group(1) if data else "",
                              "data": _data_locale(data.group(1)) if data else "",
                              "descrizione": descr.group(1) if descr else "", "tipo": "", "pulizia": ""})
    risultato.sort(key=lambda s: s["numero"], reverse=True)
    return risultato


def configurazione_per(percorso: str) -> tuple[str, Path]:
    p = Path(percorso).resolve()
    if str(p).startswith("/home/") and Path("/etc/snapper/configs/home").exists():
        return "home", p.relative_to("/home")
    return "root", p.relative_to("/")


def versioni(percorso: str) -> list[dict]:
    """Versioni distinte di un file o cartella negli snapshot (dalla più recente)."""
    config, relativo = configurazione_per(percorso)
    viste = set()
    risultato = []
    attuale = Path(percorso)
    if attuale.exists():
        st = attuale.stat()
        viste.add((int(st.st_mtime), st.st_size))
        risultato.append({"numero": 0, "data": datetime.fromtimestamp(st.st_mtime).strftime("%d/%m/%Y %H:%M"),
                          "percorso": str(attuale), "dimensione": st.st_size, "attuale": True,
                          "cartella": attuale.is_dir(), "descrizione": ""})
    for s in elenco_snapshot(config):
        candidato = RADICI[config] / str(s["numero"]) / "snapshot" / relativo
        try:
            if not candidato.exists():
                continue
            st = candidato.stat()
        except OSError:
            continue
        chiave = (int(st.st_mtime), st.st_size)
        if chiave in viste:
            continue
        viste.add(chiave)
        risultato.append({"numero": s["numero"], "data": s["data"], "percorso": str(candidato),
                          "dimensione": st.st_size, "attuale": False, "cartella": candidato.is_dir(),
                          "descrizione": s["descrizione"], "config": config})
    return risultato


def avviato_da_snapshot() -> int | None:
    valore = parametro_avvio("snapshot")
    return int(valore) if valore and valore.isdigit() else None
