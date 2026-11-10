"""Spazi di vita: Lavoro, Studio, Gioco, Famiglia… ognuno con app, notifiche, sfondo,
cartelle in evidenza, profilo energetico e rete/VPN propri. Il cambio è immediato.

Ogni Spazio è un file TOML in ~/.config/<OS_ID>/spazi/ (modelli in /usr/share/nucleo/spazi).
"""

from __future__ import annotations

import configparser
import os
import re
import shutil
import tomllib
from pathlib import Path

from .. import branding
from ..i18n import T
from ..sistema import avvia, config_utente, esegui, notifica

PREDEFINITI = Path("/usr/share/nucleo/spazi")


def cartella() -> Path:
    c = config_utente("spazi", "x").parent
    if not any(c.glob("*.toml")) and PREDEFINITI.is_dir():
        for f in PREDEFINITI.glob("*.toml"):
            shutil.copy(f, c / f.name)
    return c


def file_spazio(ident: str) -> Path:
    return cartella() / f"{Path(ident).name}.toml"


def leggi(ident: str) -> dict:
    try:
        # «@ID@» nei file degli Spazi = identificativo del sistema (app proprie, es. <id>-foto.desktop)
        dati = tomllib.loads(file_spazio(ident).read_text(encoding="utf-8").replace("@ID@", branding.id_os()))
    except (OSError, tomllib.TOMLDecodeError):
        return {}
    dati["id"] = ident
    return dati


def elenco_spazi() -> list[dict]:
    risultato = []
    for f in sorted(cartella().glob("*.toml")):
        s = leggi(f.stem)
        if s:
            risultato.append({"id": f.stem, "nome": s.get("nome", f.stem), "icona": s.get("icona", ""),
                              "descrizione": s.get("descrizione", ""), "ordine": s.get("ordine", 50)})
    return sorted(risultato, key=lambda s: (s["ordine"], s["nome"]))


def spazio_corrente() -> dict:
    f = config_utente("spazio-corrente")
    ident = f.read_text().strip() if f.exists() else ""
    if not ident:
        return {}
    s = leggi(ident)
    return {"id": ident, "nome": s.get("nome", ident), "icona": s.get("icona", "")} if s else {}


def crea(nome: str) -> str:
    ident = re.sub(r"[^a-z0-9]+", "-", nome.lower()).strip("-") or "spazio"
    file_spazio(ident).write_text(
        f'nome = "{nome}"\nicona = "user-desktop"\ndescrizione = ""\nordine = 60\n'
        '# sfondo = "/percorso/immagine.jpg"\n'
        'app = ["@ID@-file.desktop", "@ID@-web.desktop"]\n'
        'cartelle = []\nenergia = "balanced"\n\n[notifiche]\nnon_disturbare = false\nconsentite = []\n\n'
        '[rete]\nconnessione = ""\nvpn = ""\n', encoding="utf-8")
    return ident


# ── Applicazione ─────────────────────────────────────────────────────────────
def _sfondo(percorso: str):
    from ..sistema import SFONDO_INIZIALE, imposta_sfondo

    if not (percorso and Path(percorso).exists()):
        percorso = SFONDO_INIZIALE.format(id=branding.id_os())
    imposta_sfondo(percorso)


def _app_pannello(app: list[str]):
    file = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "lxqt" / "panel.conf"
    file.parent.mkdir(parents=True, exist_ok=True)
    if not file.exists() and Path("/etc/xdg/lxqt/panel.conf").exists():
        shutil.copy("/etc/xdg/lxqt/panel.conf", file)
    c = configparser.RawConfigParser(strict=False)
    c.optionxform = str
    c.read(file, encoding="utf-8")
    if not c.has_section("quicklaunch"):
        c.add_section("quicklaunch")
    for chiave in list(c["quicklaunch"]):
        if chiave.startswith("apps\\"):
            c.remove_option("quicklaunch", chiave)
    c.set("quicklaunch", "type", "quicklaunch")
    trovate = 0
    for desktop in app:
        for base in (Path.home() / ".local/share/applications", Path("/usr/share/applications"),
                     Path("/var/lib/flatpak/exports/share/applications")):
            if (base / desktop).exists():
                trovate += 1
                c.set("quicklaunch", f"apps\\{trovate}\\desktop", str(base / desktop))
                break
    c.set("quicklaunch", "apps\\size", str(trovate))
    with open(file, "w", encoding="utf-8") as f:
        c.write(f, space_around_delimiters=False)
    esegui(["pkill", "-x", "lxqt-panel"])
    avvia(["lxqt-panel"])


