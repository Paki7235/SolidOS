"""Finestra «Condividi»: scegli un dispositivo vicino oppure usa il codice QR.

Uso: <OS_ID>-condividi [FILE…]    (senza file: modalità «ricevi con QR»)
"""

import json
import sys
from pathlib import Path

from .. import branding
from ..dbusutil import chiama, inizializza
from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app


def _servizio(metodo, *argomenti, timeout=10):
    nome = branding.nome_dbus("Condivisione1")
    return chiama(nome, branding.percorso_dbus("Condivisione1"), nome, metodo, *argomenti, timeout=timeout)


class BackendSelettore(Backend):
    def file(self) -> list:
        return [str(Path(a.removeprefix("file://")).resolve()) for a in sys.argv[1:] if not a.startswith("-")]

    def attivo(self) -> bool:
        return _servizio("StatoBackend", timeout=3) is not None

    def scopri(self) -> None:
        _servizio("Scopri", 30)

    def dispositivi(self) -> list:
        testo = _servizio("Dispositivi", timeout=3)
        return json.loads(str(testo)) if testo else []

    def invia(self, dispositivo: str) -> str:
        return str(_servizio("Invia", self.file(), dispositivo) or "")

    def qr(self, hotspot: bool = False) -> dict:
        if self.file():
            testo = _servizio("InviaConQr", self.file(), timeout=40)
        else:
            testo = _servizio("RiceviConQr", bool(hotspot), timeout=40)
        return json.loads(str(testo)) if testo else {"errore": "servizio non attivo"}

    def fermaQr(self) -> None:
        _servizio("FermaQr")


def main() -> int:
    inizializza()
    return esegui_app("condividi", "Condividi/Main.qml", lambda app: {"ponte": crea_ponte(BackendSelettore())})


if __name__ == "__main__":
    sys.exit(main())
