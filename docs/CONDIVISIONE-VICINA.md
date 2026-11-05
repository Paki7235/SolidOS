# Condivisione Vicina — progetto tecnico

Un unico servizio per mandare e ricevere file da **iPhone/iPad/Mac (AirDrop)**, **telefoni Android (Quick Share)**,
qualsiasi dispositivo con **LocalSend**, e **qualsiasi telefono con un browser (QR)**.
L'utente vede sempre la stessa interfaccia: «Condividi» → lista dei dispositivi vicini → tocco → fatto.
Il backend usato è un dettaglio interno, mostrato solo come piccola etichetta («via Quick Share»).

> Nei testi visibili i marchi si usano solo per indicare compatibilità: «Dispositivi Apple (AirDrop)»,
> «Telefoni Android (Quick Share)». AirDrop è un marchio Apple, Quick Share è un marchio Google/Samsung;
> SolidOS non è affiliato.

---

## 1. Aspettative realistiche (da leggere prima di tutto)

| Dispositivo | Inviare **dal** telefono **al** PC | Inviare **dal** PC **al** telefono | Stato |
|---|---|---|---|
| Android 6+ con Quick Share | Sì: il PC appare nel foglio «Condividi» di Android | Sì: il telefono deve avere Quick Share visibile («Tutti») | **Stabile** (obiettivo) |
| iPhone / iPad / Mac | Sì, con **AirDrop impostato su «Tutti per 10 minuti»** e una scheda Wi-Fi compatibile | Sì, stesse condizioni | **BETA → obiettivo: funzionante su hardware certificato** (vedi §7.1) |
| iPhone / Android / Windows / Mac con app LocalSend | Sì | Sì | Stabile |
| Qualsiasi telefono con browser | Sì (pagina web dal QR) | Sì (download dalla pagina) | Stabile, funziona sempre |

Limiti che **non** possono essere superati via software:
- **AirDrop «Solo contatti»** richiede certificati firmati da Apple legati a un Apple ID: impossibile per un PC Linux.
  Funziona solo la modalità **«Tutti per 10 minuti»** dell'iPhone.
- **AirDrop** viaggia su **AWDL**, un collegamento Wi-Fi proprietario Apple. Serve una scheda Wi-Fi in grado di
  andare in **modalità monitor con iniezione di pacchetti**. Le schede interne dei portatili spesso non ci riescono.
  Durante l'uso di AWDL la scheda non può restare collegata alla rete Wi-Fi normale: con una sola scheda, mentre
  AirDrop è attivo, internet via Wi-Fi si interrompe. **Soluzione consigliata: una chiavetta Wi-Fi USB dedicata**
  (lista di chipset verificati in `docs/hardware-condivisione.md`, creata in Fase 6).
- Le implementazioni open source di AirDrop (OpenDrop, OWL) sono progetti di ricerca, poco aggiornati;
  Apple può cambiare il protocollo con un aggiornamento iOS. Per questo AirDrop resta **BETA** e il sistema propone sempre
  l'alternativa: **LocalSend** (se installata sull'iPhone) o **QR** (sempre).
