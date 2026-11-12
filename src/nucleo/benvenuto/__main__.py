"""Benvenuto: configurazione guidata al primo avvio.

Passi: lingua, Wi-Fi, account, aspetto, importazione da Windows, prestazioni,
Condivisione Vicina. Nella sessione live c'è anche il pulsante «Installa».
"""

import json
import os
import pwd
import sys
from pathlib import Path

from .. import branding
from ..dbusutil import chiama, inizializza
from ..hw import rete
from ..impostazioni.pannelli_aspetto import PannelloAspetto
from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app
from ..sistema import avvia, config_utente, esegui, helper, leggi_json, ram_totale_mb, scrivi_json, uscita


class BackendBenvenuto(Backend):
    def info(self) -> dict:
        u = pwd.getpwuid(os.getuid())
        return {"live": "--live" in sys.argv, "utente": u.pw_name, "nome": (u.pw_gecos.split(",")[0] or u.pw_name),
                "ram": ram_totale_mb(), "leggero": Path(f"/etc/{branding.id_os()}/profilo-leggero").exists(),
                "lingua": os.environ.get("LANG", "it_IT.UTF-8")}

    def lingue(self) -> list:
        from ..impostazioni.pannelli_sistema import LINGUE

        return [{"valore": v, "testo": t} for v, t in LINGUE]

    def impostaLingua(self, locale: str) -> bool:
        return esegui(["localectl", "set-locale", f"LANG={locale}"], timeout=60).returncode == 0

    def reti(self) -> list:
        return rete.reti_wifi(scansiona=True) if rete.wifi_attivo() else []

    def connetti(self, ssid: str, password: str) -> dict:
        return rete.connetti_wifi(ssid, password)

    def connesso(self) -> bool:
        return rete.stato_breve()["connesso"]

    def tema(self, tema: str, accento: str) -> None:
        p = PannelloAspetto()
        p.imposta("tema", tema)
        if accento:
            p.imposta("accento", accento)

    def stileBarra(self, stile: str) -> None:
        from ..impostazioni.pannelli_aspetto import PannelloPannello

        PannelloPannello().imposta("barra", stile)

    def migrazione(self) -> None:
        avvia([branding.comando("migrazione")])

    def profiloLeggero(self, attivo: bool) -> dict:
        r = helper("profilo-leggero", "si" if attivo else "no")
        return {"ok": r.returncode == 0}

    def condivisione(self, visibilita: str, nome: str) -> dict:
        file = config_utente("condivisione.json")
        conf = leggi_json(file, {})
        conf["visibilita"] = visibilita
        if nome:
            conf["nome"] = nome
        scrivi_json(file, conf)
        nome_dbus = branding.nome_dbus("Condivisione1")
        chiama(nome_dbus, branding.percorso_dbus("Condivisione1"), nome_dbus, "RicaricaConfigurazione")
        chiama(nome_dbus, branding.percorso_dbus("Condivisione1"), nome_dbus, "ImpostaVisibilita", visibilita)
        stato = chiama(nome_dbus, branding.percorso_dbus("Condivisione1"), nome_dbus, "StatoBackend")
        try:
            return json.loads(str(stato)) if stato else {}
        except ValueError:
            return {}

    def installa(self) -> None:
        avvia(["sh", "-c", "sudo -E calamares >/tmp/calamares.log 2>&1"])

    def utenti(self) -> None:
        avvia([branding.comando("impostazioni"), "utenti"])

    # ── Account: nome, foto e password (si vedono all'accesso e nella schermata di blocco)
    def account(self) -> dict:
        from .. import account

        return account.info()

    def _account(self, esito: dict) -> dict:
        return {**esito, "account": self.account()}

    def accountNome(self, nome: str) -> dict:
        from .. import account

        return self._account(account.imposta_nome(nome))

    def accountPassword(self, password: str, conferma: str) -> dict:
        from .. import account

        return self._account(account.imposta_password(password, conferma))

    def accountSenzaPassword(self) -> dict:
        from .. import account

        return self._account(account.togli_password())

    def accountFoto(self, percorso: str) -> dict:
        from .. import account

        return self._account(account.imposta_foto(percorso))

    def accountTogliFoto(self) -> dict:
        from .. import account

        return self._account(account.togli_foto())

    def solidID(self) -> None:
        avvia([branding.comando("dove")])

    def fine(self) -> None:
        config_utente("benvenuto-fatto").write_text("1")


def main() -> int:
    inizializza()
    return esegui_app("benvenuto", "Benvenuto/Main.qml", lambda app: {"ponte": crea_ponte(BackendBenvenuto())})


if __name__ == "__main__":
    sys.exit(main())
