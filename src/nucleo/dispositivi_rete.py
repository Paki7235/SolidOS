"""Tutti i dispositivi collegati alla stessa rete (per File › Rete), senza permessi speciali.

Tre fonti, unite per indirizzo IP:
- mDNS/Bonjour (avahi-browse): nomi e servizi annunciati (computer con cartelle
  condivise, stampanti, TV e Chromecast, iPhone e Mac, NAS…);
- tabella dei vicini (ip neigh) dopo un «tocco» UDP a ogni indirizzo della rete,
  così compaiono anche telefoni, prese smart e tutto ciò che non si annuncia;
- nome dal DNS del modem (molti modem conoscono i nomi assegnati con DHCP).
Il produttore si ricava dall'indirizzo MAC (elenco IEEE, se installato).
"""

from __future__ import annotations

import ipaddress
import json
import re
import socket
import subprocess
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from .i18n import T

OUI = [Path("/usr/share/ieee-data/oui.txt"), Path("/var/lib/ieee-data/oui.txt")]
_oui_cache: dict[str, str] | None = None
_blocco = threading.Lock()

# Servizi mDNS → che cosa sono e come si aprono
SERVIZI = {
    "_smb._tcp": ("computer", "smb"),
    "_sftp-ssh._tcp": ("computer", "sftp"),
    "_ssh._tcp": ("computer", ""),
    "_afpovertcp._tcp": ("computer", "afp"),
    "_ipp._tcp": ("stampante", "http"),
    "_ipps._tcp": ("stampante", "http"),
    "_printer._tcp": ("stampante", "http"),
    "_pdl-datastream._tcp": ("stampante", "http"),
    "_uscan._tcp": ("scanner", "http"),
    "_scanner._tcp": ("scanner", "http"),
    "_googlecast._tcp": ("tv", ""),
    "_airplay._tcp": ("tv", ""),
    "_raop._tcp": ("altoparlante", ""),
    "_spotify-connect._tcp": ("altoparlante", ""),
    "_companion-link._tcp": ("telefono", ""),
    "_apple-mobdev2._tcp": ("telefono", ""),
    "_device-info._tcp": ("", ""),
    "_http._tcp": ("", "http"),
    "_https._tcp": ("", "https"),
    "_hap._tcp": ("casa", ""),
    "_homekit._tcp": ("casa", ""),
    "_workstation._tcp": ("computer", ""),
    "_adisk._tcp": ("nas", "smb"),
    "_nfs._tcp": ("nas", ""),
}
TIPI = {
    "modem": (T("Modem / router"), "network-wireless"),
    "computer": (T("Computer"), "computer"),
    "nas": (T("Disco di rete (NAS)"), "network-server"),
    "stampante": (T("Stampante"), "printer"),
    "scanner": (T("Scanner"), "scanner"),
    "tv": (T("TV / Chromecast"), "video-display"),
    "altoparlante": (T("Altoparlante"), "audio-speakers"),
    "telefono": (T("Telefono o tablet"), "phone"),
    "casa": (T("Dispositivo per la casa"), "preferences-system"),
    "": (T("Dispositivo"), "network-wired"),
}
PAROLE = [  # nome o produttore → tipo
    (r"iphone|ipad|android|galaxy|pixel|redmi|xiaomi|huawei|oneplus|oppo|realme|motorola|phone|honor|vivo", "telefono"),
    (r"\btv\b|tv-|bravia|chromecast|roku|fire.?tv|webos|tizen|smart.?tv|lg-?tv|appletv|apple-tv", "tv"),
    (r"printer|stampante|epson|canon|brother|hp[a-f0-9]{6}|officejet|deskjet|laserjet|kyocera|lexmark|xerox", "stampante"),
    (r"macbook|imac|mac-?mini|desktop|laptop|notebook|\bpc\b|-pc|thinkpad|windows|ubuntu|debian|raspberry", "computer"),
    (r"synology|qnap|nas|diskstation|wd-?mycloud", "nas"),
    (r"echo|alexa|sonos|homepod|google-?home|nest", "altoparlante"),
    (r"shelly|tasmota|tuya|tplink-?smart|tapo|hue|esp[-_]|meross|sonoff", "casa"),
]


