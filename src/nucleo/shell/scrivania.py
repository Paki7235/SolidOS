"""Scrivania: file e cartelle in ~/Scrivania (cartella XDG «DESKTOP») mostrati sullo sfondo."""

from __future__ import annotations

import mimetypes
import shutil
import subprocess
from pathlib import Path
from urllib.parse import unquote, urlparse

from ..i18n import T
from ..sistema import avvia

IMMAGINI = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".svg"}

ICONE_MIME = [
    ("inode/directory", "folder"), ("image/", "image-x-generic"), ("video/", "video-x-generic"),
    ("audio/", "audio-x-generic"), ("application/pdf", "application-pdf"), ("text/", "text-x-generic"),
    ("application/zip", "package-x-generic"), ("application/x-tar", "package-x-generic"),
    ("application/x-7z", "package-x-generic"), ("application/vnd.debian", "application-x-deb"),
    ("application/x-msdownload", "application-x-ms-dos-executable"),
    ("application/vnd.openxmlformats-officedocument.wordprocessing", "x-office-document"),
    ("application/vnd.openxmlformats-officedocument.spreadsheet", "x-office-spreadsheet"),
    ("application/vnd.openxmlformats-officedocument.presentation", "x-office-presentation"),
    ("application/vnd.oasis.opendocument.text", "x-office-document"),
    ("application/vnd.oasis.opendocument.spreadsheet", "x-office-spreadsheet"),
]


def cartella() -> Path:
    """Cartella della scrivania (creata se manca)."""
    try:
        percorso = subprocess.run(["xdg-user-dir", "DESKTOP"], capture_output=True, text=True, timeout=2).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        percorso = ""
    c = Path(percorso) if percorso and percorso != str(Path.home()) else Path.home() / "Scrivania"
    c.mkdir(parents=True, exist_ok=True)
    return c


def icona(p: Path) -> str:
    if p.is_dir():
        return "folder"
    if p.suffix == ".desktop":
        return "application-x-executable"
    tipo = mimetypes.guess_type(p.name)[0] or ""
    for prefisso, nome in ICONE_MIME:
        if tipo.startswith(prefisso):
            return nome
    return "text-x-generic" if not tipo else "application-x-generic"


def _voce_desktop(p: Path) -> dict:
    import configparser

    c = configparser.RawConfigParser(strict=False, interpolation=None)
    try:
        c.read(p, encoding="utf-8")
        v = c["Desktop Entry"]
        return {"nome": v.get("Name[it]") or v.get("Name", p.stem), "icona": v.get("Icon", "application-x-executable")}
    except (configparser.Error, KeyError, UnicodeDecodeError):
        return {"nome": p.stem, "icona": "application-x-executable"}


def elementi() -> list[dict]:
    c = cartella()
    risultato = []
    for p in sorted(c.iterdir(), key=lambda x: (x.suffix != ".desktop", not x.is_dir(), x.name.lower())):
        if p.name.startswith("."):
            continue
        app = _voce_desktop(p) if p.suffix == ".desktop" else None
        risultato.append({
            "nome": app["nome"] if app else p.name,
            "percorso": str(p),
            "cartella": p.is_dir(),
            "collegamento": app is not None,
            "icona": app["icona"] if app else icona(p),
            "anteprima": ("file://" + str(p)) if p.suffix.lower() in IMMAGINI else "",
        })
    return risultato


def apri(percorso: str) -> None:
    if percorso.endswith(".desktop"):     # collegamento a un'app: la si avvia
        from ..sistema import avvia_desktop

        avvia_desktop(percorso)
        return
    avvia(["xdg-open", percorso])


def aggiungi_collegamento(desktop: str) -> bool:
    """Copia la voce .desktop di un'app sulla scrivania (collegamento)."""
    from .dock import CARTELLE

    nome = desktop if desktop.endswith(".desktop") else desktop + ".desktop"
    for c in CARTELLE:
        sorgente = c / nome
        if sorgente.is_file():
            dest = cartella() / nome
            if not dest.exists():
                shutil.copy(sorgente, dest)
                dest.chmod(0o755)
            return True
    return False


def nome_libero(c: Path, base: str, est: str = "") -> Path:
    p = c / f"{base}{est}"
    n = 2
    while p.exists():
        p = c / f"{base} {n}{est}"
        n += 1
    return p


def nuova_cartella() -> str:
    p = nome_libero(cartella(), T("Nuova cartella"))
    p.mkdir()
    return str(p)


def nuovo_testo() -> str:
    p = nome_libero(cartella(), T("Nuovo documento"), ".txt")
    p.write_text("")
    return str(p)


def rinomina(percorso: str, nuovo: str) -> bool:
    nuovo = nuovo.strip().replace("/", "-")
    if not nuovo:
        return False
    p = Path(percorso)
    dest = p.with_name(nuovo)
    if dest.exists():
        return False
    p.rename(dest)
    return True


def cestino(percorso: str) -> bool:
    return subprocess.run(["gio", "trash", percorso], capture_output=True).returncode == 0


def copia_qui(indirizzi: list[str]) -> int:
    """File trascinati sulla scrivania: copiati (le cartelle intere comprese)."""
    c, n = cartella(), 0
    for indirizzo in indirizzi:
        sorgente = Path(unquote(urlparse(str(indirizzo)).path))
        if not sorgente.exists() or sorgente.parent == c:
            continue
        dest = nome_libero(c, sorgente.stem if sorgente.is_file() else sorgente.name,
                           sorgente.suffix if sorgente.is_file() else "")
        if sorgente.is_dir():
            shutil.copytree(sorgente, dest)
        else:
            shutil.copy2(sorgente, dest)
        n += 1
    return n
