"""Scrive gli SVG degli sfondi predefiniti in branding/grafica/sfondi/: ogni sfondo ha la versione
scura («nome») e quella chiara («nome-chiaro»), scelta da sola in base al tema.
Uso: python3 scripts/genera-sfondi.py branding/grafica/sfondi"""
import pathlib
import sys

DEST = pathlib.Path(sys.argv[1])
DEST.mkdir(parents=True, exist_ok=True)

# nome: (cielo alto, cielo medio, cielo basso, luce, collina1 alto, collina1 basso, collina2 alto, collina2 basso, collina3 alto, collina3 basso)
PALETTE = {
    "notte":   ("#0B0E18", "#16203D", "#0A0C14", "#5B7CFF", "#3A4D93", "#141B36", "#26346A", "#0E1328", "#18213F", "#080A12"),
    "alba":    ("#1B1030", "#6B2F5E", "#F08A5D", "#FFB86B", "#B84A62", "#4A1E44", "#7A2E55", "#2C1230", "#3D1838", "#120814"),
    "oceano":  ("#03141C", "#0B3A4A", "#06222C", "#3FD0D4", "#1F6F86", "#0A3140", "#155669", "#082630", "#0C3644", "#03141A"),
    "aurora":  ("#060F14", "#0F2E2A", "#081614", "#4DE3A1", "#2E8C6E", "#0E3A33", "#1F6B5A", "#0A2A26", "#123F38", "#05120F"),
    "grafite": ("#111214", "#24262B", "#0D0E10", "#8A8F9C", "#3A3D45", "#1A1B1F", "#2C2E34", "#141518", "#1F2024", "#0A0A0C"),
    # versioni chiare (tema chiaro): stesso disegno, colori pastello
    "notte-chiaro":   ("#C9D7F2", "#E7EDF8", "#D3DDEF", "#FFFFFF", "#9FB4E0", "#C8D4EE", "#86A0D6", "#B9C8E8", "#6F8ACB", "#A9BBE2"),
    "alba-chiaro":    ("#FBE1D3", "#FDF0E8", "#F8D6C3", "#FFFFFF", "#F2A98B", "#F8C9B4", "#E8907A", "#F3B7A1", "#D9775F", "#EDA58E"),
    "oceano-chiaro":  ("#CDEDF1", "#E9F7F9", "#D1ECEF", "#FFFFFF", "#7CC9D3", "#B5E2E7", "#5BB4C1", "#A0D7DE", "#3F9DAE", "#8CCBD4"),
    "aurora-chiaro":  ("#D1F1E2", "#EBF9F2", "#D4EFE3", "#FFFFFF", "#86D3B1", "#BCE8D4", "#63C29B", "#A6DEC5", "#45AD86", "#93D3B7"),
    "grafite-chiaro": ("#E4E5E8", "#F3F4F5", "#E0E1E4", "#FFFFFF", "#B9BCC4", "#D7D9DE", "#A2A6B0", "#C8CBD2", "#8B909C", "#B8BCC5"),
}

for nome, c in PALETTE.items():
    svg = f'''<?xml version="1.0" encoding="UTF-8"?>
<!-- Sfondo «{nome.replace("-chiaro", " (chiaro)").capitalize()}» di @OS_NAME@ (generato: colline stratificate). Reso a 1920x1080. -->
<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1280 720" preserveAspectRatio="xMidYMid slice">
  <defs>
    <linearGradient id="cielo" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{c[0]}"/><stop offset="0.55" stop-color="{c[1]}"/><stop offset="1" stop-color="{c[2]}"/></linearGradient>
    <radialGradient id="luce" cx="0.68" cy="0.42" r="0.5"><stop offset="0" stop-color="{c[3]}" stop-opacity="0.55"/><stop offset="1" stop-color="{c[3]}" stop-opacity="0"/></radialGradient>
    <linearGradient id="d1" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{c[4]}"/><stop offset="1" stop-color="{c[5]}"/></linearGradient>
    <linearGradient id="d2" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{c[6]}"/><stop offset="1" stop-color="{c[7]}"/></linearGradient>
    <linearGradient id="d3" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{c[8]}"/><stop offset="1" stop-color="{c[9]}"/></linearGradient>
  </defs>
  <rect width="1280" height="720" fill="url(#cielo)"/>
  <rect width="1280" height="720" fill="url(#luce)"/>
  <path d="M0 423 C 220 360 380 468 620 405 S 1020 297 1280 369 V720 H0Z" fill="url(#d1)"/>
  <path d="M0 504 C 260 450 470 549 720 504 S 1080 423 1280 477 V720 H0Z" fill="url(#d2)"/>
  <path d="M0 594 C 300 549 520 630 820 585 S 1140 540 1280 576 V720 H0Z" fill="url(#d3)"/>
</svg>
'''
    (DEST / f"{nome}.svg.in").write_text(svg)
print(len(PALETTE))
