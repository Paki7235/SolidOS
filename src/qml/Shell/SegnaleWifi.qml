// Tacche del Wi-Fi come su telefono e Windows: quante sono piene dice quanto è forte
// il segnale, cioè quanto si è vicini al modem. Senza rete: tacche vuote e una lineetta.
import QtQuick

Item {
    id: segnale
    property int percento: 0          // 0-100 (qualità del collegamento)
    property bool connesso: false
    property color colore: Tema.testoVetro
    readonly property int tacche: !connesso ? 0 : (percento >= 75 ? 4 : percento >= 50 ? 3 : percento >= 25 ? 2 : 1)
    width: 18
    height: 14
    Row {
        anchors.bottom: parent.bottom
        spacing: 2
        Repeater {
            model: 4
            Rectangle {
                required property int index
                anchors.bottom: parent.bottom
                width: 3
                height: 4 + index * 3.33
                radius: 1
                color: index < segnale.tacche ? segnale.colore : Qt.rgba(segnale.colore.r, segnale.colore.g, segnale.colore.b, 0.28)
            }
        }
    }
    Rectangle {
        visible: !segnale.connesso
        anchors.right: parent.right; anchors.top: parent.top
        width: 6; height: 2; radius: 1
        color: segnale.colore
    }
}
