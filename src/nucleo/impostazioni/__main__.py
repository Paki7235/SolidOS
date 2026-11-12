"""Avvio dell'app Impostazioni.   Uso: <OS_ID>-impostazioni [pannello]"""

from __future__ import annotations

import sys
import threading
import traceback
import unicodedata

from ..i18n import T
from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app
from . import PANNELLI


def normalizza(testo: str) -> str:
    testo = unicodedata.normalize("NFD", str(testo).lower())
    return "".join(c for c in testo if unicodedata.category(c) != "Mn")


class BackendImpostazioni(Backend):
    def __init__(self):
        self._pannelli = {cls.id: cls() for cls in PANNELLI}
        self._cache: dict[str, list[dict]] = {}
        # Il precaricamento dei pannelli (per la ricerca) parte dopo che la finestra è comparsa:
        # all'avvio contenderebbe il processore all'interfaccia e la finestra arriverebbe tardi
        avvio = threading.Timer(4.0, self._precarica)
        avvio.daemon = True
        avvio.start()

    def _precarica(self):
        for ident in list(self._pannelli):
            if ident not in self._cache:
                try:
                    self._cache[ident] = self._pannelli[ident].voci()
                except Exception:  # noqa: BLE001
                    self._cache[ident] = []

    def pannelli(self) -> list[dict]:
        return [{"id": p.id, "titolo": p.titolo, "icona": p.icona, "gruppo": p.gruppo}
                for p in self._pannelli.values()]

    def utente(self) -> dict:
        import os
        import pwd

        voce = pwd.getpwuid(os.getuid())
        completo = (voce.pw_gecos or "").split(",")[0].strip()
        return {"nome": completo or voce.pw_name, "login": voce.pw_name}

    def iniziale(self) -> str:
        argomenti = [a for a in sys.argv[1:] if not a.startswith("-")]
        return argomenti[0] if argomenti and argomenti[0] in self._pannelli else "rete"

    def voci(self, pannello: str) -> list[dict]:
        try:
            voci = self._pannelli[pannello].voci()
        except Exception as e:  # noqa: BLE001 — un pannello guasto non blocca l'app
            traceback.print_exc()
            voci = [{"tipo": "info", "id": "errore", "titolo": T("Impossibile leggere le impostazioni"),
                     "valore": str(e), "descrizione": ""}]
        self._cache[pannello] = voci
        return voci

    def imposta(self, pannello: str, voce: str, valore) -> dict:
        try:
            r = self._pannelli[pannello].imposta(voce, valore)
        except Exception as e:  # noqa: BLE001
            traceback.print_exc()
            return {"ok": False, "messaggio": str(e), "ricarica": True}
        return r or {"ok": False, "messaggio": T("Impostazione non supportata"), "ricarica": False}

    def azione(self, pannello: str, voce: str, elemento: str, azione: str, dati) -> dict:
        try:
            r = self._pannelli[pannello].azione(voce, elemento, azione, dict(dati or {}))
        except Exception as e:  # noqa: BLE001
            traceback.print_exc()
            return {"ok": False, "messaggio": str(e), "ricarica": True}
        return r or {"ok": False, "messaggio": T("Azione non supportata"), "ricarica": False}

    def cerca(self, testo: str) -> list[dict]:
        parole = normalizza(testo).split()
        if not parole:
            return []
        risultati = []
        for p in self._pannelli.values():
            testo_p = normalizza(f"{p.titolo} {p.chiavi}")
            if all(w in testo_p for w in parole):
                risultati.append({"pannello": p.id, "voce": "", "titolo": p.titolo, "percorso": p.gruppo, "icona": p.icona})
            for v in self._cache.get(p.id, []):
                if v.get("tipo") == "intestazione" or not v.get("titolo"):
                    continue
                testo_v = normalizza(f'{v.get("titolo", "")} {v.get("descrizione", "")} {v.get("chiavi", "")}')
                if all(w in testo_v for w in parole):
                    risultati.append({"pannello": p.id, "voce": v.get("id", ""), "titolo": v["titolo"],
                                      "percorso": p.titolo, "icona": p.icona})
        return risultati[:40]


def main() -> int:
    return esegui_app("impostazioni", "Impostazioni/Main.qml",
                      lambda app: {"ponte": crea_ponte(BackendImpostazioni())})


if __name__ == "__main__":
    sys.exit(main())
