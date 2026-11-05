"""Riconoscimento dei formati di file e suggerimenti di app."""

from __future__ import annotations

from pathlib import Path

# Formati installabili → backend di «Installa con …»
INSTALLABILI = {
    ".deb": "deb", ".rpm": "rpm", ".appimage": "appimage", ".flatpakref": "flatpakref",
    ".flatpak": "flatpak", ".exe": "exe", ".msi": "msi",
    ".dmg": "mac", ".pkg": "mac", ".app": "mac",
}

# Estensione → app suggerite (id Flatpak su Flathub e/o pacchetto Debian)
SUGGERIMENTI = {
    ".psd": [("org.gimp.GIMP", "GIMP"), ("org.kde.krita", "Krita")],
    ".xcf": [("org.gimp.GIMP", "GIMP")],
    ".kra": [("org.kde.krita", "Krita")],
    ".svg": [("org.inkscape.Inkscape", "Inkscape")],
    ".ai": [("org.inkscape.Inkscape", "Inkscape")],
    ".cdr": [("org.inkscape.Inkscape", "Inkscape")],
    ".dwg": [("org.librecad.librecad", "LibreCAD")],
    ".dxf": [("org.librecad.librecad", "LibreCAD")],
    ".stl": [("org.freecad.FreeCAD", "FreeCAD")],
    ".step": [("org.freecad.FreeCAD", "FreeCAD")],
    ".blend": [("org.blender.Blender", "Blender")],
    ".epub": [("com.github.johnfactotum.Foliate", "Foliate")],
    ".mobi": [("com.github.johnfactotum.Foliate", "Foliate")],
    ".cbz": [("com.github.johnfactotum.Foliate", "Foliate")],
    ".torrent": [("org.qbittorrent.qBittorrent", "qBittorrent")],
    ".kdbx": [("org.keepassxc.KeePassXC", "KeePassXC")],
    ".mscz": [("org.musescore.MuseScore", "MuseScore")],
    ".mid": [("org.musescore.MuseScore", "MuseScore")],
    ".aup3": [("org.audacityteam.Audacity", "Audacity")],
    ".kdenlive": [("org.kde.kdenlive", "Kdenlive")],
    ".gpx": [("org.gnome.Maps", "Mappe")],
    ".sqlite": [("org.sqlitebrowser.sqlitebrowser", "DB Browser for SQLite")],
    ".db": [("org.sqlitebrowser.sqlitebrowser", "DB Browser for SQLite")],
    ".pptx": [("libreoffice-impress", "LibreOffice Impress")],
    ".pub": [("libreoffice-draw", "LibreOffice Draw")],
    ".vsdx": [("libreoffice-draw", "LibreOffice Draw")],
    ".mpp": [("net.sourceforge.projectlibre", "ProjectLibre")],
    ".eml": [("org.mozilla.Thunderbird", "Thunderbird")],
    ".msg": [("org.mozilla.Thunderbird", "Thunderbird")],
    ".ttf": [("org.gnome.font-viewer", "Caratteri")],
    ".otf": [("org.gnome.font-viewer", "Caratteri")],
    ".nes": [("org.libretro.RetroArch", "RetroArch")],
    ".iso": [("lxqt-archiver", "Gestore archivi")],
}

ARCHIVI = {".zip", ".rar", ".7z", ".tar", ".gz", ".xz", ".bz2", ".zst", ".tgz", ".iso", ".cab", ".lzh"}


def tipo_installabile(percorso: str) -> str:
    nome = Path(percorso).name.lower()
    for est, tipo in INSTALLABILI.items():
        if nome.endswith(est):
            return tipo
    return ""


def tipo_mime(percorso: str) -> str:
    try:
        import magic

        return magic.from_file(percorso, mime=True)
    except Exception:  # noqa: BLE001 — libmagic assente o file illeggibile
        return "application/octet-stream"


def descrizione(percorso: str) -> str:
    try:
        import magic

        return magic.from_file(percorso)
    except Exception:  # noqa: BLE001
        return ""


def suggerimenti(percorso: str) -> list[dict]:
    est = Path(percorso).suffix.lower()
    return [{"id": i, "nome": n} for i, n in SUGGERIMENTI.get(est, [])]


def estensione_ingannevole(percorso: str) -> bool:
    """Vero se il contenuto è un eseguibile ma l'estensione suggerisce un documento."""
    mime = tipo_mime(percorso)
    est = Path(percorso).suffix.lower()
    eseguibili = ("application/x-executable", "application/x-dosexec", "application/x-sharedlib",
                  "application/x-msdownload", "text/x-shellscript", "application/x-pie-executable")
    documenti = (".pdf", ".jpg", ".jpeg", ".png", ".gif", ".doc", ".docx", ".txt", ".mp3", ".mp4", ".xlsx", ".zip")
    return mime in eseguibili and est in documenti
