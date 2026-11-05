// Barra Unica: cerca app, file, impostazioni ed esegue azioni («wifi off», «installa vlc»…).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Rectangle {
    id: barra
    property bool attiva: false
    property var risultati: []
    property int selezionato: 0
    property string messaggio: ""
    signal chiudi()

    height: colonna.implicitHeight + 24
    radius: 16
    color: Tema.sfondo
    border.color: Tema.bordo
    MouseArea { anchors.fill: parent }

    onAttivaChanged: if (attiva) { campo.text = ""; risultati = []; messaggio = ""; campo.forceActiveFocus() }

    function esegui(r) {
        if (!r) return
        var esito = shell.chiama("barraEsegui", [r])
        if (esito && typeof esito === "string" && esito.length) { messaggio = esito; chiusura.restart() }
        else barra.chiudi()
    }
    Timer { id: chiusura; interval: 1800; onTriggered: barra.chiudi() }
    Timer { id: ritardo; interval: 120; onTriggered: { barra.risultati = shell.chiama("barraCerca", [campo.text]); barra.selezionato = 0 } }

    ColumnLayout {
        id: colonna
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Icona { nome: "system-search"; lato: 24 }
            TextField {
                id: campo
                Layout.fillWidth: true
                placeholderText: I18n.t("Cerca o scrivi cosa fare… (es. «wifi off», «installa vlc», «invia al telefono»)")
                font.pointSize: Tema.fontDimensione + 4
                color: Tema.testo
                placeholderTextColor: Tema.testoSecondario
                background: null
                onTextChanged: { barra.messaggio = ""; ritardo.restart() }
                Keys.onEscapePressed: barra.chiudi()
                Keys.onDownPressed: barra.selezionato = Math.min(barra.selezionato + 1, barra.risultati.length - 1)
                Keys.onUpPressed: barra.selezionato = Math.max(barra.selezionato - 1, 0)
                onAccepted: barra.esegui(barra.risultati[barra.selezionato])
            }
        }
        Testo { visible: barra.messaggio !== ""; text: "✓ " + barra.messaggio; color: Tema.successo; Layout.leftMargin: 34 }
        Separatore { Layout.fillWidth: true; visible: barra.risultati.length > 0 }
        Repeater {
            model: barra.risultati
            VoceElenco {
                Layout.fillWidth: true
                icona: modelData.icona
                titolo: modelData.titolo
                sottotitolo: modelData.sottotitolo
                selezionata: index === barra.selezionato
                onClicked: barra.esegui(modelData)
            }
        }
    }
}
