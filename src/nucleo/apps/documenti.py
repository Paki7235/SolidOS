"""Documenti: lettore di PDF (sostituisce qpdfview), basato su QtPdf."""

from __future__ import annotations

import sys
from pathlib import Path

from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app


class BackendDocumenti(Backend):
    def fileIniziale(self) -> str:
        argomenti = [a for a in sys.argv[1:] if not a.startswith("-")]
        return str(Path(argomenti[0]).resolve()) if argomenti else ""

    def stampa(self, percorso: str) -> bool:
        from ..sistema import esegui

        return esegui(["lp", percorso.replace("file://", "")]).returncode == 0


def main() -> int:
    return esegui_app("documenti", "Documenti/Main.qml", lambda app: {"ponte": crea_ponte(BackendDocumenti())})


if __name__ == "__main__":
    sys.exit(main())
