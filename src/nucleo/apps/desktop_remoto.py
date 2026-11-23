"""Desktop remoto: vedere e usare un altro computer da qui, e lasciare che un altro computer
veda e usi questo.

- «Collegati»: indirizzo (o un computer trovato nella rete), protocollo RDP o VNC, utente.
  La finestra del collegamento la apre Remmina, che parla entrambi i protocolli.
- «Questo computer»: con l'interruttore acceso parte wayvnc (VNC, porta 5900), con utente e
  password e la cifratura RSA-AES; la porta si apre solo per la sessione. Qualsiasi programma
  VNC degli altri sistemi operativi si collega con indirizzo, utente e password.
"""

from __future__ import annotations

import os
import pwd
import secrets
import socket
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from .. import branding
from ..i18n import T
from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app
from ..sistema import avvia, config_utente, helper, leggi_json, scrivi_json

PORTA_VNC = 5900
PORTE = {"rdp": 3389, "vnc": 5900}
UNITA = f"{branding.id_os()}-desktop-remoto"


def _conf() -> dict:
    return leggi_json(config_utente("desktop-remoto.json"), {})


def _salva(c: dict) -> None:
    f = config_utente("desktop-remoto.json")
    scrivi_json(f, c)
    os.chmod(f, 0o600)   # c'è la password


def _ip_locale() -> str:
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("192.0.2.1", 9))
            return s.getsockname()[0]
    except OSError:
        return ""


def _porta_aperta(ip: str, porta: int, attesa: float = 0.6) -> bool:
    try:
        with socket.create_connection((ip, porta), timeout=attesa):
            return True
    except OSError:
        return False


def _utente() -> str:
    return pwd.getpwuid(os.getuid()).pw_name


def _prepara_wayvnc(password: str) -> None:
    cartella = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "wayvnc"
    cartella.mkdir(parents=True, exist_ok=True)
    os.chmod(cartella, 0o700)
    chiave = cartella / "chiave-rsa.pem"
    if not chiave.is_file():
        subprocess.run(["openssl", "genrsa", "-traditional", "-out", str(chiave), "2048"], capture_output=True)
        os.chmod(chiave, 0o600)
    conf = cartella / "config"
    conf.write_text(
        "# Scritto da Desktop remoto di SolidOS\n"
        f"address=0.0.0.0\nport={PORTA_VNC}\nenable_auth=true\n"
        f"username={_utente()}\npassword={password}\n"
        f"rsa_private_key_file={chiave}\n"
        # anche i programmi VNC che non conoscono RSA-AES (sempre con utente e password)
        "relax_encryption=true\n", encoding="utf-8")
    os.chmod(conf, 0o600)


def avvia_server() -> None:
    c = _conf()
    if not c.get("password"):
        c["password"] = "".join(secrets.choice("abcdefghjkmnpqrstuvwxyz23456789") for _ in range(8))
        _salva(c)
    _prepara_wayvnc(c["password"])
    helper("condivisione-porta", "apri", str(PORTA_VNC), "tcp")
    subprocess.run(["systemctl", "--user", "reset-failed", UNITA], capture_output=True)
    subprocess.run(["systemd-run", "--user", f"--unit={UNITA}", "--collect", "wayvnc"], capture_output=True)


def ferma_server() -> None:
    subprocess.run(["systemctl", "--user", "stop", UNITA], capture_output=True)
    helper("condivisione-porta", "chiudi", str(PORTA_VNC), "tcp")


class BackendDesktopRemoto(Backend):
    def stato(self) -> dict:
        c = _conf()
        try:
            in_corso = subprocess.run(["systemctl", "--user", "is-active", "--quiet", UNITA],
                                      capture_output=True, timeout=5).returncode == 0
        except (OSError, subprocess.TimeoutExpired):
            in_corso = False
        try:
            from ..nome import nome_dispositivo

            nome = nome_dispositivo()
        except Exception:  # noqa: BLE001
            nome = socket.gethostname()
        return {"attivo": bool(c.get("attivo")), "inCorso": in_corso, "indirizzo": _ip_locale(),
                "porta": PORTA_VNC, "utente": _utente(), "password": c.get("password", ""), "nome": nome,
                "recenti": c.get("recenti", [])[:8]}

    def consenti(self, si: bool) -> dict:
        c = _conf()
        c["attivo"] = bool(si)
        _salva(c)
        avvia_server() if si else ferma_server()
        return self.stato()

    def nuovaPassword(self) -> dict:
        c = _conf()
        c["password"] = "".join(secrets.choice("abcdefghjkmnpqrstuvwxyz23456789") for _ in range(8))
        _salva(c)
        if c.get("attivo"):
            ferma_server()
            avvia_server()
        return self.stato()

    def cerca(self) -> list:
        """I computer della rete che accettano un collegamento RDP o VNC."""
        from ..dispositivi_rete import cerca

        try:
            trovati = [d for d in cerca() if d.get("ip") and d.get("ip") != _ip_locale()]
        except Exception:  # noqa: BLE001
            return []

        def prova(d):
            protocolli = [p for p, porta in PORTE.items() if _porta_aperta(d["ip"], porta)]
            return {"nome": d.get("nome") or d["ip"], "ip": d["ip"], "protocolli": protocolli} if protocolli else None

        with ThreadPoolExecutor(max_workers=16) as pool:
            return [x for x in pool.map(prova, trovati) if x]

    def collega(self, indirizzo: str, protocollo: str = "auto", utente: str = "") -> dict:
        indirizzo, utente = str(indirizzo).strip(), str(utente).strip()
        if not indirizzo or any(c in indirizzo for c in " \n\t;"):
            return {"ok": False, "messaggio": T("Scrivi l'indirizzo dell'altro computer, es. 192.168.1.20")}
        host = indirizzo.rsplit(":", 1)[0] if indirizzo.count(":") == 1 else indirizzo
        if protocollo not in ("rdp", "vnc"):
            protocollo = next((p for p, porta in PORTE.items() if _porta_aperta(host, porta, 1.5)), "")
            if not protocollo:
                return {"ok": False, "messaggio": T("«{h}» non accetta collegamenti di desktop remoto (RDP o VNC). "
                                                    "Sull'altro computer attiva il desktop remoto o la condivisione schermo.", h=host)}
        profilo = Path.home() / ".cache" / branding.id_os() / "collegamento.remmina"
        profilo.parent.mkdir(parents=True, exist_ok=True)
        righe = ["[remmina]", f"name={host}", f"protocol={protocollo.upper()}", f"server={indirizzo}",
                 "scale=2" if protocollo == "vnc" else "scale=2", "viewmode=1"]
        if utente:
            righe.append(f"username={utente}")
        profilo.write_text("\n".join(righe) + "\n", encoding="utf-8")
        os.chmod(profilo, 0o600)
        avvia(["remmina", "-c", str(profilo)])
        c = _conf()
        recenti = [r for r in c.get("recenti", []) if r.get("indirizzo") != indirizzo]
        c["recenti"] = [{"indirizzo": indirizzo, "protocollo": protocollo, "utente": utente}] + recenti[:7]
        _salva(c)
        return {"ok": True, "messaggio": T("Collegamento a {h} ({p})…", h=host, p=protocollo.upper())}


def main() -> int:
    if "--avvia-server" in sys.argv[1:]:   # all'accesso, se «Consenti» è acceso
        avvia_server()
        return 0
    return esegui_app("desktop-remoto", "DesktopRemoto/Main.qml", lambda app: {"ponte": crea_ponte(BackendDesktopRemoto())})


if __name__ == "__main__":
    sys.exit(main())
