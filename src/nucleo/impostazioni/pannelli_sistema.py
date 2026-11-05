"""Pannelli: Utenti, Privacy, Sicurezza, Aggiornamenti, Snapshot, App predefinite,
Lingua e regione, Data e ora, Informazioni sul sistema."""

from __future__ import annotations

import configparser
import os
import platform
import pwd
import re
from pathlib import Path

from .. import branding
from ..i18n import T
from ..sistema import (avvia, config_utente, esegui, helper, leggi_json, ram_totale_mb, scrivi_json,
                       uscita)
from .base import (Pannello, azione, campo, elenco, esito, info, interruttore, intestazione, scelta)


def _esito_helper(r, ok_msg=""):
    return esito(r.returncode == 0, ok_msg if r.returncode == 0 else (r.stderr.strip() or T("Operazione annullata")))


class PannelloUtenti(Pannello):
    id = "utenti"
    titolo = T("Utenti e account")
    icona = "system-users"
    gruppo = T("Sistema")
    chiavi = "account password amministratore nuovo utente famiglia"

    def voci(self):
        io = pwd.getpwuid(os.getuid()).pw_name
        amministratori = set(uscita(["getent", "group", "sudo"]).strip().split(":")[-1].split(","))
        utenti = []
        for u in pwd.getpwall():
            if 1000 <= u.pw_uid < 60000 and not u.pw_shell.endswith(("nologin", "false")):
                azioni = [{"id": "password", "testo": T("Cambia password"),
                           "richiede": [{"id": "password", "etichetta": T("Nuova password"), "segreto": True}]}]
                if u.pw_name != io:
                    azioni.append({"id": "elimina", "testo": T("Elimina"), "pericolosa": True})
                utenti.append({"id": u.pw_name, "titolo": (u.pw_gecos.split(",")[0] or u.pw_name) + (f" ({T('tu')})" if u.pw_name == io else ""),
                               "sottotitolo": T("Amministratore") if u.pw_name in amministratori else T("Utente standard"),
                               "icona": "user-identity", "attivo": u.pw_name == io, "azioni": azioni})
        return [
            elenco("utenti", T("Utenti"), utenti),
            azione("nuovo", T("Aggiungi un utente"), T("Aggiungi"), T("La password verrà scelta al primo accesso"),
                   richiede=[{"id": "nome", "etichetta": T("Nome e cognome")},
                             {"id": "utente", "etichetta": T("Nome utente (minuscolo, senza spazi)")},
                             {"id": "amministratore", "etichetta": T("Amministratore? (si/no)")}]),
        ]

    def azione(self, voce, elemento, az, dati):
        if voce == "utenti" and az == "password":
            import subprocess

            comando = ["pkexec", "/usr/libexec/nucleo/helper", "utente-password", elemento]
            r = subprocess.run(comando, input=dati.get("password", "") + "\n", capture_output=True, text=True)
            return _esito_helper(r, T("Password cambiata"))
        if voce == "utenti" and az == "elimina":
            return _esito_helper(helper("utente-elimina", elemento), T("Utente eliminato"))
        if voce == "nuovo":
            utente = re.sub(r"[^a-z0-9_-]", "", dati.get("utente", "").lower())
            amministratore = "si" if dati.get("amministratore", "").strip().lower().startswith("s") else "no"
            return _esito_helper(helper("utente-crea", utente, dati.get("nome", utente), amministratore),
                                 T("Utente creato"))
        return None


