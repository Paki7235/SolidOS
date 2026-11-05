// Linea del Tempo: scorri all'indietro e ripristina file, cartelle o l'intero sistema.
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Linea del Tempo")
    width: 1040
    height: 680
    property var stato: ponte.chiama0("stato")
    property string percorso: stato.iniziale
    property var versioni: []
    property int indice: 0
    property var versione: versioni.length ? versioni[indice] : null
    property var anteprima: ({})
    property var punti: []

    function carica() {
        versioni = ponte.chiama("versioni", [percorso])
        indice = 0
        aggiornaAnteprima()
    }
    function aggiornaAnteprima() { anteprima = versione ? ponte.chiama("contenuto", [versione.percorso]) : ({}) }
    Component.onCompleted: { carica(); if (stato.disponibile) punti = ponte.chiama0("sistema") }
    Connections {
        target: ponte
        function onCompletato(id, r) {
            finestra.avviso(r.messaggio || (r.ok ? I18n.t("Fatto") : I18n.t("Operazione non riuscita")))
            if (id === "torna" && r.ok) riavvio.open()
            if (id === "punto") finestra.punti = ponte.chiama0("sistema")
            if (id === "ripristina") finestra.carica()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            visible: finestra.stato.daSnapshot > 0
            color: Tema.avviso
            implicitHeight: 60
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                Testo { color: "#000000"; Layout.fillWidth: true; text: I18n.t("Stai usando il sistema com'era in un punto di ripristino. Le modifiche di questa sessione non verranno salvate.") }
                Pulsante { principale: true; text: I18n.t("Rendi permanente"); onClicked: ponte.avvia("tornaA", [finestra.stato.daSnapshot], "torna") }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            visible: !finestra.stato.disponibile
            color: Tema.superficieAlta
            implicitHeight: 48
            Testo { anchors.centerIn: parent; text: I18n.t("La Linea del Tempo è disponibile dopo l'installazione su disco (file system Btrfs).") }
        }

        TabBar {
            id: schede
            Layout.fillWidth: true
            TabButton { text: I18n.t("File e cartelle") }
            TabButton { text: I18n.t("Sistema") }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: schede.currentIndex

            // ── File e cartelle ──────────────────────────────────────────
            ColumnLayout {
                spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: 16
                    CampoTesto { id: campoPercorso; Layout.fillWidth: true; text: finestra.percorso; onAccepted: { finestra.percorso = text; finestra.carica() } }
                    Pulsante { text: I18n.t("File…"); onClicked: sceltaFile.open() }
                    Pulsante { text: I18n.t("Cartella…"); onClicked: sceltaCartella.open() }
                }

                // Il cursore del tempo: a destra «adesso», a sinistra il passato
                Scheda {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    ColumnLayout {
                        width: parent.width
                        RowLayout {
                            Layout.fillWidth: true
                            Testo { text: I18n.t("Passato"); secondario: true }
                            Item { Layout.fillWidth: true }
                            Titolo { livello: 3; text: finestra.versione ? (finestra.versione.attuale ? I18n.t("Adesso") : finestra.versione.data) : I18n.t("Nessuna versione") }
                            Item { Layout.fillWidth: true }
                            Testo { text: I18n.t("Adesso"); secondario: true }
                        }
                        Cursore {
                            Layout.fillWidth: true
                            from: Math.max(finestra.versioni.length - 1, 0)
                            to: 0
                            stepSize: 1
                            snapMode: Slider.SnapAlways
                            value: finestra.indice
                            enabled: finestra.versioni.length > 1
                            onMoved: { finestra.indice = Math.round(value); finestra.aggiornaAnteprima() }
                        }
                        Testo {
                            secondario: true
                            text: finestra.versioni.length > 1
                                  ? I18n.t("Versioni trovate:") + " " + finestra.versioni.length + (finestra.versione && finestra.versione.descrizione ? " · " + finestra.versione.descrizione : "")
                                  : I18n.t("Non ci sono versioni precedenti di questo elemento")
                        }
                    }
                }

                Scheda {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Loader {
                        anchors.fill: parent
                        sourceComponent: finestra.anteprima.tipo === "immagine" ? compImmagine : (finestra.anteprima.tipo === "cartella" ? compCartella : compTesto)
                    }
                    Component { id: compImmagine; Image { source: "file://" + finestra.anteprima.percorso; fillMode: Image.PreserveAspectFit; asynchronous: true } }
                    Component {
                        id: compTesto
                        ScrollView { TextArea { readOnly: true; text: finestra.anteprima.testo || ""; color: Tema.testo; wrapMode: TextEdit.Wrap; background: null } }
                    }
                    Component {
                        id: compCartella
                        ListView {
                            clip: true
                            model: finestra.anteprima.voci || []
                            delegate: VoceElenco {
                                width: ListView.view.width
                                icona: modelData.cartella ? "folder" : "text-x-generic"
                                titolo: modelData.nome
                                onDoubleClicked: if (finestra.versione && finestra.versione.attuale) { finestra.percorso = modelData.percorso; finestra.carica() }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: 16
                    Item { Layout.fillWidth: true }
                    Pulsante {
                        text: I18n.t("Ripristina come copia")
                        enabled: finestra.versione && !finestra.versione.attuale
                        onClicked: ponte.avvia("ripristina", [finestra.versione.percorso, finestra.percorso, false], "ripristina")
                    }
                    Pulsante {
                        principale: true
                        text: I18n.t("Ripristina questa versione")
                        enabled: finestra.versione && !finestra.versione.attuale
                        onClicked: conferma.open()
                    }
                }
            }

            // ── Sistema ──────────────────────────────────────────────────
            ColumnLayout {
                spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: 16
                    Testo { Layout.fillWidth: true; text: I18n.t("Punti di ripristino dell'intero sistema. Se il computer non si avvia, all'accensione scegli «Torna a ieri».") }
                    Pulsante { text: I18n.t("Crea punto adesso"); icona: "list-add"; enabled: finestra.stato.disponibile; onClicked: ponte.avvia("creaPunto", [""], "punto") }
                }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    clip: true
                    spacing: 4
                    model: finestra.punti
                    delegate: Scheda {
                        width: ListView.view.width
                        RowLayout {
                            width: parent.width
                            Icona { nome: modelData.tipo === "pre" ? "system-software-update" : "document-open-recent"; lato: 28 }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Testo { text: modelData.data; font.weight: Font.DemiBold }
                                Testo { text: modelData.descrizione || (modelData.pulizia === "timeline" ? I18n.t("Punto automatico") : ""); secondario: true }
                            }
                            Pulsante { text: I18n.t("Torna a questo punto"); onClicked: { tornaDialogo.numero = modelData.numero; tornaDialogo.data = modelData.data; tornaDialogo.open() } }
                        }
                    }
                    Testo { anchors.centerIn: parent; visible: finestra.punti.length === 0; secondario: true; text: I18n.t("Nessun punto di ripristino") }
                }
            }
        }
    }

    FileDialog { id: sceltaFile; onAccepted: { finestra.percorso = selectedFile.toString().replace("file://", ""); finestra.carica() } }
    FolderDialog { id: sceltaCartella; onAccepted: { finestra.percorso = selectedFolder.toString().replace("file://", ""); finestra.carica() } }
    Dialog {
        id: conferma
        title: I18n.t("Ripristinare questa versione?")
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Cancel | Dialog.Ok
        Testo { text: I18n.t("La versione attuale verrà spostata nel cestino, così potrai recuperarla se cambi idea."); width: 380 }
        onAccepted: ponte.avvia("ripristina", [finestra.versione.percorso, finestra.percorso, true], "ripristina")
    }
    Dialog {
        id: tornaDialogo
        property int numero: 0
        property string data: ""
        title: I18n.t("Tornare al") + " " + data + "?"
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Cancel | Dialog.Ok
        Testo { width: 420; text: I18n.t("Programmi e impostazioni di sistema torneranno com'erano in quel momento. I tuoi documenti nella cartella personale non vengono toccati. Il sistema attuale resta conservato per 30 giorni.") }
        onAccepted: ponte.avvia("tornaA", [numero], "torna")
    }
    Dialog {
        id: riavvio
        title: I18n.t("Ripristino pronto")
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Close | Dialog.Ok
        Testo { text: I18n.t("Riavviare adesso?") }
        onAccepted: ponte.chiama0("riavvia")
    }
}
