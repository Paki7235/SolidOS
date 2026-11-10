"""Pannelli: Schermo, Audio, Alimentazione, Tastiera, Mouse e touchpad, Stampanti, Archiviazione."""

from __future__ import annotations

import json
import re
import shutil
from pathlib import Path

from .. import branding, labwc
from ..hw import audio, energia, schermo
from ..i18n import T
from ..sistema import avvia, config_utente, esegui, leggi_json, scrivi_json, uscita
from .base import (Pannello, azione, cursore, elenco, esito, info, interruttore, intestazione,
                   scelta)


class PannelloSchermo(Pannello):
    id = "schermo"
    titolo = T("Schermo")
    icona = "video-display"
    gruppo = T("Dispositivi")
    chiavi = "monitor risoluzione scala luminosità luce notturna multi-monitor"

    def voci(self):
        voci = []
        for u in schermo.uscite():
            n = u["nome"]
            voci += [
                intestazione(f'{u["descrizione"]} ({n})'),
                interruttore(f"attivo|{n}", T("Attivo"), u["attivo"]),
                scelta(f"modo|{n}", T("Risoluzione"), u["modo"],
                       [(m, m.split("@")[0] + " · " + str(round(float(m.split("@")[1]))) + " Hz") for m in u["modi"]]),
                scelta(f"scala|{n}", T("Scala"), str(u["scala"]),
                       [("1.0", "100%"), ("1.25", "125%"), ("1.5", "150%"), ("1.75", "175%"), ("2.0", "200%")]),
                scelta(f"rotazione|{n}", T("Rotazione"), u["rotazione"],
                       [("normal", T("Normale")), ("90", "90°"), ("180", "180°"), ("270", "270°")]),
            ]
        luce = schermo.luminosita()
        if luce is not None:
            voci.insert(0, cursore("luminosita", T("Luminosità"), luce, 5, 100, unita="%"))
        notte = schermo.luce_notturna()
        voci += [
            intestazione(T("Luce notturna")),
            interruttore("notte", T("Luce notturna"), notte.get("attiva", False), T("Colori più caldi per riposare la vista")),
            cursore("temperatura", T("Calore dei colori"), notte.get("temperatura", 4000), 2500, 6000, 100, " K"),
        ]
        if not schermo.uscite():
            voci.insert(0, info("nessuno", T("Schermi"), T("Impossibile leggere gli schermi (wlr-randr)")))
        return voci

    def imposta(self, voce, valore):
        if voce == "luminosita":
            schermo.imposta_luminosita(int(valore))
            return esito(ricarica=False)
        if voce == "notte":
            schermo.imposta_luce_notturna(bool(valore), schermo.luce_notturna().get("temperatura", 4000))
            return esito()
        if voce == "temperatura":
            schermo.imposta_luce_notturna(schermo.luce_notturna().get("attiva", False), int(valore))
            return esito(ricarica=False)
        tipo, _, nome = voce.partition("|")
        if tipo == "attivo":
            r = schermo.applica_uscita(nome, attivo=bool(valore))
        elif tipo == "modo":
            r = schermo.applica_uscita(nome, modo=str(valore))
        elif tipo == "scala":
            r = schermo.applica_uscita(nome, scala=float(valore))
        elif tipo == "rotazione":
            r = schermo.applica_uscita(nome, rotazione=str(valore))
        else:
            return None
        return esito(r["ok"], r["messaggio"])


