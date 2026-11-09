"""Testo: editor di testo semplice (sostituisce FeatherPad)."""

from __future__ import annotations

import sys
from pathlib import Path

from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app


class BackendTesto(Backend):
    def fileIniziale(self) -> str:
        argomenti = [a for a in sys.argv[1:] if not a.startswith("-")]
        return str(Path(argomenti[0]).resolve()) if argomenti else ""

    def apri(self, percorso: str) -> dict:
        p = Path(percorso.replace("file://", ""))
        try:
            dati = p.read_bytes()
        except OSError as e:
            return {"ok": False, "errore": str(e)}
        for codifica in ("utf-8", "cp1252", "latin-1"):
            try:
                testo = dati.decode(codifica)
                break
            except UnicodeDecodeError:
                continue
        return {"ok": True, "testo": testo, "percorso": str(p), "nome": p.name}

    def salva(self, percorso: str, testo: str) -> dict:
        p = Path(percorso.replace("file://", ""))
        try:
            p.write_text(testo, encoding="utf-8")
        except OSError as e:
            return {"ok": False, "errore": str(e)}
        return {"ok": True, "percorso": str(p), "nome": p.name}


def main() -> int:
    return esegui_app("testo", "Testo/Main.qml", lambda app: {"ponte": crea_ponte(BackendTesto())})


if __name__ == "__main__":
    sys.exit(main())
