"""Pannelli: Aspetto, Pannello e Dock, Notifiche, Spazi, Accessibilità."""

from __future__ import annotations

import configparser
import os
import shutil
from pathlib import Path

from .. import branding, labwc
from ..dbusutil import chiama
from ..i18n import T
from ..sistema import avvia, config_utente, esegui, leggi_json, notifica, scrivi_json
from .base import (Pannello, azione, campo, cursore, elenco, esito, info, interruttore, intestazione,
                   scelta)

ACCENTI = [("#3B82F6", T("Blu")), ("#8B5CF6", T("Viola")), ("#EC4899", T("Rosa")), ("#EF4444", T("Rosso")),
           ("#F97316", T("Arancione")), ("#EAB308", T("Giallo")), ("#22C55E", T("Verde")), ("#14B8A6", T("Turchese")),
           ("#64748B", T("Grafite"))]


def _lxqt_conf() -> Path:
    file = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "lxqt" / "lxqt.conf"
    file.parent.mkdir(parents=True, exist_ok=True)
    if not file.exists() and Path("/etc/xdg/lxqt/lxqt.conf").exists():
        shutil.copy("/etc/xdg/lxqt/lxqt.conf", file)
    return file


def _ini(file: Path) -> configparser.RawConfigParser:
    c = configparser.RawConfigParser(strict=False)
    c.optionxform = str
    c.read(file, encoding="utf-8")
    return c


def _salva_ini(c: configparser.RawConfigParser, file: Path) -> None:
    with open(file, "w", encoding="utf-8") as f:
        c.write(f, space_around_delimiters=False)


def riavvia_pannello() -> None:
    """Riavvia la shell (barra, Dock, scrivania) per ricaricare icone e impostazioni."""
    esegui(["pkill", "-f", "python3 -m nucleo.shell$"])
    stato = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / branding.id_os()
    stato.mkdir(parents=True, exist_ok=True)
    import subprocess

    ambiente = {k: v for k, v in os.environ.items() if k not in ("QT_WAYLAND_SHELL_INTEGRATION", "QT_SCALE_FACTOR")}
    with open(stato / "shell.log", "a") as registro:
        subprocess.Popen([branding.comando("shell")], stdout=registro, stderr=registro, stdin=subprocess.DEVNULL,
                         start_new_session=True, env=ambiente)


