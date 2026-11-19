"""Calcoli e conversioni comuni a PC e telefono (Calcolatrice: Base, Scientifica, Converti).

Stesso codice della Calcolatrice di SolidOS Mobile: valutazione sicura con ast (niente eval),
percentuali come le calcolatrici («89,90 − 15%»), fattoriali, gradi/radianti, cronologia per
giorno, valute con i cambi della Banca Centrale Europea (in memoria per l'uso senza rete) e misure.
"""

from __future__ import annotations

import ast
import math
import operator
import re
import time
import urllib.request
from pathlib import Path

from .i18n import T
from .sistema import config_utente, leggi_json, scrivi_json


# ── Calcolatrice ─────────────────────────────────────────────────────────────
_OPERATORI = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul, ast.Div: operator.truediv,
              ast.Pow: operator.pow, ast.Mod: operator.mod, ast.USub: operator.neg, ast.UAdd: operator.pos}
_ANGOLO = {"radianti": False}   # Scientifica: «Rad» acceso = angoli in radianti


def _trig(f):
    return lambda x: f(x if _ANGOLO["radianti"] else math.radians(x))


def _fattoriale(x):
    if x < 0 or x > 170 or x != int(x):
        raise ValueError
    return math.factorial(int(x))


_FUNZIONI = {"sqrt": math.sqrt, "sin": _trig(math.sin), "cos": _trig(math.cos), "tan": _trig(math.tan),
             "log": math.log10, "ln": math.log, "abs": abs, "fact": _fattoriale}
_COSTANTI = {"pi": math.pi, "e": math.e}


def _valuta(nodo):
    if isinstance(nodo, ast.Expression):
        return _valuta(nodo.body)
    if isinstance(nodo, ast.Constant) and isinstance(nodo.value, (int, float)):
        return nodo.value
    if isinstance(nodo, ast.BinOp) and type(nodo.op) in _OPERATORI:
        a, b = _valuta(nodo.left), _valuta(nodo.right)
        if isinstance(nodo.op, ast.Pow) and abs(b) > 1000:
            raise ValueError
        return _OPERATORI[type(nodo.op)](a, b)
    if isinstance(nodo, ast.UnaryOp) and type(nodo.op) in _OPERATORI:
        return _OPERATORI[type(nodo.op)](_valuta(nodo.operand))
    if isinstance(nodo, ast.Call) and isinstance(nodo.func, ast.Name) and nodo.func.id in _FUNZIONI and len(nodo.args) == 1:
        return _FUNZIONI[nodo.func.id](_valuta(nodo.args[0]))
    if isinstance(nodo, ast.Name) and nodo.id in _COSTANTI:
        return _COSTANTI[nodo.id]
    raise ValueError


def formatta_numero(valore) -> str:
    if isinstance(valore, float) and abs(valore - round(valore)) < 1e-12 and abs(valore) < 1e15:
        valore = int(round(valore))
    if isinstance(valore, int):
        return f"{valore:,}".replace(",", ".")
    testo = f"{valore:.10g}"
    if "e" in testo:
        return testo.replace(".", ",")
    intero, _, decimali = testo.partition(".")
    segno = "-" if intero.startswith("-") else ""
    return segno + f"{abs(int(intero)):,}".replace(",", ".") + ("," + decimali if decimali else "")


def _fattoriali(testo: str) -> str:
    """«5!» e «(2+3)!» → fact(5), fact((2+3))."""
    while "!" in testo:
        i = testo.index("!")
        j = i - 1
        if j >= 0 and testo[j] == ")":
            livello = 0
            while j >= 0:
                livello += testo[j] == ")"
                livello -= testo[j] == "("
                if livello == 0:
                    break
                j -= 1
        else:
            while j >= 0 and (testo[j].isdigit() or testo[j] == "."):
                j -= 1
            j += 1
        if j < 0 or j >= i:
            raise ValueError
        testo = testo[:j] + "fact(" + testo[j:i] + ")" + testo[i + 1:]
    return testo


def calcola(espressione: str, radianti: bool = False) -> dict:
    testo = (espressione.replace("×", "*").replace("÷", "/").replace("−", "-").replace("^", "**")
             .replace("π", "pi").replace("√", "sqrt").replace(".", "").replace(",", "."))
    # «89,90 − 15%» toglie il 15% di 89,90 (come le calcolatrici); «1250 × 12%» moltiplica per 0,12
    m = re.fullmatch(r"(.+?)([+-])(\d+(?:\.\d+)?)%", testo)
    if m:
        testo = f"({m.group(1)}){m.group(2)}({m.group(1)})*{m.group(3)}/100"
    testo = re.sub(r"(\d+(?:\.\d+)?)%", r"(\1/100)", testo)
    if testo.endswith("%"):
        testo = f"({testo[:-1]})/100"
    _ANGOLO["radianti"] = bool(radianti)
    try:
        testo = _fattoriali(testo)
        return {"ok": True, "valore": formatta_numero(_valuta(ast.parse(testo, mode="eval")))}
    except ZeroDivisionError:
        return {"ok": False, "valore": T("Impossibile dividere per zero")}
    except (ValueError, SyntaxError, TypeError, OverflowError):
        return {"ok": False, "valore": T("Errore")}


def _file_storia() -> Path:
    return config_utente("calcolatrice.json")


