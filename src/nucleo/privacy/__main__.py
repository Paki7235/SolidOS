"""Servizio di registro privacy (demone utente leggero).

Ogni 15 secondi controlla, senza strumenti pesanti:
- microfono: flussi di registrazione attivi in PipeWire (pactl source-outputs);
- webcam: processi che hanno aperto /dev/video* (lettura di /proc/*/fd);
- rete: processi dell'utente con connessioni Internet attive (ss -tunp), una volta per app ogni 10 minuti;
- file: file aperti di recente dalle app (recently-used.xbel).
I trasferimenti di Condivisione Vicina vengono registrati direttamente dal servizio.
Limite dichiarato: non si monitora ogni accesso ai file (costerebbe troppa memoria e CPU).
"""

import json
import os
import re
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

from ..sistema import uscita
from .registro import Registro

INTERVALLO = 15
SILENZIO_RETE = 600


def nome_processo(pid: str) -> str:
    try:
        return Path(f"/proc/{pid}/comm").read_text().strip()
    except OSError:
        return "?"


def microfono() -> set[str]:
    try:
        flussi = json.loads(uscita(["pactl", "-f", "json", "list", "source-outputs"], timeout=5) or "[]")
    except json.JSONDecodeError:
        return set()
    return {f.get("properties", {}).get("application.name", "?") for f in flussi
            if not f.get("properties", {}).get("stream.monitor")}


def webcam() -> set[str]:
    attivi = set()
    mio_uid = os.getuid()
    for proc in Path("/proc").iterdir():
        if not proc.name.isdigit():
            continue
        try:
            if proc.stat().st_uid != mio_uid:
                continue
            for fd in (proc / "fd").iterdir():
                if os.readlink(fd).startswith("/dev/video"):
                    attivi.add(nome_processo(proc.name))
                    break
        except OSError:
            continue
    return attivi


def rete() -> set[str]:
    app = set()
    for riga in uscita(["ss", "-tunpH", "state", "established"], timeout=5).splitlines():
        remoto = riga.split()[4] if len(riga.split()) > 4 else ""
        if remoto.startswith(("127.", "[::1]", "[::ffff:127.")):
            continue
        for nome in re.findall(r'\("([^"]+)"', riga):
            app.add(nome)
    return app


def file_recenti(dopo: float) -> list[tuple[str, str]]:
    xbel = Path.home() / ".local/share/recently-used.xbel"
    if not xbel.exists() or xbel.stat().st_mtime < dopo:
        return []
    risultato = []
    try:
        for bookmark in ET.parse(xbel).getroot().iter("bookmark"):
            modificato = bookmark.get("modified", "")
            try:
                istante = time.mktime(time.strptime(modificato[:19], "%Y-%m-%dT%H:%M:%S")) - time.timezone
            except ValueError:
                continue
            if istante > dopo:
                app = next((a.get("name", "?") for a in bookmark.iter() if a.tag.endswith("application")), "?")
                risultato.append((app, bookmark.get("href", "").removeprefix("file://")))
    except ET.ParseError:
        pass
    return risultato


def main() -> int:
    reg = Registro()
    attivi = {"microfono": set(), "webcam": set()}
    ultima_rete: dict[str, float] = {}
    ultimo_controllo = time.time()
    giri = 0
    while True:
        adesso = time.time()
        for tipo, funzione in (("microfono", microfono), ("webcam", webcam)):
            correnti = funzione()
            for app in correnti - attivi[tipo]:
                reg.aggiungi(tipo, app, "ha iniziato a usare il dispositivo")
            attivi[tipo] = correnti
        for app in rete():
            if adesso - ultima_rete.get(app, 0) > SILENZIO_RETE:
                reg.aggiungi("rete", app, "connessione a Internet")
                ultima_rete[app] = adesso
        for app, file in file_recenti(ultimo_controllo):
            reg.aggiungi("file", app, file)
        ultimo_controllo = adesso
        giri += 1
        if giri % 240 == 0:
            reg.pulisci()
        time.sleep(INTERVALLO)


if __name__ == "__main__":
    sys.exit(main())