class PannelloAspetto(Pannello):
    id = "aspetto"
    titolo = T("Aspetto")
    icona = "preferences-desktop-theme"
    gruppo = T("Personalizzazione")
    chiavi = "tema scuro chiaro colore accento sfondo font carattere icone"

    def _sfondi(self) -> list[Path]:
        cartelle = [Path("/usr/share/backgrounds"), Path.home() / ".local/share/backgrounds"]
        # le versioni «-chiaro» degli sfondi del sistema non si elencano: il tema le sceglie da solo
        return sorted(p for c in cartelle if c.is_dir() for p in c.rglob("*")
                      if p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp")
                      and not (p.stem.endswith("-chiaro") and p.with_name(p.stem.removesuffix("-chiaro") + p.suffix).exists()))[:40]

    def voci(self):
        pref = leggi_json(config_utente("aspetto.json"), {})
        conf = _ini(_lxqt_conf())
        temi_icone = sorted({p.name for p in Path("/usr/share/icons").iterdir()
                             if (p / "index.theme").exists() and not p.name.startswith(("hicolor", "default"))}) \
            if Path("/usr/share/icons").is_dir() else []
        from ..sistema import sfondo_attuale as _sfondo

        sfondo_attuale = _sfondo()
        chiaro = pref.get("tema") == "chiaro"

        def uguale(p: Path) -> bool:      # «notte.png» e «notte-chiaro.png» sono lo stesso sfondo
            a = Path(sfondo_attuale)
            return p.parent == a.parent and p.stem.removesuffix("-chiaro") == a.stem.removesuffix("-chiaro") and p.suffix == a.suffix

        def anteprima(p: Path) -> str:
            v = p.with_name(p.stem + "-chiaro" + p.suffix)
            return str(v) if chiaro and v.exists() else str(p)

        return [
            scelta("tema", T("Tema"), pref.get("tema", "scuro"), [("scuro", T("Scuro")), ("chiaro", T("Chiaro"))]),
            scelta("accento", T("Colore d'accento"), pref.get("accento", branding.get("COLORE_ACCENTO")), ACCENTI),
            intestazione(T("Sfondo")),
            elenco("sfondi", T("Sfondi"), [{
                "id": str(p), "titolo": p.stem.replace("-", " ").capitalize(),
                "sottotitolo": T("Chiaro e scuro, segue il tema") if p.with_name(p.stem + "-chiaro" + p.suffix).exists() else str(p.parent),
                "icona": anteprima(p), "attivo": uguale(p),
                "azioni": [] if uguale(p) else [{"id": "usa", "testo": T("Usa")}]} for p in self._sfondi()]),
            azione("sfondo-file", T("Usa un'immagine personale"), T("Scegli…"), file=True),
            intestazione(T("Testo e icone")),
            scelta("font-dimensione", T("Dimensione del testo"), pref.get("font_dimensione", branding.get("FONT_UI_DIMENSIONE", "10")),
                   [("9", T("Piccolo")), ("10", T("Normale")), ("11", T("Medio")), ("12", T("Grande")), ("14", T("Molto grande"))]),
            scelta("icone", T("Tema delle icone"), conf.get("General", "icon_theme", fallback=branding.get("TEMA_ICONE")),
                   temi_icone or [branding.get("TEMA_ICONE")]),
        ]

    def _pref(self, chiave, valore):
        file = config_utente("aspetto.json")
        pref = leggi_json(file, {})
        pref[chiave] = valore
        scrivi_json(file, pref)

    def _applica_palette(self):
        """Allinea la palette delle app Qt (lxqt.conf) al tema scelto."""
        pref = leggi_json(config_utente("aspetto.json"), {})
        chiaro = pref.get("tema") == "chiaro"
        accento = pref.get("accento", branding.get("COLORE_ACCENTO"))
        file = _lxqt_conf()
        c = _ini(file)
        if not c.has_section("Palette"):
            c.add_section("Palette")
        valori = {
            "window_color": "#F5F7FB" if chiaro else branding.get("COLORE_SUPERFICIE_SCURA"),
            "base_color": "#FFFFFF" if chiaro else branding.get("COLORE_SFONDO_SCURO"),
            "alt_base_color": "#EEF2F8" if chiaro else branding.get("COLORE_SUPERFICIE_SCURA"),
            "button_color": "#EEF2F8" if chiaro else branding.get("COLORE_SUPERFICIE_SCURA"),
            "window_text_color": branding.get("COLORE_TESTO_SCURO") if chiaro else branding.get("COLORE_TESTO_CHIARO"),
            "text_color": branding.get("COLORE_TESTO_SCURO") if chiaro else branding.get("COLORE_TESTO_CHIARO"),
            "button_text_color": branding.get("COLORE_TESTO_SCURO") if chiaro else branding.get("COLORE_TESTO_CHIARO"),
            "highlight_color": accento, "link_color": accento,
        }
        for k, v in valori.items():
            c.set("Palette", k, v)
        _salva_ini(c, file)
        # GTK (Firefox, LibreOffice in parte)
        gtk = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "gtk-3.0" / "settings.ini"
        gtk.parent.mkdir(parents=True, exist_ok=True)
        g = _ini(gtk)
        if not g.has_section("Settings"):
            g.add_section("Settings")
        g.set("Settings", "gtk-application-prefer-dark-theme", "false" if chiaro else "true")
        _salva_ini(g, gtk)
        # Icone: simboli scuri sul tema chiaro (solo se si usano le icone del sistema)
        c = _ini(file)
        icone = c.get("General", "icon_theme", fallback=branding.id_os()) if c.has_section("General") else branding.id_os()
        if icone in (branding.id_os(), branding.id_os() + "-chiaro"):
            if not c.has_section("General"):
                c.add_section("General")
            c.set("General", "icon_theme", branding.id_os() + ("-chiaro" if chiaro else ""))
            _salva_ini(c, file)
        # Bordi e pulsanti delle finestre
        from .. import labwc

        labwc.imposta({"theme/name": branding.nome() + ("-Chiaro" if chiaro else "")})

    def imposta(self, voce, valore):
        if voce in ("tema", "accento"):
            self._pref(voce, str(valore))
            self._applica_palette()
            return esito(True, T("Aspetto aggiornato"))
        if voce == "font-dimensione":
            self._pref("font_dimensione", str(valore))
            # anche le app non nostre (Qt) usano il carattere più grande
            file = _lxqt_conf()
            c = _ini(file)
            if not c.has_section("Qt"):
                c.add_section("Qt")
            c.set("Qt", "font", f'"{branding.get("FONT_UI")},{valore},-1,5,50,0,0,0,0,0"')
            _salva_ini(c, file)
            return esito(True, T("Testo più grande nelle app che apri da ora (riapri quelle già aperte)"))
        if voce == "icone":
            file = _lxqt_conf()
            c = _ini(file)
            if not c.has_section("General"):
                c.add_section("General")
            c.set("General", "icon_theme", str(valore))
            _salva_ini(c, file)
            riavvia_pannello()
            return esito(True, T("Icone cambiate: le app aperte le useranno quando le riapri"))
        return None

    def _imposta_sfondo(self, percorso: str):
        from ..sistema import imposta_sfondo

        imposta_sfondo(percorso)

    def azione(self, voce, elemento, az, dati):
        if voce == "sfondi" and az == "usa":
            self._imposta_sfondo(elemento)
            return esito()
        if voce == "sfondo-file" and dati.get("file"):
            destinazione = Path.home() / ".local/share/backgrounds"
            destinazione.mkdir(parents=True, exist_ok=True)
            copia = destinazione / Path(dati["file"]).name
            shutil.copy(dati["file"], copia)
            self._imposta_sfondo(str(copia))
            return esito()
        return None


