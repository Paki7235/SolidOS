# Comandi di altri sistemi operativi nel Terminale (prompt dei comandi, shell a oggetti,
# terminale Unix).
#
# Chi arriva da un altro sistema operativo può scrivere i comandi che conosce: qui diventano
# l'equivalente Linux. I comandi Linux restano tutti uguali.
# Caricato da /etc/bash.bashrc solo nelle shell interattive. «comandi» mostra l'elenco.

[ -n "$BASH_VERSION" ] || return 0
case $- in *i*) ;; *) return 0 ;; esac

__nc_nota() { printf '\033[2m(%s)\033[0m\n' "$*" >&2; }
__nc_c() { command -v "$1" >/dev/null 2>&1; }
# Le opzioni con la barra («/s», «/q», «/a»…) in minuscolo, per confrontarle
__nc_min() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# ══ Altri sistemi: prompt dei comandi ═════════════════════════════════════════
alias cls='clear'
alias cd..='cd ..'
alias chdir='cd'
alias md='mkdir -p'
alias ver='__nc_ver'
alias winver='__nc_ver'

# «type FILE» mostra il file come nel prompt dei comandi; «type comando» resta quello di Linux
type() {
	if [ $# -ge 1 ] && [ "${1#-}" = "$1" ] && [ -f "${1//\\//}" ]; then cat -- "${@//\\//}"; else builtin type "$@"; fi
}

dir() {
	local mostra_tutto="" larghi="" args=()
	for a in "$@"; do
		case "$(__nc_min "$a")" in
			/a|/ah|/as) mostra_tutto=1 ;;
			/w|/d) larghi=1 ;;
			/s) args+=("-R") ;;
			/b) larghi=b ;;
			/p|/q|/o*|/t*) ;;
			*) args+=("${a//\\//}") ;;
		esac
	done
	if [ "$larghi" = b ]; then ls -1 ${mostra_tutto:+-A} "${args[@]}"
	elif [ -n "$larghi" ]; then ls -C ${mostra_tutto:+-A} "${args[@]}"
	else ls -lh --group-directories-first ${mostra_tutto:+-A} "${args[@]}"
	fi
}

