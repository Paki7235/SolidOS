"""Finestre aperte (protocollo wlr-foreign-toplevel di labwc) per il dock e la barra.

Il modulo del protocollo è generato da pywayland-scanner durante la build in
nucleo/wl/. Se manca (o il compositor non lo offre) il dock funziona lo stesso
come lanciatore, senza indicatori delle app aperte.
"""

from __future__ import annotations

import sys

STATI = {0: "massimizzata", 1: "minimizzata", 2: "attiva", 3: "schermoIntero"}


class Finestre:
    """Elenco delle finestre aperte; chiama `al_cambio(elenco)` a ogni variazione."""

    def __init__(self, al_cambio):
        self.al_cambio = al_cambio
        self.finestre: dict[int, dict] = {}
        self._maniglie: dict[int, object] = {}
        self._prossimo = 1
        self.seat = None
        self.display = None
        self.notificatore = None
        try:
            self._collega()
        except Exception as e:  # noqa: BLE001 — il dock resta usabile come lanciatore
            print(f"finestre: protocollo non disponibile ({e})", file=sys.stderr)
            self.display = None

    # ── Collegamento Wayland ────────────────────────────────────────────────
    def _collega(self):
        from pywayland.client import Display

        from ..wl.wayland import WlSeat
        from ..wl.wlr_foreign_toplevel_management_unstable_v1 import ZwlrForeignToplevelManagerV1

        self.display = Display()
        self.display.connect()
        # Il registro va tenuto in vita: pywayland lo usa per ritrovare il display
        # quando arrivano nuovi oggetti (le maniglie delle finestre).
        self.registro = registro = self.display.get_registry()
        manager = []

        def globale(reg, nome, interfaccia, versione):
            if interfaccia == "zwlr_foreign_toplevel_manager_v1":
                manager.append(reg.bind(nome, ZwlrForeignToplevelManagerV1, min(versione, 3)))
            elif interfaccia == "wl_seat" and self.seat is None:
                self.seat = reg.bind(nome, WlSeat, min(versione, 5))

        registro.dispatcher["global"] = globale
        self.display.roundtrip()
        if not manager:
            raise RuntimeError("zwlr_foreign_toplevel_manager_v1 assente")
        self.manager = manager[0]
        self.manager.dispatcher["toplevel"] = self._nuova
        self.display.roundtrip()

        from PyQt6.QtCore import QSocketNotifier

        self.notificatore = QSocketNotifier(self.display.get_fd(), QSocketNotifier.Type.Read)
        self.notificatore.activated.connect(self._leggi)
        self.display.flush()

    def _leggi(self, *_):
        try:
            # Il socket ha dati: si leggono (senza attese) e si elaborano gli eventi in coda.
            # Mai dispatch(block=True): un problema qui non deve bloccare la shell.
            self.display.read()
            self.display.dispatch(block=False)
            self.display.flush()
        except Exception as e:  # noqa: BLE001
            print(f"finestre: {e}", file=sys.stderr)
            if self.notificatore:
                self.notificatore.setEnabled(False)

    def _nuova(self, _manager, maniglia):
        ident = self._prossimo
        self._prossimo += 1
        dati = {"id": ident, "appId": "", "titolo": "", "attiva": False, "minimizzata": False,
                "massimizzata": False, "schermoIntero": False}
        provvisori = dict(dati)

        def titolo(_h, t):
            provvisori["titolo"] = t

        def app_id(_h, a):
            provvisori["appId"] = a

        def stato(_h, valori):
            attivi = set()
            raw = bytes(valori) if not isinstance(valori, (list, tuple)) else None
            if raw is not None:
                import struct

                attivi = set(struct.unpack(f"{len(raw) // 4}I", raw))
            else:
                attivi = set(valori)
            for codice, nome in STATI.items():
                provvisori[nome] = codice in attivi

        def fatto(_h):
            self.finestre[ident] = dict(provvisori)
            self._avvisa()

        def chiusa(_h):
            self.finestre.pop(ident, None)
            self._maniglie.pop(ident, None)
            self._avvisa()

        maniglia.dispatcher["title"] = titolo
        maniglia.dispatcher["app_id"] = app_id
        maniglia.dispatcher["state"] = stato
        maniglia.dispatcher["done"] = fatto
        maniglia.dispatcher["closed"] = chiusa
        self._maniglie[ident] = maniglia

    def _avvisa(self):
        try:
            self.al_cambio(self.elenco())
        except Exception as e:  # noqa: BLE001
            print(f"finestre: {e}", file=sys.stderr)

    # ── Interrogazioni e comandi ────────────────────────────────────────────
    def disponibile(self) -> bool:
        return self.display is not None

    def elenco(self) -> list[dict]:
        return list(self.finestre.values())

    def _esegui(self, ident: int, fn):
        maniglia = self._maniglie.get(int(ident))
        if maniglia is None or self.display is None:
            return False
        fn(maniglia)
        self.display.flush()
        return True

    def attiva(self, ident: int) -> bool:
        def f(m):
            if self.finestre.get(int(ident), {}).get("minimizzata"):
                m.unset_minimized()
            if self.seat is not None:
                m.activate(self.seat)
        return self._esegui(ident, f)

    def minimizza(self, ident: int) -> bool:
        return self._esegui(ident, lambda m: m.set_minimized())

    def chiudi(self, ident: int) -> bool:
        return self._esegui(ident, lambda m: m.close())

    def alterna(self, ident: int) -> bool:
        """Clic sul dock: attiva la finestra, oppure la riduce se è già quella attiva."""
        f = self.finestre.get(int(ident))
        if f and f["attiva"] and not f["minimizzata"]:
            return self.minimizza(ident)
        return self.attiva(ident)
