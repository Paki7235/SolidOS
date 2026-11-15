# SolidOS

**Il sistema che non si rompe, non rallenta e ricorda tutto.**

Sistema operativo desktop per PC x86_64 (anche vecchi) basato su Debian 13, distribuito come ISO avviabile
(live + installer, BIOS e UEFI), interamente in italiano.

## Stato

**Fasi 1-10 scritte, ISO non ancora compilata né provata.** Dettagli e rischi in [docs/STATO.md](docs/STATO.md).
Il nome del sistema si cambia in un solo punto: `OS_NAME` in [branding/branding.conf](branding/branding.conf).
Controlli statici: `./scripts/controlla.sh`.

Documenti: [Architettura](docs/ARCHITETTURA.md) · [Condivisione Vicina](docs/CONDIVISIONE-VICINA.md) ·
[Struttura](docs/STRUTTURA.md) · [Roadmap](docs/ROADMAP.md) · [Licenze](docs/LICENZE.md) · [Stato](docs/STATO.md)

## Creare la chiavetta di installazione (Windows, con Rufus)

1. Scarica la ISO **x86_64** dalle [Releases](https://github.com/Paki7235/SolidOS/releases) (un solo file `.iso`).
2. Apri **Rufus**, scegli la chiavetta e la ISO e premi *Avvia*. Se Rufus chiede la modalità,
   scegli **Scrivi in modalità immagine DD**.
3. Avvia il PC dalla chiavetta (F12, F11 o Esc all'accensione).
4. Parte direttamente **Installa SolidOS sul computer** e si apre l'installatore. Se lo schermo
   resta nero o la grafica non va, riavvia e scegli **Installa SolidOS (grafica sicura)**.

L'installatore prepara da solo i dischi: si sceglie solo dove installare (tutto il disco o accanto
a un altro sistema), le partizioni giuste (EFI o BIOS) le crea lui.

## Compilare la ISO

La build gira in un contenitore Debian 13 amd64, su qualsiasi sistema.

### macOS (anche Apple Silicon)

```bash
brew install colima docker qemu
```

```bash
colima start --cpu 4 --memory 8 --disk 60 --vm-type vz --vz-rosetta
```

```bash
./build.sh
```

Con Rosetta i programmi amd64 girano quasi a velocità nativa; la prima build scarica circa 1,5 GB
di pacchetti (poi restano nella cache del volume `solidos-build-cache`).

### Linux

Con Docker o Podman attivo: `./build.sh`. Su Debian 13 amd64 anche senza contenitore: `sudo ./build.sh --nativo`.

### GitHub Actions

Il workflow [.github/workflows/iso.yml](.github/workflows/iso.yml) compila la ISO su un runner x86_64
e la pubblica come artefatto (avvio manuale o a ogni push su `main`).

### Opzioni

| Comando | Effetto |
|---|---|
| `./build.sh --pulisci` | ricomincia da zero, svuotando anche la cache |
| `./build.sh --snapshot 20251101T000000Z` | pacchetti fissati a quella data di snapshot.debian.org (riproducibile) |
| `./build.sh --solo-albero` | genera solo `build/albero` per controllare il branding, senza compilare |

Risultato in `dist/`: `solidos-0.1-amd64.iso`, checksum `.sha256`, elenco pacchetti, registro della build
e `licenze-pacchetti.tsv`.

## Provare in QEMU

```bash
./test-vm.sh
```

```bash
./test-vm.sh --uefi
```

Altre opzioni: `--ram 1024` (simula un PC vecchio), `--cpu 4`, `--disco` (disco vuoto per l'installer), `--stampa`.
Su Mac Apple Silicon la VM è emulata: avvio in qualche minuto, desktop lento. Va bene per verificare avvio
e RAM; per la fluidità usa un PC reale (scrivi la ISO su chiavetta con `dd` o balenaEtcher).

## Provare in VirtualBox

1. Scarica dalla pagina *Releases* del repository tutte le parti `…iso.parte-00`, `…parte-01`, … e il file `.sha256`.
2. Ricomponi la ISO nella cartella dei download:

```bash
cat solidos-0.1-amd64.iso.parte-* > solidos-0.1-amd64.iso
```

```bash
shasum -a 256 solidos-0.1-amd64.iso
```

   Il valore deve coincidere con quello nel file `.sha256`.
3. In VirtualBox crea una nuova macchina: **Tipo** Linux, **Versione** Debian (64-bit), **RAM** 4096 MB (2048 per provare il profilo «PC vecchio»), **CPU** 2, **disco** 30 GB.
4. Impostazioni → **Schermo**: controller grafico **VMSVGA**, memoria video 128 MB, accelerazione 3D **spenta**.
5. Impostazioni → **Sistema**: «Abilita EFI» acceso per provare l'avvio UEFI, spento per il BIOS.
6. Impostazioni → **Archiviazione**: collega la ISO al lettore ottico, poi avvia.

In macchina virtuale la grafica usa automaticamente il rendering software. Quick Share e AirDrop
non sono provabili in VirtualBox (servono Wi-Fi e Bluetooth reali); il codice QR e LocalSend
funzionano se la rete della VM è in modalità **Scheda con bridge**.

> Su Mac con processore Apple (M1–M5) VirtualBox può avviare solo sistemi ARM: questa ISO x86_64
> va provata su un PC con processore Intel/AMD oppure con QEMU (`./test-vm.sh`, emulato e lento).

### Cosa controllare

1. Menu di avvio con sfondo e voci in italiano: *Prova SolidOS*, *grafica sicura*, *Modalità Salvataggio*,
   *Test della memoria*, *Avvia dal disco fisso*, *Spegni* (BIOS e UEFI).
2. Logo animato di Plymouth, poi desktop con sfondo, pannello in basso, menu con il logo.
3. Nel terminale: `cat /etc/os-release` mostra `NAME="SolidOS"`, `hostname` mostra `solidos`.
4. Scorciatoie: `Super+E` file, `Ctrl+Alt+T` terminale, `Stamp` cattura schermo, `Alt+Tab`, `Super+←/→`.
5. RAM a riposo: `solidos-misura-ram` (dopo 2 minuti scrive un rapporto Markdown nella home).
6. Rinomina: cambia `OS_NAME` in `branding/branding.conf`, `./build.sh --solo-albero`, e verifica con
   `grep -ri solidos build/albero` che non resti nulla del vecchio nome.

## Limiti dichiarati

- Le app macOS (`.dmg`, `.app`, `.pkg`) **non** sono supportate.
- AirDrop è **beta**: richiede una scheda Wi-Fi con modalità monitor e iniezione e l'iPhone su «Tutti per 10 minuti».
- La barra delle applicazioni è ancora `lxqt-panel` (tema proprio); notifiche, centro di controllo,
  OSD e Barra Unica sono della shell propria.
- APFS (dischi Mac recenti) non è supportato in questa versione; HFS+ in sola lettura.

## Licenza

Codice: GPL-3.0-or-later ([LICENSE](LICENSE)). Grafica originale: CC BY-SA 4.0.
