"""Dischi: elenco, montaggio, espulsione, salute SMART, formattazione, scrittura immagini."""

from __future__ import annotations

import json
import sys

from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app
from ..sistema import esegui, helper, uscita

CAMPI = "NAME,PATH,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS,MODEL,RM,TRAN,FSUSED,FSAVAIL,RO,PKNAME"


def _gb(byte) -> float:
    try:
        return round(int(byte) / 1e9, 1)
    except (TypeError, ValueError):
        return 0.0


class BackendDischi(Backend):
    def dischi(self) -> list[dict]:
        try:
            dati = json.loads(uscita(["lsblk", "-J", "-b", "-o", CAMPI]) or "{}")
        except json.JSONDecodeError:
            return []
        risultato = []
        for d in dati.get("blockdevices", []):
            if d.get("type") not in ("disk",) or d.get("name", "").startswith(("zram", "loop")):
                continue
            partizioni = []
            for p in d.get("children", []) or []:
                punti = [m for m in (p.get("mountpoints") or []) if m]
                partizioni.append({
                    "percorso": p.get("path"), "nome": p.get("label") or p.get("name"),
                    "fs": p.get("fstype") or "", "dimensione": _gb(p.get("size")),
                    "usato": _gb(p.get("fsused")), "libero": _gb(p.get("fsavail")),
                    "montata": bool(punti), "punto": punti[0] if punti else "",
                    "crittografata": p.get("fstype") in ("crypto_LUKS", "BitLocker"),
                })
            risultato.append({
                "percorso": d.get("path"), "modello": (d.get("model") or d.get("name") or "").strip(),
                "dimensione": _gb(d.get("size")), "rimovibile": bool(d.get("rm")),
                "collegamento": d.get("tran") or "", "partizioni": partizioni,
            })
        return risultato

    def monta(self, percorso: str) -> dict:
        r = esegui(["udisksctl", "mount", "-b", percorso, "--no-user-interaction"], timeout=30)
        if r.returncode != 0:
            r = esegui(["udisksctl", "mount", "-b", percorso], timeout=60)
        return {"ok": r.returncode == 0, "messaggio": (r.stdout or r.stderr).strip()}

    def smonta(self, percorso: str) -> dict:
        r = esegui(["udisksctl", "unmount", "-b", percorso], timeout=30)
        return {"ok": r.returncode == 0, "messaggio": (r.stdout or r.stderr).strip()}

    def espelli(self, disco: str) -> dict:
        for d in self.dischi():
            if d["percorso"] == disco:
                for p in d["partizioni"]:
                    if p["montata"]:
                        self.smonta(p["percorso"])
        r = esegui(["udisksctl", "power-off", "-b", disco], timeout=30)
        return {"ok": r.returncode == 0, "messaggio": (r.stdout or r.stderr).strip()}

    def salute(self, disco: str) -> dict:
        r = helper("smart", disco, timeout=60)
        try:
            dati = json.loads(r.stdout)
        except json.JSONDecodeError:
            return {"ok": False, "messaggio": r.stderr.strip() or "SMART non disponibile"}
        stato = dati.get("smart_status", {}).get("passed")
        return {"ok": True, "superato": stato, "ore": dati.get("power_on_time", {}).get("hours"),
                "temperatura": dati.get("temperature", {}).get("current"),
                "modello": dati.get("model_name", "")}

    def formatta(self, percorso: str, fs: str, etichetta: str) -> dict:
        r = helper("formatta", percorso, fs, etichetta or "Disco", timeout=600)
        return {"ok": r.returncode == 0, "messaggio": (r.stderr or r.stdout).strip()}

    def scriviImmagine(self, immagine: str, disco: str) -> dict:
        r = helper("scrivi-immagine", immagine.removeprefix("file://"), disco, timeout=3600)
        return {"ok": r.returncode == 0, "messaggio": (r.stderr or r.stdout).strip()}


def main() -> int:
    return esegui_app("dischi", "Dischi/Main.qml", lambda app: {"ponte": crea_ponte(BackendDischi())})


if __name__ == "__main__":
    sys.exit(main())
