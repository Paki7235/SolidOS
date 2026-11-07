// Menu a comparsa della shell. voci: [{ t: "Testo", f: function }, { sep: true }, { titolo: "Intestazione" }]
import QtQuick
import SolidUI

Rectangle {
    id: menu
    property var voci: []
    signal scelto()
    width: 250
    height: colonna.implicitHeight + 10
    radius: 10
    color: "#F2232429"
    border.color: "#24FFFFFF"
    border.width: 1
    // blocca i clic sul fondo trasparente dietro al menu
    MouseArea { anchors.fill: parent }
    Column {
        id: colonna
        x: 5; y: 5
        width: menu.width - 10
        Repeater {
            model: menu.voci
            Item {
                required property var modelData
                width: colonna.width
                height: modelData.sep ? 9 : (modelData.titolo !== undefined ? 26 : 26)
                Rectangle { visible: !!modelData.sep; anchors.centerIn: parent; width: parent.width - 16; height: 1; color: "#1FFFFFFF" }
                Text {
                    visible: modelData.titolo !== undefined
                    x: 10; anchors.verticalCenter: parent.verticalCenter
                    text: modelData.titolo || ""
                    color: "#8E8E96"; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold
                }
                Rectangle {
                    visible: modelData.t !== undefined
                    anchors.fill: parent
                    radius: 5
                    color: area.containsMouse ? Tema.accento : "transparent"
                    Text {
                        x: 10; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 20
                        elide: Text.ElideRight
                        text: modelData.t || ""
                        color: area.containsMouse ? "#FFFFFF" : "#F5F5F7"; font.family: Tema.font; font.pixelSize: 13
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: { if (modelData.f) modelData.f(); menu.scelto() }
                    }
                }
            }
        }
    }
}
