// «Condividi»: dispositivi vicini (Quick Share, AirDrop, LocalSend) oppure codice QR.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Condivisione Vicina")
    width: 560
    height: 600
    property var file: ponte.chiama0("file")
    property var dispositivi: []
    property var qr: null
    property string inviato: ""
    property bool attivo: ponte.chiama0("attivo")

    Component.onCompleted: { ponte.chiama0("scopri"); if (file.length === 0) schede.currentIndex = 1 }
    Timer { interval: 1500; running: schede.currentIndex === 0; repeat: true; triggeredOnStart: true; onTriggered: finestra.dispositivi = ponte.chiama0("dispositivi") }
    Connections {
        target: ponte
        function onCompletato(id, r) { if (id === "qr") finestra.qr = r }
    }
    onClosing: ponte.chiama0("fermaQr")

    function iconaTipo(t) { return t === "computer" ? "computer" : (t === "tablet" ? "tablet" : "phone") }
    function nomeBackend(b) { return { quickshare: "Quick Share", airdrop: "AirDrop (beta)", localsend: "LocalSend", qr: "QR" }[b] || b }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12
        Titolo {
            livello: 2
            text: finestra.file.length === 0 ? I18n.t("Ricevi file da un telefono")
                  : (finestra.file.length === 1 ? I18n.t("Condividi") + " «" + finestra.file[0].split("/").pop() + "»"
                                                : I18n.t("Condividi") + " " + finestra.file.length + " " + I18n.t("file"))
        }
        Testo { visible: !finestra.attivo; color: Tema.pericolo; text: I18n.t("Il servizio Condivisione Vicina non è attivo.") }
        TabBar {
            id: schede
            Layout.fillWidth: true
            TabButton { text: I18n.t("Dispositivi vicini"); enabled: finestra.file.length > 0 }
            TabButton { text: I18n.t("Codice QR") }
            onCurrentIndexChanged: if (currentIndex === 1 && !finestra.qr) ponte.avvia("qr", [false], "qr")
        }
        StackLayout {
            currentIndex: schede.currentIndex
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                spacing: 8
                BarraProgresso { Layout.fillWidth: true; indeterminate: true }
                Testo { secondario: true; Layout.fillWidth: true; text: I18n.t("Ricerca in corso… Sul telefono apri il menu Condividi: Quick Share (Android), AirDrop su «Tutti per 10 minuti» (iPhone) oppure l'app LocalSend.") }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: finestra.dispositivi
                    delegate: VoceElenco {
                        width: ListView.view.width
                        icona: finestra.iconaTipo(modelData.tipo)
                        titolo: modelData.nome
                        sottotitolo: finestra.inviato === modelData.id ? I18n.t("Invio avviato: conferma sul dispositivo") : finestra.nomeBackend(modelData.backend)
                        onClicked: { ponte.chiama("invia", [modelData.id]); finestra.inviato = modelData.id }
                    }
                    Testo { anchors.centerIn: parent; visible: parent.count === 0; secondario: true; text: I18n.t("Nessun dispositivo trovato per ora") }
                }
            }

            ColumnLayout {
                spacing: 10
                BarraProgresso { Layout.fillWidth: true; indeterminate: true; visible: finestra.qr === null }
                Testo { visible: finestra.qr && finestra.qr.errore; color: Tema.pericolo; text: finestra.qr ? (finestra.qr.errore || "") : ""; Layout.fillWidth: true }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 20
                    visible: finestra.qr && !finestra.qr.errore
                    ColumnLayout {
                        visible: finestra.qr && !!finestra.qr.qrWifi
                        Testo { text: "1. " + I18n.t("Collega il telefono"); Layout.alignment: Qt.AlignHCenter }
                        Rectangle { color: "#FFFFFF"; radius: 8; width: 190; height: 190; Image { anchors.fill: parent; anchors.margins: 6; source: finestra.qr && finestra.qr.qrWifi ? "file://" + finestra.qr.qrWifi : ""; sourceSize.width: 400 } }
                    }
                    ColumnLayout {
                        Testo { text: (finestra.qr && finestra.qr.qrWifi ? "2. " : "") + I18n.t("Inquadra con la fotocamera"); Layout.alignment: Qt.AlignHCenter }
                        Rectangle { color: "#FFFFFF"; radius: 8; width: 240; height: 240; Image { anchors.fill: parent; anchors.margins: 6; source: finestra.qr && finestra.qr.qr ? "file://" + finestra.qr.qr : ""; sourceSize.width: 480 } }
                    }
                }
                Testo {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    secondario: true
                    visible: finestra.qr && !finestra.qr.errore
                    text: I18n.t("Il codice vale per un solo telefono, solo in questa rete, e scade tra 10 minuti. Non serve installare nulla.")
                }
                Pulsante {
                    Layout.alignment: Qt.AlignHCenter
                    text: I18n.t("Nessuna rete Wi-Fi in comune? Crea un hotspot")
                    onClicked: { finestra.qr = null; ponte.avvia("qr", [true], "qr") }
                }
            }
        }
    }
}
