// Schermata di accesso a tutto schermo, in stile Mac (come la schermata di blocco):
// in alto data e ora grandi, in basso la foto, il nome e — solo se serve — la password.
// Più persone: le foto una accanto all'altra, si sceglie con un clic.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Window {
    id: finestra
    visible: true
    visibility: Window.FullScreen
    color: "#000000"
    property var utenti: greeter.chiama0("utenti")
    property string utente: {
        var ultimo = greeter.chiama0("ultimoUtente")
        for (var i = 0; i < utenti.length; i++) if (utenti[i].utente === ultimo) return ultimo
        return utenti.length ? utenti[0].utente : ""
    }
    readonly property var scelto: {
        for (var i = 0; i < utenti.length; i++) if (utenti[i].utente === utente) return utenti[i]
        return ({ nome: "", iniziali: "?", foto: "", password: true })
    }
    readonly property bool serve: scelto.password !== false
    property bool inCorso: false

    function accedi() {
        if (inCorso || !utente || (serve && !password.text)) return
        inCorso = true
        errore.text = ""
        greeter.avvia("accedi", [utente, serve ? password.text : ""], "accesso")
    }
    onUtenteChanged: { password.text = ""; errore.text = ""; password.forceActiveFocus() }
    Connections {
        target: greeter
        function onCompletato(id, r) {
            finestra.inCorso = false
            if (r.ok) greeter.chiama0("esci")
            else { errore.text = r.messaggio; password.text = ""; password.forceActiveFocus(); scuoti.restart() }
        }
    }

    Image {
        anchors.fill: parent
        // Lo sfondo della persona scelta (lo stesso della sua scrivania), non uno fisso
        source: finestra.utente ? greeter.chiama("sfondo", [finestra.utente]) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
    }
    // Leggera ombra in alto e in basso per leggere bene ora e nome su ogni sfondo
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#47000000" }
            GradientStop { position: 0.38; color: "#00000000" }
            GradientStop { position: 0.62; color: "#00000000" }
            GradientStop { position: 1.0; color: "#61000000" }
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 64
        Text {
            id: data
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#EBFFFFFF"
            font.family: Tema.font
            font.pixelSize: 22
            font.weight: Font.DemiBold
        }
        Text {
            id: ora
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#E6FFFFFF"
            font.family: Tema.font
            font.pixelSize: 116
            font.weight: Font.Bold
        }
        Timer {
            interval: 5000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: {
                var d = new Date()
                ora.text = Qt.formatTime(d, "HH:mm")
                // Nomi di giorno e mese nella lingua del sistema (italiano se non è impostata)
                var lingua = Qt.locale().name === "C" || Qt.locale().name === "en_US" ? Qt.locale("it_IT") : Qt.locale()
                var g = d.toLocaleDateString(lingua, "dddd d MMMM")
                data.text = g.charAt(0).toUpperCase() + g.slice(1)
            }
        }
    }

    Column {
        id: basso
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 72
        spacing: 12

        // Più persone: tutte le foto in fila, la scelta è più grande
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 28
            Repeater {
                model: finestra.utenti
                Column {
                    required property var modelData
                    readonly property bool attivo: modelData.utente === finestra.utente
                    spacing: 8
                    visible: attivo || finestra.utenti.length > 1
                    opacity: attivo ? 1 : 0.7
                    FotoAccount {
                        anchors.horizontalCenter: parent.horizontalCenter
                        lato: parent.attivo ? 92 : 64
                        account: parent.modelData
                        Behavior on lato { NumberAnimation { duration: 150 } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: finestra.utente = parent.parent.modelData.utente }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: parent.modelData.nome
                        color: "#FFFFFF"
                        font.family: Tema.font
                        font.pixelSize: parent.attivo ? 17 : 14
                        font.weight: Font.DemiBold
                        style: Text.Raised; styleColor: "#55000000"
                    }
                }
            }
        }

        // Campo della password a pillola con la freccia (solo se l'account ne ha una)
        Rectangle {
            id: pillola
            anchors.horizontalCenter: parent.horizontalCenter
            visible: finestra.serve
            width: 250; height: 34; radius: 17
            color: "#38FFFFFF"
            TextField {
                id: password
                anchors.left: parent.left; anchors.leftMargin: 14
                anchors.right: freccia.left; anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                placeholderText: I18n.t("Inserisci la password")
                placeholderTextColor: "#C8FFFFFF"
                color: "#FFFFFF"
                font.family: Tema.font
                font.pixelSize: 14
                background: Item {}
                enabled: !finestra.inCorso
                focus: true
                onAccepted: finestra.accedi()
            }
            Rectangle {
                id: freccia
                anchors.right: parent.right; anchors.rightMargin: 3
                anchors.verticalCenter: parent.verticalCenter
                width: 28; height: 28; radius: 14
                color: areaFreccia.containsMouse ? Tema.accento : "#4DFFFFFF"
                opacity: password.text ? 1 : 0.5
                Text { anchors.centerIn: parent; text: finestra.inCorso ? "…" : "→"; color: "#FFFFFF"; font.pixelSize: 16; font.weight: Font.Bold }
                MouseArea { id: areaFreccia; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: finestra.accedi() }
            }
            SequentialAnimation {
                id: scuoti
                NumberAnimation { target: pillola; property: "anchors.horizontalCenterOffset"; to: -10; duration: 50 }
                NumberAnimation { target: pillola; property: "anchors.horizontalCenterOffset"; to: 10; duration: 70 }
                NumberAnimation { target: pillola; property: "anchors.horizontalCenterOffset"; to: -6; duration: 60 }
                NumberAnimation { target: pillola; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
            }
        }
        // Account senza password: un solo pulsante «Entra» (o Invio)
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !finestra.serve
            width: 120; height: 34; radius: 17
            color: areaEntra.containsMouse ? Tema.accento : "#3DFFFFFF"
            Text { anchors.centerIn: parent; text: finestra.inCorso ? I18n.t("Accesso…") : I18n.t("Entra"); color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.DemiBold }
            MouseArea { id: areaEntra; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: finestra.accedi() }
        }
        Text {
            id: errore
            anchors.horizontalCenter: parent.horizontalCenter
            visible: text !== ""
            color: "#FFD5D5"
            font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold
            style: Text.Raised; styleColor: "#66000000"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !finestra.serve && errore.text === ""
            text: I18n.t("Premi Invio per entrare")
            color: "#D1FFFFFF"
            font.family: Tema.font; font.pixelSize: 12
        }
    }
    // Invio funziona anche quando non serve la password
    Shortcut { sequences: ["Return", "Enter"]; enabled: !finestra.serve; onActivated: finestra.accedi() }
    Shortcut { sequence: "Left"; enabled: finestra.utenti.length > 1 && !password.activeFocus; onActivated: finestra.cambia(-1) }
    Shortcut { sequence: "Right"; enabled: finestra.utenti.length > 1 && !password.activeFocus; onActivated: finestra.cambia(1) }
    function cambia(d) {
        for (var i = 0; i < utenti.length; i++) if (utenti[i].utente === utente) { utente = utenti[(i + d + utenti.length) % utenti.length].utente; return }
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 28
        spacing: 22
        Repeater {
            model: [{ icona: "system-reboot", testo: I18n.t("Riavvia"), azione: "riavvia" }, { icona: "system-shutdown", testo: I18n.t("Spegni"), azione: "spegni" }]
            Column {
                required property var modelData
                spacing: 4
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 40; height: 40; radius: 20
                    color: areaPotenza.containsMouse ? "#59FFFFFF" : "#33FFFFFF"
                    // simboli disegnati: la schermata di accesso non sempre trova il tema delle icone
                    Canvas {
                        anchors.centerIn: parent; width: 22; height: 22
                        readonly property bool spegni: parent.parent.modelData.azione === "spegni"
                        onPaint: {
                            var g = getContext("2d"); g.reset()
                            g.strokeStyle = "white"; g.fillStyle = "white"; g.lineWidth = 2.2; g.lineCap = "round"
                            if (spegni) {
                                g.beginPath(); g.arc(11, 12, 7.5, Math.PI * 1.68, Math.PI * 1.32 + Math.PI * 2, false); g.stroke()
                                g.beginPath(); g.moveTo(11, 2.5); g.lineTo(11, 10); g.stroke()
                            } else {
                                g.beginPath(); g.arc(11, 11, 7.5, Math.PI * 0.1, Math.PI * 1.65); g.stroke()
                                g.beginPath(); g.moveTo(19.5, 2.5); g.lineTo(19, 9); g.lineTo(12.5, 7.5); g.closePath(); g.fill()
                            }
                        }
                    }
                    MouseArea { id: areaPotenza; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: greeter.chiama0(parent.parent.modelData.azione) }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.modelData.testo; color: "#E6FFFFFF"; font.family: Tema.font; font.pixelSize: 12 }
            }
        }
    }
    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 28
        color: "#B3FFFFFF"
        font.family: Tema.font
        font.pixelSize: 12
        text: Tema.nomeSistema + " " + Tema.versione
    }
}
