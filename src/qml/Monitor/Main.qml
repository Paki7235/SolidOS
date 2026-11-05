// Gestore attività: tabella dei processi con schede Processore, Memoria,
// Disco e Rete, riepilogo in basso con grafico del carico.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Gestore attività")
    width: 980
    height: 680
    property var dati: ({ memoria: {}, rete: { interfacce: [] }, disco: {}, processi: [] })
    property string scheda: "cpu"
    property int selezionato: -1
    property var storiaUtente: []
    property var storiaSistema: []

    function aggiorna() {
        dati = ponte.chiama("istantanea", [scheda, ricerca.text])
        storiaUtente = storiaUtente.slice(-59).concat([dati.utente || 0])
        storiaSistema = storiaSistema.slice(-59).concat([dati.sistema || 0])
        grafico.requestPaint()
    }
    Timer { interval: 2000; running: finestra.visible; repeat: true; triggeredOnStart: true; onTriggered: finestra.aggiorna() }

    readonly property var colonne: scheda === "memoria"
        ? [{ t: I18n.t("Memoria"), k: "memoria", u: " MB" }, { t: I18n.t("Thread"), k: "thread", u: "" }, { t: "% " + I18n.t("processore"), k: "cpu", u: "" }]
        : scheda === "disco"
        ? [{ t: I18n.t("Disco"), k: "disco", u: " KB/s" }, { t: I18n.t("Memoria"), k: "memoria", u: " MB" }, { t: "% " + I18n.t("processore"), k: "cpu", u: "" }]
        : [{ t: "% " + I18n.t("processore"), k: "cpu", u: "" }, { t: I18n.t("Tempo"), k: "tempo", u: "" }, { t: I18n.t("Thread"), k: "thread", u: "" }, { t: I18n.t("Memoria"), k: "memoria", u: " MB" }]

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Barra degli strumenti ──────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 52
            color: Tema.superficie
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 12
                spacing: 12
                ColumnLayout {
                    spacing: 0
                    Testo { text: I18n.t("Gestore attività"); font.weight: Font.DemiBold }
                    Testo { text: (finestra.dati.numeroProcessi || 0) + " " + I18n.t("processi"); secondario: true; font.pointSize: Tema.fontDimensione - 1 }
                }
                Item { Layout.fillWidth: true }
                Pulsante {
                    text: I18n.t("Chiudi processo")
                    pericoloso: true
                    enabled: finestra.selezionato >= 0
                    onClicked: {
                        var p = finestra.dati.processi.find(function (x) { return x.pid === finestra.selezionato })
                        if (p) { ponte.chiama("termina", [p.pid, false]); finestra.selezionato = -1; finestra.aggiorna() }
                    }
                }
                Rectangle {
                    implicitWidth: schede.implicitWidth + 4
                    implicitHeight: 30
                    radius: 8
                    color: Qt.rgba(0, 0, 0, Tema.chiaro ? 0.06 : 0.3)
                    Row {
                        id: schede
                        anchors.centerIn: parent
                        spacing: 2
                        Repeater {
                            model: [{ t: I18n.t("Processore"), v: "cpu" }, { t: I18n.t("Memoria"), v: "memoria" },
                                    { t: I18n.t("Disco"), v: "disco" }, { t: I18n.t("Rete"), v: "rete" }]
                            Rectangle {
                                width: et.implicitWidth + 24
                                height: 26
                                radius: 6
                                color: finestra.scheda === modelData.v ? (Tema.chiaro ? "#FFFFFF" : "#5A5B63") : "transparent"
                                Text { id: et; anchors.centerIn: parent; text: modelData.t; color: Tema.testo; font.family: Tema.font; font.pixelSize: 12; font.weight: finestra.scheda === modelData.v ? Font.Medium : Font.Normal }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { finestra.scheda = modelData.v; finestra.aggiorna() } }
                            }
                        }
                    }
                }
                CampoRicerca { id: ricerca; Layout.preferredWidth: 180; placeholderText: I18n.t("Cerca"); onTextChanged: finestra.aggiorna() }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Tema.bordo }
        }

        // ── Tabella dei processi ────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Tema.sfondo
            visible: finestra.scheda !== "rete"
            ListView {
                id: elenco
                anchors.fill: parent
                clip: true
                model: finestra.dati.processi
                headerPositioning: ListView.OverlayHeader
                header: Rectangle {
                    z: 2
                    width: elenco.width
                    height: 30
                    color: Tema.sfondo
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        Text { text: I18n.t("Nome del processo"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11; Layout.fillWidth: true }
                        Repeater {
                            model: finestra.colonne
                            Text { text: modelData.t; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 110 }
                        }
                        Text { text: I18n.t("Utente"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 90 }
                    }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Tema.bordo }
                }
                delegate: Rectangle {
                    id: riga
                    required property var modelData
                    required property int index
                    readonly property bool scelta: modelData.pid === finestra.selezionato
                    width: elenco.width
                    height: 26
                    color: scelta ? Tema.accento : (index % 2 ? Qt.rgba(1, 1, 1, Tema.chiaro ? 0 : 0.025) : "transparent")
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        Text { text: riga.modelData.nome; color: riga.scelta ? "#FFFFFF" : Tema.testo; font.family: Tema.font; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                        Repeater {
                            model: finestra.colonne
                            Text {
                                text: {
                                    var v = riga.modelData[modelData.k]
                                    return (typeof v === "number" ? v.toLocaleString(Qt.locale(), "f", modelData.k === "thread" ? 0 : 1) : v) + modelData.u
                                }
                                color: riga.scelta ? "#FFFFFF" : Tema.testo
                                font.family: Tema.font; font.pixelSize: 13; font.features: { "tnum": 1 }
                                horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 110
                            }
                        }
                        Text { text: riga.modelData.mio ? riga.modelData.utente : I18n.t("sistema"); color: riga.scelta ? "#FFFFFF" : Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13; elide: Text.ElideRight; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 90 }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: finestra.selezionato = riga.modelData.mio ? riga.modelData.pid : -1
                        onDoubleClicked: finestra.selezionato = riga.modelData.pid
                    }
                }
                ScrollBar.vertical: ScrollBar {}
            }
        }

        // ── Scheda Rete: interfacce e traffico ─────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Tema.sfondo
            visible: finestra.scheda === "rete"
            Column {
                anchors.centerIn: parent
                spacing: 10
                Testo { anchors.horizontalCenter: parent.horizontalCenter; text: "↓ " + (finestra.dati.rete.giu || 0) + " MB/s     ↑ " + (finestra.dati.rete.su || 0) + " MB/s"; font.pointSize: Tema.fontDimensione + 6; font.weight: Font.DemiBold }
                Testo { anchors.horizontalCenter: parent.horizontalCenter; secondario: true; text: I18n.t("Dall'accensione") + ": " + (finestra.dati.rete.ricevuti || 0) + " GB " + I18n.t("ricevuti") + ", " + (finestra.dati.rete.inviati || 0) + " GB " + I18n.t("inviati") }
                Repeater {
                    model: finestra.dati.rete.interfacce
                    Testo { anchors.horizontalCenter: parent.horizontalCenter; secondario: true; text: modelData.nome + (modelData.velocita > 0 ? "  ·  " + modelData.velocita + " Mbit/s" : "") }
                }
            }
        }

        // ── Riepilogo ───────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 150
            color: Tema.superficie
            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Tema.bordo }
            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 24
                GridLayout {
                    columns: 2
                    rowSpacing: 6
                    columnSpacing: 24
                    Layout.preferredWidth: 220
                    Testo { text: I18n.t("Sistema"); secondario: true }
                    Testo { text: (finestra.dati.sistema || 0).toLocaleString(Qt.locale(), "f", 1) + "%"; color: "#FF6B6B"; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignRight }
                    Testo { text: I18n.t("Utente"); secondario: true }
                    Testo { text: (finestra.dati.utente || 0).toLocaleString(Qt.locale(), "f", 1) + "%"; color: "#5B9BFF"; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignRight }
                    Testo { text: I18n.t("Inattivo"); secondario: true }
                    Testo { text: (finestra.dati.inattivo || 0).toLocaleString(Qt.locale(), "f", 1) + "%"; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignRight }
                    Testo { text: I18n.t("Disco"); secondario: true }
                    Testo { text: (finestra.dati.disco.lettura || 0) + " / " + (finestra.dati.disco.scrittura || 0) + " MB/s"; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignRight }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 6
                    Testo { text: I18n.t("Carico del processore"); secondario: true; Layout.alignment: Qt.AlignHCenter }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        color: Tema.chiaro ? "#F2F2F7" : "#111216"
                        border.color: Tema.bordo
                        Canvas {
                            id: grafico
                            anchors.fill: parent
                            anchors.margins: 1
                            onPaint: {
                                var c = getContext("2d"); c.reset()
                                var n = 60, passo = width / (n - 1)
                                function area(serie, base, colore) {
                                    if (serie.length < 2) return
                                    c.beginPath()
                                    var inizio = n - serie.length
                                    c.moveTo(inizio * passo, height)
                                    for (var i = 0; i < serie.length; i++)
                                        c.lineTo((inizio + i) * passo, height - height * Math.min((serie[i] + (base ? base[i] : 0)) / 100, 1))
                                    c.lineTo(width, height); c.closePath()
                                    c.fillStyle = colore; c.fill()
                                }
                                area(finestra.storiaUtente, finestra.storiaSistema, "#5B9BFF")
                                area(finestra.storiaSistema, null, "#FF6B6B")
                            }
                        }
                    }
                }
                ColumnLayout {
                    Layout.preferredWidth: 220
                    spacing: 8
                    Testo { text: I18n.t("Memoria fisica"); secondario: true }
                    Testo { text: (finestra.dati.memoria.usata || 0).toLocaleString(Qt.locale(), "f", 1) + " GB  " + I18n.t("di") + " " + (finestra.dati.memoria.totale || 0).toLocaleString(Qt.locale(), "f", 1) + " GB"; font.pointSize: Tema.fontDimensione + 3; font.weight: Font.DemiBold }
                    Rectangle {
                        Layout.fillWidth: true
                        height: 6
                        radius: 3
                        color: Tema.chiaro ? "#E5E5EA" : "#1FFFFFFF"
                        clip: true
                        Row {
                            Rectangle { width: parent.parent.width * (finestra.dati.memoria.app || 0) / 100; height: 6; color: "#5B9BFF" }
                            Rectangle { width: parent.parent.width * (finestra.dati.memoria.compressa || 0) / 100; height: 6; color: "#FFB340" }
                        }
                    }
                    Testo { secondario: true; font.pointSize: Tema.fontDimensione - 1; text: I18n.t("Compressa") + ": " + (finestra.dati.memoria.swapMB || 0) + " MB" }
                }
            }
        }
    }
}
