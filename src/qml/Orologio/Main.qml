// Orologio: in alto quattro schede (Ora nel mondo, Sveglie, Cronometro, Timer). Sveglie e timer
// suonano anche ad app chiusa (servizio degli avvisi), con «Ferma» e «Posticipa».
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Orologio")
    width: 760
    height: 640
    minimumWidth: 520
    minimumHeight: 480

    property string scheda: "mondo"     // mondo | sveglie | cronometro | timer
    property var adesso: new Date()
    property var mondo: []
    property var sveglie: []
    property string prossima: ""
    property var timer: ({ attivo: false })
    // cronometro (solo nell'app)
    property bool corre: false
    property real partenza: 0
    property real accumulato: 0
    property real giroInizio: 0
    property var giri: []
    readonly property real trascorso: corre ? accumulato + (adesso.getTime() - partenza) : accumulato
    // editor della sveglia
    property var bozza: null

    function due(n) { return (n < 10 ? "0" : "") + n }
    function formatoCrono(ms) {
        var cent = Math.floor(ms / 10) % 100, s = Math.floor(ms / 1000) % 60, m = Math.floor(ms / 60000)
        return due(m) + ":" + due(s) + "," + due(cent)
    }
    function formatoTimer(sec) {
        sec = Math.ceil(sec)
        var h = Math.floor(sec / 3600), m = Math.floor(sec / 60) % 60, s = sec % 60
        return (h > 0 ? h + ":" + due(m) : m) + ":" + due(s)
    }
    function ricarica() {
        mondo = ponte.chiama0("mondo"); sveglie = ponte.chiama0("sveglie")
        prossima = ponte.chiama0("prossima"); timer = ponte.chiama0("timer")
    }
    Component.onCompleted: ricarica()
    Timer {
        interval: finestra.corre || (finestra.scheda === "timer" && finestra.timer.attivo) ? 33 : 1000
        repeat: true; running: true
        onTriggered: {
            finestra.adesso = new Date()
            if (finestra.scheda === "timer" && finestra.timer.attivo) finestra.timer = ponte.chiama0("timer")
            if (finestra.adesso.getSeconds() === 0 && !finestra.corre) finestra.mondo = ponte.chiama0("mondo")
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        // schede
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: rigaSchede.implicitWidth + 8
            Layout.preferredHeight: 38
            radius: 19
            color: Tema.superficieAlta
            Row {
                id: rigaSchede
                anchors.centerIn: parent
                spacing: 2
                Repeater {
                    model: [{ id: "mondo", t: I18n.t("Ora nel mondo"), s: "globo" }, { id: "sveglie", t: I18n.t("Sveglie"), s: "sveglia" },
                            { id: "cronometro", t: I18n.t("Cronometro"), s: "cronometro" }, { id: "timer", t: I18n.t("Timer"), s: "clessidra" }]
                    Rectangle {
                        width: rs.implicitWidth + 26; height: 32; radius: 16
                        color: finestra.scheda === modelData.id ? Tema.accento : "transparent"
                        Row {
                            id: rs; anchors.centerIn: parent; spacing: 6
                            Simbolo { anchors.verticalCenter: parent.verticalCenter; nome: modelData.s; lato: 16; colore: finestra.scheda === modelData.id ? "#FFFFFF" : Tema.testo }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.t; color: finestra.scheda === modelData.id ? "white" : Tema.testo; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.Medium }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { finestra.scheda = modelData.id; finestra.ricarica() } }
                    }
                }
            }
        }

        // ── Ora nel mondo ──
        ColumnLayout {
            visible: finestra.scheda === "mondo"
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: 10
            Text { Layout.alignment: Qt.AlignHCenter; text: Qt.formatTime(finestra.adesso, "HH:mm"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 64; font.weight: Font.Light }
            Text { Layout.alignment: Qt.AlignHCenter; text: finestra.adesso.toLocaleDateString(Qt.locale("it_IT"), "dddd d MMMM yyyy"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 15 }
            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.topMargin: 6
                clip: true; spacing: 8
                model: finestra.mondo
                delegate: Rectangle {
                    width: ListView.view.width; height: 70; radius: 14
                    color: Tema.superficie; border.color: Tema.bordo
                    HoverHandler { id: sopraM }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 18
                        Simbolo { nome: modelData.notte ? "luna" : "sole"; lato: 20; colore: Tema.testoSecondario }
                        ColumnLayout {
                            Layout.fillWidth: true; Layout.leftMargin: 8; spacing: 2
                            Text { text: modelData.citta; color: Tema.testo; font.family: Tema.font; font.pixelSize: 17; font.weight: Font.DemiBold }
                            Text { text: modelData.giorno + ", " + modelData.differenza; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                        }
                        Item { Layout.fillWidth: true }
                        Simbolo {
                            visible: sopraM.hovered; nome: "cestino"; lato: 18; colore: Tema.testoSecondario
                            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: finestra.mondo = ponte.chiama("togliCitta", [modelData.citta]) }
                        }
                        Text { text: modelData.ora; color: Tema.testo; font.family: Tema.font; font.pixelSize: 36; font.weight: Font.Light; Layout.leftMargin: 12 }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                CampoRicerca { id: cercaCitta; Layout.fillWidth: true; placeholderText: I18n.t("Aggiungi una città (es. Tokyo, New York)") }
            }
            Flow {
                visible: cercaCitta.text.length > 0
                Layout.fillWidth: true; spacing: 6
                Repeater {
                    model: cercaCitta.text.length ? ponte.chiama("citta", [cercaCitta.text]) : []
                    Pulsante { text: modelData; onClicked: { finestra.mondo = ponte.chiama("aggiungiCitta", [modelData]); cercaCitta.text = "" } }
                }
            }
        }

        // ── Sveglie ──
        ColumnLayout {
            visible: finestra.scheda === "sveglie" && !finestra.bozza
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                Text { text: finestra.prossima || I18n.t("Nessuna sveglia attiva"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13; Layout.fillWidth: true }
                Pulsante { text: I18n.t("Nuova sveglia"); principale: true; onClicked: finestra.bozza = { ora: "07:00", giorni: [0, 1, 2, 3, 4], etichetta: "", attiva: true } }
            }
            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; spacing: 8
                model: finestra.sveglie
                delegate: Rectangle {
                    width: ListView.view.width; height: 86; radius: 14
                    color: Tema.superficie; border.color: Tema.bordo
                    HoverHandler { id: sopraS }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 18
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            Text { text: modelData.ora; color: modelData.attiva ? Tema.testo : Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 44; font.weight: Font.Light }
                            Text { text: (modelData.etichetta ? modelData.etichetta + " · " : "") + modelData.ripeti; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13 }
                        }
                        Simbolo {
                            visible: sopraS.hovered; nome: "matita"; lato: 18; colore: Tema.testoSecondario
                            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: finestra.bozza = Object.assign({}, modelData) }
                        }
                        Simbolo {
                            visible: sopraS.hovered; nome: "cestino"; lato: 18; colore: Tema.testoSecondario; Layout.leftMargin: 10
                            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: { finestra.sveglie = ponte.chiama("togliSveglia", [modelData.id]); finestra.prossima = ponte.chiama0("prossima") } }
                        }
                        Interruttore {
                            Layout.leftMargin: 12
                            checked: modelData.attiva
                            onToggled: { finestra.sveglie = ponte.chiama("attivaSveglia", [modelData.id, checked]); finestra.prossima = ponte.chiama0("prossima") }
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent; visible: finestra.sveglie.length === 0
                    text: I18n.t("Nessuna sveglia. Aggiungine una con «Nuova sveglia».")
                    color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 14
                }
            }
        }
        // editor della sveglia
        ColumnLayout {
            visible: finestra.scheda === "sveglie" && !!finestra.bozza
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: 14
            Text { text: finestra.bozza && finestra.bozza.id ? I18n.t("Modifica sveglia") : I18n.t("Nuova sveglia"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 20; font.weight: Font.Bold }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 4
                Tumbler {
                    id: oreT; model: 24; visibleItemCount: 5; implicitWidth: 90; implicitHeight: 200
                    currentIndex: finestra.bozza ? parseInt(finestra.bozza.ora.split(":")[0]) : 7
                    delegate: Text { text: finestra.due(modelData); horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; color: Tema.testo; opacity: 1.0 - Math.abs(Tumbler.displacement) / 3; font.family: Tema.font; font.pixelSize: Math.abs(Tumbler.displacement) < 0.5 ? 44 : 28; font.weight: Font.Light }
                }
                Text { text: ":"; color: Tema.testo; font.pixelSize: 40 }
                Tumbler {
                    id: minutiT; model: 60; visibleItemCount: 5; implicitWidth: 90; implicitHeight: 200
                    currentIndex: finestra.bozza ? parseInt(finestra.bozza.ora.split(":")[1]) : 0
                    delegate: Text { text: finestra.due(modelData); horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; color: Tema.testo; opacity: 1.0 - Math.abs(Tumbler.displacement) / 3; font.family: Tema.font; font.pixelSize: Math.abs(Tumbler.displacement) < 0.5 ? 44 : 28; font.weight: Font.Light }
                }
            }
            Text { text: I18n.t("Ripeti"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold }
            Row {
                spacing: 6
                Repeater {
                    model: ["lun", "mar", "mer", "gio", "ven", "sab", "dom"]
                    Rectangle {
                        readonly property bool scelto: !!finestra.bozza && finestra.bozza.giorni.indexOf(index) >= 0
                        width: 46; height: 36; radius: 18
                        color: scelto ? Tema.accento : Tema.superficieAlta
                        Text { anchors.centerIn: parent; text: I18n.t(modelData); color: parent.scelto ? "white" : Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var b = Object.assign({}, finestra.bozza), g = b.giorni.slice(), i = g.indexOf(index)
                                if (i >= 0) g.splice(i, 1); else g.push(index)
                                b.giorni = g; finestra.bozza = b
                            }
                        }
                    }
                }
            }
            CampoTesto { id: etichettaS; Layout.fillWidth: true; placeholderText: I18n.t("Nome della sveglia (facoltativo)"); text: finestra.bozza ? finestra.bozza.etichetta : "" }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Pulsante { text: I18n.t("Annulla"); onClicked: finestra.bozza = null }
                Pulsante {
                    text: I18n.t("Salva"); principale: true
                    onClicked: {
                        var b = Object.assign({}, finestra.bozza)
                        b.ora = finestra.due(oreT.currentIndex) + ":" + finestra.due(minutiT.currentIndex)
                        b.etichetta = etichettaS.text; b.attiva = true
                        finestra.sveglie = ponte.chiama("salvaSveglia", [b])
                        finestra.prossima = ponte.chiama0("prossima")
                        finestra.bozza = null
                        avviso.mostra(finestra.prossima)
                    }
                }
            }
        }

        // ── Cronometro ──
        ColumnLayout {
            visible: finestra.scheda === "cronometro"
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: 18
            Text {
                Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 20
                text: finestra.formatoCrono(finestra.trascorso)
                color: Tema.testo; font.family: Tema.font; font.pixelSize: 80; font.weight: Font.Light
                font.features: ({ "tnum": 1 })
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 60
                BottoneTondo {
                    testo: finestra.corre ? I18n.t("Giro") : I18n.t("Azzera")
                    attivo: finestra.corre || finestra.accumulato > 0
                    colore: Tema.superficieAlta; coloreTesto: Tema.testo
                    onPremuto: {
                        if (finestra.corre) {
                            var t = finestra.trascorso
                            finestra.giri = [{ n: finestra.giri.length + 1, tempo: t - finestra.giroInizio }].concat(finestra.giri)
                            finestra.giroInizio = t
                        } else { finestra.accumulato = 0; finestra.giri = []; finestra.giroInizio = 0 }
                    }
                }
                BottoneTondo {
                    testo: finestra.corre ? I18n.t("Ferma") : I18n.t("Avvia")
                    colore: finestra.corre ? "#3D1F1F" : "#1D3A27"; coloreTesto: finestra.corre ? "#FF6961" : "#4CD964"
                    onPremuto: {
                        if (finestra.corre) { finestra.accumulato = finestra.trascorso; finestra.corre = false }
                        else { finestra.partenza = new Date().getTime(); finestra.corre = true }
                    }
                }
            }
            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true
                model: finestra.giri
                readonly property var tempi: finestra.giri.map(function (g) { return g.tempo })
                delegate: Item {
                    width: ListView.view.width; height: 44
                    readonly property var lv: ListView.view
                    readonly property bool migliore: lv.tempi.length > 1 && modelData.tempo === Math.min.apply(null, lv.tempi)
                    readonly property bool peggiore: lv.tempi.length > 1 && modelData.tempo === Math.max.apply(null, lv.tempi)
                    Rectangle { width: parent.width; height: 1; color: Tema.bordo }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Giro") + " " + modelData.n; color: parent.migliore ? "#22C55E" : (parent.peggiore ? "#EF4444" : Tema.testo); font.family: Tema.font; font.pixelSize: 16 }
                    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: finestra.formatoCrono(modelData.tempo); color: parent.migliore ? "#22C55E" : (parent.peggiore ? "#EF4444" : Tema.testo); font.family: Tema.font; font.pixelSize: 16; font.features: ({ "tnum": 1 }) }
                }
            }
        }

        // ── Timer ──
        ColumnLayout {
            visible: finestra.scheda === "timer"
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: 14
            // impostazione
            ColumnLayout {
                visible: !finestra.timer.attivo
                Layout.alignment: Qt.AlignHCenter
                spacing: 14
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6
                    Repeater {
                        model: [{ id: "h", n: 24, t: I18n.t("ore") }, { id: "m", n: 60, t: I18n.t("min") }, { id: "s", n: 60, t: I18n.t("s") }]
                        ColumnLayout {
                            spacing: 0
                            Tumbler {
                                id: tumb
                                objectName: "timer-" + modelData.id
                                model: modelData.n; visibleItemCount: 5; implicitWidth: 86; implicitHeight: 190
                                currentIndex: modelData.id === "m" ? 5 : 0
                                delegate: Text { text: modelData; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; color: Tema.testo; opacity: 1.0 - Math.abs(Tumbler.displacement) / 3; font.family: Tema.font; font.pixelSize: Math.abs(Tumbler.displacement) < 0.5 ? 40 : 26; font.weight: Font.Light }
                                Component.onCompleted: { if (modelData.id === "h") finestra.tOre = tumb; else if (modelData.id === "m") finestra.tMin = tumb; else finestra.tSec = tumb }
                            }
                            Text { Layout.alignment: Qt.AlignHCenter; text: modelData.t; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                        }
                    }
                }
                Flow {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 420
                    spacing: 6
                    Repeater {
                        model: [1, 3, 5, 10, 15, 30, 60]
                        Pulsante { text: modelData < 60 ? modelData + " min" : "1 h"; onClicked: finestra.timer = ponte.chiama("avviaTimer", [modelData * 60, etichettaT.text]) }
                    }
                }
                CampoTesto { id: etichettaT; Layout.preferredWidth: 320; Layout.alignment: Qt.AlignHCenter; placeholderText: I18n.t("Nome (es. Pasta)") }
                BottoneTondo {
                    Layout.alignment: Qt.AlignHCenter
                    testo: I18n.t("Avvia"); colore: "#1D3A27"; coloreTesto: "#4CD964"
                    attivo: finestra.tOre && (finestra.tOre.currentIndex + finestra.tMin.currentIndex + finestra.tSec.currentIndex) > 0
                    onPremuto: finestra.timer = ponte.chiama("avviaTimer", [finestra.tOre.currentIndex * 3600 + finestra.tMin.currentIndex * 60 + finestra.tSec.currentIndex, etichettaT.text])
                }
            }
            // in corso
            ColumnLayout {
                visible: !!finestra.timer.attivo
                Layout.alignment: Qt.AlignHCenter
                spacing: 18
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    width: 300; height: 300
                    Canvas {
                        id: anello
                        anchors.fill: parent
                        property real frazione: finestra.timer.attivo ? finestra.timer.resto / Math.max(1, finestra.timer.durata) : 0
                        onFrazioneChanged: requestPaint()
                        onPaint: {
                            var g = getContext("2d"); g.reset(); g.lineWidth = 10; g.lineCap = "round"
                            g.strokeStyle = Tema.superficieAlta; g.beginPath(); g.arc(150, 150, 140, 0, Math.PI * 2); g.stroke()
                            g.strokeStyle = Tema.accento; g.beginPath(); g.arc(150, 150, 140, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * frazione); g.stroke()
                        }
                    }
                    ColumnLayout {
                        anchors.centerIn: parent; spacing: 4
                        Text { Layout.alignment: Qt.AlignHCenter; text: finestra.formatoTimer(finestra.timer.resto || 0); color: Tema.testo; font.family: Tema.font; font.pixelSize: 58; font.weight: Font.Light; font.features: ({ "tnum": 1 }) }
                        Text { Layout.alignment: Qt.AlignHCenter; text: finestra.timer.etichetta || ""; visible: !!finestra.timer.etichetta; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 14 }
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter; spacing: 4
                            Simbolo { nome: "sveglia"; lato: 13; colore: Tema.testoSecondario }
                            Text { text: Qt.formatTime(new Date(finestra.adesso.getTime() + (finestra.timer.resto || 0) * 1000), "HH:mm"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13 }
                        }
                    }
                }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter; spacing: 60
                    BottoneTondo { testo: I18n.t("Annulla"); colore: Tema.superficieAlta; coloreTesto: Tema.testo; onPremuto: finestra.timer = ponte.chiama0("fermaTimer") }
                    BottoneTondo {
                        testo: finestra.timer.inPausa ? I18n.t("Riprendi") : I18n.t("Pausa")
                        colore: finestra.timer.inPausa ? "#1D3A27" : "#3D2E12"; coloreTesto: finestra.timer.inPausa ? "#4CD964" : "#FFB340"
                        onPremuto: finestra.timer = ponte.chiama("pausaTimer", [!finestra.timer.inPausa])
                    }
                }
            }
        }
    }
    property var tOre: null
    property var tMin: null
    property var tSec: null

    // pulsante tondo grande (come gli orologi dei telefoni)
    component BottoneTondo: Rectangle {
        id: bt
        property string testo: ""
        property color coloreTesto: "white"
        property color colore: Tema.accento
        property bool attivo: true
        signal premuto()
        width: 86; height: 86; radius: 43
        color: colore
        opacity: attivo ? 1 : 0.4
        scale: maBt.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        Text { anchors.centerIn: parent; text: bt.testo; color: bt.coloreTesto; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.Medium }
        MouseArea { id: maBt; anchors.fill: parent; enabled: bt.attivo; cursorShape: Qt.PointingHandCursor; onClicked: bt.premuto() }
    }
    Messaggio { id: avviso }
}
