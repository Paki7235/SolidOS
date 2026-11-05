"""Finestra «Installa con <OS_NAME>».   Uso: <OS_ID>-installa FILE"""

from __future__ import annotations

import sys

from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app
from . import analizza, esegui_senza_installare, installa


class BackendInstalla(Backend):
    def file(self) -> str:
        argomenti = [a for a in sys.argv[1:] if not a.startswith("-")]
        return argomenti[0].removeprefix("file://") if argomenti else ""

    def analizza(self, percorso: str) -> dict:
        return analizza(percorso)

    def installa(self, percorso: str) -> dict:
        return installa(percorso, lambda testo: self.emetti("fase", testo))

    def eseguiSenzaInstallare(self, percorso: str) -> None:
        esegui_senza_installare(percorso)

    def cercaAlternativa(self, nome: str) -> None:
        from .. import branding
        from ..sistema import avvia

        avvia([branding.comando("store"), "--cerca", nome])


def main() -> int:
    return esegui_app("installa", "Installa/Main.qml", lambda app: {"ponte": crea_ponte(BackendInstalla())})


if __name__ == "__main__":
    sys.exit(main())
