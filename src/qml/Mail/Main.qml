// Mail: a sinistra le caselle (Tutte le entrate e, per ogni account, Entrata, Bozze, Inviata,
// Archivio, Indesiderata, Cestino e le altre cartelle) con i non letti; al centro i messaggi con
// mittente, oggetto, anteprima, data, pallino dei non letti, bandiera e graffetta; a destra il
// messaggio con i comandi (rispondi, rispondi a tutti, inoltra, archivia, indesiderata, elimina,
// bandiera, non letto, sposta). Le immagini remote restano bloccate finché non si chiede.
// «Scrivi» apre il pannello per un messaggio nuovo, con allegati, Cc e Ccn.
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Mail")
    width: 1240
    height: 780
    minimumWidth: 900
    minimumHeight: 560

    property var conti: []
    property var cartelle: ({})            // id account → [cartelle]
    property string conto: ""              // "" = tutte le entrate
    property string cartella: "INBOX"
    property string nomeCartella: I18n.t("Tutte le entrate")
    property var messaggi: []
    property var aperto: null              // messaggio letto ora
    property bool immagini: false
    property bool soloNonLetti: false
    property bool aggiornando: false
    property bool configurazione: false     // schermata per aggiungere un account
    property int attesa: 0
    readonly property var simboli: ({ entrata: "entrata", bozze: "documento", inviata: "invia", archivio: "archivio",
                                       indesiderata: "attenzione", cestino: "cestino", tutta: "busta" })
    readonly property var scelto: aperto ? { conto: aperto.conto, cartella: aperto.cartella, uid: aperto.uid } : null

    function ricaricaConti() {
        conti = ponte.chiama0("conti")
        var c = {}
        for (var i = 0; i < conti.length; i++) c[conti[i].id] = ponte.chiama("cartelle", [conti[i].id])
        cartelle = c
        if (conti.length === 0) configurazione = true
    }
    function ricaricaMessaggi() { messaggi = ponte.chiama("messaggi", [conto, cartella, cerca.text, soloNonLetti]) }
    function aggiorna() {
        if (aggiornando || conti.length === 0) return
        aggiornando = true
        ponte.avvia("aggiorna", [conto, cartella], "aggiorna")
    }
    function vai(idConto, nome, visibile) {
        conto = idConto; cartella = nome; nomeCartella = visibile
        aperto = null; immagini = false
        ricaricaMessaggi(); aggiorna()
    }
    function apri(m) {
        immagini = false
        attesa++
        ponte.avvia("apri", [m.conto, m.cartella, m.uid, false, !Tema.chiaro], "apri")
    }
    function azione(metodo, argomenti, chiudi) {
        var r = ponte.chiama(metodo, argomenti)
        if (r && r.messaggio) avviso.mostra(r.messaggio)
        if (chiudi && r && r.ok) {
            // passa al messaggio successivo, come si aspetta chi legge
            var i = messaggi.findIndex(function (m) { return aperto && m.uid === aperto.uid && m.conto === aperto.conto })
            ricaricaMessaggi()
            aperto = null
            if (i >= 0 && messaggi.length) apri(messaggi[Math.min(i, messaggi.length - 1)])
        } else ricaricaMessaggi()
        ricaricaConti()
    }
    function scrivi(bozza) { componi.mostra(bozza || { conto: conto || (conti.length ? conti[0].id : ""), a: "", cc: "", oggetto: "", testo: "", allegati: [] }) }
    function contoDi(id) { return conti.find(function (a) { return a.id === id }) || {} }

    Component.onCompleted: {
        ricaricaConti()
        if (conti.length) { ricaricaMessaggi(); aggiorna() }
        var m = ponte.chiama0("inizio")
        if (m.a !== undefined && conti.length) scrivi({ conto: conti[0].id, a: m.a, cc: m.cc, oggetto: m.oggetto, testo: m.testo, allegati: [] })
    }
    Timer { interval: 5 * 60 * 1000; repeat: true; running: finestra.conti.length > 0; onTriggered: finestra.aggiorna() }
    Shortcut { sequence: StandardKey.New; onActivated: finestra.scrivi() }
    Shortcut { sequence: "Ctrl+R"; enabled: !!finestra.aperto; onActivated: finestra.scrivi(ponte.chiama("bozza", [finestra.aperto.conto, finestra.aperto.cartella, finestra.aperto.uid, "rispondi"])) }
    Shortcut { sequences: [StandardKey.Delete]; enabled: !!finestra.aperto && !componi.visible; onActivated: finestra.azione("elimina", [finestra.aperto.conto, finestra.aperto.cartella, finestra.aperto.uid], true) }
    Shortcut { sequences: [StandardKey.Refresh]; onActivated: finestra.aggiorna() }

    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id === "aggiorna") {
                finestra.aggiornando = false
                if (!r.ok && r.messaggio) avviso.mostra(r.messaggio)
                finestra.ricaricaConti(); finestra.ricaricaMessaggi()
            } else if (id === "apri") {
                finestra.attesa--
                if (r.ok) { finestra.aperto = r; finestra.ricaricaMessaggi(); finestra.ricaricaConti() }
                else avviso.mostra(r.messaggio)
            } else if (id === "immagini") {
                if (r.ok) finestra.aperto = r
            } else if (id === "invia") {
                componi.inviando = false
                avviso.mostra(r.messaggio)
                if (r.ok) componi.chiudi()
            } else if (id === "bozza") {
                avviso.mostra(r.messaggio)
                if (r.ok) componi.chiudi()
            } else if (id === "configura") {
                nuovoConto.trovata(r)
            } else if (id === "aggiungi") {
                nuovoConto.finito(r)
            }
        }
        function onErrore(id, testo) {
            if (id === "aggiorna") finestra.aggiornando = false
            if (id === "apri") finestra.attesa--
            if (id === "invia") componi.inviando = false
            if (id === "aggiungi" || id === "configura") nuovoConto.lavoro = false
            avviso.mostra(testo)
        }
    }

    // ── Aggiungere un account ──
    Rectangle {
        id: nuovoConto
        anchors.fill: parent
        visible: finestra.configurazione
        z: 5
        color: Tema.sfondo
        property bool lavoro: false
        property bool avanzate: false
        property var conf: null
        function trovata(c) {
            lavoro = false; conf = c
            campoImap.text = c.imap; campoPortaImap.text = c.portaImap; campoSmtp.text = c.smtp; campoPortaSmtp.text = c.portaSmtp
            campoUtente.text = c.utente; sicurezza.currentIndex = c.sicurezzaSmtp === "starttls" ? 1 : 0
            avanzate = !c.trovata
            aggiungi()
        }
        function aggiungi() {
            lavoro = true
            errore.text = ""
            ponte.avvia("aggiungiConto", [{ email: campoEmail.text.trim(), nome: campoNome.text.trim(), password: campoPw.text, utente: campoUtente.text,
                                             imap: campoImap.text, portaImap: parseInt(campoPortaImap.text), smtp: campoSmtp.text,
                                             portaSmtp: parseInt(campoPortaSmtp.text), sicurezzaSmtp: sicurezza.currentIndex === 1 ? "starttls" : "ssl" }], "aggiungi")
        }
        function finito(r) {
            lavoro = false
            if (!r.ok) { errore.text = r.messaggio; avanzate = true; return }
            campoPw.text = ""; conf = null; avanzate = false
            finestra.configurazione = false
            finestra.ricaricaConti()
            finestra.vai(r.id, "INBOX", I18n.t("Entrata"))
            if (r.messaggio) avviso.mostra(r.messaggio)
        }
        function avanti() {
            if (!campoEmail.text.includes("@") || !campoPw.text) { errore.text = I18n.t("Scrivi l'email e la password"); return }
            if (conf) { aggiungi(); return }
            lavoro = true; errore.text = ""
            ponte.avvia("configura", [campoEmail.text.trim()], "configura")
        }
        Flickable {
            anchors.fill: parent
            contentHeight: Math.max(height, moduloConto.implicitHeight + 80)
            ColumnLayout {
                id: moduloConto
                width: Math.min(440, parent.width - 48)
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.max(40, (parent.height - implicitHeight) / 2 - 20)
                spacing: 12
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 72; height: 72; radius: 18
                    gradient: Gradient { GradientStop { position: 0; color: "#60A5FA" } GradientStop { position: 1; color: "#2563EB" } }
                    Simbolo { anchors.centerIn: parent; nome: "busta"; lato: 38; colore: "#FFFFFF" }
                }
                Text { Layout.alignment: Qt.AlignHCenter; text: I18n.t("Aggiungi un account di posta"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 22; font.weight: Font.Bold }
                Text {
                    Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                    text: I18n.t("Funziona con Gmail, iCloud, Yahoo, Libero, Virgilio, Alice e TIM, Tiscali, Aruba e PEC, Fastweb e con ogni posta IMAP.")
                    color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13
                }
                CampoTesto { id: campoNome; Layout.fillWidth: true; placeholderText: I18n.t("Il tuo nome (lo vede chi riceve)") }
                CampoTesto { id: campoEmail; Layout.fillWidth: true; placeholderText: I18n.t("Indirizzo email"); inputMethodHints: Qt.ImhEmailCharactersOnly; onTextChanged: nuovoConto.conf = null }
                CampoTesto { id: campoPw; Layout.fillWidth: true; placeholderText: I18n.t("Password"); echoMode: TextInput.Password; onAccepted: nuovoConto.avanti() }
                Text {
                    visible: !!nuovoConto.conf && !!nuovoConto.conf.nota
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: nuovoConto.conf ? nuovoConto.conf.nota : ""
                    color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                }
                Text {
                    text: nuovoConto.avanzate ? I18n.t("Nascondi i server") : I18n.t("Server e porte…")
                    color: Tema.accento; font.family: Tema.font; font.pixelSize: 13
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: nuovoConto.avanzate = !nuovoConto.avanzate }
                }
                GridLayout {
                    visible: nuovoConto.avanzate
                    Layout.fillWidth: true
                    columns: 3; columnSpacing: 8; rowSpacing: 8
                    Text { text: I18n.t("Ricezione (IMAP)"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                    CampoTesto { id: campoImap; Layout.fillWidth: true; placeholderText: "imap.esempio.it" }
                    CampoTesto { id: campoPortaImap; Layout.preferredWidth: 64; text: "993"; inputMethodHints: Qt.ImhDigitsOnly }
                    Text { text: I18n.t("Invio (SMTP)"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                    CampoTesto { id: campoSmtp; Layout.fillWidth: true; placeholderText: "smtp.esempio.it" }
                    CampoTesto { id: campoPortaSmtp; Layout.preferredWidth: 64; text: "465"; inputMethodHints: Qt.ImhDigitsOnly }
                    Text { text: I18n.t("Sicurezza invio"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                    Scelta { id: sicurezza; Layout.fillWidth: true; Layout.columnSpan: 2; model: [I18n.t("SSL/TLS (porta 465)"), I18n.t("STARTTLS (porta 587)")]; textRole: ""; valueRole: "" }
                    Text { text: I18n.t("Nome utente"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                    CampoTesto { id: campoUtente; Layout.fillWidth: true; Layout.columnSpan: 2; placeholderText: I18n.t("di solito l'email") }
                }
                Text { id: errore; visible: text !== ""; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: "#EF4444"; font.family: Tema.font; font.pixelSize: 13 }
                RowLayout {
                    Layout.fillWidth: true; Layout.topMargin: 6
                    Pulsante { visible: finestra.conti.length > 0; text: I18n.t("Annulla"); onClicked: { finestra.configurazione = false; nuovoConto.conf = null; errore.text = "" } }
                    Item { Layout.fillWidth: true }
                    BusyIndicator { visible: nuovoConto.lavoro; running: visible; Layout.preferredWidth: 26; Layout.preferredHeight: 26 }
                    Pulsante { text: nuovoConto.lavoro ? I18n.t("Collegamento…") : I18n.t("Aggiungi"); principale: true; enabled: !nuovoConto.lavoro; onClicked: nuovoConto.avanti() }
                }
                Text {
                    Layout.fillWidth: true; Layout.topMargin: 10; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                    text: I18n.t("La password resta su questo computer, cifrata. I messaggi si scaricano direttamente dal tuo fornitore di posta.")
                    color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11
                }
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0
        visible: !finestra.configurazione

        // ── Caselle ──
        Rectangle {
            Layout.preferredWidth: 230
            Layout.fillHeight: true
            color: Tema.superficie
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                RowLayout {
                    Layout.fillWidth: true; Layout.margins: 12
                    Text { text: I18n.t("Caselle"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    BottoneIcona { simbolo: "freccia-giro"; suggerimento: I18n.t("Controlla la posta"); ruota: finestra.aggiornando; onClicked: finestra.aggiorna() }
                    BottoneIcona { simbolo: "matita"; suggerimento: I18n.t("Scrivi un messaggio"); colore: Tema.accento; onClicked: finestra.scrivi() }
                }
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: colonna.implicitHeight
                    clip: true
                    ScrollBar.vertical: ScrollBar {}
                    ColumnLayout {
                        id: colonna
                        width: parent.width
                        spacing: 1
                        VoceCasella {
                            visible: finestra.conti.length > 1
                            simbolo: "entrata"; testo: I18n.t("Tutte le entrate")
                            numero: finestra.conti.reduce(function (s, a) { return s + (a.nonlette || 0) }, 0)
                            attiva: finestra.conto === ""
                            onScelta: finestra.vai("", "INBOX", I18n.t("Tutte le entrate"))
                        }
                        Repeater {
                            model: finestra.conti
                            ColumnLayout {
                                id: gruppo
                                required property var modelData
                                property bool aperto: true
                                Layout.fillWidth: true
                                spacing: 1
                                RowLayout {
                                    Layout.fillWidth: true; Layout.leftMargin: 14; Layout.rightMargin: 10; Layout.topMargin: 12; Layout.bottomMargin: 2
                                    Rectangle { width: 8; height: 8; radius: 4; color: gruppo.modelData.colore }
                                    Text { text: gruppo.modelData.email; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                    Simbolo { nome: gruppo.aperto ? "freccia-giu" : "freccia-destra"; lato: 13; colore: Tema.testoSecondario }
                                    TapHandler { onTapped: gruppo.aperto = !gruppo.aperto }
                                    TapHandler { acceptedButtons: Qt.RightButton; onTapped: menuConto.apri(gruppo.modelData) }
                                }
                                Repeater {
                                    model: gruppo.aperto ? (finestra.cartelle[gruppo.modelData.id] || []) : []
                                    VoceCasella {
                                        simbolo: finestra.simboli[modelData.ruolo] || "cartella"
                                        testo: modelData.nomeVisibile
                                        numero: modelData.ruolo === "inviata" || modelData.ruolo === "cestino" || modelData.ruolo === "bozze" ? 0 : modelData.nonlette
                                        attiva: finestra.conto === gruppo.modelData.id && finestra.cartella === modelData.nome
                                        onScelta: finestra.vai(gruppo.modelData.id, modelData.nome, modelData.nomeVisibile)
                                    }
                                }
                            }
                        }
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: Tema.bordo }
                Pulsante { Layout.fillWidth: true; Layout.margins: 10; text: I18n.t("Aggiungi un account"); onClicked: { finestra.configurazione = true } }
            }
        }
        Rectangle { Layout.fillHeight: true; width: 1; color: Tema.bordo }

        // ── Messaggi ──
        Rectangle {
            Layout.preferredWidth: 350
            Layout.fillHeight: true
            color: Tema.sfondo
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                RowLayout {
                    Layout.fillWidth: true; Layout.leftMargin: 16; Layout.rightMargin: 10; Layout.topMargin: 12
                    ColumnLayout {
                        spacing: 0; Layout.fillWidth: true
                        Text { text: finestra.nomeCartella; color: Tema.testo; font.family: Tema.font; font.pixelSize: 20; font.weight: Font.Bold; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text {
                            text: finestra.aggiornando ? I18n.t("Controllo della posta…")
                                  : (finestra.messaggi.filter(function (m) { return !m.letto }).length + " " + I18n.t("non letti"))
                            color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                        }
                    }
                    BottoneIcona {
                        simbolo: "elenco"; suggerimento: finestra.soloNonLetti ? I18n.t("Mostra tutti") : I18n.t("Solo non letti")
                        colore: finestra.soloNonLetti ? Tema.accento : Tema.testoSecondario
                        onClicked: { finestra.soloNonLetti = !finestra.soloNonLetti; finestra.ricaricaMessaggi() }
                    }
                }
                CampoRicerca { id: cerca; Layout.fillWidth: true; Layout.margins: 12; onTextChanged: finestra.ricaricaMessaggi() }
                Rectangle { Layout.fillWidth: true; height: 1; color: Tema.bordo }
                ListView {
                    id: elenco
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: finestra.messaggi
                    ScrollBar.vertical: ScrollBar {}
                    delegate: Rectangle {
                        id: riga
                        required property var modelData
                        readonly property bool attivo: !!finestra.aperto && finestra.aperto.uid === modelData.uid && finestra.aperto.conto === modelData.conto && finestra.aperto.cartella === modelData.cartella
                        width: elenco.width
                        height: 92
                        color: attivo ? Tema.accento : (sopraM.hovered ? Tema.superficie : "transparent")
                        HoverHandler { id: sopraM }
                        Rectangle { visible: !riga.modelData.letto; x: 8; y: 18; width: 9; height: 9; radius: 5; color: riga.attivo ? "white" : Tema.accento }
                        ColumnLayout {
                            x: 26; y: 10; width: parent.width - 40
                            spacing: 2
                            RowLayout {
                                Layout.fillWidth: true; spacing: 6
                                Text { text: riga.modelData.da; Layout.fillWidth: true; elide: Text.ElideRight; color: riga.attivo ? "white" : Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: riga.modelData.letto ? Font.DemiBold : Font.Bold }
                                Simbolo { visible: riga.modelData.allegati; nome: "graffetta"; lato: 13; colore: riga.attivo ? "#FFFFFF" : Tema.testoSecondario }
                                Simbolo { visible: riga.modelData.bandiera; nome: "bandiera-piena"; lato: 13; colore: riga.attivo ? "#FFFFFF" : "#F59E0B" }
                                Text { text: riga.modelData.quando; color: riga.attivo ? Qt.rgba(1, 1, 1, 0.85) : Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                            }
                            Text { Layout.fillWidth: true; text: riga.modelData.oggetto; elide: Text.ElideRight; color: riga.attivo ? "white" : Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                            Text {
                                Layout.fillWidth: true; text: riga.modelData.anteprima; elide: Text.ElideRight; wrapMode: Text.WordWrap; maximumLineCount: 2
                                color: riga.attivo ? Qt.rgba(1, 1, 1, 0.8) : Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                            }
                        }
                        Rectangle { visible: finestra.conto === "" && finestra.conti.length > 1; x: 2; y: 10; width: 3; height: parent.height - 20; radius: 2; color: riga.modelData.colore }
                        Rectangle { anchors.bottom: parent.bottom; x: 26; width: parent.width - 26; height: 1; color: Tema.bordo; opacity: 0.6 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: finestra.apri(riga.modelData) }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: elenco.count === 0
                        width: parent.width - 40; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                        text: finestra.aggiornando ? I18n.t("Scaricamento dei messaggi…") : (cerca.text ? I18n.t("Nessun risultato") : I18n.t("Nessun messaggio"))
                        color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 14
                    }
                }
            }
        }
        Rectangle { Layout.fillHeight: true; width: 1; color: Tema.bordo }

        // ── Messaggio ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Column {
                anchors.centerIn: parent
                visible: !finestra.aperto
                spacing: 10
                Simbolo { anchors.horizontalCenter: parent.horizontalCenter; nome: "busta"; lato: 52; colore: Tema.testoSecondario; opacity: 0.5 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: finestra.attesa > 0 ? I18n.t("Apertura del messaggio…") : I18n.t("Nessun messaggio selezionato"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 15 }
            }

            ColumnLayout {
                anchors.fill: parent
                visible: !!finestra.aperto
                spacing: 0
                // comandi
                RowLayout {
                    Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12; Layout.topMargin: 8; Layout.bottomMargin: 8
                    spacing: 2
                    BottoneIcona { simbolo: "rispondi"; suggerimento: I18n.t("Rispondi"); onClicked: finestra.scrivi(ponte.chiama("bozza", [finestra.aperto.conto, finestra.aperto.cartella, finestra.aperto.uid, "rispondi"])) }
                    BottoneIcona { simbolo: "rispondi-tutti"; suggerimento: I18n.t("Rispondi a tutti"); onClicked: finestra.scrivi(ponte.chiama("bozza", [finestra.aperto.conto, finestra.aperto.cartella, finestra.aperto.uid, "tutti"])) }
                    BottoneIcona { simbolo: "inoltra"; suggerimento: I18n.t("Inoltra"); onClicked: finestra.scrivi(ponte.chiama("bozza", [finestra.aperto.conto, finestra.aperto.cartella, finestra.aperto.uid, "inoltra"])) }
                    Rectangle { width: 1; height: 20; color: Tema.bordo; Layout.leftMargin: 6; Layout.rightMargin: 6 }
                    BottoneIcona { simbolo: "archivio"; suggerimento: I18n.t("Archivia"); onClicked: finestra.azione("sposta", [finestra.aperto.conto, finestra.aperto.cartella, finestra.aperto.uid, "archivio"], true) }
                    BottoneIcona { simbolo: "attenzione"; suggerimento: I18n.t("Sposta in Indesiderata"); onClicked: finestra.azione("sposta", [finestra.aperto.conto, finestra.aperto.cartella, finestra.aperto.uid, "indesiderata"], true) }
                    BottoneIcona { simbolo: "cestino"; suggerimento: I18n.t("Elimina"); onClicked: finestra.azione("elimina", [finestra.aperto.conto, finestra.aperto.cartella, finestra.aperto.uid], true) }
                    BottoneIcona { simbolo: "cartella"; suggerimento: I18n.t("Sposta in…"); onClicked: menuSposta.popup() }
                    Item { Layout.fillWidth: true }
                    BottoneIcona {
                        readonly property var m: finestra.messaggi.find(function (x) { return finestra.aperto && x.uid === finestra.aperto.uid && x.conto === finestra.aperto.conto }) || {}
                        simbolo: m.bandiera ? "bandiera-piena" : "bandiera"; colore: m.bandiera ? "#F59E0B" : Tema.testoSecondario
                        suggerimento: m.bandiera ? I18n.t("Togli la bandiera") : I18n.t("Bandiera")
                        onClicked: finestra.azione("segna", [finestra.aperto.conto, finestra.aperto.cartella, finestra.aperto.uid, "bandiera", !m.bandiera], false)
                    }
                    BottoneIcona {
                        simbolo: "busta"; suggerimento: I18n.t("Segna come non letto")
                        onClicked: { finestra.azione("segna", [finestra.aperto.conto, finestra.aperto.cartella, finestra.aperto.uid, "letto", false], false); finestra.aperto = null }
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: Tema.bordo }
                // intestazione
                RowLayout {
                    Layout.fillWidth: true; Layout.leftMargin: 24; Layout.rightMargin: 24; Layout.topMargin: 18
                    spacing: 12
                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        width: 44; height: 44; radius: 22
                        color: finestra.aperto ? ["#3B82F6", "#8B5CF6", "#EC4899", "#F97316", "#14B8A6", "#22C55E"][(finestra.aperto.daEmail || "").length % 6] : "gray"
                        Text { anchors.centerIn: parent; text: finestra.aperto ? (finestra.aperto.daNome || "?").charAt(0).toUpperCase() : ""; color: "white"; font.family: Tema.font; font.pixelSize: 19; font.weight: Font.Bold }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: finestra.aperto ? finestra.aperto.daNome : ""; color: Tema.testo; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.Bold; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { text: finestra.aperto ? finestra.aperto.quando : ""; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                        }
                        Text { text: finestra.aperto ? finestra.aperto.daEmail : ""; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                        Text {
                            Layout.fillWidth: true; elide: Text.ElideRight
                            text: finestra.aperto ? I18n.t("A") + ": " + finestra.aperto.a + (finestra.aperto.cc ? "   " + I18n.t("Cc") + ": " + finestra.aperto.cc : "") : ""
                            color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true; Layout.leftMargin: 24; Layout.rightMargin: 24; Layout.topMargin: 12
                    text: finestra.aperto ? finestra.aperto.oggetto : ""
                    wrapMode: Text.WordWrap
                    color: Tema.testo; font.family: Tema.font; font.pixelSize: 20; font.weight: Font.Bold
                }
                // immagini bloccate
                Rectangle {
                    visible: !!finestra.aperto && finestra.aperto.bloccate > 0 && !finestra.immagini
                    Layout.fillWidth: true; Layout.leftMargin: 24; Layout.rightMargin: 24; Layout.topMargin: 10
                    Layout.preferredHeight: 40; radius: 8
                    color: Tema.superficie
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 6
                        Simbolo { nome: "scudo"; lato: 16; colore: Tema.testoSecondario }
                        Text { Layout.fillWidth: true; elide: Text.ElideRight; text: I18n.t("Immagini esterne bloccate: chi ha scritto non sa che hai aperto il messaggio."); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                        Pulsante {
                            text: I18n.t("Carica immagini")
                            onClicked: { finestra.immagini = true; ponte.avvia("apri", [finestra.aperto.conto, finestra.aperto.cartella, finestra.aperto.uid, true, !Tema.chiaro], "immagini") }
                        }
                    }
                }
                // allegati
                Flow {
                    visible: !!finestra.aperto && finestra.aperto.allegati.length > 0
                    Layout.fillWidth: true; Layout.leftMargin: 24; Layout.rightMargin: 24; Layout.topMargin: 10
                    spacing: 8
                    Repeater {
                        model: finestra.aperto ? finestra.aperto.allegati : []
                        Rectangle {
                            width: Math.min(260, rigaAll.implicitWidth + 24); height: 44; radius: 8
                            color: sopraA.hovered ? Tema.superficieAlta : Tema.superficie
                            border.color: Tema.bordo; border.width: 1
                            HoverHandler { id: sopraA }
                            RowLayout {
                                id: rigaAll
                                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                                Simbolo { nome: "documento"; lato: 18; colore: Tema.accento }
                                ColumnLayout {
                                    spacing: 0; Layout.fillWidth: true
                                    Text { Layout.fillWidth: true; Layout.maximumWidth: 190; text: modelData.nome; elide: Text.ElideMiddle; color: Tema.testo; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                                    Text { text: modelData.testoDimensione; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { var r = ponte.chiama("allegato", [finestra.aperto.conto, finestra.aperto.cartella, finestra.aperto.uid, modelData.indice, true]); if (r.messaggio) avviso.mostra(r.messaggio) }
                            }
                            ToolTip.visible: sopraA.hovered; ToolTip.text: I18n.t("Apri (si salva in Scaricati)"); ToolTip.delay: 600
                        }
                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.leftMargin: 24; Layout.rightMargin: 24; Layout.topMargin: 14; height: 1; color: Tema.bordo }
                // corpo
                Loader {
                    id: corpo
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: 20; Layout.rightMargin: 12; Layout.topMargin: 8
                    source: "Lettore.qml"
                    onStatusChanged: if (status === Loader.Error) source = "LettoreTesto.qml"
                    Binding { target: corpo.item; property: "pagina"; value: finestra.aperto ? finestra.aperto.html : ""; when: corpo.status === Loader.Ready }
                    Connections { target: corpo.item; ignoreUnknownSignals: true; function onCollegamento(url) { ponte.chiama("apriLink", [url]) } }
                }
            }
        }
    }

    // ── Pannello per scrivere ──
    Popup {
        id: componi
        property bool inviando: false
        property var allegati: []
        property string inRisposta: ""
        property string riferimenti: ""
        property bool copie: false
        function mostra(b) {
            sceltaConto.currentIndex = Math.max(0, finestra.conti.findIndex(function (a) { return a.id === b.conto }))
            campoA.text = b.a || ""; campoCc.text = b.cc || ""; campoCcn.text = ""; campoOggetto.text = b.oggetto || ""
            var firma = b.inRisposta || b.oggetto ? "" : ponte.chiama("firma", [b.conto])
            campoTesto.text = (b.testo || "") + (firma ? "\n\n-- \n" + firma : "")
            allegati = ponte.chiama("infoFile", [b.allegati || []])
            inRisposta = b.inRisposta || ""; riferimenti = b.riferimenti || ""
            copie = !!b.cc
            open()
            if (campoA.text) { campoTesto.forceActiveFocus(); campoTesto.cursorPosition = 0 } else campoA.forceActiveFocus()
        }
        function dati() {
            return { conto: finestra.conti.length ? finestra.conti[sceltaConto.currentIndex].id : "", a: campoA.text, cc: campoCc.text, ccn: campoCcn.text,
                     oggetto: campoOggetto.text, testo: campoTesto.text, allegati: allegati.map(function (x) { return x.percorso }),
                     inRisposta: inRisposta, riferimenti: riferimenti }
        }
        function invia() {
            if (!campoA.text.trim() && !campoCc.text.trim() && !campoCcn.text.trim()) { avviso.mostra(I18n.t("Scrivi almeno un destinatario")); return }
            if (!campoOggetto.text.trim() && !confermaSenzaOggetto.visible) { confermaSenzaOggetto.open(); return }
            inviando = true
            ponte.avvia("invia", [dati()], "invia")
        }
        function chiudi() { close(); campoTesto.text = ""; allegati = [] }
        anchors.centerIn: Overlay.overlay
        width: Math.min(820, finestra.width - 60)
        height: Math.min(680, finestra.height - 60)
        modal: true
        closePolicy: Popup.NoAutoClose
        padding: 0
        background: Rectangle { radius: 14; color: Tema.sfondo; border.color: Tema.bordo; border.width: 1 }
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            RowLayout {
                Layout.fillWidth: true; Layout.margins: 14
                Text { text: campoOggetto.text || I18n.t("Nuovo messaggio"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 17; font.weight: Font.Bold; elide: Text.ElideRight; Layout.fillWidth: true }
                Pulsante {
                    text: I18n.t("Annulla")
                    onClicked: campoTesto.text.trim() || campoOggetto.text.trim() ? chiediBozza.open() : componi.chiudi()
                }
                Pulsante { text: componi.inviando ? I18n.t("Invio…") : I18n.t("Invia"); principale: true; enabled: !componi.inviando; icona: ""; onClicked: componi.invia() }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Tema.bordo }
            RigaCampo {
                etichetta: I18n.t("Da")
                visible: finestra.conti.length > 1
                Scelta { id: sceltaConto; Layout.fillWidth: true; model: finestra.conti.map(function (a) { return (a.nome ? a.nome + " · " : "") + a.email }); textRole: ""; valueRole: "" }
            }
            RigaCampo {
                etichetta: I18n.t("A")
                CampoIndirizzi { id: campoA }
                Text {
                    text: componi.copie ? "" : I18n.t("Cc/Ccn"); color: Tema.accento; font.family: Tema.font; font.pixelSize: 12
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: componi.copie = true }
                }
            }
            RigaCampo { etichetta: I18n.t("Cc"); visible: componi.copie; CampoIndirizzi { id: campoCc } }
            RigaCampo { etichetta: I18n.t("Ccn"); visible: componi.copie; CampoIndirizzi { id: campoCcn } }
            RigaCampo {
                etichetta: I18n.t("Oggetto")
                TextField { id: campoOggetto; Layout.fillWidth: true; background: null; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; leftPadding: 0 }
            }
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                TextArea {
                    id: campoTesto
                    wrapMode: TextEdit.Wrap
                    color: Tema.testo; font.family: Tema.font; font.pixelSize: 14
                    leftPadding: 18; rightPadding: 18; topPadding: 14
                    background: Item {}
                    selectByMouse: true
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Tema.bordo }
            RowLayout {
                Layout.fillWidth: true; Layout.margins: 10
                spacing: 8
                Pulsante { text: I18n.t("Allega…"); onClicked: sceltaAllegati.open() }
                Flow {
                    Layout.fillWidth: true; spacing: 6
                    Repeater {
                        model: componi.allegati
                        Rectangle {
                            width: rigaF.implicitWidth + 16; height: 28; radius: 14; color: Tema.superficie
                            Row {
                                id: rigaF; anchors.centerIn: parent; spacing: 6
                                Simbolo { anchors.verticalCenter: parent.verticalCenter; nome: "graffetta"; lato: 13; colore: Tema.testoSecondario }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.nome + " · " + modelData.testoDimensione; color: Tema.testo; font.family: Tema.font; font.pixelSize: 12 }
                                Simbolo {
                                    anchors.verticalCenter: parent.verticalCenter; nome: "chiudi"; lato: 12; colore: Tema.testoSecondario
                                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: { var a = componi.allegati.slice(); a.splice(index, 1); componi.allegati = a } }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── pezzi ──
    component VoceCasella: Rectangle {
        property string simbolo
        property string testo
        property int numero: 0
        property bool attiva: false
        signal scelta()
        Layout.fillWidth: true
        Layout.leftMargin: 8; Layout.rightMargin: 8
        Layout.preferredHeight: 32
        radius: 7
        color: attiva ? Tema.superficieAlta : (sopraC.hovered ? Qt.rgba(0.5, 0.5, 0.5, 0.08) : "transparent")
        HoverHandler { id: sopraC }
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
            spacing: 10
            Simbolo { nome: parent.parent.simbolo; lato: 16; colore: parent.parent.attiva ? Tema.accento : Tema.testoSecondario }
            Text { text: parent.parent.testo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }
            Text { visible: parent.parent.numero > 0; text: parent.parent.numero; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.scelta() }
    }
    component BottoneIcona: Rectangle {
        property string simbolo
        property string suggerimento
        property color colore: Tema.testoSecondario
        property bool ruota: false
        signal clicked()
        width: 32; height: 32; radius: 8
        color: sopraI.hovered ? Tema.superficieAlta : "transparent"
        HoverHandler { id: sopraI }
        Simbolo {
            anchors.centerIn: parent; nome: parent.simbolo; lato: 17; colore: parent.colore
            RotationAnimation on rotation { running: ruota; loops: Animation.Infinite; from: 0; to: 360; duration: 900 }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
        ToolTip.visible: sopraI.hovered && suggerimento !== ""; ToolTip.text: suggerimento; ToolTip.delay: 500
        Accessible.role: Accessible.Button; Accessible.name: suggerimento
    }
    component RigaCampo: ColumnLayout {
        property string etichetta
        default property alias contenuto: spazio.data
        Layout.fillWidth: true
        spacing: 0
        RowLayout {
            Layout.fillWidth: true; Layout.leftMargin: 18; Layout.rightMargin: 14
            Layout.preferredHeight: 40
            spacing: 8
            Text { text: parent.parent.etichetta + ":"; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13; Layout.preferredWidth: 58 }
            RowLayout { id: spazio; Layout.fillWidth: true; spacing: 6 }
        }
        Rectangle { Layout.fillWidth: true; Layout.leftMargin: 18; height: 1; color: Tema.bordo; opacity: 0.7 }
    }
    // campo degli indirizzi con i suggerimenti (rubrica e persone con cui si è scritto)
    component CampoIndirizzi: TextField {
        id: campoInd
        property var proposte: []
        Layout.fillWidth: true
        background: Item {}
        color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; leftPadding: 0
        inputMethodHints: Qt.ImhEmailCharactersOnly
        onTextEdited: { proposte = ponte.chiama("suggerimenti", [text]); if (proposte.length && text.split(",").pop().trim().length) tendina.open(); else tendina.close() }
        Keys.onDownPressed: if (tendina.opened) lista.incrementCurrentIndex()
        Keys.onUpPressed: if (tendina.opened) lista.decrementCurrentIndex()
        Keys.onReturnPressed: function (e) { if (tendina.opened && lista.currentIndex >= 0) campoInd.scegli(proposte[lista.currentIndex]); else e.accepted = false }
        function scegli(p) {
            var parti = text.split(",").slice(0, -1).map(function (x) { return x.trim() }).filter(function (x) { return x })
            parti.push(p.nome ? '"' + p.nome + '" <' + p.email + ">" : p.email)
            text = parti.join(", ") + ", "
            tendina.close()
        }
        Popup {
            id: tendina
            y: campoInd.height
            width: Math.max(320, campoInd.width)
            padding: 4
            background: Rectangle { radius: 8; color: Tema.superficie; border.color: Tema.bordo }
            contentItem: ListView {
                id: lista
                implicitHeight: contentHeight
                model: campoInd.proposte
                currentIndex: 0
                delegate: Rectangle {
                    width: lista.width; height: 40; radius: 6
                    color: ListView.isCurrentItem || sopraS.hovered ? Tema.superficieAlta : "transparent"
                    HoverHandler { id: sopraS }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; x: 10
                        Text { text: modelData.nome || modelData.email; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                        Text { visible: !!modelData.nome; text: modelData.email; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
                    }
                    MouseArea { anchors.fill: parent; onClicked: campoInd.scegli(modelData) }
                }
            }
        }
    }

    Menu {
        id: menuSposta
        Instantiator {
            model: finestra.aperto ? (finestra.cartelle[finestra.aperto.conto] || []).filter(function (c) { return c.nome !== finestra.aperto.cartella && c.ruolo !== "tutta" }) : []
            MenuItem { text: modelData.nomeVisibile; onTriggered: finestra.azione("sposta", [finestra.aperto.conto, finestra.aperto.cartella, finestra.aperto.uid, modelData.nome], true) }
            onObjectAdded: function (i, o) { menuSposta.insertItem(i, o) }
            onObjectRemoved: function (i, o) { menuSposta.removeItem(o) }
        }
    }
    Menu {
        id: menuConto
        property var conto: null
        function apri(a) { conto = a; firma.text = a.firma || ""; popup() }
        MenuItem { text: I18n.t("Firma…"); onTriggered: dialogoFirma.open() }
        MenuItem { text: I18n.t("Togli questo account"); onTriggered: confermaTogli.open() }
    }
    Dialog {
        id: dialogoFirma
        anchors.centerIn: parent; modal: true
        title: I18n.t("Firma in fondo ai messaggi")
        standardButtons: Dialog.Cancel | Dialog.Save
        TextArea { id: firma; width: 380; height: 120; wrapMode: TextEdit.Wrap; color: Tema.testo; font.family: Tema.font; background: Rectangle { radius: 8; color: Tema.superficieAlta } }
        onAccepted: { ponte.chiama("salvaFirma", [menuConto.conto.id, firma.text]); finestra.ricaricaConti() }
    }
    Dialog {
        id: confermaTogli
        anchors.centerIn: parent; modal: true
        title: I18n.t("Togliere l'account?")
        standardButtons: Dialog.Cancel | Dialog.Ok
        Text {
            width: 360; wrapMode: Text.WordWrap; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14
            text: menuConto.conto ? I18n.t("{e} sparisce da questo computer. I messaggi restano sul server e li ritrovi aggiungendolo di nuovo.").replace("{e}", menuConto.conto.email) : ""
        }
        onAccepted: { ponte.chiama("togliConto", [menuConto.conto.id]); finestra.conto = ""; finestra.aperto = null; finestra.ricaricaConti(); finestra.ricaricaMessaggi() }
    }
    Dialog {
        id: chiediBozza
        anchors.centerIn: parent; modal: true
        title: I18n.t("Salvare la bozza?")
        standardButtons: Dialog.Save | Dialog.Discard | Dialog.Cancel
        Text { width: 320; wrapMode: Text.WordWrap; text: I18n.t("La bozza va nella cartella Bozze e la riprendi quando vuoi."); color: Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
        onAccepted: ponte.avvia("salvaBozza", [componi.dati()], "bozza")
        onDiscarded: { close(); componi.chiudi() }
    }
    Dialog {
        id: confermaSenzaOggetto
        anchors.centerIn: parent; modal: true
        title: I18n.t("Inviare senza oggetto?")
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: { componi.inviando = true; ponte.avvia("invia", [componi.dati()], "invia") }
    }
    FileDialog {
        id: sceltaAllegati
        fileMode: FileDialog.OpenFiles
        onAccepted: componi.allegati = componi.allegati.concat(ponte.chiama("infoFile", [selectedFiles.map(function (u) { return u.toString() })]))
    }
    Messaggio { id: avviso }
}
