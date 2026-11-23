// Desktop remoto: in alto «Collegati a un altro computer» (indirizzo o computer trovati nella
// rete, RDP o VNC), sotto «Questo computer» con l'interruttore, l'indirizzo, l'utente e la password.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Desktop remoto")
    width: 720
    height: 640
    minimumWidth: 520
    minimumHeight: 520

    property var stato: ({})
    property var trovati: []
    property bool cercando: false

    function aggiorna() { stato = ponte.chiama0("stato") }
    function cerca() { cercando = true; ponte.avvia("cerca", [], "cerca") }
    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id === "cerca") { finestra.trovati = r; finestra.cercando = false }
            else if (id === "collega") { avviso.mostra(r.messaggio); finestra.aggiorna() }
            else if (id === "consenti" || id === "password") finestra.stato = r
        }
    }
    Component.onCompleted: { aggiorna(); cerca() }

    Flickable {
        anchors.fill: parent
        contentHeight: colonna.implicitHeight + 48
        clip: true
        ScrollBar.vertical: ScrollBar {}

        ColumnLayout {
            id: colonna
            x: 24; y: 24
            width: finestra.width - 48
            spacing: 14

            RowLayout {
                spacing: 14
                Rectangle {
                    width: 48; height: 48; radius: 12
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#5B8CFF" }
                        GradientStop { position: 1; color: "#3557D6" }
                    }
                    // schermo con una freccia: il simbolo dell'app
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            var g = getContext("2d"); g.reset(); g.strokeStyle = "white"; g.fillStyle = "white"; g.lineWidth = 2.4; g.lineJoin = "round"
                            g.strokeRect(11, 13, 26, 17)
                            g.beginPath(); g.moveTo(19, 36); g.lineTo(29, 36); g.stroke()
                            g.beginPath(); g.moveTo(24, 30); g.lineTo(24, 36); g.stroke()
                            g.beginPath(); g.moveTo(20, 25); g.lineTo(27, 18); g.stroke()
                            g.beginPath(); g.moveTo(28, 17); g.lineTo(28, 23); g.lineTo(22, 17); g.closePath(); g.fill()
                        }
                    }
                }
                ColumnLayout {
                    spacing: 2
                    Text { text: I18n.t("Desktop remoto"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 22; font.weight: Font.Bold }
                    Text { text: I18n.t("Usa un altro computer da qui, o lascia che un altro computer usi questo"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13 }
                }
            }

            // ── Collegati a un altro computer ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: collegati.implicitHeight + 32
                radius: 14; color: Tema.superficie; border.color: Tema.bordo
                ColumnLayout {
                    id: collegati
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 16
                    spacing: 10
                    Text { text: I18n.t("Collegati a un altro computer"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.DemiBold }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        CampoTesto { id: indirizzo; Layout.fillWidth: true; placeholderText: I18n.t("Indirizzo, es. 192.168.1.20"); onAccepted: vai.clicked() }
                        ComboBox {
                            id: protocollo
                            Layout.preferredWidth: 140
                            textRole: "t"; valueRole: "v"
                            model: [{ t: I18n.t("Automatico"), v: "auto" }, { t: "RDP", v: "rdp" }, { t: "VNC", v: "vnc" }]
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        CampoTesto { id: utente; Layout.fillWidth: true; placeholderText: I18n.t("Utente sull'altro computer (se serve)") }
                        Pulsante {
                            id: vai
                            text: I18n.t("Collega"); principale: true
                            onClicked: ponte.avvia("collega", [indirizzo.text, protocollo.currentValue, utente.text], "collega")
                        }
                    }
                    Text {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap
                        text: I18n.t("La password la chiede la finestra del collegamento. Sull'altro computer va attivato il desktop remoto (RDP) o la condivisione schermo (VNC).")
                        color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                    }

                    // Computer trovati e recenti
                    RowLayout {
                        Layout.topMargin: 6
                        Text { text: I18n.t("Nella rete"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold; Layout.fillWidth: true }
                        BusyIndicator { running: finestra.cercando; visible: running; implicitWidth: 18; implicitHeight: 18 }
                        Text {
                            text: I18n.t("Cerca di nuovo"); color: Tema.accento; font.family: Tema.font; font.pixelSize: 12
                            visible: !finestra.cercando
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: finestra.cerca() }
                        }
                    }
                    Text {
                        visible: !finestra.cercando && finestra.trovati.length === 0
                        text: I18n.t("Nessun computer con il desktop remoto attivo in questa rete")
                        color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13
                    }
                    Repeater {
                        model: finestra.trovati.concat((finestra.stato.recenti || []).filter(function (r) {
                            return !finestra.trovati.some(function (t) { return t.ip === r.indirizzo })
                        }).map(function (r) { return { nome: r.indirizzo, ip: r.indirizzo, protocolli: [r.protocollo], recente: true, utente: r.utente } }))
                        Rectangle {
                            Layout.fillWidth: true
                            height: 46; radius: 10
                            color: sopra.hovered ? Tema.superficieAlta : "transparent"
                            HoverHandler { id: sopra }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                                spacing: 10
                                Text { text: "🖥"; font.pixelSize: 18 }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 0
                                    Text { text: modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }
                                    Text {
                                        text: (modelData.recente ? I18n.t("Recente") + " · " : modelData.ip + " · ") + modelData.protocolli.map(function (p) { return p.toUpperCase() }).join(", ")
                                        color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11
                                    }
                                }
                                Pulsante {
                                    text: I18n.t("Collega")
                                    onClicked: ponte.avvia("collega", [modelData.ip, modelData.protocolli[0], modelData.utente || utente.text], "collega")
                                }
                            }
                        }
                    }
                }
            }

            // ── Questo computer ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: questo.implicitHeight + 32
                radius: 14; color: Tema.superficie; border.color: Tema.bordo
                ColumnLayout {
                    id: questo
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 16
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            Text { text: I18n.t("Consenti ad altri di usare questo computer"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.DemiBold }
                            Text {
                                Layout.fillWidth: true; wrapMode: Text.WordWrap
                                text: I18n.t("Un altro computer della rete vede questo schermo e lo usa, con utente e password. Si spegne quando vuoi.")
                                color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                            }
                        }
                        Interruttore {
                            checked: finestra.stato.attivo === true
                            onToggled: ponte.avvia("consenti", [checked], "consenti")
                        }
                    }
                    GridLayout {
                        visible: finestra.stato.attivo === true
                        Layout.fillWidth: true
                        columns: 2; columnSpacing: 14; rowSpacing: 6
                        Text { text: I18n.t("Nome"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13 }
                        Text { text: finestra.stato.nome || ""; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                        Text { text: I18n.t("Indirizzo"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13 }
                        Text { text: (finestra.stato.indirizzo || "—") + ":" + (finestra.stato.porta || 5900) + "  (VNC)"; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                        Text { text: I18n.t("Utente"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13 }
                        Text { text: finestra.stato.utente || ""; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                        Text { text: I18n.t("Password"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13 }
                        RowLayout {
                            spacing: 10
                            Text { text: finestra.stato.password || ""; color: Tema.testo; font.family: "monospace"; font.pixelSize: 14; font.weight: Font.DemiBold }
                            Text {
                                text: I18n.t("Cambia"); color: Tema.accento; font.family: Tema.font; font.pixelSize: 12
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ponte.avvia("nuovaPassword", [], "password") }
                            }
                        }
                        Text { text: I18n.t("Stato"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13 }
                        Text {
                            text: finestra.stato.inCorso ? I18n.t("Pronto: dall'altro computer apri un programma VNC e scrivi l'indirizzo") : I18n.t("Avvio in corso…")
                            color: finestra.stato.inCorso ? "#22C55E" : Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13
                            Layout.fillWidth: true; wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
    Timer { interval: 3000; repeat: true; running: finestra.stato.attivo === true && !finestra.stato.inCorso; onTriggered: finestra.aggiorna() }
    Messaggio { id: avviso }
}
