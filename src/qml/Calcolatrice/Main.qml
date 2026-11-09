// Calcolatrice: tastierino o tastiera del computer; Invio calcola, Esc cancella.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Calcolatrice")
    width: 340
    height: 520
    minimumWidth: 300
    minimumHeight: 460
    property string espressione: ""
    property string risultato: "0"
    property bool appenaCalcolato: false
    property var storia: []

    function premi(t) {
        if (appenaCalcolato && /[0-9(π√]/.test(t)) espressione = ""
        appenaCalcolato = false
        espressione += t
        var r = ponte.chiama("calcola", [espressione])
        if (r.ok) risultato = r.risultato
    }
    function uguale() {
        if (!espressione) return
        var r = ponte.chiama("calcola", [espressione])
        if (!r.ok) { risultato = I18n.t(r.errore); return }
        storia = [espressione + " = " + r.risultato].concat(storia).slice(0, 20)
        risultato = r.risultato
        espressione = r.grezzo.replace(".", ",")
        appenaCalcolato = true
    }
    function cancella() { espressione = ""; risultato = "0"; appenaCalcolato = false }
    function indietro() { espressione = espressione.slice(0, -1); appenaCalcolato = false }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: function (ev) {
            var t = ev.text
            if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter || t === "=") finestra.uguale()
            else if (ev.key === Qt.Key_Escape || ev.key === Qt.Key_Delete) finestra.cancella()
            else if (ev.key === Qt.Key_Backspace) finestra.indietro()
            else if ("0123456789+-*/().,%^".indexOf(t) >= 0 && t !== "") finestra.premi(t === "*" ? "×" : t === "/" ? "÷" : t === "." ? "," : t)
            else return
            ev.accepted = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10
        // Display
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideLeft
                text: finestra.storia.length ? finestra.storia[0] : " "
                color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideLeft
                text: finestra.espressione || "0"
                color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 16
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 18
                text: finestra.risultato
                color: Tema.testo; font.family: Tema.font; font.pixelSize: 42; font.weight: Font.Light
                font.features: ({ "tnum": 1 })
            }
        }
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 4
            rowSpacing: 8
            columnSpacing: 8
            Repeater {
                model: [
                    { t: "C", f: "c", k: 1 }, { t: "⌫", f: "b", k: 1 }, { t: "%", f: "%", k: 1 }, { t: "÷", f: "÷", k: 2 },
                    { t: "7" }, { t: "8" }, { t: "9" }, { t: "×", f: "×", k: 2 },
                    { t: "4" }, { t: "5" }, { t: "6" }, { t: "−", f: "-", k: 2 },
                    { t: "1" }, { t: "2" }, { t: "3" }, { t: "+", f: "+", k: 2 },
                    { t: "√", f: "√(", k: 1 }, { t: "0" }, { t: ",", f: "," }, { t: "=", f: "=", k: 3 },
                    { t: "(", k: 1 }, { t: ")", k: 1 }, { t: "xʸ", f: "^", k: 1 }, { t: "π", k: 1 }
                ]
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 40
                    radius: 10
                    color: modelData.k === 3 ? (area.pressed ? Tema.accentoScuro : Tema.accento)
                         : modelData.k === 2 ? (area.pressed ? "#C2700A" : "#F0920F")
                         : modelData.k === 1 ? (area.pressed ? Qt.darker(Tema.superficieAlta, 1.2) : Qt.lighter(Tema.superficieAlta, Tema.chiaro ? 0.95 : 1.15))
                         : (area.pressed ? Qt.darker(Tema.superficie, 1.2) : Tema.superficieAlta)
                    Text {
                        anchors.centerIn: parent
                        text: modelData.t
                        color: modelData.k >= 2 ? "#FFFFFF" : Tema.testo
                        font.family: Tema.font; font.pixelSize: 20; font.weight: Font.Medium
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        onClicked: {
                            var f = modelData.f !== undefined ? modelData.f : modelData.t
                            if (f === "c") finestra.cancella()
                            else if (f === "b") finestra.indietro()
                            else if (f === "=") finestra.uguale()
                            else finestra.premi(f)
                        }
                    }
                }
            }
        }
    }
}
