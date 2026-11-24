// Desktop remoto: in alto «Collegati a un altro computer» (indirizzo o un computer trovato nella
// rete, utente e password), sotto «Questo computer» con l'interruttore, l'indirizzo, l'utente e la
// password. Lo schermo di un computer SolidOS, Mac o Linux si apre qui dentro (SchermoRemoto);
// quello di un PC Windows in una finestra a parte.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import SolidUI
import SolidOS.Remoto 1.0

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
    property bool collegando: false
    property var remoto: null              // collegamento aperto qui dentro (VNC)
    property bool remotoPronto: false
    function collega() {
        if (!indirizzo.text.trim()) { avviso.mostra(I18n.t("Scrivi l'indirizzo dell'altro computer")); indirizzo.forceActiveFocus(); return }
        collegando = true
        ponte.avvia("collega", [indirizzo.text, "auto", utente.text, password.text], "collega")
    }
    function scollega() {
        schermo.chiudi()
        remoto = null; remotoPronto = false
        if (visibility === Window.FullScreen) showNormal()
    }

    function aggiorna() { stato = ponte.chiama0("stato") }
    function cerca() { cercando = true; ponte.avvia("cerca", [], "cerca") }
    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id === "cerca") { finestra.trovati = r; finestra.cercando = false }
            else if (id === "collega") {
                finestra.collegando = false
                finestra.aggiorna()
                if (r.ok && r.vnc) { finestra.remoto = { host: r.host, nome: r.host }; schermo.collega(r.host, r.porta, utente.text, password.text); password.text = "" }
                else { if (r.ok) password.text = ""; avviso.mostra(r.messaggio) }
            }
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
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2; columnSpacing: 10; rowSpacing: 8
                        Text { text: I18n.t("Indirizzo"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13 }
                        CampoTesto { id: indirizzo; Layout.fillWidth: true; placeholderText: I18n.t("es. 192.168.1.20, o tocca un computer qui sotto"); onAccepted: utente.forceActiveFocus() }
                        Text { text: I18n.t("Utente"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13 }
                        CampoTesto { id: utente; Layout.fillWidth: true; placeholderText: I18n.t("Il nome con cui entri nell'altro computer"); onAccepted: password.forceActiveFocus() }
                        Text { text: I18n.t("Password"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13 }
                        CampoTesto { id: password; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: I18n.t("La password dell'altro computer"); onAccepted: finestra.collega() }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true; wrapMode: Text.WordWrap
                            text: I18n.t("Sull'altro computer va attivata la condivisione dello schermo (SolidOS, Mac) o il Desktop remoto (Windows).")
                            color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                        }
                        BusyIndicator { visible: finestra.collegando; running: visible; Layout.preferredWidth: 24; Layout.preferredHeight: 24 }
                        Pulsante { id: vai; text: finestra.collegando ? I18n.t("Collegamento…") : I18n.t("Collega"); principale: true; enabled: !finestra.collegando; onClicked: finestra.collega() }
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
                                Simbolo { nome: "schermo"; lato: 20; colore: Tema.accento }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 0
                                    Text { text: modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }
                                    Text {
                                        text: (modelData.recente ? I18n.t("Recente") + " · " : modelData.ip + " · ") + modelData.protocolli.map(function (p) { return p.toUpperCase() }).join(", ")
                                        color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11
                                    }
                                }
                                Pulsante {
                                    text: I18n.t("Scegli")
                                    onClicked: { indirizzo.text = modelData.ip; if (modelData.utente) utente.text = modelData.utente; (utente.text ? password : utente).forceActiveFocus() }
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
    // ── Lo schermo dell'altro computer, dentro l'app ──
    Rectangle {
        anchors.fill: parent
        visible: !!finestra.remoto
        color: "#0B0C10"
        z: 10
        SchermoRemoto {
            id: schermo
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: barraRemoto.bottom; anchors.bottom: parent.bottom
            focus: !!finestra.remoto
            onCollegato: function (nome, larghezza, altezza) {
                finestra.remotoPronto = true
                if (nome) finestra.remoto = { host: finestra.remoto.host, nome: nome }
                if (finestra.visibility !== Window.FullScreen) { finestra.width = Math.max(finestra.width, Math.min(Screen.width - 40, larghezza)); finestra.height = Math.max(finestra.height, Math.min(Screen.height - 60, altezza + 44)) }
                forceActiveFocus()
            }
            onErrore: function (messaggio) { avviso.mostra(messaggio); finestra.scollega() }
            onFinito: function (messaggio) { avviso.mostra(I18n.t("Collegamento chiuso")); finestra.scollega() }
        }
        Column {
            anchors.centerIn: parent
            visible: !finestra.remotoPronto
            spacing: 12
            BusyIndicator { anchors.horizontalCenter: parent.horizontalCenter; running: parent.visible }
            Text { text: I18n.t("Collegamento a {h}…").replace("{h}", finestra.remoto ? finestra.remoto.host : ""); color: "#F5F5F7"; font.family: Tema.font; font.pixelSize: 15 }
        }
        Rectangle {
            id: barraRemoto
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            height: 44
            color: "#1C1D22"
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 10
                spacing: 8
                Simbolo { nome: "schermo"; lato: 18; colore: "#F5F5F7" }
                Text { text: finestra.remoto ? finestra.remoto.nome : ""; color: "#F5F5F7"; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                Pulsante { text: I18n.t("Incolla"); visible: finestra.remotoPronto; onClicked: { incollatore.text = ""; incollatore.paste(); if (incollatore.text) schermo.scrivi(incollatore.text); schermo.forceActiveFocus() } }
                Pulsante { text: "Ctrl+Alt+Canc"; visible: finestra.remotoPronto; onClicked: { schermo.ctrlAltCanc(); schermo.forceActiveFocus() } }
                Pulsante {
                    text: finestra.visibility === Window.FullScreen ? I18n.t("Esci da schermo intero") : I18n.t("Schermo intero")
                    onClicked: { finestra.visibility === Window.FullScreen ? finestra.showNormal() : finestra.showFullScreen(); schermo.forceActiveFocus() }
                }
                Pulsante { text: I18n.t("Scollega"); pericoloso: true; onClicked: finestra.scollega() }
            }
        }
        TextEdit { id: incollatore; visible: false }
    }

    Messaggio { id: avviso }
}
