"""Copia e spostamento di file e cartelle (GIO), usati da File e dalla Scrivania.

Trascinando senza tasti:
- sullo stesso disco i file vengono SPOSTATI;
- su un altro disco (chiavetta, rete…) vengono COPIATI.
Ctrl forza la copia, Maiusc lo spostamento. I nomi già presenti diventano «nome (2)».
"""

from __future__ import annotations

import time
from typing import Callable

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

from .i18n import T  # noqa: E402


def file_da(indirizzo: str) -> Gio.File:
    indirizzo = str(indirizzo)
    return Gio.File.new_for_uri(indirizzo) if "://" in indirizzo else Gio.File.new_for_path(indirizzo)


def _filesystem(f: Gio.File) -> str:
    try:
        return f.query_info("id::filesystem", Gio.FileQueryInfoFlags.NONE, None).get_attribute_string("id::filesystem") or ""
    except GLib.Error:
        return ""


def stesso_disco(sorgente: Gio.File, cartella: Gio.File) -> bool:
    a, b = _filesystem(sorgente), _filesystem(cartella)
    return bool(a) and a == b


def nome_libero(cartella: Gio.File, nome: str) -> Gio.File:
    dest = cartella.get_child(nome)
    n = 2
    while dest.query_exists(None):
        radice, punto, est = nome.rpartition(".")
        dest = cartella.get_child(f"{radice} ({n}).{est}" if punto and radice else f"{nome} ({n})")
        n += 1
    return dest


def _dimensione_totale(sorgenti: list[Gio.File], limite_s: float = 4.0) -> int:
    totale, pila, fine = 0, list(sorgenti), time.monotonic() + limite_s
    while pila and time.monotonic() < fine:
        f = pila.pop()
        try:
            info = f.query_info("standard::type,standard::size", Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, None)
        except GLib.Error:
            continue
        if info.get_file_type() == Gio.FileType.DIRECTORY:
            try:
                for figlio in f.enumerate_children("standard::name", Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, None):
                    pila.append(f.get_child(figlio.get_name()))
            except GLib.Error:
                pass
        else:
            totale += info.get_size()
    return totale


class _Avanzamento:
    def __init__(self, totale: int, avviso: Callable | None):
        self.totale, self.fatti, self.avviso, self.ultimo = max(totale, 1), 0, avviso, 0.0

    def file_copiato(self, byte: int, nome: str):
        self.fatti += byte
        self.segnala(nome)

    def segnala(self, nome: str, parziale: int = 0):
        if not self.avviso:
            return
        ora = time.monotonic()
        if ora - self.ultimo < 0.2:
            return
        self.ultimo = ora
        self.avviso(min(self.fatti + parziale, self.totale), self.totale, nome)


def _copia(sorgente: Gio.File, dest: Gio.File, av: _Avanzamento):
    info = sorgente.query_info("standard::type,standard::size,standard::name", Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, None)
    if info.get_file_type() == Gio.FileType.DIRECTORY:
        dest.make_directory(None)
        for figlio in sorgente.enumerate_children("standard::name", Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, None):
            _copia(sorgente.get_child(figlio.get_name()), dest.get_child(figlio.get_name()), av)
    else:
        nome = info.get_name()
        sorgente.copy(dest, Gio.FileCopyFlags.NOFOLLOW_SYMLINKS | Gio.FileCopyFlags.ALL_METADATA, None,
                      lambda attuali, _tot, *_: av.segnala(nome, attuali), None)
        av.file_copiato(info.get_size(), nome)


def elimina(f: Gio.File):
    info = f.query_info("standard::type", Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, None)
    if info.get_file_type() == Gio.FileType.DIRECTORY:
        for figlio in f.enumerate_children("standard::name", Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, None):
            elimina(f.get_child(figlio.get_name()))
    f.delete(None)


def trasferisci(indirizzi, cartella: str, modo: str = "auto", avviso: Callable | None = None) -> dict:
    """modo: «auto» (sposta sullo stesso disco, copia altrove), «copia», «sposta».
    avviso(fatti_byte, totale_byte, nome) viene chiamato durante le copie lunghe."""
    dest_cartella = file_da(cartella)
    sorgenti = [file_da(u) for u in indirizzi if str(u)]
    errori, nuovi, spostati, copiati = [], [], 0, 0
    av = _Avanzamento(_dimensione_totale(sorgenti) if avviso else 1, avviso)
    for sorgente in sorgenti:
        nome = sorgente.get_basename() or "file"
        genitore = sorgente.get_parent()
        if sorgente.equal(dest_cartella) or dest_cartella.has_prefix(sorgente):
            errori.append(T("Non puoi mettere una cartella dentro se stessa"))
            continue
        sposta = modo == "sposta" or (modo == "auto" and stesso_disco(sorgente, dest_cartella))
        if sposta and genitore is not None and genitore.equal(dest_cartella):
            continue                       # già qui: niente da fare
        dest = nome_libero(dest_cartella, nome)
        try:
            if sposta:
                try:
                    sorgente.move(dest, Gio.FileCopyFlags.NOFOLLOW_SYMLINKS, None, None, None)
                except GLib.Error:
                    _copia(sorgente, dest, av)
                    elimina(sorgente)
                spostati += 1
            else:
                _copia(sorgente, dest, av)
                copiati += 1
            nuovi.append(dest.get_uri())
        except GLib.Error as e:
            errori.append(f"{nome}: {e.message}")
    if avviso:
        avviso(av.totale, av.totale, "")
    return {"ok": not errori, "fatti": spostati + copiati, "spostati": spostati, "copiati": copiati,
            "nuovi": nuovi, "errore": errori[0] if errori else ""}
