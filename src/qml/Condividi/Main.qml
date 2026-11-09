// «Condividi»: visibilità del computer, dispositivi vicini (Quick Share, AirDrop,
// LocalSend), codice QR e stato di ogni sistema (diagnosi).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Condivisione Vicina")
    width: 600
    height: 680
    property var file: ponte.chiama0("file")
    readonly property bool ricevi: file.length === 0
    property var dispositivi: []
    property var qr: null
    property string inviato: ""
    property string visibilita: ponte.chiama0("visibilita")
    property var diagnosi: []
    property bool mostraDiagnosi: false

    function imposta(m) { ponte.chiama("impostaVisibilita", [m]); visibilita = m; aggiornaDiagnosi() }
    function aggiornaDiagnosi() { ponte.avvia("diagnosi", [], "diagnosi") }

    Component.onCompleted: {
        // Come AirDrop su Mac: aprendo la finestra il computer diventa visibile per 10 minuti
        if (visibilita === "nessuno" || visibilita === "associati") imposta("tutti10")
        ponte.chiama0("scopri")
        aggiornaDiagnosi()
    }
    Timer { interval: 1500; running: !finestra.ricevi && schede.currentIndex === 0; repeat: true; triggeredOnStart: true; onTriggered: finestra.dispositivi = ponte.chiama0("dispositivi") }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: finestra.visibilita = ponte.chiama0("visibilita") }
    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id === "qr") finestra.qr = r
            else if (id === "diagnosi") finestra.diagnosi = r
        }
    }
    onClosing: ponte.chiama0("fermaQr")

    function iconaTipo(t) { return t === "computer" ? "computer" : (t === "tablet" ? "tablet" : "phone") }
    function nomeBackend(b) { return { quickshare: "Quick Share", airdrop: "AirDrop (beta)", localsend: "LocalSend", qr: "QR" }[b] || b }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        ColumnLayout {
            width: parent.width
            spacing: 14
            Item { Layout.preferredHeight: 4 }
            Titolo {
                Layout.leftMargin: 22; Layout.rightMargin: 22
                livello: 2
                text: finestra.ricevi ? I18n.t("Ricevi file da un telefono o da un computer")
                      : (finestra.file.length === 1 ? I18n.t("Condividi") + " «" + finestra.file[0].split("/").pop() + "»"
                                                    : I18n.t("Condividi") + " " + finestra.file.length + " " + I18n.t("file"))
            }

            // ── Visibilità ─────────────────────────────────────────────────
            Scheda {
                Layout.fillWidth: true
                Layout.leftMargin: 22; Layout.rightMargin: 22
                margine: 14
                ColumnLayout {
                    width: parent.width
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        Rectangle { width: 10; height: 10; radius: 5; color: finestra.visibilita === "nessuno" ? "#8E8E93" : "#34C759" }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold
                            text: finestra.visibilita === "nessuno" ? I18n.t("Nascosto: telefoni e computer non vedono questo PC")
                                  : finestra.visibilita === "tutti10" ? I18n.t("Visibile a tutti per 10 minuti")
                                  : finestra.visibilita === "tutti" ? I18n.t("Sempre visibile a tutti")
                                  : I18n.t("Visibile solo ai dispositivi già associati")
                        }
                    }
                    Row {
                        spacing: 6
                        Repeater {
                            model: [{ t: I18n.t("Nascosto"), v: "nessuno" }, { t: I18n.t("Tutti per 10 minuti"), v: "tutti10" }, { t: I18n.t("Sempre visibile"), v: "tutti" }]
                            Pulsante { text: modelData.t; principale: finestra.visibilita === modelData.v; onClicked: finestra.imposta(modelData.v) }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: finestra.ricevi
                        wrapMode: Text.Wrap
                        color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12; lineHeight: 1.2
                        text: I18n.t("Sul telefono apri la foto o il file → Condividi.") + "\n"
                              + "• Android: " + I18n.t("Quick Share, poi scegli questo computer (stessa rete Wi-Fi, Bluetooth acceso).") + "\n"
                              + "• iPhone: " + I18n.t("AirDrop (serve una scheda Wi-Fi compatibile, vedi Stato), oppure usa il Codice QR qui sotto.") + "\n"
                              + I18n.t("I file arrivano nella cartella Scaricati › Ricevuti.")
                    }
                }
            }

            // ── Invio a un dispositivo / Codice QR ─────────────────────────
            TabBar {
                id: schede
                Layout.fillWidth: true
                Layout.leftMargin: 22; Layout.rightMargin: 22
                currentIndex: finestra.ricevi ? 1 : 0
                TabButton { text: I18n.t("Dispositivi vicini"); enabled: !finestra.ricevi }
                TabButton { text: I18n.t("Codice QR") }
                onCurrentIndexChanged: if (currentIndex === 1 && !finestra.qr) ponte.avvia("qr", [false], "qr")
                Component.onCompleted: if (currentIndex === 1) ponte.avvia("qr", [false], "qr")
            }
            StackLayout {
                currentIndex: schede.currentIndex
                Layout.fillWidth: true
                Layout.leftMargin: 22; Layout.rightMargin: 22
                Layout.preferredHeight: 330

                ColumnLayout {
                    spacing: 8
                    BarraProgresso { Layout.fillWidth: true; indeterminate: true }
                    Testo { secondario: true; Layout.fillWidth: true; text: I18n.t("Ricerca in corso… Sul telefono metti la ricezione su «Tutti»: Quick Share su Android, AirDrop su «Tutti per 10 minuti» su iPhone, oppure apri LocalSend.") }
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
                    Testo { visible: !!(finestra.qr && finestra.qr.errore); color: Tema.pericolo; text: finestra.qr ? (finestra.qr.errore || "") : ""; Layout.fillWidth: true }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 20
                        visible: !!(finestra.qr && !finestra.qr.errore)
                        ColumnLayout {
                            visible: !!(finestra.qr && finestra.qr.qrWifi)
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
                        visible: !!(finestra.qr && !finestra.qr.errore)
                        text: I18n.t("Funziona con qualsiasi telefono, anche iPhone, senza installare nulla. Vale per un solo telefono, in questa rete, per 10 minuti.")
                    }
                    Pulsante {
                        Layout.alignment: Qt.AlignHCenter
                        text: I18n.t("Nessuna rete Wi-Fi in comune? Crea un hotspot")
                        onClicked: { finestra.qr = null; ponte.avvia("qr", [true], "qr") }
                    }
                }
            }

            // ── Stato (diagnosi) ───────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 22; Layout.rightMargin: 22
                Text { text: I18n.t("Stato"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.fillWidth: true }
                Pulsante { text: I18n.t("Aggiorna"); onClicked: finestra.aggiornaDiagnosi() }
            }
            Scheda {
                Layout.fillWidth: true
                Layout.leftMargin: 22; Layout.rightMargin: 22
                Layout.bottomMargin: 22
                margine: 0
                implicitHeight: colonnaStato.implicitHeight
                Column {
                    id: colonnaStato
                    width: parent.width
                    Repeater {
                        model: finestra.diagnosi
                        Item {
                            required property var modelData
                            required property int index
                            width: colonnaStato.width
                            height: Math.max(44, testiStato.implicitHeight + 16)
                            Rectangle { visible: index > 0; x: 14; width: parent.width - 28; height: 1; color: Tema.chiaro ? "#E5E5EA" : "#14FFFFFF" }
                            Rectangle { x: 14; anchors.verticalCenter: parent.verticalCenter; width: 10; height: 10; radius: 5; color: modelData.ok ? "#34C759" : "#FF9F0A" }
                            Column {
                                id: testiStato
                                x: 34; width: parent.width - 48
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                                Text { width: parent.width; wrapMode: Text.Wrap; text: modelData.motivo; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
                            }
                        }
                    }
                }
            }
        }
    }
}
