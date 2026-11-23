// Password: si apre con la password di accesso al computer. A sinistra le sezioni (Tutte, Codici,
// Wi-Fi, Sicurezza, Eliminate) con i numeri; al centro l'elenco con la ricerca e «+»; a destra la
// voce scelta: nome utente, password (nascosta, si mostra e si copia), codice di verifica che
// cambia ogni 30 secondi, sito, note, avvisi di sicurezza. «Modifica» rende i campi scrivibili;
// «Genera» crea una password robusta. Senza usarla per 5 minuti l'app si blocca da sola.
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Password")
    width: 1080
    height: 700
    minimumWidth: 820
    minimumHeight: 520

    property bool aperta: false
    property bool servePassword: true
    property bool serveVecchia: false
    property bool apertura: false
    property string sezione: "tutte"
    property var conteggi: ({})
    property var voci: []
    property var reti: []
    property string scelta: ""
    property var voce: ({})
    property var rete: ({})
    property bool modifica: false
    property bool mostraPassword: false
    property var codice: ({})
    property bool controllo: false
    readonly property color rosso: "#EF4444"
    readonly property color arancio: "#F59E0B"
    readonly property color verde: "#22C55E"
    readonly property var colori: ["#3B82F6", "#8B5CF6", "#EC4899", "#F97316", "#14B8A6", "#64748B", "#22C55E", "#EF4444"]
    readonly property var sezioni: [
        { id: "tutte", nome: I18n.t("Tutte"), simbolo: "chiave", colore: "#3B82F6" },
        { id: "codici", nome: I18n.t("Codici"), simbolo: "orologio", colore: "#8B5CF6" },
        { id: "wifi", nome: I18n.t("Wi-Fi"), simbolo: "wifi", colore: "#14B8A6" },
        { id: "sicurezza", nome: I18n.t("Sicurezza"), simbolo: "scudo", colore: "#F59E0B" },
        { id: "eliminate", nome: I18n.t("Eliminate"), simbolo: "cestino", colore: "#64748B" }
    ]
    readonly property var testiProblemi: ({ trapelata: I18n.t("Compare tra le password trapelate in rete"),
                                            riutilizzata: I18n.t("Usata anche per altri account"),
                                            debole: I18n.t("Facile da indovinare") })

    function coloreDi(testo) { var h = 0; for (var i = 0; i < testo.length; i++) h = (h * 31 + testo.charCodeAt(i)) % 997; return colori[h % colori.length] }
    function iniziale(t) { return (t || "?").replace(/^www\./, "").charAt(0).toUpperCase() }
    function controllaStato() {
        var s = ponte.chiama0("stato")
        servePassword = s.servePassword
        if (aperta && !s.aperta) { aperta = false; modifica = false; scelta = "" }
        if (!s.aperta && !servePassword && !apertura) sblocca("")
    }
    function sblocca(pw) {
        apertura = true
        ponte.avvia("apri", [pw, serveVecchia ? campoVecchia.text : ""], "apri")
    }
    function blocca() { ponte.chiama0("blocca"); aperta = false; modifica = false; scelta = ""; voce = ({}); campoLogin.text = ""; campoVecchia.text = "" }
    function ricarica() {
        if (!aperta) return
        conteggi = ponte.chiama0("conteggi")
        if (sezione === "wifi") reti = ponte.chiama0("reti")
        else voci = ponte.chiama("elenco", [sezione, cerca.text])
        if (scelta && sezione !== "wifi" && !modifica) { voce = ponte.chiama("dettagli", [scelta]); riempi() }
    }
    function scegli(id) {
        modifica = false; mostraPassword = false; scelta = id
        voce = ponte.chiama("dettagli", [id])
        riempi()
        aggiornaCodice()
    }
    // i campi si riempiono qui (non con un legame), così la modifica non si perde
    function riempi() {
        campoTitolo.text = voce.titolo || ""; campoUtente.text = voce.utente || ""; campoPw.text = voce.password || ""
        campoCodice.text = voce.codice || ""; campoSito.text = voce.sito || ""; campoNote.text = voce.note || ""
    }
    function scegliRete(nome) {
        var r = ponte.chiama("rete", [nome]); r.nome = nome
        rete = r; mostraPassword = false
    }
    function aggiornaCodice() { codice = scelta && voce.codice ? ponte.chiama("codice", [scelta]) : ({}) }
    function nuova() {
        sezione = sezione === "wifi" || sezione === "eliminate" ? "tutte" : sezione
        scelta = ""; voce = { titolo: "", sito: "", utente: "", password: ponte.chiama("genera", ["robusta", 20]), codice: "", note: "", nuova: true }
        modifica = true; mostraPassword = true
        riempi()
        campoTitolo.forceActiveFocus()
    }
    function salva() {
        var v = { id: voce.nuova ? "" : voce.id, titolo: campoTitolo.text, sito: campoSito.text, utente: campoUtente.text,
                  password: campoPw.text, codice: campoCodice.text, note: campoNote.text }
        var r = ponte.chiama("salva", [v])
        if (r.bloccata) { blocca(); return }
        if (!r.ok) { avviso.mostra(r.messaggio); return }
        modifica = false; mostraPassword = false
        ricarica(); scegli(r.id)
    }
    function copia(campo, testo) {
        if (ponte.chiama("copiaVoce", [scelta, campo])) avviso.mostra(testo + " · " + I18n.t("si cancella dagli appunti tra 90 secondi"))
    }
    onSezioneChanged: { scelta = ""; voce = ({}); rete = ({}); modifica = false; ricarica() }
    Component.onCompleted: controllaStato()

    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id === "apri") {
                finestra.apertura = false
                if (r.ok) { finestra.aperta = true; finestra.serveVecchia = false; campoLogin.text = ""; campoVecchia.text = ""; finestra.ricarica() }
                else { finestra.serveVecchia = !!r.serveVecchia; erroreApertura.text = r.messaggio || ""; campoLogin.selectAll(); campoLogin.forceActiveFocus() }
            } else if (id === "trapelate") {
                finestra.controllo = false
                avviso.mostra(r.messaggio || "")
                finestra.ricarica()
            }
        }
    }
    // codice che cambia e blocco dopo 5 minuti
    Timer { interval: 1000; repeat: true; running: finestra.aperta; onTriggered: { if (finestra.voce.codice && !finestra.modifica) finestra.aggiornaCodice(); finestra.controllaStato() } }

    // ── Bloccata ──
    Rectangle {
        anchors.fill: parent
        visible: !finestra.aperta
        color: Tema.sfondo
        ColumnLayout {
            anchors.centerIn: parent
            width: 340
            spacing: 14
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 76; height: 76; radius: 20
                gradient: Gradient { GradientStop { position: 0; color: "#60A5FA" } GradientStop { position: 1; color: "#2563EB" } }
                Simbolo { anchors.centerIn: parent; nome: "chiave"; lato: 40; colore: "#FFFFFF" }
            }
            Text { Layout.alignment: Qt.AlignHCenter; text: I18n.t("Password è bloccata"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 22; font.weight: Font.Bold }
            Text {
                Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                text: finestra.servePassword ? I18n.t("Scrivi la password con cui entri nel computer.") : I18n.t("Apertura…")
                color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 14
            }
            CampoTesto {
                id: campoLogin
                visible: finestra.servePassword
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: I18n.t("Password di accesso")
                enabled: !finestra.apertura
                focus: true
                onAccepted: if (finestra.serveVecchia) campoVecchia.forceActiveFocus(); else finestra.sblocca(text)
            }
            CampoTesto {
                id: campoVecchia
                visible: finestra.serveVecchia
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: I18n.t("Password di prima")
                enabled: !finestra.apertura
                onAccepted: finestra.sblocca(campoLogin.text)
            }
            Text { id: erroreApertura; visible: text !== ""; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; color: finestra.rosso; font.family: Tema.font; font.pixelSize: 13 }
            Pulsante {
                visible: finestra.servePassword || finestra.serveVecchia
                Layout.alignment: Qt.AlignHCenter
                text: finestra.apertura ? I18n.t("Controllo…") : I18n.t("Sblocca")
                principale: true
                enabled: !finestra.apertura
                onClicked: finestra.sblocca(campoLogin.text)
            }
        }
        Text {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 18; anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width - 40, 560); horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
            text: finestra.servePassword ? I18n.t("Le password sono cifrate sul computer e si aprono solo con la tua password di accesso.")
                                         : I18n.t("Il tuo account non ha una password: chi usa il computer può aprire le password. Mettine una in Impostazioni, Utenti.")
            color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
        }
    }

    // ── Aperta ──
    RowLayout {
        anchors.fill: parent
        visible: finestra.aperta
        spacing: 0

        // sezioni
        Rectangle {
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            color: Tema.superficie
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 12
                spacing: 4
                Repeater {
                    model: finestra.sezioni
                    Rectangle {
                        readonly property bool attiva: finestra.sezione === modelData.id
                        Layout.fillWidth: true; Layout.preferredHeight: 40
                        radius: 8
                        color: attiva ? Tema.superficieAlta : (sopraS.hovered ? Qt.rgba(0.5, 0.5, 0.5, 0.08) : "transparent")
                        HoverHandler { id: sopraS }
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 10
                            spacing: 10
                            Rectangle {
                                width: 26; height: 26; radius: 7; color: modelData.colore
                                Simbolo { anchors.centerIn: parent; nome: modelData.simbolo; lato: 15; colore: "#FFFFFF" }
                            }
                            Text { text: modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; Layout.fillWidth: true }
                            Text { text: finestra.conteggi[modelData.id] || ""; color: modelData.id === "sicurezza" && finestra.conteggi.sicurezza ? finestra.arancio : Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13; font.weight: modelData.id === "sicurezza" ? Font.DemiBold : Font.Normal }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: finestra.sezione = modelData.id }
                    }
                }
                Item { Layout.fillHeight: true }
                Pulsante { Layout.fillWidth: true; text: I18n.t("Importa da file CSV…"); onClicked: sceltaCsv.open() }
                Pulsante { Layout.fillWidth: true; text: I18n.t("Esporta…"); onClicked: confermaEsporta.open() }
                Pulsante { Layout.fillWidth: true; text: I18n.t("Blocca"); onClicked: finestra.blocca() }
            }
        }
        Rectangle { Layout.fillHeight: true; width: 1; color: Tema.bordo }

        // elenco
        Rectangle {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            color: Tema.sfondo
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                RowLayout {
                    Layout.fillWidth: true; Layout.margins: 12
                    spacing: 8
                    CampoRicerca { id: cerca; Layout.fillWidth: true; visible: finestra.sezione !== "wifi"; onTextChanged: finestra.ricarica() }
                    Text { visible: finestra.sezione === "wifi"; text: I18n.t("Reti salvate"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.Bold; Layout.fillWidth: true }
                    Rectangle {
                        visible: finestra.sezione !== "wifi" && finestra.sezione !== "eliminate"
                        width: 30; height: 30; radius: 8
                        color: sopraP.hovered ? Tema.superficieAlta : "transparent"
                        HoverHandler { id: sopraP }
                        Simbolo { anchors.centerIn: parent; nome: "piu"; lato: 18; colore: Tema.accento }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: finestra.nuova() }
                        ToolTip.visible: sopraP.hovered; ToolTip.text: I18n.t("Nuova password")
                    }
                }
                // controllo delle password trapelate
                Rectangle {
                    visible: finestra.sezione === "sicurezza"
                    Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12; Layout.bottomMargin: 8
                    Layout.preferredHeight: testoCtrl.implicitHeight + 52
                    radius: 10; color: Tema.superficie
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 10; spacing: 6
                        Text { id: testoCtrl; Layout.fillWidth: true; wrapMode: Text.WordWrap; text: I18n.t("Controlla se qualche password compare tra quelle trapelate. Al servizio arriva solo un pezzo dell'impronta, mai la password."); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                        Pulsante { text: finestra.controllo ? I18n.t("Controllo…") : I18n.t("Controlla adesso"); enabled: !finestra.controllo; onClicked: { finestra.controllo = true; ponte.avvia("controllaTrapelate", [], "trapelate") } }
                    }
                }
                ListView {
                    id: elenco
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: finestra.sezione === "wifi" ? finestra.reti : finestra.voci
                    ScrollBar.vertical: ScrollBar {}
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool wifi: finestra.sezione === "wifi"
                        readonly property bool attiva: wifi ? finestra.rete.nome === modelData.nome : finestra.scelta === modelData.id
                        readonly property string titolo: wifi ? modelData.nome : modelData.titolo
                        width: elenco.width - 16; x: 8
                        height: 54
                        radius: 9
                        color: attiva ? Tema.accento : (sopraV.hovered ? Tema.superficie : "transparent")
                        HoverHandler { id: sopraV }
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                            spacing: 10
                            Rectangle {
                                width: 34; height: 34; radius: 8
                                color: wifi ? "#14B8A6" : finestra.coloreDi(modelData.dominio || modelData.titolo)
                                Text { visible: !wifi; anchors.centerIn: parent; text: finestra.iniziale(modelData.dominio || modelData.titolo); color: "white"; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.Bold }
                                Simbolo { visible: wifi; anchors.centerIn: parent; nome: "wifi"; lato: 18; colore: "#FFFFFF" }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 1
                                Text { Layout.fillWidth: true; text: titolo; elide: Text.ElideRight; color: attiva ? "white" : Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                                Text {
                                    visible: !wifi
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                    text: modelData.eliminata ? I18n.t("Eliminata: resta ancora {n} giorni").replace("{n}", modelData.giorniRimasti) : (modelData.utente || "")
                                    color: attiva ? Qt.rgba(1, 1, 1, 0.8) : Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                                }
                            }
                            Simbolo { visible: !wifi && modelData.problemi && modelData.problemi.length > 0; nome: "attenzione"; lato: 16; colore: attiva ? "#FFFFFF" : finestra.arancio }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: wifi ? finestra.scegliRete(modelData.nome) : finestra.scegli(modelData.id)
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 40; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                        visible: elenco.count === 0
                        text: finestra.sezione === "wifi" ? I18n.t("Nessuna rete Wi-Fi salvata")
                            : finestra.sezione === "sicurezza" ? I18n.t("Nessun problema trovato")
                            : finestra.sezione === "codici" ? I18n.t("Nessun codice di verifica. Aggiungilo modificando una password.")
                            : finestra.sezione === "eliminate" ? I18n.t("Nessuna password eliminata")
                            : cerca.text ? I18n.t("Nessun risultato") : I18n.t("Nessuna password. Premi + per aggiungerne una, o importale da un file CSV.")
                        color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13
                    }
                }
            }
        }
        Rectangle { Layout.fillHeight: true; width: 1; color: Tema.bordo }

        // dettagli
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Text {
                anchors.centerIn: parent
                visible: !finestra.modifica && !finestra.voce.id && !(finestra.sezione === "wifi" && finestra.rete.nome)
                text: I18n.t("Scegli una voce dall'elenco")
                color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 15
            }

            // Wi-Fi
            ColumnLayout {
                visible: finestra.sezione === "wifi" && !!finestra.rete.nome
                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 28
                spacing: 16
                RowLayout {
                    spacing: 14
                    Rectangle { width: 56; height: 56; radius: 14; color: "#14B8A6"; Simbolo { anchors.centerIn: parent; nome: "wifi"; lato: 30; colore: "#FFFFFF" } }
                    Text { text: finestra.rete.ssid || finestra.rete.nome || ""; color: Tema.testo; font.family: Tema.font; font.pixelSize: 24; font.weight: Font.Bold }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 52; radius: 10; color: Tema.superficie
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 10
                        Text { text: I18n.t("Password"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13; Layout.preferredWidth: 120 }
                        Text {
                            Layout.fillWidth: true
                            text: !finestra.rete.ok ? (finestra.rete.messaggio || I18n.t("Password non disponibile")) : (finestra.rete.password ? (finestra.mostraPassword ? finestra.rete.password : "••••••••••") : I18n.t("Rete aperta"))
                            color: Tema.testo; font.family: finestra.mostraPassword ? "monospace" : Tema.font; font.pixelSize: 14
                        }
                        BottoneIcona { visible: !!finestra.rete.password; simbolo: finestra.mostraPassword ? "occhio-chiuso" : "occhio"; suggerimento: finestra.mostraPassword ? I18n.t("Nascondi") : I18n.t("Mostra"); onClicked: finestra.mostraPassword = !finestra.mostraPassword }
                        BottoneIcona { visible: !!finestra.rete.password; simbolo: "copia"; suggerimento: I18n.t("Copia"); onClicked: { ponte.chiama("copia", [finestra.rete.password]); avviso.mostra(I18n.t("Password copiata") + " · " + I18n.t("si cancella dagli appunti tra 90 secondi")) } }
                    }
                }
                Rectangle {
                    visible: !!finestra.rete.immagineQr
                    Layout.alignment: Qt.AlignHCenter
                    width: 220; height: 220; radius: 14; color: "white"
                    Image { anchors.fill: parent; anchors.margins: 10; source: finestra.rete.immagineQr || ""; sourceSize.width: 400; sourceSize.height: 400; smooth: false }
                }
                Text {
                    visible: !!finestra.rete.immagineQr
                    Layout.alignment: Qt.AlignHCenter
                    text: I18n.t("Inquadra il codice con la fotocamera di un telefono per collegarlo a questa rete.")
                    color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                }
            }

            // Voce
            Flickable {
                visible: finestra.sezione !== "wifi" && (finestra.modifica || !!finestra.voce.id)
                anchors.fill: parent
                contentHeight: corpo.implicitHeight + 56
                clip: true
                ScrollBar.vertical: ScrollBar {}
                ColumnLayout {
                    id: corpo
                    x: 28; y: 24
                    width: parent.width - 56
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        Rectangle {
                            width: 56; height: 56; radius: 14
                            color: finestra.coloreDi(finestra.voce.dominio || campoTitolo.text || finestra.voce.titolo || "?")
                            Text { anchors.centerIn: parent; text: finestra.iniziale(finestra.voce.dominio || campoTitolo.text || finestra.voce.titolo); color: "white"; font.family: Tema.font; font.pixelSize: 26; font.weight: Font.Bold }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            TextInput {
                                id: campoTitolo
                                Layout.fillWidth: true
                                readOnly: !finestra.modifica
                                color: Tema.testo; font.family: Tema.font; font.pixelSize: 24; font.weight: Font.Bold
                                selectByMouse: true
                                Text { visible: !parent.text && finestra.modifica; text: I18n.t("Nome (per esempio Amazon)"); color: Tema.testoSecondario; font: parent.font }
                            }
                            Text { visible: !finestra.modifica && !!finestra.voce.quando; text: I18n.t("Modificata il {d}").replace("{d}", finestra.voce.quando || ""); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                        }
                        Pulsante {
                            visible: !finestra.modifica && !finestra.voce.eliminata
                            text: I18n.t("Modifica")
                            onClicked: { finestra.modifica = true; finestra.mostraPassword = true }
                        }
                        Pulsante {
                            visible: !!finestra.voce.eliminata
                            text: I18n.t("Recupera")
                            principale: true
                            onClicked: { ponte.chiama("ripristina", [finestra.scelta]); finestra.scelta = ""; finestra.voce = ({}); finestra.ricarica() }
                        }
                    }

                    // avvisi di sicurezza
                    Repeater {
                        model: finestra.modifica ? [] : (finestra.voce.problemi || [])
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 10
                            color: Qt.rgba(0.96, 0.62, 0.04, 0.14)
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10
                                spacing: 10
                                Simbolo { nome: "attenzione"; lato: 18; colore: modelData === "trapelata" ? finestra.rosso : finestra.arancio }
                                Text { text: finestra.testiProblemi[modelData]; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; Layout.fillWidth: true }
                                Pulsante { visible: !!finestra.voce.sito; text: I18n.t("Cambia sul sito"); onClicked: ponte.chiama("apriSito", [finestra.voce.sito]) }
                            }
                        }
                    }

                    // campi
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: campi.implicitHeight
                        radius: 12; color: Tema.superficie
                        ColumnLayout {
                            id: campi
                            width: parent.width
                            spacing: 0

                            Riga {
                                etichetta: I18n.t("Nome utente")
                                CampoRiga { id: campoUtente; segnaposto: I18n.t("Email o nome utente") }
                                BottoneIcona { visible: !finestra.modifica && !!finestra.voce.utente; simbolo: "copia"; suggerimento: I18n.t("Copia"); onClicked: finestra.copia("utente", I18n.t("Nome utente copiato")) }
                            }
                            Separatore { Layout.fillWidth: true; Layout.leftMargin: 14 }
                            Riga {
                                etichetta: I18n.t("Password")
                                CampoRiga { id: campoPw; segnaposto: I18n.t("Password"); nascosto: !finestra.mostraPassword; monospazio: finestra.mostraPassword }
                                BottoneIcona { visible: finestra.modifica; simbolo: "freccia-giro"; suggerimento: I18n.t("Genera una password robusta"); onClicked: menuGenera.open() }
                                BottoneIcona { visible: !!campoPw.text; simbolo: finestra.mostraPassword ? "occhio-chiuso" : "occhio"; suggerimento: finestra.mostraPassword ? I18n.t("Nascondi") : I18n.t("Mostra"); onClicked: finestra.mostraPassword = !finestra.mostraPassword }
                                BottoneIcona { visible: !finestra.modifica && !!finestra.voce.password; simbolo: "copia"; suggerimento: I18n.t("Copia"); onClicked: finestra.copia("password", I18n.t("Password copiata")) }
                                Menu {
                                    id: menuGenera
                                    y: 30
                                    MenuItem { text: I18n.t("Robusta e facile da scrivere"); onTriggered: campoPw.text = ponte.chiama("genera", ["robusta", 20]) }
                                    MenuItem { text: I18n.t("Con caratteri speciali (20)"); onTriggered: campoPw.text = ponte.chiama("genera", ["caratteri", 20]) }
                                    MenuItem { text: I18n.t("Solo numeri (PIN di 6 cifre)"); onTriggered: campoPw.text = ponte.chiama("genera", ["numeri", 6]) }
                                }
                            }
                            // forza della password mentre si scrive
                            RowLayout {
                                visible: finestra.modifica && campoPw.text.length > 0
                                Layout.fillWidth: true; Layout.leftMargin: 14 + 130; Layout.rightMargin: 14; Layout.bottomMargin: 10
                                spacing: 6
                                readonly property var f: ponte.chiama("forza", [campoPw.text])
                                Repeater {
                                    model: 3
                                    Rectangle {
                                        Layout.preferredWidth: 40; height: 4; radius: 2
                                        color: index <= parent.f.livello ? [finestra.rosso, finestra.arancio, finestra.verde][parent.f.livello] : Tema.superficieAlta
                                    }
                                }
                                Text { text: parent.f.testo || ""; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                            }
                            Separatore { Layout.fillWidth: true; Layout.leftMargin: 14 }
                            Riga {
                                etichetta: I18n.t("Codice di verifica")
                                visible: finestra.modifica || !!finestra.voce.codice
                                CampoRiga { id: campoCodice; visible: finestra.modifica; segnaposto: I18n.t("Chiave di configurazione o link otpauth://") }
                                Text {
                                    visible: !finestra.modifica
                                    Layout.fillWidth: true
                                    text: finestra.codice.codice ? finestra.codice.codice.slice(0, 3) + " " + finestra.codice.codice.slice(3) : ""
                                    color: Tema.testo; font.family: "monospace"; font.pixelSize: 20; font.weight: Font.DemiBold; font.letterSpacing: 1
                                }
                                // anello del tempo rimasto
                                Canvas {
                                    visible: !finestra.modifica && !!finestra.codice.codice
                                    width: 22; height: 22
                                    property real parte: finestra.codice.periodo ? finestra.codice.resto / finestra.codice.periodo : 0
                                    onParteChanged: requestPaint()
                                    onPaint: {
                                        var g = getContext("2d"); g.reset()
                                        g.lineWidth = 3; g.strokeStyle = Tema.superficieAlta
                                        g.beginPath(); g.arc(11, 11, 8, 0, 2 * Math.PI); g.stroke()
                                        g.strokeStyle = parte < 0.2 ? finestra.rosso : Tema.accento
                                        g.beginPath(); g.arc(11, 11, 8, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * parte); g.stroke()
                                    }
                                }
                                BottoneIcona { visible: !finestra.modifica && !!finestra.codice.codice; simbolo: "copia"; suggerimento: I18n.t("Copia"); onClicked: finestra.copia("codice", I18n.t("Codice copiato")) }
                            }
                            Separatore { visible: finestra.modifica || !!finestra.voce.codice; Layout.fillWidth: true; Layout.leftMargin: 14 }
                            Riga {
                                etichetta: I18n.t("Sito web")
                                CampoRiga { id: campoSito; segnaposto: "amazon.it"; collegamento: !finestra.modifica }
                                BottoneIcona { visible: !finestra.modifica && !!finestra.voce.sito; simbolo: "globo"; suggerimento: I18n.t("Apri il sito"); onClicked: ponte.chiama("apriSito", [finestra.voce.sito]) }
                            }
                            Separatore { visible: finestra.modifica || !!finestra.voce.note; Layout.fillWidth: true; Layout.leftMargin: 14 }
                            Riga {
                                etichetta: I18n.t("Note")
                                visible: finestra.modifica || !!finestra.voce.note
                                TextArea {
                                    id: campoNote
                                    Layout.fillWidth: true
                                    readOnly: !finestra.modifica
                                    placeholderText: finestra.modifica ? I18n.t("Domande di sicurezza, PIN, altro") : ""
                                    wrapMode: TextEdit.Wrap
                                    color: Tema.testo; placeholderTextColor: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 14
                                    background: Item {}
                                    leftPadding: 0
                                }
                            }
                        }
                    }

                    Text {
                        visible: finestra.modifica && !!campoCodice.text
                        Layout.fillWidth: true; wrapMode: Text.WordWrap
                        readonly property var prova: campoCodice.text ? ponte.chiama("provaCodice", [campoCodice.text]) : ({})
                        text: prova.codice ? I18n.t("Codice di adesso: {c}. Scrivilo sul sito per completare la configurazione.").replace("{c}", prova.codice)
                                           : I18n.t("Chiave non valida: copia la chiave che il sito mostra accanto al codice QR.")
                        color: prova.codice ? Tema.testoSecondario : finestra.rosso; font.family: Tema.font; font.pixelSize: 12
                    }

                    // password usate prima
                    ColumnLayout {
                        visible: !finestra.modifica && (finestra.voce.precedenti || []).length > 0
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: I18n.t("Password precedenti"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                        Repeater {
                            model: finestra.voce.precedenti || []
                            Text {
                                text: (finestra.mostraPassword ? modelData.password : "••••••••") + "   ·   " + I18n.t("fino al {d}").replace("{d}", new Date(modelData.fino * 1000).toLocaleDateString(Qt.locale("it_IT"), "dd/MM/yyyy"))
                                color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        spacing: 8
                        Pulsante {
                            visible: !finestra.modifica && !finestra.voce.eliminata
                            text: I18n.t("Elimina"); pericoloso: true
                            onClicked: { ponte.chiama("elimina", [finestra.scelta, false]); avviso.mostra(I18n.t("Spostata in Eliminate: la recuperi entro 30 giorni")); finestra.scelta = ""; finestra.voce = ({}); finestra.ricarica() }
                        }
                        Pulsante {
                            visible: !!finestra.voce.eliminata
                            text: I18n.t("Elimina per sempre"); pericoloso: true
                            onClicked: { ponte.chiama("elimina", [finestra.scelta, true]); finestra.scelta = ""; finestra.voce = ({}); finestra.ricarica() }
                        }
                        Item { Layout.fillWidth: true }
                        Pulsante {
                            visible: finestra.modifica
                            text: I18n.t("Annulla")
                            onClicked: { finestra.modifica = false; finestra.mostraPassword = false; if (finestra.voce.nuova) finestra.voce = ({}); else finestra.scegli(finestra.scelta) }
                        }
                        Pulsante { visible: finestra.modifica; text: I18n.t("Salva"); principale: true; onClicked: finestra.salva() }
                    }
                }
            }
        }
    }

    // ── pezzi ──
    component Riga: RowLayout {
        property string etichetta
        default property alias contenuto: spazio.data
        Layout.fillWidth: true
        Layout.minimumHeight: 48
        Layout.leftMargin: 14; Layout.rightMargin: 8
        spacing: 8
        Text { text: parent.etichetta; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13; Layout.preferredWidth: 122; Layout.alignment: Qt.AlignVCenter }
        RowLayout { id: spazio; Layout.fillWidth: true; spacing: 4 }
    }
    component CampoRiga: TextField {
        property string segnaposto
        property bool nascosto: false
        property bool monospazio: false
        property bool collegamento: false
        id: campoInterno
        Layout.fillWidth: true
        readOnly: !finestra.modifica
        echoMode: nascosto ? TextInput.Password : TextInput.Normal
        placeholderText: finestra.modifica ? segnaposto : ""
        color: collegamento ? Tema.accento : Tema.testo
        placeholderTextColor: Tema.testoSecondario
        font.family: monospazio ? "monospace" : Tema.font
        font.pixelSize: 14
        leftPadding: finestra.modifica ? 8 : 0
        selectByMouse: true
        background: Rectangle { radius: 6; color: finestra.modifica ? Tema.superficieAlta : "transparent"; border.width: campoInterno.activeFocus && finestra.modifica ? 2 : 0; border.color: Tema.accento }
    }
    component BottoneIcona: Rectangle {
        property string simbolo
        property string suggerimento
        signal clicked()
        width: 30; height: 30; radius: 7
        color: sopraI.hovered ? Tema.superficieAlta : "transparent"
        HoverHandler { id: sopraI }
        Simbolo { anchors.centerIn: parent; nome: parent.simbolo; lato: 16; colore: Tema.testoSecondario }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
        ToolTip.visible: sopraI.hovered && suggerimento !== ""; ToolTip.text: suggerimento; ToolTip.delay: 500
        Accessible.role: Accessible.Button; Accessible.name: suggerimento
    }

    FileDialog { id: sceltaCsv; nameFilters: [I18n.t("File CSV") + " (*.csv)"]; onAccepted: { avviso.mostra(ponte.chiama("importa", [selectedFile.toString()]).messaggio || ""); finestra.ricarica() } }
    Dialog {
        id: confermaEsporta
        anchors.centerIn: parent
        modal: true
        title: I18n.t("Esportare le password?")
        standardButtons: Dialog.Cancel | Dialog.Ok
        Text {
            width: 360; wrapMode: Text.WordWrap
            text: I18n.t("Verrà creato in Documenti un file CSV con tutte le password in chiaro, leggibile da chiunque lo apra. Usalo per passarle a un altro programma e poi cancellalo.")
            color: Tema.testo; font.family: Tema.font; font.pixelSize: 14
        }
        onAccepted: avviso.mostra(ponte.chiama0("esporta").messaggio || "")
    }
    Messaggio { id: avviso }
}