def _produttore(mac: str) -> str:
    global _oui_cache
    if not mac or len(mac) < 8:
        return ""
    primo = int(mac[:2], 16)
    if primo & 2:   # indirizzo «casuale» (privacy di iPhone e Android): nessun produttore
        return ""
    if _oui_cache is None:
        _oui_cache = {}
        for f in OUI:
            try:
                for riga in f.read_text(encoding="utf-8", errors="replace").splitlines():
                    if "(hex)" in riga:
                        prefisso, _, nome = riga.partition("(hex)")
                        _oui_cache[prefisso.strip().replace("-", ":").lower()] = nome.strip()
                break
            except OSError:
                continue
    nome = _oui_cache.get(mac[:8].lower(), "")
    # «Apple, Inc.» → «Apple»
    return re.sub(r",?\s+(inc|ltd|co|corp|corporation|limited|gmbh|s\.?p\.?a|technologies|technology|electronics)\.?.*$", "", nome, flags=re.I)


def _reti_locali() -> list[tuple[str, ipaddress.IPv4Network, str]]:
    """(interfaccia, rete, mio indirizzo) per ogni rete IPv4 attiva."""
    try:
        dati = json.loads(subprocess.run(["ip", "-j", "-4", "addr", "show", "up"], capture_output=True, text=True, timeout=3).stdout or "[]")
    except (OSError, ValueError, subprocess.SubprocessError):
        return []
    reti = []
    for interfaccia in dati:
        nome = interfaccia.get("ifname", "")
        if nome == "lo" or nome.startswith(("docker", "podman", "veth", "virbr", "br-", "tun", "wg")):
            continue
        for a in interfaccia.get("addr_info", []):
            try:
                rete = ipaddress.ip_network(f'{a["local"]}/{a["prefixlen"]}', strict=False)
            except (KeyError, ValueError):
                continue
            if rete.prefixlen < 24:   # reti grandi: si guarda solo il proprio /24
                rete = ipaddress.ip_network(f'{a["local"]}/24', strict=False)
            if rete.is_private:
                reti.append((nome, rete, a["local"]))
    return reti


def _modem() -> str:
    try:
        dati = json.loads(subprocess.run(["ip", "-j", "-4", "route", "show", "default"], capture_output=True, text=True, timeout=3).stdout or "[]")
        return dati[0].get("gateway", "") if dati else ""
    except (OSError, ValueError, IndexError, subprocess.SubprocessError):
        return ""


