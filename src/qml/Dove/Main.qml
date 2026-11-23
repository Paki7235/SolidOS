// Dov'è: trova i tuoi dispositivi.
// Senza Solid ID: accesso o creazione dell'account. Con il Solid ID: a sinistra l'elenco
// dei dispositivi, a destra la mappa; per quello scelto: Fai suonare, Blocca, Indicazioni.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Dov'è")
    width: 1080
    height: 700
    property var utente: ponte.chiama0("utente")
    property var dispositivi: []
    property string scelto: ""
    property bool caricando: false
    property string erroreElenco: ""
    readonly property var dispositivoScelto: dispositivi.find(function (d) { return d.id === scelto }) || null
    // Comando in corso: id → testo dello stato
    property int comandoId: 0
    property string comandoTipo: ""
    property string statoComando: ""

    function aggiorna() {
        if (!utente.collegato) return
        caricando = true
        ponte.avvia("dispositivi", [], "dispositivi")
    }
    function scegli(id, centra) {
        scelto = id
        var d = dispositivoScelto
        if (centra && d && d.posizione) mappa.centra(d.lat, d.lon, Math.max(mappa.zoom, d.precisione > 5000 ? 11 : 15))
    }
    function invia(tipo, messaggio) {
        if (!dispositivoScelto) return
        comandoTipo = tipo
        statoComando = I18n.t("Invio…")
        ponte.avvia("comando", [dispositivoScelto.id, tipo, messaggio || ""], "comando")
    }

    Component.onCompleted: aggiorna()
    Timer { interval: 30000; running: finestra.utente.collegato; repeat: true; onTriggered: finestra.aggiorna() }
    // Segue il comando finché il dispositivo non l'ha eseguito
    Timer {
        id: seguiComando
        interval: 2500; repeat: true
        property int tentativi: 0
        onTriggered: {
            if (++tentativi > 40) { stop(); finestra.statoComando = I18n.t("Il dispositivo non risponde: lo farà appena torna in linea"); return }
            ponte.avvia("statoComando", [finestra.comandoId], "statoComando")
        }
    }

    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id === "dispositivi") {
                finestra.caricando = false
                finestra.erroreElenco = r.ok ? "" : r.messaggio
                if (!r.ok) return
                var primoGiro = finestra.dispositivi.length === 0
                finestra.dispositivi = r.dispositivi
                if (!finestra.scelto || !finestra.dispositivoScelto) {
                    var conPos = r.dispositivi.find(function (d) { return d.posizione && !d.questo }) || r.dispositivi.find(function (d) { return d.posizione }) || r.dispositivi[0]
                    if (conPos) finestra.scegli(conPos.id, primoGiro)
                }
            } else if (id === "comando") {
                if (!r.ok) { finestra.statoComando = ""; finestra.avviso(r.messaggio); return }
                finestra.comandoId = r.id
                finestra.statoComando = I18n.t("Inviato, in attesa del dispositivo…")
                seguiComando.tentativi = 0; seguiComando.restart()
            } else if (id === "statoComando") {
                if (r === "ricevuto") finestra.statoComando = I18n.t("Ricevuto dal dispositivo")
                else if (r === "eseguito") {
                    seguiComando.stop()
                    finestra.statoComando = ({ suona: I18n.t("Sta suonando 🔊"), ferma: I18n.t("Suono fermato"),
                                               blocca: I18n.t("Bloccato 🔒"), perso: I18n.t("Modalità smarrito attiva 🔒"), cancella: I18n.t("Il telefono si sta cancellando"), posizione: I18n.t("Posizione aggiornata") })[finestra.comandoTipo] || I18n.t("Fatto")
                    finestra.aggiorna()
                } else if (r === "errore") { seguiComando.stop(); finestra.statoComando = I18n.t("Il dispositivo non è riuscito a eseguirlo") }
            } else if (id === "accesso") {
                accesso.inCorso = false
                accesso.messaggio = r.messaggio || ""
                accesso.errore = !r.ok
                if (r.ok && r.collegato) { finestra.utente = ponte.chiama0("utente"); finestra.aggiorna() }
                else if (r.ok && r.conferma) accesso.modo = "accedi"
            }
        }
    }

    // ══ Senza Solid ID: accesso o creazione ══════════════════════════════════
    Item {
        id: accesso
        anchors.fill: parent
        visible: !finestra.utente.collegato
        property string modo: "accedi"      // accedi | crea
        property bool inCorso: false
        property string messaggio: ""
        property bool errore: false
        function vai() {
            if (inCorso) return
            inCorso = true; messaggio = ""
            if (modo === "accedi") ponte.avvia("accedi", [email.text, password.text], "accesso")
            else ponte.avvia("crea", [nome.text, email.text, password.text], "accesso")
        }
        Rectangle { anchors.fill: parent; color: Tema.sfondo }
        ColumnLayout {
            anchors.centerIn: parent
            width: 360
            spacing: 12
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 76; height: 76
                color: "transparent"
                Icona { anchors.centerIn: parent; nome: "org.gnome.Maps"; lato: 76 }
            }
            Titolo { Layout.alignment: Qt.AlignHCenter; text: accesso.modo === "accedi" ? I18n.t("Accedi al Solid ID") : I18n.t("Crea il tuo Solid ID") }
            Testo {
                Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; secondario: true
                text: I18n.t("Un solo account per tutti i tuoi dispositivi: ritrovali, falli suonare o bloccali se li perdi.")
            }
            CampoTesto { id: nome; Layout.fillWidth: true; visible: accesso.modo === "crea"; placeholderText: I18n.t("Nome") }
            CampoTesto { id: email; Layout.fillWidth: true; placeholderText: I18n.t("Email"); inputMethodHints: Qt.ImhEmailCharactersOnly; onAccepted: password.forceActiveFocus() }
            CampoTesto {
                id: password; Layout.fillWidth: true; echoMode: TextInput.Password
                placeholderText: accesso.modo === "crea" ? I18n.t("Password (almeno 8 caratteri)") : I18n.t("Password")
                onAccepted: accesso.vai()
            }
            Testo { Layout.fillWidth: true; visible: accesso.messaggio !== ""; text: accesso.messaggio; color: accesso.errore ? Tema.pericolo : Tema.testo; horizontalAlignment: Text.AlignHCenter }
            Pulsante {
                Layout.fillWidth: true; principale: true; enabled: !accesso.inCorso && email.text && password.text
                text: accesso.inCorso ? I18n.t("Attendi…") : (accesso.modo === "accedi" ? I18n.t("Accedi") : I18n.t("Crea Solid ID"))
                onClicked: accesso.vai()
            }
            Pulsante {
                Layout.fillWidth: true
                text: accesso.modo === "accedi" ? I18n.t("Non hai un Solid ID? Creane uno") : I18n.t("Hai già un Solid ID? Accedi")
                onClicked: { accesso.modo = accesso.modo === "accedi" ? "crea" : "accedi"; accesso.messaggio = "" }
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                visible: accesso.modo === "accedi"
                spacing: 16
                Testo { text: "<a href='x'>" + I18n.t("Password dimenticata?") + "</a>"; textFormat: Text.StyledText; linkColor: Tema.accento
                        onLinkActivated: { if (!email.text) { accesso.errore = true; accesso.messaggio = I18n.t("Scrivi prima la tua email") } else { accesso.inCorso = true; ponte.avvia("passwordDimenticata", [email.text], "accesso") } } }
                Testo { text: "<a href='x'>" + I18n.t("Reinvia l'email di conferma") + "</a>"; textFormat: Text.StyledText; linkColor: Tema.accento
                        onLinkActivated: { if (!email.text) { accesso.errore = true; accesso.messaggio = I18n.t("Scrivi prima la tua email") } else { accesso.inCorso = true; ponte.avvia("reinviaConferma", [email.text], "accesso") } } }
            }
        }
    }

    // ══ Con il Solid ID: elenco + mappa ══════════════════════════════════════
    RowLayout {
        anchors.fill: parent
        visible: finestra.utente.collegato
        spacing: 0

        Rectangle {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            color: Tema.chiaro ? "#EEEEF2" : "#232428"
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    Titolo { livello: 2; text: I18n.t("Dispositivi"); Layout.fillWidth: true }
                    BusyIndicator { running: finestra.caricando; visible: running; implicitWidth: 22; implicitHeight: 22 }
                    Pulsante { icona: "view-refresh-symbolic"; onClicked: finestra.aggiorna() }
                }
                Testo { Layout.fillWidth: true; visible: finestra.erroreElenco !== ""; text: finestra.erroreElenco; color: Tema.pericolo }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4
                    model: finestra.dispositivi
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: 60
                        radius: 10
                        color: modelData.id === finestra.scelto ? (Tema.chiaro ? "#FFFFFF" : "#34363D") : (area.containsMouse ? (Tema.chiaro ? "#F7F7F9" : "#2B2D33") : "transparent")
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 10; spacing: 10
                            Rectangle {
                                Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 19
                                color: modelData.posizione ? Tema.accento : (Tema.chiaro ? "#D5D5DB" : "#45474F")
                                IconaDispositivo { anchors.centerIn: parent; tipo: modelData.tipo; icona: modelData.icona; lato: 22; colore: "#FFFFFF" }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 1
                                Testo { Layout.fillWidth: true; text: modelData.nome; font.weight: Font.DemiBold; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                                Testo { Layout.fillWidth: true; text: modelData.stato + (modelData.bloccato ? " · 🔒" : ""); secondario: true; font.pointSize: Tema.fontDimensione - 1; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                            }
                        }
                        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: finestra.scegli(modelData.id, true) }
                    }
                    Testo { anchors.centerIn: parent; visible: !finestra.caricando && finestra.dispositivi.length === 0 && !finestra.erroreElenco; secondario: true; width: parent.width - 20; horizontalAlignment: Text.AlignHCenter
                            text: I18n.t("Nessun dispositivo ancora. Accedi al Solid ID anche sugli altri computer e telefoni.") }
                }
                Separatore { Layout.fillWidth: true }
                RowLayout {
                    Layout.fillWidth: true
                    Testo { Layout.fillWidth: true; text: finestra.utente.nome || finestra.utente.email; elide: Text.ElideRight; wrapMode: Text.NoWrap; secondario: true }
                    Pulsante { text: I18n.t("Account"); onClicked: ponte.chiama0("apriImpostazioni") }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Mappa {
                id: mappa
                anchors.fill: parent
                segnaposti: finestra.dispositivi.filter(function (d) { return d.posizione }).map(function (d) {
                    return { id: d.id, lat: d.lat, lon: d.lon, nome: d.nome, tipo: d.tipo, icona: d.icona, precisione: d.precisione, scelto: d.id === finestra.scelto }
                })
                onSegnapostoScelto: function (ident) { finestra.scegli(ident, false) }
            }

            // Scheda del dispositivo scelto
            Rectangle {
                visible: finestra.dispositivoScelto !== null
                anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 16
                width: 330
                height: scheda.implicitHeight + 28
                radius: 16
                color: Tema.chiaro ? "#F7FFFFFF" : "#F2232428"
                border.color: Tema.bordo
                ColumnLayout {
                    id: scheda
                    anchors.fill: parent; anchors.margins: 14
                    spacing: 8
                    readonly property var d: finestra.dispositivoScelto || ({})
                    Titolo { livello: 2; text: scheda.d.nome || ""; Layout.fillWidth: true; elide: Text.ElideRight }
                    Testo {
                        Layout.fillWidth: true; secondario: true
                        text: !scheda.d.posizione ? I18n.t("Posizione non disponibile")
                              : I18n.t("Posizione") + " " + (scheda.d.quandoPosizione || "") + " · "
                                + (scheda.d.fonte === "gps" ? I18n.t("GPS") : scheda.d.fonte === "wifi" ? I18n.t("dalle reti Wi-Fi") : I18n.t("approssimativa (città)"))
                                + (scheda.d.precisione ? " · ±" + (scheda.d.precisione >= 1000 ? Math.round(scheda.d.precisione / 1000) + " km" : Math.round(scheda.d.precisione) + " m") : "")
                    }
                    Testo { Layout.fillWidth: true; visible: !!scheda.d.modello; text: scheda.d.modello || ""; secondario: true; font.pointSize: Tema.fontDimensione - 1 }
                    Testo { Layout.fillWidth: true; visible: scheda.d.trova === false; color: Tema.pericolo; text: I18n.t("«Dov'è» è spento su questo dispositivo: non riceverà i comandi.") }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2; columnSpacing: 8; rowSpacing: 8
                        Pulsante {
                            Layout.fillWidth: true; principale: true; icona: "audio-volume-high"
                            text: finestra.comandoTipo === "suona" && finestra.statoComando.indexOf("🔊") >= 0 ? I18n.t("Ferma il suono") : I18n.t("Fai suonare")
                            onClicked: finestra.invia(text === I18n.t("Ferma il suono") ? "ferma" : "suona")
                        }
                        Pulsante { Layout.fillWidth: true; icona: "system-lock-screen"; text: scheda.d.tipo === "telefono" ? I18n.t("Modalità smarrito…") : I18n.t("Blocca…"); onClicked: dialogoBlocco.open() }
                        Pulsante { Layout.fillWidth: true; icona: "find-location"; text: I18n.t("Aggiorna posizione"); onClicked: finestra.invia("posizione") }
                        Pulsante { Layout.fillWidth: true; icona: "mark-location"; text: I18n.t("Indicazioni"); enabled: !!scheda.d.posizione; onClicked: ponte.chiama("indicazioni", [scheda.d.lat, scheda.d.lon]) }
                    }
                    Pulsante { Layout.fillWidth: true; visible: scheda.d.tipo === "telefono"; pericoloso: true; icona: "edit-delete"; text: I18n.t("Inizializza a distanza…"); onClicked: dialogoCancella.open() }
                    Testo { Layout.fillWidth: true; visible: finestra.statoComando !== ""; text: finestra.statoComando; font.weight: Font.DemiBold }
                }
            }
        }
    }

    Dialog {
        id: dialogoBlocco
        anchors.centerIn: parent
        modal: true
        readonly property bool telefono: !!finestra.dispositivoScelto && finestra.dispositivoScelto.tipo === "telefono"
        title: (telefono ? I18n.t("Modalità smarrito:") : I18n.t("Blocca")) + " " + (finestra.dispositivoScelto ? finestra.dispositivoScelto.nome : "")
        standardButtons: Dialog.Cancel | Dialog.Ok
        ColumnLayout {
            spacing: 10
            width: 380
            Testo { Layout.fillWidth: true; wrapMode: Text.Wrap
                    text: dialogoBlocco.telefono ? I18n.t("Il telefono si blocca subito e per sbloccarlo serve la password del tuo Solid ID, non basta il codice. Il messaggio compare sullo schermo per chi lo trova.")
                                                 : I18n.t("Lo schermo si blocca subito e mostra questo messaggio a chi lo trova.") }
            CampoTesto { id: messaggioBlocco; Layout.fillWidth: true; placeholderText: I18n.t("Es. Se lo trovi chiama il 333 1234567"); maximumLength: 200 }
        }
        onAccepted: { finestra.invia(dialogoBlocco.telefono ? "perso" : "blocca", messaggioBlocco.text); messaggioBlocco.text = "" }
    }

    Dialog {
        id: dialogoCancella
        anchors.centerIn: parent
        modal: true
        title: I18n.t("Cancellare") + " " + (finestra.dispositivoScelto ? finestra.dispositivoScelto.nome : "") + "?"
        standardButtons: Dialog.Cancel | Dialog.Ok
        Testo {
            width: 380; wrapMode: Text.Wrap
            text: I18n.t("Appena è collegato a Internet, il telefono cancella tutti i dati e riparte come nuovo. Non si può tornare indietro. Il blocco di attivazione resta: per usarlo servirà il tuo Solid ID.")
        }
        onAccepted: finestra.invia("cancella")
    }
}
