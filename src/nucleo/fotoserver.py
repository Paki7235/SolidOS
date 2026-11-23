"""Server delle foto di casa: condivide una cartella di foto con i telefoni SolidOS.

Le Foto del telefono lo trovano in «Account collegati › Server di casa» (da sole, sulla stessa
rete Wi-Fi, oppure scrivendo l'indirizzo). Il protocollo è WebDAV, lo stesso di Nextcloud, di
molti NAS (Synology, QNAP) e dei router con disco: il telefono funziona anche con quelli.

Solo lettura: dal telefono si vedono e si scaricano le foto, non si cancella niente.

Uso (sul PC SolidOS o su un altro computer con Python 3):
    python3 -m nucleo.fotoserver [CARTELLA] [--porta 8765] [--password PAROLA]
Senza cartella condivide ~/Immagini (o ~/Pictures). Con --password il telefono chiede
utente «foto» e quella password.
"""

from __future__ import annotations

import argparse
import base64
import html
import mimetypes
import os
import socket
import sys
import urllib.parse
from email.utils import formatdate
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ESTENSIONI = {".jpg", ".jpeg", ".png", ".webp", ".heic", ".gif", ".tif", ".tiff"}


def _cartella_predefinita() -> Path:
    for nome in ("Immagini", "Pictures", "Foto"):
        c = Path.home() / nome
        if c.is_dir():
            return c
    return Path.home()


def _ip_locale() -> str:
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("192.0.2.1", 9))   # nessun pacchetto parte: serve solo a scegliere la scheda di rete
            return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"


class Gestore(BaseHTTPRequestHandler):
    radice: Path = Path.home()
    password: str = ""
    server_version = "SolidOS-Foto/1.0"

    def log_message(self, formato, *argomenti):  # noqa: D401 — una riga breve per richiesta
        sys.stderr.write("  %s %s\n" % (self.command, urllib.parse.unquote(self.path)))

    # ── Accesso ──────────────────────────────────────────────────────────
    def _autorizzato(self) -> bool:
        if not self.password:
            return True
        atteso = "Basic " + base64.b64encode(f"foto:{self.password}".encode()).decode()
        if self.headers.get("Authorization", "") == atteso:
            return True
        self.send_response(401)
        self.send_header("WWW-Authenticate", 'Basic realm="Foto di casa"')
        self.send_header("Content-Length", "0")
        self.end_headers()
        return False

    def _percorso(self) -> Path | None:
        relativo = urllib.parse.unquote(urllib.parse.urlparse(self.path).path).lstrip("/")
        p = (self.radice / relativo).resolve()
        if p != self.radice and self.radice not in p.parents:
            return None   # niente «../» fuori dalla cartella condivisa
        if any(parte.startswith(".") for parte in p.relative_to(self.radice).parts):
            return None
        return p

    # ── Metodi ───────────────────────────────────────────────────────────
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("DAV", "1")
        self.send_header("Allow", "OPTIONS, GET, HEAD, PROPFIND")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_PROPFIND(self):
        if not self._autorizzato():
            return
        lunghezza = int(self.headers.get("Content-Length") or 0)
        if lunghezza:
            self.rfile.read(lunghezza)
        p = self._percorso()
        if p is None or not p.exists():
            self.send_error(404)
            return
        voci = [p]
        if p.is_dir() and self.headers.get("Depth", "1") != "0":
            for figlio in sorted(p.iterdir()):
                if figlio.name.startswith("."):
                    continue
                if figlio.is_dir() or figlio.suffix.lower() in ESTENSIONI:
                    voci.append(figlio)
        risposte = []
        for v in voci:
            rel = v.relative_to(self.radice).as_posix()
            href = "/" + urllib.parse.quote(rel + ("/" if v.is_dir() and rel else ""))
            if v == self.radice:
                href = "/"
            st = v.stat()
            if v.is_dir():
                prop = "<d:resourcetype><d:collection/></d:resourcetype>"
            else:
                prop = (f"<d:resourcetype/><d:getcontentlength>{st.st_size}</d:getcontentlength>"
                        f"<d:getcontenttype>{mimetypes.guess_type(v.name)[0] or 'application/octet-stream'}</d:getcontenttype>")
            risposte.append(
                f"<d:response><d:href>{html.escape(href)}</d:href><d:propstat><d:prop>"
                f"<d:displayname>{html.escape(v.name)}</d:displayname>{prop}"
                f"<d:getlastmodified>{formatdate(st.st_mtime, usegmt=True)}</d:getlastmodified>"
                f"</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>")
        corpo = ('<?xml version="1.0" encoding="utf-8"?><d:multistatus xmlns:d="DAV:">'
                 + "".join(risposte) + "</d:multistatus>").encode()
        self.send_response(207)
        self.send_header("Content-Type", 'application/xml; charset="utf-8"')
        self.send_header("Content-Length", str(len(corpo)))
        self.end_headers()
        self.wfile.write(corpo)

    def do_GET(self, solo_intestazioni: bool = False):
        if not self._autorizzato():
            return
        p = self._percorso()
        if p is None or not p.is_file() or p.suffix.lower() not in ESTENSIONI:
            self.send_error(404)
            return
        st = p.stat()
        self.send_response(200)
        self.send_header("Content-Type", mimetypes.guess_type(p.name)[0] or "application/octet-stream")
        self.send_header("Content-Length", str(st.st_size))
        self.send_header("Last-Modified", formatdate(st.st_mtime, usegmt=True))
        self.end_headers()
        if not solo_intestazioni:
            with p.open("rb") as f:
                while blocco := f.read(1 << 16):
                    self.wfile.write(blocco)

    def do_HEAD(self):
        self.do_GET(solo_intestazioni=True)


