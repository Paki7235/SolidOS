"""Linea del Tempo: torna indietro nel tempo su un file, una cartella o l'intero sistema.

Uso: <OS_ID>-linea-del-tempo [FILE_O_CARTELLA]
"""

from __future__ import annotations

import mimetypes
import shutil
import sys
from pathlib import Path

from ..i18n import T
from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app
from ..sistema import avvia, esegui, helper
from .snapshot import avviato_da_snapshot, elenco_snapshot, snapshot_disponibili, versioni


class BackendLinea(Backend):
    def stato(self) -> dict:
        argomenti = [a for a in sys.argv[1:] if not a.startswith("-")]
        return {"disponibile": snapshot_disponibili(), "daSnapshot": avviato_da_snapshot() or 0,
                "iniziale": argomenti[0].removeprefix("file://") if argomenti else str(Path.home())}

    def versioni(self, percorso: str) -> list[dict]:
        return versioni(percorso.removeprefix("file://"))

    def contenuto(self, percorso: str) -> dict:
        """Anteprima: elenco per le cartelle, testo per i file di testo, immagine per le immagini."""
        p = Path(percorso)
        if p.is_dir():
            try:
                voci = sorted(p.iterdir(), key=lambda x: (not x.is_dir(), x.name.lower()))[:200]
            except OSError:
                return {"tipo": "errore", "testo": T("Non hai i permessi per vedere questa cartella")}
            return {"tipo": "cartella", "voci": [{"nome": v.name, "cartella": v.is_dir(), "percorso": str(v)} for v in voci]}
        mime = mimetypes.guess_type(p.name)[0] or ""
        if mime.startswith("image/"):
            return {"tipo": "immagine", "percorso": str(p)}
        try:
            dati = p.read_bytes()[:20000]
            return {"tipo": "testo", "testo": dati.decode("utf-8")}
        except UnicodeDecodeError:
            return {"tipo": "binario", "testo": T("Anteprima non disponibile per questo tipo di file")}
        except OSError:
            return {"tipo": "errore", "testo": T("Non hai i permessi per leggere questo file")}

    def ripristina(self, versione: str, originale: str, sostituisci: bool) -> dict:
        sorgente, destinazione = Path(versione), Path(originale)
        if sostituisci:
            if destinazione.exists():
                cestino = Path.home() / ".local/share/Trash/files"
                cestino.mkdir(parents=True, exist_ok=True)
                shutil.move(str(destinazione), str(cestino / f"{destinazione.name}.prima-del-ripristino"))
        else:
            data = sorgente.parts[3] if len(sorgente.parts) > 3 else "copia"
            destinazione = destinazione.with_name(f"{destinazione.stem} ({T('versione')} {data}){destinazione.suffix}")
        try:
            if sorgente.is_dir():
                shutil.copytree(sorgente, destinazione, symlinks=True)
            else:
                shutil.copy2(sorgente, destinazione)
        except PermissionError:
            parti = sorgente.parts
            config = "home" if str(sorgente).startswith("/home/.snapshots") else "root"
            numero = parti[3] if config == "home" else parti[2]
            r = helper("ripristina-file", config, numero, originale, str(destinazione))
            if r.returncode != 0:
                return {"ok": False, "messaggio": r.stderr.strip()}
        return {"ok": True, "messaggio": T("Ripristinato in {p}", p=str(destinazione)), "percorso": str(destinazione)}

    def sistema(self) -> list[dict]:
        return elenco_snapshot("root") if snapshot_disponibili() else []

    def creaPunto(self, descrizione: str) -> dict:
        r = helper("snapshot-crea", descrizione or T("Manuale"))
        return {"ok": r.returncode == 0, "messaggio": r.stderr.strip()}

    def tornaA(self, numero: int) -> dict:
        r = helper("ripristina-sistema", str(int(numero)))
        return {"ok": r.returncode == 0, "messaggio": r.stdout.strip() or r.stderr.strip()}

    def riavvia(self) -> None:
        esegui(["systemctl", "reboot"])

    def apri(self, percorso: str) -> None:
        avvia(["xdg-open", percorso])


def main() -> int:
    return esegui_app("linea-del-tempo", "LineaDelTempo/Main.qml", lambda app: {"ponte": crea_ponte(BackendLinea())})


if __name__ == "__main__":
    sys.exit(main())
