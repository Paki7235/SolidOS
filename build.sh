#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Build della ISO live (BIOS + UEFI) del sistema definito in branding/branding.conf
#
#  Uso:
#    ./build.sh                     build nel contenitore Debian 13 amd64 (Docker o Podman)
#    ./build.sh --pulisci           ricomincia da zero (svuota anche la cache dei pacchetti)
#    ./build.sh --snapshot 20251101T000000Z
#                                   usa snapshot.debian.org a quella data (build riproducibile)
#    ./build.sh --nativo            build direttamente su un host Debian 13 amd64 (come root)
#    ./build.sh --solo-albero       genera solo l'albero live-build in build/albero (controllo)
#
#    ARCH=arm64 ./build.sh          ISO ARM64 (macchine virtuali su Mac Apple Silicon: UTM, Parallels, VMware)
#
#  Risultato in dist/: <id>-<versione>-<arch>.iso, .sha256, elenco pacchetti,
#  licenze-pacchetti.tsv, build.log.
#
#  Su macOS (anche Apple Silicon) serve un motore di contenitori con emulazione
#  amd64: Colima (consigliato, open source) o OrbStack / Docker Desktop.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

RADICE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib/branding.sh
. "$RADICE/scripts/lib/branding.sh"

IMMAGINE_CONTENITORE="docker.io/library/debian:trixie"
MODALITA=contenitore
PULISCI=${PULISCI:-0}
SNAPSHOT=${SNAPSHOT:-}

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
avviso() { printf '\033[1;33mATTENZIONE:\033[0m %s\n' "$*" >&2; }
errore() { printf '\033[1;31mERRORE:\033[0m %s\n' "$*" >&2; exit 1; }

uso() { sed -n '3,17p' "$0" | sed 's/^#  \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
	case $1 in
		--pulisci) PULISCI=1; shift ;;
		--snapshot) SNAPSHOT=${2:?--snapshot richiede una data, es. 20251101T000000Z}; shift 2 ;;
		--nativo) MODALITA=nativo; shift ;;
		--nel-contenitore) MODALITA=interno; shift ;;
		--solo-albero) MODALITA=albero; shift ;;
		-h|--aiuto|--help) uso; exit 0 ;;
		*) errore "opzione sconosciuta: $1 (vedi ./build.sh --aiuto)" ;;
	esac
done

carica_branding

# Data di riferimento per la riproducibilità (timestamp nei file della ISO)
if [[ -z ${SOURCE_DATE_EPOCH:-} ]]; then
	if git -C "$RADICE" rev-parse --git-dir >/dev/null 2>&1; then
		SOURCE_DATE_EPOCH=$(git -C "$RADICE" log -1 --format=%ct)
	else
		SOURCE_DATE_EPOCH=$(date +%s)
		[[ $MODALITA == contenitore || $MODALITA == nativo ]] \
			&& avviso "repository git assente: la data della build non è riproducibile"
	fi
fi
export SOURCE_DATE_EPOCH

# ── Fasi comuni (dentro il contenitore o su host Debian) ─────────────────────

prepara_host_debian() {
	[[ $(id -u) -eq 0 ]] || errore "la build richiede root (nel contenitore lo è già; su host usa sudo)"
	[[ $(dpkg --print-architecture 2>/dev/null) == "$ARCH" ]] \
		|| errore "per la ISO $ARCH serve un ambiente $ARCH (trovato: $(dpkg --print-architecture 2>/dev/null || uname -m))"
	grep -q 'trixie' /etc/os-release || avviso "l'host non è Debian 13: risultato non garantito"

	local sorgenti=/etc/apt/sources.list.d/debian.sources
	if [[ -f $sorgenti ]]; then
		sed -i 's/^Components: main$/Components: main contrib non-free non-free-firmware/' "$sorgenti"
		if [[ -n $SNAPSHOT ]]; then
			sed -i -e "s|^URIs: http://deb.debian.org/debian$|URIs: http://snapshot.debian.org/archive/debian/$SNAPSHOT/|" \
				-e "s|^URIs: http://deb.debian.org/debian-security$|URIs: http://snapshot.debian.org/archive/debian-security/$SNAPSHOT/|" \
				"$sorgenti"
			echo 'Acquire::Check-Valid-Until "false";' >/etc/apt/apt.conf.d/99snapshot
		fi
	fi

	info "Installazione degli strumenti di build"
	export DEBIAN_FRONTEND=noninteractive
	apt-get update -qq
	local per_arch
	if [[ $ARCH == amd64 ]]; then
		per_arch="isolinux syslinux-common syslinux-utils grub-efi-amd64-bin grub-pc-bin"
	else
		per_arch="grub-efi-arm64-bin"
	fi
	# shellcheck disable=SC2086
	apt-get install -y -qq --no-install-recommends \
		live-build debootstrap squashfs-tools xorriso cpio zstd $per_arch \
		grub-common mtools dosfstools \
		librsvg2-bin fonts-inter fonts-league-spartan python3-fonttools perl ca-certificates file >/dev/null
	info "live-build $(dpkg-query -W -f='${Version}' live-build)"
}

