// Promemoria: a sinistra i riquadri «Oggi», «Programmati», «Tutti», «Con bandiera», «Completati»
// con i numeri e sotto «Le mie liste»; a destra l'elenco con il cerchio da spuntare, la scadenza
// (rossa se passata) e la bandiera. Un clic su un promemoria apre i dettagli (note, data, ora,
// lista, bandiera). In fondo si scrive subito un promemoria nuovo.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Promemoria")
    width: 980
    height: 680
    minimumWidth: 720
    minimumHeight: 480

    property var liste: []
    property var conteggi: ({})
    property var voci: []
    property string filtro: "oggi"
    property string aperto: ""           // id del promemoria con i dettagli aperti
    property var colori: []
    readonly property var speciali: [
        { id: "oggi", nome: I18n.t("Oggi"), simbolo: "calendario", colore: "#3B82F6" },
        { id: "programmati", nome: I18n.t("Programmati"), simbolo: "orologio", colore: "#EF4444" },
        { id: "tutti", nome: I18n.t("Tutti"), simbolo: "elenco", colore: "#64748B" },
        { id: "bandiera", nome: I18n.t("Con bandiera"), simbolo: "bandiera", colore: "#F59E0B" },
        { id: "completati", nome: I18n.t("Completati"), simbolo: "spunta", colore: "#22C55E" }
    ]
    readonly property var attuale: {
        var s = speciali.find(function (x) { return x.id === filtro })
        if (s) return s
        var l = liste.find(function (x) { return x.id === filtro })
        return l ? { id: l.id, nome: l.nome, colore: l.colore, lista: true } : speciali[0]
    }
    readonly property string listaNuovi: attuale.lista ? attuale.id : (liste.length ? liste[0].id : "promemoria")

    function due(n) { return (n < 10 ? "0" : "") + n }
    function ricarica() {
        liste = ponte.chiama0("liste")
        conteggi = ponte.chiama0("conteggi")
        voci = ponte.chiama("promemoria", [filtro])
    }
    function aggiungi(testo) {
        if (!testo.trim()) return
        var p = { titolo: testo, lista: listaNuovi }
        var d = new Date()
        if (filtro === "oggi" || filtro === "programmati") p.scadenza = d.getFullYear() + "-" + due(d.getMonth() + 1) + "-" + due(d.getDate())
        if (filtro === "bandiera") p.bandiera = true
        ponte.chiama("salva", [p])
        ricarica()
    }
    function aggiorna(p, cambi) { ponte.chiama("salva", [Object.assign({}, p, cambi)]); ricarica() }
    onFiltroChanged: { aperto = ""; ricarica() }
    Component.onCompleted: { colori = ponte.chiama0("colori"); ricarica() }
    Timer { id: dopoFatto; interval: 4300; onTriggered: finestra.ricarica() }
    Timer { interval: 60000; repeat: true; running: true; onTriggered: finestra.ricarica() }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Barra laterale ──
        Rectangle {
            Layout.preferredWidth: 270
            Layout.fillHeight: true
            color: Tema.superficie
            Flickable {
                anchors.fill: parent; anchors.margins: 14
                contentHeight: lato.implicitHeight
                clip: true
                ColumnLayout {
                    id: lato
                    width: parent.width
                    spacing: 10
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2; columnSpacing: 8; rowSpacing: 8
                        Repeater {
                            model: finestra.speciali
                            Rectangle {
                                readonly property bool scelto: finestra.filtro === modelData.id
                                Layout.fillWidth: true
                                Layout.columnSpan: index === 4 ? 2 : 1
                                Layout.preferredHeight: 68
                                radius: 10
                                color: scelto ? modelData.colore : (sopraS.hovered ? Tema.superficieAlta : Qt.lighter(Tema.superficie, Tema.chiaro ? 0.97 : 1.25))
                                HoverHandler { id: sopraS }
                                Rectangle {
                                    x: 10; y: 10; width: 28; height: 28; radius: 14
                                    color: parent.scelto ? "white" : modelData.colore
                                    Simbolo { anchors.centerIn: parent; nome: modelData.simbolo; lato: 16; colore: parent.parent.scelto ? modelData.colore : "#FFFFFF" }
                                }
                                Text {
                                    anchors.right: parent.right; anchors.rightMargin: 12; y: 8
                                    text: finestra.conteggi[modelData.id] || 0
                                    color: parent.scelto ? "white" : Tema.testo; font.family: Tema.font; font.pixelSize: 22; font.weight: Font.Bold
                                }
                                Text {
                                    x: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                                    text: modelData.nome
                                    color: parent.scelto ? "white" : Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: finestra.filtro = modelData.id }
                            }
                        }
                    }
                    Text { Layout.topMargin: 8; text: I18n.t("Le mie liste"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                    Repeater {
                        model: finestra.liste
                        Rectangle {
                            id: rigaL
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            radius: 8
                            readonly property bool scelta: finestra.filtro === modelData.id
                            color: scelta ? Tema.superficieAlta : (sopraL.hovered ? Qt.lighter(Tema.superficie, Tema.chiaro ? 0.97 : 1.2) : "transparent")
                            HoverHandler { id: sopraL }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 10
                                spacing: 10
                                Rectangle {
                                    width: 26; height: 26; radius: 13; color: modelData.colore
                                    Simbolo { anchors.centerIn: parent; nome: "elenco"; lato: 14; colore: "#FFFFFF" }
                                }
                                Text { text: modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; Layout.fillWidth: true; elide: Text.ElideRight }
                                Simbolo {
                                    visible: sopraL.hovered && finestra.liste.length > 1
                                    nome: "cestino"; lato: 15; colore: Tema.testoSecondario
                                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: conferma.chiedi(modelData) }
                                }
                                Text { visible: !(sopraL.hovered && finestra.liste.length > 1); text: modelData.quanti; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13 }
                            }
                            MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.PointingHandCursor; onClicked: finestra.filtro = modelData.id }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        CampoTesto { id: nuovaLista; Layout.fillWidth: true; placeholderText: I18n.t("Nuova lista"); onAccepted: aggiungiLista.clicked() }
                        Pulsante {
                            id: aggiungiLista; text: I18n.t("Aggiungi"); enabled: nuovaLista.text.trim().length > 0
                            onClicked: { finestra.liste = ponte.chiama("salvaLista", [{ nome: nuovaLista.text.trim() }]); finestra.filtro = finestra.liste[finestra.liste.length - 1].id; nuovaLista.text = "" }
                        }
                    }
                }
            }
        }
        Rectangle { Layout.fillHeight: true; width: 1; color: Tema.bordo }

        // ── Elenco ──
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 28; Layout.rightMargin: 28; Layout.topMargin: 22; Layout.bottomMargin: 8
                Text { text: finestra.attuale.nome; color: finestra.attuale.colore; font.family: Tema.font; font.pixelSize: 30; font.weight: Font.Bold; Layout.fillWidth: true; elide: Text.ElideRight }
                Text {
                    visible: finestra.filtro !== "completati"
                    text: finestra.voci.filter(function (p) { return !p.fatto }).length
                    color: finestra.attuale.colore; font.family: Tema.font; font.pixelSize: 30; font.weight: Font.Bold
                }
            }
            ListView {
                id: elenco
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: finestra.voci
                ScrollBar.vertical: ScrollBar {}
                footer: Item {
                    width: elenco.width; height: 52
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 28; anchors.rightMargin: 28
                        spacing: 12
                        visible: finestra.filtro !== "completati"
                        Rectangle {
                            width: 22; height: 22; radius: 11; color: "transparent"
                            border.color: Tema.testoSecondario; border.width: 1.5; opacity: 0.6
                            Simbolo { anchors.centerIn: parent; nome: "piu"; lato: 14; colore: Tema.testoSecondario }
                        }
                        TextField {
                            id: nuovo
                            Layout.fillWidth: true
                            placeholderText: I18n.t("Nuovo promemoria")
                            color: Tema.testo; placeholderTextColor: Tema.testoSecondario
                            font.family: Tema.font; font.pixelSize: 15
                            background: Item {}
                            onAccepted: { finestra.aggiungi(text); text = "" }
                        }
                    }
                }
                delegate: Item {
                    id: riga
                    required property var modelData
                    readonly property bool apertoQui: finestra.aperto === modelData.id
                    width: elenco.width
                    height: corpo.implicitHeight + 16
                    Rectangle {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                        radius: 10
                        color: riga.apertoQui ? Tema.superficie : (sopraR.hovered ? Qt.rgba(0.5, 0.5, 0.5, 0.06) : "transparent")
                        HoverHandler { id: sopraR }
                        MouseArea { anchors.fill: parent; onClicked: finestra.aperto = riga.apertoQui ? "" : riga.modelData.id }
                    }
                    ColumnLayout {
                        id: corpo
                        x: 28; y: 8; width: parent.width - 56
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true; spacing: 12
                            // cerchio da spuntare
                            Rectangle {
                                Layout.alignment: Qt.AlignTop
                                width: 22; height: 22; radius: 11
                                color: riga.modelData.fatto ? riga.modelData.colore : "transparent"
                                border.color: riga.modelData.fatto ? riga.modelData.colore : Tema.testoSecondario; border.width: 1.5
                                Simbolo { anchors.centerIn: parent; visible: riga.modelData.fatto; nome: "spunta"; lato: 14; colore: "#FFFFFF" }
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                                    onClicked: { ponte.chiama("fatto", [riga.modelData.id, !riga.modelData.fatto]); finestra.ricarica(); dopoFatto.restart() }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                TextInput {
                                    Layout.fillWidth: true
                                    text: riga.modelData.titolo
                                    color: riga.modelData.fatto ? Tema.testoSecondario : Tema.testo
                                    font.family: Tema.font; font.pixelSize: 15; font.strikeout: riga.modelData.fatto
                                    wrapMode: TextInput.Wrap
                                    selectByMouse: true
                                    onEditingFinished: if (text.trim() && text !== riga.modelData.titolo) finestra.aggiorna(riga.modelData, { titolo: text })
                                }
                                Text {
                                    visible: !!riga.modelData.note && !riga.apertoQui
                                    Layout.fillWidth: true; elide: Text.ElideRight; maximumLineCount: 1
                                    text: riga.modelData.note; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                                }
                                RowLayout {
                                    visible: !!riga.modelData.quando || (finestra.attuale.lista !== true)
                                    spacing: 8
                                    Text {
                                        visible: !!riga.modelData.quando
                                        text: riga.modelData.quando
                                        color: riga.modelData.scaduto ? "#EF4444" : Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                                    }
                                    Text {
                                        visible: finestra.attuale.lista !== true
                                        text: (finestra.liste.find(function (l) { return l.id === riga.modelData.lista }) || { nome: "" }).nome
                                        color: riga.modelData.colore; font.family: Tema.font; font.pixelSize: 12
                                    }
                                }
                            }
                            Simbolo {
                                Layout.alignment: Qt.AlignTop
                                visible: riga.modelData.bandiera
                                nome: "bandiera-piena"; lato: 16; colore: "#F59E0B"
                            }
                        }
                        // dettagli
                        ColumnLayout {
                            visible: riga.apertoQui
                            Layout.fillWidth: true
                            Layout.leftMargin: 34
                            Layout.bottomMargin: 6
                            spacing: 8
                            TextArea {
                                Layout.fillWidth: true
                                placeholderText: I18n.t("Note")
                                text: riga.modelData.note || ""
                                wrapMode: TextEdit.Wrap
                                color: Tema.testo; font.family: Tema.font; font.pixelSize: 13
                                background: Rectangle { radius: 8; color: Tema.superficieAlta }
                                onActiveFocusChanged: if (!activeFocus && text !== (riga.modelData.note || "")) finestra.aggiorna(riga.modelData, { note: text })
                            }
                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                Simbolo { nome: "calendario"; lato: 16; colore: Tema.testoSecondario }
                                CampoTesto {
                                    id: campoData
                                    Layout.preferredWidth: 120
                                    placeholderText: "gg/mm/aaaa"
                                    readonly property string s: riga.modelData.scadenza || ""
                                    text: s ? s.slice(8, 10) + "/" + s.slice(5, 7) + "/" + s.slice(0, 4) : ""
                                    onEditingFinished: riga.salvaScadenza()
                                }
                                Simbolo { nome: "orologio"; lato: 16; colore: Tema.testoSecondario }
                                CampoTesto {
                                    id: campoOra
                                    Layout.preferredWidth: 70
                                    placeholderText: "hh:mm"
                                    text: (riga.modelData.scadenza || "").indexOf("T") > 0 ? riga.modelData.scadenza.slice(11, 16) : ""
                                    onEditingFinished: riga.salvaScadenza()
                                }
                                Pulsante { text: I18n.t("Oggi"); onClicked: { var d = new Date(); campoData.text = finestra.due(d.getDate()) + "/" + finestra.due(d.getMonth() + 1) + "/" + d.getFullYear(); riga.salvaScadenza() } }
                                Pulsante { text: I18n.t("Domani"); onClicked: { var d = new Date(); d.setDate(d.getDate() + 1); campoData.text = finestra.due(d.getDate()) + "/" + finestra.due(d.getMonth() + 1) + "/" + d.getFullYear(); riga.salvaScadenza() } }
                                Pulsante { visible: !!riga.modelData.scadenza; text: I18n.t("Togli"); onClicked: { campoData.text = ""; campoOra.text = ""; riga.salvaScadenza() } }
                            }
                            Text {
                                visible: !!riga.modelData.scadenza && (riga.modelData.scadenza || "").indexOf("T") < 0
                                text: I18n.t("Con l'ora arriva anche l'avviso.")
                                color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11
                            }
                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                Simbolo { nome: "elenco"; lato: 16; colore: Tema.testoSecondario }
                                Scelta {
                                    Layout.preferredWidth: 180
                                    model: finestra.liste; textRole: "nome"; valueRole: "id"
                                    currentIndex: Math.max(0, finestra.liste.findIndex(function (l) { return l.id === riga.modelData.lista }))
                                    onActivated: finestra.aggiorna(riga.modelData, { lista: currentValue })
                                }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    width: 34; height: 30; radius: 8
                                    color: riga.modelData.bandiera ? "#F59E0B" : Tema.superficieAlta
                                    Simbolo { anchors.centerIn: parent; nome: riga.modelData.bandiera ? "bandiera-piena" : "bandiera"; lato: 16; colore: riga.modelData.bandiera ? "#FFFFFF" : Tema.testo }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: finestra.aggiorna(riga.modelData, { bandiera: !riga.modelData.bandiera }) }
                                    ToolTip.visible: sopraB.hovered; ToolTip.text: I18n.t("Bandiera")
                                    HoverHandler { id: sopraB }
                                }
                                Rectangle {
                                    width: 34; height: 30; radius: 8
                                    color: Tema.superficieAlta
                                    Simbolo { anchors.centerIn: parent; nome: "cestino"; lato: 16; colore: "#EF4444" }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ponte.chiama("elimina", [riga.modelData.id]); finestra.aperto = ""; finestra.ricarica() } }
                                    ToolTip.visible: sopraE.hovered; ToolTip.text: I18n.t("Elimina")
                                    HoverHandler { id: sopraE }
                                }
                            }
                        }
                    }
                    function salvaScadenza() {
                        var d = campoData.text.trim(), o = campoOra.text.trim(), s = ""
                        if (d) {
                            var p = d.split(/[\/.\-]/)
                            if (p.length !== 3 || !(parseInt(p[1]) >= 1 && parseInt(p[1]) <= 12 && parseInt(p[0]) >= 1 && parseInt(p[0]) <= 31)) { avviso.mostra(I18n.t("Scrivi la data come 24/11/2026")); return }
                            var a = parseInt(p[2]); if (a < 100) a += 2000
                            s = a + "-" + finestra.due(parseInt(p[1])) + "-" + finestra.due(parseInt(p[0]))
                            if (o) {
                                if (!/^\d{1,2}:\d{2}$/.test(o)) { avviso.mostra(I18n.t("Scrivi l'ora come 09:30")); return }
                                s += "T" + finestra.due(parseInt(o.split(":")[0])) + ":" + o.split(":")[1]
                            }
                        }
                        if (s !== (modelData.scadenza || "")) finestra.aggiorna(modelData, { scadenza: s })
                    }
                }
                // nessun promemoria
                Column {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -40
                    visible: elenco.count === 0
                    spacing: 10
                    Simbolo { anchors.horizontalCenter: parent.horizontalCenter; nome: "cerchio-spunta"; lato: 44; colore: Tema.testoSecondario; opacity: 0.6 }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: finestra.filtro === "completati" ? I18n.t("Nessun promemoria completato") : I18n.t("Nessun promemoria")
                        color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 15
                    }
                }
            }
        }
    }

    Dialog {
        id: conferma
        property var lista: null
        function chiedi(l) { lista = l; open() }
        anchors.centerIn: parent
        modal: true
        title: I18n.t("Eliminare la lista?")
        standardButtons: Dialog.Cancel | Dialog.Ok
        Text {
            width: 320; wrapMode: Text.WordWrap
            text: conferma.lista ? I18n.t("«{nome}» e i suoi promemoria verranno eliminati.").replace("{nome}", conferma.lista.nome) : ""
            color: Tema.testo; font.family: Tema.font; font.pixelSize: 14
        }
        onAccepted: { finestra.liste = ponte.chiama("eliminaLista", [lista.id]); if (finestra.filtro === lista.id) finestra.filtro = "oggi"; finestra.ricarica() }
    }
    Messaggio { id: avviso }
}
