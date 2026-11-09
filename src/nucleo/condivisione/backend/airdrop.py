"""Compatibilità con AirDrop (iPhone, iPad, Mac) — BETA.

Componenti:
- OWL (seemoo-lab, GPL-3.0): implementa il collegamento Wi-Fi AWDL e crea l'interfaccia awdl0;
- questo modulo: protocollo AirDrop su HTTPS sopra awdl0 (/Discover, /Ask, /Upload),
  ispirato a OpenDrop (seemoo-lab, GPL-3.0);
- annuncio BLE Apple per «svegliare» gli iPhone vicini (ble.py).

Requisiti: scheda Wi-Fi con modalità monitor e iniezione di pacchetti, Bluetooth LE.
Funziona solo con iPhone/Mac impostati su «Tutti per 10 minuti».
"""

import asyncio
import gzip
import io
import json
import logging
import os
import plistlib
import secrets
import shutil
import socket
import ssl
import subprocess
import tempfile
import time
from pathlib import Path

from ...i18n import T
from ...sistema import config_utente, esegui, uscita
from .. import PORTA_AIRDROP
from ..modelli import Dispositivo, FileInArrivo, Trasferimento
from ..sicurezza import nome_sicuro, percorso_libero
from .base import Backend

log = logging.getLogger("condivisione.airdrop")
TIPO_SERVIZIO = "_airdrop._tcp.local."
OWL = [Path("/usr/local/bin/owl"), Path("/usr/bin/owl")]
AWDL_SCRIPT = "/usr/libexec/nucleo/airdrop-awdl"

# Driver verificati per modalità monitor + iniezione (lista da ampliare con i test su hardware reale)
DRIVER_VERIFICATI = {"ath9k", "ath9k_htc", "mt76x2u", "mt76x0u", "mt7921u", "rt2800usb", "ath10k_pci", "mt7612u"}


# ── Rilevamento dei requisiti ─────────────────────────────────────────────────
def schede_wifi() -> list[dict]:
    schede = []
    for riga in uscita(["iw", "dev"]).splitlines():
        riga = riga.strip()
        if riga.startswith("Interface "):
            nome = riga.split()[1]
            if nome == "awdl0":
                continue
            driver_link = Path(f"/sys/class/net/{nome}/device/driver")
            driver = driver_link.resolve().name if driver_link.exists() else ""
            fisico = Path(f"/sys/class/net/{nome}/phy80211/name")
            phy = fisico.read_text().strip() if fisico.exists() else ""
            info_phy = uscita(["iw", "phy", phy, "info"]) if phy else ""
            modi = info_phy.split("Supported interface modes:")[1].split("Band")[0] if "Supported interface modes:" in info_phy else ""
            connessa = "connected" in uscita(["nmcli", "-t", "-f", "DEVICE,STATE", "device"]).split(f"{nome}:")[-1].split("\n")[0]
            schede.append({"nome": nome, "driver": driver, "monitor": "monitor" in modi,
                           "cinqueGhz": "5180 MHz" in info_phy, "connessa": connessa,
                           "verificata": driver in DRIVER_VERIFICATI})
    return schede


def bluetooth_presente() -> bool:
    return "Controller" in uscita(["bluetoothctl", "list"], timeout=5)


def scegli_scheda() -> tuple[dict | None, str]:
    """Restituisce (scheda, avviso). Preferisce una scheda secondaria non connessa."""
    candidate = [s for s in schede_wifi() if s["monitor"]]
    if not candidate:
        return None, ""
    candidate.sort(key=lambda s: (s["connessa"], not s["verificata"]))
    scelta = candidate[0]
    avviso = T("Mentre AirDrop è attivo il Wi-Fi verrà scollegato. Consigliata una chiavetta Wi-Fi USB.") if scelta["connessa"] else ""
    return scelta, avviso


# ── CPIO (formato odc) ────────────────────────────────────────────────────────
def crea_cpio(file: list[Path]) -> bytes:
    out = io.BytesIO()

    def voce(nome: str, dati: bytes, modo: int):
        nome_b = nome.encode("utf-8") + b"\0"
        out.write(b"070707" + b"%06o%06o%06o%06o%06o%06o%06o%011o%06o%011o" % (
            0, 0, modo, 0, 0, 1, 0, int(time.time()), len(nome_b), len(dati)))
        out.write(nome_b)
        out.write(dati)

    for p in file:
        voce(f"./{p.name}", p.read_bytes(), 0o100644)
    voce("TRAILER!!!", b"", 0)
    return gzip.compress(out.getvalue())