def _panel_conf() -> Path:
    file = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "lxqt" / "panel.conf"
    file.parent.mkdir(parents=True, exist_ok=True)
    if not file.exists() and Path("/etc/xdg/lxqt/panel.conf").exists():
        shutil.copy("/etc/xdg/lxqt/panel.conf", file)
    return file


class PannelloPannello(Pannello):
    id = "pannello"
    titolo = T("Barra e Dock")
    icona = "preferences-desktop"
    gruppo = T("Personalizzazione")
    chiavi = "barra delle applicazioni dock stile mac windows cestino orologio icone start"

    def voci(self):
        pref = leggi_json(config_utente("aspetto.json"), {})
        return [
            intestazione(T("Disposizione")),
            scelta("barra", T("Stile"), "windows" if pref.get("barra") == "windows" else "mac",
                   [("mac", T("Barra in alto e Dock")),
                    ("windows", T("Una barra unica in basso"))]),
            info("spiegazione", T("Barra unica: menu S, app, orologio, Wi-Fi e centro di controllo in basso"), ""),
            intestazione(T("Dock")),
            scelta("dockLato", T("Dimensione delle icone"), str(pref.get("dockLato", 48)),
                   [("40", T("Piccole")), ("48", T("Medie")), ("56", T("Grandi"))]),
            interruttore("barraPrestazioni", T("Mostra processore e memoria nella barra"), pref.get("barraPrestazioni", True)),
            azione("ripristina", T("App del Dock predefinite"), T("Ripristina"),
                   T("Rimette le app iniziali; il Cestino resta sempre in fondo"), pericolosa=True),
        ]

    def imposta(self, voce, valore):
        file = config_utente("aspetto.json")
        pref = leggi_json(file, {})
        if voce == "barra":
            pref["barra"] = "windows" if valore == "windows" else "mac"
        elif voce == "dockLato":
            pref["dockLato"] = int(valore)
        elif voce == "barraPrestazioni":
            pref["barraPrestazioni"] = bool(valore)
        else:
            return esito(False, T("Impostazione sconosciuta"))
        scrivi_json(file, pref)   # la shell lo vede subito e cambia disposizione
        return esito()

    def azione(self, voce, elemento, az, dati):
        if voce == "ripristina":
            config_utente("dock.json").unlink(missing_ok=True)
            from ..dbusutil import chiama as _chiama

            _chiama(branding.nome_dbus("Shell"), branding.percorso_dbus("Shell"), branding.nome_dbus("Shell"), "Aggiorna")
            return esito(True, T("Dock ripristinato"))
        return None


class PannelloNotifiche(Pannello):
    id = "notifiche"
    titolo = T("Notifiche")
    icona = "preferences-system-notifications"
    gruppo = T("Personalizzazione")
    chiavi = "non disturbare avvisi popup"

    def _shell(self, metodo, *argomenti):
        nome = branding.nome_dbus("Shell")
        return chiama(nome, branding.percorso_dbus("Shell"), nome, metodo, *argomenti)

    def voci(self):
        pref = leggi_json(config_utente("notifiche.json"), {"non_disturbare": False})
        return [
            interruttore("non-disturbare", T("Non disturbare"), pref.get("non_disturbare", False),
                         T("Le notifiche finiscono nel centro notifiche senza comparire; quelle urgenti si vedono sempre")),
            azione("prova", T("Invia una notifica di prova"), T("Prova")),
            info("centro", T("Centro notifiche"), T("Super + N oppure l'icona nel pannello")),
        ]

    def imposta(self, voce, valore):
        if voce == "non-disturbare":
            scrivi_json(config_utente("notifiche.json"), {"non_disturbare": bool(valore)})
            self._shell("NonDisturbare", bool(valore))
            return esito()
        return None

    def azione(self, voce, elemento, az, dati):
        if voce == "prova":
            notifica(T("Notifica di prova"), T("Le notifiche funzionano correttamente."), icona=f"{branding.id_os()}-logo-chiaro")
            return esito(ricarica=False)
        return None


