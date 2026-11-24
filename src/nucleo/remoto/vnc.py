"""Client VNC (protocollo RFB 3.8) di SolidOS, scritto da noi: niente programmi esterni.

Accesso (in quest'ordine, secondo cosa offre l'altro computer):
- «Apple Diffie-Hellman» (tipo 30): utente e password, cifrati con AES (chiave da uno scambio
  Diffie-Hellman). Lo usano il Mac (Condivisione schermo) e SolidOS (wayvnc).
- «VNC» (tipo 2): solo password (le prime 8 lettere), sfida e risposta con DES.
- Nessuna password (tipo 1).

Immagine: pixel a 32 bit (BGRX), codifiche Raw e CopyRect, più il cambio di risoluzione
(DesktopSize). L'immagine è un QImage che l'interfaccia disegna (nucleo.remoto.schermo).
"""

from __future__ import annotations

import hashlib
import secrets
import socket
import struct
import threading

TASTI_SPECIALI = {}   # riempito da schermo.py (tasti Qt → keysym X11)


class ErroreVNC(Exception):
    pass


# ── DES (solo per l'accesso «VNC»: sfida di 16 byte) ────────────────────────
_PC1 = [57, 49, 41, 33, 25, 17, 9, 1, 58, 50, 42, 34, 26, 18, 10, 2, 59, 51, 43, 35, 27, 19, 11, 3, 60, 52, 44, 36,
        63, 55, 47, 39, 31, 23, 15, 7, 62, 54, 46, 38, 30, 22, 14, 6, 61, 53, 45, 37, 29, 21, 13, 5, 28, 20, 12, 4]
_PC2 = [14, 17, 11, 24, 1, 5, 3, 28, 15, 6, 21, 10, 23, 19, 12, 4, 26, 8, 16, 7, 27, 20, 13, 2,
        41, 52, 31, 37, 47, 55, 30, 40, 51, 45, 33, 48, 44, 49, 39, 56, 34, 53, 46, 42, 50, 36, 29, 32]
_GIRI = [1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1]
_IP = [58, 50, 42, 34, 26, 18, 10, 2, 60, 52, 44, 36, 28, 20, 12, 4, 62, 54, 46, 38, 30, 22, 14, 6,
       64, 56, 48, 40, 32, 24, 16, 8, 57, 49, 41, 33, 25, 17, 9, 1, 59, 51, 43, 35, 27, 19, 11, 3,
       61, 53, 45, 37, 29, 21, 13, 5, 63, 55, 47, 39, 31, 23, 15, 7]
_FP = [40, 8, 48, 16, 56, 24, 64, 32, 39, 7, 47, 15, 55, 23, 63, 31, 38, 6, 46, 14, 54, 22, 62, 30,
       37, 5, 45, 13, 53, 21, 61, 29, 36, 4, 44, 12, 52, 20, 60, 28, 35, 3, 43, 11, 51, 19, 59, 27,
       34, 2, 42, 10, 50, 18, 58, 26, 33, 1, 41, 9, 49, 17, 57, 25]
_E = [32, 1, 2, 3, 4, 5, 4, 5, 6, 7, 8, 9, 8, 9, 10, 11, 12, 13, 12, 13, 14, 15, 16, 17,
      16, 17, 18, 19, 20, 21, 20, 21, 22, 23, 24, 25, 24, 25, 26, 27, 28, 29, 28, 29, 30, 31, 32, 1]
