"""Schermata di blocco in stile Mac: in alto data e ora grandi, in basso la foto,
il nome dell'utente e — solo se l'account ha una password — il campo per scriverla.
Senza password basta premere Invio o «Entra».

Il blocco vero lo fa gtklock (protocollo ext-session-lock di Wayland: se qualcosa
si chiude per errore lo schermo resta bloccato). Qui si preparano solo disposizione
e stile in ~/.cache/<os>/blocco/ e poi si avvia gtklock.

Uso: python3 -m nucleo.blocco [--prepara]   (--prepara: crea i file e non blocca)
"""

from __future__ import annotations

import html
import os
import pwd
import shutil
import subprocess
import sys
from pathlib import Path

from .. import branding
from ..i18n import T

CARTELLA_SENZA_PASSWORD = Path("/var/lib/nucleo/senza-password")


def senza_password(utente: str) -> bool:
    """L'account si apre senza password? (scelta fatta nella configurazione o in Impostazioni)."""
    if (CARTELLA_SENZA_PASSWORD / utente).exists():
        return True
    try:
        r = subprocess.run(["passwd", "-S", utente], capture_output=True, text=True, timeout=3)
        campi = r.stdout.split()
        return r.returncode == 0 and len(campi) > 1 and campi[1] == "NP"
    except (OSError, subprocess.SubprocessError):
        return False


def foto_utente(u: pwd.struct_passwd) -> str:
    for p in (Path(u.pw_dir) / ".face", Path(f"/var/lib/AccountsService/icons/{u.pw_name}")):
        if p.is_file() and p.stat().st_size > 0:
            return str(p)
    return ""


def iniziali(nome: str) -> str:
    parole = [p for p in nome.replace("_", " ").split() if p]
    if not parole:
        return "?"
    return (parole[0][0] + (parole[-1][0] if len(parole) > 1 else "")).upper()


def _css_url(percorso: str) -> str:
    return "file://" + percorso.replace("\\", "\\\\").replace('"', '\\"')


def prepara() -> list[str]:
    """Scrive layout e stile; restituisce il comando gtklock da eseguire."""
    from ..qmlapp import tema_effettivo
    from ..sistema import sfondo_attuale

    u = pwd.getpwuid(os.getuid())
    nome = (u.pw_gecos.split(",")[0] or u.pw_name).strip()
    serve_password = not senza_password(u.pw_name)
    foto = foto_utente(u)
    tema = tema_effettivo()
    accento = tema.get("accento", "#3B82F6")
    sfondo = sfondo_attuale()

    base = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / branding.id_os() / "blocco"
    base.mkdir(parents=True, exist_ok=True)
    layout, stile = base / "layout.ui", base / "stile.css"
    layout.write_text(_layout(nome, foto, serve_password), encoding="utf-8")
    stile.write_text(_stile(sfondo, foto, accento, serve_password), encoding="utf-8")
    return ["gtklock", "--daemonize", "--layout", str(layout), "--style", str(stile),
            "--time-format", "%H:%M", "--date-format", "%A %-d %B", "--follow-focus"]


