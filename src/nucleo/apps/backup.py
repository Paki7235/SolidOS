"""Backup: copie cifrate e incrementali con restic su disco esterno o cartella."""

from __future__ import annotations

import json
import os
import secrets
import subprocess
import sys
from pathlib import Path

from ..i18n import T
from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app
from ..sistema import config_utente, esegui, leggi_json, notifica, scrivi_json

CONFIG = "backup.json"


class BackendBackup(Backend):
    def configurazione(self) -> dict:
        predefinita = {"destinazione": "", "cartelle": [str(Path.home())],
                       "escludi": [".cache", "Scaricati/*.iso", ".local/share/Trash"]}
        return leggi_json(config_utente(CONFIG), predefinita)

    def _chiave(self) -> Path:
        file = config_utente("backup.chiave")
        if not file.exists():
            file.write_text(secrets.token_urlsafe(24))
            os.chmod(file, 0o600)
        return file

    def chiaveRipristino(self) -> str:
        return self._chiave().read_text().strip()

    def _ambiente(self) -> dict:
        conf = self.configurazione()
        return {"RESTIC_REPOSITORY": str(Path(conf["destinazione"]) / "backup-restic"),
                "RESTIC_PASSWORD_FILE": str(self._chiave())}

    def destinazioniPossibili(self) -> list[dict]:
        risultato = []
        for base in (Path("/media") / os.environ.get("USER", ""), Path("/run/media") / os.environ.get("USER", "")):
            if base.is_dir():
                for d in base.iterdir():
                    if d.is_dir():
                        risultato.append({"percorso": str(d), "nome": d.name})
        return risultato

    def imposta(self, destinazione: str, cartelle: list) -> dict:
        conf = self.configurazione()
        conf["destinazione"] = destinazione.removeprefix("file://")
        conf["cartelle"] = [c.removeprefix("file://") for c in cartelle] or conf["cartelle"]
        scrivi_json(config_utente(CONFIG), conf)
        repo = Path(self._ambiente()["RESTIC_REPOSITORY"])
        if not (repo / "config").exists():
            r = esegui(["restic", "init"], ambiente=self._ambiente(), timeout=120)
            if r.returncode != 0:
                return {"ok": False, "messaggio": r.stderr.strip()}
        return {"ok": True, "chiave": self.chiaveRipristino()}

    def esegui(self) -> dict:
        conf = self.configurazione()
        if not conf.get("destinazione"):
            return {"ok": False, "messaggio": T("Scegli prima dove salvare il backup.")}
        cmd = ["restic", "backup", "--json", *conf["cartelle"]]
        for e in conf.get("escludi", []):
            cmd += ["--exclude", e]
        env = dict(os.environ, **self._ambiente())
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=env)
        riepilogo = {}
        for riga in proc.stdout:
            try:
                dati = json.loads(riga)
            except json.JSONDecodeError:
                continue
            if dati.get("message_type") == "status":
                self.emetti("avanzamento", round(dati.get("percent_done", 0) * 100))
            elif dati.get("message_type") == "summary":
                riepilogo = dati
        proc.wait()
        ok = proc.returncode == 0
        if ok:
            notifica(T("Backup completato"), T("{n} file salvati", n=riepilogo.get("total_files_processed", 0)),
                     icona="drive-harddisk")
        return {"ok": ok, "messaggio": "" if ok else proc.stderr.read().strip()}

    def istantanee(self) -> list[dict]:
        r = esegui(["restic", "snapshots", "--json"], ambiente=self._ambiente(), timeout=120)
        try:
            dati = json.loads(r.stdout or "[]")
        except json.JSONDecodeError:
            return []
        return [{"id": s["short_id"], "data": s["time"][:16].replace("T", " "),
                 "cartelle": ", ".join(s.get("paths", []))} for s in reversed(dati)]

    def ripristina(self, ident: str, destinazione: str) -> dict:
        destinazione = destinazione.removeprefix("file://") or str(Path.home() / T("Ripristinati"))
        r = esegui(["restic", "restore", ident, "--target", destinazione],
                   ambiente=self._ambiente(), timeout=7200)
        return {"ok": r.returncode == 0, "cartella": destinazione, "messaggio": r.stderr.strip()}


def main() -> int:
    return esegui_app("backup", "Backup/Main.qml", lambda app: {"ponte": crea_ponte(BackendBackup())})


if __name__ == "__main__":
    sys.exit(main())
