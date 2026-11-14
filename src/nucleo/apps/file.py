"""File: gestore dei file di SolidOS (sostituisce la grafica di PCManFM-Qt).

Usa GIO, quindi gli stessi indirizzi valgono per cartelle locali, rete (smb://,
sftp://, ftp://, dav://, network:///), cestino (trash:///), telefoni (mtp://,
afc://) e dischi esterni.
"""

from __future__ import annotations

import os
import subprocess
import sys
import threading
import time
from pathlib import Path

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

from ..i18n import T  # noqa: E402
from ..ponte import Backend, crea_ponte  # noqa: E402
from ..qmlapp import esegui_app  # noqa: E402
from ..sistema import avvia  # noqa: E402

ATTRIBUTI = ("standard::name,standard::display-name,standard::type,standard::size,standard::icon,"
             "standard::content-type,standard::is-hidden,standard::is-backup,standard::target-uri,"
             "time::modified,access::can-write,access::can-trash,thumbnail::path")
IMMAGINI = (".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".svg")


def _f(uri: str) -> Gio.File:
    return Gio.File.new_for_commandline_arg(uri) if "://" not in uri else Gio.File.new_for_uri(uri)


def _icona(info: Gio.FileInfo) -> str:
    icona = info.get_icon()
    if isinstance(icona, Gio.ThemedIcon):
        nomi = icona.get_names()
        return nomi[0] if nomi else "text-x-generic"
    if isinstance(icona, Gio.FileIcon):
        return icona.get_file().get_path() or "text-x-generic"
    return "text-x-generic"


def _dimensione(byte: int) -> str:
    for unita in ("B", "KB", "MB", "GB", "TB"):
        if byte < 1024 or unita == "TB":
            return f"{byte:.0f} {unita}" if unita == "B" else f"{byte:.1f} {unita}".replace(".", ",")
        byte /= 1024
    return ""


class BackendFile(Backend):
    def __init__(self):
        self._monitor_volumi = None

    # ── Posizioni ──────────────────────────────────────────────────────────
    def iniziale(self) -> str:
        argomenti = [a for a in sys.argv[1:] if not a.startswith("-")]
        if argomenti:
            f = _f(argomenti[0])
            # «--proprieta FILE» o un file (non una cartella): si apre la cartella che lo contiene
            if f.query_file_type(Gio.FileQueryInfoFlags.NONE, None) not in (Gio.FileType.DIRECTORY, Gio.FileType.UNKNOWN, Gio.FileType.MOUNTABLE) \
                    and f.get_parent() is not None:
                return f.get_parent().get_uri()
            return f.get_uri()
        return Gio.File.new_for_path(str(Path.home())).get_uri()

    def bersaglio(self) -> str:
        """Il file passato da riga di comando (per «--proprieta»)."""
        argomenti = [a for a in sys.argv[1:] if not a.startswith("-")]
        return _f(argomenti[0]).get_uri() if argomenti else ""

    def richiesta(self) -> str:
        """Azione chiesta da riga di comando: «svuota» (Cestino nel Dock) o «proprieta»."""
        if "--svuota-cestino" in sys.argv:
            return "svuota"
        if "--proprieta" in sys.argv:
            return "proprieta"
        return ""

    def osservaVolumi(self) -> None:
        """Chiavette, dischi e cartelle di rete collegati/scollegati: la barra laterale
        si aggiorna da sola (eventi GIO sul thread principale, nessuna attesa)."""
        if self._monitor_volumi:
            return
        m = Gio.VolumeMonitor.get()
        for segnale in ("mount-added", "mount-removed", "mount-changed", "volume-added", "volume-removed"):
            m.connect(segnale, lambda *_a: self.emetti("luoghi", None))
        self._monitor_volumi = m

    def luoghi(self) -> list:
        def cartella(tipo, nome, icona):
            percorso = GLib.get_user_special_dir(tipo)
            return {"nome": nome, "uri": Gio.File.new_for_path(percorso).get_uri(), "icona": icona} if percorso else None

        voci = [{"nome": T("Home"), "uri": Gio.File.new_for_path(str(Path.home())).get_uri(), "icona": "user-home"}]
        for v in (cartella(GLib.UserDirectory.DIRECTORY_DESKTOP, T("Scrivania"), "user-desktop"),
                  cartella(GLib.UserDirectory.DIRECTORY_DOCUMENTS, T("Documenti"), "folder-documents"),
                  cartella(GLib.UserDirectory.DIRECTORY_DOWNLOAD, T("Scaricati"), "folder-download"),
                  cartella(GLib.UserDirectory.DIRECTORY_PICTURES, T("Immagini"), "folder-pictures"),
                  cartella(GLib.UserDirectory.DIRECTORY_MUSIC, T("Musica"), "folder-music"),
                  cartella(GLib.UserDirectory.DIRECTORY_VIDEOS, T("Video"), "folder-videos")):
            if v:
                voci.append(v)
        segnalibri = []
        file_segnalibri = Path(GLib.get_user_config_dir()) / "gtk-3.0" / "bookmarks"
        if file_segnalibri.exists():
            for riga in file_segnalibri.read_text().splitlines():
                uri, _, nome = riga.partition(" ")
                if uri:
                    segnalibri.append({"nome": nome or Gio.File.new_for_uri(uri).get_basename(), "uri": uri, "icona": "folder"})
        dispositivi = []
        monitor = Gio.VolumeMonitor.get()
        visti = set()
        for mount in monitor.get_mounts():
            if mount.is_shadowed():
                continue
            radice = mount.get_root().get_uri()
            visti.add(radice)
            dispositivi.append({"nome": mount.get_name(), "uri": radice, "icona": _icona_di(mount.get_symbolic_icon() or mount.get_icon()),
                                "espellibile": mount.can_eject() or mount.can_unmount(), "montato": True})
        for volume in monitor.get_volumes():
            if volume.get_mount() is None:
                dispositivi.append({"nome": volume.get_name(), "uri": "volume:" + (volume.get_identifier("unix-device") or volume.get_name()),
                                    "icona": _icona_di(volume.get_symbolic_icon() or volume.get_icon()), "espellibile": False, "montato": False})
        altro = [{"nome": T("Rete"), "uri": "network:///", "icona": "network-workgroup"},
                 {"nome": T("Cestino"), "uri": "trash:///", "icona": "user-trash-full" if self._cestino_pieno() else "user-trash"},
                 {"nome": T("Computer"), "uri": "file:///", "icona": "computer"}]
        return [{"titolo": T("Preferiti"), "voci": voci + segnalibri},
                {"titolo": T("Dispositivi"), "voci": dispositivi},
                {"titolo": T("Altro"), "voci": altro}]

    def _cestino_pieno(self) -> bool:
        try:
            info = Gio.File.new_for_uri("trash:///").query_info("trash::item-count", Gio.FileQueryInfoFlags.NONE, None)
            return info.get_attribute_uint32("trash::item-count") > 0
        except GLib.Error:
            return False

    # ── Elenco del contenuto ───────────────────────────────────────────────
    def elenco(self, uri: str, nascosti: bool = False) -> dict:
        if uri.rstrip("/") == "network:":
            return self._elenco_rete(nascosti)
        cartella = _f(uri)
        try:
            enumeratore = cartella.enumerate_children(ATTRIBUTI, Gio.FileQueryInfoFlags.NONE, None)
        except GLib.Error as e:
            if e.matches(Gio.io_error_quark(), Gio.IOErrorEnum.NOT_MOUNTED):
                return {"ok": False, "montare": True, "errore": T("Questa posizione va collegata")}
            return {"ok": False, "errore": e.message}
        voci = []
        for info in enumeratore:
            nome = info.get_name()
            if not nascosti and (info.get_is_hidden() or info.get_is_backup()):
                continue
            figlio = enumeratore.get_child(info)
            tipo = info.get_file_type()
            cartella_si = tipo in (Gio.FileType.DIRECTORY, Gio.FileType.MOUNTABLE, Gio.FileType.SHORTCUT)
            bersaglio = info.get_attribute_string("standard::target-uri")
            mod = info.get_modification_date_time()
            percorso = figlio.get_path()
            voci.append({
                "nome": info.get_display_name() or nome,
                "uri": bersaglio or figlio.get_uri(),
                "cartella": cartella_si,
                "dimensione": info.get_size() if not cartella_si else -1,
                "testoDimensione": "" if cartella_si else _dimensione(info.get_size()),
                "modificato": mod.format("%d/%m/%Y %H:%M") if mod else "",
                "ordinaData": mod.to_unix() if mod else 0,
                "tipo": Gio.content_type_get_description(info.get_content_type() or "") if info.get_content_type() else "",
                "icona": _icona(info),
                "anteprima": ("file://" + percorso) if percorso and nome.lower().endswith(IMMAGINI) else "",
                "miniatura": "file://" + info.get_attribute_byte_string("thumbnail::path") if info.get_attribute_byte_string("thumbnail::path") else "",
            })
        enumeratore.close(None)
        voci.sort(key=lambda v: (not v["cartella"], v["nome"].lower()))
        titolo = self._titolo(cartella)
        return {"ok": True, "uri": cartella.get_uri(), "titolo": titolo, "voci": voci, "percorso": cartella.get_path() or "",
                "genitore": cartella.get_parent().get_uri() if cartella.get_parent() else "",
                "cestino": cartella.get_uri().startswith("trash:"), "briciole": self._briciole(cartella)}

    _dispositivi_cache: tuple[float, list] = (0.0, [])

    def _elenco_rete(self, nascosti: bool) -> dict:
        """Rete: le cartelle condivise viste da GIO più tutti i dispositivi collegati
        alla stessa rete (modem, computer, telefoni, stampanti, TV…)."""
        import time

        from .. import dispositivi_rete

        cartella = Gio.File.new_for_uri("network:///")
        voci = []
        try:
            enumeratore = cartella.enumerate_children(ATTRIBUTI, Gio.FileQueryInfoFlags.NONE, None)
            for info in enumeratore:
                bersaglio = info.get_attribute_string("standard::target-uri")
                voci.append({"nome": info.get_display_name() or info.get_name(),
                             "uri": bersaglio or enumeratore.get_child(info).get_uri(), "cartella": True,
                             "dimensione": -1, "testoDimensione": "", "modificato": "", "ordinaData": 0,
                             "tipo": T("Cartelle condivise"), "icona": _icona(info), "anteprima": "", "miniatura": ""})
            enumeratore.close(None)
        except GLib.Error:
            pass
        adesso = time.monotonic()
        quando, dispositivi = BackendFile._dispositivi_cache
        if adesso - quando > 30 or not dispositivi:
            dispositivi = dispositivi_rete.cerca()
            BackendFile._dispositivi_cache = (adesso, dispositivi)
        gia = {v["nome"].lower() for v in voci}
        for d in dispositivi:
            if d["nome"].lower() in gia:
                continue
            voci.append({"nome": d["nome"], "uri": d["uri"] or "dispositivo:" + d["ip"], "cartella": d["cartelle"],
                         "dimensione": -1, "testoDimensione": "", "modificato": d["ip"], "ordinaData": 0,
                         "tipo": d["descrizione"] + (" · " + d["dettagli"] if d["dettagli"] else ""),
                         "icona": d["icona"], "anteprima": "", "miniatura": "", "dispositivo": d})
        return {"ok": True, "uri": "network:///", "titolo": T("Rete"), "voci": voci, "percorso": "", "genitore": "",
                "cestino": False, "rete": True, "briciole": [{"nome": T("Rete"), "uri": "network:///"}],
                "vuoto": T("Nessun dispositivo trovato: controlla di essere collegato al Wi-Fi o al cavo di rete")}

    def aggiornaRete(self) -> None:
        BackendFile._dispositivi_cache = (0.0, [])

    def _titolo(self, f: Gio.File) -> str:
        uri = f.get_uri()
        if uri == "trash:///":
            return T("Cestino")
        if uri == "network:///":
            return T("Rete")
        if f.get_path() == str(Path.home()):
            return T("Home")
        try:
            return f.query_info("standard::display-name", Gio.FileQueryInfoFlags.NONE, None).get_display_name()
        except GLib.Error:
            return f.get_basename() or uri

    def _briciole(self, f: Gio.File) -> list:
        voci, corrente = [], f
        while corrente is not None and len(voci) < 12:
            voci.insert(0, {"nome": self._titolo(corrente), "uri": corrente.get_uri()})
            if corrente.get_path() == str(Path.home()):
                break
            corrente = corrente.get_parent()
        return voci

    # ── Aprire ─────────────────────────────────────────────────────────────
    def apri(self, uri: str) -> bool:
        f = _f(uri)
        if f.get_path():
            from ..sistema import avvia

            avvia(["xdg-open", f.get_path()])
            return True
        try:
            Gio.AppInfo.launch_default_for_uri(uri, None)
            return True
        except GLib.Error:
            return False

    def appPer(self, uri: str) -> list:
        try:
            info = _f(uri).query_info("standard::content-type", Gio.FileQueryInfoFlags.NONE, None)
            tipo = info.get_content_type()
        except GLib.Error:
            return []
        risultato = []
        for app in Gio.AppInfo.get_all_for_type(tipo):
            if app.should_show():
                risultato.append({"id": app.get_id(), "nome": app.get_display_name(), "icona": _icona_di(app.get_icon())})
        return risultato

    def apriCon(self, idApp: str, uri: str) -> bool:
        try:
            app = Gio.DesktopAppInfo.new(idApp)
        except (AttributeError, TypeError):
            return False
        return bool(app and app.launch([_f(uri)], None))

    def terminaleQui(self, uri: str) -> dict:
        """Terminale nella cartella. Per le cartelle di rete la collega prima (GVFS le rende
        visibili anche ai programmi normali); per i server SSH apre direttamente «ssh»."""
        f = _f(uri)
        percorso = f.get_path()
        if not percorso and not uri.startswith("file:"):
            r = self.collega(uri)
            if not r.get("ok") and r.get("password"):
                return {"ok": False, "password": True, "uri": uri, "errore": r.get("errore", "")}
            percorso = _f(uri).get_path()
        if percorso:
            subprocess.Popen(["qterminal", "-w", percorso], start_new_session=True)
            return {"ok": True}
        if uri.startswith(("sftp://", "ssh://")):
            ospite = uri.split("://", 1)[1].split("/", 1)[0]
            return self.terminaleDispositivo(ospite.split("@")[-1], ospite.split("@")[0] if "@" in ospite else "")
        return {"ok": False, "errore": T("Questa posizione non si può aprire nel terminale")}

    @staticmethod
    def _porta_aperta(ip: str, porta: int, attesa: float = 1.5) -> bool:
        import socket

        try:
            with socket.create_connection((ip, porta), timeout=attesa):
                return True
        except OSError:
            return False

    def terminaleDispositivo(self, ip: str, nome: str = "", utente: str = "") -> dict:
        """Terminale collegato a un computer della rete con SSH (Mac, Linux, Windows con OpenSSH)."""
        import shlex

        if not self._porta_aperta(ip, 22):
            return {"ok": False, "info": True, "errore": T(
                "«{n}» non accetta collegamenti dal terminale (SSH). Per attivarli:\n"
                "• Mac: Impostazioni di Sistema › Generali › Condivisione › Accesso remoto\n"
                "• Windows: Impostazioni › Sistema › Funzionalità facoltative › Server OpenSSH\n"
                "• Linux: installa «openssh-server»", n=nome or ip)}
        if utente:
            comando = f"ssh {shlex.quote(utente + '@' + ip)}"
        else:
            domanda = shlex.quote(T("Nome utente su {n}: ", n=nome or ip))
            comando = f"read -r -p {domanda} u; ssh \"$u@{ip}\""
        script = comando + "; echo; read -r -p " + shlex.quote(T("Premi Invio per chiudere")) + " _"
        subprocess.Popen(["qterminal", "-e", "bash", "-c", script], start_new_session=True)
        return {"ok": True}

    def apriDispositivo(self, d: dict) -> dict:
        """Apre un dispositivo della rete: cartelle condivise (SMB/SFTP) se ci sono, altrimenti
        spiega che cosa attivare sul dispositivo. Prova anche quando il dispositivo non le annuncia."""
        ip, nome = d.get("ip", ""), d.get("nome", "")
        candidati = []
        if d.get("uri") and d.get("cartelle"):
            candidati.append(d["uri"])
        if ip and self._porta_aperta(ip, 445):
            candidati.append(f"smb://{ip}/")
        ultimo = None
        for uri in dict.fromkeys(candidati):
            r = self.collega(uri)
            if r.get("ok"):
                return {"ok": True, "uri": uri}
            if r.get("password"):
                return {"ok": False, "password": True, "uri": uri, "errore": T("Serve l'accesso: scrivi nome utente e password del dispositivo")}
            ultimo = (uri, r.get("errore", ""))
        if ultimo:
            # Molti server non si lasciano elencare senza accesso: si chiedono le credenziali
            return {"ok": False, "password": True, "uri": ultimo[0], "errore": ultimo[1]}
        if d.get("uri") and not d.get("cartelle"):
            self.apri(d["uri"])
            return {"ok": True, "uri": ""}
        if ip and self._porta_aperta(ip, 22):
            return {"ok": False, "password": True, "uri": f"sftp://{ip}/",
                    "errore": T("«{n}» accetta SSH: scrivi nome utente e password per vedere i suoi file", n=nome or ip)}
        return {"ok": False, "info": True, "errore": T(
            "«{n}» è collegato alla rete ma non condivide cartelle.\n"
            "• Mac: Impostazioni di Sistema › Generali › Condivisione › Condivisione file "
            "(in «Opzioni» attiva «Condividi file e cartelle usando SMB»)\n"
            "• Windows: Esplora file › clic destro su una cartella › Proprietà › Condivisione\n"
            "• Per mandare file al volo usa Condivisione Vicina.", n=nome or ip)}

    # ── Operazioni ─────────────────────────────────────────────────────────
    def nuovoFile(self, uri: str, nome: str) -> dict:
        from .. import trasferimenti

        f = trasferimenti.nome_libero(_f(uri), nome)
        try:
            f.create(Gio.FileCreateFlags.NONE, None).close(None)
            return {"ok": True, "uri": f.get_uri()}
        except GLib.Error as e:
            return {"ok": False, "errore": e.message}

    def nuovaCartella(self, uri: str) -> dict:
        base, n = T("Nuova cartella"), 2
        f = _f(uri).get_child(base)
        while f.query_exists(None):
            f = _f(uri).get_child(f"{base} {n}")
            n += 1
        try:
            f.make_directory(None)
            return {"ok": True, "uri": f.get_uri()}
        except GLib.Error as e:
            return {"ok": False, "errore": e.message}

    def rinomina(self, uri: str, nome: str) -> dict:
        nome = nome.strip().replace("/", "-")
        if not nome:
            return {"ok": False, "errore": T("Nome non valido")}
        try:
            nuovo = _f(uri).set_display_name(nome, None)
            return {"ok": True, "uri": nuovo.get_uri()}
        except GLib.Error as e:
            return {"ok": False, "errore": e.message}

    def cestino(self, uris) -> dict:
        errori = []
        for uri in uris:
            try:
                _f(str(uri)).trash(None)
            except GLib.Error as e:
                errori.append(e.message)
        return {"ok": not errori, "errore": errori[0] if errori else ""}

    def eliminaDefinitivamente(self, uris) -> dict:
        errori = []
        for uri in uris:
            try:
                self._elimina(_f(str(uri)))
            except GLib.Error as e:
                errori.append(e.message)
        return {"ok": not errori, "errore": errori[0] if errori else ""}

    def svuotaCestino(self) -> dict:
        cestino = Gio.File.new_for_uri("trash:///")
        try:
            for info in cestino.enumerate_children("standard::name", Gio.FileQueryInfoFlags.NONE, None):
                self._elimina(cestino.get_child(info.get_name()))
            return {"ok": True}
        except GLib.Error as e:
            return {"ok": False, "errore": e.message}

    def ripristina(self, uris) -> dict:
        """Rimette al loro posto gli elementi del cestino."""
        errori = []
        for uri in uris:
            f = _f(str(uri))
            try:
                info = f.query_info("trash::orig-path", Gio.FileQueryInfoFlags.NONE, None)
                originale = info.get_attribute_byte_string("trash::orig-path")
                f.move(Gio.File.new_for_path(originale), Gio.FileCopyFlags.NONE, None, None, None)
            except GLib.Error as e:
                errori.append(e.message)
        return {"ok": not errori, "errore": errori[0] if errori else ""}

    # Appunti di sistema: copia/taglia/incolla anche tra File, Scrivania e altre app
    def copiaTesto(self, testo: str) -> None:
        subprocess.run(["wl-copy", "--", str(testo)], timeout=5, check=False)

    def copia(self, uris, taglia: bool = False) -> bool:
        from .. import appunti

        return appunti.copia([str(u) for u in uris], bool(taglia))

    def appunti(self) -> dict:
        from .. import appunti

        return appunti.leggi()

    def appuntiPieni(self) -> bool:
        return bool(self.appunti()["uri"])

    def svuotaAppunti(self) -> None:
        from .. import appunti

        appunti.svuota()

    def trasferisci(self, uris, cartella: str, modo="auto", _svuota: bool = False) -> dict:
        """Copia o sposta (anche cartelle intere) con la barra di avanzamento.
        modo: «auto» (come Windows: sposta sullo stesso disco, copia su un altro), «copia», «sposta».
        Per compatibilità accetta anche True (= sposta) / False (= auto)."""
        from .. import trasferimenti

        if modo is True:
            modo = "sposta"
        elif modo is False or modo not in ("auto", "copia", "sposta"):
            modo = "auto"
        return trasferimenti.trasferisci([str(u) for u in uris], cartella, modo,
                                         lambda fatti, totale, nome: self.emetti("avanzamento", {"fatti": fatti, "totale": totale, "nome": nome}))

    def _elimina(self, f: Gio.File):
        from .. import trasferimenti

        trasferimenti.elimina(f)

    # ── Proprietà ──────────────────────────────────────────────────────────
    def proprieta(self, uri: str) -> dict:
        f = _f(uri)
        try:
            info = f.query_info("*", Gio.FileQueryInfoFlags.NONE, None)
        except GLib.Error as e:
            return {"ok": False, "errore": e.message}
        tipo = info.get_file_type()
        cartella = tipo == Gio.FileType.DIRECTORY
        mod = info.get_modification_date_time()
        acc = info.get_access_date_time()
        cre = info.get_creation_date_time() if hasattr(info, "get_creation_date_time") else None
        contenuto = info.get_content_type() or ""
        r = {
            "ok": True, "nome": info.get_display_name(), "uri": f.get_uri(), "cartella": cartella,
            "icona": _icona(info), "posizione": (f.get_parent().get_path() or f.get_parent().get_uri()) if f.get_parent() else "",
            "tipo": Gio.content_type_get_description(contenuto) if contenuto else "",
            "mime": contenuto, "dimensione": "" if cartella else f"{_dimensione(info.get_size())} ({info.get_size():,} byte)".replace(",", "."),
            "modificato": mod.format("%d/%m/%Y %H:%M") if mod else "",
            "accesso": acc.format("%d/%m/%Y %H:%M") if acc else "",
            "creato": cre.format("%d/%m/%Y %H:%M") if cre else "",
            "proprietario": info.get_attribute_string("owner::user") or "",
            "permessi": self._permessi(info),
            "leggibile": info.get_attribute_boolean("access::can-read"),
            "scrivibile": info.get_attribute_boolean("access::can-write"),
            "eseguibile": info.get_attribute_boolean("access::can-execute"),
        }
        try:
            fs = f.query_filesystem_info("filesystem::free,filesystem::size,filesystem::type", None)
            libero, totale = fs.get_attribute_uint64("filesystem::free"), fs.get_attribute_uint64("filesystem::size")
            r["spazio"] = T("{l} liberi su {t}", l=_dimensione(libero), t=_dimensione(totale)) if totale else ""
            r["filesystem"] = fs.get_attribute_string("filesystem::type") or ""
        except GLib.Error:
            r["spazio"] = ""
        return r

    def _permessi(self, info: Gio.FileInfo) -> str:
        modo = info.get_attribute_uint32("unix::mode")
        if not modo:
            return ""
        def terna(m):
            return ("r" if m & 4 else "-") + ("w" if m & 2 else "-") + ("x" if m & 1 else "-")
        return terna(modo >> 6 & 7) + terna(modo >> 3 & 7) + terna(modo & 7)

    def contenutoCartella(self, uri: str) -> dict:
        """Dimensione totale e numero di elementi di una cartella (calcolato in background)."""
        totale, file, cartelle = 0, 0, 0
        limite = time.monotonic() + 20
        pila = [_f(uri)]
        while pila and time.monotonic() < limite:
            c = pila.pop()
            try:
                for info in c.enumerate_children("standard::name,standard::type,standard::size",
                                                 Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, None):
                    if info.get_file_type() == Gio.FileType.DIRECTORY:
                        cartelle += 1
                        pila.append(c.get_child(info.get_name()))
                    else:
                        file += 1
                        totale += info.get_size()
            except GLib.Error:
                continue
        return {"testo": T("{f} file e {c} cartelle, {d}", f=file, c=cartelle, d=_dimensione(totale)) + ("" if not pila else " …")}

    def impostaEseguibile(self, uri: str, si: bool) -> bool:
        p = _f(uri).get_path()
        if not p:
            return False
        modo = os.stat(p).st_mode
        os.chmod(p, modo | 0o111 if si else modo & ~0o111)
        return True

    # ── Rete e dispositivi ─────────────────────────────────────────────────
    def collega(self, uri: str, utente: str = "", password: str = "", dominio: str = "") -> dict:
        """Collega una posizione di rete (smb://, sftp://, ftp://, dav://) o un volume."""
        risultato = {"ok": False, "errore": ""}
        fatto = threading.Event()
        contesto = GLib.MainContext.new()
        ciclo = GLib.MainLoop.new(contesto, False)

        def esegui():
            contesto.push_thread_default()
            op = Gio.MountOperation()
            op.set_username(utente or "")
            op.set_password(password or "")
            op.set_domain(dominio or "WORKGROUP")
            op.set_anonymous(not utente)
            op.set_password_save(Gio.PasswordSave.FOR_SESSION)

            def chiede_password(o, messaggio, utente_pred, dominio_pred, flag):
                o.reply(Gio.MountOperationResult.HANDLED if (utente or not flag & Gio.AskPasswordFlags.NEED_USERNAME)
                        else Gio.MountOperationResult.ABORTED)

            op.connect("ask-password", chiede_password)

            def finito(f, res):
                try:
                    f.mount_enclosing_volume_finish(res)
                    risultato["ok"] = True
                except GLib.Error as e:
                    if e.matches(Gio.io_error_quark(), Gio.IOErrorEnum.ALREADY_MOUNTED):
                        risultato["ok"] = True
                    else:
                        risultato["errore"] = e.message
                        risultato["password"] = e.matches(Gio.io_error_quark(), Gio.IOErrorEnum.FAILED_HANDLED) or \
                            e.matches(Gio.io_error_quark(), Gio.IOErrorEnum.PERMISSION_DENIED)
                ciclo.quit()

            if uri.startswith("volume:"):
                nome = uri[7:]
                for v in Gio.VolumeMonitor.get().get_volumes():
                    if v.get_identifier("unix-device") == nome or v.get_name() == nome:
                        def volume_finito(vol, res):
                            try:
                                vol.mount_finish(res)
                                risultato["ok"] = True
                                risultato["uri"] = vol.get_mount().get_root().get_uri() if vol.get_mount() else ""
                            except GLib.Error as e:
                                risultato["errore"] = e.message
                            ciclo.quit()
                        v.mount(Gio.MountMountFlags.NONE, op, None, volume_finito)
                        break
                else:
                    risultato["errore"] = T("Dispositivo non trovato")
                    ciclo.quit()
            else:
                _f(uri).mount_enclosing_volume(Gio.MountMountFlags.NONE, op, None, finito)
            ciclo.run()
            contesto.pop_thread_default()
            fatto.set()

        threading.Thread(target=esegui, daemon=True).start()
        fatto.wait(60)
        return risultato

    def espelli(self, uri: str) -> dict:
        for mount in Gio.VolumeMonitor.get().get_mounts():
            if mount.get_root().get_uri() == uri:
                fatto = threading.Event()
                esito = {"ok": False}
                contesto = GLib.MainContext.new()
                ciclo = GLib.MainLoop.new(contesto, False)

                def esegui():
                    contesto.push_thread_default()

                    def finito(m, res):
                        try:
                            (m.eject_with_operation_finish if m.can_eject() else m.unmount_with_operation_finish)(res)
                            esito["ok"] = True
                        except GLib.Error as e:
                            esito["errore"] = e.message
                        ciclo.quit()

                    if mount.can_eject():
                        mount.eject_with_operation(Gio.MountUnmountFlags.NONE, None, None, finito)
                    else:
                        mount.unmount_with_operation(Gio.MountUnmountFlags.NONE, None, None, finito)
                    ciclo.run()
                    contesto.pop_thread_default()
                    fatto.set()

                threading.Thread(target=esegui, daemon=True).start()
                fatto.wait(30)
                return esito
        return {"ok": False, "errore": T("Dispositivo non trovato")}

    # ── Azioni sui file ────────────────────────────────────────────────────
    def convertiPdf(self, uris) -> None:
        percorsi = [p for p in (_f(str(u)).get_path() for u in uris) if p]
        if percorsi:
            avvia(["/usr/libexec/nucleo/converti-pdf", *percorsi])

    def comprimi(self, uris) -> None:
        percorsi = [p for p in (_f(str(u)).get_path() for u in uris) if p]
        if percorsi:
            from .. import branding

            avvia([branding.comando("archivi"), "--comprimi", *percorsi])

    def estrai(self, uris) -> None:
        percorsi = [p for p in (_f(str(u)).get_path() for u in uris) if p]
        if percorsi:
            from .. import branding

            avvia([branding.comando("archivi"), "--estrai", *percorsi])

    def condividi(self, uris) -> None:
        percorsi = [p for p in (_f(str(u)).get_path() for u in uris) if p]
        if percorsi:
            from .. import branding

            avvia([branding.comando("condividi"), *percorsi])

    def aggiungiSegnalibro(self, uri: str) -> None:
        file_segnalibri = Path(GLib.get_user_config_dir()) / "gtk-3.0" / "bookmarks"
        file_segnalibri.parent.mkdir(parents=True, exist_ok=True)
        righe = file_segnalibri.read_text().splitlines() if file_segnalibri.exists() else []
        if not any(r.split(" ")[0] == uri for r in righe):
            righe.append(uri)
            file_segnalibri.write_text("\n".join(righe) + "\n")

    def percorsoLocale(self, uri: str) -> str:
        return _f(uri).get_path() or ""

    def cerca(self, uri: str, testo: str) -> list:
        """Cerca per nome nella cartella e nelle sottocartelle (al massimo 300 risultati, 15 secondi)."""
        testo = testo.lower()
        risultati, pila = [], [_f(uri)]
        limite = time.monotonic() + 15
        while pila and len(risultati) < 300 and time.monotonic() < limite:
            c = pila.pop()
            try:
                for info in c.enumerate_children(ATTRIBUTI, Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, None):
                    if info.get_is_hidden():
                        continue
                    figlio = c.get_child(info.get_name())
                    cartella = info.get_file_type() == Gio.FileType.DIRECTORY
                    if cartella:
                        pila.append(figlio)
                    if testo in (info.get_display_name() or "").lower():
                        risultati.append({"nome": info.get_display_name(), "uri": figlio.get_uri(), "cartella": cartella,
                                          "dimensione": -1 if cartella else info.get_size(),
                                          "testoDimensione": "" if cartella else _dimensione(info.get_size()),
                                          "modificato": "", "ordinaData": 0, "tipo": c.get_path() or "", "icona": _icona(info),
                                          "anteprima": "", "miniatura": ""})
            except GLib.Error:
                continue
        return risultati


def _icona_di(icona) -> str:
    if isinstance(icona, Gio.ThemedIcon):
        nomi = icona.get_names()
        return nomi[0] if nomi else "drive-harddisk"
    return "drive-harddisk"


def main() -> int:
    return esegui_app("file", "File/Main.qml", lambda app: {"ponte": crea_ponte(BackendFile())})


if __name__ == "__main__":
    sys.exit(main())
