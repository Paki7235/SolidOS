"""Alimentazione: batteria, profili energetici, azioni di sessione."""

from __future__ import annotations

from pathlib import Path

from ..sistema import avvia, esegui, esiste, uscita


# Tipi di telaio (DMI/SMBIOS) dei computer portatili: portatile, notebook, palmare,
# sub-notebook, convertibile, staccabile, tablet
_TELAI_PORTATILI = {8, 9, 10, 14, 30, 31, 32}


def _telaio() -> int:
    try:
        return int(Path("/sys/class/dmi/id/chassis_type").read_text().strip())
    except (OSError, ValueError):
        return 0


def _batteria_di_sistema():
    """La batteria del computer, non quelle di mouse, tastiere o cuffie (scope «Device»)
    e non quella finta che alcune macchine virtuali mostrano."""
    for alim in sorted(Path("/sys/class/power_supply").glob("*")):
        try:
            if (alim / "type").read_text().strip() != "Battery":
                continue
            if (alim / "scope").exists() and (alim / "scope").read_text().strip().lower() == "device":
                continue
            if (alim / "present").exists() and (alim / "present").read_text().strip() == "0":
                continue
            return alim
        except OSError:
            continue
    return None


def portatile() -> bool:
    """È un portatile? Lo dice il telaio; se non lo dice (0, 1, 2 = sconosciuto o «altro»),
    basta una batteria di sistema vera. Le macchine virtuali con il telaio da fisso no."""
    telaio = _telaio()
    if telaio in _TELAI_PORTATILI:
        return True
    if telaio in (0, 2) and _batteria_di_sistema() is not None:
        return True
    return False


def batteria() -> dict | None:
    """Livello e stato della batteria, solo sui portatili (sui fissi: None, e la batteria non si mostra)."""
    if not portatile():
        return None
    alim = _batteria_di_sistema()
    if alim is None:
        return None
    try:
        capacita = int((alim / "capacity").read_text().strip())
        stato = (alim / "status").read_text().strip()
    except (OSError, ValueError):
        return None
    return {"percentuale": capacita, "in_carica": stato in ("Charging", "Full"), "stato": stato}


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
