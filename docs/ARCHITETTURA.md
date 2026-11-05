# SolidOS — Architettura (Fase 0)

> «Il sistema che non si rompe, non rallenta e ricorda tutto.»

Questo documento fissa le scelte tecniche. Ogni scelta è giustificata rispetto ai tre pilastri:
**non si rompe** (snapshot, aggiornamenti atomici, ripristino), **non rallenta** (RAM < 500 MB a riposo,
avvio pigro dei servizi), **ricorda tutto** (Linea del Tempo, registro privacy, Spazi).

---

## 1. Base del sistema: Debian 13 "trixie" — confermata

| Criterio | Debian 13 | Fedora | openSUSE Leap/TW | Ubuntu LTS |
|---|---|---|---|---|
| Ciclo di vita | ~5 anni (3 + LTS) | 13 mesi | Leap lungo / TW rolling | 5 anni |
| Strumento ISO live | live-build (maturo) | lorax/kiwi | kiwi | livecd-rootfs (complesso) |
| Btrfs + snapshot | snapper/grub-btrfs pacchettizzati, da configurare | default Btrfs, niente snapper | **migliore integrazione nativa** | limitato |
| Codec | ffmpeg completo in main da trixie | servono repo esterni | servono repo esterni (Packman) | restricted-extras |
| Secure Boot | shim + kernel firmati Debian | sì | sì | sì |
| Hardware vecchio | i686 abbandonato, x86_64 ottimo | x86_64-v2 minimo previsto | x86_64-v2 | x86_64 |
| Calamares | pacchettizzato | non standard | non standard | sì |

**Decisione:** Debian 13. openSUSE avrebbe snapper "gratis", ma Debian vince su durata del supporto, live-build,
Calamares, codec in main e compatibilità con i `.deb` (il formato più diffuso per le app di terze parti).
Il lavoro extra (layout Btrfs compatibile con `snapper rollback`, voci GRUB) è circoscritto alla Fase 5.

Note: kernel 6.12 LTS (driver `ntfs3`, buon supporto hardware fino al 2024); per hardware recentissimo si
offrirà opzionalmente il kernel di `trixie-backports`. Componenti `non-free-firmware` inclusi (Wi-Fi, GPU),
come fa l'ISO ufficiale Debian.

---

## 2. Desktop: labwc (Wayland) + shell propria in Qt/QML

### Opzioni valutate

| | **LXQt 2.x completo** | **labwc + shell SolidOS** (scelta) |
|---|---|---|
| RAM sessione | ~250–300 MB (X11) | ~180–260 MB stimati (compositor ~25 MB) |
| Coerenza grafica | pannello e dialoghi LXQt, stile anni 2000, difficile da trasformare | totale: pannello, dock, notifiche, centro di controllo sono nostri |
| Futuro | in transizione verso Wayland | Wayland nativo, protocollo `wlr-layer-shell`, `ext-session-lock` |
| Hardware vecchio | X11 funziona ovunque | serve KMS; senza GPU usabile si passa al renderer software **pixman** (automatico) |
| Lavoro | basso | alto (la shell è da scrivere) |

**Decisione:** **labwc** come compositor (stack Openbox, leggero, configurabile via XML, mantenuto, usato da
Raspberry Pi OS) e **solid-shell**, un unico processo QML che contiene pannello, dock, menu app, centro notifiche,
centro di controllo rapido, OSD volume/luminosità e tray.
Un solo processo = un solo motore QML in memoria invece di 6 processi separati.

**Ponte pragmatico:** in Fase 1 il desktop gira su labwc con `lxqt-panel` temporaneo, così l'ISO è avviabile
subito. In Fase 2 viene sostituito da solid-shell. Dei componenti LXQt teniamo solo ciò che è già buono
e coerente con Qt (file manager, terminale, agente polkit).

**Sessione di emergenza:** al boot, se il rendering GLES2 fallisce o la GPU è in lista nera, la sessione parte con
`WLR_RENDERER=pixman` e `QT_QUICK_BACKEND=software`. Le app X11 (Wine, vecchi programmi) passano da **Xwayland**,
avviato solo su richiesta.

