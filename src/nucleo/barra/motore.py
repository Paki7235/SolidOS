"""Motore della Barra Unica: cerca app, impostazioni, file ed esegue azioni scritte
in linguaggio semplice. Funziona offline e senza intelligenza artificiale.

Le azioni sono dichiarate in file TOML (/usr/share/nucleo/azioni/*.toml e
~/.config/<OS_ID>/azioni/*.toml), ad esempio:

    [[azione]]
    id = "wifi-off"
    titolo = "Spegni il Wi-Fi"
    icona = "network-wireless-offline"
    frasi = ["wifi off", "spegni wifi", "disattiva wifi"]
    comando = ["nmcli", "radio", "wifi", "off"]

Le frasi possono contenere parametri: "installa {app}", "converti {file} in pdf".
Un'azione può usare «interno = "nome"» per i comportamenti predefiniti (installa,
invia, spazio, cerca sul web…).
"""

from __future__ import annotations

import ast
import configparser
import difflib
import operator
import re
import tomllib
import unicodedata
from functools import lru_cache
from pathlib import Path

from .. import branding
from ..i18n import T
from ..sistema import avvia, avvia_desktop, config_utente, esegui, notifica, uscita

SINONIMI = {
    "wi-fi": "wifi", "wlan": "wifi", "wireless": "wifi", "internet": "wifi",
    "spegni": "off", "disattiva": "off", "disabilita": "off", "togli": "off", "chiudi": "off",
    "accendi": "on", "attiva": "on", "abilita": "on", "metti": "on",
    "alza": "su", "aumenta": "su", "piu": "su", "abbassa": "giu", "diminuisci": "giu", "meno": "giu",
    "telefonino": "telefono", "cellulare": "telefono", "smartphone": "telefono", "iphone": "telefono",
    "android": "telefono", "schermata": "screenshot", "foto dello schermo": "screenshot",
    "programma": "app", "applicazione": "app",
}


def normalizza(testo: str) -> str:
    t = unicodedata.normalize("NFD", testo.lower().strip())
    t = "".join(c for c in t if unicodedata.category(c) != "Mn")
    t = re.sub(r"[^\w\s{}./~-]", " ", t)
    for parola, sinonimo in sorted(SINONIMI.items(), key=lambda x: -len(x[0])):
        t = re.sub(rf"\b{re.escape(parola)}\b", sinonimo, t)
    return re.sub(r"\s+", " ", t).strip()


# ── Azioni ───────────────────────────────────────────────────────────────────
@lru_cache(maxsize=1)
def azioni() -> list[dict]:
    elenco = []
    for cartella in (Path("/usr/share/nucleo/azioni"), Path(__file__).resolve().parents[2] / "dati" / "azioni",
                     config_utente("azioni", "x").parent):
        if not cartella.is_dir():
            continue
        for f in sorted(cartella.glob("*.toml")):
            try:
                dati = tomllib.loads(f.read_text(encoding="utf-8"))
            except (OSError, tomllib.TOMLDecodeError):
                continue
            for a in dati.get("azione", []):
                a["_modelli"] = [_modello(normalizza(fr)) for fr in a.get("frasi", [])]
                elenco.append(a)
    return elenco


def _modello(frase: str) -> tuple[str, re.Pattern | None]:
    if "{" not in frase:
        return frase, None
    regex = re.escape(frase)
    regex = re.sub(r"\\\{(\w+)\\\}", r"(?P<\1>.+?)", regex)
    return frase, re.compile(rf"^{regex}$")


def _punteggio_azione(a: dict, testo: str) -> tuple[float, dict]:
    migliore, parametri = 0.0, {}
    for frase, regex in a["_modelli"]:
        if regex:
            m = regex.match(testo)
            if m:
                return 95.0, m.groupdict()
            base = frase.split("{")[0].strip()
            if base and testo.startswith(base):
                migliore = max(migliore, 60.0)
            continue
        if testo == frase:
            return 100.0, {}
        if frase.startswith(testo) and len(testo) >= 3:
            migliore = max(migliore, 70.0 + 20 * len(testo) / len(frase))
        rapporto = difflib.SequenceMatcher(None, testo, frase).ratio()
        if rapporto > 0.78:
            migliore = max(migliore, rapporto * 85)
    return migliore, parametri


# ── App e impostazioni ───────────────────────────────────────────────────────
@lru_cache(maxsize=1)
def app_installate() -> list[dict]:
    risultato, viste = [], set()
    for base in (Path.home() / ".local/share/applications", Path("/usr/share/applications"),
                 Path("/var/lib/flatpak/exports/share/applications"),
                 Path.home() / ".local/share/flatpak/exports/share/applications"):
        if not base.is_dir():
            continue
        for f in base.rglob("*.desktop"):
            if f.name in viste:
                continue
            c = configparser.RawConfigParser(strict=False, interpolation=None)
            try:
                c.read(f, encoding="utf-8")
                v = c["Desktop Entry"]
            except (configparser.Error, KeyError, UnicodeDecodeError):
                continue
            if v.get("NoDisplay", "false") == "true" or v.get("Type", "Application") != "Application":
                continue
            viste.add(f.name)
            nome = v.get("Name[it]", v.get("Name", f.stem))
            risultato.append({"desktop": f.name, "nome": nome, "icona": v.get("Icon", "application-x-executable"),
                              "chiavi": normalizza(" ".join([nome, v.get("GenericName[it]", v.get("GenericName", "")),
                                                             v.get("Keywords[it]", v.get("Keywords", "")),
                                                             v.get("Comment[it]", v.get("Comment", ""))]))})
    return risultato


