#!/usr/bin/env python3
"""Genera l'animazione della schermata di avvio (Plymouth) di SolidOS.

Riproduce branding/avvio/solidos-boot.html:
  1. «SolidOS» compare da sfocato a nitido;
  2. «olidOS» scorre verso sinistra e sparisce: resta la «S», che torna al centro;
  3. sotto compare la barra di caricamento.
Allo spegnimento la sequenza è al contrario.

Plymouth non ha font né filtri: i fotogrammi sono SVG con i contorni delle lettere
(presi dal font con fontTools), poi resi in PNG da rsvg-convert.

Uso: genera-avvio.py FONT.otf NOME CARTELLA_SVG CARTELLA_TEMA ID
Scrive gli SVG dei fotogrammi in CARTELLA_SVG e lo script Plymouth <ID>.script
in CARTELLA_TEMA; stampa l'elenco «svg png larghezza altezza» da rendere.
"""

import sys
from pathlib import Path

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

FONT, NOME, CARTELLA_SVG, CARTELLA_TEMA, ID = sys.argv[1:6]
svg_dir, tema = Path(CARTELLA_SVG), Path(CARTELLA_TEMA)
svg_dir.mkdir(parents=True, exist_ok=True)
tema.mkdir(parents=True, exist_ok=True)

DIMENSIONE = 58.0          # «olidOS» (come nel file HTML)
DIMENSIONE_S = 58.0 * 1.6  # la «S» è più grande
LARGHEZZA, ALTEZZA, BASE = 560, 180, 128
FOTOGRAMMI_COMPARSA = 16
FOTOGRAMMI_CODA = 26

font = TTFont(FONT)
upm = font["head"].unitsPerEm
glyph_set = font.getGlyphSet()
cmap = font.getBestCmap()
hmtx = font["hmtx"]


def tracciato(testo: str, dimensione: float, x0: float) -> tuple[str, float]:
    """Contorni SVG del testo a partire da x0 sulla linea di base; restituisce (path, larghezza)."""
    scala = dimensione / upm
    pezzi, x = [], x0
    for carattere in testo:
        nome = cmap.get(ord(carattere))
        if nome is None:
            continue
        penna = SVGPathPen(glyph_set)
        glyph_set[nome].draw(TransformPen(penna, (scala, 0, 0, -scala, x, BASE)))
        pezzi.append(penna.getCommands())
        x += hmtx[nome][0] * scala
    return " ".join(pezzi), x - x0


S, CODA = NOME[0], NOME[1:]
_, larghezza_s = tracciato(S, DIMENSIONE_S, 0)
_, larghezza_coda = tracciato(CODA, DIMENSIONE, 0)


def ease_in_out(t: float) -> float:
    """Approssima cubic-bezier(.65,0,.35,1) del file HTML."""
    return 4 * t * t * t if t < 0.5 else 1 - (-2 * t + 2) ** 3 / 2


def fotogramma(e: float, sfocatura: float) -> str:
    """e = quanto è scorsa la coda (0 = «SolidOS» intero, 1 = solo «S»)."""
    visibile = larghezza_coda * (1 - e)
    gx = (LARGHEZZA - (larghezza_s + visibile)) / 2
    path_s, _ = tracciato(S, DIMENSIONE_S, gx)
    inizio_coda = gx + larghezza_s
    path_coda, _ = tracciato(CODA, DIMENSIONE, inizio_coda - e * larghezza_coda)
    filtro = (f'<filter id="f" x="-20%" y="-40%" width="140%" height="180%">'
              f'<feGaussianBlur stdDeviation="{sfocatura:.2f}"/></filter>') if sfocatura > 0.05 else ""
    gruppo = ' filter="url(#f)"' if filtro else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{LARGHEZZA}" height="{ALTEZZA}" '
            f'viewBox="0 0 {LARGHEZZA} {ALTEZZA}"><defs>{filtro}'
            f'<clipPath id="c"><rect x="{inizio_coda:.2f}" y="0" width="{max(visibile, 0):.2f}" height="{ALTEZZA}"/></clipPath></defs>'
            f'<g fill="#FFFFFF"{gruppo}><path d="{path_s}"/>'
            f'<g clip-path="url(#c)" opacity="{1 - e:.3f}"><path d="{path_coda}"/></g></g></svg>\n')


elenco = []
for i in range(FOTOGRAMMI_COMPARSA):
    t = i / (FOTOGRAMMI_COMPARSA - 1)
    nome = f"comparsa-{i:02d}"
    (svg_dir / f"{nome}.svg").write_text(fotogramma(0.0, 10 * (1 - t) ** 1.5))
    elenco.append(nome)
for i in range(FOTOGRAMMI_CODA):
    e = ease_in_out(i / (FOTOGRAMMI_CODA - 1))
    nome = f"coda-{i:02d}"
    (svg_dir / f"{nome}.svg").write_text(fotogramma(e, 0.0))
    elenco.append(nome)

