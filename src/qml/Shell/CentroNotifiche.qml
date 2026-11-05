import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Rectangle {
    id: centro
    property var storico: []
    property bool nonDisturbare: false
    signal aggiorna()
    signal cambiaNonDisturbare(bool valore)

    radius: 14
    color: Tema.sfondo
    border.color: Tema.bordo
    MouseArea { anchors.fill: parent }   // i clic dentro il pannello non lo chiudono

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            Titolo { text: I18n.t("Notifiche"); livello: 2; Layout.fillWidth: true }
            Pulsante {
                text: I18n.t("Cancella tutto")
                enabled: centro.storico.length > 0
                onClicked: { shell.chiama0("svuotaNotifiche"); centro.aggiorna() }
            }
        }
        Interruttore {
            text: I18n.t("Non disturbare")
            checked: centro.nonDisturbare
            onToggled: centro.cambiaNonDisturbare(checked)
        }
        Separatore { Layout.fillWidth: true }
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: centro.storico
            delegate: SchedaNotifica {
                width: ListView.view.width
                notifica: modelData
                onChiusa: { shell.chiama("rimuoviNotifica", [modelData.id]); centro.aggiorna() }
                onAzione: function (chiave) { shell.chiama("azioneNotifica", [modelData.id, chiave]); centro.aggiorna() }
            }
            Testo {
                anchors.centerIn: parent
                visible: centro.storico.length === 0
                text: I18n.t("Nessuna notifica")
                secondario: true
            }
        }
    }
}