@lru_cache(maxsize=1)
def indice_impostazioni() -> list[dict]:
    try:
        from ..impostazioni import PANNELLI
    except Exception:  # noqa: BLE001
        return []
    return [{"id": p.id, "titolo": p.titolo, "icona": p.icona, "chiavi": normalizza(f"{p.titolo} {p.chiavi}")}
            for p in PANNELLI]


# ── Calcolatrice ─────────────────────────────────────────────────────────────
_OPERATORI = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul, ast.Div: operator.truediv,
              ast.Pow: operator.pow, ast.Mod: operator.mod, ast.USub: operator.neg, ast.UAdd: operator.pos}


def calcola(testo: str):
    espressione = testo.replace(",", ".").replace("x", "*").replace(":", "/").replace("^", "**").strip()
    if not re.fullmatch(r"[\d\s.+\-*/()%]+", espressione) or not re.search(r"\d\s*[-+*/%]", espressione):
        return None

    def valuta(nodo):
        if isinstance(nodo, ast.Expression):
            return valuta(nodo.body)
        if isinstance(nodo, ast.Constant) and isinstance(nodo.value, (int, float)):
            return nodo.value
        if isinstance(nodo, ast.BinOp) and type(nodo.op) in _OPERATORI:
            sinistra, destra = valuta(nodo.left), valuta(nodo.right)
            if isinstance(nodo.op, ast.Pow) and abs(destra) > 100:
                raise ValueError
            return _OPERATORI[type(nodo.op)](sinistra, destra)
        if isinstance(nodo, ast.UnaryOp) and type(nodo.op) in _OPERATORI:
            return _OPERATORI[type(nodo.op)](valuta(nodo.operand))
        raise ValueError

    try:
        risultato = valuta(ast.parse(espressione, mode="eval"))
    except (ValueError, SyntaxError, ZeroDivisionError, OverflowError):
        return None
    return round(risultato, 10) if isinstance(risultato, float) else risultato


# ── File ─────────────────────────────────────────────────────────────────────
def cerca_file(testo: str, limite: int = 8) -> list[str]:
    if len(testo) < 3:
        return []
    casa = str(Path.home())
    righe = uscita(["plocate", "-i", "-l", "200", "--", testo], timeout=3).splitlines()
    risultati = [r for r in righe if r.startswith(casa) and "/." not in r[len(casa):]]
    risultati.sort(key=lambda r: (testo.lower() not in Path(r).name.lower(), len(r)))
    return risultati[:limite]


def trova_file(nome: str) -> str:
    nome = nome.strip().strip('"')
    if Path(nome).expanduser().exists():
        return str(Path(nome).expanduser())
    trovati = cerca_file(nome, 1)
    return trovati[0] if trovati else ""


# ── Ricerca principale ───────────────────────────────────────────────────────
def cerca(testo: str) -> list[dict]:
    originale = testo.strip()
    testo = normalizza(originale)
    if not testo:
        return []
    risultati = []

    valore = calcola(originale)
    if valore is not None:
        risultati.append({"tipo": "calcolo", "titolo": f"= {valore}", "sottotitolo": T("Premi Invio per copiare"),
                          "icona": "accessories-calculator", "punteggio": 99, "dati": {"valore": str(valore)}})

    for a in azioni():
        punteggio, parametri = _punteggio_azione(a, testo)
        if punteggio >= 55:
            titolo = a.get("titolo", "")
            for k, v in parametri.items():
                titolo = titolo.replace("{" + k + "}", v)
            risultati.append({"tipo": "azione", "titolo": titolo, "sottotitolo": T("Azione"),
                              "icona": a.get("icona", "system-run"), "punteggio": punteggio,
                              "dati": {"id": a.get("id"), "parametri": parametri}})

    for app in app_installate():
        nome = normalizza(app["nome"])
        if nome.startswith(testo):
            punteggio = 90
        elif testo in nome:
            punteggio = 75
        elif all(p in app["chiavi"] for p in testo.split()):
            punteggio = 60
        else:
            continue
        risultati.append({"tipo": "app", "titolo": app["nome"], "sottotitolo": T("App"), "icona": app["icona"],
                          "punteggio": punteggio, "dati": {"desktop": app["desktop"]}})

    for p in indice_impostazioni():
        if all(parola in p["chiavi"] for parola in testo.split()):
            risultati.append({"tipo": "impostazione", "titolo": p["titolo"], "sottotitolo": T("Impostazioni"),
                              "icona": p["icona"], "punteggio": 65, "dati": {"pannello": p["id"]}})

    for f in cerca_file(originale):
        risultati.append({"tipo": "file", "titolo": Path(f).name, "sottotitolo": str(Path(f).parent).replace(str(Path.home()), "~"),
                          "icona": "folder" if Path(f).is_dir() else "text-x-generic", "punteggio": 40, "dati": {"percorso": f}})

    risultati.append({"tipo": "web", "titolo": T("Cerca «{t}» sul web", t=originale), "sottotitolo": T("Browser"),
                      "icona": "internet-web-browser", "punteggio": 1, "dati": {"testo": originale}})
    risultati.sort(key=lambda r: -r["punteggio"])
    return risultati[:12]


