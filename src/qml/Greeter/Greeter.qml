// Schermata di accesso a tutto schermo.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Window {
    id: finestra
    visible: true
    visibility: Window.FullScreen
    color: Tema.sfondo
    property var utenti: greeter.chiama0("utenti")
    property string utente: {
        var ultimo = greeter.chiama0("ultimoUtente")
        for (var i = 0; i < utenti.length; i++) if (utenti[i].utente === ultimo) return ultimo
        return utenti.length ? utenti[0].utente : ""
    }
    property bool inCorso: false

    function accedi() {
        if (!password.text) return
        inCorso = true
        errore.text = ""
        greeter.avvia("accedi", [utente, password.text], "accesso")
    }
    Connections {
        target: greeter
        function onCompletato(id, r) {
            finestra.inCorso = false
            if (r.ok) greeter.chiama0("esci")
            else { errore.text = r.messaggio; password.text = ""; password.forceActiveFocus() }
        }
    }

    Image {
        anchors.fill: parent
        source: "file:///usr/share/backgrounds/" + Tema.idSistema + "/predefinito.png"
        fillMode: Image.PreserveAspectCrop
        Rectangle { anchors.fill: parent; color: "#66000000" }
    }

    Testo {
        id: ora
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.12
        font.pointSize: 48
        font.weight: Font.Light
        color: "#FFFFFF"
        function aggiorna() { text = Qt.formatTime(new Date(), "HH:mm"); data.text = Qt.formatDate(new Date(), "dddd d MMMM") }
        Timer { interval: 10000; running: true; repeat: true; triggeredOnStart: true; onTriggered: ora.aggiorna() }
    }
    Testo { id: data; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: ora.bottom; color: "#E6FFFFFF"; font.pointSize: Tema.fontDimensione + 4 }

    Rectangle {
        anchors.centerIn: parent
        width: 380
        height: colonna.implicitHeight + 48
        radius: 18
        color: "#CC" + Tema.superficie.substring(1)
        border.color: Tema.bordo
        ColumnLayout {
            id: colonna
            anchors.fill: parent
            anchors.margins: 24
            spacing: 14
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 88; height: 88; radius: 44
                color: Tema.accento
                Testo {
                    anchors.centerIn: parent
                    color: "#FFFFFF"
                    font.pointSize: 30
                    text: finestra.utente ? finestra.utente.charAt(0).toUpperCase() : "?"
                }
            }
            Scelta {
                Layout.fillWidth: true
                model: finestra.utenti.map(function (u) { return { testo: u.nome, valore: u.utente } })
                currentIndex: Math.max(0, finestra.utenti.findIndex(function (u) { return u.utente === finestra.utente }))
                onActivated: finestra.utente = currentValue
                visible: finestra.utenti.length > 1
            }
            Titolo {
                Layout.alignment: Qt.AlignHCenter
                livello: 2
                visible: finestra.utenti.length <= 1
                text: finestra.utenti.length ? finestra.utenti[0].nome : ""
            }
            CampoTesto {
                id: password
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: I18n.t("Password")
                enabled: !finestra.inCorso
                focus: true
                onAccepted: finestra.accedi()
            }
            Testo { id: errore; color: Tema.pericolo; visible: text !== ""; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
            Pulsante {
                Layout.fillWidth: true
                principale: true
                text: finestra.inCorso ? I18n.t("Accesso in corso…") : I18n.t("Accedi")
                enabled: !finestra.inCorso
                onClicked: finestra.accedi()
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 10
        Pulsante { icona: "system-reboot"; text: I18n.t("Riavvia"); onClicked: greeter.chiama0("riavvia") }
        Pulsante { icona: "system-shutdown"; text: I18n.t("Spegni"); onClicked: greeter.chiama0("spegni") }
    }
    Testo {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 24
        color: "#B3FFFFFF"
        text: Tema.nomeSistema + " " + Tema.versione
    }
}
