# shellcheck shell=bash
# Libreria: carica branding/branding.conf e i testi della lingua, calcola le
# variabili derivate ed esporta tutto per la sostituzione dei segnaposto @VAR@.
# Uso: RADICE=/percorso/progetto; . scripts/lib/branding.sh; carica_branding

# Elenco delle variabili disponibili nei modelli (riempito da carica_branding).
VARIABILI_BRANDING=()

_errore_branding() { printf 'ERRORE (branding): %s\n' "$*" >&2; exit 1; }

# Converte "#RRGGBB" in tre frazioni 0..1 (per Plymouth).
_hex_a_frazioni() {
	local h=${1#\#}
	[[ $h =~ ^[0-9A-Fa-f]{6}$ ]] || _errore_branding "colore non valido: $1"
	local r=$((16#${h:0:2})) g=$((16#${h:2:2})) b=$((16#${h:4:2}))
	awk -v r="$r" -v g="$g" -v b="$b" 'BEGIN { printf "%.3f %.3f %.3f", r/255, g/255, b/255 }'
}

_variabili_da_file() {
	grep -oE '^[A-Z][A-Z0-9_]*=' "$1" | tr -d '='
}

carica_branding() {
	local conf="$RADICE/branding/branding.conf"
	[[ -f $conf ]] || _errore_branding "manca $conf"

	set -a
	# shellcheck disable=SC1090
	. "$conf"
	set +a

	[[ -n ${OS_NAME:-} ]] || _errore_branding "OS_NAME è vuoto"

	if [[ -z ${OS_ID:-} ]]; then
		OS_ID=$(printf '%s' "$OS_NAME" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null \
			| tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')
	fi
	[[ $OS_ID =~ ^[a-z][a-z0-9]{1,30}$ ]] \
		|| _errore_branding "OS_ID «$OS_ID» non valido: servono 2-31 caratteri a-z/0-9, iniziale lettera"
	export OS_ID

	local testi="$RADICE/branding/testi/${LINGUA:-it}.conf"
	[[ -f $testi ]] || _errore_branding "manca il file dei testi $testi"
	set -a
	# shellcheck disable=SC1090
	. "$testi"
	set +a

	# ── Variabili derivate ───────────────────────────────────────────────────
	local nome colore
	for nome in COLORE_ACCENTO COLORE_ACCENTO_SCURO COLORE_SFONDO_SCURO COLORE_TESTO_CHIARO; do
		colore=${!nome}
		read -r "${nome}_R" "${nome}_G" "${nome}_B" <<<"$(_hex_a_frazioni "$colore")"
		export "${nome}_R" "${nome}_G" "${nome}_B"
		# Senza '#', per ISOLINUX (#AARRGGBB) e GRUB
		printf -v "${nome}_HEX" '%s' "${colore#\#}"
		export "${nome}_HEX"
		VARIABILI_BRANDING+=("${nome}_R" "${nome}_G" "${nome}_B" "${nome}_HEX")
	done

	# Nome del volume ISO: massimo 32 caratteri
	ISO_VOLUME=$(printf '%s %s' "$OS_NAME" "$OS_VERSION" | cut -c1-32)
	ISO_NOME_FILE="${OS_ID}-${OS_VERSION}-amd64"
	# Parametri del kernel comuni a tutte le voci live
	KERNEL_PARAMETRI_LIVE="boot=live components quiet splash"
	TEMA_ICONE=${TEMA_ICONE:-$OS_ID}
	export ISO_VOLUME ISO_NOME_FILE KERNEL_PARAMETRI_LIVE TEMA_ICONE
	VARIABILI_BRANDING+=(OS_ID ISO_VOLUME ISO_NOME_FILE KERNEL_PARAMETRI_LIVE)

	local v
	while read -r v; do VARIABILI_BRANDING+=("$v"); done < <(_variabili_da_file "$conf"; _variabili_da_file "$testi")
	for v in "${VARIABILI_BRANDING[@]}"; do export "${v?}"; done
}

# Sequenza di escape: @@NOME@@ nel modello diventa il testo letterale @NOME@
# (serve per strumenti che usano la stessa sintassi, es. wpctl @@DEFAULT_AUDIO_SINK@@).
_PERL_ESC_INIZIO='s/@@([A-Z][A-Z0-9_]*)@@/\x01$1\x01/g;'
_PERL_ESC_FINE='s/\x01/@/g;'

# Sostituisce @VAR@ nel file $1 scrivendo $2. Fallisce se una variabile non esiste.
applica_modello() {
	local sorgente=$1 destinazione=$2
	mkdir -p "$(dirname "$destinazione")"
	MODELLO_CORRENTE="$sorgente" perl -pe "$_PERL_ESC_INIZIO"'s/@([A-Z][A-Z0-9_]*)@/exists $ENV{$1} ? $ENV{$1} : die("segnaposto sconosciuto \@$1\@ in $ENV{MODELLO_CORRENTE} riga $.\n")/ge;'"$_PERL_ESC_FINE" \
		"$sorgente" >"$destinazione" || { rm -f "$destinazione"; _errore_branding "modello non valido: $sorgente"; }
}

# Sostituisce @VAR@ in una stringa (es. un percorso) e la stampa.
applica_a_stringa() {
	printf '%s' "$1" | perl -pe "$_PERL_ESC_INIZIO"'s/@([A-Z][A-Z0-9_]*)@/exists $ENV{$1} ? $ENV{$1} : die("segnaposto sconosciuto \@$1\@\n")/ge;'"$_PERL_ESC_FINE"
}

# Scrive tutte le variabili in formato shell (per gli altri script).
scrivi_ambiente_branding() {
	local file=$1 v
	: >"$file"
	for v in $(printf '%s\n' "${VARIABILI_BRANDING[@]}" | sort -u); do
		printf '%s=%q\n' "$v" "${!v}" >>"$file"
	done
}