for nome in elenco:
    print(f"{svg_dir / (nome + '.svg')} {tema / (nome + '.png')} {LARGHEZZA} {ALTEZZA}")

# ── Script Plymouth ────────────────────────────────────────────────────────
righe_comparsa = "\n".join(f'comparsa[{i}] = Image("comparsa-{i:02d}.png");' for i in range(FOTOGRAMMI_COMPARSA))
righe_coda = "\n".join(f'coda[{i}] = Image("coda-{i:02d}.png");' for i in range(FOTOGRAMMI_CODA))
script = f"""# Schermata di avvio di {NOME} (generata da scripts/genera-avvio.py: non modificare a mano).
# Avvio: «{NOME}» compare da sfocato, «{CODA}» scorre via e resta la «{S}», poi la barra.
# Spegnimento e riavvio: la stessa sequenza al contrario.

Window.SetBackgroundTopColor(0, 0, 0);
Window.SetBackgroundBottomColor(0, 0, 0);

{righe_comparsa}
{righe_coda}
NC = {FOTOGRAMMI_COMPARSA};
ND = {FOTOGRAMMI_CODA};

cx = Window.GetX() + Window.GetWidth() / 2;
cy = Window.GetY() + Window.GetHeight() / 2;

logo = Sprite(comparsa[0]);
logo.SetX(cx - comparsa[0].GetWidth() / 2);
logo.SetY(cy - comparsa[0].GetHeight() / 2 - 30);
logo.SetZ(10);
logo.SetOpacity(0);

vuota.image = Image("barra-vuota.png");
vuota.sprite = Sprite(vuota.image);
vuota.sprite.SetX(cx - vuota.image.GetWidth() / 2);
vuota.sprite.SetY(cy + 60);
vuota.sprite.SetZ(10);
vuota.sprite.SetOpacity(0);

piena.originale = Image("barra-piena.png");
piena.sprite = Sprite();
piena.sprite.SetX(vuota.sprite.GetX());
piena.sprite.SetY(vuota.sprite.GetY());
piena.sprite.SetZ(11);
piena.sprite.SetOpacity(0);

spegnimento = (Plymouth.GetMode() == "shutdown" || Plymouth.GetMode() == "reboot");
tempo = 0;
progresso = 0;
mostrato = 0;

fun riempi(frazione) {{
	larghezza = Math.Int(piena.originale.GetWidth() * frazione);
	if (larghezza < 4) larghezza = 4;
	piena.sprite.SetImage(piena.originale.Scale(larghezza, piena.originale.GetHeight()));
}}

fun limita(x) {{
	if (x < 0) return 0;
	if (x > 1) return 1;
	return x;
}}

fun avvio() {{
	# ~50 aggiornamenti al secondo
	tempo++;
	if (tempo <= 50) {{
		t = tempo / 50;
		logo.SetImage(comparsa[Math.Int(t * (NC - 1))]);
		logo.SetOpacity(t);
	}} else if (tempo >= 80 && tempo <= 130) {{
		logo.SetImage(coda[Math.Int(limita((tempo - 80) / 50) * (ND - 1))]);
	}}
	if (tempo >= 140) {{
		o = limita((tempo - 140) / 25);
		vuota.sprite.SetOpacity(o);
		piena.sprite.SetOpacity(o);
		# la barra avanza con l'avvio reale, ma non resta mai ferma
		finto = limita((tempo - 155) / 400) * 0.9;
		obiettivo = progresso;
		if (finto > obiettivo) obiettivo = finto;
		if (obiettivo > mostrato) mostrato = mostrato + (obiettivo - mostrato) * 0.15;
		riempi(mostrato);
	}}
}}

fun chiusura() {{
	tempo++;
	if (tempo == 1) {{
		logo.SetImage(coda[ND - 1]);
		logo.SetOpacity(1);
		riempi(1);
	}}
	if (tempo <= 20) {{
		o = 1 - tempo / 20;
		vuota.sprite.SetOpacity(o);
		piena.sprite.SetOpacity(o);
	}} else if (tempo >= 25 && tempo <= 75) {{
		logo.SetImage(coda[Math.Int((1 - limita((tempo - 25) / 50)) * (ND - 1))]);
	}} else if (tempo >= 95 && tempo <= 145) {{
		t = 1 - limita((tempo - 95) / 50);
		logo.SetImage(comparsa[Math.Int(t * (NC - 1))]);
		logo.SetOpacity(t);
	}}
}}

fun avanzamento(durata, frazione) {{
	progresso = frazione;
}}

if (spegnimento) {{
	Plymouth.SetRefreshFunction(chiusura);
}} else {{
	Plymouth.SetRefreshFunction(avvio);
	Plymouth.SetBootProgressFunction(avanzamento);
}}
"""
(tema / f"{ID}.script").write_text(script)
