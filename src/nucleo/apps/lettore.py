"""Lettore: video e musica (sostituisce VLC), basato su QtMultimedia."""

from __future__ import annotations

import sys
from pathlib import Path

from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app

MEDIA = {".mp4", ".mkv", ".webm", ".avi", ".mov", ".m4v", ".mpg", ".mpeg", ".wmv", ".flv", ".3gp", ".ogv",
         ".mp3", ".flac", ".ogg", ".opus", ".wav", ".m4a", ".aac", ".wma", ".aiff"}


class BackendLettore(Backend):
    def fileIniziale(self) -> list[str]:
        return [str(Path(a).resolve()) for a in sys.argv[1:] if not a.startswith("-")]

    def cartella(self, percorso: str) -> list[str]:
        """I file audio e video della stessa cartella, per la scaletta."""
        p = Path(percorso.replace("file://", ""))
        c = p if p.is_dir() else p.parent
        if not c.is_dir():
            return []
        return [str(f) for f in sorted(c.iterdir(), key=lambda x: x.name.lower())
                if f.is_file() and f.suffix.lower() in MEDIA]


def main() -> int:
    return esegui_app("lettore", "Lettore/Main.qml", lambda app: {"ponte": crea_ponte(BackendLettore())})


if __name__ == "__main__":
    sys.exit(main())
