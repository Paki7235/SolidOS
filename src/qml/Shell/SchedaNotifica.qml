// Una notifica: icona, titolo, testo, avanzamento e azioni.
import QtQuick
import QtQuick.Layouts
import SolidUI

Rectangle {
    id: scheda
    property var notifica: ({})
    property bool aComparsa: false
    signal chiusa()
    signal scaduta()
    signal azione(string chiave)

    radius: 12
    color: Tema.superficie
    border.color: notifica.urgenza === 2 ? Tema.pericolo : Tema.bordo
    implicitHeight: colonna.implicitHeight + 24

    Timer {
        running: scheda.aComparsa && scheda.notifica.scadenza > 0 && !area.containsMouse
        interval: scheda.notifica.scadenza || 6000
        onTriggered: scheda.scaduta()
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            var predefinita = (scheda.notifica.azioni || []).filter(function (a) { return a.chiave === "default" })
            if (predefinita.length) scheda.azione("default"); else scheda.chiusa()
        }
    }
    ColumnLayout {
        id: colonna
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8
        RowLayout {
            spacing: 10
            Layout.fillWidth: true
            Icona {
                nome: scheda.notifica.icona || "dialog-information"
                lato: 36
                Layout.alignment: Qt.AlignTop
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    Testo { text: scheda.notifica.app || ""; secondario: true; font.pointSize: Tema.fontDimensione - 2; Layout.fillWidth: true; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                    Testo { text: scheda.notifica.ora || ""; secondario: true; font.pointSize: Tema.fontDimensione - 2 }
                }
                Testo { text: scheda.notifica.titolo || ""; font.weight: Font.DemiBold; Layout.fillWidth: true }
                Text {
                    text: scheda.notifica.testo || ""
                    visible: text !== ""
                    color: Tema.testoSecondario
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    maximumLineCount: 6
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    font.family: Tema.font
                    font.pointSize: Tema.fontDimensione
                    onLinkActivated: function (link) { Qt.openUrlExternally(link) }
                }
            }
            Pulsante {
                text: "✕"
                Layout.alignment: Qt.AlignTop
                leftPadding: 8; rightPadding: 8; topPadding: 2; bottomPadding: 2
                onClicked: scheda.chiusa()
            }
        }
        BarraProgresso {
            visible: scheda.notifica.valore >= 0
            value: Math.max(0, scheda.notifica.valore) / 100
            Layout.fillWidth: true
        }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            visible: (scheda.notifica.azioni || []).length > 0
            Repeater {
                model: (scheda.notifica.azioni || []).filter(function (a) { return a.chiave !== "default" })
                Pulsante {
                    text: modelData.testo
                    principale: index === 0
                    onClicked: scheda.azione(modelData.chiave)
                }
            }
        }
    }
}
