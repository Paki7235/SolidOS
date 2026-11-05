"""Cattura: schermate (intero schermo o area) e registrazione video dello schermo."""

from __future__ import annotations

import signal
import subprocess
import sys
import time

from ..i18n import T
from ..ponte import Backend
from ..qmlapp import esegui_app
from ..sistema import cartella_utente, esegui, esiste, notifica


class BackendCattura(Backend):
    def __init__(self):
        self._registrazione: subprocess.Popen | None = None
        self._file_video = ""

    def _nome(self, estensione: str, cartella: str) -> str:
        base = cartella_utente(cartella, "Immagini" if cartella == "PICTURES" else "Video")
        base.mkdir(parents=True, exist_ok=True)
        return str(base / f"{T('Schermata') if estensione == 'png' else T('Registrazione')}_"
                         f"{time.strftime('%Y-%m-%d_%H-%M-%S')}.{estensione}")

    def area(self) -> str:
        r = esegui(["slurp"], timeout=120)
        return r.stdout.strip() if r.returncode == 0 else ""

    def schermata(self, area: str = "", appunti: bool = False) -> dict:
        file = self._nome("png", "PICTURES")
        cmd = ["grim"] + (["-g", area] if area else []) + [file]
        r = esegui(cmd, timeout=20)
        if r.returncode != 0:
            return {"ok": False, "messaggio": r.stderr.strip()}
        if appunti and esiste("wl-copy"):
            with open(file, "rb") as f:
                subprocess.run(["wl-copy", "--type", "image/png"], stdin=f, check=False)
        notifica(T("Schermata salvata"), file, icona=file)
        return {"ok": True, "file": file}

    def avviaRegistrazione(self, area: str = "", audio: bool = False) -> dict:
        if self._registrazione:
            return {"ok": False, "messaggio": T("Registrazione già in corso")}
        self._file_video = self._nome("mp4", "VIDEOS")
        cmd = ["wf-recorder", "-f", self._file_video]
        if area:
            cmd += ["-g", area]
        if audio:
            cmd.append("--audio")
        self._registrazione = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return {"ok": True}

    def fermaRegistrazione(self) -> dict:
        if not self._registrazione:
            return {"ok": False}
        self._registrazione.send_signal(signal.SIGINT)
        try:
            self._registrazione.wait(timeout=10)
        except subprocess.TimeoutExpired:
            self._registrazione.kill()
        self._registrazione = None
        notifica(T("Registrazione salvata"), self._file_video, icona="video-x-generic")
        return {"ok": True, "file": self._file_video}

    def inRegistrazione(self) -> bool:
        return self._registrazione is not None

    def apri(self, file: str) -> None:
        subprocess.Popen(["xdg-open", file], start_new_session=True)


def main() -> int:
    from ..ponte import crea_ponte

    if "--subito" in sys.argv:
        BackendCattura().schermata()
        return 0
    return esegui_app("cattura", "Cattura/Main.qml", lambda app: {"ponte": crea_ponte(BackendCattura())})


if __name__ == "__main__":
    sys.exit(main())