copy() {
	local args=()
	for a in "$@"; do case "$(__nc_min "$a")" in /y|/v|/b|/a|/-y|/z) ;; *) args+=("${a//\\//}") ;; esac; done
	[ ${#args[@]} -eq 1 ] && args+=(".")
	cp -iv "${args[@]}"
}
xcopy() {
	local args=()
	for a in "$@"; do case "$(__nc_min "$a")" in /*) ;; *) args+=("${a//\\//}") ;; esac; done
	[ ${#args[@]} -eq 1 ] && args+=(".")
	cp -rv "${args[@]}"
}
robocopy() {
	[ $# -ge 2 ] || { echo "uso: robocopy ORIGINE DESTINAZIONE [/MIR]"; return 1; }
	local da="${1//\\//}" a="${2//\\//}" extra=()
	shift 2
	for o in "$@"; do [ "$(__nc_min "$o")" = /mir ] && extra+=("--delete"); done
	__nc_nota "rsync -a --info=progress2 ${extra[*]} \"$da/\" \"$a/\""
	rsync -a --info=progress2 "${extra[@]}" "$da/" "$a/"
}
move() {
	local args=()
	for a in "$@"; do case "$(__nc_min "$a")" in /y|/-y) ;; *) args+=("${a//\\//}") ;; esac; done
	mv -iv "${args[@]}"
}
del() {
	local ricorsivo="" args=()
	for a in "$@"; do
		case "$(__nc_min "$a")" in /s) ricorsivo=1 ;; /q|/f|/p|/a*) ;; *) args+=("${a//\\//}") ;; esac
	done
	[ ${#args[@]} -gt 0 ] || { echo "uso: del FILE…"; return 1; }
	if __nc_c gio; then
		gio trash -- "${args[@]}" && __nc_nota "spostato nel Cestino: si può recuperare"
	else
		rm -i ${ricorsivo:+-r} -- "${args[@]}"
	fi
}
alias erase='del'
ren() {
	[ $# -eq 2 ] || { echo "uso: ren VECCHIO_NOME NUOVO_NOME"; return 1; }
	local vecchio="${1//\\//}"
	mv -iv -- "$vecchio" "$(dirname -- "$vecchio")/$2"
}
rd() {
	local args=() ricorsivo=""
	for a in "$@"; do case "$(__nc_min "$a")" in /s) ricorsivo=1 ;; /q) ;; *) args+=("${a//\\//}") ;; esac; done
	if [ -n "$ricorsivo" ]; then
		if __nc_c gio; then gio trash -- "${args[@]}" && __nc_nota "spostata nel Cestino"; else rm -rI -- "${args[@]}"; fi
	else
		command rmdir -- "${args[@]}"
	fi
}

ipconfig() {
	case "$(__nc_min "${1:-}")" in
		"") ip -br -c address; echo; ip route show default ;;
		/all) ip -c address; echo; ip route; echo; __nc_c resolvectl && resolvectl status 2>/dev/null | head -20 || cat /etc/resolv.conf ;;
		/release) nmcli networking off && echo "Rete disattivata" ;;
		/renew) nmcli networking on && echo "Rete riattivata" ;;
		/flushdns) resolvectl flush-caches 2>/dev/null && echo "Cache DNS svuotata" || echo "Nessuna cache DNS da svuotare" ;;
		*) echo "uso: ipconfig [/all | /release | /renew | /flushdns]" ;;
	esac
}
getmac() { ip -br link | awk '$1 != "lo" {print $1, $3}'; }
tracert() { if __nc_c traceroute; then traceroute "$@"; else tracepath "$@"; fi; }
pathping() { tracert "$@"; }
netstat() { if __nc_c /usr/bin/netstat; then command netstat "$@"; else __nc_nota "ss -tunap"; ss -tunap; fi; }
nslookup() {
	if __nc_c /usr/bin/nslookup; then command nslookup "$@"
	else getent ahosts "$1" | awk '{print $1}' | sort -u
	fi
}
tasklist() { ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | head -n "${1:-40}"; }
taskkill() {
	local forza="" nome="" pid=""
	while [ $# -gt 0 ]; do
		case "$(__nc_min "$1")" in
			/f) forza=1 ;;
			/im) shift; nome="${1%.exe}" ;;
			/pid) shift; pid="$1" ;;
			/t) ;;
			*) nome="${1%.exe}" ;;
		esac
		shift
	done
	if [ -n "$pid" ]; then kill ${forza:+-9} "$pid"
	elif [ -n "$nome" ]; then pkill ${forza:+-9} -x "$nome" || pkill ${forza:+-9} -f "$nome"
	else echo "uso: taskkill /IM nome.exe  oppure  taskkill /PID numero  [/F]"; return 1
	fi
}
systeminfo() {
	. /etc/os-release
	echo "Sistema:        $PRETTY_NAME"
	echo "Nome computer:  $(hostname)"
	echo "Kernel:         $(uname -r)"
	echo "Processore:     $(awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo)"
	echo "Memoria:        $(free -h | awk '/^Mem/ {print $2 " totale, " $7 " libera"}')"
	echo "Avviato da:     $(uptime -p 2>/dev/null)"
	echo "Disco /:        $(df -h / | awk 'NR==2 {print $3 " usati di " $2}')"
}
__nc_ver() { . /etc/os-release; echo "$PRETTY_NAME [kernel $(uname -r)]"; }
where() { local r=0; for c in "$@"; do builtin type -P "${c%.exe}" || { echo "INFO: impossibile trovare «$c»." >&2; r=1; }; done; return $r; }
findstr() {
	local opz=() args=()
	for a in "$@"; do
		case "$(__nc_min "$a")" in /i) opz+=(-i) ;; /s) opz+=(-r) ;; /n) opz+=(-n) ;; /v) opz+=(-v) ;; /c:*) args+=("${a:3}") ;; *) args+=("$a") ;; esac
	done
	grep --color=auto "${opz[@]}" -- "${args[@]}"
}
fc() {
	# «fc» in bash è anche lo storico: con due file confronta i file
	if [ $# -ge 2 ] && [ -e "${1//\\//}" ]; then diff --color=auto -- "${1//\\//}" "${2//\\//}"; else builtin fc "$@"; fi
}
comp() { cmp -- "${1//\\//}" "${2//\\//}"; }
tree() {
	if __nc_c /usr/bin/tree; then command tree "$@"; return; fi
	local base="${1:-.}"
	find "$base" -not -path '*/.*' | sort | sed -e "s|^$base||" -e 's|[^/]*/|│   |g' -e 's|│   \([^│]\)|├── \1|'
}
shutdown() {
	local riavvia="" ritardo=0 annulla=""
	while [ $# -gt 0 ]; do
		case "$(__nc_min "$1")" in
			/s|-s) ;;
			/r|-r) riavvia=1 ;;
			/t|-t) shift; ritardo="$1" ;;
			/a|-a|-c) annulla=1 ;;
			/h) systemctl hibernate; return ;;
			/l) loginctl terminate-session "${XDG_SESSION_ID:-self}"; return ;;
			*) command shutdown "$@"; return ;;   # sintassi Linux («shutdown now», «shutdown -h +5»…)
		esac
		shift
	done
	if [ -n "$annulla" ]; then command shutdown -c; return; fi
	local minuti=$(( (ritardo + 59) / 60 ))
	if [ -n "$riavvia" ]; then command shutdown -r "+$minuti"; else command shutdown -h "+$minuti"; fi
}
start() {
	[ $# -gt 0 ] || { qterminal >/dev/null 2>&1 & disown; return; }
	[ "$1" = '""' ] && shift
	xdg-open "${1//\\//}" >/dev/null 2>&1 & disown
}
alias explorer='__nc_apri_file'
__nc_apri_file() { __nc_app file "${1:-.}"; }
notepad() { __nc_app testo "$@"; }
calc() { __nc_app calcolatrice "$@"; }
control() { __nc_app impostazioni "$@"; }
taskmgr() { __nc_app monitor "$@"; }
diskmgmt() { __nc_app dischi "$@"; }
alias diskmgmt.msc='diskmgmt'
alias diskpart='diskmgmt'
alias msconfig='control'
alias mspaint='__nc_nota "apre Foto"; __nc_app foto'
__nc_app() {
	local id; id=$(. /etc/os-release && echo "$ID")
	local nome="$1"; shift
	if __nc_c "$id-$nome"; then "$id-$nome" "$@" >/dev/null 2>&1 & disown
	else echo "App «$nome» non trovata"; return 1; fi
}
clip() { wl-copy; }
title() { printf '\033]0;%s\007' "$*"; }
chkdsk() { __nc_nota "su Linux il controllo del disco si fa a disco non montato: apri l'app Dischi"; lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS; }
sfc() { __nc_nota "verifica dei file del sistema"; sudo dpkg --verify 2>/dev/null | head -50 && echo "Controllo completato."; }
attrib() {
	local f="${*: -1}"
	case "$(__nc_min "$1")" in
		+r) chmod a-w -- "${f//\\//}" ;; -r) chmod u+w -- "${f//\\//}" ;;
		+h) __nc_nota "su Linux i file nascosti iniziano con un punto: ren $f .$f" ;;
		*) ls -l -- "${f//\\//}" ;;
	esac
}
mklink() {
	local opz="-s"
	case "$(__nc_min "$1")" in /h) opz=""; shift ;; /d|/j) shift ;; esac
	ln $opz -- "${2//\\//}" "${1//\\//}"
}
wmic() { __nc_nota "wmic non esiste su Linux: uso «systeminfo»"; systeminfo; }
winget() {
	case "$(__nc_min "${1:-}")" in
		install) shift; sudo apt install "$@" ;;
		search) shift; apt search "$@" ;;
		upgrade) sudo apt update && sudo apt upgrade ;;
		uninstall|remove) shift; sudo apt remove "$@" ;;
		list) apt list --installed 2>/dev/null | less ;;
		*) echo "uso: winget install|search|upgrade|uninstall|list NOME  (usa apt; c'è anche lo Store)" ;;
	esac
}
alias choco='winget'

