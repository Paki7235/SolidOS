#!/usr/bin/env bash
# Trasforma gli elenchi pacchetti/*.txt di un albero generato nella lista di
# live-build, verificando che ogni pacchetto esista nell'archivio Debian.
#
#   scripts/filtra-pacchetti.sh ALBERO
#
# - riga "nome"   → obbligatorio: se manca, errore e build fermata;
# - riga "?nome"  → facoltativo: se manca, avviso e pacchetto saltato.
# - riga "nome @amd64" o "nome @arm64" → solo per quell'architettura.
# Deve girare su un sistema Debian 13 della stessa architettura della ISO (il contenitore di build).
set -euo pipefail

ALBERO=${1:?Uso: filtra-pacchetti.sh ALBERO}
LISTA="$ALBERO/config/package-lists/sistema.list.chroot"
mkdir -p "$(dirname "$LISTA")"

ARCHITETTURA=$(dpkg --print-architecture 2>/dev/null || echo amd64)
esiste() { [[ -n $(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ { print $2 }' | grep -v '(none)') ]]; }

mancanti_obbligatori=()
mancanti_facoltativi=()
totale=0
: >"$LISTA"

for elenco in "$ALBERO"/pacchetti/*.txt; do
	echo "# --- $(basename "$elenco") ---" >>"$LISTA"
	while IFS= read -r riga || [[ -n $riga ]]; do
		riga=${riga%%#*}
		riga=$(echo "$riga" | xargs)
		[[ -z $riga ]] && continue
		if [[ $riga == *" @"* ]]; then
			solo=${riga##* @}
			riga=${riga%% @*}
			[[ $solo == "$ARCHITETTURA" ]] || continue
		fi
		facoltativo=0
		if [[ $riga == \?* ]]; then
			facoltativo=1
			riga=${riga#\?}
		fi
		if esiste "$riga"; then
			echo "$riga" >>"$LISTA"
			totale=$((totale + 1))
		elif ((facoltativo)); then
			mancanti_facoltativi+=("$riga")
		else
			mancanti_obbligatori+=("$riga")
		fi
	done <"$elenco"
done

if ((${#mancanti_facoltativi[@]})); then
	echo "AVVISO: pacchetti facoltativi non disponibili, saltati: ${mancanti_facoltativi[*]}"
fi
if ((${#mancanti_obbligatori[@]})); then
	echo "ERRORE: pacchetti obbligatori non disponibili: ${mancanti_obbligatori[*]}" >&2
	exit 1
fi
echo "Pacchetti nella lista: $totale"