class PannelloAudio(Pannello):
    id = "audio"
    titolo = T("Audio")
    icona = "audio-volume-high"
    gruppo = T("Dispositivi")
    chiavi = "volume altoparlanti cuffie microfono suono pipewire"

    def voci(self):
        uscite = audio.dispositivi("sinks")
        ingressi = audio.dispositivi("sources")
        vol = audio.volume()
        mic = audio.volume(audio.INGRESSO)
        voci = [
            intestazione(T("Uscita")),
            cursore("volume", T("Volume"), vol["volume"], 0, 150, unita="%"),
            interruttore("muto", T("Disattiva audio"), vol["muto"]),
            scelta("uscita", T("Dispositivo di uscita"), next((d["nome"] for d in uscite if d["predefinito"]), ""),
                   [(d["nome"], d["descrizione"]) for d in uscite]),
            intestazione(T("Ingresso")),
            cursore("microfono", T("Volume del microfono"), mic["volume"], 0, 150, unita="%"),
            scelta("ingresso", T("Microfono"), next((d["nome"] for d in ingressi if d["predefinito"]), ""),
                   [(d["nome"], d["descrizione"]) for d in ingressi]),
            intestazione(T("Volume per app")),
        ]
        flussi = audio.flussi_app()
        for f in flussi:
            voci.append(cursore(f"app|{f['indice']}", f["app"], f["volume"], 0, 150, unita="%"))
        if not flussi:
            voci.append(info("nessuna-app", T("Nessuna app sta riproducendo audio"), ""))
        return voci

    def imposta(self, voce, valore):
        if voce == "volume":
            audio.imposta_volume(int(valore))
            return esito(ricarica=False)
        if voce == "microfono":
            audio.imposta_volume(int(valore), audio.INGRESSO)
            return esito(ricarica=False)
        if voce == "muto":
            audio.imposta_muto(bool(valore))
            return esito()
        if voce == "uscita":
            return esito(audio.imposta_predefinito(str(valore), "sinks"))
        if voce == "ingresso":
            return esito(audio.imposta_predefinito(str(valore), "sources"))
        if voce.startswith("app|"):
            audio.imposta_volume_app(int(voce.split("|")[1]), int(valore))
            return esito(ricarica=False)
        return None


class PannelloEnergia(Pannello):
    id = "energia"
    titolo = T("Alimentazione e batteria")
    icona = "battery"
    gruppo = T("Dispositivi")
    chiavi = "batteria risparmio energetico prestazioni sospensione blocco schermo"

    def voci(self):
        conf = leggi_json(config_utente("energia.json"), {"blocco": 10})
        batt = energia.batteria()
        prof = energia.profili()
        nomi = {"performance": T("Prestazioni"), "balanced": T("Bilanciato"), "power-saver": T("Risparmio energetico")}
        voci = []
        if batt:
            voci.append(info("batteria", T("Batteria"), f'{batt["percentuale"]}% · ' +
                             (T("In carica") if batt["in_carica"] else T("A batteria"))))
        if prof["disponibile"]:
            voci.append(scelta("profilo", T("Modalità di alimentazione"), prof["attivo"],
                               [(p, nomi.get(p, p)) for p in prof["elenco"]]))
        voci += [
            scelta("blocco", T("Blocca lo schermo dopo"), str(conf.get("blocco", 10)),
                   [("5", T("5 minuti")), ("10", T("10 minuti")), ("15", T("15 minuti")),
                    ("30", T("30 minuti")), ("0", T("Mai"))]),
            azione("sospendi", T("Sospendi ora"), T("Sospendi")),
        ]
        return voci

    def imposta(self, voce, valore):
        if voce == "profilo":
            return esito(energia.imposta_profilo(str(valore)))
        if voce == "blocco":
            minuti = int(valore)
            scrivi_json(config_utente("energia.json"), {"blocco": minuti})
            esegui(["pkill", "-x", "swayidle"])
            blocco = branding.comando("blocca")
            if minuti > 0:
                avvia(["swayidle", "-w", "timeout", str(minuti * 60), blocco, "before-sleep", blocco])
            else:
                avvia(["swayidle", "-w", "before-sleep", blocco])
            return esito()
        return None

    def azione(self, voce, elemento, az, dati):
        if voce == "sospendi":
            energia.sospendi()
            return esito(ricarica=False)
        return None