def _tocca(reti) -> None:
    """Un pacchetto UDP vuoto a ogni indirizzo: il sistema chiede chi è (ARP) e la
    risposta finisce nella tabella dei vicini. Nessun permesso speciale."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setblocking(False)
    try:
        for _nome, rete, mio in reti:
            for ip in rete.hosts():
                if str(ip) != mio:
                    try:
                        s.sendto(b"", (str(ip), 9))
                    except OSError:
                        pass
    finally:
        s.close()


def _vicini() -> dict[str, str]:
    """IP → MAC dalla tabella dei vicini (solo quelli che hanno risposto)."""
    try:
        dati = json.loads(subprocess.run(["ip", "-j", "-4", "neigh"], capture_output=True, text=True, timeout=3).stdout or "[]")
    except (OSError, ValueError, subprocess.SubprocessError):
        return {}
    return {v["dst"]: v.get("lladdr", "") for v in dati
            if v.get("lladdr") and not set(v.get("state", [])) & {"FAILED", "INCOMPLETE"}}


def _mdns(secondi: float = 3.0) -> dict[str, dict]:
    """IP → {nome, servizi:[(tipo, porta)], modello} dagli annunci mDNS (avahi)."""
    risultato: dict[str, dict] = {}
    try:
        r = subprocess.run(["avahi-browse", "-a", "-r", "-t", "-p", "-k"], capture_output=True, text=True, timeout=secondi + 5)
        righe = r.stdout.splitlines()
    except (OSError, subprocess.SubprocessError):
        return risultato
    for riga in righe:
        campi = riga.split(";")
        # =;interfaccia;protocollo;nome;tipo;dominio;host;indirizzo;porta;txt
        if len(campi) < 9 or campi[0] != "=" or campi[2] != "IPv4":
            continue
        nome_servizio, tipo, host, ip, porta = campi[3], campi[4], campi[6], campi[7], campi[8]
        txt = campi[9] if len(campi) > 9 else ""
        voce = risultato.setdefault(ip, {"nome": "", "host": "", "servizi": [], "modello": ""})
        voce["host"] = voce["host"] or host.removesuffix(".local")
        if tipo in ("_smb._tcp", "_device-info._tcp", "_workstation._tcp", "_companion-link._tcp") or not voce["nome"]:
            pulito = re.sub(r"\s*\[[0-9a-f:]{17}\]$", "", nome_servizio.replace("\\032", " ").replace("\\.", "."))
            if tipo != "_device-info._tcp" and pulito:
                voce["nome"] = pulito
        modello = re.search(r'"model=([^"]+)"', txt) or re.search(r'"md=([^"]+)"', txt) or re.search(r'"ty=([^"]+)"', txt)
        if modello and not voce["modello"]:
            voce["modello"] = modello.group(1)
        voce["servizi"].append((tipo, porta))
    return risultato


def _nome_dns(ip: str) -> str:
    try:
        nome = socket.gethostbyaddr(ip)[0]
    except (OSError, UnicodeError):
        return ""
    nome = nome.split(".")[0] if not re.match(r"^\d+\.\d+\.\d+\.\d+$", nome) else ""
    return "" if nome.lower() in ("localhost", "_gateway") else nome


def cerca(attesa: float = 2.5) -> list[dict]:
    """Elenco dei dispositivi trovati (modem per primo). Dura circa 3 secondi."""
    with _blocco:
        reti = _reti_locali()
        if not reti:
            return []
        miei = {mio for _n, _r, mio in reti}
        modem = _modem()
        with ThreadPoolExecutor(max_workers=24) as pool:
            annunci = pool.submit(_mdns, attesa + 0.5)
            _tocca(reti)
            time.sleep(attesa)
            vicini = _vicini()
            mdns = annunci.result()
            ips = (set(vicini) | set(mdns)) - miei
            ips = {ip for ip in ips if any(ipaddress.ip_address(ip) in r for _n, r, _m in reti)}
            nomi_dns = dict(zip(ips, pool.map(_nome_dns, ips)))

        dispositivi = []
        for ip in ips:
            a = mdns.get(ip, {})
            mac = vicini.get(ip, "")
            produttore = _produttore(mac)
            nome = a.get("nome") or a.get("host") or nomi_dns.get(ip, "")
            tipo, apertura = "", ""
            for servizio, _porta in a.get("servizi", []):
                t, ap = SERVIZI.get(servizio, ("", ""))
                if t and (not tipo or tipo in ("", "computer") and t in ("nas", "stampante")):
                    tipo = t
                if ap and (not apertura or ap == "smb"):
                    apertura = ap
            if ip == modem:
                tipo = "modem"
                apertura = apertura or "http"
            if not tipo:
                indizi = " ".join([nome, a.get("host", ""), a.get("modello", ""), produttore]).lower()
                for schema, t in PAROLE:
                    if re.search(schema, indizi):
                        tipo = t
                        break
                if not tipo and produttore.lower().startswith("apple"):
                    tipo = "telefono"   # senza servizi annunciati, quasi sempre un iPhone/iPad
            descrizione, icona = TIPI.get(tipo, TIPI[""])
            if not nome:
                nome = f"{produttore} ({ip})" if produttore else (descrizione if tipo == "modem" else f"{T('Dispositivo')} {ip}")
            porta_http = next((p for s, p in a.get("servizi", []) if s in ("_http._tcp", "_https._tcp")), "")
            if apertura == "smb":
                uri = f"smb://{a.get('host') + '.local' if a.get('host') else ip}/"
            elif apertura == "sftp":
                uri = f"sftp://{ip}/"
            elif apertura == "afp":
                uri = f"afp://{ip}/"
            elif apertura in ("http", "https"):
                uri = f"{apertura}://{ip}{':' + porta_http if porta_http and porta_http not in ('80', '443') else ''}/"
            else:
                uri = ""
            dettagli = [x for x in (a.get("modello", ""), produttore if produttore not in nome else "", ip) if x]
            dispositivi.append({
                "nome": nome, "ip": ip, "mac": mac, "produttore": produttore, "modello": a.get("modello", ""),
                "tipo": tipo, "descrizione": descrizione, "icona": icona, "uri": uri,
                "cartelle": apertura in ("smb", "sftp", "afp"), "dettagli": " · ".join(dettagli),
                "ssh": any(sv in ("_ssh._tcp", "_sftp-ssh._tcp") for sv, _p in a.get("servizi", [])),
            })
        ordine = ["modem", "computer", "nas", "stampante", "scanner", "tv", "altoparlante", "telefono", "casa", ""]
        dispositivi.sort(key=lambda d: (ordine.index(d["tipo"]) if d["tipo"] in ordine else 99, d["nome"].lower()))
        return dispositivi


if __name__ == "__main__":
    for d in cerca():
        print(f'{d["descrizione"]:<24} {d["nome"]:<30} {d["dettagli"]:<40} {d["uri"]}')