# ══ Altri sistemi: shell a oggetti (Get-…, Set-…) ════════════════════════════
alias Get-ChildItem='ls -la' gci='ls -la'
alias Set-Location='cd' sl='cd'
alias Get-Location='pwd' gl='pwd'
alias Get-Content='cat' gc='cat'
alias Set-Content='tee' Add-Content='tee -a'
alias Copy-Item='cp -riv' cpi='cp -riv'
alias Move-Item='mv -iv' mi='mv -iv'
alias Remove-Item='del' ri='del'
alias Rename-Item='ren' rni='ren'
alias Clear-Host='clear'
alias Get-Process='tasklist' gps='tasklist'
alias Write-Host='echo' Write-Output='echo'
alias Get-Help='man'
alias Get-Command='type -a'
alias Get-History='history'
alias Restart-Computer='systemctl reboot'
alias Stop-Computer='systemctl poweroff'
alias Get-Date='date'
alias Get-NetIPAddress='ip -br -c address'
alias Get-NetAdapter='ip -br link'
alias Resolve-DnsName='nslookup'
alias Invoke-WebRequest='curl -LO' iwr='curl -LO'
alias Invoke-RestMethod='curl -s' irm='curl -s'
alias Get-Service='systemctl list-units --type=service'
alias Select-String='findstr' sls='findstr'
alias Measure-Object='wc'
alias Get-ComputerInfo='systeminfo'
New-Item() {
	local tipo="file" nome=""
	while [ $# -gt 0 ]; do
		case "$(__nc_min "$1")" in
			-itemtype|-type) shift; tipo="$(__nc_min "$1")" ;;
			-path|-name) shift; nome="$1" ;;
			*) nome="$1" ;;
		esac
		shift
	done
	if [ "$tipo" = directory ]; then mkdir -p -- "$nome"; else touch -- "$nome"; fi
}
alias ni='New-Item' mkdir.exe='mkdir -p'
Stop-Process() {
	case "$(__nc_min "${1:-}")" in
		-name) pkill -x "$2" ;;
		-id) kill "$2" ;;
		*) kill "$@" ;;
	esac
}
alias spps='Stop-Process' kill.exe='Stop-Process'
Test-Connection() { ping -c 4 "${@: -1}"; }
Test-NetConnection() { ping -c 4 "${@: -1}"; }

