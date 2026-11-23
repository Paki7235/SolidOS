"""Pannelli: Wi-Fi e rete, Bluetooth, Condivisione Vicina."""

from __future__ import annotations

import os
from pathlib import Path

from .. import branding
from ..dbusutil import chiama
from ..hw import bluetooth, rete
from ..i18n import T
from ..sistema import cartella_utente, config_utente, leggi_json, scrivi_json
from .base import (Pannello, azione, campo, elenco, esito, info, interruttore, intestazione,
                   scelta)


def _forza(segnale: int) -> str:
    """Tacche e parole: si capisce subito se si è vicini o lontani dal modem."""
    if segnale >= 75:
        return "▂▄▆█  " + T("Segnale ottimo ({s}%) · vicino al modem", s=segnale)
    if segnale >= 50:
        return "▂▄▆_  " + T("Segnale buono ({s}%)", s=segnale)
    if segnale >= 25:
        return "▂▄__  " + T("Segnale debole ({s}%) · lontano dal modem", s=segnale)
    return "▂___  " + T("Segnale molto debole ({s}%) · troppo lontano dal modem", s=segnale)


class PannelloRete(Pannello):
    id = "rete"
    titolo = T("Wi-Fi e rete")
    icona = "network-wireless"
    gruppo = T("Connessioni")
    chiavi = "wifi wlan internet ethernet vpn proxy hotspot rete wireless"

    def voci(self):
        wifi = rete.wifi_attivo()
        reti = rete.reti_wifi() if wifi else []
        if wifi and not reti:
            reti = rete.reti_wifi(scansiona=True)    # elenco vuoto: si cerca davvero prima di dirlo
        elementi_reti = [{
            "id": r["ssid"], "titolo": r["ssid"],
            "sottotitolo": (T("Connessa") if r["connessa"] else "") + (" · " if r["connessa"] else "")
                           + _forza(r["segnale"]) + (" · " + T("protetta") if r["protetta"] else ""),
            "icona": "network-wireless-signal-" + ("excellent" if r["segnale"] > 75 else "good" if r["segnale"] > 50 else "ok" if r["segnale"] > 25 else "weak"),
            "attivo": r["connessa"],
            "azioni": [{"id": "disconnetti", "testo": T("Disconnetti")}] if r["connessa"] else
                      [{"id": "connetti", "testo": T("Connetti"),
                        "richiede": [{"id": "password", "etichetta": T("Password"), "segreto": True}] if r["protetta"] else []}],
        } for r in reti]
        vpn = [{"id": c["uuid"], "titolo": c["nome"], "sottotitolo": T("Attiva") if c["attiva"] else T("Non attiva"),
                "icona": "network-vpn", "attivo": c["attiva"],
                "azioni": [{"id": "disattiva" if c["attiva"] else "attiva",
                            "testo": T("Disattiva") if c["attiva"] else T("Attiva")}]} for c in rete.vpn()]
        cablate = [d for d in rete.dispositivi() if d["tipo"] == "ethernet"]
        hotspot = rete.dati_hotspot()
        voci = [
            interruttore("wifi", T("Wi-Fi"), wifi, chiavi="wireless wlan"),
            azione("aggiorna", T("Cerca reti"), T("Aggiorna"), chiavi="scansione"),
            elenco("reti", T("Reti disponibili"), elementi_reti,
                   vuoto=T("Nessuna rete trovata") if wifi else T("Il Wi-Fi è spento")),
            intestazione(T("Rete cablata")),
            *[info("eth-" + d["nome"], d["nome"], T("Connessa") if d["stato"] == "connected" else T("Scollegata"))
              for d in cablate],
            intestazione(T("VPN")),
            elenco("vpn", T("Connessioni VPN"), vpn, vuoto=T("Nessuna VPN configurata")),
            azione("importa-vpn", T("Aggiungi VPN da file"), T("Scegli file…"),
                   T("File OpenVPN (.ovpn) o WireGuard (.conf)"), file=True, chiavi="openvpn wireguard"),
            intestazione(T("Hotspot")),
            interruttore("hotspot", T("Condividi la connessione (hotspot)"), bool(hotspot),
                         T("Rete: {s} · Password: {p}", s=hotspot.get("ssid", ""), p=hotspot.get("password", ""))
                         if hotspot else T("Crea una rete Wi-Fi a cui collegare telefoni e altri dispositivi"),
                         abilitata=rete.supporta_hotspot(), chiavi="tethering punto di accesso"),
            intestazione(T("Proxy")),
            campo("proxy", T("Proxy HTTP/HTTPS"), self._proxy(), T("Esempio: http://proxy.azienda.it:8080 — vale dal prossimo accesso")),
        ]
        return voci

    def _file_proxy(self) -> Path:
        cartella = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "environment.d"
        cartella.mkdir(parents=True, exist_ok=True)
        return cartella / "50-proxy.conf"

    def _proxy(self) -> str:
        f = self._file_proxy()
        if f.exists():
            for r in f.read_text().splitlines():
                if r.startswith("http_proxy="):
                    return r.split("=", 1)[1]
        return ""

    def imposta(self, voce, valore):
        if voce == "wifi":
            return esito(rete.imposta_wifi(bool(valore)))
        if voce == "hotspot":
            r = rete.hotspot(bool(valore))
            return esito(r["ok"], r.get("messaggio", ""))
        if voce == "proxy":
            v = str(valore).strip()
            f = self._file_proxy()
            if v:
                f.write_text("".join(f"{k}={v}\n" for k in ("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY")))
            else:
                f.unlink(missing_ok=True)
            return esito(True, T("Il proxy sarà usato dal prossimo accesso"))
        return None

    def azione(self, voce, elemento, az, dati):
        if voce == "aggiorna":
            rete.reti_wifi(scansiona=True)
            return esito()
        if voce == "reti" and az == "connetti":
            r = rete.connetti_wifi(elemento, dati.get("password", ""))
            return esito(r["ok"], T("Connesso a {r}", r=elemento) if r["ok"] else r["messaggio"])
        if voce == "reti" and az == "disconnetti":
            return esito(rete.disconnetti_wifi())
        if voce == "vpn":
            return esito(rete.attiva_connessione(elemento, az == "attiva"))
        if voce == "importa-vpn":
            r = rete.importa_vpn(dati.get("file", ""))
            return esito(r["ok"], r["messaggio"])
        return None


