// Pulsante del centro di controllo: icona + etichetta, acceso/spento.
import QtQuick
import QtQuick.Layouts
import SolidUI

Rectangle {
    id: pulsante
    property string icona: ""
    property string testo: ""
    property string dettaglio: ""
    property bool acceso: false
    signal attivato()
    signal dettagli()

    implicitHeight: 64
    radius: 12
    color: acceso ? Tema.accento : (area.containsMouse ? Tema.superficieAlta : Tema.superficie)
    border.color: acceso ? "transparent" : Tema.bordo
    Behavior on color { enabled: Tema.animazioni; ColorAnimation { duration: 120 } }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function (e) { if (e.button === Qt.RightButton) pulsante.dettagli(); else pulsante.attivato() }
    }
    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10
        Icona { nome: pulsante.icona; lato: 22 }
        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            Text { text: pulsante.testo; color: pulsante.acceso ? "#FFFFFF" : Tema.testo; font.family: Tema.font; font.pointSize: Tema.fontDimensione; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
            Text { text: pulsante.dettaglio; visible: text !== ""; color: pulsante.acceso ? "#E6FFFFFF" : Tema.testoSecondario; font.family: Tema.font; font.pointSize: Tema.fontDimensione - 2; elide: Text.ElideRight; Layout.fillWidth: true }
        }
    }
}