_P = [16, 7, 20, 21, 29, 12, 28, 17, 1, 15, 23, 26, 5, 18, 31, 10, 2, 8, 24, 14, 32, 27, 3, 9, 19, 13, 30, 6, 22, 11, 4, 25]
_S = [
    [14, 4, 13, 1, 2, 15, 11, 8, 3, 10, 6, 12, 5, 9, 0, 7, 0, 15, 7, 4, 14, 2, 13, 1, 10, 6, 12, 11, 9, 5, 3, 8,
     4, 1, 14, 8, 13, 6, 2, 11, 15, 12, 9, 7, 3, 10, 5, 0, 15, 12, 8, 2, 4, 9, 1, 7, 5, 11, 3, 14, 10, 0, 6, 13],
    [15, 1, 8, 14, 6, 11, 3, 4, 9, 7, 2, 13, 12, 0, 5, 10, 3, 13, 4, 7, 15, 2, 8, 14, 12, 0, 1, 10, 6, 9, 11, 5,
     0, 14, 7, 11, 10, 4, 13, 1, 5, 8, 12, 6, 9, 3, 2, 15, 13, 8, 10, 1, 3, 15, 4, 2, 11, 6, 7, 12, 0, 5, 14, 9],
    [10, 0, 9, 14, 6, 3, 15, 5, 1, 13, 12, 7, 11, 4, 2, 8, 13, 7, 0, 9, 3, 4, 6, 10, 2, 8, 5, 14, 12, 11, 15, 1,
     13, 6, 4, 9, 8, 15, 3, 0, 11, 1, 2, 12, 5, 10, 14, 7, 1, 10, 13, 0, 6, 9, 8, 7, 4, 15, 14, 3, 11, 5, 2, 12],
    [7, 13, 14, 3, 0, 6, 9, 10, 1, 2, 8, 5, 11, 12, 4, 15, 13, 8, 11, 5, 6, 15, 0, 3, 4, 7, 2, 12, 1, 10, 14, 9,
     10, 6, 9, 0, 12, 11, 7, 13, 15, 1, 3, 14, 5, 2, 8, 4, 3, 15, 0, 6, 10, 1, 13, 8, 9, 4, 5, 11, 12, 7, 2, 14],
    [2, 12, 4, 1, 7, 10, 11, 6, 8, 5, 3, 15, 13, 0, 14, 9, 14, 11, 2, 12, 4, 7, 13, 1, 5, 0, 15, 10, 3, 9, 8, 6,
     4, 2, 1, 11, 10, 13, 7, 8, 15, 9, 12, 5, 6, 3, 0, 14, 11, 8, 12, 7, 1, 14, 2, 13, 6, 15, 0, 9, 10, 4, 5, 3],
    [12, 1, 10, 15, 9, 2, 6, 8, 0, 13, 3, 4, 14, 7, 5, 11, 10, 15, 4, 2, 7, 12, 9, 5, 6, 1, 13, 14, 0, 11, 3, 8,
     9, 14, 15, 5, 2, 8, 12, 3, 7, 0, 4, 10, 1, 13, 11, 6, 4, 3, 2, 12, 9, 5, 15, 10, 11, 14, 1, 7, 6, 0, 8, 13],
    [4, 11, 2, 14, 15, 0, 8, 13, 3, 12, 9, 7, 5, 10, 6, 1, 13, 0, 11, 7, 4, 9, 1, 10, 14, 3, 5, 12, 2, 15, 8, 6,
     1, 4, 11, 13, 12, 3, 7, 14, 10, 15, 6, 8, 0, 5, 9, 2, 6, 11, 13, 8, 1, 4, 10, 7, 9, 5, 0, 15, 14, 2, 3, 12],
    [13, 2, 8, 4, 6, 15, 11, 1, 10, 9, 3, 14, 5, 0, 12, 7, 1, 15, 13, 8, 10, 3, 7, 4, 12, 5, 6, 11, 0, 14, 9, 2,
     7, 11, 4, 1, 9, 12, 14, 2, 0, 6, 10, 13, 15, 3, 5, 8, 2, 1, 14, 7, 4, 10, 8, 13, 15, 12, 9, 0, 3, 5, 6, 11],
]


def _permuta(valore: int, tabella: list[int], bit_in: int) -> int:
    out = 0
    for p in tabella:
        out = (out << 1) | ((valore >> (bit_in - p)) & 1)
    return out


def des_cifra(chiave: bytes, blocco: bytes) -> bytes:
    """DES su un blocco di 8 byte (verificato con il vettore di prova classico)."""
    k = _permuta(int.from_bytes(chiave, "big"), _PC1, 64)
    c, d = k >> 28, k & 0x0FFFFFFF
    sotto = []
    for g in _GIRI:
        c = ((c << g) | (c >> (28 - g))) & 0x0FFFFFFF
        d = ((d << g) | (d >> (28 - g))) & 0x0FFFFFFF
        sotto.append(_permuta((c << 28) | d, _PC2, 56))
    b = _permuta(int.from_bytes(blocco, "big"), _IP, 64)
    sx, dx = b >> 32, b & 0xFFFFFFFF
    for k in sotto:
        e = _permuta(dx, _E, 32) ^ k
        f = 0
        for i in range(8):
            sei = (e >> (42 - 6 * i)) & 0x3F
            riga = ((sei & 0x20) >> 4) | (sei & 1)
            colonna = (sei >> 1) & 0xF
            f = (f << 4) | _S[i][riga * 16 + colonna]
        sx, dx = dx, sx ^ _permuta(f, _P, 32)
    return _permuta((dx << 32) | sx, _FP, 64).to_bytes(8, "big")


