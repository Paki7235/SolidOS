// Riga cliccabile con icona, titolo e sottotitolo.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ItemDelegate {
    id: voce
    property string icona: ""
    property string titolo: ""
    property string sottotitolo: ""
    property bool selezionata: false
    width: parent ? parent.width : 300
    hoverEnabled: true
    background: Rectangle {
        radius: 8
        color: voce.selezionata ? Qt.rgba(0.23, 0.51, 0.96, 0.22) : (voce.hovered ? Tema.superficieAlta : "transparent")
    }
    contentItem: RowLayout {
        spacing: 12
        Icona { nome: voce.icona; lato: 24; visible: voce.icona !== "" }
        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            Testo { text: voce.titolo; Layout.fillWidth: true; elide: Text.ElideRight; wrapMode: Text.NoWrap }
            Testo { text: voce.sottotitolo; secondario: true; visible: text !== ""; Layout.fillWidth: true; elide: Text.ElideRight; wrapMode: Text.NoWrap; font.pointSize: Tema.fontDimensione - 1 }
        }
    }
}
