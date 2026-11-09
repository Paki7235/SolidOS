"""Foto: visualizzatore di immagini (sostituisce qimgv)."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app

ESTENSIONI = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".svg", ".tif", ".tiff", ".avif", ".heic", ".heif"}


class BackendFoto(Backend):
    def fileIniziale(self) -> str:
        argomenti = [a for a in sys.argv[1:] if not a.startswith("-")]
        if argomenti:
            return str(Path(argomenti[0]).resolve())
        immagini = Path.home() / "Immagini"
        prima = self.elenco(str(immagini))
        return prima[0] if prima else ""

    def elenco(self, percorso: str) -> list[str]:
        """Le immagini della cartella del file (o della cartella stessa), in ordine."""
        p = Path(percorso.replace("file://", ""))
        cartella = p if p.is_dir() else p.parent
        if not cartella.is_dir():
            return []
        return [str(f) for f in sorted(cartella.iterdir(), key=lambda x: x.name.lower())
                if f.suffix.lower() in ESTENSIONI and f.is_file()]

    def usaComeSfondo(self, percorso: str) -> bool:
        from ..sistema import imposta_sfondo

        imposta_sfondo(percorso.replace("file://", ""))
        return True

    def cestino(self, percorso: str) -> bool:
        return subprocess.run(["gio", "trash", percorso.replace("file://", "")], capture_output=True).returncode == 0

    def mostraNellaCartella(self, percorso: str) -> None:
        from ..sistema import avvia

        avvia(["pcmanfm-qt", str(Path(percorso.replace("file://", "")).parent)])


def main() -> int:
    return esegui_app("foto", "Foto/Main.qml", lambda app: {"ponte": crea_ponte(BackendFoto())})


if __name__ == "__main__":
    sys.exit(main())
