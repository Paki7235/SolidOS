"""Il proprio account: nome mostrato, foto e password (anche nessuna password).

Usato dalla configurazione iniziale (Benvenuto) e da Impostazioni → Utenti.
Nome e foto compaiono nella schermata di accesso e in quella di blocco.
"""

from __future__ import annotations

import os
import pwd
import subprocess
from pathlib import Path

from .i18n import T
from .sistema import HELPER, helper


def _io() -> pwd.struct_passwd:
    return pwd.getpwuid(os.getuid())


def _esito(r: subprocess.CompletedProcess, ok: str) -> dict:
    if r.returncode == 0:
        return {"ok": True, "messaggio": ok}
    errore = (r.stderr or "").strip() if isinstance(r.stderr, str) else ""
    if r.returncode in (126, 127) and not errore:
        errore = T("Operazione annullata")
    return {"ok": False, "messaggio": errore or T("Operazione non riuscita")}


def info() -> dict:
    from .blocco.__main__ import foto_utente, iniziali, senza_password

    u = _io()
    nome = (u.pw_gecos.split(",")[0] or u.pw_name).strip()
    foto = foto_utente(u)
    return {"utente": u.pw_name, "nome": nome, "iniziali": iniziali(nome),
            "foto": ("file://" + foto) if foto else "", "password": not senza_password(u.pw_name)}


def imposta_nome(nome: str) -> dict:
    nome = " ".join(nome.split())
    if not nome:
        return {"ok": False, "messaggio": T("Scrivi un nome")}
    return _esito(helper("utente-nome", _io().pw_name, nome), T("Nome cambiato"))


def imposta_password(password: str, conferma: str) -> dict:
    if len(password) < 4:
        return {"ok": False, "messaggio": T("La password deve avere almeno 4 caratteri")}
    if password != conferma:
        return {"ok": False, "messaggio": T("Le due password non coincidono")}
    comando = [HELPER, "utente-password", _io().pw_name]
    if os.geteuid() != 0:
        comando.insert(0, "pkexec")
    r = subprocess.run(comando, input=password + "\n", capture_output=True, text=True, timeout=600)
    return _esito(r, T("Password impostata: servirà per entrare e per sbloccare"))


def togli_password() -> dict:
    return _esito(helper("utente-senza-password", _io().pw_name),
                  T("Password tolta: per entrare e sbloccare basta premere Invio"))


def imposta_foto(percorso: str) -> dict:
    """Ritaglia la foto al centro (quadrata, 256 px) e la salva come ~/.face."""
    from PyQt6.QtCore import QRect, Qt
    from PyQt6.QtGui import QImage

    percorso = percorso.removeprefix("file://")
    immagine = QImage(percorso)
    if immagine.isNull():
        return {"ok": False, "messaggio": T("Questa immagine non si può aprire")}
    lato = min(immagine.width(), immagine.height())
    quadrata = immagine.copy(QRect((immagine.width() - lato) // 2, (immagine.height() - lato) // 2, lato, lato))
    quadrata = quadrata.scaled(256, 256, Qt.AspectRatioMode.IgnoreAspectRatio, Qt.TransformationMode.SmoothTransformation)
    faccia = Path.home() / ".face"
    if faccia.is_symlink():
        faccia.unlink()
    if not quadrata.save(str(faccia), "PNG"):
        return {"ok": False, "messaggio": T("Non sono riuscito a salvare la foto")}
    helper("utente-foto", _io().pw_name, timeout=60)   # per la schermata di accesso (se rifiutato, resta per il blocco)
    return {"ok": True, "messaggio": T("Foto cambiata")}


def togli_foto() -> dict:
    (Path.home() / ".face").unlink(missing_ok=True)
    helper("utente-foto", _io().pw_name, timeout=60)
    return {"ok": True, "messaggio": T("Foto tolta")}
