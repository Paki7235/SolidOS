// Impostazioni: barra laterale con i pannelli (icone su quadratini colorati),
// a destra le voci raggruppate in schede; ricerca globale e nel pannello.
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Impostazioni")
    width: 1020
    height: 680
    minimumWidth: 760
    property var pannelli: ponte.chiama0("pannelli")
    property var utente: ponte.chiama0("utente")
    property string corrente: ponte.chiama0("iniziale")
    property var storia: []
    property int posizione: -1
    property string titoloCorrente: {
        for (var i = 0; i < pannelli.length; i++) if (pannelli[i].id === corrente) return pannelli[i].titolo
        return ""
    }
    property var voci: []
    property bool caricamento: false
    property string evidenzia: ""
    property var risultati: []

    // Le voci divise in sezioni: ogni «intestazione» apre un nuovo gruppo;
    // un «elenco» sta in un gruppo tutto suo con il titolo sopra.
    readonly property var sezioni: {
        var out = [], cur = null
        for (var i = 0; i < voci.length; i++) {
            var v = voci[i]
            if (v.tipo === "intestazione") { cur = { titolo: v.titolo, voci: [] }; out.push(cur) }
            else if (v.tipo === "elenco") { out.push({ titolo: v.titolo, voci: [v], elenco: true }); cur = null }
            else { if (!cur) { cur = { titolo: "", voci: [] }; out.push(cur) } cur.voci.push(v) }
        }
        return out.filter(function (s) { return s.voci.length > 0 })
    }

    function corrisponde(v, f) {
        if (!f) return true
        var t = ((v.titolo || "") + " " + (v.descrizione || "") + " " + (v.chiavi || "")).toLowerCase()
        return t.indexOf(f.toLowerCase()) >= 0
    }
    function quanteVisibili(elenco, f) {
        var n = 0
        for (var i = 0; i < elenco.length; i++) if (corrisponde(elenco[i], f)) n++
        return n
    }
    function iconaPannello(id) { return "file:///usr/share/nucleo/icone-pannelli/pannello-" + id + ".svg" }
    function carica() {
        caricamento = true
        ponte.avvia("voci", [corrente], "voci:" + corrente)
    }
    function vai(id, voce, daStoria) {
        corrente = id; evidenzia = voce || ""; campoFiltro.text = ""
        if (!daStoria) { storia = storia.slice(0, posizione + 1).concat([id]); posizione = storia.length - 1 }
        carica()
    }
    function apri(id, voce) { vai(id, voce, false) }
    function imposta(voce, valore) { ponte.avvia("imposta", [corrente, voce, valore], "imposta") }
    function esegui(voce, elemento, azione, dati) { ponte.avvia("azione", [corrente, voce, elemento, azione, dati || {}], "azione") }

    Component.onCompleted: { storia = [corrente]; posizione = 0; carica() }
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
            Layout.preferredWidth: 248
            Layout.fillHeight: true
            color: Tema.chiaro ? "#E9E9EE" : "#232428"
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Tema.chiaro ? "#1A000000" : "#66000000" }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                anchors.topMargin: 12
                spacing: 8
                CampoRicerca {
                    id: ricercaGlobale
                    Layout.fillWidth: true
                    placeholderText: I18n.t("Cerca")
                    onTextChanged: ponte.avvia("cerca", [text], "cerca")
                }
                // Utente
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Layout.leftMargin: 6
                    Layout.bottomMargin: 6
                    visible: !ricercaGlobale.text
                    spacing: 10
                    Rectangle {
                        width: 36; height: 36; radius: 18
                        gradient: Gradient { GradientStop { position: 0; color: "#A1A1AA" } GradientStop { position: 1; color: "#6E6E76" } }
                        Text { anchors.centerIn: parent; text: (finestra.utente.nome || "?").charAt(0).toUpperCase(); color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.DemiBold }
                    }
                    ColumnLayout {
                        spacing: 0
                        Text { text: finestra.utente.nome || ""; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                        Text { text: I18n.t("Account e utenti"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: finestra.apri("utenti", "") }
                }
                ListView {
                    id: elencoPannelli
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 1
                    model: ricercaGlobale.text ? finestra.risultati : finestra.pannelli
                    delegate: Column {
                        width: ListView.view.width
                        property bool nuovoGruppo: !ricercaGlobale.text && index > 0 && ListView.view.model[index - 1].gruppo !== modelData.gruppo
                        Item { width: 1; height: parent.nuovoGruppo ? 12 : 0 }
                        VoceElenco {
                            width: parent.width
                            immagine: finestra.iconaPannello(ricercaGlobale.text ? modelData.pannello : modelData.id)
                            titolo: modelData.titolo
                            sottotitolo: ricercaGlobale.text ? modelData.percorso : ""
                            selezionata: !ricercaGlobale.text && modelData.id === finestra.corrente
                            onClicked: {
                                if (ricercaGlobale.text) { finestra.apri(modelData.pannello, modelData.voce); ricercaGlobale.text = "" }
                                else finestra.apri(modelData.id, "")
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: ricercaGlobale.text !== "" && finestra.risultati.length === 0
                        text: I18n.t("Nessun risultato")
                        color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13
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
                frecce: true
                puoIndietro: finestra.posizione > 0
                puoAvanti: finestra.posizione < finestra.storia.length - 1
                onIndietro: { finestra.posizione--; finestra.vai(finestra.storia[finestra.posizione], "", true) }
                onAvanti: { finestra.posizione++; finestra.vai(finestra.storia[finestra.posizione], "", true) }
                CampoRicerca {
                    id: campoFiltro
                    width: 200
                    placeholderText: I18n.t("Cerca nel pannello")
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 2
                color: "transparent"
                BarraProgresso { anchors.fill: parent; indeterminate: true; visible: finestra.caricamento }
            }
            ScrollView {
                id: scorrimento
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                ColumnLayout {
                    x: Math.max(24, (scorrimento.availableWidth - width) / 2)
                    width: Math.min(scorrimento.availableWidth - 48, 680)
                    spacing: 0
                    Item { Layout.preferredHeight: 18 }
                    Repeater {
                        model: finestra.sezioni
                        ColumnLayout {
                            id: sezione
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.bottomMargin: 20
                            spacing: 7
                            visible: gruppo.visibili > 0 || (!campoFiltro.text && sezione.modelData.elenco)
                            Text {
                                visible: !!sezione.modelData.titolo
                                text: sezione.modelData.titolo || ""
                                color: Tema.testo
                                font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold
                                Layout.leftMargin: 4
                            }
                            Scheda {
                                id: gruppo
                                property int visibili: finestra.quanteVisibili(sezione.modelData.voci, campoFiltro.text)
                                Layout.fillWidth: true
                                margine: 0
                                implicitHeight: colonna.implicitHeight
                                Column {
                                    id: colonna
                                    width: parent.width
                                    Repeater {
                                        id: righe
                                        model: sezione.modelData.voci
                                        Voce {
                                            required property var modelData
                                            required property int index
                                            width: colonna.width
                                            voce: modelData
                                            filtro: campoFiltro.text
                                            primaRiga: index === 0
                                            evidenziata: finestra.evidenzia !== "" && modelData.id === finestra.evidenzia
                                            onCambia: function (valore) { finestra.imposta(modelData.id, valore) }
                                            onEsegui: function (elemento, azione, dati) { finestra.esegui(modelData.id, elemento, azione, dati) }
                                            onChiediDati: function (elemento, azione, campi) { dialogo.chiedi(modelData.id, elemento, azione, campi) }
                                            onChiediFile: function (elemento, azione) { sceltaFile.voce = modelData.id; sceltaFile.elemento = elemento; sceltaFile.azione = azione; sceltaFile.open() }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Item { Layout.preferredHeight: 24 }
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
