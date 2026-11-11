"""Gestore attività: processi, processore, memoria, disco e rete."""

from __future__ import annotations

import os
import signal
import sys
import time

import psutil

from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app

# Nomi leggibili per i processi più comuni del sistema
NOMI = {
    "labwc": "Compositor grafico", "Xwayland": "Compatibilità X11", "pipewire": "Audio",
    "pipewire-pulse": "Audio (compatibilità)", "wireplumber": "Audio (sessione)",
    "NetworkManager": "Gestore di rete", "lxqt-panel": "Pannello (vecchio)", "swaybg": "Sfondo",
    "firefox-esr": "Browser", "pcmanfm-qt": "File", "qterminal": "Terminale",
    "systemd": "Servizi di sistema", "dbus-daemon": "Bus di sistema", "greetd": "Accesso",
    "Xorg": "Server grafico", "bluetoothd": "Bluetooth", "avahi-daemon": "Rete locale",
}


class BackendMonitor(Backend):
    def __init__(self):
        self._prec = (time.monotonic(), psutil.net_io_counters(), psutil.disk_io_counters())
        self._io_prec: dict[int, tuple[float, int]] = {}
        psutil.cpu_percent()
        psutil.cpu_times_percent()
        for p in psutil.process_iter():
            try:
                p.cpu_percent()
            except psutil.Error:
                pass

    @staticmethod
    def _nome(p_info: dict) -> str:
        nome = p_info.get("name") or "?"
        cmd = p_info.get("cmdline") or []
        # Le app di sistema sono «python3 -m nucleo.<app>»: si mostra il nome dell'app
        if nome.startswith("python") and len(cmd) >= 3 and cmd[1] == "-m" and cmd[2].startswith("nucleo"):
            parte = cmd[2].split(".")[-1].replace("__main__", "")
            etichette = {"shell": "Shell del sistema", "monitor": "Gestore attività", "impostazioni": "Impostazioni",
                         "condivisione": "Condivisione Vicina", "store": "App", "lineadeltempo": "Linea del Tempo"}
            return etichette.get(parte, parte.capitalize() or "Sistema")
        return NOMI.get(nome, nome)

    def istantanea(self, scheda: str = "cpu", filtro: str = "") -> dict:
        ora = time.monotonic()
        rete, disco = psutil.net_io_counters(), psutil.disk_io_counters()
        dt = max(ora - self._prec[0], 0.2)
        rete_giu = (rete.bytes_recv - self._prec[1].bytes_recv) / dt
        rete_su = (rete.bytes_sent - self._prec[1].bytes_sent) / dt
        disco_l = (disco.read_bytes - self._prec[2].read_bytes) / dt if disco and self._prec[2] else 0
        disco_s = (disco.write_bytes - self._prec[2].write_bytes) / dt if disco and self._prec[2] else 0
        self._prec = (ora, rete, disco)

        mio = os.environ.get("USER")
        ncpu = max(psutil.cpu_count() or 1, 1)
        filtro = filtro.lower()
        processi, io_nuovo = [], {}
        for p in psutil.process_iter(["pid", "name", "username", "memory_info", "num_threads", "cmdline", "cpu_times"]):
            try:
                info = p.info
                if not info["cmdline"] and info["username"] == "root":
                    continue   # thread del kernel: non interessano all'utente
                nome = self._nome(info)
                if filtro and filtro not in nome.lower() and filtro not in (info["name"] or "").lower():
                    continue
                disco_proc = 0.0
                if scheda == "disco" and info["username"] == mio:
                    try:
                        io = p.io_counters()
                        totale = io.read_bytes + io.write_bytes
                        prima = self._io_prec.get(info["pid"])
                        if prima:
                            disco_proc = max(totale - prima[1], 0) / max(ora - prima[0], 0.2)
                        io_nuovo[info["pid"]] = (ora, totale)
                    except (psutil.Error, OSError):
                        pass
                tempo = sum(info["cpu_times"][:2]) if info["cpu_times"] else 0
                processi.append({
                    "pid": info["pid"], "nome": nome, "utente": info["username"] or "",
                    "cpu": round(p.cpu_percent() / ncpu, 1),
                    "memoria": round((info["memory_info"].rss if info["memory_info"] else 0) / 1048576, 1),
                    "thread": info["num_threads"] or 0,
                    "tempo": "%d:%05.2f" % (tempo // 60, tempo % 60),
                    "disco": round(disco_proc / 1024, 1),
                    "mio": info["username"] == mio,
                })
            except psutil.Error:
                continue
        if scheda == "disco":
            self._io_prec = io_nuovo
        chiave = {"cpu": "cpu", "memoria": "memoria", "disco": "disco", "rete": "cpu"}.get(scheda, "cpu")
        processi.sort(key=lambda x: x[chiave], reverse=True)

        tempi = psutil.cpu_times_percent()
        mem = psutil.virtual_memory()
        swap = psutil.swap_memory()
        interfacce = []
        for nome_if, st in psutil.net_if_stats().items():
            if nome_if == "lo" or not st.isup:
                continue
            interfacce.append({"nome": nome_if, "velocita": st.speed})
        return {
            "cpu": psutil.cpu_percent(),
            "sistema": round(tempi.system, 1), "utente": round(tempi.user + getattr(tempi, "nice", 0), 1),
            "inattivo": round(tempi.idle, 1),
            "numeroProcessi": len(processi),
            "memoria": {"totale": round(mem.total / 1073741824, 1), "usata": round((mem.total - mem.available) / 1073741824, 1),
                        "app": round((mem.total - mem.available) / mem.total * 100, 1),
                        "compressa": round(swap.used / mem.total * 100, 1), "swapMB": round(swap.used / 1048576)},
            "rete": {"giu": round(rete_giu / 1048576, 2), "su": round(rete_su / 1048576, 2),
                     "ricevuti": round(rete.bytes_recv / 1073741824, 2), "inviati": round(rete.bytes_sent / 1073741824, 2),
                     "interfacce": interfacce},
            "disco": {"lettura": round(disco_l / 1048576, 1), "scrittura": round(disco_s / 1048576, 1)},
            "processi": processi[:200],
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
