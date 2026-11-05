"""Registro privacy in SQLite (~/.local/state/<OS_ID>/privacy.db). Resta sul computer."""

from __future__ import annotations

import sqlite3
import time
from pathlib import Path

from ..sistema import config_utente, leggi_json, stato_utente


class Registro:
    def __init__(self, percorso: Path | None = None):
        self.percorso = percorso or stato_utente("privacy.db")
        self.con = sqlite3.connect(self.percorso, timeout=5)
        self.con.execute("CREATE TABLE IF NOT EXISTS eventi (id INTEGER PRIMARY KEY, istante REAL, tipo TEXT, app TEXT, dettaglio TEXT)")
        self.con.execute("CREATE INDEX IF NOT EXISTS indice_istante ON eventi(istante)")

    def attivo(self) -> bool:
        return leggi_json(config_utente("privacy.json"), {"attivo": True}).get("attivo", True)

    def aggiungi(self, tipo: str, app: str, dettaglio: str = "") -> None:
        if not self.attivo():
            return
        with self.con:
            self.con.execute("INSERT INTO eventi (istante, tipo, app, dettaglio) VALUES (?, ?, ?, ?)",
                             (time.time(), tipo, app[:80], dettaglio[:400]))

    def ultimi(self, quanti: int = 50) -> list[dict]:
        righe = self.con.execute("SELECT id, istante, tipo, app, dettaglio FROM eventi ORDER BY istante DESC LIMIT ?", (quanti,))
        return [{"id": r[0], "quando": time.strftime("%d/%m %H:%M", time.localtime(r[1])), "tipo": r[2], "app": r[3],
                 "dettaglio": r[4]} for r in righe]

    def riepilogo(self, giorni: int = 7) -> dict:
        da = time.time() - giorni * 86400
        return {t: n for t, n in self.con.execute("SELECT tipo, COUNT(*) FROM eventi WHERE istante > ? GROUP BY tipo", (da,))}

    def pulisci(self) -> None:
        giorni = leggi_json(config_utente("privacy.json"), {"giorni": 90}).get("giorni", 90)
        with self.con:
            self.con.execute("DELETE FROM eventi WHERE istante < ?", (time.time() - int(giorni) * 86400,))

    def cancella(self) -> None:
        with self.con:
            self.con.execute("DELETE FROM eventi")
