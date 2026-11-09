"""Calcolatrice (sostituisce Qalculate): valutazione sicura delle espressioni con ast."""

from __future__ import annotations

import ast
import math
import operator
import sys

from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app

OPERATORI = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul, ast.Div: operator.truediv,
             ast.Pow: operator.pow, ast.Mod: operator.mod, ast.USub: operator.neg, ast.UAdd: operator.pos}
FUNZIONI = {"sqrt": math.sqrt, "sin": lambda x: math.sin(math.radians(x)), "cos": lambda x: math.cos(math.radians(x)),
            "tan": lambda x: math.tan(math.radians(x)), "log": math.log10, "ln": math.log, "abs": abs,
            "fact": lambda x: math.factorial(int(x))}
COSTANTI = {"pi": math.pi, "e": math.e}


def _valuta(nodo):
    if isinstance(nodo, ast.Expression):
        return _valuta(nodo.body)
    if isinstance(nodo, ast.Constant) and isinstance(nodo.value, (int, float)):
        return nodo.value
    if isinstance(nodo, ast.BinOp) and type(nodo.op) in OPERATORI:
        sinistra, destra = _valuta(nodo.left), _valuta(nodo.right)
        if isinstance(nodo.op, ast.Pow) and abs(destra) > 1000:
            raise ValueError("esponente troppo grande")
        return OPERATORI[type(nodo.op)](sinistra, destra)
    if isinstance(nodo, ast.UnaryOp) and type(nodo.op) in OPERATORI:
        return OPERATORI[type(nodo.op)](_valuta(nodo.operand))
    if isinstance(nodo, ast.Call) and isinstance(nodo.func, ast.Name) and nodo.func.id in FUNZIONI and len(nodo.args) == 1:
        return FUNZIONI[nodo.func.id](_valuta(nodo.args[0]))
    if isinstance(nodo, ast.Name) and nodo.id in COSTANTI:
        return COSTANTI[nodo.id]
    raise ValueError("espressione non valida")


def formatta(valore: float) -> str:
    if isinstance(valore, float) and valore.is_integer() and abs(valore) < 1e15:
        valore = int(valore)
    if isinstance(valore, int):
        return f"{valore:,}".replace(",", ".")
    testo = f"{valore:.10g}"
    if "e" in testo:
        return testo.replace(".", ",")
    intero, _, decimali = testo.partition(".")
    return f"{int(intero):,}".replace(",", ".") + ("," + decimali if decimali else "")


class BackendCalcolatrice(Backend):
    def calcola(self, espressione: str) -> dict:
        testo = (espressione.replace("×", "*").replace("÷", "/").replace("−", "-").replace("^", "**")
                 .replace("π", "pi").replace("√", "sqrt").replace(",", "."))
        if testo.endswith("%"):
            testo = f"({testo[:-1]})/100"
        try:
            valore = _valuta(ast.parse(testo, mode="eval"))
        except ZeroDivisionError:
            return {"ok": False, "errore": "Divisione per zero"}
        except (ValueError, SyntaxError, TypeError, OverflowError):
            return {"ok": False, "errore": "Espressione non valida"}
        return {"ok": True, "risultato": formatta(valore), "grezzo": repr(valore)}


def main() -> int:
    return esegui_app("calcolatrice", "Calcolatrice/Main.qml", lambda app: {"ponte": crea_ponte(BackendCalcolatrice())})


if __name__ == "__main__":
    sys.exit(main())
