// Contenitore arrotondato per raggruppare contenuti.
import QtQuick

Rectangle {
    default property alias contenuto: interno.data
    property int margine: 16
    color: Tema.superficie
    radius: Tema.raggio
    border.color: Tema.bordo
    border.width: 1
    implicitHeight: interno.childrenRect.height + margine * 2
    Item {
        id: interno
        anchors.fill: parent
        anchors.margins: parent.margine
    }
}
