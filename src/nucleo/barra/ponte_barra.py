"""Metodi della Barra Unica esposti al QML (usati dalla shell e dalla finestra autonoma)."""

from ..ponte import Backend
from . import motore


class BackendBarra(Backend):
    def barraCerca(self, testo: str) -> list:
        return motore.cerca(testo)

    def barraEsegui(self, risultato) -> str:
        return motore.esegui_risultato(dict(risultato))
