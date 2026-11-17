"""App store.   Uso: <OS_ID>-store [--cerca TESTO]"""

from __future__ import annotations

import sys

from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app
from . import aggiornamenti_flatpak, cerca, installa, installate, rimuovi, vetrina


class BackendStore(Backend):
    def ricercaIniziale(self) -> str:
        if "--cerca" in sys.argv:
            i = sys.argv.index("--cerca")
            return sys.argv[i + 1] if i + 1 < len(sys.argv) else ""
        return ""

    def vetrina(self):
        return vetrina()

    def prepara(self) -> dict:
        """All'apertura: Flathub e il suo catalogo (la prima volta lo scarica, un minuto circa)."""
        from ..installa import prepara_flathub
        from ..sistema import esiste

        if not esiste("flatpak"):
            return {"ok": False, "messaggio": "Flatpak non è installato"}
        prepara_flathub()
        return {"ok": True}

    def cerca(self, testo):
        return cerca(testo)

    def installate(self):
        return installate()

    def installa(self, ident, origine):
        return installa(ident, origine)

    def rimuovi(self, ident, origine, sistema=False):
        return rimuovi(ident, origine, bool(sistema))

    def aggiorna(self):
        return aggiornamenti_flatpak()


def main() -> int:
    return esegui_app("store", "Store/Main.qml", lambda app: {"ponte": crea_ponte(BackendStore())})


if __name__ == "__main__":
    sys.exit(main())
