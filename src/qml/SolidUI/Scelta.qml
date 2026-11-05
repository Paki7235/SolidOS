// Menu a tendina. Il modello è un elenco di stringhe o di oggetti {testo, valore}.
import QtQuick
import QtQuick.Controls

ComboBox {
    id: scelta
    font.family: Tema.font
    font.pointSize: Tema.fontDimensione
    textRole: "testo"
    valueRole: "valore"
    implicitWidth: 240
    background: Rectangle {
        implicitHeight: 36
        radius: 8
        color: Tema.superficie
        border.color: scelta.activeFocus ? Tema.accento : Tema.bordo
    }
    contentItem: Text {
        leftPadding: 12
        text: scelta.displayText
        font: scelta.font
        color: Tema.testo
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    delegate: ItemDelegate {
        width: scelta.width
        text: modelData.testo !== undefined ? modelData.testo : modelData
        highlighted: scelta.highlightedIndex === index
        palette.text: Tema.testo
        background: Rectangle { color: highlighted ? Tema.accento : Tema.superficie }
    }
    popup.background: Rectangle { color: Tema.superficie; border.color: Tema.bordo; radius: 8 }
}
