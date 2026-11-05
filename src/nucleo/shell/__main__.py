"""Processo della shell: un solo motore QML per notifiche, centro di controllo,
centro notifiche e OSD (finestre Wayland layer-shell).

Servizio D-Bus org.<OS_ID>.Shell (sessione) usato da scorciatoie e altre app:
    MostraControllo()  MostraNotifiche()  MostraBarra()  Nascondi()
    Volume(i passo)    Muto()             Luminosita(i passo)
    NonDisturbare(b)   FiltroApp(as app)  (usato dagli Spazi di vita)
"""

from __future__ import annotations

import sys

import dbus
import dbus.service

from .. import branding
from ..dbusutil import chiama, inizializza
from ..hw import audio, bluetooth, energia, rete, schermo
from ..i18n import T
from ..ponte import Backend, crea_ponte
from ..qmlapp import carica, crea_app, prepara_ambiente
from ..sistema import avvia, esegui
from .notifiche import ServerNotifiche


class BackendShell(Backend):
    def __init__(self):
        self.server: ServerNotifiche | None = None

    # ── Stato per il centro di controllo ────────────────────────────────────
    def stato(self) -> dict:
        r = rete.stato_breve()
        vol = audio.volume()
        luce = schermo.luminosita()
        batt = energia.batteria()
        return {
            "wifi": r["wifi"], "connesso": r["connesso"], "reteNome": r["nome"], "reteTipo": r["tipo"],
            "bluetoothDisponibile": bluetooth.disponibile(), "bluetooth": bluetooth.attivo(),
            "volume": vol["volume"], "muto": vol["muto"],
            "luminosita": -1 if luce is None else luce,
            "nonDisturbare": bool(self.server and self.server.non_disturbare),
            "luceNotturna": schermo.luce_notturna().get("attiva", False),
            "batteria": batt or {},
            "visibilita": self._visibilita(),
            "spazio": self._spazio(),
        }

    def _visibilita(self) -> str:
        valore = chiama(branding.nome_dbus("Condivisione1"), branding.percorso_dbus("Condivisione1"),
                        "org.freedesktop.DBus.Properties", "Get",
                        branding.nome_dbus("Condivisione1"), "Visibilita", timeout=1)
        return str(valore) if valore is not None else "nessuno"

    def _spazio(self) -> dict:
        try:
            from ..spazi import spazio_corrente

            return spazio_corrente()
        except Exception:  # noqa: BLE001 — gli Spazi sono facoltativi
            return {}

    def wifi(self, attivo: bool) -> bool:
        return rete.imposta_wifi(attivo)

    def bluetooth(self, attivo: bool) -> bool:
        return bluetooth.imposta(attivo)

    def volume(self, valore: int) -> None:
        audio.imposta_volume(valore)

    def muto(self) -> dict:
        return audio.imposta_muto(None)

    def luminosita(self, valore: int):
        return schermo.imposta_luminosita(valore)

    def nonDisturbare(self, attivo: bool) -> bool:
        if self.server:
            self.server.non_disturbare = bool(attivo)
        return bool(attivo)

    def luceNotturna(self, attiva: bool) -> dict:
        return schermo.imposta_luce_notturna(bool(attiva))

    def visibilita(self, modalita: str) -> bool:
        return chiama(branding.nome_dbus("Condivisione1"), branding.percorso_dbus("Condivisione1"),
                      branding.nome_dbus("Condivisione1"), "ImpostaVisibilita", modalita) is not None

    def spazi(self) -> list:
        try:
            from ..spazi import elenco_spazi

            return elenco_spazi()
        except Exception:  # noqa: BLE001
            return []

    def attivaSpazio(self, nome: str) -> bool:
        avvia([branding.comando("spazi"), "attiva", nome])
        return True

    def apri(self, app: str, *argomenti) -> None:
        avvia([branding.comando(app), *[str(a) for a in argomenti]])

    def esegui(self, *comando) -> None:
        avvia([str(c) for c in comando])

    def sessione(self, azione: str) -> None:
        {"blocca": energia.blocca, "esci": energia.esci, "riavvia": energia.riavvia,
         "spegni": energia.spegni, "sospendi": energia.sospendi}[azione]()

    # ── Barra Unica ─────────────────────────────────────────────────────────
    def barraCerca(self, testo: str) -> list:
        from ..barra import motore

        return motore.cerca(testo)

    def barraEsegui(self, risultato) -> str:
        from ..barra import motore

        return motore.esegui_risultato(dict(risultato))

    # ── Notifiche ───────────────────────────────────────────────────────────
    def storico(self) -> list:
        return self.server.storico if self.server else []

    def chiudiNotifica(self, ident: int) -> None:
        if self.server:
            self.server.chiudi(int(ident))

    def rimuoviNotifica(self, ident: int) -> None:
        if self.server:
            self.server.rimuovi_da_storico(int(ident))

    def svuotaNotifiche(self) -> None:
        if self.server:
            self.server.svuota_storico()

    def azioneNotifica(self, ident: int, chiave: str) -> None:
        if self.server:
            self.server.azione(int(ident), chiave)

    def scadutaNotifica(self, ident: int) -> None:
        if self.server:
            self.server.NotificationClosed(dbus.UInt32(int(ident)), dbus.UInt32(1))


