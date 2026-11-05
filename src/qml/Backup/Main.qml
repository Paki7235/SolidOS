import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Backup")
    width: 720
    property var conf: ponte.chiama0("configurazione")
    property var istantanee: []
    property int avanzamento: -1
    function aggiorna() { conf = ponte.chiama0("configurazione"); if (conf.destinazione) ponte.avvia("istantanee", [], "istantanee") }
    Component.onCompleted: aggiorna()
    Connections {
        target: ponte
        function onEvento(nome, dati) { if (nome === "avanzamento") finestra.avanzamento = dati }
        function onCompletato(id, r) {
            if (id === "istantanee") finestra.istantanee = r
            else if (id === "esegui") { finestra.avanzamento = -1; finestra.avviso(r.ok ? I18n.t("Backup completato") : r.messaggio); finestra.aggiorna() }
            else if (id === "ripristina") finestra.avviso(r.ok ? I18n.t("File ripristinati in") + " " + r.cartella : r.messaggio)
            else if (id === "imposta") { if (r.ok) { chiave.text = r.chiave; dialogoChiave.open() } else finestra.avviso(r.messaggio); finestra.aggiorna() }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16
        Titolo { text: I18n.t("Backup dei tuoi file") }
        Testo { secondario: true; Layout.fillWidth: true; text: I18n.t("Le copie sono cifrate e incrementali: ogni backup salva solo ciò che è cambiato.") }
        Scheda {
            Layout.fillWidth: true
            ColumnLayout {
                width: parent.width
                RigaImpostazione {
                    titolo: I18n.t("Destinazione")
                    descrizione: finestra.conf.destinazione || I18n.t("Nessuna: collega un disco esterno e sceglilo")
                    Pulsante { text: I18n.t("Scegli…"); onClicked: sceltaCartella.open() }
                }
                RigaImpostazione {
                    titolo: I18n.t("Cartelle incluse")
                    descrizione: (finestra.conf.cartelle || []).join(", ")
                }
            }
        }
        RowLayout {
            Pulsante { principale: true; text: I18n.t("Esegui backup ora"); enabled: finestra.conf.destinazione && finestra.avanzamento < 0; onClicked: { finestra.avanzamento = 0; ponte.avvia("esegui", [], "esegui") } }
            Pulsante { text: I18n.t("Mostra chiave di ripristino"); enabled: !!finestra.conf.destinazione; onClicked: { chiave.text = ponte.chiama0("chiaveRipristino"); dialogoChiave.open() } }
        }
        BarraProgresso { Layout.fillWidth: true; visible: finestra.avanzamento >= 0; value: finestra.avanzamento / 100 }
        Titolo { text: I18n.t("Backup precedenti"); livello: 3 }
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: finestra.istantanee
            delegate: VoceElenco {
                width: ListView.view.width
                icona: "document-save"
                titolo: modelData.data
                sottotitolo: modelData.cartelle
                onClicked: { ripristino.ident = modelData.id; ripristino.open() }
            }
        }
    }
    FolderDialog { id: sceltaCartella; onAccepted: ponte.avvia("imposta", [selectedFolder.toString(), []], "imposta") }
    Dialog {
        id: dialogoChiave
        title: I18n.t("Chiave di ripristino")
        anchors.centerIn: parent
        standardButtons: Dialog.Ok
        ColumnLayout {
            Testo { text: I18n.t("Conservala in un luogo sicuro: serve per recuperare i file da un altro computer."); Layout.maximumWidth: 400 }
            CampoTesto { id: chiave; readOnly: true; Layout.fillWidth: true }
        }
    }
    Dialog {
        id: ripristino
        property string ident: ""
        title: I18n.t("Ripristinare questo backup?")
        anchors.centerIn: parent
        standardButtons: Dialog.Cancel | Dialog.Ok
        Testo { text: I18n.t("I file verranno copiati nella cartella «Ripristinati» della tua home, senza sovrascrivere nulla."); Layout.maximumWidth: 400 }
        onAccepted: ponte.avvia("ripristina", [ident, ""], "ripristina")
    }
}