LAYOUT = [("it", "Italiano"), ("us", "Inglese (USA)"), ("gb", "Inglese (Regno Unito)"), ("de", "Tedesco"),
          ("fr", "Francese"), ("es", "Spagnolo"), ("ch", "Svizzero"), ("pt", "Portoghese"), ("ro", "Rumeno"),
          ("pl", "Polacco"), ("ru", "Russo"), ("ara", "Arabo")]


class PannelloTastiera(Pannello):
    id = "tastiera"
    titolo = T("Tastiera e scorciatoie")
    icona = "input-keyboard"
    gruppo = T("Dispositivi")
    chiavi = "layout lingua tasti scorciatoie ripetizione"

    SCORCIATOIE = [
        ("Super", T("Menu rapido")), ("Super + Spazio", T("Barra Unica")), ("Super + A", T("Centro di controllo")),
        ("Super + N", T("Notifiche")), ("Super + E", T("File")), ("Super + I", T("Impostazioni")),
        ("Super + L", T("Blocca lo schermo")), ("Super + T", T("Linea del Tempo")),
        ("Super + ← / →", T("Affianca la finestra")), ("Super + ↑", T("Ingrandisci")),
        ("Alt + Tab", T("Cambia finestra")), ("Alt + F4", T("Chiudi finestra")),
        ("Stamp", T("Cattura lo schermo")), ("Maiusc + Stamp", T("Apri Cattura")),
        ("Ctrl + Alt + T", T("Terminale")), ("Ctrl + Maiusc + Esc", T("Monitor di sistema")),
    ]

    def _layout(self) -> str:
        env = labwc.file_utente().parent / "environment"
        if env.exists():
            m = re.search(r"^XKB_DEFAULT_LAYOUT=(\S+)", env.read_text(), re.M)
            if m:
                return m.group(1)
        m = re.search(r'XKBLAYOUT="?([^"\n]*)', Path("/etc/default/keyboard").read_text()) if Path("/etc/default/keyboard").exists() else None
        return m.group(1) if m else "it"

    def voci(self):
        return [
            scelta("layout", T("Disposizione della tastiera"), self._layout(), LAYOUT),
            cursore("ripetizione", T("Velocità di ripetizione"), int(labwc.leggi("keyboard/repeatRate", None, "25") or 25), 10, 60),
            cursore("ritardo", T("Ritardo prima della ripetizione"), int(labwc.leggi("keyboard/repeatDelay", None, "600") or 600), 200, 1000, 50, " ms"),
            interruttore("numlock", T("Bloc Num attivo all'avvio"), labwc.leggi("keyboard/numlock", None, "on") == "on"),
            intestazione(T("Scorciatoie")),
            *[info(f"s{i}", descr, tasti) for i, (tasti, descr) in enumerate(self.SCORCIATOIE)],
        ]

    def imposta(self, voce, valore):
        if voce == "layout":
            labwc.imposta_ambiente({"XKB_DEFAULT_LAYOUT": str(valore)})
            return esito(True, T("Disposizione applicata"))
        if voce == "ripetizione":
            labwc.imposta({"keyboard/repeatRate": str(int(valore))})
            return esito(ricarica=False)
        if voce == "ritardo":
            labwc.imposta({"keyboard/repeatDelay": str(int(valore))})
            return esito(ricarica=False)
        if voce == "numlock":
            labwc.imposta({"keyboard/numlock": "on" if valore else "off"})
            return esito()
        return None


