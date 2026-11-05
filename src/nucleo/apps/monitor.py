"""Monitor di sistema: CPU, memoria, dischi, rete e processi."""

from __future__ import annotations

import os
import signal
import sys
import time

import psutil

from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app


class BackendMonitor(Backend):
    def __init__(self):
        self._rete_prec = psutil.net_io_counters()
        self._tempo_prec = time.monotonic()
        psutil.cpu_percent(percpu=True)
        for p in psutil.process_iter():
            try:
                p.cpu_percent()
            except psutil.Error:
                pass

    def istantanea(self, ordina: str = "cpu", filtro: str = "") -> dict:
        mem = psutil.virtual_memory()
        swap = psutil.swap_memory()
        rete = psutil.net_io_counters()
        ora = time.monotonic()
        intervallo = max(ora - self._tempo_prec, 0.1)
        giu = (rete.bytes_recv - self._rete_prec.bytes_recv) / intervallo
        su = (rete.bytes_sent - self._rete_prec.bytes_sent) / intervallo
        self._rete_prec, self._tempo_prec = rete, ora

        processi = []
        filtro = filtro.lower()
        for p in psutil.process_iter(["pid", "name", "username", "memory_info"]):
            try:
                nome = p.info["name"] or "?"
                if filtro and filtro not in nome.lower():
                    continue
                processi.append({
                    "pid": p.info["pid"], "nome": nome, "utente": p.info["username"] or "",
                    "cpu": round(p.cpu_percent() / max(psutil.cpu_count() or 1, 1), 1),
                    "memoria": round((p.info["memory_info"].rss if p.info["memory_info"] else 0) / 1048576, 1),
                    "mio": p.info["username"] == os.environ.get("USER"),
                })
            except psutil.Error:
                continue
        chiave = {"cpu": "cpu", "memoria": "memoria", "nome": "nome"}.get(ordina, "cpu")
        processi.sort(key=lambda x: x[chiave], reverse=chiave != "nome")

        dischi = []
        for part in psutil.disk_partitions():
            if part.mountpoint.startswith(("/snap", "/run/live", "/boot/efi")):
                continue
            try:
                uso = psutil.disk_usage(part.mountpoint)
            except OSError:
                continue
            dischi.append({"punto": part.mountpoint, "fs": part.fstype,
                           "totale": round(uso.total / 1e9, 1), "usato": round(uso.used / 1e9, 1),
                           "percentuale": uso.percent})
        return {
            "cpu": psutil.cpu_percent(),
            "cpuCore": psutil.cpu_percent(percpu=True),
            "memoria": {"totale": round(mem.total / 1048576), "usata": round((mem.total - mem.available) / 1048576),
                        "percentuale": mem.percent},
            "swap": {"totale": round(swap.total / 1048576), "usata": round(swap.used / 1048576)},
            "rete": {"giu": round(giu / 1024, 1), "su": round(su / 1024, 1)},
            "dischi": dischi,
            "processi": processi[:150],
            "avvio": time.strftime("%d/%m %H:%M", time.localtime(psutil.boot_time())),
        }

    def termina(self, pid: int, forza: bool = False) -> bool:
        try:
            os.kill(int(pid), signal.SIGKILL if forza else signal.SIGTERM)
            return True
        except OSError:
            return False


def main() -> int:
    return esegui_app("monitor", "Monitor/Main.qml", lambda app: {"ponte": crea_ponte(BackendMonitor())})


if __name__ == "__main__":
    sys.exit(main())
