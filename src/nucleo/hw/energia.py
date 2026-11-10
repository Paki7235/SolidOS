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
    """Profili di alimentazione letti da power-profiles-daemon via D-Bus (risposta entro 2 s)."""
    from ..dbusutil import a_python, chiama

    nulla = {"disponibile": False, "attivo": "", "elenco": []}
    for nome, percorso in (("org.freedesktop.UPower.PowerProfiles", "/org/freedesktop/UPower/PowerProfiles"),
                           ("net.hadess.PowerProfiles", "/net/hadess/PowerProfiles")):
        if not chiama("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "NameHasOwner",
                      nome, sistema=True, timeout=1):
            continue            # servizio non avviato: niente attese
        attivo = chiama(nome, percorso, "org.freedesktop.DBus.Properties", "Get", nome, "ActiveProfile",
                        sistema=True, timeout=2)
        if attivo is None:
            continue
        profili_dbus = chiama(nome, percorso, "org.freedesktop.DBus.Properties", "Get", nome, "Profiles",
                              sistema=True, timeout=2)
        elenco = [str(p.get("Profile")) for p in (a_python(profili_dbus) or []) if isinstance(p, dict)]
        return {"disponibile": True, "attivo": str(attivo), "elenco": elenco or ["balanced", "power-saver"]}
    return nulla


def imposta_profilo(nome: str) -> bool:
    return esegui(["powerprofilesctl", "set", nome]).returncode == 0


def blocca() -> None:
    from .. import branding

    avvia([branding.comando("blocca")])


def esci() -> None:
    avvia(["labwc", "--exit"])


def riavvia() -> None:
    avvia(["systemctl", "reboot"])


def spegni() -> None:
    avvia(["systemctl", "poweroff"])


def sospendi() -> None:
    avvia(["systemctl", "suspend"])