class PannelloSpazi(Pannello):
    id = "spazi"
    titolo = T("Spazi di vita")
    icona = "preferences-desktop-workspaces"
    gruppo = T("Personalizzazione")
    chiavi = "lavoro studio gioco famiglia profili ambienti"

    def voci(self):
        try:
            from ..spazi import elenco_spazi, spazio_corrente

            corrente = spazio_corrente().get("id")
            spazi = elenco_spazi()
        except Exception:  # noqa: BLE001
            return [info("assenti", T("Spazi di vita"), T("Non disponibili"))]
        elementi = [{
            "id": s["id"], "titolo": s["nome"], "sottotitolo": s.get("descrizione", ""), "icona": s.get("icona", ""),
            "attivo": s["id"] == corrente,
            "azioni": ([] if s["id"] == corrente else [{"id": "attiva", "testo": T("Attiva")}])
                      + [{"id": "modifica", "testo": T("Modifica")}],
        } for s in spazi]
        return [
            elenco("spazi", T("I tuoi Spazi"), elementi),
            azione("nuovo", T("Crea un nuovo Spazio"), T("Crea"),
                   richiede=[{"id": "nome", "etichetta": T("Nome dello Spazio")}]),
            info("spiegazione", T("Cosa cambia uno Spazio"),
                 T("App nel pannello, notifiche consentite, sfondo, cartelle in evidenza, risparmio energetico, rete o VPN")),
        ]

    def azione(self, voce, elemento, az, dati):
        from .. import spazi

        if voce == "spazi" and az == "attiva":
            spazi.attiva(elemento)
            return esito()
        if voce == "spazi" and az == "modifica":
            avvia(["xdg-open", str(spazi.file_spazio(elemento))])
            return esito(ricarica=False)
        if voce == "nuovo" and dati.get("nome"):
            spazi.crea(dati["nome"])
            return esito()
        return None


class PannelloAccessibilita(Pannello):
    id = "accessibilita"
    titolo = T("Accessibilità")
    icona = "preferences-desktop-accessibility"
    gruppo = T("Personalizzazione")
    chiavi = "contrasto ingrandimento lente lettore schermo orca tastiera a schermo cursore grande"

    def voci(self):
        pref = leggi_json(config_utente("accessibilita.json"), {})
        return [
            interruttore("contrasto", T("Contrasto elevato"), pref.get("contrasto", False), T("Testo e bordi più marcati")),
            interruttore("testo-grande", T("Testo grande"), pref.get("testo_grande", False)),
            interruttore("cursore-grande", T("Puntatore grande"), pref.get("cursore_grande", False)),
            interruttore("lettore", T("Lettore dello schermo (Orca)"), self._attivo("orca"), T("Legge ad alta voce ciò che è sullo schermo")),
            interruttore("tastiera", T("Tastiera a schermo"), self._attivo("wvkbd-mobintl"), T("Per usare il computer senza tastiera fisica")),
            info("lente", T("Ingrandimento"), T("Super + più / Super + meno")),
        ]

    def _attivo(self, programma):
        return esegui(["pgrep", "-x", programma[:15]]).returncode == 0

    def _pref(self, chiave, valore):
        file = config_utente("accessibilita.json")
        pref = leggi_json(file, {})
        pref[chiave] = valore
        scrivi_json(file, pref)

    def imposta(self, voce, valore):
        valore = bool(valore)
        if voce == "contrasto":
            self._pref("contrasto", valore)
            aspetto = leggi_json(config_utente("aspetto.json"), {})
            aspetto["tema"] = "chiaro" if valore else aspetto.get("tema", "scuro")
            aspetto["accento"] = "#0000CC" if valore else branding.get("COLORE_ACCENTO")
            scrivi_json(config_utente("aspetto.json"), aspetto)
            PannelloAspetto()._applica_palette()
            return esito()
        if voce == "testo-grande":
            self._pref("testo_grande", valore)
            return PannelloAspetto().imposta("font-dimensione", "12" if valore else branding.get("FONT_UI_DIMENSIONE", "10"))
        if voce == "cursore-grande":
            self._pref("cursore_grande", valore)
            labwc.imposta_ambiente({"XCURSOR_SIZE": "48" if valore else "24"})
            return esito(True, T("Vale dal prossimo accesso"))
        if voce == "lettore":
            if valore:
                avvia(["orca"])
            else:
                esegui(["pkill", "-x", "orca"])
            return esito()
        if voce == "tastiera":
            if valore:
                avvia(["wvkbd-mobintl", "-L", "280"])
            else:
                esegui(["pkill", "-f", "wvkbd-mobintl"])
            return esito()
        return None
