# Stato del progetto

Aggiornato: 5 novembre 2026.

## Cosa è stato scritto (Fasi 1-10)

| Fase | Contenuto | Dove |
|---|---|---|
| 1 | ISO live, branding unico, menu di avvio BIOS/UEFI, Plymouth, build in contenitore, QEMU | `build.sh`, `test-vm.sh`, `branding/`, `live-build/` |
| 2 | Shell (notifiche, centro di controllo, OSD, montaggio automatico), schermata di accesso, blocco schermo, Cattura, Monitor, Guida, Dischi, Backup | `src/nucleo/shell`, `greeter`, `apps/` |
| 3 | Impostazioni con 24 pannelli, ricerca globale e interna | `src/nucleo/impostazioni` |
| 4 | Montaggio NTFS/exFAT/HFS+…, codec e formati, «Installa con…», store, «Apri con…» | `shell/automount.py`, `installa/`, `store/`, `apricon/` |
| 5 | Calamares su Btrfs, snapper, «Torna a ieri», aggiornamenti sicuri, Linea del Tempo | `etc/calamares`, `etc/grub.d`, `lineadeltempo/` |
| 6 | Condivisione Vicina: QR, LocalSend, Quick Share, AirDrop (beta), BLE, firewall | `src/nucleo/condivisione` |
| 7 | Spazi di vita, Barra Unica con 43 azioni | `spazi/`, `barra/`, `dati/azioni` |
| 8 | Modalità Salvataggio, Migrazione dal computer di prima, chiavetta persistente | `salvataggio/`, `migrazione/`, `chiavetta/` |
| 9 | Benvenuto, registro privacy, profilo «PC vecchio» | `benvenuto/`, `privacy/`, `libexec/profilo-prestazioni` |
| 10 | Guida offline, controlli statici, zoom, documentazione | `dati/guida`, `scripts/controlla.sh` |

## Cosa è stato verificato

- `scripts/controlla.sh`: sintassi di tutti i file Python e shell, generazione dell'albero di build
  con il branding, nessun segnaposto rimasto, XML/TOML/JSON validi, coerenza tra registro delle app,
  moduli e file QML.
- Cambiando `OS_NAME` non resta traccia del vecchio nome nell'albero generato.
- Motore della Barra Unica provato sulle frasi d'esempio; codifica protobuf provata in andata e ritorno.
- Nomi dei pacchetti verificati sull'archivio Debian 13.

## Cosa NON è ancora stato verificato

Nulla è stato eseguito su Debian né in una macchina virtuale: **la ISO non è ancora stata compilata**.
Aree a rischio, in ordine:

1. **Build live-build** (opzioni, hook, compilazione di OWL): primo test obbligatorio.
2. **QML**: errori di binding si vedono solo all'esecuzione (`~/.local/state/<id>/shell.log`).
3. **Quick Share e AirDrop**: protocolli scritti dalla documentazione pubblica senza prove con telefoni
   reali. Servono i test su hardware della Fase 1b / Fase 6.
4. **Calamares**: layout Btrfs, rimozione dei pacchetti live, Secure Boot.
5. **lxqt-panel su labwc**: barra delle finestre sotto Wayland.
6. **RAM a riposo**: da misurare con `<id>-misura-ram` (obiettivo < 500 MB).

## Come proseguire

1. Compilare la ISO (`./build.sh` con Docker/Podman, oppure GitHub Actions).
2. `./test-vm.sh` e `./test-vm.sh --uefi`, poi la lista «Cosa controllare» del README.
3. Installazione in QEMU con `./test-vm.sh --uefi --disco`.
4. Prove su un PC reale con due telefoni di sistemi diversi (con chiavetta Wi-Fi compatibile).