class PannelloMouse(Pannello):
    id = "mouse"
    titolo = T("Mouse e touchpad")
    icona = "input-mouse"
    gruppo = T("Dispositivi")
    chiavi = "puntatore velocità clic tocco scorrimento naturale touchpad"

    TP = {"category": "touchpad"}
    MOUSE = {"category": "non-touch"}

    def voci(self):
        def leggi(nodo, attr, predefinito):
            return labwc.leggi(f"libinput/device/{nodo}", attr, predefinito)

        return [
            intestazione(T("Mouse")),
            cursore("velocita-mouse", T("Velocità del puntatore"), int(float(leggi("pointerSpeed", self.MOUSE, "0") or 0) * 100), -100, 100, 10),
            interruttore("naturale-mouse", T("Scorrimento naturale"), leggi("naturalScroll", self.MOUSE, "no") == "yes"),
            interruttore("sinistro", T("Tasti invertiti (mancini)"), leggi("leftHanded", self.MOUSE, "no") == "yes"),
            intestazione(T("Touchpad")),
            cursore("velocita-tp", T("Velocità del puntatore"), int(float(leggi("pointerSpeed", self.TP, "0") or 0) * 100), -100, 100, 10),
            interruttore("tap", T("Tocca per fare clic"), leggi("tap", self.TP, "yes") == "yes"),
            interruttore("naturale-tp", T("Scorrimento naturale"), leggi("naturalScroll", self.TP, "no") == "yes"),
            interruttore("digitazione", T("Disattiva durante la digitazione"), leggi("disableWhileTyping", self.TP, "yes") == "yes"),
        ]

    def imposta(self, voce, valore):
        mappa = {
            "velocita-mouse": ("pointerSpeed", self.MOUSE, lambda v: f"{int(v) / 100:.1f}"),
            "naturale-mouse": ("naturalScroll", self.MOUSE, lambda v: "yes" if v else "no"),
            "sinistro": ("leftHanded", self.MOUSE, lambda v: "yes" if v else "no"),
            "velocita-tp": ("pointerSpeed", self.TP, lambda v: f"{int(v) / 100:.1f}"),
            "tap": ("tap", self.TP, lambda v: "yes" if v else "no"),
            "naturale-tp": ("naturalScroll", self.TP, lambda v: "yes" if v else "no"),
            "digitazione": ("disableWhileTyping", self.TP, lambda v: "yes" if v else "no"),
        }
        if voce not in mappa:
            return None
        nodo, attr, conv = mappa[voce]
        percorso = f"libinput/device/{nodo}"
        labwc.imposta({percorso: conv(valore)}, {percorso: attr})
        return esito(ricarica=False)


class PannelloStampanti(Pannello):
    id = "stampanti"
    titolo = T("Stampanti e scanner")
    icona = "printer"
    gruppo = T("Dispositivi")
    chiavi = "stampa cups scanner scansione predefinita"

    def _stampanti(self) -> list[dict]:
        predefinita = uscita(["lpstat", "-d"]).split(":")[-1].strip()
        risultato = []
        for riga in uscita(["lpstat", "-p"]).splitlines():
            m = re.match(r"\S+ (\S+) (.*)", riga)
            if riga.startswith(("printer", "stampante")) and m:
                risultato.append({"nome": m.group(1), "stato": m.group(2), "predefinita": m.group(1) == predefinita})
        return risultato

    def _trovate(self) -> list[dict]:
        risultato = []
        for riga in uscita(["lpinfo", "--include-schemes", "dnssd,usb,ipp", "-v"], timeout=30).splitlines():
            parti = riga.split(maxsplit=1)
            if len(parti) == 2 and "://" in parti[1]:
                risultato.append({"uri": parti[1]})
        return risultato

    def voci(self):
        if not shutil.which("lpstat"):
            return [info("cups", T("Stampa"), T("Il servizio di stampa non è installato"))]
        stampanti = [{
            "id": s["nome"], "titolo": s["nome"] + (" ★" if s["predefinita"] else ""), "sottotitolo": s["stato"],
            "icona": "printer", "attivo": s["predefinita"],
            "azioni": [{"id": "predefinita", "testo": T("Predefinita")}, {"id": "prova", "testo": T("Pagina di prova")},
                       {"id": "rimuovi", "testo": T("Rimuovi"), "pericolosa": True}],
        } for s in self._stampanti()]
        return [
            elenco("stampanti", T("Stampanti"), stampanti, vuoto=T("Nessuna stampante configurata")),
            azione("cerca", T("Aggiungi stampanti trovate in rete o via USB"), T("Cerca e aggiungi"),
                   T("Le stampanti moderne funzionano senza driver")),
            intestazione(T("Scanner")),
            azione("scanner", T("Scanner collegati"), T("Cerca scanner"), T("La ricerca richiede qualche secondo")),
        ]

    def azione(self, voce, elemento, az, dati):
        if voce == "scanner":
            trovati = [r for r in uscita(["scanimage", "-L"], timeout=20).splitlines() if r.startswith("device")]
            nomi = [r.split("`")[1].split("'")[0] if "`" in r else r for r in trovati]
            return esito(True, (T("Scanner trovati: ") + ", ".join(nomi)) if nomi else T("Nessuno scanner trovato"), ricarica=False)
        if voce == "cerca":
            aggiunte = 0
            for i, t in enumerate(self._trovate()):
                nome = re.sub(r"[^A-Za-z0-9_]", "_", t["uri"].split("/")[-1] or f"Stampante{i}")[:30] or f"Stampante{i}"
                if esegui(["lpadmin", "-p", nome, "-E", "-v", t["uri"], "-m", "everywhere"], timeout=60).returncode == 0:
                    aggiunte += 1
            return esito(True, T("{n} stampanti aggiunte", n=aggiunte) if aggiunte else T("Nessuna nuova stampante trovata"))
        if voce == "stampanti":
            if az == "predefinita":
                return esito(esegui(["lpoptions", "-d", elemento]).returncode == 0)
            if az == "prova":
                pagina = "/usr/share/cups/data/testprint"
                return esito(esegui(["lp", "-d", elemento, pagina]).returncode == 0, T("Pagina inviata"), ricarica=False)
            if az == "rimuovi":
                return esito(esegui(["lpadmin", "-x", elemento]).returncode == 0)
        return None