def _annuncia(porta: int, nome: str):
    """Si fa trovare dai telefoni sulla stessa rete (mDNS, servizio _webdav._tcp)."""
    try:
        from zeroconf import ServiceInfo, Zeroconf
    except ImportError:
        return None
    ip = _ip_locale()
    info = ServiceInfo("_webdav._tcp.local.", f"{nome}._webdav._tcp.local.", addresses=[socket.inet_aton(ip)],
                       port=porta, properties={"path": "/", "solidos": "foto"}, server=f"{socket.gethostname()}.local.")
    z = Zeroconf()
    try:
        z.register_service(info)
    except Exception:  # noqa: BLE001 — senza mDNS si scrive l'indirizzo a mano
        z.close()
        return None
    return z, info


def _nome_predefinito() -> str:
    try:
        from nucleo.nome import nome_dispositivo

        return f"Foto di {nome_dispositivo()}"
    except Exception:  # noqa: BLE001 — anche fuori da SolidOS (altri computer con Python)
        return f"Foto di {socket.gethostname().split('.')[0]}"


def main() -> int:
    a = argparse.ArgumentParser(description="Condivide una cartella di foto con i telefoni SolidOS")
    a.add_argument("cartella", nargs="?", default=str(_cartella_predefinita()))
    a.add_argument("--porta", type=int, default=8765)
    a.add_argument("--password", default=os.environ.get("FOTO_PASSWORD", ""))
    a.add_argument("--nome", default=_nome_predefinito())
    arg = a.parse_args()
    radice = Path(arg.cartella).expanduser().resolve()
    if not radice.is_dir():
        print(f"Cartella non trovata: {radice}")
        return 1
    Gestore.radice, Gestore.password = radice, arg.password
    server = ThreadingHTTPServer(("0.0.0.0", arg.porta), Gestore)
    annuncio = _annuncia(arg.porta, arg.nome)
    ip = _ip_locale()
    print(f"Server delle foto di casa: {radice}")
    print(f"  Indirizzo per il telefono:          http://{ip}:{arg.porta}")
    print(f"  Dal telefono virtuale (QEMU):        http://10.0.2.2:{arg.porta}")
    print("  " + (f"Utente «foto», password «{arg.password}»" if arg.password else "Senza password (solo per la rete di casa)"))
    print("  " + ("I telefoni sulla stessa rete Wi-Fi lo trovano da soli." if annuncio else "Per farlo trovare da solo serve il modulo «zeroconf»."))
    print("Premi Ctrl+C per fermarlo.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        if annuncio:
            annuncio[0].unregister_service(annuncio[1])
            annuncio[0].close()
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
