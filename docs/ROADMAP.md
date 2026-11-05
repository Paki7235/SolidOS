# Roadmap

Ogni fase termina con: riepilogo, istruzioni di test, attesa della conferma. File sempre completi.

## Ambiente di sviluppo (importante: il Mac di sviluppo è Apple Silicon)

live-build deve girare su Debian e la ISO è x86_64. Sul Mac (arm64) le opzioni sono:

| Uso | Soluzione proposta |
|---|---|
| Build della ISO | **VM Debian 13 arm64** (UTM, OrbStack o Lima) con `qemu-user-static` per costruire il chroot amd64 (lento: ~1–2 h la prima volta, poi cache) **oppure** GitHub Actions su runner x86_64 (~20–30 min, gratuito per repo pubblici) |
| Test in QEMU | `qemu-system-x86_64` via Homebrew: emulazione TCG, funziona ma il desktop è lento → buono per verificare avvio, BIOS/UEFI e RAM, non per giudicare la fluidità |
| Test realistici | un **PC x86_64 vecchio** (anche 2–4 GB RAM) avviato da chiavetta: indispensabile da Fase 2 in poi e per Condivisione Vicina |

`build.sh` rileverà automaticamente l'ambiente e userà un contenitore Debian 13 con versioni bloccate
(`SOURCE_DATE_EPOCH`, snapshot.debian.org) per la riproducibilità.

---

## Fase 1 — ISO live minima con branding
- `branding/solidos.conf` + generatore modelli; `build.sh`, `test-vm.sh` (BIOS e UEFI, OVMF).
- live-build trixie amd64: kernel, firmware, zram, NetworkManager, PipeWire, labwc + `lxqt-panel` provvisorio,
  pcmanfm-qt, qterminal, Firefox ESR; locale e tastiera italiani.
- Branding: GRUB (BIOS+UEFI), Plymouth, sfondo, os-release, hostname, utente live.
- Voci di boot già presenti (anche se ancora segnaposto): «Prova SolidOS», «Modalità Salvataggio», «Modalità sicura grafica».
- **Test:** la ISO si avvia in QEMU BIOS e UEFI fino al desktop; `cat /etc/os-release` mostra SolidOS;
  cambiando OS_NAME e ricompilando cambia tutto. Prima misura di RAM.

## Fase 1b — Prototipo AirDrop su hardware reale (verifica di fattibilità)
- Su un PC x86_64 con Debian 13 / ISO di Fase 1: OWL + OpenDrop + annuncio BLE di prova, con iPhone aggiornato
  su «Tutti per 10 minuti» e almeno due chiavette Wi-Fi USB diverse.
- Risultato: rapporto `tests/hardware/airdrop-prototipo.md` con cosa funziona (scoperta, iPhone→PC, PC→iPhone,
  velocità, stabilità) e prima lista di chipset certificati. Nessuna interfaccia grafica.
- Scopo: scoprire i problemi di AirDrop all'inizio, non alla Fase 6.

## Fase 2 — Ambiente completo e app di base
- SolidUI (libreria QML), solid-shell (pannello, dock, menu app, notifiche, centro di controllo rapido, OSD, tray).
- greetd + solid-greeter, gtklock con tema, agente polkit, scorciatoie di labwc.
- App di base terze configurate + app proprie Cattura, Monitor, Guida (base).
- **Test:** login, blocco, notifiche di prova (`notify-send`), Wi-Fi/volume/luminosità dal centro di controllo, tray.

## Fase 3 — Impostazioni
- Tutti i 26 pannelli richiesti, ricerca interna per pannello e ricerca globale; backend D-Bus
  (NetworkManager, BlueZ, PipeWire, UDisks2, CUPS, firewalld, logind, accountsservice, timedated, localed…).
- Pannelli di funzioni future (Spazi, Linea del Tempo, Condivisione Vicina) presenti con stato «in arrivo».
- **Test:** checklist per pannello in `tests/vm/impostazioni.md`.

