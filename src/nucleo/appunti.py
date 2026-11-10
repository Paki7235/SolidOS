"""Appunti di sistema per i file (copia / taglia / incolla tra File, Scrivania e altre app).

Usa gli appunti di Qt (Wayland) con i formati standard:
- «text/uri-list»: elenco degli indirizzi (capito da tutte le app);
- «x-special/gnome-copied-files»: «copy» o «cut» seguito dagli indirizzi (GNOME, Thunar, PCManFM…).
Va chiamato dal thread principale dell'app Qt.
"""

from __future__ import annotations

from urllib.parse import quote, urlparse


def _uri(x: str) -> str:
    x = str(x)
    if "://" in x:
        return x
    return "file://" + quote(x)


def copia(indirizzi, taglia: bool = False) -> bool:
    from PyQt6.QtCore import QByteArray, QMimeData, QUrl
    from PyQt6.QtGui import QGuiApplication

    uri = [_uri(i) for i in indirizzi if str(i)]
    if not uri:
        return False
    dati = QMimeData()
    dati.setUrls([QUrl(u) for u in uri])
    dati.setData("x-special/gnome-copied-files", QByteArray((("cut" if taglia else "copy") + "\n" + "\n".join(uri)).encode()))
    dati.setText("\n".join(QUrl(u).toLocalFile() or u for u in uri))
    QGuiApplication.clipboard().setMimeData(dati)
    return True


def leggi() -> dict:
    """{"uri": [...], "taglia": bool} — vuoto se negli appunti non ci sono file."""
    from PyQt6.QtGui import QGuiApplication

    dati = QGuiApplication.clipboard().mimeData()
    if dati is None:
        return {"uri": [], "taglia": False}
    if dati.hasFormat("x-special/gnome-copied-files"):
        righe = bytes(dati.data("x-special/gnome-copied-files")).decode(errors="replace").splitlines()
        if righe:
            return {"uri": [r for r in righe[1:] if r.strip()], "taglia": righe[0].strip() == "cut"}
    if dati.hasUrls():
        return {"uri": [u.toString() for u in dati.urls() if u.isValid()], "taglia": False}
    # testo con percorsi assoluti (es. copiato da un terminale)
    testo = (dati.text() or "").strip()
    righe = [r.strip() for r in testo.splitlines() if r.strip()]
    if righe and all(r.startswith("/") or urlparse(r).scheme == "file" for r in righe):
        return {"uri": [_uri(r) for r in righe], "taglia": False}
    return {"uri": [], "taglia": False}


def svuota() -> None:
    from PyQt6.QtGui import QGuiApplication

    QGuiApplication.clipboard().clear()
