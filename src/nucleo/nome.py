"""Il nome di questo dispositivo, uno solo per tutto il sistema (come «Nome del computer»):
lo vedono i telefoni nella Condivisione Vicina, la rete, «Dov'è» e il server delle foto.

Si salva dove lo prevede systemd (PRETTY_HOSTNAME in /etc/machine-info, leggibile da tutti);
il nome di rete (hostname) ne è una versione senza spazi né accenti.
"""

from __future__ import annotations

import os
import pwd
import re
import socket
import unicodedata
from pathlib import Path

from . import branding
from .i18n import T


def nome_rete(nome: str) -> str:
    """«PC di Màrio» → «PC-di-Mario» (lettere, cifre e trattini, massimo 63)."""
    semplice = unicodedata.normalize("NFKD", nome).encode("ascii", "ignore").decode()
    semplice = re.sub(r"[^A-Za-z0-9]+", "-", semplice).strip("-")[:63].strip("-")
    return semplice or branding.id_os()


def nome_dispositivo() -> str:
    try:
        for riga in Path("/etc/machine-info").read_text(encoding="utf-8").splitlines():
            if riga.startswith("PRETTY_HOSTNAME="):
                valore = riga.split("=", 1)[1].strip().strip('"').replace('\\"', '"')
                if valore:
                    return valore
    except OSError:
        pass
    portatile = any(Path("/sys/class/power_supply").glob("BAT*"))
    try:
        persona = (pwd.getpwuid(os.getuid()).pw_gecos.split(",")[0] or "").split(" ")[0]
    except KeyError:
        persona = ""
    if persona:
        return T("{t} di {p}", t=T("Portatile") if portatile else T("Computer"), p=persona)
    return socket.gethostname()


def nome_valido(nome: str) -> bool:
    nome = nome.strip()
    return 0 < len(nome) <= 64 and not any(ord(c) < 32 for c in nome) and '"' not in nome and "\\" not in nome
