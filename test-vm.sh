#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Avvia la ISO in una macchina virtuale QEMU x86_64.
#
#  Uso:
#    ./test-vm.sh                 firmware BIOS (predefinito)
#    ./test-vm.sh --uefi          firmware UEFI (OVMF)
#    ./test-vm.sh --ram 1024      RAM in MB (predefinita 2048; prova anche 1024 e 4096)
#    ./test-vm.sh --cpu 4         numero di CPU virtuali (predefinito 2)
#    ./test-vm.sh --disco         collega un disco virtuale vuoto da 30 GB (per l'installer)
#    ./test-vm.sh --iso FILE      ISO da avviare (predefinita: la più recente in dist/)
#    ./test-vm.sh --stampa        mostra solo il comando QEMU, senza eseguirlo
#
#  Accelerazione: KVM su Linux, HVF su Mac Intel. Su Mac Apple Silicon la VM è
#  emulata (TCG): funziona ma è lenta, adatta a verificare avvio e RAM, non la fluidità.
#  Installazione QEMU: macOS «brew install qemu», Debian «apt install qemu-system-x86 ovmf».
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

RADICE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FIRMWARE=bios
RAM=2048
CPU=2
DISCO=0
ISO=""
STAMPA=0

errore() { printf '\033[1;31mERRORE:\033[0m %s\n' "$*" >&2; exit 1; }
uso() { sed -n '3,17p' "$0" | sed 's/^#  \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
	case $1 in
		--bios) FIRMWARE=bios; shift ;;
		--uefi) FIRMWARE=uefi; shift ;;
		--ram) RAM=${2:?}; shift 2 ;;
		--cpu) CPU=${2:?}; shift 2 ;;
		--disco) DISCO=1; shift ;;
		--iso) ISO=${2:?}; shift 2 ;;
		--stampa) STAMPA=1; shift ;;
		-h|--aiuto|--help) uso; exit 0 ;;
		*) errore "opzione sconosciuta: $1 (vedi ./test-vm.sh --aiuto)" ;;
	esac
done

command -v qemu-system-x86_64 >/dev/null || errore "qemu-system-x86_64 non trovato (macOS: brew install qemu)"

if [[ -z $ISO ]]; then
	ISO=$(ls -t "$RADICE"/dist/*.iso 2>/dev/null | head -n 1 || true)
	[[ -n $ISO ]] || errore "nessuna ISO in dist/: esegui prima ./build.sh"
fi
[[ -f $ISO ]] || errore "ISO non trovata: $ISO"

VM="$RADICE/build/vm"
mkdir -p "$VM"

argomenti=(
	-name "test $(basename "$ISO") [$FIRMWARE]"
	-machine q35
	-m "$RAM"
	-smp "$CPU"
	-device virtio-vga
	-usb -device usb-tablet
	-nic user,model=virtio-net-pci
	-drive "file=$ISO,media=cdrom,readonly=on,if=none,id=cd0"
	-device ide-cd,drive=cd0,bootindex=1
	-boot menu=on
)

# Accelerazione
sistema=$(uname -s)
architettura=$(uname -m)
if [[ $sistema == Linux && -w /dev/kvm ]]; then
	argomenti+=(-accel kvm -cpu host)
elif [[ $sistema == Darwin && $architettura == x86_64 ]]; then
	argomenti+=(-accel hvf -cpu host)
else
	argomenti+=(-accel tcg,thread=multi -cpu max)
	echo "Nota: nessuna accelerazione hardware disponibile, la VM è emulata (lenta)."
fi

# Audio e visualizzazione
if [[ $sistema == Darwin ]]; then
	argomenti+=(-audiodev coreaudio,id=audio0 -display cocoa)
else
	argomenti+=(-audiodev pa,id=audio0)
fi
argomenti+=(-device intel-hda -device hda-duplex,audiodev=audio0)

# Firmware UEFI
if [[ $FIRMWARE == uefi ]]; then
	prefisso_brew=$(brew --prefix 2>/dev/null || true)
	codice=""
	variabili=""
	for c in \
		/usr/share/OVMF/OVMF_CODE_4M.fd:/usr/share/OVMF/OVMF_VARS_4M.fd \
		/usr/share/OVMF/OVMF_CODE.fd:/usr/share/OVMF/OVMF_VARS.fd \
		/usr/share/edk2/x64/OVMF_CODE.4m.fd:/usr/share/edk2/x64/OVMF_VARS.4m.fd \
		/usr/share/edk2/ovmf/OVMF_CODE.fd:/usr/share/edk2/ovmf/OVMF_VARS.fd \
		"$prefisso_brew/share/qemu/edk2-x86_64-code.fd:$prefisso_brew/share/qemu/edk2-i386-vars.fd"; do
		if [[ -f ${c%%:*} && -f ${c#*:} ]]; then
			codice=${c%%:*}
			variabili=${c#*:}
			break
		fi
	done
	[[ -n $codice ]] || errore "firmware OVMF non trovato (Debian: apt install ovmf; macOS: incluso in brew qemu)"
	cp -f "$variabili" "$VM/OVMF_VARS.fd"
	argomenti+=(
		-drive "if=pflash,format=raw,readonly=on,file=$codice"
		-drive "if=pflash,format=raw,file=$VM/OVMF_VARS.fd"
	)
fi

# Disco virtuale per i test di installazione (Fase 5)
if ((DISCO)); then
	command -v qemu-img >/dev/null || errore "qemu-img non trovato"
	immagine="$VM/disco-$FIRMWARE.qcow2"
	[[ -f $immagine ]] || qemu-img create -q -f qcow2 "$immagine" 30G
	argomenti+=(-drive "file=$immagine,if=virtio,format=qcow2")
fi

echo "ISO: $ISO"
echo "Firmware: $FIRMWARE · RAM: ${RAM} MB · CPU: $CPU"
if ((STAMPA)); then
	printf 'qemu-system-x86_64'
	printf ' %q' "${argomenti[@]}"
	printf '\n'
	exit 0
fi
exec qemu-system-x86_64 "${argomenti[@]}"