class PannelloBluetooth(Pannello):
    id = "bluetooth"
    titolo = T("Bluetooth")
    icona = "bluetooth"
    gruppo = T("Connessioni")
    chiavi = "cuffie auricolari mouse tastiera associa"

    def voci(self):
        if not bluetooth.disponibile():
            return [info("assente", T("Bluetooth"), T("Nessun adattatore Bluetooth trovato"))]
        acceso = bluetooth.attivo()
        elementi = []
        for d in bluetooth.dispositivi() if acceso else []:
            azioni = []
            if d["associato"]:
                azioni.append({"id": "disconnetti" if d["connesso"] else "connetti",
                               "testo": T("Disconnetti") if d["connesso"] else T("Connetti")})
                azioni.append({"id": "rimuovi", "testo": T("Dimentica"), "pericolosa": True})
            else:
                azioni.append({"id": "associa", "testo": T("Associa")})
            elementi.append({"id": d["indirizzo"], "titolo": d["nome"],
                             "sottotitolo": T("Connesso") if d["connesso"] else (T("Associato") if d["associato"] else T("Disponibile")),
                             "icona": "bluetooth", "attivo": d["connesso"], "azioni": azioni})
        return [
            interruttore("acceso", T("Bluetooth"), acceso),
            azione("cerca", T("Cerca nuovi dispositivi"), T("Cerca"), T("Metti il dispositivo in modalità associazione")),
            elenco("dispositivi", T("Dispositivi"), elementi, vuoto=T("Nessun dispositivo")),
        ]

    def imposta(self, voce, valore):
        if voce == "acceso":
            return esito(bluetooth.imposta(bool(valore)))
        return None

    def azione(self, voce, elemento, az, dati):
        if voce == "cerca":
            bluetooth.cerca(10)
            return esito()
        if voce == "dispositivi":
            funzioni = {"associa": bluetooth.associa, "connetti": bluetooth.connetti,
                        "disconnetti": lambda m: bluetooth.connetti(m, False), "rimuovi": bluetooth.rimuovi}
            ok = funzioni[az](elemento)
            return esito(ok, "" if ok else T("Operazione non riuscita"))
        return None