def _cartelle(cartelle: list[str]):
    """Cartelle in evidenza nel file manager (segnalibri)."""
    segnalibri = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "gtk-3.0" / "bookmarks"
    segnalibri.parent.mkdir(parents=True, exist_ok=True)
    originale = config_utente("segnalibri-originali")
    if segnalibri.exists() and not originale.exists():
        shutil.copy(segnalibri, originale)
    righe = originale.read_text().splitlines() if originale.exists() else []
    for c in cartelle:
        p = Path(os.path.expanduser(c))
        p.mkdir(parents=True, exist_ok=True)
        righe.insert(0, f"file://{p} {p.name}")
    segnalibri.write_text("\n".join(dict.fromkeys(righe)) + "\n")


def _notifiche(non_disturbare: bool, consentite: list[str]):
    from ..dbusutil import chiama

    nome = branding.nome_dbus("Shell")
    percorso = branding.percorso_dbus("Shell")
    chiama(nome, percorso, nome, "NonDisturbare", bool(non_disturbare))
    import dbus

    chiama(nome, percorso, nome, "FiltroApp", dbus.Array(consentite, signature="s"))


def _rete(connessione: str, vpn: str):
    from ..hw import rete

    if connessione:
        rete.attiva_connessione(connessione, True)
    for v in rete.vpn():
        if v["nome"] == vpn and not v["attiva"]:
            rete.attiva_connessione(v["uuid"], True)
        elif v["nome"] != vpn and v["attiva"]:
            rete.attiva_connessione(v["uuid"], False)


def attiva(ident: str, silenzioso: bool = False) -> bool:
    s = leggi(ident)
    if not s:
        return False
    passi = [
        lambda: _sfondo(s.get("sfondo", "")),
        lambda: _app_pannello(s.get("app", [])) if s.get("app") else None,
        lambda: _cartelle(s.get("cartelle", [])),
        lambda: _notifiche(s.get("notifiche", {}).get("non_disturbare", False), s.get("notifiche", {}).get("consentite", [])),
        lambda: esegui(["powerprofilesctl", "set", s["energia"]]) if s.get("energia") else None,
        lambda: _rete(s.get("rete", {}).get("connessione", ""), s.get("rete", {}).get("vpn", "")),
    ]
    for passo in passi:
        try:
            passo()
        except Exception:  # noqa: BLE001 — un passo non riuscito non blocca gli altri
            pass
    config_utente("spazio-corrente").write_text(ident)
    if not silenzioso:
        notifica(T("Spazio «{n}» attivo", n=s.get("nome", ident)), s.get("descrizione", ""), icona=s.get("icona", ""))
    return True


def main() -> int:
    import sys

    argomenti = sys.argv[1:]
    if not argomenti or argomenti[0] == "elenco":
        for s in elenco_spazi():
            print(f'{s["id"]}\t{s["nome"]}')
        return 0
    if argomenti[0] == "attiva" and len(argomenti) > 1:
        return 0 if attiva(argomenti[1]) else 1
    if argomenti[0] == "ripristina":
        corrente = spazio_corrente()
        if corrente:
            attiva(corrente["id"], silenzioso=True)
        return 0
    print("uso: spazi [elenco | attiva ID | ripristina]")
    return 1