# ── Esecuzione ───────────────────────────────────────────────────────────────
def esegui_risultato(r: dict) -> str:
    """Esegue un risultato; restituisce un messaggio da mostrare (o "")."""
    tipo, dati = r.get("tipo"), r.get("dati", {})
    if tipo == "app":
        avvia_desktop(dati["desktop"])
    elif tipo == "impostazione":
        avvia([branding.comando("impostazioni"), dati["pannello"]])
    elif tipo == "file":
        avvia(["xdg-open", dati["percorso"]])
    elif tipo == "web":
        from urllib.parse import quote_plus

        avvia(["xdg-open", f"https://duckduckgo.com/?q={quote_plus(dati['testo'])}"])
    elif tipo == "calcolo":
        esegui(["wl-copy", dati["valore"]])
        return T("Copiato: {v}", v=dati["valore"])
    elif tipo == "azione":
        return _esegui_azione(dati["id"], dati.get("parametri", {}))
    return ""


def _esegui_azione(ident: str, parametri: dict) -> str:
    a = next((x for x in azioni() if x.get("id") == ident), None)
    if not a:
        return T("Azione non trovata")
    if a.get("interno"):
        return INTERNE[a["interno"]](parametri, a)
    comando = [str(c).format(**parametri) if parametri else str(c) for c in a.get("comando", [])]
    comando = [c.replace("@OS_ID@", branding.id_os()) for c in comando]
    if a.get("attendi"):
        r = esegui(comando, timeout=60)
        return a.get("messaggio", "") if r.returncode == 0 else (r.stderr.strip() or T("Azione non riuscita"))
    avvia(comando)
    return a.get("messaggio", "")


def _installa(parametri, _a):
    from ..store import installa, trova_per_nome

    nome = parametri.get("app", "").strip()
    app = trova_per_nome(nome)
    if not app:
        avvia([branding.comando("store"), "--cerca", nome])
        return T("Nessuna app trovata con questo nome: apro lo store")
    notifica(T("Installazione di {a}…", a=app["nome"]), T("Ti avviso quando è pronta"), icona="system-software-install")
    r = installa(app["id"], app["origine"])
    notifica(T("{a} installata", a=app["nome"]) if r["ok"] else T("Installazione non riuscita"),
             r.get("messaggio", ""), icona="system-software-install")
    app_installate.cache_clear()
    return ""


def _invia(parametri, _a):
    file = trova_file(parametri.get("file", "")) if parametri.get("file") else ""
    avvia([branding.comando("condividi")] + ([file] if file else []))
    return "" if file or not parametri.get("file") else T("File non trovato: scegli dal selettore")


def _converti_pdf(parametri, _a):
    file = trova_file(parametri.get("file", ""))
    if not file:
        return T("File non trovato")
    avvia(["/usr/libexec/nucleo/converti-pdf", file])
    return T("Conversione avviata: il PDF comparirà accanto al file")


def _spazio(parametri, _a):
    from ..spazi import attiva, elenco_spazi

    richiesto = normalizza(parametri.get("nome", ""))
    for s in elenco_spazi():
        if normalizza(s["nome"]) == richiesto or s["id"] == richiesto:
            attiva(s["id"])
            return ""
    return T("Spazio non trovato")


def _apri(parametri, _a):
    nome = normalizza(parametri.get("app", ""))
    for app in app_installate():
        if normalizza(app["nome"]).startswith(nome):
            avvia_desktop(app["desktop"])
            return ""
    return T("App non trovata")


def _versioni(parametri, _a):
    file = trova_file(parametri.get("file", "")) if parametri.get("file") else ""
    avvia([branding.comando("linea-del-tempo")] + ([file] if file else []))
    return ""


def _volume(parametri, a):
    from ..hw import audio

    passo = int(a.get("passo", 10))
    v = audio.cambia_volume(passo)
    return T("Volume {v}%", v=v["volume"])


INTERNE = {"installa": _installa, "invia": _invia, "converti-pdf": _converti_pdf, "spazio": _spazio,
           "apri": _apri, "versioni": _versioni, "volume": _volume}
