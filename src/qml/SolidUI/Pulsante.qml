import QtQuick
import QtQuick.Controls

Button {
    id: pulsante
    property bool principale: false
    property bool pericoloso: false
    property string icona: ""
    font.family: Tema.font
    font.pointSize: Tema.fontDimensione
    leftPadding: 16
    rightPadding: 16
    topPadding: 8
    bottomPadding: 8
    icon.name: icona
    icon.width: 18
    icon.height: 18
    icon.color: "transparent"
    hoverEnabled: true

    contentItem: Row {
        spacing: 8
        Icona { nome: pulsante.icona; lato: 18; visible: pulsante.icona !== ""; anchors.verticalCenter: parent.verticalCenter }
        Text {
            text: pulsante.text
            font: pulsante.font
            color: (pulsante.principale || pulsante.pericoloso) ? "#FFFFFF" : Tema.testo
            opacity: pulsante.enabled ? 1 : 0.5
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    background: Rectangle {
        implicitHeight: 36
        radius: 8
        color: pulsante.pericoloso ? Tema.pericolo
             : pulsante.principale ? (pulsante.down ? Tema.accentoScuro : Tema.accento)
             : (pulsante.down ? Tema.bordo : (pulsante.hovered ? Tema.superficieAlta : Tema.superficie))
        border.color: (pulsante.principale || pulsante.pericoloso) ? "transparent" : Tema.bordo
        border.width: 1
        opacity: pulsante.enabled ? 1 : 0.6
        Behavior on color { enabled: Tema.animazioni; ColorAnimation { duration: 120 } }
    }
}