# ══ Altri sistemi: terminale Unix (open, pbcopy…) ════════════════════════════
open() {
	if [ "${1:-}" = "-a" ] && [ -n "${2:-}" ]; then
		local app="$2"; shift 2
		local id; id=$(. /etc/os-release && echo "$ID")
		case "$(__nc_min "$app")" in
			safari|"google chrome"|chrome|firefox) app="$id-web" ;;
			finder) app="$id-file" ;;
			textedit) app="$id-testo" ;;
			"system settings"|"system preferences") app="$id-impostazioni" ;;
			calculator) app="$id-calcolatrice" ;;
			terminal) app="qterminal" ;;
			notes) app="$id-note" ;;
			preview|photos) app="$id-foto" ;;
		esac
		"$app" "$@" >/dev/null 2>&1 & disown
		return
	fi
	[ "${1:-}" = "-R" ] && { shift; __nc_apri_file "$(dirname -- "${1:-.}")"; return; }
	if [ $# -eq 0 ]; then echo "uso: open FILE|CARTELLA|URL  oppure  open -a App"; return 1; fi
	for f in "$@"; do xdg-open "$f" >/dev/null 2>&1 & disown; done
}
alias pbcopy='wl-copy'
alias pbpaste='wl-paste --no-newline'
say() {
	if __nc_c spd-say; then spd-say -l it -w "$*"
	elif __nc_c espeak-ng; then espeak-ng -v it "$*"
	else echo "Sintesi vocale non disponibile"; return 1; fi
}
sw_vers() {
	. /etc/os-release
	echo "ProductName:    $NAME"
	echo "ProductVersion: ${VERSION_ID:-$VERSION}"
	echo "BuildVersion:   $(uname -r)"
}
system_profiler() { systeminfo; echo; lsblk -o NAME,SIZE,MODEL; }
diskutil() {
	case "${1:-}" in
		list) lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS ;;
		info) lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,UUID,MODEL,MOUNTPOINTS "${2:-}" ;;
		eject|unmount|unmountDisk) udisksctl unmount -b "$2" 2>/dev/null; udisksctl power-off -b "$2" ;;
		mount) udisksctl mount -b "$2" ;;
		*) echo "uso: diskutil list | info DISCO | mount DISCO | eject DISCO   (oppure apri l'app Dischi)" ;;
	esac
}
caffeinate() {
	if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then systemd-inhibit --what=idle:sleep --why="caffeinate" "$@"
	else echo "Il computer resta sveglio finché non premi Ctrl+C…"; systemd-inhibit --what=idle:sleep --why="caffeinate" sleep infinity
	fi
}
ditto() { cp -a -- "$@"; }
mdfind() { if __nc_c plocate; then plocate -i -- "$*"; else find ~ -iname "*$1*" 2>/dev/null; fi; }
mdls() { stat -- "$@"; file -- "$@"; }
softwareupdate() {
	case "${1:-}" in
		-l|--list) apt list --upgradable 2>/dev/null ;;
		-i|--install|-ia) sudo apt update && sudo apt upgrade ;;
		*) echo "uso: softwareupdate -l (elenco) | -ia (installa tutto)" ;;
	esac
}
brew() {
	case "${1:-}" in
		install) shift; __nc_nota "sudo apt install $*"; sudo apt install "$@" ;;
		uninstall|remove) shift; sudo apt remove "$@" ;;
		search) shift; apt search "$@" ;;
		update) sudo apt update ;;
		upgrade) sudo apt update && sudo apt upgrade ;;
		list) apt list --installed 2>/dev/null | less ;;
		info) shift; apt show "$@" ;;
		*) echo "Homebrew qui non serve: brew install|uninstall|search|update|upgrade|list|info usano apt (c'è anche lo Store)" ;;
	esac
}
networksetup() {
	case "${1:-}" in
		-listallhardwareports) nmcli device ;;
		-setairportpower) nmcli radio wifi "$3" ;;
		-getairportnetwork) nmcli -t -f active,ssid dev wifi | awk -F: '$1=="yes" {print "Rete Wi-Fi attuale: " $2}' ;;
		-setairportnetwork) nmcli device wifi connect "$3" ${4:+password "$4"} ;;
		*) nmcli general status ;;
	esac
}
ifconfig() { if __nc_c /usr/sbin/ifconfig; then command ifconfig "$@"; else ip -c address; fi; }
afplay() { pw-play -- "$@"; }
screencapture() { grim "${1:-$HOME/Schermata-$(date +%Y%m%d-%H%M%S).png}"; }
pmset() {
	case "${1:-}" in
		sleepnow) systemctl suspend ;;
		displaysleepnow) "$(. /etc/os-release && echo "$ID")-blocca" ;;
		-g) powerprofilesctl 2>/dev/null; cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | sed 's/^/Batteria: /;s/$/%/' ;;
		*) echo "uso: pmset sleepnow | displaysleepnow | -g" ;;
	esac
}
launchctl() {
	case "${1:-}" in
		list) systemctl --user list-units --type=service ;;
		start|load) systemctl --user start "$2" ;;
		stop|unload) systemctl --user stop "$2" ;;
		*) systemctl --user "$@" ;;
	esac
}
dscacheutil() { resolvectl flush-caches 2>/dev/null; echo "Cache DNS svuotata"; }
md5() { md5sum "$@"; }
qlmanage() { [ "${1:-}" = "-p" ] && shift; open "$@"; }
defaults() { __nc_nota "su questo sistema le preferenze si cambiano in Impostazioni"; control; }