## Fase 4 — File system, codec, formati, installazioni universali
- Regole UDisks2, ntfs3, apfs-fuse, hfsplus ro, dislocker; codec e formati; «Apri con…» di riserva.
- «Installa con SolidOS» e store «SolidOS App» (apt + Flathub; distrobox, AppImage, Wine).
- **Test:** cartella `tests/campioni/` con un file per formato; immagini disco di prova per ogni FS; installazione
  di un .deb, .rpm, .AppImage, Flatpak, .exe e .msi di esempio.

## Fase 5 — Installer, snapshot, aggiornamenti, Linea del Tempo
- Calamares brandizzato (BIOS/UEFI, Btrfs con subvolumi, LUKS2 opzionale, Secure Boot).
- snapper + hook apt, grub-btrfs + voce «Torna a ieri», solid-aggiornamenti, app Linea del Tempo.
- **Test:** installazione in QEMU BIOS e UEFI; rompere volontariamente il sistema → «Torna a ieri» dal GRUB;
  ripristinare una versione di un file modificato.

## Fase 6 — Condivisione Vicina (ordine: QR → LocalSend → Quick Share → AirDrop beta)
- Demone, D-Bus, selettore «Condividi», popup ricezione, impostazioni, registro.
- Ogni backend è una sotto-consegna con test propri; AirDrop con rilevamento hardware e messaggi.
- **Test:** QEMU per QR/LocalSend; matrice su hardware reale (vedi `CONDIVISIONE-VICINA.md` §9).

## Fase 7 — Spazi di vita e Barra Unica
- solidd, file TOML degli Spazi, cambio istantaneo, selettore nel pannello; Barra Unica con 40+ azioni iniziali
  in italiano (Wi-Fi, Bluetooth, volume, converti in PDF, installa X, invia al telefono, Spazio X, torna indietro…).

## Fase 8 — Modalità Salvataggio, migrazione da Windows, USB persistente
- Sessione kiosk Salvataggio, Migrazione (con strumento per Windows), «Crea chiavetta SolidOS».
- **Test:** immagine disco Windows di prova in QEMU (NTFS, ibernazione, BitLocker con chiave).

## Fase 9 — Primo avvio, Pannello privacy, profilo PC vecchio
- Benvenuto (lingua, Wi-Fi, account, tema, importazione Windows, profilo prestazioni, Condivisione Vicina).
- solid-privacy: rete per app (contatori nftables per cgroup delle app), microfono/camera (PipeWire + fanotify su
  `/dev/video*`), file (accessi tramite portali e file recenti — il monitoraggio totale costerebbe troppa RAM/CPU:
  limite dichiarato), trasferimenti.
- Profilo PC vecchio automatico.

## Fase 10 — Ottimizzazione e rifinitura
- Misure RAM prima/dopo su QEMU (1, 2, 4 GB) e su PC reale; tabella in `docs/misure-ram.md`.
- Blocco schermo nativo, animazioni, suoni, icone, coerenza grafica, accessibilità (Orca, contrasto, ingrandimento).

---

## Rischi principali

| Rischio | Impatto | Mitigazione |
|---|---|---|
| AirDrop non funziona con iOS recenti o su molte schede | Funzione primaria compromessa | Prototipo anticipato (Fase 1b), fork mantenuti, annuncio BLE proprio, chiavette certificate, test a ogni iOS; LocalSend/QR come ripiego |
| Google cambia il protocollo Quick Share | Ricezione da Android interrotta | rqs_lib è attivamente seguito; QR/LocalSend come ripiego |
| solid-shell QML pesa più del previsto | Budget 500 MB | renderer software, caricamento pigro dei componenti, misure dalla Fase 2 |
| GPU molto vecchie senza KMS valido | Schermo nero | sessione pixman automatica + voce «Modalità sicura grafica» |
| Build lenta su Mac arm64 | Cicli lenti | CI x86_64 + cache apt |
| Scala del progetto | Tempi | ogni fase produce una ISO utilizzabile; le funzioni distintive sono indipendenti |