class PannelloCondivisione(Pannello):
    id = "condivisione"
    titolo = T("Condivisione Vicina")
    icona = "document-send"
    gruppo = T("Connessioni")
    chiavi = "quick share nearby localsend qr telefono iphone android invia ricevi"

    def _servizio(self, metodo, *argomenti):
        nome = branding.nome_dbus("Condivisione1")
        return chiama(nome, branding.percorso_dbus("Condivisione1"), nome, metodo, *argomenti, timeout=5)

    def voci(self):
        conf = leggi_json(config_utente("condivisione.json"), {})
        import json

        grezzo = self._servizio("StatoBackend")
        try:
            stato = json.loads(str(grezzo)) if grezzo else {}
        except ValueError:
            stato = {}
        visibilita = conf.get("visibilita", "nessuno")
        voci = [
            scelta("visibilita", T("Chi può vedere questo computer"), visibilita, [
                ("nessuno", T("Nessuno")), ("associati", T("Solo dispositivi associati")),
                ("tutti10", T("Tutti per 10 minuti")), ("tutti", T("Tutti (sempre)"))]),
            campo("nome", T("Nome del dispositivo"), conf.get("nome", ""),
                  T("Come appare sui telefoni. Vuoto = nome predefinito")),
            info("cartella", T("Cartella dei file ricevuti"),
                 conf.get("cartella", str(cartella_utente("DOWNLOAD", "Scaricati") / T("Ricevuti")))),
            azione("scegli-cartella", T("Cambia cartella"), T("Scegli…"), file=True),
            intestazione(T("Compatibilità")),
        ]
        nomi = {"quickshare": T("Telefoni con Quick Share"), "localsend": T("App LocalSend (telefoni e computer)"), "qr": T("Qualsiasi telefono con codice QR")}
        for chiave in ("quickshare", "localsend", "qr"):
            disponibile, motivo = stato.get(chiave, (False, T("Servizio non avviato")))
            voci.append(info("stato-" + chiave, nomi[chiave], (T("pronto") + " · " if disponibile else T("non disponibile") + " · ") + str(motivo)))
        voci.append(azione("registro", T("Registro dei trasferimenti"), T("Apri"),
                           T("Nel pannello Privacy trovi tutti i file inviati e ricevuti")))
        return voci

    def _salva(self, chiave, valore):
        file = config_utente("condivisione.json")
        conf = leggi_json(file, {})
        conf[chiave] = valore
        scrivi_json(file, conf)
        self._servizio("RicaricaConfigurazione")

    def imposta(self, voce, valore):
        if voce == "visibilita":
            self._servizio("ImpostaVisibilita", str(valore))
            self._salva("visibilita", str(valore))
            return esito()
        if voce == "nome":
            self._salva("nome", str(valore).strip())
            return esito()
        if voce == "stabili":
            self._salva("preferisci_stabili", bool(valore))
            return esito()
        return None

    def azione(self, voce, elemento, az, dati):
        if voce == "scegli-cartella" and dati.get("file"):
            cartella = Path(dati["file"])
            self._salva("cartella", str(cartella if cartella.is_dir() else cartella.parent))
            return esito()
        if voce == "registro":
            from ..sistema import avvia

            avvia([branding.comando("impostazioni"), "privacy"])
            return esito(ricarica=False)
        return None
