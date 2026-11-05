#!/usr/bin/env bash
# Produce l'elenco delle licenze di tutti i pacchetti presenti nella ISO,
# leggendo i file copyright di Debian dal chroot di live-build.
#
#   scripts/verifica-licenze.sh CHROOT FILE_USCITA.tsv
#
# Colonne: pacchetto, versione, sezione, licenze (dai campi "License:" in
# formato DEP-5; "da verificare a mano" se il file non è leggibile in automatico).
# I pacchetti delle sezioni non-free / non-free-firmware / contrib vengono
# segnalati anche a schermo.
set -euo pipefail

CHROOT=${1:?Uso: verifica-licenze.sh CHROOT FILE_USCITA.tsv}
USCITA=${2:?Uso: verifica-licenze.sh CHROOT FILE_USCITA.tsv}
[[ -d $CHROOT/var/lib/dpkg ]] || { echo "ERRORE: $CHROOT non è un chroot Debian" >&2; exit 1; }

printf 'pacchetto\tversione\tsezione\tlicenze\n' >"$USCITA"
non_libero=()

while IFS=$'\t' read -r pacchetto versione sezione; do
	nome=${pacchetto%%:*}
	copyright="$CHROOT/usr/share/doc/$nome/copyright"
	licenze="da verificare a mano"
	if [[ -f $copyright ]]; then
		trovate=$(awk -F': *' '/^License:/ { print $2 }' "$copyright" | sort -u | paste -sd ',' - | sed 's/,/, /g')
		[[ -n $trovate ]] && licenze=$trovate
	elif [[ -L $CHROOT/usr/share/doc/$nome ]]; then
		licenze="vedi pacchetto collegato ($(readlink "$CHROOT/usr/share/doc/$nome"))"
	fi
	printf '%s\t%s\t%s\t%s\n' "$nome" "$versione" "$sezione" "$licenze" >>"$USCITA"
	case $sezione in non-free*|contrib*) non_libero+=("$nome ($sezione)") ;; esac
done < <(chroot "$CHROOT" dpkg-query -W -f='${binary:Package}\t${Version}\t${Section}\n' | sort)

echo "Licenze di $(($(wc -l <"$USCITA") - 1)) pacchetti scritte in $USCITA"
if ((${#non_libero[@]})); then
	echo "Pacchetti non liberi o contrib inclusi (${#non_libero[@]}):"
	printf '  - %s\n' "${non_libero[@]}"
fi