class PannelloPrivacy(Pannello):
    id = "privacy"
    titolo = T("Privacy e permessi")
    icona = "preferences-system-privacy"
    gruppo = T("Sistema")
    chiavi = "registro attività microfono webcam fotocamera rete file trasferimenti cronologia"

    def voci(self):
        from ..privacy.registro import Registro

        conf = leggi_json(config_utente("privacy.json"), {"attivo": True, "giorni": 90})
        reg = Registro()
        eventi = reg.ultimi(40)
        nomi = {"microfono": T("Microfono"), "webcam": T("Webcam"), "rete": T("Rete"), "file": T("File"),
                "trasferimento": T("Condivisione Vicina")}
        icone = {"microfono": "audio-input-microphone", "webcam": "camera-web", "rete": "network-transmit-receive",
                 "file": "document-open-recent", "trasferimento": "document-send"}
        elementi = [{"id": str(e["id"]), "titolo": f'{e["app"]} — {nomi.get(e["tipo"], e["tipo"])}',
                     "sottotitolo": f'{e["quando"]} · {e["dettaglio"]}', "icona": icone.get(e["tipo"], "dialog-information"),
                     "attivo": False, "azioni": []} for e in eventi]
        riepilogo = reg.riepilogo()
        return [
            interruttore("attivo", T("Registra l'attività delle app"), conf.get("attivo", True),
                         T("Tiene traccia di quale app usa microfono, webcam, rete, file e trasferimenti. Resta solo su questo computer.")),
            scelta("giorni", T("Conserva il registro per"), str(conf.get("giorni", 90)),
                   [("7", T("7 giorni")), ("30", T("30 giorni")), ("90", T("90 giorni")), ("365", T("1 anno"))]),
            intestazione(T("Ultimi 7 giorni")),
            *[info("r-" + k, nomi.get(k, k), T("{n} eventi", n=v)) for k, v in riepilogo.items()],
            elenco("eventi", T("Attività recenti"), elementi, vuoto=T("Nessuna attività registrata")),
            azione("cancella", T("Cancella il registro"), T("Cancella"), pericolosa=True),
            azione("recenti", T("Cancella l'elenco dei file recenti"), T("Cancella")),
        ]

    def imposta(self, voce, valore):
        file = config_utente("privacy.json")
        conf = leggi_json(file, {"attivo": True, "giorni": 90})
        conf["attivo" if voce == "attivo" else "giorni"] = bool(valore) if voce == "attivo" else int(valore)
        scrivi_json(file, conf)
        return esito()

    def azione(self, voce, elemento, az, dati):
        if voce == "cancella":
            from ..privacy.registro import Registro

            Registro().cancella()
            return esito(True, T("Registro cancellato"))
        if voce == "recenti":
            (Path.home() / ".local/share/recently-used.xbel").unlink(missing_ok=True)
            return esito(True, T("Elenco svuotato"))
        return None


class PannelloSicurezza(Pannello):
    id = "sicurezza"
    titolo = T("Sicurezza")
    icona = "security-high"
    gruppo = T("Sistema")
    chiavi = "firewall cifratura secure boot protezione"

    def voci(self):
        firewall = esegui(["systemctl", "is-active", "firewalld"]).returncode == 0
        zona = uscita(["firewall-cmd", "--get-default-zone"]).strip() if firewall else ""
        cifrato = "crypt" in uscita(["lsblk", "-o", "TYPE"])
        sb = uscita(["mokutil", "--sb-state"]).strip() or T("Non rilevabile")
        return [
            interruttore("firewall", T("Firewall"), firewall, T("Blocca le connessioni in arrivo non richieste")),
            scelta("zona", T("Tipo di rete"), zona or "home",
                   [("home", T("Casa (fidata)")), ("work", T("Lavoro")), ("public", T("Pubblica (massima protezione)"))]),
            info("cifratura", T("Cifratura del disco"), T("Attiva") if cifrato else
                 T("Non attiva — si sceglie durante l'installazione")),
            info("secureboot", T("Secure Boot"), sb),
            info("apparmor", T("Isolamento delle app (AppArmor)"),
                 T("Attivo") if Path("/sys/module/apparmor/parameters/enabled").exists()
                 and Path("/sys/module/apparmor/parameters/enabled").read_text().strip() == "Y" else T("Non attivo")),
        ]

    def imposta(self, voce, valore):
        if voce == "firewall":
            return _esito_helper(helper("firewall", "attiva" if valore else "disattiva"))
        if voce == "zona":
            return _esito_helper(helper("firewall", "zona", str(valore)))
        return None


class PannelloAggiornamenti(Pannello):
    id = "aggiornamenti"
    titolo = T("Aggiornamenti")
    icona = "system-software-update"
    gruppo = T("Sistema")
    chiavi = "update aggiorna sistema sicurezza automatici"

    def voci(self):
        stato = leggi_json(Path("/var/lib/nucleo/aggiornamenti.json"), {})
        disponibili = uscita(["apt-get", "-s", "-o", "Debug::NoLocking=1", "upgrade"], timeout=60).count("\nInst ")
        return [
            info("stato", T("Stato"), T("{n} aggiornamenti disponibili", n=disponibili) if disponibili
                 else T("Il sistema è aggiornato")),
            info("ultimo", T("Ultimo aggiornamento"), stato.get("ultimo", T("mai"))),
            info("esito", T("Esito"), stato.get("esito", "—")),
            azione("ora", T("Aggiorna adesso"), T("Aggiorna"),
                   T("Prima di aggiornare viene creato uno snapshot: se qualcosa va storto puoi tornare indietro.")),
            info("automatici", T("Aggiornamenti automatici"),
                 T("Attivi: scaricati e installati in background ogni giorno, con snapshot preventivo")),
        ]

    def azione(self, voce, elemento, az, dati):
        if voce == "ora":
            return _esito_helper(helper("aggiorna-ora"), T("Aggiornamento avviato in background: riceverai una notifica"))
        return None


