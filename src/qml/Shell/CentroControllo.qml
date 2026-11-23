// Centro di controllo rapido: Wi-Fi, Bluetooth, volume, luminosità, non disturbare,
// luce notturna, visibilità di Condivisione Vicina, Spazi, sessione.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Rectangle {
    id: centro
    property var stato: ({})
    signal chiudi()
    signal aggiorna()

    width: 380
    height: colonna.implicitHeight + 32
    radius: 16
    color: Tema.sfondo
    border.color: Tema.bordo
    MouseArea { anchors.fill: parent }

    function cambia(metodo, valore) {
        shell.avvia(metodo, [valore], metodo)
    }
    Connections {
        target: shell
        function onCompletato(id, valore) { centro.aggiorna() }
    }

    ColumnLayout {
        id: colonna
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 12

        GridLayout {
            columns: 2
            columnSpacing: 10
            rowSpacing: 10
            Layout.fillWidth: true
            PulsanteRapido {
                Layout.fillWidth: true
                icona: centro.stato.wifi ? "network-wireless" : "network-wireless-offline"
                testo: I18n.t("Wi-Fi")
                dettaglio: centro.stato.connesso ? centro.stato.reteNome : (centro.stato.wifi ? I18n.t("Non connesso") : I18n.t("Spento"))
                acceso: centro.stato.wifi === true
                onAttivato: centro.cambia("wifi", !centro.stato.wifi)
                onDettagli: { shell.chiama("apri", ["impostazioni", "rete"]); centro.chiudi() }
            }
            PulsanteRapido {
                Layout.fillWidth: true
                visible: centro.stato.bluetoothDisponibile === true
                icona: "bluetooth"
                testo: I18n.t("Bluetooth")
                dettaglio: centro.stato.bluetooth ? I18n.t("Acceso") : I18n.t("Spento")
                acceso: centro.stato.bluetooth === true
                onAttivato: centro.cambia("bluetooth", !centro.stato.bluetooth)
                onDettagli: { shell.chiama("apri", ["impostazioni", "bluetooth"]); centro.chiudi() }
            }
            PulsanteRapido {
                Layout.fillWidth: true
                icona: "notifications-disabled"
                testo: I18n.t("Non disturbare")
                acceso: centro.stato.nonDisturbare === true
                onAttivato: centro.cambia("nonDisturbare", !centro.stato.nonDisturbare)
            }
            PulsanteRapido {
                Layout.fillWidth: true
                icona: "weather-clear-night"
                testo: I18n.t("Luce notturna")
                acceso: centro.stato.luceNotturna === true
                onAttivato: centro.cambia("luceNotturna", !centro.stato.luceNotturna)
                onDettagli: { shell.chiama("apri", ["impostazioni", "schermo"]); centro.chiudi() }
            }
            PulsanteRapido {
                Layout.fillWidth: true
                Layout.columnSpan: 2
                icona: "document-send"
                testo: I18n.t("Condivisione Vicina")
                dettaglio: centro.stato.visibilita === "tutti10" ? I18n.t("Visibile a tutti per 10 minuti")
                         : centro.stato.visibilita === "associati" ? I18n.t("Visibile ai dispositivi associati")
                         : I18n.t("Non visibile")
                acceso: centro.stato.visibilita !== undefined && centro.stato.visibilita !== "nessuno"
                onAttivato: centro.cambia("visibilita", centro.stato.visibilita === "tutti10" ? "nessuno" : "tutti10")
                onDettagli: { shell.chiama("apri", ["impostazioni", "condivisione"]); centro.chiudi() }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Icona { nome: centro.stato.muto ? "audio-volume-muted" : "audio-volume-high"; lato: 22
                MouseArea { anchors.fill: parent; onClicked: { shell.chiama0("muto"); centro.aggiorna() } } }
            Cursore {
                Layout.fillWidth: true
                from: 0; to: 100
                value: centro.stato.volume || 0
                onMoved: shell.chiama("volume", [Math.round(value)])
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: centro.stato.luminosita >= 0
            Icona { nome: "display-brightness"; lato: 22 }
            Cursore {
                Layout.fillWidth: true
                from: 5; to: 100
                value: centro.stato.luminosita || 50
                onMoved: shell.chiama("luminosita", [Math.round(value)])
            }
        }

        // Spazi di vita
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: shell.chiama0("spazi")
                Pulsante {
                    text: modelData.nome
                    icona: modelData.icona || ""
                    principale: !!(centro.stato.spazio && centro.stato.spazio.id === modelData.id)
                    onClicked: { shell.chiama("attivaSpazio", [modelData.id]); centro.chiudi() }
                }
            }
        }

        Separatore { Layout.fillWidth: true }

        RowLayout {
            Layout.fillWidth: true
            Testo {
                Layout.fillWidth: true
                secondario: true
                text: centro.stato.batteria && centro.stato.batteria.percentuale !== undefined
                      ? I18n.t("Batteria") + " " + centro.stato.batteria.percentuale + "%" + (centro.stato.batteria.in_carica ? " · " + I18n.t("in carica") : "")
                      : Tema.nomeSistema
            }
            Pulsante { icona: "preferences-system"; onClicked: { shell.chiama("apri", ["impostazioni"]); centro.chiudi() } }
            Pulsante { icona: "system-lock-screen"; onClicked: { shell.chiama("sessione", ["blocca"]); centro.chiudi() } }
            Pulsante { icona: "system-shutdown"; onClicked: menuSessione.open() }
        }
    }

    Menu {
        id: menuSessione
        MenuItem { text: I18n.t("Sospendi"); onTriggered: shell.chiama("sessione", ["sospendi"]) }
        MenuItem { text: I18n.t("Esci dalla sessione"); onTriggered: shell.chiama("sessione", ["esci"]) }
        MenuItem { text: I18n.t("Riavvia"); onTriggered: shell.chiama("sessione", ["riavvia"]) }
        MenuItem { text: I18n.t("Spegni"); onTriggered: shell.chiama("sessione", ["spegni"]) }
    }
}
