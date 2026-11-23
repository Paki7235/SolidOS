// Meteo: a sinistra la posizione attuale e le città salvate (con la temperatura); a destra, su
// uno sfondo che cambia col tempo e col giorno/notte, la città, i gradi, le prossime 24 ore,
// i prossimi 10 giorni con la barra delle temperature e i riquadri dei dettagli.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Meteo")
    width: 1040
    height: 720
    minimumWidth: 760
    minimumHeight: 520

    property var luoghi: []                 // [{nome, regione, lat, lon, qui?}]
    property int scelto: 0
    property var dati: ({})                 // previsioni del luogo scelto
    property var mini: ({})                 // "lat,lon" → previsioni (per l'elenco)
    property var trovate: []
    property bool carica: false
    readonly property var luogo: luoghi.length ? luoghi[Math.min(scelto, luoghi.length - 1)] : null
    readonly property color testoSfondo: "#FFFFFF"

    function chiave(l) { return l.lat.toFixed(3) + "," + l.lon.toFixed(3) }
    function apri(i) {
        scelto = i
        var l = luoghi[i]
        if (!l) return
        if (mini[chiave(l)]) dati = mini[chiave(l)]
        carica = true
        ponte.avvia("previsioni", [l.lat, l.lon, l.nome], "previsioni:" + chiave(l))
    }
    function aggiornaElenco() {
        for (var i = 0; i < luoghi.length; i++)
            if (!mini[chiave(luoghi[i])]) ponte.avvia("previsioni", [luoghi[i].lat, luoghi[i].lon, luoghi[i].nome], "mini:" + chiave(luoghi[i]))
    }
    // colori dello sfondo: sereno, nuvoloso, pioggia, notte
    readonly property var sfondo: {
        var s = dati.simbolo || "sole", notte = dati.giorno === false
        if (notte) return ["#0B1630", "#1E2B52"]
        if (s === "sole") return ["#2F7DE1", "#78B6F2"]
        if (s === "parz-nuvoloso") return ["#4A7FC0", "#93B6DA"]
        if (s === "pioggia" || s === "temporale") return ["#3C4A5C", "#68788C"]
        if (s === "neve") return ["#7D8FA8", "#B9C6D6"]
        return ["#5A6E86", "#93A4B8"]
    }

    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id === "qui") {
                if (r && r.lat !== undefined) { finestra.luoghi = [r].concat(finestra.luoghi.filter(function (x) { return !x.qui })); finestra.apri(0); finestra.aggiornaElenco() }
                else if (!finestra.luoghi.length) finestra.carica = false
            } else if (id === "cerca") finestra.trovate = r || []
            else if (id.indexOf("previsioni:") === 0 || id.indexOf("mini:") === 0) {
                if (!r || !r.ok) { if (id.indexOf("previsioni:") === 0) { finestra.carica = false; if (r) avviso.mostra(r.messaggio) } return }
                var c = id.split(":")[1]
                var m = Object.assign({}, finestra.mini); m[c] = r; finestra.mini = m
                if (id.indexOf("previsioni:") === 0 && finestra.luogo && finestra.chiave(finestra.luogo) === c) { finestra.dati = r; finestra.carica = false }
            }
        }
    }
    Component.onCompleted: {
        luoghi = ponte.chiama0("luoghi")
        carica = true
        if (luoghi.length) { apri(0); aggiornaElenco() }
        ponte.avvia("qui", [], "qui")
    }
    Timer { interval: 20 * 60 * 1000; repeat: true; running: true; onTriggered: { finestra.mini = ({}); finestra.apri(finestra.scelto); finestra.aggiornaElenco() } }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Elenco delle città ──
        Rectangle {
            Layout.preferredWidth: 270
            Layout.fillHeight: true
            color: Tema.superficie
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 12
                spacing: 8
                CampoRicerca {
                    id: ricerca
                    Layout.fillWidth: true
                    placeholderText: I18n.t("Aggiungi una città")
                    onTextChanged: attesa.restart()
                    Timer { id: attesa; interval: 400; onTriggered: { if (ricerca.text.length >= 2) ponte.avvia("cerca", [ricerca.text], "cerca"); else finestra.trovate = [] } }
                }
                // città trovate
                Repeater {
                    model: finestra.trovate
                    Rectangle {
                        Layout.fillWidth: true
                        height: 46; radius: 10
                        color: sopraT.hovered ? Tema.superficieAlta : "transparent"
                        HoverHandler { id: sopraT }
                        ColumnLayout {
                            anchors.fill: parent; anchors.leftMargin: 10; spacing: 0
                            Text { text: modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                            Text { text: modelData.regione; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var salvati = ponte.chiama("salva", [modelData])
                                var qui = finestra.luoghi.filter(function (x) { return x.qui })
                                finestra.luoghi = qui.concat(salvati)
                                finestra.trovate = []; ricerca.text = ""
                                finestra.apri(finestra.luoghi.length - 1); finestra.aggiornaElenco()
                            }
                        }
                    }
                }
                // città salvate
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: finestra.trovate.length === 0
                    clip: true
                    spacing: 6
                    model: finestra.luoghi
                    delegate: Rectangle {
                        id: voce
                        required property var modelData
                        required property int index
                        readonly property var m: finestra.mini[finestra.chiave(modelData)] || ({})
                        width: ListView.view.width
                        height: 76; radius: 14
                        color: index === finestra.scelto ? Tema.accento : (sopraL.hovered ? Tema.superficieAlta : Tema.sfondo)
                        HoverHandler { id: sopraL }
                        readonly property color t1: index === finestra.scelto ? "#FFFFFF" : Tema.testo
                        readonly property color t2: index === finestra.scelto ? "#E6FFFFFF" : Tema.testoSecondario
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 12
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                RowLayout {
                                    spacing: 5
                                    Simbolo { visible: voce.modelData.qui === true; nome: "naviga"; lato: 12; colore: voce.t1 }
                                    Text { text: voce.modelData.nome; color: voce.t1; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.maximumWidth: 140 }
                                }
                                Text { text: voce.m.descrizione || " "; color: voce.t2; font.family: Tema.font; font.pixelSize: 12 }
                            }
                            ColumnLayout {
                                spacing: 0
                                Text { Layout.alignment: Qt.AlignRight; text: voce.m.ok ? voce.m.gradi + "°" : ""; color: voce.t1; font.family: Tema.font; font.pixelSize: 26; font.weight: Font.Light }
                                Text { Layout.alignment: Qt.AlignRight; text: voce.m.ok ? "Max " + voce.m.max + "°  Min " + voce.m.min + "°" : ""; color: voce.t2; font.family: Tema.font; font.pixelSize: 11 }
                            }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: function (e) {
                                if (e.button === Qt.RightButton && !voce.modelData.qui) {
                                    var salvati = ponte.chiama("togli", [voce.modelData.lat, voce.modelData.lon])
                                    finestra.luoghi = finestra.luoghi.filter(function (x) { return x.qui }).concat(salvati)
                                    finestra.apri(0)
                                } else finestra.apri(voce.index)
                            }
                        }
                    }
                }
                Text {
                    visible: finestra.luoghi.length > 1 && finestra.trovate.length === 0
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: I18n.t("Clic destro su una città per toglierla")
                    color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11
                }
            }
        }

        // ── Il tempo ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            gradient: Gradient {
                GradientStop { position: 0; color: finestra.sfondo[0]; Behavior on color { ColorAnimation { duration: 500 } } }
                GradientStop { position: 1; color: finestra.sfondo[1]; Behavior on color { ColorAnimation { duration: 500 } } }
            }

            ColumnLayout {
                anchors.centerIn: parent
                visible: !finestra.dati.ok
                spacing: 10
                BusyIndicator { Layout.alignment: Qt.AlignHCenter; running: finestra.carica; visible: running }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: finestra.carica ? I18n.t("Carico il meteo…") : I18n.t("Aggiungi una città a sinistra")
                    color: "white"; font.family: Tema.font; font.pixelSize: 16
                }
            }

            Flickable {
                anchors.fill: parent
                visible: !!finestra.dati.ok
                contentHeight: colonna.implicitHeight + 40
                clip: true
                ScrollBar.vertical: ScrollBar {}
                ColumnLayout {
                    id: colonna
                    x: 28; y: 24
                    width: parent.width - 56
                    spacing: 16

                    // intestazione
                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 0
                        Text { Layout.alignment: Qt.AlignHCenter; text: finestra.luogo ? finestra.luogo.nome : ""; color: "white"; font.family: Tema.font; font.pixelSize: 30; font.weight: Font.Medium }
                        Text { Layout.alignment: Qt.AlignHCenter; text: (finestra.dati.gradi !== undefined ? finestra.dati.gradi : "") + "°"; color: "white"; font.family: Tema.font; font.pixelSize: 86; font.weight: Font.Light }
                        Text { Layout.alignment: Qt.AlignHCenter; text: finestra.dati.descrizione || ""; color: "#EAF2FF"; font.family: Tema.font; font.pixelSize: 18 }
                        Text { Layout.alignment: Qt.AlignHCenter; text: "Max " + finestra.dati.max + "°   Min " + finestra.dati.min + "°"; color: "#EAF2FF"; font.family: Tema.font; font.pixelSize: 16 }
                    }

                    // prossime 24 ore
                    Scheda {
                        titolo: I18n.t("Prossime 24 ore")
                        simbolo: "orologio"
                        contenuto: ListView {
                            width: parent ? parent.width : 0
                            height: 88
                            orientation: ListView.Horizontal
                            clip: true
                            spacing: 6
                            model: finestra.dati.ore || []
                            delegate: Column {
                                width: 52; spacing: 6
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.ora; color: "white"; font.family: Tema.font; font.pixelSize: 13; font.weight: index === 0 ? Font.DemiBold : Font.Normal }
                                Simbolo { anchors.horizontalCenter: parent.horizontalCenter; nome: modelData.simbolo; lato: 24; colore: "#FFFFFF" }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; visible: modelData.pioggia >= 20; text: modelData.pioggia + "%"; color: "#9FD0FF"; font.family: Tema.font; font.pixelSize: 11 }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.gradi + "°"; color: "white"; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.Medium }
                            }
                        }
                    }

                    // prossimi 10 giorni
                    Scheda {
                        titolo: I18n.t("Prossimi 10 giorni")
                        simbolo: "calendario"
                        contenuto: Column {
                            spacing: 0
                            Repeater {
                                model: finestra.dati.giorni || []
                                Item {
                                    width: colonna.width - 32; height: 42
                                    Rectangle { visible: index > 0; width: parent.width; height: 1; color: "#26FFFFFF" }
                                    Text { x: 0; anchors.verticalCenter: parent.verticalCenter; width: 70; text: modelData.giorno; color: "white"; font.family: Tema.font; font.pixelSize: 15 }
                                    Simbolo { x: 76; anchors.verticalCenter: parent.verticalCenter; nome: modelData.simbolo; lato: 22; colore: "#FFFFFF" }
                                    Text { x: 104; anchors.verticalCenter: parent.verticalCenter; visible: modelData.pioggia >= 20; text: modelData.pioggia + "%"; color: "#9FD0FF"; font.family: Tema.font; font.pixelSize: 11 }
                                    Text { x: 150; anchors.verticalCenter: parent.verticalCenter; width: 36; horizontalAlignment: Text.AlignRight; text: modelData.min + "°"; color: "#D0DDEE"; font.family: Tema.font; font.pixelSize: 15 }
                                    // barra delle temperature del giorno sulla scala della settimana
                                    Rectangle {
                                        id: binario
                                        x: 196; anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 196 - 50; height: 5; radius: 3
                                        color: "#33FFFFFF"
                                        readonly property real scala: Math.max(1, finestra.dati.scalaMax - finestra.dati.scalaMin)
                                        Rectangle {
                                            x: binario.width * (modelData.min - finestra.dati.scalaMin) / binario.scala
                                            width: Math.max(6, binario.width * (modelData.max - modelData.min) / binario.scala)
                                            height: parent.height; radius: 3
                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop { position: 0; color: "#7DD3FC" }
                                                GradientStop { position: 1; color: modelData.max >= 25 ? "#FB923C" : "#FCD34D" }
                                            }
                                        }
                                    }
                                    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: modelData.max + "°"; color: "white"; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.Medium }
                                }
                            }
                        }
                    }

                    // dettagli
                    GridLayout {
                        Layout.fillWidth: true
                        columns: Math.max(2, Math.floor((colonna.width + 12) / 200))
                        columnSpacing: 12; rowSpacing: 12
                        Repeater {
                            model: [
                                { t: I18n.t("Percepita"), s: "termometro", v: finestra.dati.percepita + "°", n: finestra.dati.percepita < finestra.dati.gradi ? I18n.t("Il vento la fa sembrare più fresca") : (finestra.dati.percepita > finestra.dati.gradi ? I18n.t("L'umidità la fa sembrare più calda") : I18n.t("Come la temperatura vera")) },
                                { t: I18n.t("Umidità"), s: "goccia", v: finestra.dati.umidita + "%", n: "" },
                                { t: I18n.t("Vento"), s: "vento", v: finestra.dati.vento + " km/h", n: I18n.t("Da") + " " + (finestra.dati.direzioneVento || "") },
                                { t: I18n.t("Indice UV"), s: "sole", v: "" + finestra.dati.uv, n: finestra.dati.giudizioUv || "" },
                                { t: I18n.t("Alba"), s: "alba", v: finestra.dati.alba || "", n: I18n.t("Tramonto") + " " + (finestra.dati.tramonto || "") },
                                { t: I18n.t("Qualità dell'aria"), s: "foglia", v: finestra.dati.aria && finestra.dati.aria.indice !== undefined ? "" + finestra.dati.aria.indice : "—", n: finestra.dati.aria ? (finestra.dati.aria.giudizio || "") : "" },
                                { t: I18n.t("Visibilità"), s: "occhio", v: finestra.dati.visibilita + " km", n: "" },
                                { t: I18n.t("Pressione"), s: "nuvola", v: finestra.dati.pressione + " hPa", n: "" }
                            ]
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 116
                                radius: 16
                                color: "#26FFFFFF"
                                border.color: "#33FFFFFF"
                                ColumnLayout {
                                    anchors.fill: parent; anchors.margins: 14
                                    spacing: 4
                                    RowLayout {
                                        spacing: 6
                                        Simbolo { nome: modelData.s; lato: 15; colore: "#DCE8F8" }
                                        Text { text: modelData.t.toUpperCase(); color: "#DCE8F8"; font.family: Tema.font; font.pixelSize: 11; font.weight: Font.DemiBold }
                                    }
                                    Text { text: modelData.v; color: "white"; font.family: Tema.font; font.pixelSize: 28; font.weight: Font.Medium }
                                    Text { Layout.fillWidth: true; text: modelData.n; color: "#EAF2FF"; font.family: Tema.font; font.pixelSize: 12; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
                                    Item { Layout.fillHeight: true }
                                }
                            }
                        }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: I18n.t("Aggiornato alle") + " " + (finestra.dati.aggiornato || "") + (finestra.dati.vecchie ? " · " + I18n.t("senza rete") : "") + "  ·  " + I18n.t("Dati: Open-Meteo")
                        color: "#CFE0F5"; font.family: Tema.font; font.pixelSize: 11
                    }
                }
            }
        }
    }

    // riquadro di vetro con titolo piccolo
    component Scheda: Rectangle {
        id: sch
        property string titolo: ""
        property string simbolo: ""
        property alias contenuto: posto.data
        Layout.fillWidth: true
        Layout.preferredHeight: colSch.implicitHeight + 28
        radius: 16
        color: "#26FFFFFF"
        border.color: "#33FFFFFF"
        Column {
            id: colSch
            x: 16; y: 14; width: parent.width - 32
            spacing: 10
            Row {
                spacing: 6
                Simbolo { nome: sch.simbolo; lato: 15; colore: "#DCE8F8" }
                Text { text: sch.titolo.toUpperCase(); color: "#DCE8F8"; font.family: Tema.font; font.pixelSize: 11; font.weight: Font.DemiBold }
            }
            Rectangle { width: parent.width; height: 1; color: "#26FFFFFF" }
            Item { id: posto; width: parent.width; height: childrenRect.height }
        }
    }
    Messaggio { id: avviso }
}
