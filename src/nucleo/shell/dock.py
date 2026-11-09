"""Dati del dock: app fissate (config utente) e collegamento tra finestre e voci .desktop."""

from __future__ import annotations

import configparser
from functools import lru_cache
from pathlib import Path

from .. import branding
from ..sistema import config_utente, leggi_json, scrivi_json

CARTELLE = [Path.home() / ".local/share/applications", Path("/usr/share/applications"),
            Path("/var/lib/flatpak/exports/share/applications"),
            Path.home() / ".local/share/flatpak/exports/share/applications"]


def predefinite() -> list[str]:
    i = branding.id_os()
    return [f"{i}-file", "firefox-esr", "qterminal", f"{i}-store", f"{i}-linea-del-tempo",
            f"{i}-condividi", f"{i}-monitor", f"{i}-impostazioni"]


def fissate() -> list[str]:
    elenco = leggi_json(config_utente("dock.json"), {}).get("fissate")
    return [d for d in (elenco if isinstance(elenco, list) else predefinite()) if info(d)]


def fissa(desktop: str, si: bool) -> list[str]:
    elenco = fissate()
    if si and desktop not in elenco and info(desktop):
        elenco.append(desktop)
    if not si and desktop in elenco:
        elenco.remove(desktop)
    scrivi_json(config_utente("dock.json"), {"fissate": elenco})
    return elenco


def ordina(ordine: list[str]) -> list[str]:
    """Salva l'ordine delle app fissate; un'app aperta trascinata tra le fissate viene fissata."""
    elenco = [d for d in ordine if info(d)]
    scrivi_json(config_utente("dock.json"), {"fissate": elenco})
    return elenco


@lru_cache(maxsize=256)
def info(desktop: str) -> dict | None:
    """Nome e icona di una voce .desktop (senza estensione); None se non esiste."""
    nome_file = desktop if desktop.endswith(".desktop") else desktop + ".desktop"
    for cartella in CARTELLE:
        percorso = cartella / nome_file
        if not percorso.is_file():
            continue
        c = configparser.RawConfigParser(strict=False, interpolation=None)
        try:
            c.read(percorso, encoding="utf-8")
            voce = c["Desktop Entry"]
        except (configparser.Error, KeyError, UnicodeDecodeError):
            return None
        return {"id": nome_file[:-8], "nome": voce.get("Name[it]") or voce.get("Name", desktop),
                "icona": voce.get("Icon", "application-x-executable"),
                "wmclass": voce.get("StartupWMClass", "")}
    return None


@lru_cache(maxsize=256)
def desktop_per_app_id(app_id: str) -> str:
    """Trova la voce .desktop di una finestra dal suo app_id Wayland."""
    if not app_id:
        return ""
    for candidato in (app_id, app_id.lower(), app_id.split(".")[-1].lower()):
        if info(candidato):
            return candidato
    for cartella in CARTELLE:
        if not cartella.is_dir():
            continue
        for f in cartella.glob("*.desktop"):
            dati = info(f.stem)
            if dati and dati["wmclass"] and dati["wmclass"].lower() == app_id.lower():
                return f.stem
    return ""


def voci(finestre: list[dict]) -> list[dict]:
    """Icone del dock: prima le fissate, poi le altre app aperte; con le finestre di ognuna."""
    per_app: dict[str, list[dict]] = {}
    for f in finestre:
        chiave = desktop_per_app_id(f.get("appId", "")) or ("finestra:" + (f.get("appId") or str(f["id"])))
        per_app.setdefault(chiave, []).append(f)
    risultato = []
    elenco_fissate = fissate()
    for d in elenco_fissate:
        dati = info(d)
        risultato.append({**dati, "fissata": True, "finestre": per_app.pop(d, [])})
    for chiave, gruppo in per_app.items():
        dati = info(chiave) if not chiave.startswith("finestra:") else None
        if dati is None:
            titolo = gruppo[0].get("titolo") or gruppo[0].get("appId") or "?"
            dati = {"id": chiave, "nome": titolo, "icona": gruppo[0].get("appId") or "application-x-executable", "wmclass": ""}
        risultato.append({**dati, "fissata": False, "finestre": gruppo})
    for r in risultato:
        r["aperta"] = len(r["finestre"]) > 0
        r["attiva"] = any(f.get("attiva") for f in r["finestre"])
    return risultato


def tutte_le_app() -> list[dict]:
    """Tutte le app installate (per il menu Start), in ordine alfabetico."""
    viste, app = set(), []
    for cartella in CARTELLE:
        if not cartella.is_dir():
            continue
        for f in sorted(cartella.glob("*.desktop")):
            if f.stem in viste:
                continue
            viste.add(f.stem)
            c = configparser.RawConfigParser(strict=False, interpolation=None)
            try:
                c.read(f, encoding="utf-8")
                v = c["Desktop Entry"]
            except (configparser.Error, KeyError, UnicodeDecodeError):
                continue
            if v.get("Type", "Application") != "Application" or v.get("NoDisplay", "").lower() == "true" \
                    or v.get("Hidden", "").lower() == "true" or "OnlyShowIn" in v:
                continue
            app.append({"id": f.stem, "nome": v.get("Name[it]") or v.get("Name", f.stem),
                        "icona": v.get("Icon", "application-x-executable"),
                        "descrizione": v.get("Comment[it]") or v.get("Comment", ""),
                        "chiavi": (v.get("Keywords[it]") or v.get("Keywords", "")) + " " + v.get("GenericName", "")})
    app.sort(key=lambda a: a["nome"].lower())
    return app
