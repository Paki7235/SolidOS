// Barra Unica in una finestra normale (se la shell non è in esecuzione).
import QtQuick
import QtQuick.Window
import SolidUI

Window {
    visible: true
    width: 700
    height: 520
    color: Tema.sfondo
    title: I18n.t("Barra Unica")
    BarraUnica {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 20
        width: parent.width - 40
        attiva: true
        onChiudi: Qt.quit()
    }
}
