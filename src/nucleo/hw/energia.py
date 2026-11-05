"""Alimentazione: batteria, profili energetici, azioni di sessione."""

from __future__ import annotations

from pathlib import Path

from ..sistema import avvia, esegui, esiste, uscita


def batteria() -> dict | None:
    for alim in Path("/sys/class/power_supply").glob("*"):
        try:
            if (alim / "type").read_text().strip() != "Battery":
                continue
            capacita = int((alim / "capacity").read_text().strip())
            stato = (alim / "status").read_text().strip()
            return {"percentuale": capacita, "in_carica": stato in ("Charging", "Full"),
                    "stato": stato}
        except (OSError, ValueError):
            continue
    return None


def profili() -> dict:
    if not esiste("powerprofilesctl"):
        return {"disponibile": False, "attivo": "", "elenco": []}
    import re

    attivo = uscita(["powerprofilesctl", "get"]).strip()
    elenco = re.findall(r"^\s*\*?\s*([a-z-]+):\s*$", uscita(["powerprofilesctl", "list"]), re.M)
    return {"disponibile": True, "attivo": attivo, "elenco": elenco or ["balanced", "power-saver"]}


def imposta_profilo(nome: str) -> bool:
    return esegui(["powerprofilesctl", "set", nome]).returncode == 0


def blocca() -> None:
    avvia(["swaylock", "-f"])


def esci() -> None:
    avvia(["labwc", "--exit"])


def riavvia() -> None:
    avvia(["systemctl", "reboot"])


def spegni() -> None:
    avvia(["systemctl", "poweroff"])


def sospendi() -> None:
    avvia(["systemctl", "suspend"])
