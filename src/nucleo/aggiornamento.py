"""Nuove versioni di SolidOS, pubblicate da ogni build su GitHub.

Ogni build pubblica, accanto alle ISO, un «pacchetto di aggiornamento» (tutti i file di
SolidOS: shell, app, impostazioni, script) e una scheda `versione.json` con il numero della
build, la somma di controllo e le novità. Un PC installato confronta quel numero con il suo
(`/usr/share/nucleo/versione`) e, se è più vecchio, scarica e installa i file nuovi dopo un
punto di ripristino (vedi /usr/libexec/nucleo/aggiorna-solidos).

La scheda è FIRMATA (Ed25519) con la chiave segreta di SolidOS, che sta solo nei segreti
delle build su GitHub: `versione.json.firma` accanto alla scheda. Il PC la verifica con la
chiave pubblica installata (`/usr/share/nucleo/chiave-aggiornamenti.pem`); senza firma
valida la scheda si ignora, quindi nessuno può spacciarsi per un aggiornamento di SolidOS.
La somma di controllo dentro la scheda firmata garantisce poi il pacchetto scaricato.
"""

from __future__ import annotations

import json
import subprocess
import tempfile
import urllib.request
from pathlib import Path

from . import branding

FILE_VERSIONE = Path("/usr/share/nucleo/versione")
CHIAVE = Path("/usr/share/nucleo/chiave-aggiornamenti.pem")


def firma_valida(dati: bytes, firma: bytes, chiave: Path = CHIAVE) -> bool:
    """True se «firma» è la firma Ed25519 di «dati» fatta con la chiave di SolidOS."""
    if not chiave.is_file() or not firma:
        return False
    with tempfile.TemporaryDirectory(prefix="firma-") as c:
        d, f = Path(c) / "dati", Path(c) / "firma"
        d.write_bytes(dati)
        f.write_bytes(firma)
        try:
            r = subprocess.run(["openssl", "pkeyutl", "-verify", "-pubin", "-inkey", str(chiave),
                                "-rawin", "-in", str(d), "-sigfile", str(f)],
                               capture_output=True, timeout=20)
        except (OSError, subprocess.TimeoutExpired):
            return False
    return r.returncode == 0


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


# Perché l'ultima scheda non è stata accettata (per i messaggi all'utente)
ultimo_errore = ""


def scheda_remota(timeout: float = 20) -> dict | None:
    """La scheda dell'ultima versione pubblicata, solo se la firma è valida; altrimenti None
    (senza rete, senza indirizzo o con una firma che non torna: vedi «ultimo_errore»)."""
    global ultimo_errore
    ultimo_errore = ""
    base = url_base()
    if not base.startswith("https://"):
        ultimo_errore = "indirizzo degli aggiornamenti mancante"
        return None

    def scarica(nome: str) -> bytes:
        richiesta = urllib.request.Request(f"{base}/{nome}",
                                           headers={"User-Agent": f"{branding.nome()}-Aggiornamenti"})
        with urllib.request.urlopen(richiesta, timeout=timeout) as r:
            return r.read(1 << 20)

    try:
        grezza, firma = scarica("versione.json"), scarica("versione.json.firma")
    except OSError:
        ultimo_errore = "server degli aggiornamenti non raggiungibile"
        return None
    if not firma_valida(grezza, firma):
        ultimo_errore = "la firma dell'aggiornamento non è valida: non viene installato"
        return None
    try:
        dati = json.loads(grezza)
    except ValueError:
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
