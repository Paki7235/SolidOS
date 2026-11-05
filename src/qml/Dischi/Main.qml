import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Dischi")
    property var dischi: []
    property int selezionato: 0
    property var disco: dischi.length ? dischi[Math.min(selezionato, dischi.length - 1)] : null
    property string occupato: ""
    function aggiorna() { dischi = ponte.chiama0("dischi") }
    Component.onCompleted: aggiorna()
    Timer { interval: 4000; running: true; repeat: true; onTriggered: finestra.aggiorna() }

    function lavora(metodo, args, messaggio) {
        occupato = messaggio
        ponte.avvia(metodo, args, metodo)
    }
    Connections {
        target: ponte
        function onCompletato(id, r) {
            finestra.occupato = ""
            if (id === "salute") salute.mostra(r)
            else finestra.avviso(r.ok ? I18n.t("Operazione completata") : (r.messaggio || I18n.t("Operazione non riuscita")))
            finestra.aggiorna()
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.preferredWidth: 280
            Layout.fillHeight: true
            color: Tema.superficie
            ListView {
                anchors.fill: parent
                anchors.margins: 10
                model: finestra.dischi
                delegate: VoceElenco {
                    width: ListView.view.width
                    icona: modelData.rimovibile ? "drive-removable-media" : "drive-harddisk"
                    titolo: modelData.modello || modelData.percorso
                    sottotitolo: modelData.dimensione + " GB · " + modelData.percorso
                    selezionata: index === finestra.selezionato
                    onClicked: finestra.selezionato = index
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 20
            spacing: 12
            visible: finestra.disco !== null
            Titolo { text: finestra.disco ? (finestra.disco.modello || finestra.disco.percorso) : "" }
            Testo { secondario: true; text: finestra.disco ? finestra.disco.dimensione + " GB · " + (finestra.disco.collegamento || "") : "" }
            Row {
                spacing: 8
                Pulsante { text: I18n.t("Salute del disco"); icona: "dialog-information"; onClicked: finestra.lavora("salute", [finestra.disco.percorso], I18n.t("Lettura SMART…")) }
                Pulsante { text: I18n.t("Espelli"); icona: "media-eject"; visible: finestra.disco && finestra.disco.rimovibile; onClicked: finestra.lavora("espelli", [finestra.disco.percorso], I18n.t("Espulsione…")) }
                Pulsante { text: I18n.t("Scrivi immagine…"); icona: "media-write"; visible: finestra.disco && finestra.disco.rimovibile; onClicked: sceltaImmagine.open() }
            }
            BarraProgresso { indeterminate: true; visible: finestra.occupato !== ""; Layout.fillWidth: true }
            Testo { text: finestra.occupato; visible: text !== "" }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8
                clip: true
                model: finestra.disco ? finestra.disco.partizioni : []
                delegate: Scheda {
                    width: ListView.view.width
                    RowLayout {
                        width: parent.width
                        ColumnLayout {
                            Layout.fillWidth: true
                            Testo { text: modelData.nome + "  (" + modelData.percorso + ")"; font.weight: Font.DemiBold }
                            Testo { secondario: true; text: (modelData.fs || I18n.t("non formattata")) + " · " + modelData.dimensione + " GB" + (modelData.montata ? " · " + I18n.t("libero") + " " + modelData.libero + " GB · " + modelData.punto : "") }
                        }
                        Pulsante { text: modelData.montata ? I18n.t("Smonta") : I18n.t("Monta"); onClicked: finestra.lavora(modelData.montata ? "smonta" : "monta", [modelData.percorso], "…") }
                        Pulsante { text: I18n.t("Formatta…"); pericoloso: true; onClicked: { formatta.percorso = modelData.percorso; formatta.open() } }
                    }
                }
            }
        }
    }

    Dialog {
        id: formatta
        property string percorso: ""
        title: I18n.t("Formatta") + " " + percorso
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Cancel | Dialog.Ok
        ColumnLayout {
            Testo { text: I18n.t("Tutti i dati della partizione verranno cancellati."); color: Tema.pericolo }
            Scelta { id: tipoFs; model: [{ testo: "exFAT (" + I18n.t("compatibile con tutto") + ")", valore: "exfat" }, { testo: "FAT32", valore: "vfat" }, { testo: "NTFS (Windows)", valore: "ntfs" }, { testo: "ext4 (Linux)", valore: "ext4" }] }
            CampoTesto { id: etichetta; placeholderText: I18n.t("Nome del disco") }
        }
        onAccepted: finestra.lavora("formatta", [percorso, tipoFs.currentValue, etichetta.text], I18n.t("Formattazione…"))
    }
    Dialog {
        id: salute
        function mostra(r) { testoSalute.text = r.ok ? ((r.superato ? "✅ " + I18n.t("Il disco è in buona salute") : "⚠️ " + I18n.t("Il disco segnala problemi: fai subito un backup")) + "\n" + I18n.t("Ore di accensione") + ": " + (r.ore || "?") + "\n" + I18n.t("Temperatura") + ": " + (r.temperatura || "?") + " °C") : r.messaggio; open() }
        title: I18n.t("Salute del disco")
        anchors.centerIn: parent
        standardButtons: Dialog.Ok
        Testo { id: testoSalute }
    }
    FileDialog {
        id: sceltaImmagine
        nameFilters: [I18n.t("Immagini disco") + " (*.iso *.img)"]
        onAccepted: finestra.lavora("scriviImmagine", [selectedFile.toString(), finestra.disco.percorso], I18n.t("Scrittura dell'immagine…"))
    }
}