class PannelloArchiviazione(Pannello):
    id = "archiviazione"
    titolo = T("Archiviazione e dischi")
    icona = "drive-harddisk"
    gruppo = T("Sistema")
    chiavi = "spazio disco libero cestino pulizia chiavette"

    def voci(self):
        voci = []
        righe = uscita(["df", "-h", "--output=target,size,used,avail,pcent", "-x", "tmpfs", "-x", "devtmpfs",
                        "-x", "squashfs", "-x", "efivarfs"]).splitlines()[1:]
        visti = set()
        for r in righe:
            parti = r.split()
            if len(parti) == 5 and parti[0] not in visti and not parti[0].startswith(("/boot/efi", "/run/live")):
                visti.add(parti[0])
                voci.append(info("df" + parti[0], parti[0], T("{u} usati di {t} · liberi {l}", u=parti[2], t=parti[1], l=parti[3])))
        cestino = Path.home() / ".local/share/Trash/files"
        n_cestino = len(list(cestino.iterdir())) if cestino.is_dir() else 0
        return [
            intestazione(T("Spazio")), *voci,
            intestazione(T("Pulizia")),
            azione("cestino", T("Svuota il cestino") + f" ({n_cestino})", T("Svuota"), pericolosa=True),
            azione("miniature", T("Elimina le miniature salvate"), T("Elimina")),
            azione("dischi", T("Gestisci dischi e chiavette"), T("Apri Dischi")),
        ]

    def azione(self, voce, elemento, az, dati):
        if voce == "cestino":
            base = Path.home() / ".local/share/Trash"
            for sotto in ("files", "info"):
                shutil.rmtree(base / sotto, ignore_errors=True)
                (base / sotto).mkdir(parents=True, exist_ok=True)
            return esito(True, T("Cestino svuotato"))
        if voce == "miniature":
            shutil.rmtree(Path.home() / ".cache/thumbnails", ignore_errors=True)
            return esito(True, T("Miniature eliminate"))
        if voce == "dischi":
            from .. import branding

            avvia([branding.comando("dischi")])
            return esito(ricarica=False)
        return None
