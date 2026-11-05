// Impostazioni: elenco dei pannelli a sinistra, voci a destra, ricerca globale e interna.
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Impostazioni")
    width: 1040
    height: 700
    property var pannelli: ponte.chiama0("pannelli")
    property string corrente: ponte.chiama0("iniziale")
    property string titoloCorrente: {
        for (var i = 0; i < pannelli.length; i++) if (pannelli[i].id === corrente) return pannelli[i].titolo
        return ""
    }
    property var voci: []
    property bool caricamento: false
    property string evidenzia: ""
    property var risultati: []

    function carica() {
        caricamento = true
        ponte.avvia("voci", [corrente], "voci:" + corrente)
    }
    function apri(id, voce) { corrente = id; evidenzia = voce || ""; campoFiltro.text = ""; carica() }
    function imposta(voce, valore) { ponte.avvia("imposta", [corrente, voce, valore], "imposta") }
    function esegui(voce, elemento, azione, dati) { ponte.avvia("azione", [corrente, voce, elemento, azione, dati || {}], "azione") }

    Component.onCompleted: carica()
    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id === "voci:" + finestra.corrente) { finestra.voci = r; finestra.caricamento = false }
            else if (id === "imposta" || id === "azione") {
                if (r.messaggio) finestra.avviso(r.messaggio)
                else if (r.ok === false) finestra.avviso(I18n.t("Operazione non riuscita"))
                if (r.ricarica !== false) finestra.carica()
            } else if (id === "cerca") finestra.risultati = r
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Barra laterale ───────────────────────────────────────────────
        Rectangle {
            Layout.preferredWidth: 290
            Layout.fillHeight: true
            color: Tema.superficie
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                CampoRicerca {
                    id: ricercaGlobale
                    Layout.fillWidth: true
                    placeholderText: I18n.t("Cerca un'impostazione…")
                    onTextChanged: ponte.avvia("cerca", [text], "cerca")
                }
                ListView {
                    id: elencoPannelli
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: ricercaGlobale.text ? finestra.risultati : finestra.pannelli
                    delegate: Column {
                        width: ListView.view.width
                        property bool nuovoGruppo: !ricercaGlobale.text && (index === 0 || ListView.view.model[index - 1].gruppo !== modelData.gruppo)
                        Testo {
                            visible: parent.nuovoGruppo
                            text: modelData.gruppo || ""
                            secondario: true
                            font.pointSize: Tema.fontDimensione - 1
                            topPadding: 12
                            leftPadding: 8
                            bottomPadding: 4
                        }
                        VoceElenco {
                            width: parent.width
                            icona: modelData.icona
                            titolo: modelData.titolo
                            sottotitolo: ricercaGlobale.text ? modelData.percorso : ""
                            selezionata: !ricercaGlobale.text && modelData.id === finestra.corrente
                            onClicked: {
                                if (ricercaGlobale.text) { finestra.apri(modelData.pannello, modelData.voce); ricercaGlobale.text = "" }
                                else finestra.apri(modelData.id, "")
                            }
                        }
                    }
                    Testo {
                        anchors.centerIn: parent
                        visible: ricercaGlobale.text && finestra.risultati.length === 0
                        text: I18n.t("Nessun risultato")
                        secondario: true
                    }
                }
            }
        }

        // ── Contenuto del pannello ───────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            Barra {
                Layout.fillWidth: true
                titolo: finestra.titoloCorrente
                CampoRicerca {
                    id: campoFiltro
                    width: 240
                    placeholderText: I18n.t("Cerca in questo pannello…")
                }
            }
            BarraProgresso { Layout.fillWidth: true; indeterminate: true; visible: finestra.caricamento }
            ScrollView {
                id: scorrimento
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                ColumnLayout {
                    width: scorrimento.availableWidth
                    spacing: 6
                    Item { height: 12 }
                    Repeater {
                        model: finestra.voci
                        Voce {
                            Layout.fillWidth: true
                            Layout.leftMargin: 24
                            Layout.rightMargin: 24
                            voce: modelData
                            filtro: campoFiltro.text
                            evidenziata: finestra.evidenzia !== "" && modelData.id === finestra.evidenzia
                            onCambia: function (valore) { finestra.imposta(modelData.id, valore) }
                            onEsegui: function (elemento, azione, dati) { finestra.esegui(modelData.id, elemento, azione, dati) }
                            onChiediDati: function (elemento, azione, campi) { dialogo.chiedi(modelData.id, elemento, azione, campi) }
                            onChiediFile: function (elemento, azione) { sceltaFile.voce = modelData.id; sceltaFile.elemento = elemento; sceltaFile.azione = azione; sceltaFile.open() }
                        }
                    }
                    Item { height: 24 }
                }
            }
        }
    }

    // Dialogo per i dati richiesti da un'azione (password, nomi…)
    Dialog {
        id: dialogo
        property string voce: ""
        property string elemento: ""
        property string azione: ""
        property var campi: []
        property var valori: ({})
        function chiedi(v, e, a, c) { voce = v; elemento = e; azione = a; campi = c; valori = {}; open() }
        title: I18n.t("Inserisci i dati")
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Cancel | Dialog.Ok
        ColumnLayout {
            spacing: 10
            Repeater {
                model: dialogo.campi
                ColumnLayout {
                    Testo { text: modelData.etichetta }
                    CampoTesto {
                        Layout.preferredWidth: 320
                        echoMode: modelData.segreto ? TextInput.Password : TextInput.Normal
                        onTextChanged: dialogo.valori[modelData.id] = text
                    }
                }
            }
        }
        onAccepted: finestra.esegui(voce, elemento, azione, valori)
    }
    FileDialog {
        id: sceltaFile
        property string voce: ""
        property string elemento: ""
        property string azione: ""
        onAccepted: finestra.esegui(voce, elemento, azione, { file: selectedFile.toString().replace("file://", "") })
    }
}
