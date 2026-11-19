"""App store.   Uso: <OS_ID>-store [--cerca TESTO]"""

from __future__ import annotations

import sys

from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app
from . import (aggiorna_app, aggiornamenti_disponibili, aggiornamenti_flatpak, apri, cerca, installa, installate,
               installate_id, rimuovi, vetrina, vetrina_disponibile)
from . import catalogo, spiega_errore
from ..i18n import T


def _automatiche() -> bool:
    from ..sistema import config_utente, leggi_json

    return bool(leggi_json(config_utente("store.json"), {}).get("app_automatiche", True))


class BackendStore(Backend):
    def ricercaIniziale(self) -> str:
        if "--cerca" in sys.argv:
            i = sys.argv.index("--cerca")
            return sys.argv[i + 1] if i + 1 < len(sys.argv) else ""
        return ""

    def vetrina(self):
        return vetrina()

    # ── Catalogo di Flathub (come l'App Store) ───────────────────────────
    def collezione(self, nome):
        return catalogo.collezione(nome)

    def categorie(self):
        return catalogo.categorie()

    def categoria(self, nome):
        return catalogo.categoria(nome)

    def cercaCatalogo(self, testo):
        """Prima il catalogo online (solo app per questo processore), poi i pacchetti Debian."""
        risultati = catalogo.cerca(testo)
        visti = {r["id"] for r in risultati}
        for r in cerca(testo):
            if r["id"] not in visti and (r["origine"] == "apt" or not risultati):
                risultati.append(r)
        return risultati

    def dettagli(self, ident):
        return catalogo.dettagli(ident)

    # ── Raccolte e recensioni ────────────────────────────────────────────
    def raccolte(self):
        return catalogo.raccolte()

    def raccolteDi(self, ident):
        return catalogo.raccolte_di(ident)

    def piuAmate(self):
        """Le app con il voto più alto dalle recensioni di chi usa SolidOS."""
        from .. import recensioni

        voti = recensioni.piu_amate()
        app = catalogo._molte([v["app"] for v in voti])
        per_id = {v["app"]: v for v in voti}
        for a in app:
            a["media"], a["totale"] = per_id[a["id"]]["media"], per_id[a["id"]]["totale"]
        return app

    def recensioni(self, ident):
        from .. import recensioni

        return {"riepilogo": recensioni.riepilogo(ident), "elenco": recensioni.elenco(ident),
                "account": recensioni.collegato()}

    def scriviRecensione(self, ident, voto, titolo, testo):
        from .. import recensioni

        return recensioni.scrivi(ident, voto, titolo, testo)

    def cancellaRecensione(self, ident):
        from .. import recensioni

        return recensioni.cancella(ident)

    def recensioneUtile(self, recensione):
        from .. import recensioni

        return recensioni.utile(recensione)

    def installateId(self):
        return installate_id()

    def apri(self, ident, origine="flatpak"):
        return apri(ident, origine)

    def aggiornamenti(self):
        return aggiornamenti_disponibili()

    def aggiornaApp(self, ident):
        return aggiorna_app(ident)

    def vetrinaDisponibile(self):
        return vetrina_disponibile()

    def prepara(self) -> dict:
        """All'apertura: Flathub e il suo catalogo (la prima volta lo scarica, un minuto circa)."""
        from ..installa import prepara_flathub
        from ..sistema import esiste

        if not esiste("flatpak"):
            return {"ok": False, "messaggio": "Flatpak non è installato"}
        prepara_flathub()
        return {"ok": True}

    def cerca(self, testo):
        return cerca(testo)

    def installate(self):
        return installate()

    def installa(self, ident, origine, nome="", icona=""):
        from .. import appmie

        if origine == "flatpak":
            # Con la percentuale per la barra di avanzamento
            from ..installa import prepara_flathub

            prepara_flathub()
            codice, uscita = appmie.flatpak_installa(
                ident, lambda p, fase: self.emetti("avanzamento", {"id": ident, "percento": p, "fase": fase}))
            r = ({"ok": True, "messaggio": T("Installata: la trovi nel menu delle app")} if codice == 0
                 else {"ok": False, "messaggio": spiega_errore(uscita)})
        else:
            r = installa(ident, origine)
        if r.get("ok"):
            appmie.aggiungi(ident, nome, icona)   # entra in «Le mie app» del Solid ID
        return r

    # ── Le mie app: quelle prese con lo stesso Solid ID (anche sul telefono) ──
    def mieApp(self):
        from .. import appmie

        presenti = set(installate_id())
        elenco = appmie.elenco()
        for a in elenco:
            a["installata"] = a.get("app") in presenti
        return {"collegato": appmie.collegato(), "elenco": elenco, "automatiche": _automatiche()}

    def impostaAutomatiche(self, si):
        from ..sistema import config_utente, scrivi_json

        scrivi_json(config_utente("store.json"), {"app_automatiche": bool(si)})
        return {"ok": True}

    def scaricaMie(self):
        """Scarica da sole le app prese sugli altri dispositivi (se l'impostazione è accesa)."""
        from .. import appmie

        if not _automatiche() or not appmie.collegato():
            return {"ok": True, "scaricate": 0}
        n = 0
        for a in appmie.da_scaricare(set(installate_id())):
            if self.installa(a["app"], "flatpak", a.get("nome", ""), a.get("icona", "")).get("ok"):
                n += 1
                self.emetti("scaricata", {"id": a["app"], "nome": a.get("nome", "")})
        return {"ok": True, "scaricate": n}

    def togliMia(self, ident):
        from .. import appmie

        return appmie.togli(ident)

    def rimuovi(self, ident, origine, sistema=False):
        return rimuovi(ident, origine, bool(sistema))

    def aggiorna(self):
        return aggiornamenti_flatpak()


def main() -> int:
    return esegui_app("store", "Store/Main.qml", lambda app: {"ponte": crea_ponte(BackendStore())})


if __name__ == "__main__":
    sys.exit(main())
