"""Servizio degli avvisi della sessione: fa suonare sveglie e timer (anche ad app chiusa) e,
quando ci sono, ricorda appuntamenti del Calendario e Promemoria in scadenza.

Si avvia all'accesso («python3 -m nucleo.avvisi»). Ogni avviso è una notifica con i pulsanti
(«Ferma», «Posticipa 9 min»); sveglia e timer suonano finché non si risponde (massimo 5 minuti).
"""

from __future__ import annotations

import subprocess
import sys
import threading
import time
from datetime import datetime

from . import branding, orologio, suoni
from .i18n import T
from .sistema import stato_utente

POSTICIPO = 9 * 60


def _notifica(titolo: str, testo: str, azioni: list[tuple[str, str]], suona: bool) -> str:
    """Mostra la notifica (e suona); risponde con l'azione scelta ("" se chiusa o scaduta)."""
    lettore = suoni.suona(volte=60) if suona else None
    comando = ["notify-send", f"--app-name={branding.nome()}", "--icon=alarm-symbolic", "--urgency=critical", "--wait",
               "--expire-time=300000"]
    for chiave, etichetta in azioni:
        comando.append(f"--action={chiave}={etichetta}")
    comando += [titolo, testo]
    try:
        r = subprocess.run(comando, capture_output=True, text=True, timeout=310)
        scelta = r.stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        scelta = ""
    if lettore:
        try:
            import os
            import signal

            os.killpg(lettore.pid, signal.SIGTERM)
        except (OSError, ProcessLookupError):
            pass
    return scelta


def _in_sottofondo(funzione, *argomenti) -> None:
    threading.Thread(target=funzione, args=argomenti, daemon=True).start()


def _sveglia(s: dict) -> None:
    scelta = _notifica(s.get("etichetta") or T("Sveglia"), s["ora"],
                       [("posticipa", T("Posticipa 9 min")), ("ferma", T("Ferma"))], True)
    if scelta == "posticipa":
        _rimandati.append({"quando": time.time() + POSTICIPO, "sveglia": s})


def _fine_timer(t: dict) -> None:
    _notifica(T("Timer"), t.get("etichetta") or T("Il tempo è finito"), [("ferma", T("Ferma"))], True)


_rimandati: list[dict] = []
_promemoria = []   # funzioni aggiunte da Calendario e Promemoria: ognuna restituisce [(titolo, testo)] da avvisare


def ciclo() -> None:
    ultimo_minuto = ""
    stato = stato_utente("avvisi-visti.txt")
    while True:
        adesso = datetime.now()
        minuto = adesso.strftime("%Y-%m-%d %H:%M")
        if minuto != ultimo_minuto:
            ultimo_minuto = minuto
            for s in orologio.sveglie():
                if not s.get("attiva") or s["ora"] != adesso.strftime("%H:%M"):
                    continue
                if s.get("giorni") and adesso.weekday() not in s["giorni"]:
                    continue
                if not s.get("giorni"):            # «una volta»: dopo aver suonato si spegne
                    orologio.attiva_sveglia(s["id"], False)
                _in_sottofondo(_sveglia, s)
            # appuntamenti e promemoria (se le app ci sono)
            try:
                visti = set(stato.read_text().split("\n")) if stato.exists() else set()
            except OSError:
                visti = set()
            for fonte in _promemoria:
                try:
                    for chiave, titolo, testo in fonte(adesso):
                        if chiave in visti:
                            continue
                        visti.add(chiave)
                        _in_sottofondo(_notifica, titolo, testo, [("ok", T("OK"))], False)
                except Exception as e:  # noqa: BLE001
                    print(f"avvisi: {e}", file=sys.stderr)
            try:
                stato.write_text("\n".join(sorted(visti)[-2000:]))
            except OSError:
                pass
        for r in list(_rimandati):
            if time.time() >= r["quando"]:
                _rimandati.remove(r)
                _in_sottofondo(_sveglia, r["sveglia"])
        t = orologio.timer()
        if t.get("attivo") and not t.get("inPausa") and t["resto"] <= 0:
            d = dict(t)
            orologio.ferma_timer()
            _in_sottofondo(_fine_timer, d)
        time.sleep(1)


def main() -> int:
    try:
        from . import agenda   # Calendario e Promemoria

        _promemoria.append(agenda.avvisi_dovuti)
    except ImportError:
        pass
    ciclo()
    return 0


if __name__ == "__main__":
    sys.exit(main())
