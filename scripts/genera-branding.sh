#!/usr/bin/env bash
# Genera l'albero di lavoro di live-build con il branding applicato.
#
#   scripts/genera-branding.sh DESTINAZIONE [--senza-immagini]
#
# - copia live-build/ in DESTINAZIONE;
# - i file *.in vengono elaborati (segnaposto @VAR@) e perdono l'estensione .in;
# - anche i nomi di file e cartelle possono contenere segnaposto (es. @OS_ID@);
# - rende le immagini da branding/grafica/*.svg.in (serve rsvg-convert).
set -euo pipefail

RADICE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/branding.sh
. "$RADICE/scripts/lib/branding.sh"

DEST=${1:?Uso: genera-branding.sh DESTINAZIONE [--senza-immagini]}
SENZA_IMMAGINI=0
[[ ${2:-} == --senza-immagini ]] && SENZA_IMMAGINI=1

carica_branding
echo "Branding: ${OS_NAME} ${OS_VERSION} (id: ${OS_ID}, lingua: ${LINGUA})"

rm -rf "$DEST"
mkdir -p "$DEST"

# ── 1. Albero live-build con modelli ─────────────────────────────────────────
SORG="$RADICE/live-build"
conteggio_modelli=0
while IFS= read -r -d '' file; do
	rel=${file#"$SORG"/}
	rel_dest=$(applica_a_stringa "$rel")
	if [[ $rel_dest == *.in ]]; then
		rel_dest=${rel_dest%.in}
		applica_modello "$file" "$DEST/$rel_dest"
		conteggio_modelli=$((conteggio_modelli + 1))
	else
		mkdir -p "$(dirname "$DEST/$rel_dest")"
		cp -p "$file" "$DEST/$rel_dest"
	fi
	[[ -x $file ]] && chmod +x "$DEST/$rel_dest"
done < <(find "$SORG" -type f ! -name '.DS_Store' -print0)
echo "  modelli elaborati: $conteggio_modelli"

# ── 2. Grafica ───────────────────────────────────────────────────────────────
GRAFICA_TMP="$DEST/.grafica"
mkdir -p "$GRAFICA_TMP"
for svg in "$RADICE"/branding/grafica/*.svg.in; do
	base=$(basename "$svg" .svg.in)
	applica_modello "$svg" "$GRAFICA_TMP/$base.svg"
done

CHROOT="$DEST/config/includes.chroot"
BINARY="$DEST/config/includes.binary"

installa_svg() { mkdir -p "$(dirname "$2")"; cp "$1" "$2"; }

rendi_png() { # sorgente.svg larghezza altezza destinazione.png
	mkdir -p "$(dirname "$4")"
	rsvg-convert --width "$2" --height "$3" --keep-aspect-ratio --output "$4" "$1"
}

installa_svg "$GRAFICA_TMP/logo.svg" "$CHROOT/usr/share/$OS_ID/logo.svg"
installa_svg "$GRAFICA_TMP/logo.svg" "$CHROOT/usr/share/icons/hicolor/scalable/apps/$OS_ID-logo.svg"
installa_svg "$GRAFICA_TMP/logo-chiaro.svg" "$CHROOT/usr/share/$OS_ID/logo-chiaro.svg"
installa_svg "$GRAFICA_TMP/logo-chiaro.svg" "$CHROOT/usr/share/icons/hicolor/scalable/apps/$OS_ID-logo-chiaro.svg"
installa_svg "$GRAFICA_TMP/sfondo.svg" "$CHROOT/usr/share/backgrounds/$OS_ID/predefinito.svg"
installa_svg "$GRAFICA_TMP/logo.svg" "$CHROOT/etc/calamares/branding/$OS_ID/logo.svg"

if ((SENZA_IMMAGINI)); then
	echo "  immagini PNG saltate (--senza-immagini)"
else
	command -v rsvg-convert >/dev/null || _errore_branding "serve rsvg-convert (pacchetto librsvg2-bin)"
	# Schermata di caricamento: «S» bianca su nero e barra di avanzamento
	PLY="$CHROOT/usr/share/plymouth/themes/$OS_ID"
	rendi_png "$GRAFICA_TMP/logo-chiaro.svg" 96 96 "$PLY/logo.png"
	printf '<svg xmlns="http://www.w3.org/2000/svg" width="160" height="5"><rect width="160" height="5" rx="2.5" fill="#333333"/></svg>' >"$GRAFICA_TMP/barra-vuota.svg"
	printf '<svg xmlns="http://www.w3.org/2000/svg" width="160" height="5"><rect width="160" height="5" rx="2.5" fill="#FFFFFF"/></svg>' >"$GRAFICA_TMP/barra-piena.svg"
	rendi_png "$GRAFICA_TMP/barra-vuota.svg" 160 5 "$PLY/barra-vuota.png"
	rendi_png "$GRAFICA_TMP/barra-piena.svg" 160 5 "$PLY/barra-piena.png"
	# Animazione «SolidOS» → «S» (branding/avvio/solidos-boot.html), se c'è il font
	FONT_AVVIO=$(find /usr/share/fonts -iname 'LeagueSpartan-Bold.*' 2>/dev/null | head -n 1)
	if [[ -n $FONT_AVVIO ]] && python3 -c 'import fontTools' 2>/dev/null; then
		while read -r sorgente destinazione larghezza altezza; do
			rendi_png "$sorgente" "$larghezza" "$altezza" "$destinazione"
		done < <(python3 "$RADICE/scripts/genera-avvio.py" "$FONT_AVVIO" "$OS_NAME" "$GRAFICA_TMP/avvio" "$PLY" "$OS_ID")
		echo "  animazione di avvio creata ($(ls "$PLY"/comparsa-*.png "$PLY"/coda-*.png | wc -l) fotogrammi)"
	else
		echo "  animazione di avvio saltata (servono fonts-league-spartan e python3-fonttools)"
	fi
	rendi_png "$GRAFICA_TMP/logo.svg" 48 48 "$CHROOT/usr/share/icons/hicolor/48x48/apps/$OS_ID-logo.png"
	rendi_png "$GRAFICA_TMP/logo-chiaro.svg" 48 48 "$CHROOT/usr/share/icons/hicolor/48x48/apps/$OS_ID-logo-chiaro.png"
	# Tema del menu GRUB: voce scelta in una pillola bianca (immagini a 9 parti)
	TEMA="$BINARY/boot/grub/$OS_ID"
	mkdir -p "$TEMA"
	r=8
	angolo() { # nome trasformazione
		# quarto di cerchio pieno nell'angolo in alto a sinistra, poi specchiato
		printf '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d"><path d="M%d 0 A%d %d 0 0 0 0 %d L%d %d Z" fill="#FFFFFF" transform="%s"/></svg>' \
			$r $r $r $r $r $r $r $r "$2" >"$GRAFICA_TMP/sel_$1.svg"
		rendi_png "$GRAFICA_TMP/sel_$1.svg" $r $r "$TEMA/sel_$1.png"
	}
	angolo nw "" ; angolo ne "translate($r 0) scale(-1 1)"; angolo sw "translate(0 $r) scale(1 -1)"; angolo se "translate($r $r) scale(-1 -1)"
	for parte in n s c; do
		printf '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="%d"><rect width="1" height="%d" fill="#FFFFFF"/></svg>' $r $r >"$GRAFICA_TMP/sel_$parte.svg"
		rendi_png "$GRAFICA_TMP/sel_$parte.svg" 1 $r "$TEMA/sel_$parte.png"
	done
	for parte in e w; do
		printf '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="1"><rect width="%d" height="1" fill="#FFFFFF"/></svg>' $r $r >"$GRAFICA_TMP/sel_$parte.svg"
		rendi_png "$GRAFICA_TMP/sel_$parte.svg" $r 1 "$TEMA/sel_$parte.png"
	done
	rendi_png "$GRAFICA_TMP/sfondo.svg" 1920 1080 "$CHROOT/usr/share/backgrounds/$OS_ID/predefinito.png"
	rendi_png "$GRAFICA_TMP/avvio-grub.svg" 1280 720 "$BINARY/boot/grub/$OS_ID/sfondo.png"
	rendi_png "$GRAFICA_TMP/avvio-grub.svg" 1280 720 "$CHROOT/usr/share/$OS_ID/grub-sfondo.png"
	rendi_png "$GRAFICA_TMP/avvio-bios.svg" 640 480 "$BINARY/isolinux/splash.png"
	echo "  immagini PNG create"
fi
rm -rf "$GRAFICA_TMP"

# ── 3. Componenti del sistema (src/) ─────────────────────────────────────────
SRC="$RADICE/src"
if [[ -d $SRC ]]; then
	mkdir -p "$CHROOT/usr/lib/python3/dist-packages" "$CHROOT/usr/share/nucleo" "$CHROOT/usr/libexec/nucleo" "$CHROOT/usr/bin" "$CHROOT/usr/share/applications"
	rsync_semplice() { # sorgente destinazione (copia escludendo cache Python e file di macOS)
		(cd "$1" && find . -type f ! -name '*.pyc' ! -name '.DS_Store' ! -path '*/__pycache__/*' -print0) |
			while IFS= read -r -d '' f; do
				mkdir -p "$2/$(dirname "$f")"
				cp -p "$1/$f" "$2/$f"
			done
	}
	rsync_semplice "$SRC/nucleo" "$CHROOT/usr/lib/python3/dist-packages/nucleo"
	rsync_semplice "$SRC/qml" "$CHROOT/usr/share/nucleo/qml"
	[[ -d $SRC/dati ]] && rsync_semplice "$SRC/dati" "$CHROOT/usr/share/nucleo"
	# Strumento per esportare le reti Wi-Fi da Windows, nella radice della chiavetta
	if [[ -d $SRC/dati/windows ]]; then
		mkdir -p "$BINARY/windows"
		cp -p "$SRC"/dati/windows/* "$BINARY/windows/"
	fi
	for f in "$SRC"/libexec/*; do
		[[ -f $f ]] || continue
		cp -p "$f" "$CHROOT/usr/libexec/nucleo/"
		chmod 755 "$CHROOT/usr/libexec/nucleo/$(basename "$f")"
	done

	# Comandi e voci di menu dal registro src/app.tsv
	conteggio_app=0
	while IFS=$'\t' read -r comando modulo nome icona categorie descrizione nascosta mime || [[ -n ${comando:-} ]]; do
		[[ -z ${comando:-} || $comando == \#* ]] && continue
		eseguibile="$CHROOT/usr/bin/$OS_ID-$comando"
		printf '#!/bin/sh\n# Generato da src/app.tsv\nexec /usr/bin/python3 -m %s "$@"\n' "$modulo" >"$eseguibile"
		chmod 755 "$eseguibile"
		if [[ -n ${nome:-} ]]; then
			nome=$(applica_a_stringa "$nome")
			descrizione=$(applica_a_stringa "${descrizione:-}")
			icona=$(applica_a_stringa "${icona:-}")
			{
				echo "[Desktop Entry]"
				echo "Type=Application"
				echo "Name=$nome"
				echo "Comment=$descrizione"
				echo "Exec=$OS_ID-$comando %F"
				echo "Icon=$icona"
				echo "Categories=$categorie"
				echo "Terminal=false"
				echo "StartupNotify=true"
				[[ ${nascosta:-no} == si ]] && echo "NoDisplay=true"
				[[ -n ${mime:-} ]] && echo "MimeType=$mime"
			} >"$CHROOT/usr/share/applications/$OS_ID-$comando.desktop"
		fi
		conteggio_app=$((conteggio_app + 1))
	done <"$SRC/app.tsv"
	echo "  componenti installati: $conteggio_app comandi"
fi

# ── 4. Ambiente per gli altri script ─────────────────────────────────────────
scrivi_ambiente_branding "$DEST/branding.env"
cp "$DEST/branding.env" "$CHROOT/usr/share/nucleo/branding.env"
echo "Albero generato in: $DEST"