- **Quick Share** «Solo contatti» richiede l'account Google: il PC funziona in modalità «Tutti» / dispositivi vicini
  sulla stessa rete. Telefono e PC devono essere **sulla stessa rete Wi-Fi** (o sull'hotspot del PC);
  il Bluetooth LE serve per «svegliare» il telefono e far comparire il PC più in fretta.

---

## 2. Architettura

```
 App (pcmanfm-qt «Condividi», Barra Unica «invia al telefono», Salvataggio, qualsiasi app)
        │  D-Bus sessione: org.solidos.Condivisione1   (nome derivato da OS_ID)
        ▼
 ┌──────────────── solid-condivisione (Rust, servizio utente) ────────────────┐
 │  Gestore dispositivi (unisce le scoperte, deduplica, sceglie il backend)    │
 │  Gestore trasferimenti (coda, avanzamento, verifica tipo, registro)         │
 │  Politica di visibilità (Nessuno / Associati / Tutti per 10 minuti)         │
 │                                                                             │
 │  Backend (trait comune `Backend`: scopri, annuncia, invia, ricevi):         │
 │   ├─ qr          server HTTP axum temporaneo + pagina web                  │
 │   ├─ localsend   protocollo LocalSend v2 (HTTPS + multicast UDP)           │
 │   ├─ quickshare  basato su rqs_lib (core di RQuickShare): mDNS + UKEY2     │
 │   └─ airdrop     BETA: gestisce i processi OWL (AWDL) e OpenDrop           │
 └───────────────┬──────────────────────────────────────────┬──────────────────┘
                 │ D-Bus sistema + polkit                   │
                 ▼                                          ▼
   solid-sistema-helper: apre/chiude porte           solid-privacy: registro
   firewalld, crea interfaccia monitor per OWL        trasferimenti (SQLite)
```

- Il demone parte su richiesta (D-Bus activation) o all'avvio se la visibilità non è «Nessuno».
- I backend sono caricati solo quando servono: a riposo restano attivi solo gli annunci (mDNS/BLE) se si è visibili.
- **OWL** richiede privilegi (`CAP_NET_ADMIN`, `CAP_NET_RAW`): gira come servizio di sistema separato, avviato
  dall'helper solo quando AirDrop è attivo, con unità systemd blindata (`ProtectSystem=strict`, `PrivateTmp`, …).
- **OpenDrop** (Python) gira come processo figlio isolato, senza privilegi, che comunica tramite l'interfaccia `awdl0`.

### Interfaccia D-Bus (bozza)

```
org.solidos.Condivisione1
  Metodi:
    Dispositivi() → a(ssssa{sv})          id, nome, tipo(telefono/pc/tablet), backend, extra
    Invia(as file, s dispositivo) → s id_trasferimento
    InviaConQr(as file) → (s url, s png_qr, u scadenza)
    RiceviConQr() → (s url, s png_qr, u scadenza)
    Rispondi(s id_trasferimento, b accetta)
    Annulla(s id_trasferimento)
    ImpostaVisibilita(s modalita)          "nessuno" | "associati" | "tutti10"
    StatoBackend() → a{s(bs)}               disponibile?, motivo leggibile in italiano
  Segnali:
    DispositivoTrovato / DispositivoPerso
    RichiestaInArrivo(s id, s mittente, s backend, a(sst) file[nome,mime,dimensione], s anteprima)
    Avanzamento(s id, t byte, t totale)
    Completato(s id, as percorsi) / Fallito(s id, s motivo)
  Proprietà:
    Visibilita, CartellaRicevuti, ScadenzaVisibilita
```

Qualsiasi app (anche di terzi) può usarla; esiste anche il comando `solidos-condividi FILE…` che apre il selettore.

---

## 3. Selezione del backend

1. **Scoperta in parallelo** su tutti i backend disponibili; i dispositivi visti da più backend vengono uniti
   (stesso nome + stesso indirizzo IP/MAC dove possibile).
2. **Priorità predefinita** (come da specifica, modificabile in Impostazioni → Condivisione Vicina → Avanzate):
   Quick Share → AirDrop (beta) → LocalSend → QR.
3. **Ripiego automatico:** se il backend scelto fallisce durante la connessione, si riprova con il successivo
   disponibile per quel dispositivo, senza far ripetere nulla all'utente.
4. Se nessun dispositivo viene trovato, il pannello «Condividi» mostra sempre la scheda **«Usa il QR»**.

> Proposta: per un iPhone visibile sia via AirDrop (beta) sia via LocalSend, preferire LocalSend perché stabile.
> La lascio come opzione «Preferisci backend stabili» attiva di default — da confermare.

---

## 4. Backend QR (Fase 6, primo)

- Server HTTP `axum` temporaneo, porta casuale, in ascolto **solo** sull'IP dell'interfaccia LAN/hotspot scelta.
- URL nel QR: `http://192.168.x.y:PORTA/t/<token>` con token casuale 128 bit, **monouso**:
  al primo accesso viene scambiato con un cookie di sessione legato a quel telefono; altri accessi con lo stesso token
  vengono rifiutati.
- Il PC mostra anche un **codice di 4 cifre** che il telefono deve confermare sulla pagina se l'utente attiva
  «Verifica extra» (utile su reti Wi-Fi pubbliche).
- **Scadenza**: 10 minuti o alla chiusura della finestra; il server si spegne e la porta firewall si chiude.
- Solo rete locale: richieste da IP non privati (fuori RFC1918/link-local) rifiutate; porta aperta in firewalld
  solo sulla zona dell'interfaccia usata.
- **Senza Wi-Fi comune:** pulsante «Crea hotspot» → NetworkManager attiva un hotspot WPA2 con password casuale;
  il primo QR è quello standard `WIFI:T:WPA;S:…;P:…;;` (la fotocamera di iPhone e Android si collega da sola),
  il secondo è quello della pagina. Si verifica prima che la scheda supporti la modalità AP.
- Pagina web: HTML/JS minimale incluso nel demone (nessuna risorsa esterna), in italiano, caricamento con
  avanzamento, funziona con Safari iOS e Chrome Android. Il PC chiede comunque conferma prima di salvare.
- Limite: HTTP in chiaro dentro la LAN (un certificato autofirmato genererebbe un avviso spaventoso sul telefono).
  Con «Verifica extra» o hotspot dedicato il rischio è contenuto; documentato.

## 5. Backend LocalSend (Fase 6, secondo)

- Implementazione propria in Rust del **protocollo LocalSend v2** (specifica pubblica): annuncio multicast UDP
  `224.0.0.167:53317`, API HTTPS REST con certificato autogenerato e fingerprint.
- Modalità ricezione con conferma, PIN opzionale, invio a dispositivi LocalSend.
- Compatibile con le app ufficiali LocalSend per iOS, Android, Windows, macOS, Linux.

## 6. Backend Quick Share (Fase 6, terzo — obiettivo stabile)

- Basato su **rqs_lib**, il core Rust di RQuickShare (integrato come dipendenza, non come app).
- Ricezione: annuncio mDNS del servizio Quick Share sulla LAN; quando la visibilità è «Tutti per 10 minuti»,
  annuncio BLE tramite BlueZ per far comparire il PC sui telefoni vicini.
- Invio: scoperta dei telefoni Android visibili sulla stessa rete; handshake UKEY2, connessione cifrata, frame protobuf.
- Nome annunciato: «SolidOS di Mario» (derivato da OS_NAME e nome utente, modificabile).
- Test su almeno: un Pixel recente, un Samsung (One UI con Quick Share Samsung), un Android di fascia bassa
  (Xiaomi/Motorola), un Android vecchio (8–10).

## 7. Backend AirDrop (Fase 6, quarto — BETA)

**Componenti:** OWL (implementazione AWDL, crea `awdl0`) + OpenDrop (protocollo AirDrop su HTTPS sopra AWDL) +
annuncio **BLE** con BlueZ per «risvegliare» gli iPhone vicini (OpenDrop non lo implementa: va scritto da noi).

**Rilevamento automatico dei requisiti** (all'avvio del servizio e quando si collega una scheda USB):
1. Esiste un'interfaccia Wi-Fi che dichiara la modalità `monitor` (`iw phy … info`)?
2. Il driver è in una **lista di chipset verificati** per iniezione (es. `ath9k`, `ath9k_htc`, `mt76x2u`; la lista
   reale si costruisce con i test di Fase 6) oppure supera un test attivo di iniezione e canale (6/44/149)?
3. C'è un adattatore Bluetooth LE per l'annuncio?
4. Esiste una seconda scheda (così la rete normale resta attiva) o l'utente accetta la disconnessione temporanea?

Esito mostrato in Impostazioni → Condivisione Vicina:
- ✅ «Dispositivi Apple (AirDrop) — BETA: disponibile con la scheda *Alfa AWUS036ACM*».
- ⚠️ «Disponibile, ma mentre AirDrop è attivo il Wi-Fi verrà scollegato. Consigliata una chiavetta Wi-Fi USB.»
- ❌ «La tua scheda Wi-Fi (*Intel AX201*) non supporta i requisiti di AirDrop. Puoi comunque scambiare file con
  iPhone usando l'app gratuita LocalSend oppure il codice QR, senza installare nulla.» + pulsante «Mostra QR».

Il backend è disattivato per impostazione predefinita finché i requisiti non risultano soddisfatti; se attivo,
si accende solo quando l'utente apre «Condividi» o imposta «Tutti per 10 minuti» (risparmio energia).

### 7.1 Piano per rendere AirDrop davvero funzionante

AirDrop è un **obiettivo primario** del prodotto, non un extra. L'etichetta BETA resta finché la matrice di test
(§9) non passa su iOS attuale; l'obiettivo è toglierla per l'hardware certificato.

1. **Prototipo anticipato su hardware reale** (subito dopo la Fase 1, vedi ROADMAP «Fase 1b»): OWL + OpenDrop
   su Debian 13 con un iPhone aggiornato, per misurare cosa funziona oggi *prima* di costruirci sopra.
2. **Fork mantenuti da SolidOS** di OWL e OpenDrop (`src/condivisione/terzi/`), aggiornati a kernel 6.12,
   Python 3.13 e alle versioni iOS correnti; correzioni rimandate ai progetti originali.
3. **Annuncio BLE scritto da noi** (BlueZ `LEAdvertisingManager1`): è il pezzo che manca a OpenDrop ed è quello che
   fa «svegliare» l'iPhone e mostrare il PC nel foglio AirDrop. Senza di esso l'iPhone vede il PC solo a volte.
4. **Porting graduale in Rust** della parte protocollo di OpenDrop (HTTPS `/Discover`, `/Ask`, `/Upload`, archivio
   CPIO compresso) dentro il demone: meno processi, meno RAM, errori gestiti in italiano. OWL (C, livello radio) resta separato.
5. **Hardware certificato**: lista di chiavette Wi-Fi USB economiche testate da noi (chipset Atheros AR9271,
   MediaTek MT7612U e simili, da confermare con i test), indicata nella Guida e nel Benvenuto come «Kit AirDrop».
   Con una chiavetta dedicata il Wi-Fi normale resta collegato.
6. **Scheda interna**: supportata se supera il test automatico, con avviso che internet via Wi-Fi si interrompe
   durante il trasferimento (si riattiva da sola alla fine).
7. **Test di regressione a ogni versione iOS** (iPhone di prova dedicato) e ripiego automatico su LocalSend/QR
   se un aggiornamento Apple rompe qualcosa, così l'utente non resta mai bloccato.

Cosa resta impossibile anche con tutto questo: modalità «Solo contatti» (richiede certificati Apple) e AirDrop
su schede Wi-Fi che non permettono la modalità monitor.

---

## 8. Sicurezza e privacy (tutti i backend)

- **Nessuna ricezione automatica da sconosciuti.** Anche dai dispositivi associati la ricezione automatica è
  un'opzione che va attivata esplicitamente, per dispositivo.
- **Visibilità:** *Nessuno* (nessun annuncio, porte chiuse) · *Solo dispositivi associati* (annunci solo verso
  dispositivi già confermati; per QR/LocalSend significa PIN obbligatorio) · *Tutti per 10 minuti* (poi torna da sola
  alla modalità precedente, con conto alla rovescia nel centro di controllo).
- **Popup di ricezione:** nome del mittente, backend, elenco file con dimensione e tipo, anteprima (miniatura immagine,
  prime righe di testo), pulsanti **Accetta** / **Rifiuta**, barra di avanzamento, «Apri cartella» a fine trasferimento.
- **Controllo del tipo:** confronto tra estensione dichiarata e tipo reale (libmagic); avviso evidente per eseguibili,
  script, `.exe`, `.desktop`, archivi con percorsi pericolosi (`../`); i file ricevuti non sono mai eseguibili
  (`chmod -x`). Scansione antivirus **ClamAV opzionale** su richiesta (non attiva di default per la RAM).
- Nomi file ripuliti, nessuna sovrascrittura (suffisso «(1)»), limite di spazio libero verificato prima di accettare.
- **Registro** in `solid-privacy`: data, direzione, dispositivo, backend, nomi file, dimensione, esito.
  Visibile nel Pannello privacy, cancellabile, conservazione configurabile (predefinito 90 giorni).
- Cartella di destinazione: `~/Download/Ricevuti` (configurabile).

---

## 9. Test su hardware reale (dettagliati in Fase 6)

Materiale minimo:
- 1 PC x86_64 con SolidOS installato o da chiavetta, Wi-Fi + Bluetooth.
- 1 chiavetta Wi-Fi USB con chipset a supporto monitor/iniezione (per AirDrop).
- 1 iPhone con iOS recente, 1–2 telefoni Android (meglio uno Samsung e uno non Samsung).

Matrice di test (ogni casella: invio PC→telefono, telefono→PC, file piccolo, file 1 GB, 20 file insieme, annullamento,
rifiuto, rete Wi-Fi comune, hotspot del PC): QR × iPhone/Android, LocalSend × iPhone/Android/Windows,
Quick Share × Android, AirDrop × iPhone/Mac. Risultati registrati in `tests/hardware/risultati-condivisione.md`.

In QEMU si testano solo QR e LocalSend (rete in bridge); Quick Share e AirDrop richiedono hardware reale
(eventuale passthrough USB di adattatore Wi-Fi/Bluetooth su host Linux).
