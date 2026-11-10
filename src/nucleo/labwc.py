"""Modifica della configurazione utente di labwc (~/.config/labwc/rc.xml).

labwc usa il file dell'utente al posto di quello di sistema: alla prima
modifica si copia quello di sistema e poi si cambiano solo i nodi necessari.
"""

from __future__ import annotations

import os
import shutil
import xml.etree.ElementTree as ET
from pathlib import Path

from .sistema import avvia

SISTEMA = Path("/etc/xdg/labwc/rc.xml")


def file_utente() -> Path:
    base = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "labwc"
    base.mkdir(parents=True, exist_ok=True)
    rc = base / "rc.xml"
    if not rc.exists() and SISTEMA.exists():
        shutil.copy(SISTEMA, rc)
    return rc


def _albero() -> ET.ElementTree:
    rc = file_utente()
    if rc.exists():
        return ET.parse(rc)
    return ET.ElementTree(ET.Element("labwc_config"))


def _nodo(radice: ET.Element, percorso: str, attributi: dict | None = None) -> ET.Element:
    nodo = radice
    parti = percorso.split("/")
    for i, parte in enumerate(parti):
        figlio = None
        for c in nodo.findall(parte):
            if i == len(parti) - 1 and attributi:
                if all(c.get(k) == v for k, v in attributi.items()):
                    figlio = c
                    break
            else:
                figlio = c
                break
        if figlio is None:
            figlio = ET.SubElement(nodo, parte, attributi if i == len(parti) - 1 and attributi else {})
        nodo = figlio
    return nodo


def leggi(percorso: str, attributi: dict | None = None, predefinito: str = "") -> str:
    """Legge «a/b/c»; gli attributi si riferiscono al penultimo nodo (es. <device category="touchpad">),
    come in imposta()."""
    radice = _albero().getroot()
    parti = percorso.split("/")
    nodi = [radice]
    for k, parte in enumerate(parti[:-1]):
        successivi = []
        for n in nodi:
            for c in n.findall(parte):
                if k == len(parti) - 2 and attributi and not all(c.get(a) == v for a, v in attributi.items()):
                    continue
                successivi.append(c)
        nodi = successivi
    for n in nodi:
        foglia = n.find(parti[-1])
        if foglia is not None and (foglia.text or "").strip():
            return foglia.text.strip()
    return predefinito


def imposta(valori: dict[str, str], attributi_per: dict[str, dict] | None = None) -> None:
    """valori: {"libinput/device/tap": "yes", ...}; attributi_per: attributi del nodo finale."""
    albero = _albero()
    radice = albero.getroot()
    for percorso, valore in valori.items():
        attr = (attributi_per or {}).get(percorso)
        if attr and "/" in percorso:
            # l'attributo si riferisce al penultimo nodo (es. <device category="touchpad">)
            genitore_percorso, foglia = percorso.rsplit("/", 1)
            genitore = _nodo(radice, genitore_percorso, attr)
            nodo = genitore.find(foglia)
            if nodo is None:
                nodo = ET.SubElement(genitore, foglia)
        else:
            nodo = _nodo(radice, percorso)
        nodo.text = str(valore)
    ET.indent(albero)
    albero.write(file_utente(), encoding="unicode", xml_declaration=True)
    riconfigura()


def riconfigura() -> None:
    """Ricarica tema e scorciatoie. «labwc --reconfigure» funziona solo dentro la sessione
    (serve LABWC_PID); altrimenti si manda a labwc il segnale HUP, che fa la stessa cosa."""
    if os.environ.get("LABWC_PID"):
        avvia(["labwc", "--reconfigure"])
        return
    import signal
    import subprocess

    try:
        pid = subprocess.run(["pgrep", "-u", str(os.getuid()), "-x", "labwc"], capture_output=True, text=True,
                             timeout=3).stdout.split()
        for p in pid:
            os.kill(int(p), signal.SIGHUP)
    except (OSError, ValueError, subprocess.TimeoutExpired):
        pass


def imposta_ambiente(variabili: dict[str, str]) -> None:
    """Scrive ~/.config/labwc/environment (letto da labwc all'avvio e alla riconfigurazione)."""
    file = file_utente().parent / "environment"
    righe = {}
    if file.exists():
        for r in file.read_text().splitlines():
            if "=" in r and not r.startswith("#"):
                k, v = r.split("=", 1)
                righe[k] = v
    righe.update({k: v for k, v in variabili.items() if v is not None})
    file.write_text("".join(f"{k}={v}\n" for k, v in righe.items() if v != ""))
    riconfigura()
