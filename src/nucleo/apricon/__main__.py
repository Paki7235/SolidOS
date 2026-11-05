"""«Apri con…»: gestore di riserva per i tipi di file sconosciuti.

Mostra il tipo reale del file (libmagic), un'anteprima (testo o esadecimale),
le app installate che lo aprono, e le app consigliate da installare.
Uso: <OS_ID>-apri-con FILE
"""

from __future__ import annotations

import configparser
import sys
from pathlib import Path

from .. import branding
from ..formati import descrizione, estensione_ingannevole, suggerimenti, tipo_installabile, tipo_mime
from ..i18n import T
from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app
from ..sistema import avvia, avvia_desktop, esegui

CARTELLE_APP = [Path("/usr/share/applications"), Path.home() / ".local/share/applications",
                Path("/var/lib/flatpak/exports/share/applications"),
                Path.home() / ".local/share/flatpak/exports/share/applications"]


def app_desktop() -> list[dict]:
    risultato = []
    for cartella in CARTELLE_APP:
        if not cartella.is_dir():
            continue
        for f in cartella.glob("*.desktop"):
            c = configparser.RawConfigParser(strict=False, interpolation=None)
            try:
                c.read(f, encoding="utf-8")
                v = c["Desktop Entry"]
            except (configparser.Error, KeyError, UnicodeDecodeError):
                continue
            if v.get("NoDisplay", "false") == "true" or "Exec" not in v:
                continue
            risultato.append({"desktop": f.name, "nome": v.get("Name[it]", v.get("Name", f.stem)),
                              "icona": v.get("Icon", "application-x-executable"),
                              "mime": [m for m in v.get("MimeType", "").split(";") if m]})
    return risultato


class BackendApriCon(Backend):
    def file(self) -> str:
        argomenti = [a for a in sys.argv[1:] if not a.startswith("-")]
        return argomenti[0].removeprefix("file://") if argomenti else ""

    def analizza(self, percorso: str) -> dict:
        p = Path(percorso)
        mime = tipo_mime(percorso)
        tutte = app_desktop()
        compatibili = [a for a in tutte if mime in a["mime"]]
        generiche = [a for a in tutte if mime.startswith("text/") and "text/plain" in a["mime"]]
        anteprima, binario = "", False
        try:
            dati = p.read_bytes()[:4096]
            try:
                anteprima = dati.decode("utf-8")
            except UnicodeDecodeError:
                binario = True
                anteprima = "\n".join(
                    f"{i:08x}  " + " ".join(f"{b:02x}" for b in dati[i:i + 16])
                    for i in range(0, min(len(dati), 512), 16))
        except OSError:
            pass
        return {
            "nome": p.name, "dimensione": round(p.stat().st_size / 1024, 1) if p.exists() else 0,
            "mime": mime, "descrizione": descrizione(percorso), "anteprima": anteprima, "binario": binario,
            "compatibili": compatibili or generiche, "tutte": sorted(tutte, key=lambda a: a["nome"].lower()),
            "suggerite": suggerimenti(percorso), "installabile": bool(tipo_installabile(percorso)),
            "sospetto": estensione_ingannevole(percorso),
        }

    def apri(self, percorso: str, desktop: str, ricorda: bool) -> None:
        if ricorda:
            esegui(["xdg-mime", "default", desktop, tipo_mime(percorso)])
        if not avvia_desktop(desktop, [percorso]):
            avvia(["xdg-open", percorso])

    def installaApp(self, ident: str) -> None:
        avvia([branding.comando("store"), "--cerca", ident])

    def installaFile(self, percorso: str) -> None:
        avvia([branding.comando("installa"), percorso])


def main() -> int:
    return esegui_app("apri-con", "ApriCon/Main.qml", lambda app: {"ponte": crea_ponte(BackendApriCon())})


if __name__ == "__main__":
    sys.exit(main())
