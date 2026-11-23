"""Note: appunti veloci.

Cartelle, note fissate in alto, ricerca, testo formattato (titolo, intestazione,
grassetto, corsivo, sottolineato, barrato, elenchi puntati e numerati, liste di
cose da fare con ☐/☑), «Eliminate di recente» per 30 giorni.

Ogni nota è un file JSON in ~/.local/share/<os>/note/ (html + dati), salvato da
solo mentre si scrive.
"""

from __future__ import annotations

import json
import re
import sys
import time
import uuid
from html import unescape
from pathlib import Path

from .. import branding
from ..i18n import T
from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app

GIORNI_CESTINO = 30


def _cartella() -> Path:
    c = Path.home() / ".local/share" / branding.id_os() / "note"
    c.mkdir(parents=True, exist_ok=True)
    return c


def _testo_semplice(html: str) -> str:
    """Testo senza formattazione (per titolo, anteprima e ricerca)."""
    corpo = re.sub(r"(?is)<head.*?</head>", "", html)
    corpo = re.sub(r"(?i)<br\s*/?>|</p>|</h\d>|</li>|</div>", "\n", corpo)
    corpo = re.sub(r"<[^>]+>", "", corpo)
    return unescape(corpo).replace(" ", "\n").strip()


class BackendNote(Backend):
    def __init__(self):
        self._pulisci_cestino()

    # ── Lettura ────────────────────────────────────────────────────────────
    def _tutte(self) -> list[dict]:
        note = []
        for f in _cartella().glob("*.json"):
            try:
                note.append(json.loads(f.read_text(encoding="utf-8")))
            except (OSError, json.JSONDecodeError):
                continue
        return note

    def _riassunto(self, n: dict) -> dict:
        testo = _testo_semplice(n.get("html", ""))
        righe = [r.strip() for r in testo.splitlines() if r.strip()]
        return {"id": n["id"], "titolo": righe[0][:80] if righe else T("Nuova nota"),
                "anteprima": " ".join(righe[1:3])[:120] if len(righe) > 1 else T("Nessun altro testo"),
                "cartella": n.get("cartella", ""), "fissata": bool(n.get("fissata")),
                "eliminata": bool(n.get("eliminata")), "modificata": n.get("modificata", 0)}

    def cartelle(self) -> list:
        note = self._tutte()
        nomi = sorted({n.get("cartella", "") for n in note if n.get("cartella")} | set(self._cartelle_vuote()), key=str.lower)
        attive = [n for n in note if not n.get("eliminata")]
        risultato = [{"id": "", "nome": T("Tutte le note"), "quante": len(attive), "speciale": True}]
        risultato += [{"id": c, "nome": c, "quante": sum(1 for n in attive if n.get("cartella") == c), "speciale": False} for c in nomi]
        eliminate = sum(1 for n in note if n.get("eliminata"))
        if eliminate:
            risultato.append({"id": ":eliminate", "nome": T("Eliminate di recente"), "quante": eliminate, "speciale": True})
        return risultato

    def _cartelle_vuote(self) -> list[str]:
        f = _cartella() / "cartelle.txt"
        return [r for r in f.read_text(encoding="utf-8").splitlines() if r.strip()] if f.exists() else []

    def nuovaCartella(self, nome: str) -> bool:
        nome = nome.strip()
        if not nome:
            return False
        vuote = self._cartelle_vuote()
        if nome not in vuote:
            (_cartella() / "cartelle.txt").write_text("\n".join(vuote + [nome]), encoding="utf-8")
        return True

    def elenco(self, cartella: str = "", cerca: str = "") -> list:
        cerca = cerca.strip().lower()
        risultato = []
        for n in self._tutte():
            if cartella == ":eliminate":
                if not n.get("eliminata"):
                    continue
            elif n.get("eliminata") or (cartella and n.get("cartella") != cartella):
                continue
            if cerca and cerca not in _testo_semplice(n.get("html", "")).lower():
                continue
            risultato.append(self._riassunto(n))
        risultato.sort(key=lambda r: (not r["fissata"], -r["modificata"]))
        return risultato

    def leggi(self, ident: str) -> dict:
        f = _cartella() / f"{ident}.json"
        try:
            return json.loads(f.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return {}

    # ── Scrittura ──────────────────────────────────────────────────────────
    def _scrivi(self, n: dict) -> None:
        f = _cartella() / f"{n['id']}.json"
        tmp = f.with_suffix(".tmp")
        tmp.write_text(json.dumps(n, ensure_ascii=False), encoding="utf-8")
        tmp.replace(f)

    def nuova(self, cartella: str = "") -> str:
        adesso = time.time()
        n = {"id": uuid.uuid4().hex[:12], "html": "", "cartella": "" if cartella.startswith(":") else cartella,
             "creata": adesso, "modificata": adesso, "fissata": False, "eliminata": False}
        self._scrivi(n)
        return n["id"]

    def salva(self, ident: str, html: str) -> dict:
        n = self.leggi(ident)
        if not n:
            return {}
        if n.get("html") != html:
            n["html"] = html
            n["modificata"] = time.time()
            self._scrivi(n)
        return self._riassunto(n)

    def fissa(self, ident: str, si: bool) -> None:
        n = self.leggi(ident)
        if n:
            n["fissata"] = bool(si)
            self._scrivi(n)

    def sposta(self, ident: str, cartella: str) -> None:
        n = self.leggi(ident)
        if n:
            n["cartella"] = cartella
            self._scrivi(n)

    def elimina(self, ident: str) -> None:
        """Prima va in «Eliminate di recente»; da lì si elimina per sempre."""
        n = self.leggi(ident)
        if not n:
            return
        if n.get("eliminata"):
            (_cartella() / f"{ident}.json").unlink(missing_ok=True)
            return
        if not _testo_semplice(n.get("html", "")):
            (_cartella() / f"{ident}.json").unlink(missing_ok=True)   # nota vuota: sparisce e basta
            return
        n["eliminata"], n["eliminataIl"] = True, time.time()
        self._scrivi(n)

    def ripristina(self, ident: str) -> None:
        n = self.leggi(ident)
        if n:
            n["eliminata"] = False
            self._scrivi(n)

    def eliminaVuote(self) -> None:
        for n in self._tutte():
            if not n.get("eliminata") and not _testo_semplice(n.get("html", "")):
                (_cartella() / f"{n['id']}.json").unlink(missing_ok=True)

    def _pulisci_cestino(self) -> None:
        limite = time.time() - GIORNI_CESTINO * 86400
        for n in self._tutte():
            if n.get("eliminata") and n.get("eliminataIl", 0) < limite:
                (_cartella() / f"{n['id']}.json").unlink(missing_ok=True)

    # ── Formattazione (sul documento di testo del QML) ─────────────────────
    def formatta(self, documento, inizio: int, fine: int, tipo: str) -> None:
        """tipo: grassetto · corsivo · sottolineato · barrato · titolo · intestazione · corpo ·
        puntato · numerato · cose (lista di cose da fare)."""
        from PyQt6.QtGui import QFont, QTextBlockFormat, QTextCharFormat, QTextCursor, QTextListFormat

        doc = documento.textDocument()
        c = QTextCursor(doc)
        c.setPosition(int(inizio))
        c.setPosition(int(fine), QTextCursor.MoveMode.KeepAnchor)
        if tipo in ("grassetto", "corsivo", "sottolineato", "barrato"):
            if not c.hasSelection():
                c.select(QTextCursor.SelectionType.WordUnderCursor)
            attuale = c.charFormat()
            f = QTextCharFormat()
            if tipo == "grassetto":
                f.setFontWeight(QFont.Weight.Normal if attuale.fontWeight() >= QFont.Weight.Bold else QFont.Weight.Bold)
            elif tipo == "corsivo":
                f.setFontItalic(not attuale.fontItalic())
            elif tipo == "sottolineato":
                f.setFontUnderline(not attuale.fontUnderline())
            else:
                f.setFontStrikeOut(not attuale.fontStrikeOut())
            c.mergeCharFormat(f)
            return
        c.beginEditBlock()
        if tipo in ("titolo", "intestazione", "corpo"):
            dimensioni = {"titolo": 24, "intestazione": 18, "corpo": 14}
            f = QTextCharFormat()
            f.setFontPointSize(dimensioni[tipo])
            f.setFontWeight(QFont.Weight.Bold if tipo != "corpo" else QFont.Weight.Normal)
            blocco = QTextCursor(c)
            blocco.setPosition(c.selectionStart())
            blocco.movePosition(QTextCursor.MoveOperation.StartOfBlock)
            blocco.setPosition(c.selectionEnd(), QTextCursor.MoveMode.KeepAnchor)
            blocco.movePosition(QTextCursor.MoveOperation.EndOfBlock, QTextCursor.MoveMode.KeepAnchor)
            blocco.mergeCharFormat(f)
            bf = QTextBlockFormat()
            bf.setHeadingLevel({"titolo": 1, "intestazione": 2, "corpo": 0}[tipo])
            blocco.mergeBlockFormat(bf)
        elif tipo in ("puntato", "numerato"):
            lista = c.currentList()
            stile = QTextListFormat.Style.ListDisc if tipo == "puntato" else QTextListFormat.Style.ListDecimal
            if lista and lista.format().style() == stile:
                bf = QTextBlockFormat()
                bf.setIndent(0)
                for i in range(lista.count() - 1, -1, -1):
                    lista.remove(lista.item(i))
                c.mergeBlockFormat(bf)
            else:
                lf = QTextListFormat()
                lf.setStyle(stile)
                c.createList(lf)
        elif tipo == "cose":
            # ogni riga selezionata diventa (o smette di essere) una cosa da fare: «☐ »
            blocco = doc.findBlock(c.selectionStart())
            ultimo = doc.findBlock(c.selectionEnd())
            togli = blocco.text().startswith(("☐ ", "☑ "))
            while blocco.isValid():
                cur = QTextCursor(blocco)
                if togli and blocco.text().startswith(("☐ ", "☑ ")):
                    cur.movePosition(QTextCursor.MoveOperation.Right, QTextCursor.MoveMode.KeepAnchor, 2)
                    cur.removeSelectedText()
                elif not togli:
                    cur.insertText("☐ ")
                if blocco == ultimo:
                    break
                blocco = blocco.next()
        c.endEditBlock()

    def spunta(self, documento, posizione: int) -> bool:
        """Clic su ☐/☑ all'inizio di una riga: segna (o toglie) la cosa fatta."""
        from PyQt6.QtGui import QTextCharFormat, QTextCursor

        doc = documento.textDocument()
        blocco = doc.findBlock(int(posizione))
        if not blocco.text().startswith(("☐", "☑")) or int(posizione) - blocco.position() > 1:
            return False
        fatto = blocco.text().startswith("☐")
        cur = QTextCursor(blocco)
        cur.beginEditBlock()
        cur.movePosition(QTextCursor.MoveOperation.Right, QTextCursor.MoveMode.KeepAnchor, 1)
        cur.insertText("☑" if fatto else "☐")
        # le cose fatte diventano grigie e barrate
        riga = QTextCursor(blocco)
        riga.movePosition(QTextCursor.MoveOperation.Right, QTextCursor.MoveMode.MoveAnchor, 2)
        riga.movePosition(QTextCursor.MoveOperation.EndOfBlock, QTextCursor.MoveMode.KeepAnchor)
        from PyQt6.QtGui import QColor

        if fatto:
            f = QTextCharFormat()
            f.setFontStrikeOut(True)
            f.setForeground(QColor("#8E8E93"))
            riga.mergeCharFormat(f)
        else:
            f = riga.charFormat()
            f.setFontStrikeOut(False)
            f.clearForeground()
            riga.setCharFormat(f)
        cur.endEditBlock()
        return True


def main() -> int:
    return esegui_app("note", "Note/Main.qml", lambda app: {"ponte": crea_ponte(BackendNote())})


if __name__ == "__main__":
    sys.exit(main())