def risposta_vnc(password: str, sfida: bytes) -> bytes:
    # VNC usa i bit di ogni byte della password al contrario
    chiave = bytes(int(f"{b:08b}"[::-1], 2) for b in (password.encode("latin-1", "replace") + b"\0" * 8)[:8])
    return des_cifra(chiave, sfida[:8]) + des_cifra(chiave, sfida[8:16])


# ── Connessione ──────────────────────────────────────────────────────────────
class ClientVNC:
    """Collega, accede e poi riceve l'immagine in un thread; i metodi tasto/puntatore mandano
    l'input. Le funzioni di ritorno vengono chiamate dal thread di rete."""

    def __init__(self, aggiorna, dimensione, fine) -> None:
        self._aggiorna = aggiorna          # (x, y, w, h, dati BGRX o None per CopyRect, sorgente)
        self._dimensione = dimensione      # (larghezza, altezza, nome)
        self._fine = fine                  # (messaggio)
        self._sock: socket.socket | None = None
        self._scrivi = threading.Lock()
        self.larghezza = self.altezza = 0
        self.nome = ""
        self._attivo = False

    # lettura esatta
    def _leggi(self, n: int) -> bytes:
        dati = bytearray()
        while len(dati) < n:
            pezzo = self._sock.recv(min(1 << 20, n - len(dati)))
            if not pezzo:
                raise ErroreVNC("Collegamento chiuso dall'altro computer")
            dati += pezzo
        return bytes(dati)

    def _manda(self, dati: bytes) -> None:
        if not self._sock:
            return
        with self._scrivi:
            try:
                self._sock.sendall(dati)
            except OSError:
                pass

    def collega(self, host: str, porta: int, utente: str, password: str) -> None:
        self._sock = socket.create_connection((host, porta), timeout=10)
        self._sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        versione = self._leggi(12)
        if not versione.startswith(b"RFB "):
            raise ErroreVNC("Non è un computer con la condivisione schermo (VNC)")
        maggiore, minore = int(versione[4:7]), int(versione[8:11])
        uso = (3, 8) if (maggiore, minore) >= (3, 8) else (3, 7) if (maggiore, minore) >= (3, 7) else (3, 3)
        self._manda(f"RFB {uso[0]:03d}.{uso[1]:03d}\n".encode())
        if uso == (3, 3):
            tipi = [struct.unpack(">I", self._leggi(4))[0]]
        else:
            n = self._leggi(1)[0]
            if n == 0:
                lung = struct.unpack(">I", self._leggi(4))[0]
                raise ErroreVNC(self._leggi(lung).decode("utf-8", "replace"))
            tipi = list(self._leggi(n))
        if 30 in tipi and utente:
            scelto = 30
        elif 2 in tipi:
            scelto = 2
        elif 1 in tipi:
            scelto = 1
        elif 30 in tipi:
            raise ErroreVNC("Questo computer chiede anche il nome utente")
        else:
            raise ErroreVNC("L'altro computer usa un tipo di accesso che non conosciamo ancora")
        if uso != (3, 3):
            self._manda(bytes([scelto]))
        if scelto == 2:
            self._manda(risposta_vnc(password, self._leggi(16)))
        elif scelto == 30:
            self._accesso_apple(utente, password)
        if scelto != 1 or uso >= (3, 8):
            esito = struct.unpack(">I", self._leggi(4))[0]
            if esito != 0:
                motivo = ""
                if uso >= (3, 8):
                    try:
                        lung = struct.unpack(">I", self._leggi(4))[0]
                        motivo = self._leggi(lung).decode("utf-8", "replace")
                    except ErroreVNC:
                        pass
                raise ErroreVNC("Utente o password non corretti" + (f" ({motivo})" if motivo else ""))
        self._manda(b"\x01")                                   # schermo condiviso con altri
        w, h = struct.unpack(">HH", self._leggi(4))
        self._leggi(16)                                         # formato dei pixel dell'altro
        lung = struct.unpack(">I", self._leggi(4))[0]
        self.nome = self._leggi(lung).decode("utf-8", "replace")
        self.larghezza, self.altezza = w, h
        # pixel a 32 bit, little endian, RGB in 16/8/0 → in memoria B G R X (QImage RGB32)
        self._manda(struct.pack(">B3xBBBBHHHBBB3x", 0, 32, 24, 0, 1, 255, 255, 255, 16, 8, 0))
        codifiche = [1, 0, -223]                                # CopyRect, Raw, cambio risoluzione
        self._manda(struct.pack(">BxH", 2, len(codifiche)) + b"".join(struct.pack(">i", c) for c in codifiche))
        self._sock.settimeout(None)
        self._dimensione(w, h, self.nome)
        self._attivo = True
        self.chiedi(False)
        threading.Thread(target=self._ricevi, daemon=True).start()

    def _accesso_apple(self, utente: str, password: str) -> None:
        """Accesso «Apple Diffie-Hellman» (tipo 30): chiave AES-128 = MD5 del segreto comune."""
        from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

        generatore, lung = struct.unpack(">HH", self._leggi(4))
        primo = int.from_bytes(self._leggi(lung), "big")
        sua = int.from_bytes(self._leggi(lung), "big")
        mia_segreta = secrets.randbelow(primo - 2) + 1
        mia_pubblica = pow(generatore, mia_segreta, primo)
        comune = pow(sua, mia_segreta, primo).to_bytes(lung, "big")
        chiave = hashlib.md5(comune).digest()
        credenziali = bytearray(secrets.token_bytes(128))
        for i, (testo, base) in enumerate(((utente, 0), (password, 64))):
            b = testo.encode("utf-8")[:63] + b"\0"
            credenziali[base:base + len(b)] = b
        cif = Cipher(algorithms.AES(chiave), modes.ECB()).encryptor()
        self._manda(cif.update(bytes(credenziali)) + cif.finalize() + mia_pubblica.to_bytes(lung, "big"))

    def _ricevi(self) -> None:
        try:
            while self._attivo:
                tipo = self._leggi(1)[0]
                if tipo == 0:                                   # aggiornamento dell'immagine
                    self._leggi(1)
                    n = struct.unpack(">H", self._leggi(2))[0]
                    for _ in range(n):
                        x, y, w, h, cod = struct.unpack(">HHHHi", self._leggi(12))
                        if cod == 0:
                            self._aggiorna(x, y, w, h, self._leggi(w * h * 4), None)
                        elif cod == 1:
                            sx, sy = struct.unpack(">HH", self._leggi(4))
                            self._aggiorna(x, y, w, h, None, (sx, sy))
                        elif cod == -223:
                            self.larghezza, self.altezza = w, h
                            self._dimensione(w, h, self.nome)
                        else:
                            raise ErroreVNC(f"Codifica sconosciuta {cod}")
                    self.chiedi(True)
                elif tipo == 1:                                 # tavolozza (non usata a 32 bit)
                    self._leggi(1)
                    _, n = struct.unpack(">HH", self._leggi(4))
                    self._leggi(n * 6)
                elif tipo == 2:                                 # campanello
                    pass
                elif tipo == 3:                                 # testo copiato sull'altro computer
                    self._leggi(3)
                    lung = struct.unpack(">I", self._leggi(4))[0]
                    self._leggi(lung)
                else:
                    raise ErroreVNC(f"Messaggio sconosciuto {tipo}")
        except (ErroreVNC, OSError) as e:
            if self._attivo:
                self._attivo = False
                self._fine(str(e))

    # richieste e input
    def chiedi(self, solo_novita: bool) -> None:
        self._manda(struct.pack(">BBHHHH", 3, 1 if solo_novita else 0, 0, 0, self.larghezza, self.altezza))

    def tasto(self, keysym: int, giu: bool) -> None:
        self._manda(struct.pack(">BBxxI", 4, 1 if giu else 0, keysym))

    def puntatore(self, x: int, y: int, pulsanti: int) -> None:
        self._manda(struct.pack(">BBHH", 5, pulsanti & 0xFF, max(0, min(self.larghezza - 1, x)), max(0, min(self.altezza - 1, y))))

    def appunti(self, testo: str) -> None:
        dati = testo.encode("latin-1", "replace")
        self._manda(struct.pack(">B3xI", 6, len(dati)) + dati)

    def chiudi(self) -> None:
        self._attivo = False
        if self._sock:
            try:
                self._sock.shutdown(socket.SHUT_RDWR)
                self._sock.close()
            except OSError:
                pass
            self._sock = None