---

## 3. Toolkit unico per le componenti custom: QML (Qt 6) + Python (PyQt6)

> **Revisione (Fasi 2-10).** La Fase 0 prevedeva Rust + CXX-Qt. Per sviluppare senza un
> compilatore sulla macchina di sviluppo (Mac Apple Silicon, nessuna installazione consentita)
> la logica è scritta in **Python 3.13 + PyQt6**, verificabile con controlli statici e
> modificabile direttamente sul sistema. Le interfacce D-Bus restano quelle previste: i servizi
> più sollecitati (shell, Condivisione Vicina) potranno essere portati in Rust senza cambiare le app.

- **Interfacce:** QML con la libreria **SolidUI** (`src/qml/SolidUI/`), tema da `branding.conf`
  e preferenze utente (chiaro/scuro, accento).
- **Logica:** pacchetto Python `nucleo` (`src/nucleo/`), nome interno neutro: il nome visibile
  e l'identificatore vengono letti a runtime da `/usr/share/nucleo/branding.env`.
- **Ponte UI↔logica:** un unico oggetto generico (`nucleo/ponte.py`) espone al QML i metodi
  di una classe Python (`ponte.chiama`, `ponte.avvia` in un thread, segnali `evento`).
- **D-Bus:** dbus-python nei processi Qt (integrato nel ciclo GLib di Qt), dbus-next asyncio
  nel servizio Condivisione Vicina.
- **Operazioni privilegiate:** un solo helper (`/usr/libexec/nucleo/helper`) con comandi
  validati, autorizzato da polkit; un'azione polkit separata, senza password per l'utente
  attivo, solo per attivare il collegamento AirDrop.
- **Costo:** ~40-60 MB per app Python+QML aperta; a riposo girano solo la shell, il servizio
  di condivisione e il registro privacy (misure reali previste a ISO compilata).

## 4. Mappa dei componenti

