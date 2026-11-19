"""Calcolatrice: Base, Scientifica e Converti (valute con i cambi della BCE e misure),
con la cronologia per giorno. Gli stessi calcoli della Calcolatrice del telefono
(nucleo/calcolo.py)."""

from __future__ import annotations

import sys

from .. import calcolo
from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app


class BackendCalcolatrice(Backend):
    def calcola(self, espressione: str, radianti: bool = False) -> dict:
        r = calcolo.calcola(espressione, bool(radianti))
        # stessa forma di prima per chi la usa: ok + risultato/errore
        return {"ok": r["ok"], "risultato": r["valore"], "errore": "" if r["ok"] else r["valore"]}

    def storia(self) -> list:
        return calcolo.storia_calcoli()

    def ricorda(self, espressione: str, risultato: str) -> None:
        calcolo.aggiungi_calcolo(espressione, risultato)

    def cancellaStoria(self) -> None:
        calcolo.cancella_storia()

    def unita(self, categoria: str) -> list:
        return calcolo.unita_conversione(categoria)

    def converti(self, categoria: str, da: str, a: str, espressione: str) -> dict:
        return calcolo.converti(categoria, da, a, espressione)


def main() -> int:
    return esegui_app("calcolatrice", "Calcolatrice/Main.qml", lambda app: {"ponte": crea_ponte(BackendCalcolatrice())})


if __name__ == "__main__":
    sys.exit(main())
