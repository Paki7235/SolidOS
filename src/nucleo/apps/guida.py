"""Guida: documentazione offline in Markdown (/usr/share/nucleo/guida/<lingua>/)."""

from __future__ import annotations

import re
import sys
from pathlib import Path

from .. import branding
from ..i18n import lingua_corrente
from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app

BASE = Path("/usr/share/nucleo/guida")


class BackendGuida(Backend):
    def _cartella(self) -> Path:
        for lingua in (lingua_corrente(), "it"):
            if (BASE / lingua).is_dir():
                return BASE / lingua
        return BASE

    def _testo(self, file: Path) -> str:
        testo = file.read_text(encoding="utf-8")
        return (testo.replace("{{OS_NAME}}", branding.nome())
                     .replace("{{OS_ID}}", branding.id_os()))

    def argomenti(self) -> list[dict]:
        risultato = []
        for file in sorted(self._cartella().glob("*.md")):
            primo = self._testo(file).splitlines()[0] if file.stat().st_size else file.stem
            risultato.append({"id": file.stem, "titolo": primo.lstrip("# ").strip()})
        return risultato

    def pagina(self, ident: str) -> str:
        file = self._cartella() / f"{Path(ident).name}.md"
        return self._testo(file) if file.is_file() else ""

    def cerca(self, testo: str) -> list[dict]:
        testo = testo.strip().lower()
        if not testo:
            return self.argomenti()
        risultato = []
        for voce in self.argomenti():
            contenuto = self.pagina(voce["id"])
            if testo in contenuto.lower():
                m = re.search(r"[^\n]*" + re.escape(testo) + r"[^\n]*", contenuto, re.I)
                voce["estratto"] = m.group(0).strip()[:120] if m else ""
                risultato.append(voce)
        return risultato


def main() -> int:
    return esegui_app("guida", "Guida/Main.qml", lambda app: {"ponte": crea_ponte(BackendGuida())})


if __name__ == "__main__":
    sys.exit(main())
