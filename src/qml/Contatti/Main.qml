// Contatti, come sul telefono: a sinistra l'elenco con ricerca, «La mia scheda»
// e le lettere; a destra la scheda grande con le azioni e i dati, «Modifica» per cambiarli.
// Stessa rubrica del telefono; importa ed esporta i file vCard (.vcf).
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Contatti")
    width: 920
    height: 620
    minimumWidth: 640
    minimumHeight: 440

    property var tutti: []
    property var mia: ({})
    property string scelto: ""          // id del contatto aperto («io» = la mia scheda)
    property bool modifica: false
    property var bozza: ({})
    property string filtro: ""

    readonly property var campi: [
        { id: "nome", etichetta: I18n.t("Nome e cognome") }, { id: "azienda", etichetta: I18n.t("Azienda") },
        { id: "numero", etichetta: I18n.t("Cellulare") }, { id: "numero2", etichetta: I18n.t("Casa") },
        { id: "numero3", etichetta: I18n.t("Lavoro") }, { id: "email", etichetta: I18n.t("Email") },
        { id: "email2", etichetta: I18n.t("Email di lavoro") }, { id: "indirizzo", etichetta: I18n.t("Indirizzo") },
        { id: "compleanno", etichetta: I18n.t("Compleanno") }, { id: "sito", etichetta: I18n.t("Sito") },
        { id: "social", etichetta: I18n.t("Social") }, { id: "note", etichetta: I18n.t("Note") }
    ]
    readonly property var visibili: {
        var f = filtro.toLowerCase()
        return tutti.filter(function (c) {
            return !f || (c.nome + " " + (c.azienda || "") + " " + (c.numero || "") + " " + (c.email || "")).toLowerCase().indexOf(f) >= 0
        }).map(function (c) {
            var l = (c.nome || "?").charAt(0).toUpperCase()
            return Object.assign({ lettera: /[A-ZÀ-Ý]/.test(l) ? l : "#" }, c)
        })
    }
    readonly property var aperto: {
        if (scelto === "io") return mia
        for (var i = 0; i < tutti.length; i++) if (tutti[i].id === scelto) return tutti[i]
        return null
    }

    function ricarica() {
        tutti = ponte.chiama0("contatti")
        mia = ponte.chiama0("miaScheda")
        if (scelto && scelto !== "io" && !aperto) scelto = ""
    }
    function iniziali(nome) {
        var p = (nome || "?").trim().split(/\s+/)
        return (p[0].charAt(0) + (p.length > 1 ? p[p.length - 1].charAt(0) : "")).toUpperCase()
    }
    function tinta(nome) {   // colore fisso per persona
        var colori = ["#6E8BFF", "#F2994A", "#27AE60", "#EB5757", "#9B51E0", "#2D9CDB", "#E5A50A", "#D96BA0"]
        var h = 0
        for (var i = 0; i < (nome || "").length; i++) h = (h * 31 + nome.charCodeAt(i)) % 997
        return colori[h % colori.length]
    }
    function nuovo() {
        scelto = "nuovo"
        bozza = ({ id: "" })
        modifica = true
    }
    function inizia() { bozza = Object.assign({}, aperto); modifica = true }
    function salva() {
        var r = ponte.chiama("salva", [bozza])
        avviso.mostra(r.messaggio)
        if (!r.ok) return
        modifica = false
        ricarica()
        scelto = r.id
    }
    Component.onCompleted: ricarica()

    FileDialog {
        id: sceltaVcf
        nameFilters: [I18n.t("Contatti") + " (*.vcf)"]
        onAccepted: { var r = ponte.chiama("importa", [selectedFile.toString()]); avviso.mostra(r.messaggio); finestra.ricarica() }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Elenco ──
        Rectangle {
            Layout.preferredWidth: 280
            Layout.fillHeight: true
            color: Tema.superficie
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                CampoRicerca {
                    Layout.fillWidth: true
                    placeholderText: I18n.t("Cerca nei contatti")
                    onTextChanged: finestra.filtro = text
                }
                // La mia scheda
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    radius: 10
                    color: finestra.scelto === "io" ? Tema.accento : (sopraMia.hovered ? Tema.superficieAlta : "transparent")
                    HoverHandler { id: sopraMia }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                        spacing: 10
                        Rectangle {
                            width: 36; height: 36; radius: 18; color: finestra.tinta(finestra.mia.nome)
                            Text { anchors.centerIn: parent; text: finestra.iniziali(finestra.mia.nome); color: "white"; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                        }
                        ColumnLayout {
                            spacing: 0; Layout.fillWidth: true
                            Text { text: finestra.mia.nome || I18n.t("La mia scheda"); color: finestra.scelto === "io" ? "white" : Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { text: I18n.t("La mia scheda"); color: finestra.scelto === "io" ? "#E6FFFFFF" : Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
                        }
                    }
                    MouseArea { anchors.fill: parent; onClicked: { finestra.modifica = false; finestra.scelto = "io" } }
                }
                ListView {
                    id: elenco
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: finestra.visibili
                    section.property: "lettera"
                    section.delegate: Text {
                        width: ListView.view.width
                        text: section
                        leftPadding: 8; topPadding: 10; bottomPadding: 2
                        color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.Bold
                    }
                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 40
                        radius: 8
                        readonly property bool attivo: modelData.id === finestra.scelto
                        color: attivo ? Tema.accento : (sopra.hovered ? Tema.superficieAlta : "transparent")
                        HoverHandler { id: sopra }
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                            spacing: 10
                            Rectangle {
                                width: 28; height: 28; radius: 14; color: finestra.tinta(modelData.nome)
                                Text { anchors.centerIn: parent; text: finestra.iniziali(modelData.nome); color: "white"; font.family: Tema.font; font.pixelSize: 11; font.weight: Font.DemiBold }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.nome
                                elide: Text.ElideRight
                                color: parent.parent.attivo ? "white" : Tema.testo
                                font.family: Tema.font; font.pixelSize: 14
                            }
                            Text { visible: modelData.preferito === true; text: "★"; color: parent.parent.attivo ? "white" : "#F5B301"; font.pixelSize: 13 }
                        }
                        MouseArea { anchors.fill: parent; onClicked: { finestra.modifica = false; finestra.scelto = modelData.id } }
                    }
                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 20
                        visible: finestra.visibili.length === 0
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: finestra.filtro ? I18n.t("Nessun contatto trovato") : I18n.t("Nessun contatto.\nAggiungine uno con + o importa un file .vcf dal telefono, da Gmail o da Outlook.")
                        color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Pulsante { text: "+"; principale: true; onClicked: finestra.nuovo() }
                    Item { Layout.fillWidth: true }
                    Pulsante { text: I18n.t("Importa…"); onClicked: sceltaVcf.open() }
                    Pulsante { text: I18n.t("Esporta"); onClicked: avviso.mostra(ponte.chiama0("esporta").messaggio) }
                }
            }
        }
        Rectangle { Layout.fillHeight: true; width: 1; color: Tema.bordo }

        // ── Scheda ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Text {
                anchors.centerIn: parent
                visible: !finestra.aperto && !finestra.modifica
                text: I18n.t("Scegli un contatto")
                color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 16
            }

            Flickable {
                anchors.fill: parent
                visible: !!finestra.aperto || finestra.modifica
                contentHeight: scheda.implicitHeight + 60
                clip: true
                ScrollBar.vertical: ScrollBar {}

                ColumnLayout {
                    id: scheda
                    x: Math.max(24, (parent.width - width) / 2)
                    y: 28
                    width: Math.min(560, finestra.width - 280 - 48)
                    spacing: 14

                    // Intestazione: foto/iniziali grandi, nome, azienda
                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 96; height: 96; radius: 48
                            readonly property string nomeVisto: finestra.modifica ? (finestra.bozza.nome || "") : (finestra.aperto ? finestra.aperto.nome : "")
                            color: finestra.tinta(nomeVisto)
                            Text { anchors.centerIn: parent; text: finestra.iniziali(parent.nomeVisto); color: "white"; font.family: Tema.font; font.pixelSize: 36; font.weight: Font.DemiBold }
                        }
                        Text {
                            visible: !finestra.modifica
                            Layout.alignment: Qt.AlignHCenter
                            text: finestra.aperto ? finestra.aperto.nome : ""
                            color: Tema.testo; font.family: Tema.font; font.pixelSize: 26; font.weight: Font.Bold
                        }
                        Text {
                            visible: !finestra.modifica && finestra.aperto && !!finestra.aperto.azienda
                            Layout.alignment: Qt.AlignHCenter
                            text: finestra.aperto ? (finestra.aperto.azienda || "") : ""
                            color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 14
                        }
                    }

                    // Azioni rapide (pulsanti tondi)
                    Row {
                        visible: !finestra.modifica && !!finestra.aperto
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 14
                        Repeater {
                            model: [
                                { t: I18n.t("email"), s: "✉", tipo: "email" },
                                { t: I18n.t("chiama"), s: "☎", tipo: "numero" },
                                { t: I18n.t("sito"), s: "🌐", tipo: "sito" },
                                { t: I18n.t("mappa"), s: "⌖", tipo: "indirizzo" }
                            ]
                            Column {
                                spacing: 4
                                readonly property string valore: finestra.aperto ? (finestra.aperto[modelData.tipo] || "") : ""
                                opacity: valore ? 1 : 0.35
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 44; height: 44; radius: 22
                                    color: Tema.superficieAlta
                                    Text { anchors.centerIn: parent; text: modelData.s; color: Tema.accento; font.pixelSize: 18 }
                                    MouseArea { anchors.fill: parent; enabled: !!parent.parent.valore; onClicked: ponte.chiama("apri", [modelData.tipo, parent.parent.valore]) }
                                }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.t; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
                            }
                        }
                    }

                    // Dati (lettura)
                    Rectangle {
                        visible: !finestra.modifica && !!finestra.aperto
                        Layout.fillWidth: true
                        Layout.preferredHeight: datiCol.implicitHeight + 8
                        radius: 12
                        color: Tema.superficie
                        border.color: Tema.bordo
                        Column {
                            id: datiCol
                            width: parent.width
                            y: 4
                            Repeater {
                                model: finestra.campi.filter(function (c) { return c.id !== "nome" && c.id !== "azienda" && finestra.aperto && finestra.aperto[c.id] })
                                Column {
                                    width: datiCol.width
                                    Rectangle { visible: index > 0; x: 14; width: parent.width - 28; height: 1; color: Tema.bordo }
                                    Item {
                                        width: parent.width; height: Math.max(46, valoreTesto.implicitHeight + 22)
                                        Text { x: 14; y: 7; text: modelData.etichetta; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
                                        Text {
                                            id: valoreTesto
                                            x: 14; y: 22; width: parent.width - 28
                                            text: finestra.aperto ? finestra.aperto[modelData.id] : ""
                                            wrapMode: Text.WordWrap
                                            color: ["numero", "numero2", "numero3", "email", "email2", "sito", "indirizzo"].indexOf(modelData.id) >= 0 ? Tema.accento : Tema.testo
                                            font.family: Tema.font; font.pixelSize: 14
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: valoreTesto.color === Tema.accento ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: {
                                                var tipo = modelData.id.replace(/[0-9]$/, "")
                                                if (["numero", "email", "sito", "indirizzo"].indexOf(tipo) >= 0) ponte.chiama("apri", [tipo, valoreTesto.text])
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Modifica: tutti i campi
                    Rectangle {
                        visible: finestra.modifica
                        Layout.fillWidth: true
                        Layout.preferredHeight: moduloCol.implicitHeight + 24
                        radius: 12
                        color: Tema.superficie
                        border.color: Tema.bordo
                        ColumnLayout {
                            id: moduloCol
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                            anchors.margins: 12
                            spacing: 8
                            Repeater {
                                model: finestra.campi
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    Text { Layout.preferredWidth: 120; text: modelData.etichetta; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13; horizontalAlignment: Text.AlignRight }
                                    CampoTesto {
                                        Layout.fillWidth: true
                                        text: finestra.bozza[modelData.id] || ""
                                        onTextEdited: { var b = finestra.bozza; b[modelData.id] = text; finestra.bozza = b }
                                    }
                                }
                            }
                        }
                    }

                    // Pulsanti
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Pulsante {
                            visible: !finestra.modifica && finestra.scelto !== "io" && !!finestra.aperto
                            text: finestra.aperto && finestra.aperto.preferito ? "★ " + I18n.t("Preferito") : "☆ " + I18n.t("Aggiungi ai preferiti")
                            onClicked: { ponte.chiama("preferito", [finestra.scelto, !(finestra.aperto.preferito === true)]); finestra.ricarica() }
                        }
                        Pulsante {
                            visible: finestra.modifica && finestra.scelto !== "io" && finestra.scelto !== "nuovo"
                            text: I18n.t("Elimina contatto"); pericoloso: true
                            onClicked: { ponte.chiama("elimina", [finestra.scelto]); finestra.modifica = false; finestra.scelto = ""; finestra.ricarica() }
                        }
                        Item { Layout.fillWidth: true }
                        Pulsante {
                            visible: finestra.modifica
                            text: I18n.t("Annulla")
                            onClicked: { finestra.modifica = false; if (finestra.scelto === "nuovo") finestra.scelto = "" }
                        }
                        Pulsante {
                            text: finestra.modifica ? I18n.t("Fine") : I18n.t("Modifica")
                            principale: finestra.modifica
                            visible: finestra.modifica || !!finestra.aperto
                            onClicked: finestra.modifica ? finestra.salva() : finestra.inizia()
                        }
                    }
                }
            }
        }
    }
    Messaggio { id: avviso }
}