def estrai_archivio(dati: bytes, destinazione: Path) -> list[Path]:
    """Estrae l'archivio inviato dall'iPhone (cpio, di solito compresso) in modo sicuro."""
    import libarchive

    estratti = []
    with tempfile.TemporaryDirectory() as tmp:
        with libarchive.memory_reader(dati) as archivio:
            for voce in archivio:
                if not voce.isfile:
                    continue
                nome = nome_sicuro(voce.pathname)
                temporaneo = Path(tmp) / secrets.token_hex(8)
                with open(temporaneo, "wb") as f:
                    for blocco in voce.get_blocks():
                        f.write(blocco)
                finale = percorso_libero(destinazione, nome)
                shutil.move(str(temporaneo), finale)
                estratti.append(finale)
    return estratti


# ── Backend ───────────────────────────────────────────────────────────────────
class BackendAirDrop(Backend):
    nome = "airdrop"
    stabile = False

    def __init__(self, gestore):
        super().__init__(gestore)
        self.id = config_utente("airdrop-id").read_text().strip() if config_utente("airdrop-id").exists() else ""
        if not self.id:
            self.id = secrets.token_hex(6)
            config_utente("airdrop-id").write_text(self.id)
        self.attivo = False
        self.runner = None
        self.zeroconf = None
        self.registrazione = None
        self.browser = None
        self.ble = None
        self.scheda = None
        self._spegnimento: asyncio.TimerHandle | None = None

    def disponibile(self):
        if not any(p.exists() for p in OWL):
            return False, T("Componente AWDL (OWL) non installato")
        scheda, avviso = scegli_scheda()
        if not scheda:
            nomi = ", ".join(f'{s["nome"]} ({s["driver"] or "?"})' for s in schede_wifi()) or T("nessuna")
            return False, T("La scheda Wi-Fi ({n}) non supporta i requisiti di AirDrop (modalità monitor e iniezione). "
                            "Puoi scambiare file con iPhone usando l'app gratuita LocalSend oppure il codice QR.", n=nomi)
        if not bluetooth_presente():
            return False, T("Serve il Bluetooth per farsi trovare dagli iPhone. In alternativa usa LocalSend o il codice QR.")
        stato = T("BETA: disponibile con la scheda {s} ({d})", s=scheda["nome"], d=scheda["driver"])
        if not scheda["verificata"]:
            stato += " — " + T("scheda non ancora verificata")
        return True, stato + (". " + avviso if avviso else "")

    # ── Attivazione su richiesta (risparmio energia) ────────────────────────
    async def _accendi(self, durata: int = 600):
        if self._spegnimento:
            self._spegnimento.cancel()
        self._spegnimento = asyncio.get_running_loop().call_later(durata, lambda: asyncio.ensure_future(self._spegni()))
        if self.attivo:
            return True
        self.scheda, _ = scegli_scheda()
        if not self.scheda:
            return False
        r = await asyncio.to_thread(esegui, ["pkexec", AWDL_SCRIPT, "avvia", self.scheda["nome"],
                                             "149" if self.scheda["cinqueGhz"] else "6"], 60)
        if r.returncode != 0:
            log.warning("AWDL non avviato: %s", r.stderr)
            return False
        for _ in range(30):
            if Path("/sys/class/net/awdl0").exists():
                break
            await asyncio.sleep(0.5)
        else:
            return False
        await self._avvia_server()
        from .ble import AnnuncioBLE

        self.ble = AnnuncioBLE.airdrop()
        await self.ble.avvia()
        self.attivo = True
        return True

    async def _spegni(self):
        if not self.attivo:
            return
        if self.ble:
            await self.ble.ferma()
        if self.browser:
            await self.browser.async_cancel()
            self.browser = None
        if self.registrazione and self.zeroconf:
            await self.zeroconf.async_unregister_service(self.registrazione)
        if self.zeroconf:
            await self.zeroconf.async_close()
            self.zeroconf = None
        if self.runner:
            await self.runner.cleanup()
            self.runner = None
        await asyncio.to_thread(esegui, ["pkexec", AWDL_SCRIPT, "ferma"], 30)
        self.attivo = False

    async def ferma(self):
        await self._spegni()

    async def visibilita(self, modalita):
        if modalita in ("tutti10", "tutti"):
            await self._accendi(600)
        elif self.attivo:
            await self._spegni()

    async def scopri(self, secondi=15):
        if await self._accendi(max(secondi, 120)):
            await self._sfoglia()

    def _indirizzo_awdl(self) -> tuple[str, int]:
        for riga in uscita(["ip", "-6", "addr", "show", "dev", "awdl0"]).splitlines():
            riga = riga.strip()
            if riga.startswith("inet6 fe80"):
                return riga.split()[1].split("/")[0], socket.if_nametoindex("awdl0")
        return "", 0

    def _contesto_ssl(self) -> ssl.SSLContext:
        from .localsend import _certificato

        cert, chiave, _ = _certificato()
        contesto = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
        contesto.load_cert_chain(cert, chiave)
        contesto.verify_mode = ssl.CERT_NONE
        return contesto

    async def _avvia_server(self):
        from aiohttp import web
        from zeroconf import IPVersion, ServiceInfo
        from zeroconf.asyncio import AsyncZeroconf

        ip, indice = self._indirizzo_awdl()
        if not ip:
            raise RuntimeError("awdl0 senza indirizzo IPv6")
        app = web.Application(client_max_size=1024 ** 4)
        app.router.add_post("/Discover", self._discover)
        app.router.add_post("/Ask", self._ask)
        app.router.add_post("/Upload", self._upload)
        self.runner = web.AppRunner(app, access_log=None)
        await self.runner.setup()
        await web.TCPSite(self.runner, f"{ip}%awdl0", PORTA_AIRDROP, ssl_context=self._contesto_ssl()).start()
        self.zeroconf = AsyncZeroconf(interfaces=[(ip, 0, indice)], ip_version=IPVersion.V6Only)
        self.registrazione = ServiceInfo(TIPO_SERVIZIO, f"{self.id}.{TIPO_SERVIZIO}",
                                         addresses=[socket.inet_pton(socket.AF_INET6, ip)], port=PORTA_AIRDROP,
                                         properties={"flags": "1019"}, server=f"{self.id}.local.")
        await self.zeroconf.async_register_service(self.registrazione)
        self._sessioni: dict[str, Trasferimento] = {}

    # ── Ricezione ───────────────────────────────────────────────────────────
    def _plist(self, dati: dict):
        from aiohttp import web

        return web.Response(body=plistlib.dumps(dati, fmt=plistlib.FMT_BINARY),
                            content_type="application/octet-stream")

    async def _discover(self, richiesta):
        from aiohttp import web

        if self.gestore.visibilita not in ("tutti10", "tutti"):
            raise web.HTTPUnauthorized()
        return self._plist({"ReceiverComputerName": self.gestore.nome_dispositivo, "ReceiverModelName": "Mac",
                            "ReceiverMediaCapabilities": json.dumps({"Version": 1}).encode()})

    async def _ask(self, richiesta):
        from aiohttp import web

        dati = plistlib.loads(await richiesta.read())
        mittente = str(dati.get("SenderComputerName", T("Dispositivo Apple")))
        file = [FileInArrivo(nome=nome_sicuro(str(f.get("FileName", "file"))), dimensione=0)
                for f in dati.get("Files", [])]
        anteprima = ""
        if dati.get("FileIcon"):
            anteprima = str(Path(tempfile.gettempdir()) / f"airdrop-{secrets.token_hex(4)}.jpg")
            Path(anteprima).write_bytes(bytes(dati["FileIcon"]))
        t = Trasferimento(direzione="ricevi", backend="airdrop", dispositivo=mittente, file=file, anteprima=anteprima)
        if not await self.gestore.chiedi_conferma(t, f'airdrop:{dati.get("SenderID", mittente)}'):
            raise web.HTTPForbidden()
        self._sessioni[richiesta.remote] = t
        return self._plist({"ReceiverModelName": "Mac", "ReceiverComputerName": self.gestore.nome_dispositivo})

    async def _upload(self, richiesta):
        from aiohttp import web

        t = self._sessioni.pop(richiesta.remote, None)
        if not t:
            raise web.HTTPForbidden()
        notifica = [0]
        t.stato = "in corso"
        t.totale = int(richiesta.headers.get("Content-Length", 0)) or 1
        dati = bytearray()
        async for blocco in richiesta.content.iter_chunked(256 * 1024):
            dati.extend(blocco)
            t.trasferiti = len(dati)
            await self.gestore.avanzamento(t, notifica)
            if t.annullato:
                await self.gestore.completato(t, notifica, T("Annullato"))
                raise web.HTTPBadRequest()
        try:
            t.percorsi = [str(p) for p in await asyncio.to_thread(estrai_archivio, bytes(dati), self.gestore.cartella)]
        except Exception as e:  # noqa: BLE001
            await self.gestore.completato(t, notifica, T("Archivio non valido: {e}", e=str(e)))
            raise web.HTTPBadRequest()
        await self.gestore.completato(t, notifica)
        return web.Response()

    # ── Invio ───────────────────────────────────────────────────────────────
    async def _sfoglia(self):
        from zeroconf.asyncio import AsyncServiceBrowser

        if self.browser or not self.zeroconf:
            return
        self.browser = AsyncServiceBrowser(self.zeroconf.zeroconf, TIPO_SERVIZIO, handlers=[self._servizio])

    def _servizio(self, zeroconf, service_type, name, state_change):
        from zeroconf import ServiceStateChange

        if state_change is ServiceStateChange.Removed:
            self.gestore.dispositivo_perso(f"airdrop:{name}")
        elif self.registrazione is None or name != self.registrazione.name:
            asyncio.ensure_future(self._risolvi(service_type, name))

    async def _risolvi(self, tipo, nome):
        import aiohttp
        from zeroconf.asyncio import AsyncServiceInfo

        info = AsyncServiceInfo(tipo, nome)
        if not await info.async_request(self.zeroconf.zeroconf, 3000):
            return
        indirizzi = [a for a in info.parsed_scoped_addresses() if ":" in a]
        if not indirizzi:
            return
        ip = indirizzi[0] if "%" in indirizzi[0] else f"{indirizzi[0]}%awdl0"
        url = f"https://[{ip}]:{info.port}/Discover"
        try:
            async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=8)) as s:
                async with s.post(url, data=plistlib.dumps({}, fmt=plistlib.FMT_BINARY), ssl=False,
                                  headers={"Content-Type": "application/octet-stream"}) as r:
                    if r.status != 200:
                        return
                    risposta = plistlib.loads(await r.read())
        except Exception:  # noqa: BLE001 — dispositivo non in modalità «Tutti»
            return
        nome_disp = str(risposta.get("ReceiverComputerName", ""))
        if nome_disp:
            modello = str(risposta.get("ReceiverModelName", ""))
            self.gestore.dispositivo_trovato(Dispositivo(
                id=f"airdrop:{nome}", nome=nome_disp, backend="airdrop", indirizzo=ip, porta=info.port,
                tipo="telefono" if "iPhone" in modello else ("tablet" if "iPad" in modello else "computer")))

    async def invia(self, dispositivo: Dispositivo, t: Trasferimento):
        import aiohttp

        if not await self._accendi(300):
            raise RuntimeError(T("AirDrop non disponibile"))
        base = f"https://[{dispositivo.indirizzo}]:{dispositivo.porta}"
        richiesta = {
            "SenderComputerName": self.gestore.nome_dispositivo, "SenderModelName": "MacBookPro",
            "SenderID": self.id, "BundleID": "com.apple.finder", "ConvertMediaFormats": False,
            "Files": [{"FileName": p.name, "FileType": "public.data", "FileBomPath": f"./{p.name}",
                       "FileIsDirectory": False, "ConvertMediaFormats": False} for p in t.file],
        }
        timeout = aiohttp.ClientTimeout(total=None, sock_connect=15, sock_read=300)
        async with aiohttp.ClientSession(timeout=timeout) as s:
            async with s.post(f"{base}/Ask", data=plistlib.dumps(richiesta, fmt=plistlib.FMT_BINARY), ssl=False,
                              headers={"Content-Type": "application/octet-stream"}) as r:
                if r.status != 200:
                    t.stato = "rifiutato"
                    return
            archivio = await asyncio.to_thread(crea_cpio, t.file)
            t.stato = "in corso"
            notifica = [0]

            async def flusso():
                for i in range(0, len(archivio), 256 * 1024):
                    if t.annullato:
                        raise RuntimeError(T("Annullato"))
                    blocco = archivio[i:i + 256 * 1024]
                    t.trasferiti = int(t.totale * (i + len(blocco)) / len(archivio))
                    await self.gestore.avanzamento(t, notifica)
                    yield blocco

            async with s.post(f"{base}/Upload", data=flusso(), ssl=False,
                              headers={"Content-Type": "application/x-cpio"}) as r:
                r.raise_for_status()
            await self.gestore.notifiche.chiudi(notifica[0])
