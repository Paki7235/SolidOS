// Riga di impostazione: titolo, descrizione e controllo a destra (slot «controllo»).
import QtQuick
import QtQuick.Layouts

Item {
    id: riga
    property string titolo: ""
    property string descrizione: ""
    property string icona: ""
    default property alias controllo: contenitore.data
    implicitHeight: Math.max(testi.implicitHeight, contenitore.childrenRect.height) + 20
    width: parent ? parent.width : 400
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 12
        Icona { nome: riga.icona; lato: 22; visible: riga.icona !== "" }
        ColumnLayout {
            id: testi
            Layout.fillWidth: true
            spacing: 2
            Testo { text: riga.titolo; Layout.fillWidth: true }
            Testo { text: riga.descrizione; secondario: true; visible: text !== ""; Layout.fillWidth: true; font.pointSize: Tema.fontDimensione - 1 }
        }
        Item {
            id: contenitore
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