def crea_servizio_shell(bus, backend: BackendShell):
    nome = branding.nome_dbus("Shell")

    class ServizioShell(dbus.service.Object):
        def __init__(self):
            self._nome = dbus.service.BusName(nome, bus, do_not_queue=True)
            super().__init__(bus, branding.percorso_dbus("Shell"))

        @dbus.service.method(nome, in_signature="", out_signature="")
        def MostraControllo(self):
            backend.emetti("mostra", "controllo")

        @dbus.service.method(nome, in_signature="", out_signature="")
        def MostraNotifiche(self):
            backend.emetti("mostra", "notifiche")

        @dbus.service.method(nome, in_signature="", out_signature="")
        def MostraBarra(self):
            backend.emetti("mostra", "barra")

        @dbus.service.method(nome, in_signature="", out_signature="")
        def Nascondi(self):
            backend.emetti("mostra", "")

        @dbus.service.method(nome, in_signature="i", out_signature="")
        def Volume(self, passo):
            v = audio.cambia_volume(int(passo))
            backend.emetti("osd", {"tipo": "volume", "valore": v["volume"], "muto": v["muto"]})

        @dbus.service.method(nome, in_signature="", out_signature="")
        def Muto(self):
            v = audio.imposta_muto(None)
            backend.emetti("osd", {"tipo": "volume", "valore": v["volume"], "muto": v["muto"]})

        @dbus.service.method(nome, in_signature="i", out_signature="")
        def Luminosita(self, passo):
            valore = schermo.cambia_luminosita(int(passo))
            if valore is not None:
                backend.emetti("osd", {"tipo": "luminosita", "valore": valore, "muto": False})

        @dbus.service.method(nome, in_signature="b", out_signature="")
        def NonDisturbare(self, attivo):
            backend.nonDisturbare(bool(attivo))
            backend.emetti("stato", None)

        @dbus.service.method(nome, in_signature="as", out_signature="")
        def FiltroApp(self, app):
            if backend.server:
                backend.server.app_consentite = [str(a) for a in app]

    return ServizioShell()


def main() -> int:
    prepara_ambiente(layer_shell=True)
    app = crea_app("shell")
    app.setQuitOnLastWindowClosed(False)
    inizializza()
    bus = dbus.SessionBus()

    backend = BackendShell()
    ponte = crea_ponte(backend)
    try:
        backend.server = ServerNotifiche(bus, backend.emetti)
    except dbus.exceptions.NameExistsException:
        print(T("Un altro server di notifiche è già attivo: le notifiche non saranno gestite dalla shell."),
              file=sys.stderr)
    try:
        servizio = crea_servizio_shell(bus, backend)
    except dbus.exceptions.NameExistsException:
        print(T("La shell è già in esecuzione."), file=sys.stderr)
        return 0

    from .automount import avvia_automount

    automount = avvia_automount()  # noqa: F841 — deve restare vivo
    schermo.ripristina_configurazione_schermi()
    motore = carica(app, "Shell/Shell.qml", {"shell": ponte})
    codice = app.exec()
    del motore, servizio
    return codice


if __name__ == "__main__":
    sys.exit(main())
