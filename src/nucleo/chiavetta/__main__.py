"""Crea chiavetta: scrive l'immagine del sistema su una chiavetta USB e aggiunge la
partizione di persistenza (file, impostazioni e app restano salvati sulla chiavetta)."""

import json
import sys
from pathlib import Path

from ..i18n import T
from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app
from ..sistema import helper, uscita


class BackendChiavetta(Backend):
    def chiavette(self) -> list:
        try:
            dati = json.loads(uscita(["lsblk", "-J", "-d", "-b", "-o", "PATH,MODEL,SIZE,TRAN,RM,TYPE"]) or "{}")
        except json.JSONDecodeError:
            return []
        return [{"percorso": d["path"], "nome": (d.get("model") or "USB").strip(), "dimensione": round(int(d["size"]) / 1e9, 1)}
                for d in dati.get("blockdevices", [])
                if d.get("type") == "disk" and (d.get("tran") == "usb" or d.get("rm")) and int(d.get("size") or 0) >= 4e9]

    def immagini(self) -> list:
        trovate = []
        for base in (Path.home() / "Scaricati", Path.home() / "Downloads", Path.home()):
            if base.is_dir():
                trovate += [str(p) for p in base.glob("*.iso")]
        return sorted(set(trovate))

    def crea(self, immagine: str, chiavetta: str, persistenza: bool) -> dict:
        self.emetti("fase", T("Scrittura dell'immagine (alcuni minuti)…"))
        r = helper("scrivi-immagine", immagine.removeprefix("file://"), chiavetta, timeout=7200)
        if r.returncode != 0:
            return {"ok": False, "messaggio": r.stderr.strip() or T("Scrittura non riuscita")}
        if persistenza:
            self.emetti("fase", T("Creazione dello spazio per i tuoi dati…"))
            r = helper("persistenza", chiavetta, timeout=1800)
            if r.returncode != 0:
                return {"ok": False, "messaggio": T("Immagine scritta, ma la persistenza non è stata creata: {e}", e=r.stderr.strip())}
        return {"ok": True}

    def soloPersistenza(self, chiavetta: str) -> dict:
        r = helper("persistenza", chiavetta, timeout=1800)
        return {"ok": r.returncode == 0, "messaggio": r.stderr.strip()}


def main() -> int:
    return esegui_app("chiavetta", "Chiavetta/Main.qml", lambda app: {"ponte": crea_ponte(BackendChiavetta())})


if __name__ == "__main__":
    sys.exit(main())
