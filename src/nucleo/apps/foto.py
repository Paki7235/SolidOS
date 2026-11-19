"""Foto: la Libreria come sul telefono (foto per giorno, preferite, schermate, scaricati e
le foto degli account collegati: Nextcloud, server di casa…) e il visualizzatore a tutto
schermo. Aperta con un file, parte direttamente dal visualizzatore."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from .. import branding
from ..ponte import Backend, crea_ponte
from ..sistema import helper
from ..qmlapp import esegui_app

ESTENSIONI = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".svg", ".tif", ".tiff", ".avif", ".heic", ".heif"}


PORTA_FOTO = 8765


def _ip_locale() -> str:
    import socket

    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("192.0.2.1", 9))   # nessun pacchetto parte: serve solo a sapere l'indirizzo in rete
            return s.getsockname()[0]
    except OSError:
        return ""


def stato_condivisione() -> dict:
    from ..sistema import config_utente, leggi_json

    attiva = bool(leggi_json(config_utente("foto-server.json"), {}).get("attiva"))
    try:
        in_corso = subprocess.run(["systemctl", "--user", "is-active", "--quiet", f"{branding.id_os()}-fotoserver"],
                                  capture_output=True, timeout=10).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        in_corso = False
    ip = _ip_locale()
    return {"attiva": attiva, "inCorso": in_corso, "indirizzo": f"{ip}:{PORTA_FOTO}" if ip else ""}


def avvia_condivisione() -> None:
    """Avvia il server delle foto (sola lettura, ~/Immagini) e apre la porta per la rete di casa."""
    helper("condivisione-porta", "apri", str(PORTA_FOTO), "tcp")
    unita = f"{branding.id_os()}-fotoserver"
    subprocess.run(["systemctl", "--user", "reset-failed", unita], capture_output=True)
    subprocess.run(["systemd-run", "--user", f"--unit={unita}", "--collect", "/usr/bin/python3", "-m", "nucleo.fotoserver",
                    "--porta", str(PORTA_FOTO)], capture_output=True)


class BackendFoto(Backend):
    def fileIniziale(self) -> str:
        """Il file passato all'avvio (doppio clic su un'immagine); vuoto = si apre la Libreria."""
        argomenti = [a for a in sys.argv[1:] if not a.startswith("-")]
        return str(Path(argomenti[0]).resolve()) if argomenti else ""

    # ── Libreria e account collegati (come sul telefono) ────────────────────
    def libreria(self) -> list:
        from .. import fotolibreria

        return fotolibreria.foto()

    def preferita(self, percorso: str, si: bool) -> None:
        from .. import fotolibreria

        fotolibreria.foto_preferita(str(percorso).replace("file://", ""), bool(si))

    def servizi(self) -> list:
        from .. import fotoaccount

        return fotoaccount.servizi()

    def collegaNextcloud(self, indirizzo: str, utente: str, password: str, cartella: str) -> dict:
        from .. import fotoaccount

        return fotoaccount.collega_nextcloud(indirizzo, utente, password, cartella or "Photos")

    def collegaServer(self, indirizzo: str, utente: str = "", password: str = "") -> dict:
        from .. import fotoaccount

        return fotoaccount.collega_server(indirizzo, utente, password)

    def scopriServer(self) -> list:
        from .. import fotoaccount

        return fotoaccount.scopri_server()

    def scollega(self, servizio: str) -> dict:
        from .. import fotoaccount

        return fotoaccount.scollega(servizio)

    # ── Questo computer come «server di casa» per le Foto del telefono ─────
    def condivisione(self) -> dict:
        return stato_condivisione()

    def condividi(self, si: bool) -> dict:
        from ..sistema import config_utente, scrivi_json

        scrivi_json(config_utente("foto-server.json"), {"attiva": bool(si)})
        if si:
            avvia_condivisione()
        else:
            subprocess.run(["systemctl", "--user", "stop", f"{branding.id_os()}-fotoserver"], capture_output=True)
            helper("condivisione-porta", "chiudi", str(PORTA_FOTO), "tcp")
        return stato_condivisione()

    def sincronizza(self) -> bool:
        from .. import fotoaccount

        fotoaccount.sincronizza()
        return True

    def elenco(self, percorso: str) -> list[str]:
        """Le immagini della cartella del file (o della cartella stessa), in ordine."""
        p = Path(percorso.replace("file://", ""))
        cartella = p if p.is_dir() else p.parent
        if not cartella.is_dir():
            return []
        return [str(f) for f in sorted(cartella.iterdir(), key=lambda x: x.name.lower())
                if f.suffix.lower() in ESTENSIONI and f.is_file()]

    def usaComeSfondo(self, percorso: str) -> bool:
        from ..sistema import imposta_sfondo

        imposta_sfondo(percorso.replace("file://", ""))
        return True

    def cestino(self, percorso: str) -> bool:
        return subprocess.run(["gio", "trash", percorso.replace("file://", "")], capture_output=True).returncode == 0

    def mostraNellaCartella(self, percorso: str) -> None:
        from ..sistema import avvia

        avvia(["xdg-open", str(Path(percorso.replace("file://", "")).parent)])


def main() -> int:
    if "--condividi" in sys.argv[1:]:   # all'accesso, se la condivisione è accesa
        avvia_condivisione()
        return 0
    return esegui_app("foto", "Foto/Main.qml", lambda app: {"ponte": crea_ponte(BackendFoto())})


if __name__ == "__main__":
    sys.exit(main())
