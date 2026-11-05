"""Schermata di accesso per greetd (eseguita dentro il compositor kiosk «cage»).

Protocollo greetd: messaggi JSON preceduti dalla lunghezza (4 byte, ordine
nativo) sul socket indicato da $GREETD_SOCK.
"""

from __future__ import annotations

import json
import os
import pwd
import socket
import struct
import sys
from pathlib import Path

from .. import branding
from ..i18n import T
from ..ponte import Backend, crea_ponte
from ..qmlapp import carica, crea_app, prepara_ambiente

ULTIMO_UTENTE = Path("/var/cache/nucleo-greeter/ultimo-utente")


class Greetd:
    def __init__(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect(os.environ["GREETD_SOCK"])

    def richiesta(self, messaggio: dict) -> dict:
        dati = json.dumps(messaggio).encode()
        self.sock.sendall(struct.pack("=I", len(dati)) + dati)
        lunghezza = struct.unpack("=I", self._leggi(4))[0]
        return json.loads(self._leggi(lunghezza))

    def _leggi(self, n: int) -> bytes:
        buf = b""
        while len(buf) < n:
            parte = self.sock.recv(n - len(buf))
            if not parte:
                raise ConnectionError("greetd ha chiuso la connessione")
            buf += parte
        return buf


class BackendGreeter(Backend):
    def __init__(self):
        self._greetd: Greetd | None = None

    def utenti(self) -> list[dict]:
        risultato = []
        for u in pwd.getpwall():
            if 1000 <= u.pw_uid < 60000 and not u.pw_shell.endswith(("nologin", "false")):
                nome = u.pw_gecos.split(",")[0] or u.pw_name
                avatar = Path(u.pw_dir) / ".face"
                risultato.append({"utente": u.pw_name, "nome": nome,
                                  "avatar": str(avatar) if avatar.is_file() else ""})
        return risultato

    def ultimoUtente(self) -> str:
        try:
            return ULTIMO_UTENTE.read_text().strip()
        except OSError:
            return ""

    def accedi(self, utente: str, password: str) -> dict:
        try:
            g = self._greetd = Greetd()
            risposta = g.richiesta({"type": "create_session", "username": utente})
            while risposta.get("type") == "auth_message":
                tipo = risposta.get("auth_message_type")
                if tipo in ("secret", "visible"):
                    risposta = g.richiesta({"type": "post_auth_message_response", "response": password})
                else:  # info / error: nessuna risposta richiesta
                    risposta = g.richiesta({"type": "post_auth_message_response"})
            if risposta.get("type") != "success":
                g.richiesta({"type": "cancel_session"})
                return {"ok": False, "messaggio": T("Password errata. Riprova.")}
            comando = [f"/usr/bin/{branding.comando('sessione')}"]
            risposta = g.richiesta({"type": "start_session", "cmd": comando, "env": []})
            if risposta.get("type") != "success":
                return {"ok": False, "messaggio": risposta.get("description", T("Impossibile avviare la sessione."))}
            try:
                ULTIMO_UTENTE.parent.mkdir(parents=True, exist_ok=True)
                ULTIMO_UTENTE.write_text(utente)
            except OSError:
                pass
            return {"ok": True}
        except (OSError, KeyError, ValueError, ConnectionError) as e:
            return {"ok": False, "messaggio": str(e)}

    def esci(self) -> None:
        from PyQt6.QtGui import QGuiApplication

        QGuiApplication.quit()

    def spegni(self) -> None:
        os.system("systemctl poweroff")

    def riavvia(self) -> None:
        os.system("systemctl reboot")


def main() -> int:
    prepara_ambiente()
    app = crea_app("greeter")
    ponte = crea_ponte(BackendGreeter())
    motore = carica(app, "Greeter/Greeter.qml", {"greeter": ponte})
    codice = app.exec()
    del motore
    return codice


if __name__ == "__main__":
    sys.exit(main())
