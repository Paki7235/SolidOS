import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Installa con") + " " + Tema.nomeSistema
    width: 560
    height: 440
    property string file: ponte.chiama0("file")
    property var info: file ? ponte.chiama("analizza", [file]) : ({})
    property string fase: ""
    property var esito: null
    Connections {
        target: ponte
        function onEvento(nome, dati) { if (nome === "fase") finestra.fase = dati }
        function onCompletato(id, r) { finestra.fase = ""; finestra.esito = r }
    }
    Component.onCompleted: if (!file) scelta.open()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 14
        RowLayout {
            spacing: 16
            Icona { nome: finestra.info.tipo === "mac" ? "dialog-error" : "system-software-install"; lato: 64 }
            ColumnLayout {
                Layout.fillWidth: true
                Titolo { text: finestra.info.nome || I18n.t("Scegli un file"); Layout.fillWidth: true }
                Testo { secondario: true; text: (finestra.info.versione ? I18n.t("Versione") + " " + finestra.info.versione + " · " : "") + (finestra.info.dimensione || 0) + " MB · " + (finestra.info.tipo || "").toUpperCase() }
            }
        }
        Testo { text: finestra.info.descrizione || ""; Layout.fillWidth: true; visible: text !== "" }
        Scheda {
            Layout.fillWidth: true
            visible: !!finestra.info.isolamento
            RowLayout {
                width: parent.width
                Icona { nome: "security-high"; lato: 22 }
                Testo { text: finestra.info.isolamento || ""; Layout.fillWidth: true }
            }
        }
        Item { Layout.fillHeight: true }
        BarraProgresso { Layout.fillWidth: true; indeterminate: true; visible: finestra.fase !== "" }
        Testo { text: finestra.fase; visible: text !== ""; Layout.fillWidth: true }
        Testo {
            visible: finestra.esito !== null
            text: finestra.esito ? ((finestra.esito.ok ? "✅ " + I18n.t("Installazione completata") : "⚠️ " + I18n.t("Installazione non riuscita")) + (finestra.esito.messaggio ? "\n" + finestra.esito.messaggio : "")) : ""
            Layout.fillWidth: true
        }
        RowLayout {
            Layout.fillWidth: true
            Pulsante { text: I18n.t("Esegui senza installare"); visible: finestra.info.tipo === "exe"; onClicked: { ponte.chiama("eseguiSenzaInstallare", [finestra.file]); Qt.quit() } }
            Pulsante { text: I18n.t("Cerca un'alternativa"); visible: finestra.info.tipo === "mac"; onClicked: { ponte.chiama("cercaAlternativa", [finestra.info.nome]); Qt.quit() } }
            Item { Layout.fillWidth: true }
            Pulsante { text: finestra.esito ? I18n.t("Chiudi") : I18n.t("Annulla"); onClicked: Qt.quit() }
            Pulsante {
                principale: true
                visible: finestra.info.supportato === true && finestra.esito === null
                enabled: finestra.fase === ""
                text: I18n.t("Installa")
                onClicked: { finestra.fase = I18n.t("Preparazione…"); ponte.avvia("installa", [finestra.file], "installa") }
            }
        }
    }
    FileDialog {
        id: scelta
        nameFilters: [I18n.t("Programmi") + " (*.deb *.rpm *.AppImage *.appimage *.flatpakref *.flatpak *.exe *.msi)"]
        onAccepted: finestra.file = selectedFile.toString().replace("file://", "")
        onRejected: if (!finestra.file) Qt.quit()
    }
}
