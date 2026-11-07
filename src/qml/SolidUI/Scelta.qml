// Menu a tendina compatto. Il modello è un elenco di stringhe o di oggetti {testo, valore}.
import QtQuick
import QtQuick.Controls

ComboBox {
    id: scelta
    font.family: Tema.font
    font.pixelSize: 13
    textRole: "testo"
    valueRole: "valore"
    implicitWidth: 220
    hoverEnabled: true
    background: Rectangle {
        implicitHeight: 28
        radius: 7
        color: scelta.hovered ? Qt.lighter(Tema.superficieAlta, Tema.chiaro ? 1.0 : 1.12) : (Tema.chiaro ? "#FFFFFF" : Tema.superficieAlta)
        border.width: scelta.activeFocus ? 3 : (Tema.chiaro ? 0.5 : 0)
        border.color: scelta.activeFocus ? "#73" + Tema.accento.substring(1) : "#C7C7CC"
    }
    contentItem: Text {
        leftPadding: 10
        rightPadding: 26
        text: scelta.displayText
        font: scelta.font
        color: Tema.testo
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Canvas {
        x: scelta.width - width - 9
        y: (scelta.height - height) / 2
        width: 8
        height: 12
        onPaint: {
            var c = getContext("2d"); c.reset()
            c.strokeStyle = Tema.testoSecondario; c.lineWidth = 1.5; c.lineCap = "round"; c.lineJoin = "round"
            c.beginPath(); c.moveTo(1, 4.5); c.lineTo(4, 1.5); c.lineTo(7, 4.5); c.stroke()
            c.beginPath(); c.moveTo(1, 7.5); c.lineTo(4, 10.5); c.lineTo(7, 7.5); c.stroke()
        }
    }
    delegate: ItemDelegate {
        id: opzione
        width: scelta.width
        height: 28
        hoverEnabled: true
        contentItem: Text {
            text: modelData.testo !== undefined ? modelData.testo : modelData
            font: scelta.font
            color: opzione.highlighted ? "#FFFFFF" : Tema.testo
            verticalAlignment: Text.AlignVCenter
            leftPadding: 4
        }
        highlighted: scelta.highlightedIndex === index
        background: Rectangle { radius: 5; color: opzione.highlighted ? Tema.accento : "transparent" }
    }
    popup.padding: 5
    popup.background: Rectangle { color: Tema.chiaro ? "#FFFFFF" : "#2C2D33"; border.color: Tema.bordo; radius: 9 }
}
