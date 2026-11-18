"""Nuove versioni di SolidOS, pubblicate da ogni build su GitHub.

Ogni build pubblica, accanto alle ISO, un «pacchetto di aggiornamento» (tutti i file di
SolidOS: shell, app, impostazioni, script) e una scheda `versione.json` con il numero della
build, la somma di controllo e le novità. Un PC installato confronta quel numero con il suo
(`/usr/share/nucleo/versione`) e, se è più vecchio, scarica e installa i file nuovi dopo un
punto di ripristino (vedi /usr/libexec/nucleo/aggiorna-solidos).
"""

from __future__ import annotations

import json
import urllib.request
from pathlib import Path

from . import branding

FILE_VERSIONE = Path("/usr/share/nucleo/versione")


def url_base() -> str:
    return branding.get("OS_AGGIORNAMENTI_URL").rstrip("/")


def versione_installata() -> int:
    try:
        return int(FILE_VERSIONE.read_text().split()[0])
    except (OSError, ValueError, IndexError):
        return 0


def novita_installata() -> str:
    """Cosa è cambiato nella versione installata (scritto dalla build)."""
    try:
        return (FILE_VERSIONE.parent / "novita").read_text(encoding="utf-8").strip()[:600]
    except OSError:
        return ""


def scheda_remota(timeout: float = 20) -> dict | None:
    """La scheda dell'ultima versione pubblicata, o None senza rete/indirizzo."""
    base = url_base()
    if not base.startswith("https://"):
        return None
    richiesta = urllib.request.Request(f"{base}/versione.json",
                                       headers={"User-Agent": f"{branding.nome()}-Aggiornamenti"})
    try:
        with urllib.request.urlopen(richiesta, timeout=timeout) as r:
            dati = json.load(r)
    except (OSError, ValueError):
        return None
    if not isinstance(dati, dict) or not str(dati.get("versione", "")).isdigit():
        return None
    return dati


def controlla() -> dict:
    """{installata, disponibile, nuova, novita} per Impostazioni › Aggiornamenti."""
    installata = versione_installata()
    scheda = scheda_remota()
    if scheda is None:
        return {"installata": installata, "disponibile": None, "nuova": False, "novita": ""}
    disponibile = int(scheda["versione"])
    return {"installata": installata, "disponibile": disponibile, "nuova": disponibile > installata,
            "novita": str(scheda.get("novita", ""))[:600]}