# ══ Maiuscole, «.exe», «.bat» come negli altri sistemi ═══════════════════════
# DIR, Cls, IPCONFIG, notepad.exe… funzionano lo stesso.
if declare -F command_not_found_handle >/dev/null; then
	eval "__nc_cnf_originale() $(declare -f command_not_found_handle | tail -n +2)"
fi
command_not_found_handle() {
	local nome="$1" alt
	shift
	alt="$(__nc_min "$nome")"
	alt="${alt%.exe}"; alt="${alt%.com}"; alt="${alt%.bat}"; alt="${alt%.cmd}"; alt="${alt%.msc}"
	if [ "$alt" != "$nome" ]; then
		if [ -n "${BASH_ALIASES[$alt]+x}" ]; then eval "${BASH_ALIASES[$alt]} \"\$@\""; return; fi
		if declare -F "$alt" >/dev/null || builtin type -P "$alt" >/dev/null; then "$alt" "$@"; return; fi
	fi
	case "$nome" in
		*.exe) if __nc_c wine && [ -f "$nome" ]; then wine "$nome" "$@"; return; fi ;;
	esac
	if declare -F __nc_cnf_originale >/dev/null; then __nc_cnf_originale "$nome" "$@"; return; fi
	echo "«$nome»: comando non trovato. Scrivi «comandi» per vedere quelli degli altri sistemi operativi che puoi usare." >&2
	return 127
}