class PannelloSnapshot(Pannello):
    id = "snapshot"
    titolo = T("Snapshot e Linea del Tempo")
    icona = "document-open-recent"
    gruppo = T("Sistema")
    chiavi = "backup ripristino torna indietro ieri versioni precedenti btrfs snapper"

    def voci(self):
        from ..lineadeltempo.snapshot import elenco_snapshot, snapshot_disponibili

        if not snapshot_disponibili():
            return [info("non-disponibili", T("Linea del Tempo"),
                         T("Disponibile dopo l'installazione su disco (file system Btrfs)"))]
        snap = elenco_snapshot("root")
        return [
            info("quanti", T("Punti di ripristino del sistema"), str(len(snap))),
            info("ultimo", T("Più recente"), snap[0]["data"] if snap else "—"),
            azione("crea", T("Crea un punto di ripristino adesso"), T("Crea"),
                   richiede=[{"id": "descrizione", "etichetta": T("Descrizione")}]),
            azione("apri", T("Apri la Linea del Tempo"), T("Apri")),
            info("automatici", T("Punti automatici"), T("Ogni ora, ogni giorno e prima di ogni aggiornamento o installazione")),
            info("grub", T("Dal menu di avvio"), T("Se il sistema non parte, scegli «Torna a ieri» all'accensione")),
        ]

    def azione(self, voce, elemento, az, dati):
        if voce == "crea":
            return _esito_helper(helper("snapshot-crea", dati.get("descrizione") or "Manuale"), T("Punto di ripristino creato"))
        if voce == "apri":
            avvia([branding.comando("linea-del-tempo")])
            return esito(ricarica=False)
        return None


CATEGORIE_APP = [
    ("browser", T("Browser web"), ["x-scheme-handler/http", "x-scheme-handler/https", "text/html"]),
    ("email", T("Posta elettronica"), ["x-scheme-handler/mailto"]),
    ("file", T("Gestione file"), ["inode/directory"]),
    ("immagini", T("Immagini"), ["image/jpeg", "image/png", "image/webp", "image/heic"]),
    ("video", T("Video"), ["video/mp4", "video/x-matroska", "video/webm"]),
    ("musica", T("Musica"), ["audio/mpeg", "audio/flac", "audio/ogg"]),
    ("pdf", T("Documenti PDF"), ["application/pdf"]),
    ("testo", T("Testo"), ["text/plain"]),
]


def _app_per_mime(mime: str) -> list[tuple[str, str]]:
    risultato = []
    for cartella in (Path("/usr/share/applications"), Path.home() / ".local/share/applications",
                     Path("/var/lib/flatpak/exports/share/applications")):
        if not cartella.is_dir():
            continue
        for f in cartella.glob("*.desktop"):
            c = configparser.RawConfigParser(strict=False, interpolation=None)
            try:
                c.read(f, encoding="utf-8")
                voce = c["Desktop Entry"]
            except (configparser.Error, KeyError, UnicodeDecodeError):
                continue
            if mime in voce.get("MimeType", "").split(";") and voce.get("NoDisplay", "false") != "true":
                risultato.append((f.name, voce.get("Name[it]", voce.get("Name", f.stem))))
    return sorted(set(risultato), key=lambda x: x[1])


class PannelloAppPredefinite(Pannello):
    id = "predefinite"
    titolo = T("App predefinite")
    icona = "preferences-desktop-default-applications"
    gruppo = T("Sistema")
    chiavi = "apri con browser posta email lettore predefinito"

    def voci(self):
        voci = []
        for ident, titolo, mimes in CATEGORIE_APP:
            opzioni = _app_per_mime(mimes[0])
            attuale = uscita(["xdg-mime", "query", "default", mimes[0]]).strip()
            if opzioni:
                voci.append(scelta(ident, titolo, attuale, opzioni))
        return voci

    def imposta(self, voce, valore):
        for ident, _titolo, mimes in CATEGORIE_APP:
            if ident == voce:
                for m in mimes:
                    esegui(["xdg-mime", "default", str(valore), m])
                return esito()
        return None


LINGUE = [("it_IT.UTF-8", "Italiano"), ("en_US.UTF-8", "English (US)"), ("en_GB.UTF-8", "English (UK)"),
          ("de_DE.UTF-8", "Deutsch"), ("fr_FR.UTF-8", "Français"), ("es_ES.UTF-8", "Español"),
          ("pt_PT.UTF-8", "Português"), ("ro_RO.UTF-8", "Română"), ("pl_PL.UTF-8", "Polski")]


