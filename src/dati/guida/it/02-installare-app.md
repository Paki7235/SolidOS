# Installare programmi

## Dallo store

Apri **{{OS_NAME}} App** dal menu, cerca il programma e premi **Installa**. Le app arrivano da Debian e da Flathub; quelle di Flathub girano isolate dal resto del sistema.

## Da un file scaricato

Fai doppio clic sul file: si apre **Installa con {{OS_NAME}}**, che riconosce il formato e fa tutto da solo.

| Formato | Come viene installato |
|---|---|
| `.deb` | pacchetto di sistema (prima viene creato un punto di ripristino) |
| `.rpm` | in un contenitore Fedora separato |
| `.AppImage` | nella cartella *Applicazioni* della tua home, con voce nel menu |
| `.flatpakref`, `.flatpak` | in una sandbox Flatpak |
| `.exe`, `.msi` | con Wine, in un ambiente separato per ogni programma |

**Le app `.dmg` e `.pkg` di altri sistemi operativi non possono funzionare**: lo store ti propone un'alternativa.

## Dalla Barra Unica

Premi **Super + Spazio** e scrivi per esempio `installa vlc`.
