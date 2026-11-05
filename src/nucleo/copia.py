"""Copia di file e cartelle con avanzamento (senza sovrascrivere)."""

from __future__ import annotations

import os
import shutil
from pathlib import Path


def conta(sorgenti: list[str]) -> int:
    totale = 0
    for s in sorgenti:
        p = Path(s)
        if p.is_file():
            totale += p.stat().st_size
        else:
            for f in p.rglob("*"):
                try:
                    if f.is_file() and not f.is_symlink():
                        totale += f.stat().st_size
                except OSError:
                    pass
    return totale


def copia(sorgenti: list[str], destinazione: str, avanzamento=lambda fatto, totale, nome: None) -> dict:
    """Copia ricorsiva; i file illeggibili vengono saltati e conteggiati."""
    totale = conta(sorgenti) or 1
    fatto, errori, copiati = 0, [], 0
    dest = Path(destinazione)
    dest.mkdir(parents=True, exist_ok=True)
    for s in sorgenti:
        sorgente = Path(s)
        radice = dest / sorgente.name
        elementi = [sorgente] if sorgente.is_file() else [f for f in sorgente.rglob("*") if f.is_file() and not f.is_symlink()]
        for f in elementi:
            relativo = Path(f.name) if sorgente.is_file() else Path(sorgente.name) / f.relative_to(sorgente)
            obiettivo = dest / relativo
            if obiettivo.exists():
                base, est = os.path.splitext(obiettivo.name)
                n = 1
                while obiettivo.exists():
                    obiettivo = obiettivo.with_name(f"{base} ({n}){est}")
                    n += 1
            try:
                obiettivo.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(f, obiettivo)
                copiati += 1
                fatto += f.stat().st_size
            except OSError as e:
                errori.append(f"{f}: {e.strerror}")
            avanzamento(fatto, totale, f.name)
        del radice
    return {"ok": not errori or copiati > 0, "copiati": copiati, "errori": len(errori), "dettaglio_errori": errori[:20]}
