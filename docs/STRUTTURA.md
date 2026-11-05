# Struttura del repository

```
SolidOS/
├── README.md                     Presentazione, requisiti, come compilare e testare
├── LICENSE                       GPL-3.0-or-later (codice SolidOS)
├── build.sh                      Build riproducibile della ISO (live-build in contenitore Debian)
├── test-vm.sh                    Avvio in QEMU: --bios | --uefi | --salvataggio | --persistente
│
├── branding/
│   ├── branding.conf             ★ UNICA fonte di verità (OS_NAME, colori, font, lingua…)
│   ├── testi/                    Testi visibili generati in build: it.conf (predefinito), en.conf
│   └── grafica/                  Logo, sfondo, menu di avvio in SVG con segnaposto (*.svg.in)
│
├── live-build/                   Configurazione live-build; ogni file *.in è un modello del branding
│   ├── auto/                     config · build · clean
│   ├── pacchetti/                Elenchi pacchetti (prefisso ? = facoltativo), verificati in build
│   └── config/
│       ├── package-lists/        desktop.list.chroot, codec.list.chroot, salvataggio.list.chroot…
│       ├── includes.chroot/      file copiati nel sistema (etc/, usr/share/solidos/…)
│       ├── avvio/                modelli dei menu GRUB (UEFI) e ISOLINUX (BIOS)
│       ├── hooks/normal/         hook chroot (sistema) e binari (menu di avvio)
│       └── packages.chroot/      .deb SolidOS compilati localmente
│
├── src/                          Componenti del sistema (Python + QML), installati dalla build
│   ├── app.tsv                   Registro: comandi /usr/bin/<id>-* e voci di menu
│   ├── nucleo/                   Pacchetto Python (nome interno neutro)
│   │   ├── shell/  greeter/  impostazioni/  store/  installa/  apricon/
│   │   ├── lineadeltempo/  condivisione/(backend: qr, localsend, quickshare, airdrop, ble)
│   │   ├── spazi/  barra/  salvataggio/  migrazione/  chiavetta/  benvenuto/  privacy/
│   │   ├── apps/ (cattura, monitor, guida, dischi, backup)   hw/ (rete, bluetooth, audio, schermo, energia)
│   │   └── branding.py  i18n.py  ponte.py  qmlapp.py  sistema.py  …
│   ├── qml/                      SolidUI (componenti) + una cartella per app
│   ├── libexec/                  helper privilegiato e script di sistema
│   └── dati/                     guida, azioni della Barra Unica, Spazi, vetrina dello store, strumento Windows
├── packaging/debian/             Regole di pacchettizzazione .deb per ogni componente
├── dbus/                         Interfacce XML org.<OS_ID>.*
├── i18n/                         Traduzioni (.ts Qt, .po gettext) — it predefinito, en
├── scripts/                      genera-branding.sh, verifica-licenze.sh, misura-ram.sh…
├── tests/
│   ├── unita/  integrazione/     Test automatici
│   ├── vm/                       Test di avvio e screenshot in QEMU
│   └── hardware/                 Procedure e risultati su hardware reale
└── docs/
    ├── ARCHITETTURA.md  CONDIVISIONE-VICINA.md  ROADMAP.md  LICENZE.md  STRUTTURA.md
    └── guida-utente/             Fonte dei testi dell'app Guida
```

Nota: la cartella esistente `app di sistema/telefono/` (app React Native «Telefono») non fa parte del sistema desktop;
proposta di spostarla fuori dal repository o in `archivio/` alla Fase 1.
