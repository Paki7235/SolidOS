// Barra superiore con titolo e area per pulsanti.
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: barra
    property string titolo: ""
    default property alias azioni: contenitore.data
    implicitHeight: 56
    color: Tema.superficie
    Separatore { anchors.bottom: parent.bottom; width: parent.width }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 12
        Titolo { text: barra.titolo; livello: 2; Layout.fillWidth: true; elide: Text.ElideRight; wrapMode: Text.NoWrap }
        Row { id: contenitore; spacing: 8 }
    }
}