```
┌──────────────────────────────── Sessione utente (Wayland) ─────────────────────────────────┐
│ labwc (compositor)                                                                          │
│   ├─ solid-shell (QML)  pannello · dock · menu · notifiche · centro controllo · OSD · tray │
│   ├─ App SolidOS (QML): Impostazioni · SolidOS App (store) · Installa con SolidOS ·        │
│   │     Linea del Tempo · Barra Unica · Cattura · Dischi · Backup · Guida · Benvenuto ·    │
│   │     Apri con… · Condividi                                                             │
│   └─ App terze: pcmanfm-qt · qterminal · Firefox ESR · LibreOffice · VLC · …             │
│                                                                                             │
│ Demoni utente (systemd --user, avvio su richiesta via D-Bus activation)                    │
│   ├─ shell (Python+QML)      notifiche · centro controllo · OSD · Barra Unica · montaggio  │
│   ├─ condivisione (Python)   Condivisione Vicina: QR · LocalSend · Quick Share · AirDrop   │
│   └─ privacy (Python)        registro microfono · webcam · rete · file                     │
└───────────────────────────────────────────────┬─────────────────────────────────────────────┘
                                                │ D-Bus (sessione / sistema) + polkit
┌───────────────────────────────── Servizi di sistema ───────────────────────────────────────┐
│ NetworkManager · BlueZ · PipeWire+WirePlumber · UDisks2 · firewalld · CUPS · power-profiles│
│ snapper (D-Bus) · grub-btrfs · PackageKit/apt · flatpak · zram-generator · greetd          │
│ solid-sistema-helper (Rust, privilegiato, metodi minimi autorizzati da polkit)              │
│ solid-privacy (Rust): registro eventi rete/camera/microfono/file/trasferimenti (SQLite)    │
│ solid-aggiornamenti (Rust): scarica in background → snapshot → applica → verifica          │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Scelte per l'ambiente e le app di base

| Ruolo | Scelta | Perché |
|---|---|---|
| Login | **greetd** + **solid-greeter** (QML in labwc kiosk) | ~2 MB, greeter brandizzato con lo stesso SolidUI |
| Blocco schermo | **gtklock** con tema CSS SolidOS (Fase 2) → poi blocco nativo `ext-session-lock` in solid-shell (Fase 10) | il blocco schermo è critico per la sicurezza: prima uno collaudato |
| File manager | **pcmanfm-qt** + azioni SolidOS (Condividi, Torna indietro, Installa, Converti) | Qt, schede, anteprime, leggero |
| Terminale | qterminal | Qt, leggero |
| Editor | FeatherPad | Qt, leggero |
| Immagini | qimgv (o lximage-qt) + `kimageformats` (HEIC, AVIF, JXL, RAW) | Qt, veloce |
| Audio/video | VLC | codec completi, familiare a chi viene da Windows (usa Qt5: caricato solo quando aperto) |
| PDF | qpdfview | Qt, leggero |
| Office | LibreOffice con plugin `qt6` | compatibilità .docx/.xlsx/.pptx |
| Archivi | lxqt-archiver + 7zip (+ `unrar` non-free opzionale) | Qt |
| Calcolatrice | qalculate-qt | Qt |
| Browser | Firefox ESR | aggiornamenti di sicurezza Debian |
| Monitor di sistema | **solid-monitor** (QML) | coerenza; qps come ripiego |
| Cattura e registrazione | **Cattura** (QML) su `grim`, `slurp`, `wf-recorder` | nativo Wayland/wlroots |
| Dischi | **Dischi** (QML) su UDisks2 | GParted è GTK e richiede X11 |
| Backup | **Backup** (QML) su `restic` verso disco esterno/rete | cifrato, incrementale |
| Guida | **Guida** (QML) che mostra la documentazione Markdown locale | offline |
| Agente polkit | lxqt-policykit (tema SolidUI) | Qt |
| Firewall | firewalld | zone per Spazi, porte temporanee per Condivisione Vicina via D-Bus |

---

## 5. Branding centralizzato: un solo punto

`branding/branding.conf` è l'**unica** fonte di verità (testi visibili in `branding/testi/<lingua>.conf`). Estratto:

```ini
OS_NAME="SolidOS"          # ← cambiare SOLO questa riga per rinominare tutto
OS_ID=""                    # vuoto = derivato: minuscolo, senza spazi → "solidos"
OS_TAGLINE="Il sistema che non si rompe, non rallenta e ricorda tutto."
OS_VERSION="0.1"
ACCENTO="#2F6FEB"
SFONDO="sfondi/predefinito.jpg"
FONT_UI="Inter"
TEMA_ICONE="Papirus"
...
```

`scripts/genera-branding.sh` legge il file e genera da modelli `*.in` (sostituzione `@OS_NAME@`, `@OS_ID@`, …; `@@X@@` produce il testo letterale `@X@`; anche i nomi di file possono contenere segnaposto):
`/etc/os-release`, hostname predefinito, menu GRUB, tema Plymouth, greeter, branding Calamares, nomi delle app
(`@OS_NAME@ App`, «Installa con @OS_NAME@»), nomi D-Bus (`org.@OS_ID@.Condivisione1`), nome dispositivo annunciato
in Condivisione Vicina, testi della Guida. Il codice Rust/QML legge un modulo `comune/branding` generato in build,
mai stringhe scritte a mano.

---

## 6. Internazionalizzazione

- Stringhe sorgente in inglese nel codice (standard per i traduttori), **traduzione italiana completa e predefinita**
  (locale `it_IT.UTF-8` impostato nella ISO).
- QML: Qt Linguist (`.ts` in `i18n/`). Rust: `gettext` (`.po`). Script: `gettext.sh`.
- Un controllo in CI fallisce se una stringa visibile non ha la traduzione italiana.

---

## 7. Dischi, snapshot e Linea del Tempo (anteprima di Fase 5)

Layout Btrfs creato dall'installer:

```
@            → /                (snapshot di sistema, rollback)
@home        → /home            (snapshot orari per la Linea del Tempo dei file)
@snapshots   → /.snapshots
@var_log     → /var/log         (escluso dal rollback: i log sopravvivono)
@cache, @tmp → esclusi
@swap        → file di swap per ibernazione (opzionale; zram per l'uso normale)
```

- **snapper** crea snapshot: orari/giornalieri, prima di ogni operazione apt (hook), a richiesta.
- Uno script proprio in `/etc/grub.d` (al posto di grub-btrfs, assente in Debian 13) genera la voce
  **«Torna a ieri»** e il sottomenu dei punti di ripristino. Lo snapshot si avvia in sola lettura con
  uno strato scrivibile in memoria (overlayfs nell'initramfs); «Rendi permanente» sostituisce il
  subvolume `@` con lo snapshot (il sistema precedente resta 30 giorni come `@guasto-DATA`).
- **Linea del Tempo** (app QML): cursore temporale; per un file/cartella mostra le versioni presenti negli snapshot
  (deduplicate per contenuto), anteprima, «Ripristina» o «Ripristina come copia». Per il sistema: lista
  «com'era il PC» con le differenze di pacchetti tra snapshot.
- Cifratura opzionale LUKS2 sotto Btrfs.

---

## 8. Installazione universale delle app (anteprima di Fase 4)

«Installa con SolidOS» è l'applicazione predefinita per tutti i formati installabili:

| Formato | Backend | Isolamento |
|---|---|---|
| `.deb` | apt (via PackageKit); verifica architettura e dipendenze, avvisa se di terze parti | nessuno (pacchetto di sistema) — snapshot prima |
| `.rpm` | **distrobox** (contenitore Fedora condiviso, rootless con podman) con esportazione del lanciatore nel menu; `alien` solo come opzione avanzata | contenitore |
| `.AppImage` | copia in `~/Applicazioni`, permesso di esecuzione, voce di menu, icona; aggiornamento via zsync se presente | opzionale `bubblewrap` |
| Flatpak (`.flatpakref`, `.flatpak`) | flatpak + Flathub | sandbox Flatpak + portali |
| `.exe` / `.msi` | **Wine** (Debian) con un prefisso separato per app; Proton/umu per giochi se Steam presente | prefisso separato, unità `Z:` limitata alla home |
| `.dmg`, `.app`, `.pkg` | **non supportati**: messaggio chiaro + ricerca di un'alternativa nello store | — |

Lo store **SolidOS App** mostra un catalogo unico (AppStream di Debian + Flathub) con preferenza configurabile
(Flatpak per app desktop, apt per strumenti di sistema).

---

## 9. File system e formati (anteprima di Fase 4)

| FS | Supporto | Note |
|---|---|---|
| FAT32, exFAT | lettura/scrittura | kernel |
| NTFS | lettura/scrittura con `ntfs3` | se Windows è in ibernazione/avvio rapido → montaggio in sola lettura + spiegazione |
| ext2/3/4, Btrfs, XFS, F2FS | lettura/scrittura | kernel |
| HFS+ | **sola lettura** | modulo `hfsplus` |
| APFS | **sola lettura** | `apfs-fuse` (userspace: non rompe Secure Boot) — da pacchettizzare se non disponibile |
| BitLocker | sblocco con chiave di ripristino | `dislocker` / `cryptsetup` bitlk |

Montaggio automatico via UDisks2 con regole SolidOS (opzioni sicure: `nosuid,nodev`, uid utente per FAT/NTFS).
Formati: ffmpeg completo, GStreamer `plugins-good/bad/ugly/libav`, `kimageformats`, `libheif`, `libraw`, LibreOffice,
7zip. **Apri con…** di riserva: per estensioni sconosciute mostra tipo rilevato (libmagic), anteprima testo/esadecimale,
e suggerisce app dallo store tramite il tipo MIME.

---

## 10. Budget di memoria a riposo (obiettivo < 500 MB)

Stime da verificare con misure reali in Fase 10 (`scripts/misura-ram.sh`, sessione appena avviata, 2 minuti idle):

| Componente | MB stimati |
|---|---|
| Kernel, systemd, journald, udev, dbus | 70 |
| NetworkManager, wpa_supplicant | 20 |
| PipeWire + WirePlumber | 25 |
| BlueZ (se adattatore presente) | 5 |
| labwc | 25 |
| solid-shell (QML, un processo) | 90–120 |
| solidd | 10–15 |
| solid-condivisione (a riposo, backend caricati su richiesta) | 8–15 |
| polkit agent, greetd, varie | 25 |
| **Totale** | **≈ 280–340 MB** |

Tecniche: **zram** (zstd, 50% RAM; 100% nel profilo PC vecchio), D-Bus activation (i servizi partono solo se usati),
nessun indicizzatore permanente (Barra Unica usa `plocate` + file recenti), journald in RAM con limite,
niente CUPS/Avahi/ModemManager attivi finché non servono (socket activation).

**Profilo «PC vecchio»** (automatico con RAM ≤ 3 GB, modificabile): QML con renderer software, animazioni ridotte,
nessuna trasparenza, Firefox con meno processi, anteprime video disattivate, zram 100%, snapshot meno frequenti.

---

## 11. Sicurezza

- Firewall firewalld attivo, zona `home`/`public` per rete (cambiata dagli Spazi).
- Ogni operazione privilegiata passa da `solid-sistema-helper` con azioni polkit dedicate e minime.
- Condivisione Vicina: nessuna ricezione automatica, porte aperte solo mentre si è visibili (vedi documento dedicato).
- AppArmor attivo (default Debian), Flatpak con portali, Wine in prefissi separati.
- Secure Boot: si usano esclusivamente kernel e shim firmati Debian; nessun modulo DKMS nel sistema base.

---

## 12. Componenti distintivi in breve

- **Spazi di vita** (in `solidd`): ogni Spazio è un file TOML (`~/.config/solidos/spazi/lavoro.toml`) con app nel dock,
  regole notifiche, sfondo, cartelle in evidenza, profilo energetico (`power-profiles-daemon`), connessione/VPN
  NetworkManager e zona firewall. Il cambio applica le differenze via D-Bus: istantaneo, nessun riavvio di sessione.
- **Barra Unica** (`Super+Spazio`): ricerca in app (`.desktop`), impostazioni (indice generato dai pannelli), file
  (`plocate` + recenti), e **azioni** in linguaggio semplice. Le azioni sono file dichiarativi in
  `/usr/share/solidos/azioni/*.toml` con frasi d'esempio, sinonimi e parametri; un parser deterministico
  (normalizzazione, sinonimi, corrispondenza fuzzy) sceglie l'azione. Offline, senza AI, estendibile da terzi.
- **Modalità Salvataggio**: voce di boot della ISO → sessione kiosk con procedura guidata: recupero file
  (NTFS/BitLocker con chiave), test RAM (memtest86+, BIOS e UEFI), test disco (smartctl), clonazione (ddrescue/partclone),
  reset password **degli account locali di Windows** (chntpw; non funziona con account Microsoft online, lo diciamo),
  invio dei file recuperati al telefono con Condivisione Vicina (QR funziona senza configurazione).
- **Migrazione da Windows**: legge la partizione Windows (o un disco esterno) e importa Documenti, Immagini, Musica,
  Video, Desktop, sfondo, preferiti di Edge/Chrome/Firefox. **Reti Wi-Fi**: le password Windows sono cifrate con DPAPI;
  metodo affidabile = piccolo strumento da eseguire su Windows prima della migrazione (`netsh wlan export profile key=clear`),
  metodo offline sperimentale = decifratura dagli hive di registro.
- **USB persistente**: la stessa ISO ibrida; lo strumento «Crea chiavetta SolidOS» aggiunge una partizione
  `persistence` (ext4, `/ union`). La Linea del Tempo di sistema non è disponibile in modalità chiavetta (lo diciamo).
- **Pannello privacy**: vedi `CONDIVISIONE-VICINA.md` §8 e Fase 9 nella roadmap.
