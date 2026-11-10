// Menu del tasto destro del gestore dei file. mostra(voci, x, y) con voci come MenuPopup della shell:
// { t: "Testo", f: function, spunta: bool, sotto: [voci…] } · { sep: true }.
// Una voce con «sotto» apre il sottomenu (con «‹ Indietro» per tornare).
import QtQuick
import QtQuick.Controls
import SolidUI

Popup {
    id: menu
    property var voci: []
    property var principali: []
    function mostra(v, px, py) {
        voci = v; principali = v
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
                        text: (modelData.spunta === true ? "✓  " : (modelData.spunta === false ? "     " : "")) + (modelData.t || "")
                        color: area.containsMouse ? "#FFFFFF" : (modelData.disattiva ? Tema.testoSecondario : Tema.testo)
                        font.family: Tema.font; font.pixelSize: 13
                    }
                    Text {
                        visible: !!modelData.sotto
                        anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                        text: "›"; color: area.containsMouse ? "#FFFFFF" : Tema.testoSecondario; font.pixelSize: 15
                    }
                    MouseArea {
                        id: area; anchors.fill: parent; hoverEnabled: !modelData.disattiva
                        onClicked: {
                            if (modelData.disattiva) return
                            if (modelData.sotto) { menu.voci = [{ t: "‹  " + I18n.t("Indietro"), f: null, indietro: true }, { sep: true }].concat(modelData.sotto); return }
                            if (modelData.indietro) { menu.voci = menu.principali; return }
                            menu.close(); if (modelData.f) modelData.f()
                        }
                    }
                }
            }
        }
    }
}