class PannelloLingua(Pannello):
    id = "lingua"
    titolo = T("Lingua e regione")
    icona = "preferences-desktop-locale"
    gruppo = T("Sistema")
    chiavi = "lingua language formato data valuta paese"

    def voci(self):
        attuale = re.search(r"LANG=(\S+)", uscita(["localectl", "status"]))
        return [
            scelta("lingua", T("Lingua del sistema"), attuale.group(1) if attuale else "it_IT.UTF-8", LINGUE,
                   T("Vale dal prossimo accesso. Le traduzioni delle app arrivano con gli aggiornamenti.")),
            scelta("formati", T("Formati (date, numeri, valuta)"),
                   os.environ.get("LC_TIME", attuale.group(1) if attuale else "it_IT.UTF-8"), LINGUE),
        ]

    def imposta(self, voce, valore):
        if voce == "lingua":
            r = esegui(["localectl", "set-locale", f"LANG={valore}"], timeout=60)
            return esito(r.returncode == 0, T("Vale dal prossimo accesso"))
        if voce == "formati":
            cartella = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "environment.d"
            cartella.mkdir(parents=True, exist_ok=True)
            (cartella / "60-formati.conf").write_text(
                "".join(f"{k}={valore}\n" for k in ("LC_TIME", "LC_NUMERIC", "LC_MONETARY", "LC_PAPER", "LC_MEASUREMENT")))
            return esito(True, T("Vale dal prossimo accesso"))
        return None


class PannelloDataOra(Pannello):
    id = "dataora"
    titolo = T("Data e ora")
    icona = "preferences-system-time"
    gruppo = T("Sistema")
    chiavi = "orologio fuso orario sincronizzazione ntp"

    def voci(self):
        stato = uscita(["timedatectl", "show"])
        ntp = "NTP=yes" in stato
        fuso = re.search(r"Timezone=(\S+)", stato)
        fusi = [f for f in uscita(["timedatectl", "list-timezones"]).split() if f.startswith(("Europe/", "America/", "Asia/", "Africa/", "Australia/", "UTC"))]
        return [
            interruttore("ntp", T("Imposta automaticamente"), ntp, T("Sincronizza l'ora da Internet")),
            scelta("fuso", T("Fuso orario"), fuso.group(1) if fuso else "Europe/Rome", fusi or ["Europe/Rome"]),
            campo("ora", T("Data e ora manuali"), "", T("Formato AAAA-MM-GG HH:MM (solo se l'impostazione automatica è spenta)")),
        ]

    def imposta(self, voce, valore):
        if voce == "ntp":
            return esito(esegui(["timedatectl", "set-ntp", "true" if valore else "false"], timeout=60).returncode == 0)
        if voce == "fuso":
            return esito(esegui(["timedatectl", "set-timezone", str(valore)], timeout=60).returncode == 0)
        if voce == "ora" and valore:
            return esito(esegui(["timedatectl", "set-time", f"{valore}:00"], timeout=60).returncode == 0)
        return None


class PannelloInformazioni(Pannello):
    id = "informazioni"
    titolo = T("Informazioni sul sistema")
    icona = "help-about"
    gruppo = T("Sistema")
    chiavi = "versione computer processore memoria scheda video nome dispositivo hostname"

    def voci(self):
        cpu = next((r.split(":", 1)[1].strip() for r in Path("/proc/cpuinfo").read_text().splitlines()
                    if r.startswith("model name")), platform.processor()) if Path("/proc/cpuinfo").exists() else ""
        gpu = [r.split(": ", 1)[-1] for r in uscita(["lspci"]).splitlines() if "VGA" in r or "3D" in r]
        modello = " ".join(filter(None, [Path(f"/sys/class/dmi/id/{f}").read_text().strip()
                                        if Path(f"/sys/class/dmi/id/{f}").exists() else ""
                                        for f in ("sys_vendor", "product_name")]))
        debian = Path("/etc/debian_version").read_text().strip() if Path("/etc/debian_version").exists() else ""
        return [
            info("sistema", T("Sistema"), f'{branding.nome()} {branding.get("OS_VERSION")}'),
            info("base", T("Basato su"), f"Debian {debian}"),
            campo("hostname", T("Nome del computer"), platform.node()),
            info("modello", T("Modello"), modello or "—"),
            info("cpu", T("Processore"), cpu),
            info("ram", T("Memoria"), f"{ram_totale_mb()} MB"),
            info("gpu", T("Scheda video"), ", ".join(gpu) or "—"),
            info("kernel", T("Kernel"), platform.release()),
            azione("guida", T("Guida di {s}", s=branding.nome()), T("Apri")),
        ]

    def imposta(self, voce, valore):
        if voce == "hostname":
            return _esito_helper(helper("hostname", str(valore).strip()), T("Nome cambiato"))
        return None

    def azione(self, voce, elemento, az, dati):
        if voce == "guida":
            avvia([branding.comando("guida")])
            return esito(ricarica=False)
        return None