def _layout(nome: str, foto: str, serve_password: bool) -> str:
    e = html.escape
    testo_avatar = "" if foto else e(iniziali(nome))
    suggerimento = "" if serve_password else e(T("Premi Invio per entrare"))
    segnaposto = e(T("Inserisci la password"))
    pulsante = "→" if serve_password else e(T("Entra"))
    larghezza = 210 if serve_password else 1
    # Gli id richiesti da gtklock (window-box, clock-label, input-field, unlock-button…)
    # ci sono tutti: cambia solo dove stanno e come appaiono.
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<interface>
  <object class="GtkBox" id="window-box">
    <property name="name">window-box</property>
    <property name="orientation">vertical</property>
    <property name="hexpand">1</property>
    <property name="vexpand">1</property>
    <child>
      <object class="GtkBox" id="info-box">
        <property name="name">info-box</property>
        <property name="halign">center</property>
        <property name="margin-top">64</property>
        <property name="orientation">vertical</property>
        <child>
          <object class="GtkBox" id="time-box">
            <property name="name">time-box</property>
            <property name="orientation">vertical</property>
            <property name="halign">center</property>
            <child>
              <object class="GtkLabel" id="date-label">
                <property name="name">date-label</property>
                <property name="halign">center</property>
              </object>
            </child>
            <child>
              <object class="GtkLabel" id="clock-label">
                <property name="name">clock-label</property>
                <property name="halign">center</property>
              </object>
            </child>
          </object>
        </child>
      </object>
    </child>
    <child>
      <object class="GtkBox">
        <property name="vexpand">1</property>
      </object>
    </child>
    <child>
      <object class="GtkRevealer" id="body-revealer">
        <property name="transition-type">crossfade</property>
        <property name="transition-duration">250</property>
        <property name="reveal-child">0</property>
        <property name="halign">center</property>
        <property name="margin-bottom">72</property>
        <child>
          <object class="GtkGrid" id="body-grid">
            <property name="row-spacing">10</property>
            <property name="halign">center</property>
            <child>
              <object class="GtkLabel" id="avatar">
                <property name="name">avatar</property>
                <property name="label">{testo_avatar}</property>
                <property name="halign">center</property>
              </object>
              <packing><property name="left-attach">0</property><property name="top-attach">0</property></packing>
            </child>
            <child>
              <object class="GtkLabel" id="nome-label">
                <property name="name">nome-label</property>
                <property name="label">{e(nome)}</property>
                <property name="halign">center</property>
              </object>
              <packing><property name="left-attach">0</property><property name="top-attach">1</property></packing>
            </child>
            <child>
              <object class="GtkBox" id="campo">
                <property name="name">campo</property>
                <property name="halign">center</property>
                <property name="spacing">4</property>
                <child>
                  <object class="GtkLabel" id="input-label">
                    <property name="name">input-label</property>
                    <property name="no-show-all">1</property>
                    <property name="visible">0</property>
                  </object>
                </child>
                <child>
                  <object class="GtkEntry" id="input-field">
                    <property name="name">input-field</property>
                    <property name="width-request">{larghezza}</property>
                    <property name="visibility">0</property>
                    <property name="caps-lock-warning">0</property>
                    <property name="input-purpose">password</property>
                    <property name="placeholder-text">{segnaposto}</property>
                    <signal name="activate" handler="window_pw_check"/>
                  </object>
                </child>
                <child>
                  <object class="GtkButton" id="unlock-button">
                    <property name="name">unlock-button</property>
                    <property name="label">{pulsante}</property>
                    <property name="relief">none</property>
                    <signal name="clicked" handler="window_pw_check"/>
                  </object>
                </child>
              </object>
              <packing><property name="left-attach">0</property><property name="top-attach">2</property></packing>
            </child>
            <child>
              <object class="GtkBox">
                <property name="halign">center</property>
                <property name="orientation">vertical</property>
                <child>
                  <object class="GtkLabel" id="error-label">
                    <property name="name">error-label</property>
                  </object>
                </child>
                <child>
                  <object class="GtkLabel" id="warning-label">
                    <property name="name">warning-label</property>
                  </object>
                </child>
                <child>
                  <object class="GtkLabel" id="suggerimento">
                    <property name="name">suggerimento</property>
                    <property name="label">{suggerimento}</property>
                  </object>
                </child>
              </object>
              <packing><property name="left-attach">0</property><property name="top-attach">3</property></packing>
            </child>
            <child>
              <object class="GtkRevealer" id="message-revealer">
                <property name="transition-type">none</property>
                <property name="no-show-all">1</property>
                <child>
                  <object class="GtkScrolledWindow" id="message-scrolled-window">
                    <property name="hscrollbar-policy">never</property>
                    <property name="max-content-height">160</property>
                    <property name="propagate-natural-height">1</property>
                    <child>
                      <object class="GtkViewport">
                        <child>
                          <object class="GtkBox" id="message-box">
                            <property name="orientation">vertical</property>
                            <property name="homogeneous">1</property>
                          </object>
                        </child>
                      </object>
                    </child>
                  </object>
                </child>
              </object>
              <packing><property name="left-attach">0</property><property name="top-attach">4</property></packing>
            </child>
          </object>
        </child>
      </object>
    </child>
  </object>
