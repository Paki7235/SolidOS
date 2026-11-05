import QtQuick
import QtQuick.Controls

TextField {
    id: campo
    color: Tema.testo
    placeholderTextColor: Tema.testoSecondario
    selectionColor: Tema.accento
    font.family: Tema.font
    font.pointSize: Tema.fontDimensione
    leftPadding: 12
    rightPadding: 12
    background: Rectangle {
        implicitHeight: 36
        implicitWidth: 220
        radius: 8
        color: Tema.superficie
        border.width: campo.activeFocus ? 2 : 1
        border.color: campo.activeFocus ? Tema.accento : Tema.bordo
    }
}