def storia_calcoli() -> list:
    """Gli ultimi calcoli, raggruppati per giorno: [{giorno, calcoli: [{espressione, risultato}]}]."""
    gruppi, oggi = [], time.strftime("%Y-%m-%d")
    ieri = time.strftime("%Y-%m-%d", time.localtime(time.time() - 86400))
    for c in leggi_json(_file_storia(), []):
        g = time.strftime("%Y-%m-%d", time.localtime(c.get("quando", 0)))
        nome = T("Oggi") if g == oggi else (T("Ieri") if g == ieri else time.strftime("%d/%m/%Y", time.localtime(c.get("quando", 0))))
        if not gruppi or gruppi[-1]["giorno"] != nome:
            gruppi.append({"giorno": nome, "calcoli": []})
        gruppi[-1]["calcoli"].append({"espressione": c.get("espressione", ""), "risultato": c.get("risultato", "")})
    return gruppi


def aggiungi_calcolo(espressione: str, risultato: str) -> None:
    elenco = leggi_json(_file_storia(), [])
    elenco.insert(0, {"espressione": espressione, "risultato": risultato, "quando": time.time()})
    scrivi_json(_file_storia(), elenco[:200])


def cancella_storia() -> None:
    scrivi_json(_file_storia(), [])


# ── Converti: valute (cambi della BCE) e misure ─────────────────────────────
UNITA = {
    "lunghezza": {"mm": 0.001, "cm": 0.01, "m": 1, "km": 1000, "in": 0.0254, "ft": 0.3048, "yd": 0.9144, "mi": 1609.344},
    "peso": {"mg": 0.000001, "g": 0.001, "kg": 1, "t": 1000, "oz": 0.028349523125, "lb": 0.45359237},
    "volume": {"ml": 0.001, "cl": 0.01, "l": 1, "m³": 1000, "gal": 3.785411784, "tazza": 0.2365882365},
    "velocita": {"km/h": 1, "m/s": 3.6, "mph": 1.609344, "nodi": 1.852},
    "area": {"m²": 1, "km²": 1e6, "ha": 10000, "ft²": 0.09290304, "acri": 4046.8564224},
    "temperatura": {"°C": None, "°F": None, "K": None},
}
NOMI_VALUTE = {"EUR": "Euro", "USD": "Dollaro USA", "GBP": "Sterlina", "CHF": "Franco svizzero", "JPY": "Yen",
               "CNY": "Yuan", "CAD": "Dollaro canadese", "AUD": "Dollaro australiano", "SEK": "Corona svedese",
               "NOK": "Corona norvegese", "DKK": "Corona danese", "PLN": "Zloty", "CZK": "Corona ceca",
               "HUF": "Fiorino", "RON": "Leu", "TRY": "Lira turca", "BRL": "Real", "INR": "Rupia indiana",
               "MXN": "Peso messicano", "KRW": "Won"}


def _cambi() -> dict:
    """Cambi dell'euro della Banca Centrale Europea (aggiornati ogni giorno lavorativo).
    Si tengono in memoria: senza rete si usano gli ultimi scaricati."""
    cache = Path.home() / ".cache" / "solidos" / "cambi.json"
    dati = leggi_json(cache, {})
    if time.time() - dati.get("scaricati", 0) > 6 * 3600:
        try:
            with urllib.request.urlopen("https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml", timeout=8) as r:
                xml = r.read().decode()
            cambi = {m.group(1): float(m.group(2)) for m in re.finditer(r"currency='(\w+)' rate='([\d.]+)'", xml)}
            giorno = re.search(r"time='([\d-]+)'", xml)
            if cambi:
                dati = {"data": giorno.group(1) if giorno else "", "scaricati": time.time(), "cambi": cambi}
                cache.parent.mkdir(parents=True, exist_ok=True)
                scrivi_json(cache, dati)
        except (OSError, ValueError):
            pass
    return dati


def unita_conversione(categoria: str) -> list:
    if categoria == "valuta":
        c = _cambi().get("cambi", {})
        codici = ["EUR"] + [k for k in NOMI_VALUTE if k in c] + sorted(k for k in c if k not in NOMI_VALUTE)
        return [{"id": k, "nome": NOMI_VALUTE.get(k, k)} for k in codici]
    return [{"id": k, "nome": k} for k in UNITA.get(categoria, {})]


def converti(categoria: str, da: str, a: str, espressione: str) -> dict:
    v = calcola(espressione or "0")
    if not v["ok"]:
        return {"ok": False, "valore": "", "nota": ""}
    numero = float(v["valore"].replace(".", "").replace(",", "."))
    nota = ""
    if categoria == "valuta":
        dati = _cambi()
        c = {"EUR": 1.0, **dati.get("cambi", {})}
        if da not in c or a not in c:
            return {"ok": False, "valore": "", "nota": T("Cambi non disponibili: collegati a Internet una volta")}
        risultato = numero / c[da] * c[a]
        if dati.get("data"):
            g = dati["data"].split("-")
            nota = T("Cambio della Banca Centrale Europea del {d}", d=f"{g[2]}/{g[1]}/{g[0]}" if len(g) == 3 else dati["data"])
    elif categoria == "temperatura":
        c = {"°C": numero, "°F": (numero - 32) * 5 / 9, "K": numero - 273.15}[da]
        risultato = {"°C": c, "°F": c * 9 / 5 + 32, "K": c + 273.15}[a]
    else:
        u = UNITA.get(categoria, {})
        if da not in u or a not in u:
            return {"ok": False, "valore": "", "nota": ""}
        risultato = numero * u[da] / u[a]
    if categoria == "valuta":
        risultato = round(risultato, 2)
    return {"ok": True, "valore": formatta_numero(risultato), "nota": nota}
