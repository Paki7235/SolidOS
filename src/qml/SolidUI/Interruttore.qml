import QtQuick
import QtQuick.Controls

Switch {
    id: interruttore
    hoverEnabled: true
    indicator: Rectangle {
        implicitWidth: 44
        implicitHeight: 24
        x: interruttore.leftPadding
        y: parent.height / 2 - height / 2
        radius: 12
        color: interruttore.checked ? Tema.accento : Tema.bordo
        Behavior on color { enabled: Tema.animazioni; ColorAnimation { duration: 120 } }
        Rectangle {
            x: interruttore.checked ? parent.width - width - 3 : 3
            y: 3
            width: 18
            height: 18
            radius: 9
            color: "#FFFFFF"
            Behavior on x { enabled: Tema.animazioni; NumberAnimation { duration: 120 } }
        }
    }
    contentItem: Text {
        text: interruttore.text
        font: interruttore.font
        color: Tema.testo
        verticalAlignment: Text.AlignVCenter
        leftPadding: interruttore.indicator.width + 10
    }
}