costruisci() { # LAVORO USCITA
	local lavoro=$1 uscita=$2
	local albero="$lavoro/albero" lb="$lavoro/lb"
	mkdir -p "$lavoro" "$uscita"

	info "Generazione dell'albero con il branding di ${OS_NAME}"
	"$RADICE/scripts/genera-branding.sh" "$albero"

	info "Verifica dei pacchetti nell'archivio Debian"
	"$RADICE/scripts/filtra-pacchetti.sh" "$albero"

	if [[ $PULISCI == 1 && -d $lb ]]; then
		info "Pulizia completa (anche cache)"
		(cd "$lb" && lb clean --purge >/dev/null 2>&1 || true)
		rm -rf "$lb"
	fi
	mkdir -p "$lb"
	if [[ -d $lb/config ]]; then
		(cd "$lb" && lb clean >/dev/null 2>&1 || true)
	fi
	# Tutto tranne la cache viene rigenerato a ogni build
	find "$lb" -mindepth 1 -maxdepth 1 ! -name cache -exec rm -rf {} +
	cp -a "$albero/." "$lb/"

	if [[ -n $SNAPSHOT ]]; then
		export SNAPSHOT_MIRROR="http://snapshot.debian.org/archive/debian/$SNAPSHOT/"
		export SNAPSHOT_MIRROR_SECURITY="http://snapshot.debian.org/archive/debian-security/$SNAPSHOT/"
		info "Archivio fissato allo snapshot $SNAPSHOT"
	fi

	cd "$lb"
	info "Configurazione di live-build"
	lb config
	info "Build della ISO (la prima volta può richiedere molto tempo)"
	if ! lb build; then
		cp "$lb/build.log" "$uscita/fallita.build.log" 2>/dev/null || true
		errore "build non riuscita: vedi $uscita/fallita.build.log"
	fi

	local iso
	iso=$(find "$lb" -maxdepth 1 -name '*.iso' -print -quit)
	[[ -n $iso ]] || errore "nessuna ISO prodotta: controlla $lb/build.log"

	local base="$uscita/$ISO_NOME_FILE"
	cp "$iso" "$base.iso"
	(cd "$uscita" && sha256sum "$ISO_NOME_FILE.iso" >"$ISO_NOME_FILE.iso.sha256")
	cp "$lb/build.log" "$uscita/$ISO_NOME_FILE.build.log"
	local elenco
	elenco=$(find "$lb" -maxdepth 1 -name '*.packages' -print -quit)
	[[ -n $elenco ]] && cp "$elenco" "$base.pacchetti.txt"

	info "Verifica delle licenze"
	"$RADICE/scripts/verifica-licenze.sh" "$lb/chroot" "$uscita/licenze-pacchetti.tsv" || avviso "verifica licenze non riuscita"

	if [[ -n ${UID_HOST:-} ]]; then
		chown -R "$UID_HOST:${GID_HOST:-$UID_HOST}" "$uscita"
	fi

	info "Fatto: $base.iso ($(du -h "$base.iso" | cut -f1))"
}

# ── Avvio nel contenitore ────────────────────────────────────────────────────

trova_motore() {
	local m
	for m in docker podman; do
		if command -v "$m" >/dev/null 2>&1 && "$m" info >/dev/null 2>&1; then
			echo "$m"
			return 0
		fi
	done
	return 1
}

avvia_contenitore() {
	local motore
	if ! motore=$(trova_motore); then
		if [[ $(uname -s) == Darwin ]]; then
			errore "nessun motore di contenitori attivo. Su macOS:
    brew install colima docker
    colima start --cpu 4 --memory 8 --disk 60 --vm-type vz --vz-rosetta
  poi rilancia ./build.sh"
		fi
		errore "serve Docker o Podman in esecuzione (oppure usa --nativo su Debian 13)"
	fi

	mkdir -p "$RADICE/dist"
	local volume="${OS_ID}-build-cache-$ARCH"
	info "Build nel contenitore ($motore, debian:trixie $ARCH, volume $volume)"

	local tty=()
	[[ -t 1 ]] && tty=(-t)
	"$motore" run --rm ${tty[@]+"${tty[@]}"} --privileged --platform "linux/$ARCH" \
		-v "$RADICE:/sorgente:ro" \
		-v "$volume:/lavoro" \
		-v "$RADICE/dist:/uscita" \
		-e SOURCE_DATE_EPOCH -e PULISCI -e SNAPSHOT -e ARCH \
		-e UID_HOST="$(id -u)" -e GID_HOST="$(id -g)" \
		"$IMMAGINE_CONTENITORE" \
		bash /sorgente/build.sh --nel-contenitore
}

case $MODALITA in
	contenitore)
		avvia_contenitore
		;;
	interno)
		# Dentro il contenitore: il lavoro avviene nel volume (file system Linux,
		# necessario per chroot, permessi e nomi sensibili alle maiuscole).
		prepara_host_debian
		costruisci /lavoro /uscita
		;;
	nativo)
		[[ $(uname -s) == Linux ]] || errore "--nativo funziona solo su Linux"
		prepara_host_debian
		costruisci "$RADICE/build" "$RADICE/dist"
		;;
	albero)
		"$RADICE/scripts/genera-branding.sh" "$RADICE/build/albero" \
			$(command -v rsvg-convert >/dev/null || echo --senza-immagini)
		;;
esac
