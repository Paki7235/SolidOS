"""SchermoRemoto: l'elemento QML che mostra lo schermo dell'altro computer (VNC) dentro l'app
Desktop remoto e gli manda mouse e tastiera. Registrato come «SolidOS.Remoto 1.0»."""

from __future__ import annotations

import threading

from PyQt6.QtCore import QPointF, QRectF, Qt, pyqtProperty, pyqtSignal, pyqtSlot
from PyQt6.QtGui import QColor, QImage, QPainter
from PyQt6.QtQuick import QQuickPaintedItem

from .vnc import ClientVNC, ErroreVNC

# Tasti Qt → keysym X11 (quelli che non sono lettere)
TASTI = {
    0x01000000: 0xFF1B, 0x01000001: 0xFF09, 0x01000002: 0xFF09, 0x01000003: 0xFF08, 0x01000004: 0xFF0D,
    0x01000005: 0xFF8D, 0x01000006: 0xFF63, 0x01000007: 0xFFFF, 0x01000008: 0xFF13, 0x01000009: 0xFF61,
    0x01000010: 0xFF50, 0x01000011: 0xFF57, 0x01000012: 0xFF51, 0x01000013: 0xFF52, 0x01000014: 0xFF53,
    0x01000015: 0xFF54, 0x01000016: 0xFF55, 0x01000017: 0xFF56, 0x01000020: 0xFFE1, 0x01000021: 0xFFE3,
    0x01000022: 0xFFEB, 0x01000023: 0xFFE9, 0x01000024: 0xFFE5, 0x01000025: 0xFF7F, 0x01000026: 0xFF14,
    0x01000055: 0xFF67, 0x01001103: 0xFE03,
}
for _i in range(12):
    TASTI[0x01000030 + _i] = 0xFFBE + _i          # F1…F12


def keysym_di(carattere: str) -> int:
    c = ord(carattere)
    return c if 0x20 <= c <= 0xFF else 0x01000000 + c


