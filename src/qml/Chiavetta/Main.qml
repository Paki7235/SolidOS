import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Crea chiavetta") + " " + Tema.nomeSistema
    width: 640
    height: 520
    property var chiavette: ponte.chiama0("chiavette")
    property var immagini: ponte.chiama0("immagini")
    property string immagine: immagini.length ? immagini[0] : ""
    property string fase: ""
    Timer { interval: 3000; running: true; repeat: true; onTriggered: finestra.chiavette = ponte.chiama0("chiavette") }
    Connections {
        target: ponte
        function onEvento(n, d) { if (n === "fase") finestra.fase = d }
        function onCompletato(id, r) { finestra.fase = ""; finestra.avviso(r.ok ? I18n.t("Chiavetta pronta!") : r.messaggio) }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 14
        Titolo { text: I18n.t("Il tuo computer in tasca") }
        Testo { Layout.fillWidth: true; secondario: true; text: I18n.t("Crea una chiavetta avviabile con lo spazio per salvare file, impostazioni e app: la porti ovunque e la usi su qualsiasi PC.") }
        RigaImpostazione {
            Layout.fillWidth: true
            titolo: I18n.t("Immagine del sistema (.iso)")
            descrizione: finestra.immagine || I18n.t("Nessuna: scarica l'immagine oppure sceglila")
            Pulsante { text: I18n.t("Scegli…"); onClicked: sceltaIso.open() }
        }
        RigaImpostazione {
            Layout.fillWidth: true
            titolo: I18n.t("Chiavetta")
            descrizione: finestra.chiavette.length ? "" : I18n.t("Collega una chiavetta USB da almeno 8 GB")
            Scelta { id: chiavetta; model: finestra.chiavette.map(function (c) { return { testo: c.nome + " · " + c.dimensione + " GB", valore: c.percorso } }) }
        }
        RigaImpostazione {
            Layout.fillWidth: true
            titolo: I18n.t("Salva i dati sulla chiavetta (persistenza)")
            descrizione: I18n.t("Usa tutto lo spazio libero per i tuoi file e le tue app")
            Interruttore { id: persistenza; checked: true }
        }
        Testo { color: Tema.pericolo; Layout.fillWidth: true; text: I18n.t("Attenzione: tutto il contenuto della chiavetta verrà cancellato.") }
        BarraProgresso { Layout.fillWidth: true; indeterminate: true; visible: finestra.fase !== "" }
        Testo { text: finestra.fase; visible: text !== "" }
        Item { Layout.fillHeight: true }
        Pulsante {
            Layout.alignment: Qt.AlignRight
            principale: true
            text: I18n.t("Crea chiavetta")
            enabled: finestra.immagine !== "" && finestra.chiavette.length > 0 && finestra.fase === ""
            onClicked: { finestra.fase = "…"; ponte.avvia("crea", [finestra.immagine, chiavetta.currentValue, persistenza.checked], "crea") }
        }
    }
    FileDialog { id: sceltaIso; nameFilters: ["ISO (*.iso)"]; onAccepted: finestra.immagine = selectedFile.toString().replace("file://", "") }
}
