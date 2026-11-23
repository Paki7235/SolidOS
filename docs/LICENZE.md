# Licenze dei componenti

Codice SolidOS: **GPL-3.0-or-later** (compatibile con RQuickShare, OpenDrop, OWL, Calamares).
Grafica originale (sfondi, logo, tema): **CC BY-SA 4.0**.
Lo stato «da verificare» va confermato sul repository ufficiale prima dell'integrazione;
`scripts/verifica-licenze.sh` (Fase 1) estrae i file `copyright` di Debian per ogni pacchetto della ISO.

| Componente | Uso | Licenza | Stato |
|---|---|---|---|
| live-build | build ISO | GPL-3.0+ | ok |
| Calamares | installer | GPL-3.0+ | ok |
| labwc | compositor | GPL-2.0-only | ok (processo separato) |
| wlroots | libreria compositor | MIT | ok |
| Qt 6 | toolkit | LGPL-3.0 | ok (collegamento dinamico) |
| layer-shell-qt + modulo QML | finestre della shell (Wayland) | LGPL-3.0+ | ok |
| greetd | login | GPL-3.0 | ok |
| swaylock | blocco schermo | MIT | ok |
| pcmanfm-qt / libfm-qt | file manager | GPL-2.0+ / LGPL-2.1+ | ok |
| qterminal, lxqt-archiver, lxqt-policykit | app | GPL-2.0+ / LGPL-2.1+ | ok |
| FeatherPad | editor | GPL-3.0+ | ok |
| qimgv | immagini | GPL-3.0 | da verificare |
| qpdfview | PDF | GPL-2.0+ | ok |
| qalculate-qt | calcolatrice | GPL-2.0+ | ok |
| VLC | multimedia | GPL-2.0+ (libVLC LGPL-2.1+) | ok |
| LibreOffice | office | MPL-2.0 | ok |
| Firefox ESR | browser | MPL-2.0 | ok (marchio Mozilla: distribuito invariato come fa Debian) |
| FFmpeg, GStreamer | codec | LGPL/GPL | ok — nota: brevetti su alcuni codec in alcuni Paesi |
| kimageformats, libheif, libraw | immagini | LGPL / LGPL / LGPL-2.1 o CDDL | ok |
| 7zip | archivi | LGPL-2.1+ (+ unRAR restriction) | ok |
| unrar | archivi RAR | proprietaria freeware (non-free) | opzionale, segnalata |
| snapper | snapshot | GPL-2.0-only | ok |
| grub-btrfs | — | non usato (assente in Debian 13): script proprio | — |
| GRUB, Plymouth | boot | GPL-3.0+ / GPL-2.0+ | ok |
| NetworkManager, BlueZ, firewalld | sistema | GPL-2.0+ | ok |
| PipeWire / WirePlumber | audio | MIT | ok |
| Flatpak | app | LGPL-2.1+ | ok |
| distrobox / podman | .rpm in contenitore | GPL-3.0 / Apache-2.0 | ok |
| alien | conversione .rpm | GPL-2.0+ | ok |
| Wine | .exe/.msi | LGPL-2.1+ | ok |
| plocate | ricerca file | GPL-2.0+ | ok |
| restic | backup | BSD-2-Clause | ok |
| Quick Share (protocollo) | Condivisione Vicina | implementazione propria in Python, basata sulla documentazione pubblica di NearDrop e RQuickShare (nessun codice copiato) | ok |
| LocalSend (protocollo v2) | Condivisione Vicina | implementazione propria della specifica pubblica | ok |
| AirDrop (protocollo) | Condivisione Vicina | implementazione propria ispirata a OpenDrop (GPL-3.0, nessun codice copiato) | ok |
| **OWL** (seemoo-lab) | AWDL per AirDrop | GPL-3.0, compilato dai sorgenti durante la build | licenza copiata in /usr/share/doc/owl |
| PyQt6 | interfacce | GPL-3.0 | ok (compatibile con GPL-3.0-or-later) |
| python3-dbus, dbus-next, aiohttp, zeroconf, qrcode, cryptography, psutil, libarchive-c | componenti | MIT / Apache-2.0 / BSD / LGPL | ok |
| greetd, cage, swaylock, swayidle | accesso e blocco | GPL-3.0 / MIT | ok |
| memtest86+ | Salvataggio | GPL-2.0 | ok |
| chntpw | Salvataggio | GPL-2.0 / LGPL-2.1 | ok |
| ddrescue, partclone, smartmontools | Salvataggio | GPL-3.0+ / GPL-2.0 / GPL-2.0+ | ok |
| dislocker | BitLocker | GPL-2.0 | ok |
| apfs-fuse | — | non incluso (assente in Debian 13): APFS non supportato in questa versione | — |
| ClamAV (opzionale) | scansione | GPL-2.0 | ok |
| Inter, Noto | font | OFL-1.1 | ok |
| Papirus | icone | GPL-3.0 | ok |
| Bibata | cursori | GPL-3.0 | ok |

**Marchi:** «AirDrop», «Quick Share», «Windows», «iPhone» sono citati solo per indicare compatibilità.

**Simboli a linea** (`src/dati/icone/linea`, gli stessi di SolidOS Mobile, generati da `scripts/genera-icone-linea.py` del telefono): in parte ricavati da Lucide (licenza ISC, © Lucide Contributors), in parte disegnati per SolidOS.
