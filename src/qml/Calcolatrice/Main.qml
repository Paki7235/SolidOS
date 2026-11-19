// Calcolatrice: Base, Scientifica e Converti (come sul telefono), con la cronologia.
// Tastiera del computer: cifre e operazioni, Invio calcola, Esc cancella, ⌫ toglie l'ultimo.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Calcolatrice")
    width: modo === "scientifica" ? 640 : 360
    height: 560
    minimumWidth: 320
    minimumHeight: 480

    property string modo: "base"          // base | scientifica | converti
    property string espressione: ""
    property string risultato: "0"
    property bool appenaCalcolato: false
    property bool radianti: false
    property bool cronologia: false
    property var storia: []

    // Converti
    property string categoria: "valuta"
    property var unita: []
    property string da: ""
    property string a: ""
    property var conversione: ({ valore: "0", nota: "" })

    readonly property var categorie: [
        { id: "valuta", nome: I18n.t("Valuta") }, { id: "lunghezza", nome: I18n.t("Lunghezza") },
        { id: "peso", nome: I18n.t("Peso") }, { id: "volume", nome: I18n.t("Volume") },
        { id: "temperatura", nome: I18n.t("Temperatura") }, { id: "velocita", nome: I18n.t("Velocità") },
        { id: "area", nome: I18n.t("Area") }
    ]

    function aggiornaAnteprima() {
        if (modo === "converti") { converti(); return }
        if (!espressione) { risultato = "0"; return }
        var r = ponte.chiama("calcola", [espressione, radianti])
        if (r.ok) risultato = r.risultato
    }
    function premi(t) {
        if (appenaCalcolato && /^[0-9(π√se]/.test(t)) espressione = ""
        appenaCalcolato = false
        espressione += t
        aggiornaAnteprima()
    }
    function uguale() {
        if (!espressione || modo === "converti") return
        var r = ponte.chiama("calcola", [espressione, radianti])
        if (!r.ok) { risultato = r.errore; return }
        ponte.chiama("ricorda", [espressione, r.risultato])
        storia = ponte.chiama0("storia")
        risultato = r.risultato
        espressione = r.risultato
        appenaCalcolato = true
    }
    function cancella() { espressione = ""; risultato = "0"; appenaCalcolato = false; aggiornaAnteprima() }
    function indietro() { espressione = espressione.slice(0, -1); appenaCalcolato = false; aggiornaAnteprima() }

    function caricaUnita() {
        unita = ponte.chiama("unita", [categoria])
        var preferite = { valuta: ["EUR", "USD"], lunghezza: ["km", "mi"], peso: ["kg", "lb"], volume: ["l", "gal"],
                          temperatura: ["°C", "°F"], velocita: ["km/h", "mph"], area: ["m²", "ft²"] }[categoria] || []
        da = preferite[0] || (unita.length ? unita[0].id : "")
        a = preferite[1] || (unita.length > 1 ? unita[1].id : da)
        converti()
    }
    function converti() {
        if (!da || !a) return
        var r = ponte.chiama("converti", [categoria, da, a, espressione || "0"])
        conversione = r.ok ? r : ({ valore: "—", nota: r.nota || "" })
    }
    function scambia() { var t = da; da = a; a = t; converti() }
    onModoChanged: {
        espressione = ""; risultato = "0"; appenaCalcolato = false
        if (modo === "converti") caricaUnita(); else aggiornaAnteprima()
    }
    onRadiantiChanged: aggiornaAnteprima()
    Component.onCompleted: storia = ponte.chiama0("storia")

    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: function (ev) {
            var t = ev.text
            if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter || t === "=") finestra.uguale()
            else if (ev.key === Qt.Key_Escape || ev.key === Qt.Key_Delete) finestra.cancella()
            else if (ev.key === Qt.Key_Backspace) finestra.indietro()
            else if ("0123456789+-*/().,%^!".indexOf(t) >= 0 && t !== "") finestra.premi(t === "*" ? "×" : t === "/" ? "÷" : t === "-" ? "−" : t === "." ? "," : t)
            else return
            ev.accepted = true
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            // ── Modi in una pillola, cronologia a destra ──
            RowLayout {
                Layout.fillWidth: true
                Rectangle {
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: righeModi.implicitWidth + 8
                    radius: 16
                    color: Tema.superficieAlta
                    Row {
                        id: righeModi
                        anchors.centerIn: parent
                        spacing: 2
                        Repeater {
                            model: [{ id: "base", t: I18n.t("Base") }, { id: "scientifica", t: I18n.t("Scientifica") }, { id: "converti", t: I18n.t("Converti") }]
                            Rectangle {
                                width: testoModo.implicitWidth + 24; height: 26; radius: 13
                                color: finestra.modo === modelData.id ? Tema.accento : "transparent"
                                Text {
                                    id: testoModo
                                    anchors.centerIn: parent
                                    text: modelData.t
                                    color: finestra.modo === modelData.id ? "#FFFFFF" : Tema.testo
                                    font.family: Tema.font; font.pixelSize: 13; font.weight: Font.Medium
                                }
                                MouseArea { anchors.fill: parent; onClicked: finestra.modo = modelData.id }
                            }
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 32; height: 32; radius: 16
                    color: finestra.cronologia ? Tema.accento : Tema.superficieAlta
                    // orologio disegnato: la cronologia
                    Canvas {
                        anchors.centerIn: parent; width: 18; height: 18
                        property color c: finestra.cronologia ? "#FFFFFF" : Tema.testo
                        onCChanged: requestPaint()
                        onPaint: {
                            var g = getContext("2d"); g.reset(); g.strokeStyle = c; g.lineWidth = 1.8; g.lineCap = "round"
                            g.beginPath(); g.arc(9, 9, 7, 0, Math.PI * 2); g.stroke()
                            g.beginPath(); g.moveTo(9, 5); g.lineTo(9, 9); g.lineTo(12, 11); g.stroke()
                        }
                    }
                    MouseArea { anchors.fill: parent; onClicked: finestra.cronologia = !finestra.cronologia }
                    ToolTip.visible: sopraCron.hovered; ToolTip.text: I18n.t("Cronologia")
                    HoverHandler { id: sopraCron }
                }
            }

            // ── Schermo: operazione sopra, risultato grande ──
            ColumnLayout {
                visible: finestra.modo !== "converti"
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                    text: (finestra.modo === "scientifica" ? (finestra.radianti ? "Rad   " : "Deg   ") : "") + (finestra.espressione || " ")
                    color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 17
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 18
                    text: finestra.risultato
                    color: Tema.testo; font.family: Tema.font; font.pixelSize: 48; font.weight: Font.Light
                    font.features: ({ "tnum": 1 })
                }
            }

            // ── Converti: categoria, da, a ──
            ColumnLayout {
                visible: finestra.modo === "converti"
                Layout.fillWidth: true
                spacing: 8
                ComboBox {
                    Layout.fillWidth: true
                    model: finestra.categorie
                    textRole: "nome"; valueRole: "id"
                    currentIndex: Math.max(0, finestra.categorie.findIndex(function (c) { return c.id === finestra.categoria }))
                    onActivated: { finestra.categoria = currentValue; finestra.caricaUnita() }
                }
                Repeater {
                    model: [{ lato: "da" }, { lato: "a" }]
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        radius: 12
                        color: Tema.superficie
                        border.color: Tema.bordo
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            ComboBox {
                                Layout.preferredWidth: 150
                                model: finestra.unita
                                textRole: "nome"; valueRole: "id"
                                property string scelta: modelData.lato === "da" ? finestra.da : finestra.a
                                currentIndex: Math.max(0, finestra.unita.findIndex(function (u) { return u.id === scelta }))
                                onActivated: { if (modelData.lato === "da") finestra.da = currentValue; else finestra.a = currentValue; finestra.converti() }
                            }
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignRight
                                fontSizeMode: Text.HorizontalFit; minimumPixelSize: 14
                                text: modelData.lato === "da" ? (finestra.espressione || "0") : finestra.conversione.valore
                                color: modelData.lato === "da" ? Tema.testoSecondario : Tema.testo
                                font.family: Tema.font; font.pixelSize: 28; font.weight: modelData.lato === "a" ? Font.DemiBold : Font.Light
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text { Layout.fillWidth: true; text: finestra.conversione.nota || ""; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11; wrapMode: Text.WordWrap }
                    Pulsante { text: "C"; onClicked: finestra.cancella() }
                    Pulsante { text: "⇅ " + I18n.t("Scambia"); onClicked: finestra.scambia() }
                }
            }

            // ── Tasti ──
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: finestra.modo === "scientifica" ? 8 : (finestra.modo === "converti" ? 3 : 4)
                rowSpacing: 8
                columnSpacing: 8
                Repeater {
                    model: {
                        var base = [
                            { t: "C", f: "c", k: 1 }, { t: "⌫", f: "b", k: 1 }, { t: "%", f: "%", k: 1 }, { t: "÷", k: 2 },
                            { t: "7" }, { t: "8" }, { t: "9" }, { t: "×", k: 2 },
                            { t: "4" }, { t: "5" }, { t: "6" }, { t: "−", k: 2 },
                            { t: "1" }, { t: "2" }, { t: "3" }, { t: "+", k: 2 },
                            { t: "( )", f: "p", k: 1 }, { t: "0" }, { t: ",", f: "," }, { t: "=", f: "=", k: 3 }
                        ]
                        if (finestra.modo === "converti")   // solo il numero da convertire
                            return [{ t: "7" }, { t: "8" }, { t: "9" }, { t: "4" }, { t: "5" }, { t: "6" },
                                    { t: "1" }, { t: "2" }, { t: "3" }, { t: ",", f: "," }, { t: "0" }, { t: "⌫", f: "b", k: 1 }]
                        if (finestra.modo !== "scientifica") return base
                        // Scientifica: quattro colonne di funzioni a sinistra di quelle di base
                        var sci = [
                            { t: finestra.radianti ? "Rad" : "Deg", f: "r", k: 1 }, { t: "x²", f: "^2", k: 1 }, { t: "xʸ", f: "^", k: 1 }, { t: "√", f: "√(", k: 1 },
                            { t: "sin", f: "sin(", k: 1 }, { t: "cos", f: "cos(", k: 1 }, { t: "tan", f: "tan(", k: 1 }, { t: "x!", f: "!", k: 1 },
                            { t: "ln", f: "ln(", k: 1 }, { t: "log", f: "log(", k: 1 }, { t: "1/x", f: "1÷(", k: 1 }, { t: "|x|", f: "abs(", k: 1 },
                            { t: "π", k: 1 }, { t: "e", k: 1 }, { t: "(", k: 1 }, { t: ")", k: 1 },
                            { t: "eˣ", f: "e^(", k: 1 }, { t: "10ˣ", f: "10^(", k: 1 }, { t: "∛", f: "^(1÷3)", k: 1 }, { t: "EE", f: "×10^", k: 1 }
                        ]
                        var tutti = []
                        for (var r = 0; r < 5; r++) tutti = tutti.concat(sci.slice(r * 4, r * 4 + 4), base.slice(r * 4, r * 4 + 4))
                        return tutti
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 38
                        radius: 10
                        visible: modelData.k !== 9
                        color: modelData.k === 3 ? (area.pressed ? Tema.accentoScuro : Tema.accento)
                             : modelData.k === 2 ? (area.pressed ? "#C2700A" : "#F0920F")
                             : modelData.k === 1 ? (area.pressed ? Qt.darker(Tema.superficieAlta, 1.2) : Qt.lighter(Tema.superficieAlta, Tema.chiaro ? 0.95 : 1.15))
                             : (area.pressed ? Qt.darker(Tema.superficie, 1.2) : Tema.superficieAlta)
                        scale: area.pressed ? 0.96 : 1
                        Behavior on scale { enabled: Tema.animazioni; NumberAnimation { duration: 90 } }
                        Text {
                            anchors.centerIn: parent
                            text: modelData.t
                            color: modelData.k >= 2 ? "#FFFFFF" : Tema.testo
                            font.family: Tema.font; font.pixelSize: modelData.t.length > 2 ? 15 : 20; font.weight: Font.Medium
                        }
                        MouseArea {
                            id: area
                            anchors.fill: parent
                            onClicked: {
                                var f = modelData.f !== undefined ? modelData.f : modelData.t
                                if (f === "c") finestra.cancella()
                                else if (f === "b") finestra.indietro()
                                else if (f === "=") finestra.uguale()
                                else if (f === "r") finestra.radianti = !finestra.radianti
                                else if (f === "p") {
                                    // una sola parentesi: apre o chiude secondo quelle già aperte
                                    var aperte = (finestra.espressione.match(/\(/g) || []).length - (finestra.espressione.match(/\)/g) || []).length
                                    finestra.premi(aperte > 0 && /[0-9)π]$/.test(finestra.espressione) ? ")" : "(")
                                }
                                else finestra.premi(f)
                            }
                        }
                    }
                }
            }
        }

        // ── Cronologia (si apre a destra) ──
        Rectangle {
            visible: finestra.cronologia
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            radius: 12
            color: Tema.superficie
            border.color: Tema.bordo
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: I18n.t("Cronologia"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    Text {
                        text: I18n.t("Cancella"); color: Tema.accento; font.family: Tema.font; font.pixelSize: 12
                        visible: finestra.storia.length > 0
                        MouseArea { anchors.fill: parent; onClicked: { ponte.chiama0("cancellaStoria"); finestra.storia = [] } }
                    }
                }
                Text {
                    visible: finestra.storia.length === 0
                    text: I18n.t("I calcoli fatti compaiono qui")
                    color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 10
                    model: finestra.storia
                    delegate: Column {
                        width: ListView.view.width
                        spacing: 4
                        Text { text: modelData.giorno; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11; font.weight: Font.DemiBold }
                        Repeater {
                            model: modelData.calcoli
                            Column {
                                width: parent.width
                                Text { width: parent.width; text: modelData.espressione; elide: Text.ElideLeft; horizontalAlignment: Text.AlignRight; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                                Text { width: parent.width; text: "= " + modelData.risultato; horizontalAlignment: Text.AlignRight; color: Tema.testo; font.family: Tema.font; font.pixelSize: 15 }
                                TapHandler { onTapped: { finestra.espressione = modelData.risultato; finestra.risultato = modelData.risultato; finestra.appenaCalcolato = true } }
                            }
                        }
                    }
                }
            }
        }
    }
}
