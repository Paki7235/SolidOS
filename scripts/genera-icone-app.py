#!/usr/bin/env python3
"""Icone delle app di SolidOS disegnate da noi (nel tema di icone di SolidOS, che per il resto
usa Colloid): stesso linguaggio delle icone vicine nel Dock — quadrato arrotondato a colori pieni,
un filo più scuro sotto (rilievo), simbolo bianco semplice con qualche dettaglio colorato.

Uso: scripts/genera-icone-app.py      (scrive in live-build/.../icons/@OS_ID@/scalable/apps)
"""

import os

RADICE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(RADICE, "live-build", "config", "includes.chroot", "usr", "share", "icons", "@OS_ID@", "scalable", "apps")


def tessera(nome: str, alto: str, basso: str, simbolo: str) -> str:
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
 <defs>
  <linearGradient id="f-{nome}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{alto}"/><stop offset="1" stop-color="{basso}"/></linearGradient>
  <linearGradient id="l-{nome}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.22"/><stop offset="0.45" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient>
 </defs>
 <rect x="4" y="5.2" width="56" height="56" rx="12.5" fill="#000000" opacity="0.18"/>
 <rect x="4" y="4" width="56" height="56" rx="12.5" fill="url(#f-{nome})"/>
 <rect x="4" y="4" width="56" height="56" rx="12.5" fill="url(#l-{nome})"/>
 {simbolo}
</svg>
'''


ICONE = {
    # Videochiamate: videocamera bianca, obiettivo verde, puntino rosso «in diretta»
    "videochiamate": ("#43E39A", "#16A56A", '''
 <g transform="translate(0 0.8)" opacity="0.16"><rect x="12" y="20" width="29" height="24" rx="7" fill="#000"/><path d="M43 29.3 51.2 23.9c1.3-.9 2.8 0 2.8 1.6v13c0 1.6-1.5 2.5-2.8 1.6L43 34.7Z" fill="#000"/></g>
 <rect x="12" y="20" width="29" height="24" rx="7" fill="#FFFFFF"/>
 <path d="M43 29.3 51.2 23.9c1.3-.9 2.8 0 2.8 1.6v13c0 1.6-1.5 2.5-2.8 1.6L43 34.7Z" fill="#FFFFFF"/>
 <circle cx="26.5" cy="32" r="6.2" fill="#1FB476"/>
 <circle cx="26.5" cy="32" r="2.6" fill="#0E7A4E"/>
 <circle cx="17.6" cy="25.4" r="2" fill="#FF5A5F"/>'''),
    # Dov'è: radar con anelli e la puntina al centro
    "dove": ("#6E8BFF", "#3B4FE0", '''
 <circle cx="32" cy="33" r="21" fill="none" stroke="#FFFFFF" stroke-opacity="0.22" stroke-width="2"/>
 <circle cx="32" cy="33" r="14" fill="none" stroke="#FFFFFF" stroke-opacity="0.38" stroke-width="2"/>
 <path d="M32 33 L48.5 20.5 A21 21 0 0 1 53 33 Z" fill="#FFFFFF" fill-opacity="0.22"/>
 <g transform="translate(0 0.8)" opacity="0.18"><path d="M32 17c-6.1 0-11 4.8-11 10.8 0 8 11 18.7 11 18.7s11-10.7 11-18.7C43 21.8 38.1 17 32 17Z" fill="#000"/></g>
 <path d="M32 17c-6.1 0-11 4.8-11 10.8 0 8 11 18.7 11 18.7s11-10.7 11-18.7C43 21.8 38.1 17 32 17Z" fill="#FFFFFF"/>
 <circle cx="32" cy="27.8" r="4.6" fill="#4A62F0"/>
 <circle cx="48.5" cy="20.5" r="2.4" fill="#7CF5C4"/>'''),
    # Desktop remoto: due schermi, quello davanti collegato a quello dietro
    "desktop-remoto": ("#4A5163", "#232733", '''
 <rect x="26" y="14" width="27" height="19" rx="3.5" fill="#FFFFFF" fill-opacity="0.35"/>
 <g transform="translate(0 0.8)" opacity="0.2"><rect x="11" y="23" width="33" height="23" rx="4" fill="#000"/></g>
 <rect x="11" y="23" width="33" height="23" rx="4" fill="#FFFFFF"/>
 <rect x="14" y="26" width="27" height="17" rx="2.2" fill="#4F8BFF"/>
 <path d="M23 51h9M27.5 46v5" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round"/>
 <path d="M21.5 35.5h11m-3.5-3.8 3.8 3.8-3.8 3.8" fill="none" stroke="#FFFFFF" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>'''),
    # Password: chiave bianca su viola, con la testa forata
    "password": ("#9D7BFF", "#5B33E6", '''
 <g transform="translate(0 0.8)" opacity="0.18"><circle cx="23" cy="25" r="10.5" fill="#000"/><path d="M29.5 31.5 47 49" stroke="#000" stroke-width="6" stroke-linecap="round"/></g>
 <path d="M29.5 31.5 47 49M40 42l4.5-4.5M44 46l3.5-3.5" fill="none" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round"/>
 <circle cx="23" cy="25" r="10.5" fill="#FFFFFF"/>
 <circle cx="20.5" cy="22.5" r="3.4" fill="#6B45EE"/>'''),
}


def main() -> None:
    os.makedirs(DEST, exist_ok=True)
    for nome, (alto, basso, simbolo) in ICONE.items():
        with open(os.path.join(DEST, f"@OS_ID@-{nome}.svg"), "w") as f:
            f.write(tessera(nome, alto, basso, simbolo))
    print(f"{len(ICONE)} icone in {DEST}")


if __name__ == "__main__":
    main()
