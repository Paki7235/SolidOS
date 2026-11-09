// Menu del tasto destro del gestore dei file. mostra(voci, x, y) con voci come MenuPopup della shell.
import QtQuick
import QtQuick.Controls
import SolidUI

Popup {
    id: menu
    property var voci: []
    function mostra(v, px, py) {
        voci = v
        x = Math.min(px, parent.width - width - 6)
        y = Math.min(py, parent.height - colonna.implicitHeight - 16)
        open()
    }
    width: 250
    padding: 5
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    background: Rectangle { radius: 10; color: Tema.chiaro ? "#F8FFFFFF" : "#F2232429"; border.color: Tema.chiaro ? "#1F000000" : "#24FFFFFF" }
    contentItem: Column {
        id: colonna
        Repeater {
            model: menu.voci
            Item {
                required property var modelData
                width: colonna.width
                height: modelData.sep ? 9 : 26
                Rectangle { visible: !!modelData.sep; anchors.centerIn: parent; width: parent.width - 16; height: 1; color: Tema.chiaro ? "#1A000000" : "#1FFFFFFF" }
                Rectangle {
                    visible: !modelData.sep
                    anchors.fill: parent
                    radius: 5
                    color: area.containsMouse ? Tema.accento : "transparent"
                    Text {
                        x: 10; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 20; elide: Text.ElideRight
                        text: modelData.t || ""
                        color: area.containsMouse ? "#FFFFFF" : Tema.testo
                        font.family: Tema.font; font.pixelSize: 13
                    }
                    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: { menu.close(); if (modelData.f) modelData.f() } }
                }
            }
        }
    }
}
