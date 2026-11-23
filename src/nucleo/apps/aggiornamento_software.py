"""Aggiornamento software: cerca la nuova versione di SolidOS,
mostra cosa cambia e quanto pesa, la installa con una barra di avanzamento e propone
di riavviare. Con «--avvisa» resta in ascolto nella sessione e manda una notifica
(con il pulsante «Aggiorna») quando esce una nuova versione.
"""

from __future__ import annotations

import json
import subprocess
import sys
import threading
import time
from pathlib import Path

from .. import aggiornamento, branding
from ..i18n import T
from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app
from ..sistema import avvia, helper, stato_utente, uscita

AVANZAMENTO = Path("/run/nucleo-aggiornamento.json")


def _mb(byte: int) -> str:
    return f"{byte / 1048576:.1f} MB".replace(".", ",") if byte else ""


class BackendAggiornamento(Backend):
    def controlla(self) -> dict:
        c = aggiornamento.controlla()
        c["nome"] = branding.nome()
        c["versioneSistema"] = branding.get("OS_VERSION")
        c["peso"] = _mb(c.get("dimensione") or 0)
        c["novitaInstallata"] = aggiornamento.novita_installata()
        try:   # aggiornamenti di Debian e delle app (oltre a SolidOS)
            c["altri"] = uscita(["apt-get", "-s", "-o", "Debug::NoLocking=1", "upgrade"], timeout=60).count("\nInst ")
        except Exception:  # noqa: BLE001
            c["altri"] = 0
        return c

    def installa(self) -> dict:
        r = helper("aggiorna-solidos", timeout=3600)
        testo = (r.stdout or "").strip() or (r.stderr or "").strip()
        if r.returncode != 0:
            return {"ok": False, "messaggio": testo or T("Aggiornamento annullato")}
        return {"ok": True, "messaggio": testo}

    def avanzamento(self) -> dict:
        try:
            return json.loads(AVANZAMENTO.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return {}

    def altri(self) -> dict:
        r = helper("aggiorna-ora")
        return {"ok": r.returncode == 0}

    def riavvia(self) -> None:
        subprocess.Popen(["systemctl", "reboot"], start_new_session=True)


def avvisa() -> int:
    """Nella sessione: dopo l'accesso e poi ogni 6 ore cerca una nuova versione e, se c'è
    (e non è già stata segnalata), manda una notifica con il pulsante «Aggiorna»."""
    segnalata = stato_utente("aggiornamento-segnalato")
    time.sleep(90)
    while True:
        c = aggiornamento.controlla()
        gia = segnalata.read_text().strip() if segnalata.exists() else ""
        if c.get("nuova") and str(c["disponibile"]) != gia:
            segnalata.write_text(str(c["disponibile"]))

            def notifica(c=c):
                r = subprocess.run(["notify-send", f"--app-name={branding.nome()}", "--icon=system-software-update",
                                    "--action=apri=" + T("Aggiorna"), "--wait",
                                    T("Aggiornamento disponibile"),
                                    T("{s} build {n}: {novita}", s=branding.nome(), n=c["disponibile"],
                                      novita=c.get("novita") or T("miglioramenti e correzioni"))],
                                   capture_output=True, text=True, check=False)
                if r.stdout.strip() == "apri":
                    avvia([branding.comando("aggiornamento-software")])

            threading.Thread(target=notifica, daemon=True).start()
        time.sleep(6 * 3600)


def main() -> int:
    if "--avvisa" in sys.argv[1:]:
        return avvisa()
    return esegui_app("aggiornamento-software", "AggiornamentoSoftware/Main.qml",
                      lambda app: {"ponte": crea_ponte(BackendAggiornamento())})


if __name__ == "__main__":
    sys.exit(main())
