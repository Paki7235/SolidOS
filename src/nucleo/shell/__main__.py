"""Processo della shell: un solo motore QML per notifiche, centro di controllo,
centro notifiche e OSD (finestre Wayland layer-shell).

Servizio D-Bus org.<OS_ID>.Shell (sessione) usato da scorciatoie e altre app:
    MostraControllo()  MostraNotifiche()  MostraBarra()  MostraPrestazioni()  Nascondi()
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
        self.finestre = None

    # ── Stato per il centro di controllo ────────────────────────────────────
    def stato(self) -> dict:
        r = rete.stato_breve()
        vol = audio.volume()
        self._muto = vol["muto"]
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

    # ── Stato leggero per la barra in alto (solo file di sistema, pochi ms) ──
    def statoBarra(self) -> dict:
        from pathlib import Path

        connesso, tipo = False, ""
        for iface in Path("/sys/class/net").iterdir():
            if iface.name == "lo":
                continue
            try:
                su = (iface / "operstate").read_text().strip() == "up"
            except OSError:
                continue
            if su:
                connesso = True
                tipo = "wifi" if (iface / "wireless").exists() else (tipo or "ethernet")
        # forza del segnale Wi-Fi (qualità del collegamento, 0-70 in /proc/net/wireless)
        segnale = 0
        try:
            for riga in Path("/proc/net/wireless").read_text().splitlines()[2:]:
                campi = riga.split()
                if len(campi) > 2:
                    segnale = max(segnale, min(100, round(float(campi[2].rstrip(".")) * 100 / 70)))
        except (OSError, ValueError):
            pass
        return {"connesso": connesso, "reteTipo": tipo, "segnale": segnale, "batteria": energia.batteria() or {},
                "muto": getattr(self, "_muto", False)}

    # ── Indicatore delle prestazioni (Super+P) ───────────────────────────────
    def prestazioni(self) -> dict:
        import time

        import psutil

        ora = time.monotonic()
        disco, net = psutil.disk_io_counters(), psutil.net_io_counters()
        prec = getattr(self, "_prec_prestazioni", None)
        self._prec_prestazioni = (ora, disco, net)
        dt = max(ora - prec[0], 0.5) if prec else 1.0
        mb = 1048576
        disco_s = ((disco.read_bytes + disco.write_bytes) - (prec[1].read_bytes + prec[1].write_bytes)) / dt / mb if prec and disco and prec[1] else 0
        rete_s = ((net.bytes_recv + net.bytes_sent) - (prec[2].bytes_recv + prec[2].bytes_sent)) / dt / mb if prec else 0
        temperatura = None
        try:
            for voci in (psutil.sensors_temperatures() or {}).values():
                valori = [v.current for v in voci if v.current]
                if valori:
                    temperatura = max(temperatura or 0, max(valori))
        except (AttributeError, OSError):
            pass
        mem = psutil.virtual_memory()
        return {
            "cpu": psutil.cpu_percent(),
            "memoriaUsata": round((mem.total - mem.available) / 1073741824, 1),
            "memoriaTotale": round(mem.total / 1073741824, 1),
            "memoriaPercento": mem.percent,
            "swap": round(psutil.swap_memory().used / 1048576),
            "disco": round(max(disco_s, 0), 1),
            "rete": round(max(rete_s, 0), 2),
            "temperatura": round(temperatura) if temperatura else -1,
        }

    # ── Dock e finestre ──────────────────────────────────────────────────────
    def dock(self) -> list:
        from . import dock

        return dock.voci(self.finestre.elenco() if self.finestre else [])

    # ── Scrivania e sfondo ──────────────────────────────────────────────────
    def sfondo(self) -> str:
        from ..sistema import sfondo_attuale

        return "file://" + sfondo_attuale()

    def mostraStart(self) -> None:
        self.emetti("mostra", "start")

    # ── Scrivania ───────────────────────────────────────────────────────────
    def scrivania(self) -> list:
        from . import scrivania

        return scrivania.elementi()

    def scrivaniaImpostazioni(self) -> dict:
        from . import scrivania

        return scrivania.impostazioni()

    def scrivaniaSalva(self, cambi) -> dict:
        from . import scrivania

        conf = scrivania.salva_impostazioni(dict(cambi))
        if "mostra" in cambi or "sistema" in cambi:
            self.emetti("scrivania", None)
        return conf

    def scrivaniaCartella(self) -> str:
        from . import scrivania

        return str(scrivania.cartella())

    def scrivaniaApri(self, percorso: str) -> None:
        from . import scrivania

        scrivania.apri(percorso)

    def scrivaniaNuova(self, tipo: str) -> str:
        from . import scrivania

        return scrivania.nuova_cartella() if tipo == "cartella" else scrivania.nuovo_testo()

    def scrivaniaRinomina(self, percorso: str, nuovo: str) -> bool:
        from . import scrivania

        return scrivania.rinomina(percorso, nuovo)

    def scrivaniaCestino(self, percorsi) -> int:
        from . import scrivania

        elenco = [percorsi] if isinstance(percorsi, str) else list(percorsi)
        return sum(1 for p in elenco if scrivania.cestino(str(p)))

    def scrivaniaCollegamento(self, desktop: str) -> bool:
        from . import scrivania

        return scrivania.aggiungi_collegamento(desktop)

    def scrivaniaTrasferisci(self, indirizzi, cartella: str, modo: str = "auto") -> dict:
        """File trascinati o incollati sulla scrivania (o su una sua cartella)."""
        from .. import trasferimenti
        from . import scrivania

        return trasferimenti.trasferisci([str(i) for i in indirizzi], cartella or str(scrivania.cartella()), modo)

    def scrivaniaCopia(self, indirizzi) -> int:      # compatibilità
        return self.scrivaniaTrasferisci(indirizzi, "", "copia").get("fatti", 0)

    # Appunti di sistema (gli stessi dell'app File)
    def appuntiCopia(self, percorsi, taglia: bool = False) -> bool:
        from .. import appunti

        return appunti.copia([str(p) for p in percorsi], bool(taglia))

    def appunti(self) -> dict:
        from .. import appunti

        return appunti.leggi()

    def appuntiSvuota(self) -> None:
        from .. import appunti

        appunti.svuota()

    def scrivaniaAzione(self, azione: str, percorsi) -> None:
        """Voci del menu delle icone: Apri con, Mostra in File, Proprietà, PDF, zip, Condividi, Terminale."""
        from . import scrivania

        p = [str(x) for x in percorsi]
        if not p:
            return
        c = branding.comando
        if azione == "apricon":
            avvia([c("apri-con"), p[0]])
        elif azione == "mostra":
            avvia([c("file"), p[0]])          # File apre la cartella che contiene il file
        elif azione == "proprieta":
            avvia([c("file"), "--proprieta", p[0]])
        elif azione == "pdf":
            avvia(["/usr/libexec/nucleo/converti-pdf", *p])
        elif azione == "comprimi":
            avvia([c("archivi"), "--comprimi", *p])
        elif azione == "estrai":
            avvia([c("archivi"), "--estrai", *p])
        elif azione == "condividi":
            avvia([c("condividi"), *p])
        elif azione == "terminale":
            avvia(["qterminal", "-w", p[0]])
        elif azione == "cartella":
            avvia([c("file"), str(scrivania.cartella())])

    # ── Cestino (fisso in fondo al Dock / alla barra) ───────────────────────
    def cestinoPieno(self) -> bool:
        from gi.repository import Gio, GLib

        try:
            info = Gio.File.new_for_uri("trash:///").query_info("trash::item-count", Gio.FileQueryInfoFlags.NONE, None)
            return info.get_attribute_uint32("trash::item-count") > 0
        except GLib.Error:
            return False

    def cestinoApri(self) -> None:
        avvia([branding.comando("file"), "trash:///"])

    def cestinoSvuota(self) -> None:
        # chiede conferma nella finestra del Cestino (si può annullare)
        avvia([branding.comando("file"), "trash:///", "--svuota-cestino"])

    def cestinoSposta(self, indirizzi) -> int:
        from gi.repository import Gio, GLib

        n = 0
        for indirizzo in indirizzi:
            try:
                Gio.File.new_for_uri(str(indirizzo)).trash(None)
                n += 1
            except GLib.Error:
                pass
        self.emetti("cestino", None)
        return n

    def tutteLeApp(self) -> list:
        from . import dock

        return dock.tutte_le_app()

    def dockApri(self, desktop: str) -> bool:
        from ..sistema import avvia_desktop

        return avvia_desktop(desktop)

    def dockClic(self, desktop: str) -> str:
        """Clic su un'icona: apre l'app, oppure attiva/riduce la sua finestra."""
        from . import dock

        voce = next((v for v in dock.voci(self.finestre.elenco() if self.finestre else []) if v["id"] == desktop), None)
        if voce and voce["finestre"] and self.finestre:
            finestre = voce["finestre"]
            attiva = next((f for f in finestre if f["attiva"] and not f["minimizzata"]), None)
            if attiva:
                self.finestre.minimizza(attiva["id"])
                return "ridotta"
            self.finestre.attiva(finestre[-1]["id"])
            return "attivata"
        self.dockApri(desktop)
        return "avviata"

    def dockChiudi(self, desktop: str) -> None:
        from . import dock

        for v in dock.voci(self.finestre.elenco() if self.finestre else []):
            if v["id"] == desktop:
                for f in v["finestre"]:
                    self.finestre.chiudi(f["id"])

    def dockFissa(self, desktop: str, si: bool) -> None:
        from . import dock

        dock.fissa(desktop, bool(si))
        self.emetti("finestre", None)

    def finestraAttiva(self) -> dict:
        """App in primo piano, per il nome nella barra in alto."""
        from . import dock

        if not self.finestre:
            return {}
        for f in self.finestre.elenco():
            if f["attiva"] and not f["minimizzata"]:
                d = dock.desktop_per_app_id(f["appId"])
                dati = dock.info(d) if d else None
                return {"nome": (dati or {}).get("nome") or f["titolo"], "titolo": f["titolo"], "id": f["id"],
                        "massimizzata": f.get("massimizzata", False)}
        return {}

    def finestraGrande(self) -> bool:
        """C'è un'app ingrandita o a tutto schermo (non ridotta nel Dock)? Con il Dock
        in stile Mac, in quel caso il Dock si nasconde e riappare portando il mouse in basso."""
        if not self.finestre:
            return False
        return any((f.get("massimizzata") or f.get("schermoIntero")) and not f.get("minimizzata")
                   for f in self.finestre.elenco())

    def appAttiva(self, azione: str) -> bool:
        """Comandi del menu dell'app (barra in alto) e delle scorciatoie tipo Mac:
        nascondi · ingrandisci · chiudi (finestra) · esci (tutte le finestre dell'app)."""
        if not self.finestre:
            return False
        f = self.finestre.attiva_corrente()
        if not f and azione != "scrivania":
            return False
        if azione == "nascondi":
            return self.finestre.minimizza(f["id"])
        if azione == "ingrandisci":
            return self.finestre.massimizza(f["id"])
        if azione == "chiudi":
            return self.finestre.chiudi(f["id"])
        if azione == "esci":
            for altra in self.finestre.elenco():
                if altra["appId"] == f["appId"]:
                    self.finestre.chiudi(altra["id"])
            return True
        if azione == "scrivania":
            # Super+D come su Windows: riduce tutto; la seconda volta rimette com'era
            aperte = [x for x in self.finestre.elenco() if not x["minimizzata"]]
            if aperte:
                self._scrivania = [x["id"] for x in aperte]
                for x in aperte:
                    self.finestre.minimizza(x["id"])
            else:
                for ident in getattr(self, "_scrivania", []):
                    self.finestre.attiva(ident)
                self._scrivania = []
            return True
        if azione == "nascondiAltre":
            for altra in self.finestre.elenco():
                if altra["appId"] != f["appId"] and not altra["minimizzata"]:
                    self.finestre.minimizza(altra["id"])
            return True
        return False

    def chiudiFinestra(self, ident: int) -> None:
        if self.finestre:
            self.finestre.chiudi(int(ident))

    def _visibilita(self) -> str:
        # Se il servizio non è in esecuzione non lo si avvia solo per leggerne lo stato
        try:
            if not dbus.SessionBus().name_has_owner(branding.nome_dbus("Condivisione1")):
                return "nessuno"
        except dbus.exceptions.DBusException:
            return "nessuno"
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
        from ..sistema import config_utente, scrivi_json

        if self.server:
            self.server.non_disturbare = bool(attivo)
        scrivi_json(config_utente("notifiche.json"), {"non_disturbare": bool(attivo)})
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

        @dbus.service.method(nome, in_signature="", out_signature="b")
        def MostraBarra(self):
            backend.emetti("mostra", "barra")
            return True   # risposta esplicita: chi chiama sa che la shell ha mostrato la barra

        @dbus.service.method(nome, in_signature="s", out_signature="b")
        def AppAttiva(self, azione):
            return bool(backend.appAttiva(str(azione)))

        @dbus.service.method(nome, in_signature="s", out_signature="b")
        def ApriApp(self, desktop):
            """Apre un'app come farebbe un clic sul dock (usato anche dalla prova automatica)."""
            return bool(backend.dockApri(str(desktop)))

        @dbus.service.method(nome, in_signature="", out_signature="")
        def Aggiorna(self):
            backend.emetti("finestre", None)

        @dbus.service.method(nome, in_signature="", out_signature="")
        def AggiornaSfondo(self):
            backend.emetti("sfondo", None)

        @dbus.service.method(nome, in_signature="", out_signature="")
        def MostraStart(self):
            backend.emetti("mostra", "start")

        @dbus.service.method(nome, in_signature="", out_signature="")
        def MostraPrestazioni(self):
            backend.emetti("prestazioni", None)

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
        from ..sistema import config_utente, leggi_json

        backend.server.non_disturbare = bool(leggi_json(config_utente("notifiche.json"), {}).get("non_disturbare", False))
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
    from .finestre import Finestre

    def al_cambio(elenco):
        backend.emetti("finestre", None)
        try:   # diagnosi: l'elenco delle finestre per la prova automatica
            import json
            from pathlib import Path

            stato = Path.home() / ".local/state" / branding.id_os() / "finestre.json"
            stato.write_text(json.dumps(elenco, ensure_ascii=False))
        except OSError:
            pass

    backend.finestre = Finestre(al_cambio)

    # La scrivania si aggiorna quando cambia il contenuto della cartella
    from PyQt6.QtCore import QFileSystemWatcher

    from . import scrivania

    # Il Cestino nel Dock cambia icona quando si riempie o si svuota
    try:
        import gi

        gi.require_version("Gio", "2.0")
        from gi.repository import Gio

        monitor_cestino = Gio.File.new_for_uri("trash:///").monitor_directory(Gio.FileMonitorFlags.NONE, None)
        monitor_cestino.connect("changed", lambda *_a: backend.emetti("cestino", None))
        backend._monitor_cestino = monitor_cestino
    except Exception as e:  # noqa: BLE001 — senza gvfs il cestino si aggiorna comunque col Dock
        print("cestino:", e, file=sys.stderr)

    osservatore = QFileSystemWatcher([str(scrivania.cartella())])
    osservatore.directoryChanged.connect(lambda _p: backend.emetti("scrivania", None))
    backend._osservatore = osservatore
    motore = carica(app, "Shell/Shell.qml", {"shell": ponte})
    codice = app.exec()
    del motore, servizio
    return codice


if __name__ == "__main__":
    sys.exit(main())
