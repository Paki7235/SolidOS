// Menu a comparsa della shell. voci: [{ t: "Testo", f: function }, { sep: true }, { titolo: "Intestazione" }]
// Facoltativi: spunta (✓), disattiva, sotto: [voci…] (sottomenu, con «‹ Indietro»).
import QtQuick
import SolidUI

Rectangle {
    id: menu
    property var voci: []
    property var sottovoci: null
    readonly property var mostrate: sottovoci !== null ? [{ t: "‹  " + I18n.t("Indietro"), indietro: true }, { sep: true }].concat(sottovoci) : voci
    onVociChanged: sottovoci = null
    onVisibleChanged: if (!visible) sottovoci = null
    signal scelto()
    width: 250
    height: colonna.implicitHeight + 10
    radius: 10
    color: Tema.vetro
    border.color: Tema.vetroBordo
    border.width: 1
    // blocca i clic sul fondo trasparente dietro al menu
    MouseArea { anchors.fill: parent }
    Column {
        id: colonna
        x: 5; y: 5
        width: menu.width - 10
        Repeater {
            model: menu.mostrate
            Item {
                required property var modelData
                width: colonna.width
                height: modelData.sep ? 9 : (modelData.titolo !== undefined ? 26 : 26)
                Rectangle { visible: !!modelData.sep; anchors.centerIn: parent; width: parent.width - 16; height: 1; color: Tema.separatore }
                Text {
                    visible: modelData.titolo !== undefined
                    x: 10; anchors.verticalCenter: parent.verticalCenter
                    text: modelData.titolo || ""
                    color: Tema.testoVetroSecondario; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold
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
                        text: (modelData.spunta === true ? "✓  " : (modelData.spunta === false ? "     " : "")) + (modelData.t || "")
                        color: area.containsMouse ? "#FFFFFF" : (modelData.disattiva ? Tema.testoVetroSecondario : Tema.testoVetro); font.family: Tema.font; font.pixelSize: 13
                    }
                    Text {
                        visible: !!modelData.sotto
                        anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                        text: "›"; color: area.containsMouse ? "#FFFFFF" : Tema.testoVetroSecondario; font.pixelSize: 15
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: !modelData.disattiva
                        onClicked: {
                            if (modelData.disattiva) return
                            if (modelData.sotto) { menu.sottovoci = modelData.sotto; return }
                            if (modelData.indietro) { menu.sottovoci = null; return }
                            if (modelData.f) modelData.f()
                            menu.scelto()
                        }
                    }
                }
            }
        }
    }
}
