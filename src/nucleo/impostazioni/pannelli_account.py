"""Pannello: Solid ID (l'account dei dispositivi SolidOS) e «Dov'è»."""

from __future__ import annotations

from .. import branding
from ..i18n import T
from .base import Pannello, azione, elenco, esito, info, interruttore, intestazione


def _quando(iso: str) -> str:
    from datetime import datetime, timezone

    try:
        t = datetime.fromisoformat(iso.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        return ""
    secondi = (datetime.now(timezone.utc) - t).total_seconds()
    if secondi < 120:
        return T("adesso")
    if secondi < 3600:
        return T("{n} minuti fa", n=int(secondi // 60))
    if secondi < 86400:
        return T("{n} ore fa", n=int(secondi // 3600))
    return t.astimezone().strftime("%d/%m/%Y %H:%M")


class PannelloSolidID(Pannello):
    id = "solidid"
    titolo = T("Solid ID")
    icona = "avatar-default"
    gruppo = T("Account")
    chiavi = "account solid id apple id accesso registrazione trova dov'è dispositivi smarrito rubato"

    def voci(self):
        from .. import solidid

        if not solidid.disponibile():
            return [info("non", T("Solid ID"), T("Non disponibile in questa versione"))]
        u = solidid.utente()
        if not u["collegato"]:
            return [
                intestazione(T("Un account per tutti i tuoi dispositivi")),
                info("spiega", T("Che cos'è"), "",
                     T("Con il Solid ID ritrovi i tuoi computer e telefoni con «Dov'è», li fai suonare o li blocchi "
                       "a distanza, e presto sincronizzi note e preferiti. È facoltativo.")),
                azione("accedi", T("Accedi"), T("Accedi"), T("Hai già un Solid ID"),
                       richiede=[{"id": "email", "etichetta": T("Email")},
                                 {"id": "password", "etichetta": T("Password"), "segreto": True}]),
                azione("crea", T("Crea il tuo Solid ID"), T("Crea"), T("Ti serve solo un indirizzo email"),
                       richiede=[{"id": "nome", "etichetta": T("Nome")},
                                 {"id": "email", "etichetta": T("Email")},
                                 {"id": "password", "etichetta": T("Password (almeno 8 caratteri)"), "segreto": True}]),
                azione("conferma", T("Non è arrivata l'email di conferma?"), T("Invia di nuovo"),
                       richiede=[{"id": "email", "etichetta": T("Email")}]),
                azione("dimenticata", T("Password dimenticata"), T("Recupera"),
                       richiede=[{"id": "email", "etichetta": T("Email")}]),
            ]
        voci = [
            intestazione(u["nome"] or u["email"]),
            info("email", T("Email"), u["email"]),
            interruttore("trova", T("Dov'è"), u["trova"],
                         T("Mostra la posizione di questo computer ai tuoi dispositivi e permette di farlo suonare "
                           "o bloccarlo a distanza. La posizione si calcola dalle reti Wi-Fi vicine.")),
        ]
        if solidid.sessione_live():
            voci.append(info("live", T("Nota"), "", T("Dalla chiavetta questo computer non viene aggiunto ai tuoi dispositivi.")))
        try:
            dispositivi = solidid.dispositivi()
            elementi = []
            for d in dispositivi:
                questo = d["id"] == u["dispositivo"]
                icona = {"telefono": "phone", "tablet": "tablet", "portatile": "computer-laptop"}.get(d["tipo"], "computer")
                dettagli = [d.get("modello") or "", _quando(d.get("ultimo_visto", ""))]
                if d.get("batteria") is not None:
                    dettagli.append(f"🔋 {d['batteria']}%")
                elementi.append({"id": d["id"], "titolo": d["nome"] + (f" ({T('questo computer')})" if questo else ""),
                                 "sottotitolo": " · ".join(x for x in dettagli if x), "icona": icona, "attivo": questo,
                                 "azioni": [{"id": "rimuovi", "testo": T("Rimuovi"), "pericolosa": True}]})
            voci.append(elenco("dispositivi", T("I tuoi dispositivi"), elementi, vuoto=T("Nessun dispositivo")))
        except Exception as e:  # noqa: BLE001
            voci.append(info("errore", T("Dispositivi"), str(e)))
        voci += [
            azione("dove", T("Trova i tuoi dispositivi"), T("Apri Dov'è")),
            azione("esci", T("Esci dal Solid ID"), T("Esci"),
                   T("Questo computer smette di comparire in «Dov'è»"), pericolosa=True),
        ]
        return voci

    def imposta(self, voce, valore):
        from .. import solidid

        if voce == "trova":
            r = solidid.imposta_trova(bool(valore))
            return esito(r["ok"], r["messaggio"])
        return None

    def azione(self, voce, elemento, az, dati):
        from .. import solidid
        from ..sistema import avvia

        if voce == "accedi":
            r = solidid.accedi(dati.get("email", ""), dati.get("password", ""))
        elif voce == "crea":
            r = solidid.crea(dati.get("nome", ""), dati.get("email", ""), dati.get("password", ""))
        elif voce == "conferma":
            r = solidid.reinvia_conferma(dati.get("email", ""))
        elif voce == "dimenticata":
            r = solidid.password_dimenticata(dati.get("email", ""))
        elif voce == "esci":
            r = solidid.esci()
        elif voce == "dove":
            avvia([branding.comando("dove")])
            return esito(True, "", ricarica=False)
        elif voce == "dispositivi" and az == "rimuovi":
            try:
                r = solidid.rimuovi_dispositivo(elemento)
            except solidid.ErroreSolidID as e:
                r = {"ok": False, "messaggio": str(e)}
        else:
            return None
        return esito(r["ok"], r["messaggio"])
