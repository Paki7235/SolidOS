"""Accesso alle partizioni Windows (per Salvataggio e Migrazione)."""

from __future__ import annotations

import json
import re
from pathlib import Path

from .sistema import esegui, uscita

CARTELLE_UTENTE = [("Desktop", "Scrivania", "DESKTOP"), ("Documents", "Documenti", "DOCUMENTS"),
                   ("Pictures", "Immagini", "PICTURES"), ("Music", "Musica", "MUSIC"),
                   ("Videos", "Video", "VIDEOS"), ("Downloads", "Scaricati", "DOWNLOAD")]
ESCLUSI = {"Public", "Default", "Default User", "All Users", "desktop.ini", "WDAGUtilityAccount"}


def partizioni() -> list[dict]:
    try:
        dati = json.loads(uscita(["lsblk", "-J", "-b", "-o", "PATH,FSTYPE,LABEL,SIZE,MOUNTPOINTS,TYPE"]) or "{}")
    except json.JSONDecodeError:
        return []
    risultato = []

    def visita(dispositivi):
        for d in dispositivi:
            if d.get("fstype") in ("ntfs", "BitLocker"):
                punti = [m for m in (d.get("mountpoints") or []) if m]
                risultato.append({"percorso": d["path"], "fs": d["fstype"], "etichetta": d.get("label") or "",
                                  "dimensione": round(int(d.get("size") or 0) / 1e9, 1),
                                  "montata": punti[0] if punti else "",
                                  "bitlocker": d["fstype"] == "BitLocker"})
            visita(d.get("children") or [])

    visita(dati.get("blockdevices", []))
    return risultato


def sblocca_bitlocker(percorso: str, chiave: str) -> dict:
    r = esegui(["udisksctl", "unlock", "-b", percorso, "--key-file", "/dev/stdin"], ingresso=chiave.strip(), timeout=60)
    m = re.search(r"as (/dev/\S+)", r.stdout)
    return {"ok": r.returncode == 0, "dispositivo": m.group(1).rstrip(".") if m else "", "messaggio": r.stderr.strip()}


def monta(percorso: str, sola_lettura: bool = True) -> dict:
    for p in partizioni():
        if p["percorso"] == percorso and p["montata"]:
            return {"ok": True, "punto": p["montata"]}
    cmd = ["udisksctl", "mount", "-b", percorso]
    if sola_lettura:
        cmd += ["-o", "ro"]
    r = esegui(cmd, timeout=60)
    m = re.search(r"at (\S+)", r.stdout)
    if r.returncode != 0 or not m:
        messaggio = r.stderr.strip()
        if "hibernat" in messaggio.lower() or "dirty" in messaggio.lower():
            messaggio = "Windows è in ibernazione o con «avvio rapido» attivo: apertura in sola lettura non riuscita."
        return {"ok": False, "messaggio": messaggio}
    return {"ok": True, "punto": m.group(1).rstrip(".")}


def e_windows(punto: str) -> bool:
    return (Path(punto) / "Windows" / "System32").is_dir() or (Path(punto) / "Users").is_dir()


def utenti(punto: str) -> list[dict]:
    base = Path(punto) / "Users"
    if not base.is_dir():
        return []
    risultato = []
    for d in sorted(base.iterdir()):
        if d.is_dir() and d.name not in ESCLUSI and not d.name.startswith("."):
            risultato.append({"nome": d.name, "percorso": str(d)})
    return risultato


def dimensione(percorso: Path, limite_file: int = 200000) -> int:
    totale, conteggio = 0, 0
    for f in percorso.rglob("*"):
        try:
            if f.is_file() and not f.is_symlink():
                totale += f.stat().st_size
                conteggio += 1
                if conteggio > limite_file:
                    break
        except OSError:
            continue
    return totale


def cartelle_utente(percorso_utente: str) -> list[dict]:
    base = Path(percorso_utente)
    risultato = []
    for originale, italiano, xdg in CARTELLE_UTENTE:
        p = base / originale
        if p.is_dir():
            risultato.append({"id": originale, "nome": italiano, "xdg": xdg, "percorso": str(p),
                              "dimensione": round(dimensione(p) / 1048576)})
    return risultato
