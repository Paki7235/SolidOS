"""Apre la Barra Unica nella shell; se la shell non risponde, avvia una finestra autonoma."""

import sys

from .. import branding
from ..dbusutil import chiama, inizializza


def main() -> int:
    inizializza()
    nome = branding.nome_dbus("Shell")
    if chiama(nome, branding.percorso_dbus("Shell"), nome, "MostraBarra", timeout=2) is not None:
        return 0
    from ..ponte import crea_ponte
    from ..qmlapp import esegui_app
    from .ponte_barra import BackendBarra

    return esegui_app("barra", "Shell/BarraAutonoma.qml", lambda app: {"shell": crea_ponte(BackendBarra())})


if __name__ == "__main__":
    sys.exit(main())
