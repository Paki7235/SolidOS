"""Struttura dei pannelli delle Impostazioni.

Ogni pannello descrive le sue voci con dizionari semplici; l'interfaccia QML
le disegna in modo uniforme e la ricerca usa titoli, descrizioni e parole chiave.
"""

from __future__ import annotations

from ..i18n import T


def intestazione(titolo: str) -> dict:
    return {"tipo": "intestazione", "id": "", "titolo": titolo}


def interruttore(ident, titolo, valore, descrizione="", chiavi="", abilitata=True) -> dict:
    return {"tipo": "interruttore", "id": ident, "titolo": titolo, "valore": bool(valore),
            "descrizione": descrizione, "chiavi": chiavi, "abilitata": abilitata}


def scelta(ident, titolo, valore, opzioni, descrizione="", chiavi="") -> dict:
    """opzioni: elenco di (valore, testo) oppure di stringhe."""
    norm = [{"valore": o[0], "testo": o[1]} if isinstance(o, (tuple, list)) else {"valore": o, "testo": o}
            for o in opzioni]
    return {"tipo": "scelta", "id": ident, "titolo": titolo, "valore": valore, "opzioni": norm,
            "descrizione": descrizione, "chiavi": chiavi}


def cursore(ident, titolo, valore, minimo=0, massimo=100, passo=1, unita="", descrizione="", chiavi="") -> dict:
    return {"tipo": "cursore", "id": ident, "titolo": titolo, "valore": valore, "minimo": minimo,
            "massimo": massimo, "passo": passo, "unita": unita, "descrizione": descrizione, "chiavi": chiavi}


def campo(ident, titolo, valore="", descrizione="", segreto=False, chiavi="") -> dict:
    return {"tipo": "campo", "id": ident, "titolo": titolo, "valore": valore or "",
            "descrizione": descrizione, "segreto": segreto, "chiavi": chiavi}


def info(ident, titolo, valore, descrizione="", chiavi="") -> dict:
    return {"tipo": "info", "id": ident, "titolo": titolo, "valore": str(valore),
            "descrizione": descrizione, "chiavi": chiavi}


def azione(ident, titolo, pulsante, descrizione="", pericolosa=False, richiede=None, chiavi="",
           file=False) -> dict:
    """richiede: campi da chiedere prima di eseguire, es. [{"id": "nome", "etichetta": "Nome"}].
    file: True per far scegliere un file prima di eseguire (passato come dati["file"])."""
    return {"tipo": "azione", "id": ident, "titolo": titolo, "pulsante": pulsante,
            "descrizione": descrizione, "pericolosa": pericolosa, "richiede": richiede or [],
            "chiavi": chiavi, "file": file}


def elenco(ident, titolo, elementi, vuoto="", chiavi="") -> dict:
    """elementi: [{id, titolo, sottotitolo, icona, attivo, azioni:[{id, testo, richiede, pericolosa}]}]"""
    return {"tipo": "elenco", "id": ident, "titolo": titolo, "elementi": elementi,
            "vuoto": vuoto or T("Nessun elemento"), "chiavi": chiavi}


def esito(ok=True, messaggio="", ricarica=True, **altro) -> dict:
    return {"ok": ok, "messaggio": messaggio, "ricarica": ricarica, **altro}


class Pannello:
    id = ""
    titolo = ""
    icona = "preferences-system"
    gruppo = ""
    chiavi = ""

    def voci(self) -> list[dict]:
        return []

    def imposta(self, voce: str, valore) -> dict | None:
        return None

    def azione(self, voce: str, elemento: str, azione: str, dati: dict) -> dict | None:
        return None
