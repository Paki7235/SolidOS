import QtQuick
import QtQuick.Controls

Slider {
    id: cursore
    background: Rectangle {
        x: cursore.leftPadding
        y: cursore.topPadding + cursore.availableHeight / 2 - height / 2
        implicitWidth: 200
        implicitHeight: 6
        width: cursore.availableWidth
        height: implicitHeight
        radius: 3
        color: Tema.bordo
        Rectangle {
            width: cursore.visualPosition * parent.width
            height: parent.height
            color: Tema.accento
            radius: 3
        }
    }
    handle: Rectangle {
        x: cursore.leftPadding + cursore.visualPosition * (cursore.availableWidth - width)
        y: cursore.topPadding + cursore.availableHeight / 2 - height / 2
        implicitWidth: 20
        implicitHeight: 20
        radius: 10
        color: "#FFFFFF"
        border.color: Tema.accento
        border.width: 2
    }
}