</interface>
"""


def _stile(sfondo: str, foto: str, accento: str, serve_password: bool) -> str:
    font = branding.get("FONT_UI", "Inter") or "Inter"
    sfondo_css = f'url("{_css_url(sfondo)}")' if sfondo and Path(sfondo).exists() else "none"
    if foto:
        avatar = f'background-image: url("{_css_url(foto)}"); background-size: cover; background-position: center;'
    else:   # come sul Mac: cerchio grigio con le iniziali
        avatar = "background-image: linear-gradient(to bottom, #A3A8B4, #7C818D);"
    campo_nascosto = "" if serve_password else """
#input-field { opacity: 0; min-width: 0; padding: 0; margin: 0; }
#campo { background-color: transparent; padding: 0; }
#unlock-button { min-width: 96px; padding: 4px 18px; font-size: 14px; font-weight: 600;
  background-color: rgba(255,255,255,0.24); }
"""
    return f"""/* Schermata di blocco di {branding.nome()} (generata: non modificare) */
* {{ font-family: "{font}", sans-serif; }}
window {{
  background-color: #000000;
  background-image: linear-gradient(to bottom, rgba(0,0,0,0.28), rgba(0,0,0,0) 38%, rgba(0,0,0,0) 62%, rgba(0,0,0,0.38)), {sfondo_css};
  background-size: cover, cover;
  background-position: center, center;
  background-repeat: no-repeat, no-repeat;
}}
#window-box {{ background: none; }}
#date-label {{ color: rgba(255,255,255,0.92); font-size: 22px; font-weight: 600;
  text-shadow: 0 1px 6px rgba(0,0,0,0.35); }}
#clock-label {{ color: rgba(255,255,255,0.90); font-size: 116px; font-weight: 700;
  text-shadow: 0 2px 14px rgba(0,0,0,0.30); }}
#avatar {{
  min-width: 92px; min-height: 92px; border-radius: 9999px;
  {avatar}
  color: #FFFFFF; font-size: 36px; font-weight: 600;
  box-shadow: 0 4px 18px rgba(0,0,0,0.35);
}}
#nome-label {{ color: #FFFFFF; font-size: 17px; font-weight: 600; text-shadow: 0 1px 4px rgba(0,0,0,0.45); }}
#campo {{
  background-color: rgba(255,255,255,0.22);
  border-radius: 9999px;
  padding: 2px 3px 2px 14px;
  box-shadow: 0 2px 10px rgba(0,0,0,0.18);
}}
#input-field, #input-field:focus {{
  background: none; border: none; box-shadow: none; outline: none;
  color: #FFFFFF; caret-color: #FFFFFF; font-size: 14px; min-height: 30px; padding: 0;
}}
#input-field image {{ color: rgba(255,255,255,0.8); }}
#unlock-button {{
  min-width: 28px; min-height: 28px; padding: 0; border-radius: 9999px; border: none;
  background-image: none; background-color: rgba(255,255,255,0.30);
  color: #FFFFFF; font-size: 16px; font-weight: 700; box-shadow: none; text-shadow: none;
}}
#unlock-button:hover {{ background-color: {accento}; }}
#unlock-button:disabled {{ opacity: 0.5; }}
#error-label {{ color: #FFD5D5; font-weight: 600; text-shadow: 0 1px 4px rgba(0,0,0,0.5); }}
#warning-label, #suggerimento {{ color: rgba(255,255,255,0.82); font-size: 12px; text-shadow: 0 1px 4px rgba(0,0,0,0.5); }}
infobar, infobar > revealer > box {{ background-color: rgba(0,0,0,0.35); color: #FFFFFF; border-radius: 10px; border: none; }}
{campo_nascosto}"""


def main() -> int:
    solo_prepara = "--prepara" in sys.argv
    try:
        comando = prepara()
    except Exception as errore:  # noqa: BLE001 — un errore qui non deve lasciare lo schermo sbloccato
        print(f"blocco: preparazione non riuscita ({errore}), uso l'aspetto predefinito", file=sys.stderr)
        comando = ["gtklock", "--daemonize"]
    if solo_prepara:
        print(" ".join(comando))
        return 0
    if shutil.which("gtklock"):
        os.execvp(comando[0], comando)
    return 1


if __name__ == "__main__":
    sys.exit(main())
