"""App Salvataggio (procedura guidata)."""

import json
import sys

from .. import branding, windows
from ..copia import copia
from ..i18n import T
from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app
from ..sistema import avvia, esegui, helper, uscita


class BackendSalvataggio(Backend):
    # ── Recupero file ───────────────────────────────────────────────────────
    def partizioni(self) -> list:
        return windows.partizioni()

    def sblocca(self, percorso: str, chiave: str) -> dict:
        return windows.sblocca_bitlocker(percorso, chiave)

    def apri(self, percorso: str) -> dict:
        r = windows.monta(percorso, sola_lettura=True)
        if r["ok"]:
            r["windows"] = windows.e_windows(r["punto"])
            r["utenti"] = windows.utenti(r["punto"])
        return r

    def cartelle(self, percorso_utente: str) -> list:
        return windows.cartelle_utente(percorso_utente)

    def destinazioni(self) -> list:
        """Dischi esterni montati e scrivibili (escluso quello dell'altro sistema)."""
        import os
        from pathlib import Path

        risultato = []
        for base in (Path("/media") / os.environ.get("USER", ""), Path("/run/media") / os.environ.get("USER", "")):
            if base.is_dir():
                for d in base.iterdir():
                    if d.is_dir() and os.access(d, os.W_OK) and not windows.e_windows(str(d)):
                        risultato.append({"percorso": str(d), "nome": d.name})
        return risultato

    def copia(self, sorgenti: list, destinazione: str) -> dict:
        from pathlib import Path

        cartella = Path(destinazione) / T("File recuperati")
        r = copia(list(sorgenti), str(cartella), lambda f, t, n: self.emetti("avanzamento", {"fatto": f, "totale": t, "nome": n}))
        r["cartella"] = str(cartella)
        return r

    def inviaTelefono(self, sorgenti: list) -> None:
        avvia([branding.comando("condividi"), *sorgenti])

    # ── Diagnosi ────────────────────────────────────────────────────────────
    def dischi(self) -> list:
        try:
            dati = json.loads(uscita(["lsblk", "-J", "-d", "-b", "-o", "PATH,MODEL,SIZE,TYPE,TRAN,RM"]) or "{}")
        except json.JSONDecodeError:
            return []
        return [{"percorso": d["path"], "modello": (d.get("model") or "").strip() or d["path"],
                 "dimensione": round(int(d.get("size") or 0) / 1e9, 1), "rimovibile": bool(d.get("rm"))}
                for d in dati.get("blockdevices", []) if d.get("type") == "disk" and not d["path"].startswith(("/dev/zram", "/dev/loop", "/dev/sr"))]

    def salute(self, disco: str) -> dict:
        r = helper("smart", disco, timeout=120)
        try:
            d = json.loads(r.stdout)
        except json.JSONDecodeError:
            return {"ok": False, "messaggio": T("Questo disco non fornisce dati SMART")}
        attributi = {a.get("name"): a.get("raw", {}).get("value") for a in d.get("ata_smart_attributes", {}).get("table", [])}
        return {"ok": True, "superato": d.get("smart_status", {}).get("passed"),
                "ore": d.get("power_on_time", {}).get("hours"), "temperatura": d.get("temperature", {}).get("current"),
                "settoriRiallocati": attributi.get("Reallocated_Sector_Ct", 0),
                "settoriInSospeso": attributi.get("Current_Pending_Sector", 0)}

    def testRam(self, megabyte: int = 256) -> dict:
        r = esegui(["memtester", f"{int(megabyte)}M", "1"], timeout=1800)
        return {"ok": r.returncode == 0,
                "messaggio": T("Nessun errore trovato nella memoria provata") if r.returncode == 0
                else T("Trovati errori nella memoria: la RAM potrebbe essere guasta")}

    def clona(self, sorgente: str, destinazione: str) -> dict:
        r = helper("clona", sorgente, destinazione, timeout=86400)
        return {"ok": r.returncode == 0, "messaggio": r.stderr.strip()[-300:]}

    # ── Password dell'altro sistema ────────────────────────────────────────────────────
    def utentiWindows(self, partizione: str) -> dict:
        r = helper("windows-utenti", partizione, timeout=120)
        if r.returncode != 0:
            return {"ok": False, "messaggio": r.stderr.strip()}
        return {"ok": True, "utenti": [u for u in r.stdout.splitlines() if u.strip()]}

    def resetPassword(self, partizione: str, utente: str) -> dict:
        r = helper("windows-password", partizione, utente, timeout=120)
        return {"ok": r.returncode == 0, "messaggio": r.stdout.strip() or r.stderr.strip()}

    def riavvia(self) -> None:
        esegui(["systemctl", "reboot"])


def main() -> int:
    return esegui_app("salvataggio", "Salvataggio/Main.qml", lambda app: {"ponte": crea_ponte(BackendSalvataggio())})


if __name__ == "__main__":
    sys.exit(main())