class SchermoRemoto(QQuickPaintedItem):
    collegato = pyqtSignal(str, int, int, arguments=["nome", "larghezza", "altezza"])
    errore = pyqtSignal(str, arguments=["messaggio"])
    finito = pyqtSignal(str, arguments=["messaggio"])
    _ridisegna = pyqtSignal()
    _cambio = pyqtSignal(int, int, str)
    _chiuso = pyqtSignal(str)
    _sbagliato = pyqtSignal(str)

    def __init__(self, genitore=None) -> None:
        super().__init__(genitore)
        self.setAcceptedMouseButtons(Qt.MouseButton.AllButtons)
        self.setAcceptHoverEvents(True)
        self.setFillColor(QColor("#0B0C10"))
        self.setOpaquePainting(True)          # i pixel che arrivano hanno la trasparenza a 0: sempre opachi
        self._immagine = QImage()
        self._alfa_zero = True
        self._blocco = threading.Lock()
        self._client: ClientVNC | None = None
        self._pulsanti = 0
        self._premuti: dict[int, int] = {}          # tasto Qt → keysym mandato
        self._ridisegna.connect(self.update)
        self._cambio.connect(self._su_cambio)
        self._chiuso.connect(lambda m: self.finito.emit(m))
        self._sbagliato.connect(lambda m: self.errore.emit(m))

    # ── collegamento (in un thread: non blocca la finestra) ──
    @pyqtSlot(str, int, str, str)
    def collega(self, host: str, porta: int, utente: str, password: str) -> None:
        self.chiudi()

        def lavoro():
            c = ClientVNC(self._aggiorna, lambda w, h, n: self._cambio.emit(w, h, n), lambda m: self._chiuso.emit(m))
            try:
                c.collega(host, porta, utente, password)
                self._client = c
            except (ErroreVNC, OSError) as e:
                msg = str(e)
                if isinstance(e, OSError) and not isinstance(e, ErroreVNC):
                    msg = "Computer non raggiungibile: controlla l'indirizzo e che la condivisione schermo sia attiva"
                self._sbagliato.emit(msg)
            except Exception as e:  # noqa: BLE001
                self._sbagliato.emit(str(e))

        threading.Thread(target=lavoro, daemon=True).start()

    @pyqtSlot()
    def chiudi(self) -> None:
        if self._client:
            self._client.chiudi()
            self._client = None

    def _su_cambio(self, w: int, h: int, nome: str) -> None:
        with self._blocco:
            nuova = QImage(w, h, QImage.Format.Format_RGB32)
            nuova.fill(QColor("#000000"))
            if not self._immagine.isNull():
                p = QPainter(nuova)
                p.drawImage(0, 0, self._immagine)
                p.end()
            self._immagine = nuova
        self.collegato.emit(nome, w, h)
        self.update()

    def _aggiorna(self, x, y, w, h, dati, sorgente) -> None:
        with self._blocco:
            if self._immagine.isNull():
                return
            p = QPainter(self._immagine)
            if dati is not None:
                # il quarto byte dei pixel (trasparenza) arriva a 0: si copiano così come sono e
                # l'immagine si disegna con la trasparenza forzata a «pieno» (vedi paint)
                pezzo = QImage(dati, w, h, w * 4, QImage.Format.Format_RGB32)
                p.setCompositionMode(QPainter.CompositionMode.CompositionMode_Source)
                p.drawImage(x, y, pezzo)
            else:
                copia = self._immagine.copy(sorgente[0], sorgente[1], w, h)
                p.drawImage(x, y, copia)
            p.end()
        self._ridisegna.emit()

    # ── disegno: lo schermo remoto intero dentro l'elemento, senza deformarlo ──
    def _area(self) -> QRectF:
        if self._immagine.isNull():
            return QRectF()
        iw, ih = self._immagine.width(), self._immagine.height()
        s = min(self.width() / iw, self.height() / ih) if iw and ih else 1
        w, h = iw * s, ih * s
        return QRectF((self.width() - w) / 2, (self.height() - h) / 2, w, h)

    def paint(self, painter: QPainter) -> None:
        with self._blocco:
            if self._immagine.isNull():
                return
            painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)
            # RGB32 → ARGB opaco: Qt imposta la trasparenza a 255 nella conversione
            painter.drawImage(self._area(), self._immagine.convertToFormat(QImage.Format.Format_ARGB32_Premultiplied)
                              if self._alfa_zero else self._immagine)

    def _remoto(self, pos: QPointF) -> tuple[int, int]:
        a = self._area()
        if a.isEmpty():
            return 0, 0
        return (int((pos.x() - a.x()) * self._immagine.width() / a.width()),
                int((pos.y() - a.y()) * self._immagine.height() / a.height()))

    # ── mouse ──
    _BIT = {Qt.MouseButton.LeftButton: 1, Qt.MouseButton.MiddleButton: 2, Qt.MouseButton.RightButton: 4}

    def mousePressEvent(self, e) -> None:
        self.forceActiveFocus()
        self._pulsanti |= self._BIT.get(e.button(), 0)
        self._muovi(e.position())

    def mouseReleaseEvent(self, e) -> None:
        self._pulsanti &= ~self._BIT.get(e.button(), 0)
        self._muovi(e.position())

    def mouseMoveEvent(self, e) -> None:
        self._muovi(e.position())

    def hoverMoveEvent(self, e) -> None:
        self._muovi(e.position())

    def wheelEvent(self, e) -> None:
        if not self._client:
            return
        x, y = self._remoto(e.position())
        bit = 8 if e.angleDelta().y() > 0 else 16 if e.angleDelta().y() < 0 else 0
        if bit:
            for _ in range(max(1, abs(e.angleDelta().y()) // 120)):
                self._client.puntatore(x, y, self._pulsanti | bit)
                self._client.puntatore(x, y, self._pulsanti)

    def _muovi(self, pos) -> None:
        if self._client:
            x, y = self._remoto(pos)
            self._client.puntatore(x, y, self._pulsanti)

    # ── tastiera ──
    def keyPressEvent(self, e) -> None:
        if not self._client:
            return
        k = e.key()
        if k in TASTI:
            ks = TASTI[k]
        elif e.text() and ord(e.text()[0]) >= 0x20:
            ks = keysym_di(e.text()[0])
        elif 0x20 <= k <= 0x7E:
            ks = ord(chr(k).lower())                 # con Ctrl il testo è un carattere di controllo
        else:
            return
        self._premuti[k] = ks
        self._client.tasto(ks, True)
        e.accept()

    def keyReleaseEvent(self, e) -> None:
        if not self._client or e.isAutoRepeat():
            return
        ks = self._premuti.pop(e.key(), None)
        if ks is not None:
            self._client.tasto(ks, False)
        e.accept()

    @pyqtSlot()
    def ctrlAltCanc(self) -> None:
        if self._client:
            for ks in (0xFFE3, 0xFFE9, 0xFFFF):
                self._client.tasto(ks, True)
            for ks in (0xFFFF, 0xFFE9, 0xFFE3):
                self._client.tasto(ks, False)

    @pyqtSlot(str)
    def scrivi(self, testo: str) -> None:
        """Scrive un testo sull'altro computer, tasto per tasto (es. il contenuto degli appunti)."""
        if self._client:
            for c in testo:
                ks = 0xFF0D if c == "\n" else keysym_di(c)
                self._client.tasto(ks, True)
                self._client.tasto(ks, False)

    @pyqtProperty(bool)
    def attivo(self) -> bool:
        return self._client is not None


def registra() -> None:
    from PyQt6.QtQml import qmlRegisterType

    qmlRegisterType(SchermoRemoto, "SolidOS.Remoto", 1, 0, "SchermoRemoto")