# ══ Elenco ════════════════════════════════════════════════════════════════════
# «comandi» = tutto; «comandi linux», «comandi prompt», «comandi unix» = solo una parte
__nc_linux() {
	cat <<'FINE'
 LINUX (i comandi di questo sistema)
 File e cartelle
   ls -lh             elenco con dimensioni        ls -A        anche i file nascosti
   cd CARTELLA        entra   (cd .. sali, cd ~ casa, cd - torna dov'eri)
   pwd                dove sono                    tree         albero delle cartelle
   mkdir -p A/B       crea cartelle                touch FILE   crea un file vuoto
   cp -r A B          copia                        mv A B       sposta o rinomina
   rm FILE            elimina (rm -r CARTELLA)     ln -s A B    collegamento
   cat FILE           mostra                       less FILE    sfoglia (q per uscire)
   head / tail -f     inizio / fine (e segui)      nano FILE    modifica nel terminale
   find . -name '*.pdf'   cerca file              grep -ri testo .   cerca dentro i file
   du -sh *           quanto occupano              df -h        spazio sui dischi
   chmod +x FILE      rendi eseguibile             chown utente FILE   cambia proprietario
   tar -xf A.tar.gz   estrai (tar -czf A.tar.gz CARTELLA per comprimere)   unzip A.zip
 Programmi
   sudo apt update && sudo apt upgrade     aggiorna tutto
   sudo apt install NOME / remove NOME     installa / togli     apt search PAROLA
   flatpak install flathub ID              app dallo Store      xdg-open FILE   apri con l'app giusta
 Sistema
   top / htop         processi                     ps aux       elenco processi
   kill PID / pkill NOME   chiudi un programma     free -h      memoria
   uname -a           kernel                       lsblk        dischi e partizioni
   lsusb / lspci      dispositivi collegati        sensors      temperature
   systemctl status SERVIZIO   (start, stop, restart, enable)   journalctl -b -p err   errori
   sudo reboot / poweroff      riavvia / spegni    history      comandi già scritti
 Rete
   ip a               indirizzi                    nmcli dev wifi   reti Wi-Fi
   ping SITO          prova la rete                ss -tunap    connessioni aperte
   curl -O URL        scarica un file              ssh utente@PC   entra in un altro computer
   scp FILE utente@PC:   copia su un altro computer
 Trucchi: Tab completa i nomi · ↑ ripete l'ultimo comando · Ctrl+C ferma · Ctrl+R cerca
          comando --help o man comando spiegano ogni comando
FINE
}
__nc_windows() {
	cat <<'FINE'
 PROMPT DEI COMANDI (altri sistemi)      LINUX equivalente
 dir  dir /a  dir /s                     ls -lh   ls -A   ls -R
 cd..  cd  md  rd /s                     cd ..    cd      mkdir   rm -r (nel Cestino)
 copy  xcopy  robocopy /MIR              cp       cp -r   rsync -a --delete
 move  ren  del  erase                   mv       mv      (nel Cestino, recuperabile)
 type  more  cls  findstr /i             cat      more    clear   grep -i
 fc  comp  tree  where  attrib  mklink   diff     cmp     tree    which   chmod   ln -s
 ipconfig [/all /renew /flushdns]        ip address, nmcli, resolvectl
 ping  tracert  nslookup  netstat  getmac
 tasklist  taskkill /IM nome /F          ps        pkill
 systeminfo  ver  winver  hostname  whoami
 shutdown /s /r /t 60 /a                 shutdown -h / -r / -c
 start FILE  explorer  notepad  calc  control  taskmgr  diskmgmt
 winget install|search|upgrade           apt (c'è anche lo Store)
 NOMI MAIUSCOLI e .exe vanno bene: DIR, Cls, notepad.exe; i programmi .exe partono con Wine

 SHELL A OGGETTI (altri sistemi)
 Get-ChildItem  Set-Location  Get-Content  Copy-Item  Move-Item  Remove-Item
 Rename-Item  New-Item -ItemType Directory  Get-Process  Stop-Process -Name
 Clear-Host  Test-Connection  Get-NetIPAddress  Invoke-WebRequest  Select-String
 Restart-Computer  Stop-Computer  Get-Date  Get-Help  Get-ComputerInfo
FINE
}
__nc_mac() {
	cat <<'FINE'
 TERMINALE UNIX (altri sistemi)
 open FILE   open -a Firefox   open -R FILE   pbcopy   pbpaste   say "ciao"
 sw_vers  system_profiler  diskutil list|info|eject  caffeinate  ditto  mdfind
 softwareupdate -l|-ia   brew install|search|upgrade   networksetup   ifconfig
 afplay  screencapture  pmset sleepnow  launchctl  dscacheutil -flushcache  md5
FINE
}
comandi() {
	case "$(__nc_min "${1:-tutti}")" in
		linux) __nc_linux ;;
		prompt|windows|win|powershell|oggetti) __nc_windows ;;
		unix|mac|macos) __nc_mac ;;
		*)
			echo "Nel Terminale funzionano i comandi di Linux e anche quelli che conosci da altri sistemi operativi."
			echo "Solo una parte:  comandi linux  ·  comandi prompt  ·  comandi unix"
			echo
			__nc_linux; echo; __nc_windows; echo; __nc_mac ;;
	esac
}
alias aiuto-comandi='comandi' aiuto='comandi' help.exe='comandi'

# Al primo Terminale aperto, una riga per far sapere che esistono
if [ ! -e "${XDG_CONFIG_HOME:-$HOME/.config}/.comandi-visti" ] && [ -d "${XDG_CONFIG_HOME:-$HOME/.config}" ]; then
	printf '\033[2mCi sono i comandi di Linux e anche quelli di altri sistemi operativi (dir, cls, ipconfig, open, pbcopy…). Scrivi «comandi» per l’elenco (o «comandi linux»).\033[0m\n'
	: > "${XDG_CONFIG_HOME:-$HOME/.config}/.comandi-visti" 2>/dev/null
fi
