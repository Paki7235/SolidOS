// Note. A sinistra le cartelle, al centro l'elenco delle note
// (fissate in alto), a destra si scrive. Tutto si salva da solo.
// Ctrl+N nuova nota · Ctrl+F cerca · Ctrl+B/I/U grassetto/corsivo/sottolineato ·
// Ctrl+Maiusc+L lista di cose da fare · Ctrl+Maiusc+T titolo · Canc (nell'elenco) elimina
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Note")
    width: 1060
    height: 680
    readonly property color giallo: "#E3A800"
    property var cartelle: []
    property string cartella: ""
    property var note: []
    property string scelta: ""
    property string cerca: ""
    property bool caricando: false
    readonly property bool cestino: cartella === ":eliminate"
    readonly property var notaScelta: note.find(function (n) { return n.id === scelta }) || null

    function aggiornaCartelle() { cartelle = ponte.chiama0("cartelle") }
    function aggiornaElenco() { note = ponte.chiama("elenco", [cartella, cerca]) }
    function apri(id) {
        if (scelta && scelta !== id) salvaOra()
        scelta = id
        caricando = true
        var n = ponte.chiama("leggi", [id])
        editor.text = n.html || ""
        caricando = false
        editor.readOnly = !!n.eliminata
        if (!n.html) { editor.forceActiveFocus(); Qt.callLater(function () { ponte.chiama("formatta", [editor.textDocument, 0, 0, "titolo"]) }) }
    }
    function nuova() {
        if (cestino) cartella = ""
        cerca = ""; campoCerca.text = ""
        var id = ponte.chiama("nuova", [cartella])
        aggiornaElenco(); aggiornaCartelle()
        apri(id)
        editor.forceActiveFocus()
    }
    function salvaOra() {
        if (!scelta || caricando || editor.readOnly) return
        salvataggio.stop()
        var r = ponte.chiama("salva", [scelta, editor.text])
        if (r && r.id) note = note.map(function (n) { return n.id === r.id ? r : n })
    }
    function elimina(id) {
        ponte.chiama("elimina", [id])
        if (id === scelta) { scelta = ""; editor.text = "" }
        aggiornaElenco(); aggiornaCartelle()
        if (note.length && !scelta) apri(note[0].id)
    }
    function formatta(tipo) {
        if (editor.readOnly) return
        ponte.chiama("formatta", [editor.textDocument, editor.selectionStart, editor.selectionEnd, tipo])
        editor.forceActiveFocus()
        salvataggio.restart()
    }
    function data(t) {
        var d = new Date(t * 1000), oggi = new Date()
        if (d.toDateString() === oggi.toDateString()) return d.toLocaleTimeString(Qt.locale(), "HH:mm")
        return d.toLocaleDateString(Qt.locale(), "dd/MM/yy")
    }

    Component.onCompleted: {
        ponte.chiama0("eliminaVuote")
        aggiornaCartelle(); aggiornaElenco()
        if (note.length) apri(note[0].id)
    }
    onClosing: { salvaOra(); ponte.chiama0("eliminaVuote") }
    Timer { id: salvataggio; interval: 600; onTriggered: finestra.salvaOra() }

    Shortcut { sequence: StandardKey.New; onActivated: finestra.nuova() }
    Shortcut { sequence: StandardKey.Find; onActivated: campoCerca.forceActiveFocus() }
    Shortcut { sequence: StandardKey.Bold; onActivated: finestra.formatta("grassetto") }
    Shortcut { sequence: StandardKey.Italic; onActivated: finestra.formatta("corsivo") }
    Shortcut { sequence: StandardKey.Underline; onActivated: finestra.formatta("sottolineato") }
    Shortcut { sequence: "Ctrl+Shift+L"; onActivated: finestra.formatta("cose") }
    Shortcut { sequence: "Ctrl+Shift+T"; onActivated: finestra.formatta("titolo") }
    Shortcut { sequence: "Ctrl+Shift+H"; onActivated: finestra.formatta("intestazione") }
    Shortcut { sequence: "Ctrl+Shift+B"; onActivated: finestra.formatta("corpo") }

    // Pulsante quadrato della barra (icona)
    component Tasto: Rectangle {
        id: t
        property string icona: ""
        property string simbolo: ""           // disegno a linea di SolidOS (es. «puntina»)
        property string testo: ""
        property string suggerimento: ""
        property bool acceso: false
        signal premuto()
        width: Math.max(32, etichetta.implicitWidth + (icona || simbolo ? 30 : 16)); height: 30; radius: 7
        color: acceso ? "#33" + finestra.giallo.toString().substring(1) : (ma.pressed ? (Tema.chiaro ? "#1A000000" : "#26FFFFFF") : (ma.containsMouse ? (Tema.chiaro ? "#0F000000" : "#14FFFFFF") : "transparent"))
        Row {
            anchors.centerIn: parent
            spacing: 4
            Icona { visible: t.icona !== ""; nome: t.icona + (Tema.chiaro ? "?c" : ""); lato: 16; anchors.verticalCenter: parent.verticalCenter }
            Simbolo { visible: t.simbolo !== ""; nome: t.simbolo; lato: 16; colore: Tema.testo; anchors.verticalCenter: parent.verticalCenter }
            Text { id: etichetta; visible: t.testo !== ""; text: t.testo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.RichText }
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: t.premuto() }
        ToolTip.visible: ma.containsMouse && t.suggerimento !== ""
        ToolTip.delay: 600
        ToolTip.text: t.suggerimento
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Cartelle ───────────────────────────────────────────────────────
        Rectangle {
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            color: Tema.chiaro ? "#ECECEF" : "#202125"
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Tema.chiaro ? "#1A000000" : "#66000000" }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                anchors.topMargin: 14
                spacing: 2
                Text { text: I18n.t("Cartelle"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11; font.weight: Font.DemiBold; leftPadding: 8; bottomPadding: 4 }
                Repeater {
                    model: finestra.cartelle
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        height: 32; radius: 7
                        color: finestra.cartella === modelData.id ? (Tema.chiaro ? "#D9D9DE" : "#3A3B42") : (maC.containsMouse ? (Tema.chiaro ? "#0F000000" : "#14FFFFFF") : "transparent")
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 10
                            spacing: 8
                            Icona { nome: modelData.id === ":eliminate" ? "user-trash-symbolic" + (Tema.chiaro ? "?c" : "") : "folder-symbolic" + (Tema.chiaro ? "?c" : ""); lato: 16 }
                            Text { text: modelData.nome; Layout.fillWidth: true; elide: Text.ElideRight; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                            Text { text: modelData.quante; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                        }
                        MouseArea { id: maC; anchors.fill: parent; hoverEnabled: true; onClicked: { finestra.salvaOra(); finestra.cartella = modelData.id; finestra.scelta = ""; editor.text = ""; finestra.aggiornaElenco(); if (finestra.note.length) finestra.apri(finestra.note[0].id) } }
                        // si può trascinare una nota su una cartella
                        DropArea {
                            anchors.fill: parent
                            keys: ["nota"]
                            enabled: !modelData.speciale || modelData.id === ""
                            onDropped: function (d) { ponte.chiama("sposta", [d.source.idNota, modelData.id]); finestra.aggiornaElenco(); finestra.aggiornaCartelle() }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                Tasto {
                    icona: "folder-new-symbolic"
                    testo: I18n.t("Nuova cartella")
                    onPremuto: nuovaCartella.open()
                }
            }
        }

        // ── Elenco delle note ──────────────────────────────────────────────
        Rectangle {
            Layout.preferredWidth: 290
            Layout.fillHeight: true
            color: Tema.chiaro ? "#F7F7F9" : "#26272C"
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Tema.chiaro ? "#1A000000" : "#66000000" }
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: 10
                    CampoRicerca {
                        id: campoCerca
                        Layout.fillWidth: true
                        placeholderText: I18n.t("Cerca")
                        onTextChanged: { finestra.cerca = text; finestra.aggiornaElenco() }
                    }
                    Tasto { icona: "document-edit-symbolic"; suggerimento: I18n.t("Nuova nota") + " (Ctrl+N)"; onPremuto: finestra.nuova() }
                }
                ListView {
                    id: elencoNote
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: finestra.note
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}
                    delegate: Item {
                        id: riga
                        required property var modelData
                        required property int index
                        property string idNota: modelData.id
                        width: ListView.view.width
                        height: 66
                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: 8; anchors.rightMargin: 8
                            radius: 8
                            color: finestra.scelta === riga.modelData.id ? "#40" + finestra.giallo.toString().substring(1) : "transparent"
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 12; width: parent.width - 24
                                spacing: 3
                                Row {
                                    width: parent.width; spacing: 5
                                    Simbolo { visible: riga.modelData.fissata === true; nome: "puntina"; lato: 13; colore: finestra.giallo; anchors.verticalCenter: parent.verticalCenter }
                                    Text { width: parent.width - (riga.modelData.fissata ? 18 : 0); text: riga.modelData.titolo; elide: Text.ElideRight; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                                }
                                Row {
                                    width: parent.width
                                    spacing: 8
                                    Text { text: finestra.data(riga.modelData.modificata); color: Tema.testo; font.family: Tema.font; font.pixelSize: 12 }
                                    Text { width: parent.width - 60; text: riga.modelData.anteprima; elide: Text.ElideRight; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                                }
                            }
                        }
                        Rectangle { visible: finestra.scelta !== riga.modelData.id; anchors.bottom: parent.bottom; x: 20; width: parent.width - 40; height: 1; color: Tema.chiaro ? "#12000000" : "#14FFFFFF" }
                        MouseArea {
                            id: maN
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            drag.target: finestra.cestino ? null : trascinata
                            onClicked: function (ev) {
                                finestra.apri(riga.modelData.id)
                                if (ev.button === Qt.RightButton) { menuNota.idNota = riga.modelData.id; menuNota.fissata = riga.modelData.fissata; menuNota.popup() }
                            }
                            onReleased: { if (trascinata.Drag.active) trascinata.Drag.drop(); trascinata.x = 0; trascinata.y = 0 }
                        }
                        // etichetta che segue il mouse quando si trascina la nota su una cartella
                        Rectangle {
                            id: trascinata
                            property string idNota: riga.modelData.id
                            visible: Drag.active
                            width: 180; height: 30; radius: 7
                            color: finestra.giallo
                            Drag.active: maN.drag.active
                            Drag.keys: ["nota"]
                            Drag.source: trascinata
                            Text { anchors.centerIn: parent; width: parent.width - 16; elide: Text.ElideRight; text: riga.modelData.titolo; color: "#1D1D1F"; font.family: Tema.font; font.pixelSize: 12 }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: parent.count === 0
                        text: finestra.cerca ? I18n.t("Nessun risultato") : (finestra.cestino ? I18n.t("Nessuna nota eliminata") : I18n.t("Nessuna nota"))
                        color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13
                    }
                }
                Text {
                    Layout.fillWidth: true
                    Layout.margins: 10
                    horizontalAlignment: Text.AlignHCenter
                    text: finestra.note.length + " " + (finestra.note.length === 1 ? I18n.t("nota") : I18n.t("note"))
                    color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11
                }
            }
        }

        // ── Editor ─────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            // Barra degli strumenti: Aa (stili), formattazione, liste, fissa, elimina
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 46
                color: Tema.sfondo
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 14
                    spacing: 4
                    enabled: finestra.scelta !== "" && !finestra.cestino
                    opacity: enabled ? 1 : 0.4
                    Tasto { id: tastoStili; testo: "<b>Aa</b>"; suggerimento: I18n.t("Stili del testo"); onPremuto: menuStili.popup(tastoStili, 0, tastoStili.height + 4) }
                    Tasto { testo: "<b>G</b>"; suggerimento: I18n.t("Grassetto") + " (Ctrl+B)"; onPremuto: finestra.formatta("grassetto") }
                    Tasto { testo: "<i>C</i>"; suggerimento: I18n.t("Corsivo") + " (Ctrl+I)"; onPremuto: finestra.formatta("corsivo") }
                    Tasto { testo: "<u>S</u>"; suggerimento: I18n.t("Sottolineato") + " (Ctrl+U)"; onPremuto: finestra.formatta("sottolineato") }
                    Tasto { testo: "<s>B</s>"; suggerimento: I18n.t("Barrato"); onPremuto: finestra.formatta("barrato") }
                    Rectangle { width: 1; height: 20; anchors.verticalCenter: parent.verticalCenter; color: Tema.chiaro ? "#1A000000" : "#1FFFFFFF" }
                    Tasto { simbolo: "spunta"; suggerimento: I18n.t("Lista di cose da fare") + " (Ctrl+Maiusc+L)"; onPremuto: finestra.formatta("cose") }
                    Tasto { icona: "view-list-bullet-symbolic"; testo: ""; suggerimento: I18n.t("Elenco puntato"); onPremuto: finestra.formatta("puntato") }
                    Tasto { icona: "view-list-ordered-symbolic"; testo: ""; suggerimento: I18n.t("Elenco numerato"); onPremuto: finestra.formatta("numerato") }
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right; anchors.rightMargin: 14
                    spacing: 4
                    Tasto {
                        visible: finestra.cestino && finestra.scelta !== ""
                        testo: I18n.t("Ripristina")
                        onPremuto: { ponte.chiama("ripristina", [finestra.scelta]); finestra.scelta = ""; editor.text = ""; finestra.aggiornaElenco(); finestra.aggiornaCartelle() }
                    }
                    Tasto {
                        visible: !finestra.cestino && finestra.scelta !== ""
                        simbolo: "puntina"; acceso: !!(finestra.notaScelta && finestra.notaScelta.fissata)
                        suggerimento: I18n.t("Fissa in alto")
                        onPremuto: { ponte.chiama("fissa", [finestra.scelta, !(finestra.notaScelta && finestra.notaScelta.fissata)]); finestra.aggiornaElenco() }
                    }
                    Tasto {
                        visible: finestra.scelta !== ""
                        icona: "user-trash-symbolic"
                        suggerimento: finestra.cestino ? I18n.t("Elimina per sempre") : I18n.t("Elimina")
                        onPremuto: finestra.elimina(finestra.scelta)
                    }
                }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: !!finestra.notaScelta
                text: finestra.notaScelta ? new Date(finestra.notaScelta.modificata * 1000).toLocaleString(Qt.locale(), "d MMMM yyyy 'alle' HH:mm") : ""
                color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11
                bottomPadding: 6
            }
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: finestra.scelta !== ""
                contentWidth: availableWidth
                TextArea {
                    id: editor
                    textFormat: TextEdit.RichText
                    wrapMode: TextEdit.Wrap
                    leftPadding: 36; rightPadding: 36; topPadding: 8; bottomPadding: 40
                    font.family: Tema.font
                    font.pixelSize: 15
                    color: Tema.testo
                    selectionColor: "#66" + finestra.giallo.toString().substring(1)
                    selectedTextColor: Tema.testo
                    placeholderText: I18n.t("Scrivi qui…")
                    background: null
                    persistentSelection: true
                    onTextChanged: if (!finestra.caricando) salvataggio.restart()
                    // clic su ☐ / ☑: segna la cosa come fatta
                    TapHandler {
                        onTapped: function (ev) {
                            var pos = editor.positionAt(ev.position.x, ev.position.y)
                            if (!editor.readOnly && ponte.chiama("spunta", [editor.textDocument, pos])) salvataggio.restart()
                        }
                    }
                }
            }
            Column {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: finestra.scelta === ""
                Item { width: 1; height: 160 }
                Simbolo { anchors.horizontalCenter: parent.horizontalCenter; nome: "note"; lato: 48; colore: Tema.testoSecondario }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Scegli una nota o creane una nuova"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 14; topPadding: 8 }
                Item { width: 1; height: 12 }
                Pulsante { anchors.horizontalCenter: parent.horizontalCenter; principale: true; text: I18n.t("Nuova nota"); onClicked: finestra.nuova() }
            }
        }
    }

    Menu {
        id: menuStili
        MenuItem { text: I18n.t("Titolo"); font.pixelSize: 18; font.bold: true; onTriggered: finestra.formatta("titolo") }
        MenuItem { text: I18n.t("Intestazione"); font.pixelSize: 15; font.bold: true; onTriggered: finestra.formatta("intestazione") }
        MenuItem { text: I18n.t("Corpo"); onTriggered: finestra.formatta("corpo") }
        MenuSeparator {}
        MenuItem { text: "•  " + I18n.t("Elenco puntato"); onTriggered: finestra.formatta("puntato") }
        MenuItem { text: "1.  " + I18n.t("Elenco numerato"); onTriggered: finestra.formatta("numerato") }
        MenuItem { text: "☑  " + I18n.t("Lista di cose da fare"); onTriggered: finestra.formatta("cose") }
    }
    Menu {
        id: menuNota
        property string idNota: ""
        property bool fissata: false
        MenuItem { text: menuNota.fissata ? I18n.t("Togli dalle fissate") : I18n.t("Fissa in alto"); visible: !finestra.cestino; onTriggered: { ponte.chiama("fissa", [menuNota.idNota, !menuNota.fissata]); finestra.aggiornaElenco() } }
        MenuItem { text: I18n.t("Ripristina"); visible: finestra.cestino; onTriggered: { ponte.chiama("ripristina", [menuNota.idNota]); finestra.aggiornaElenco(); finestra.aggiornaCartelle() } }
        MenuItem { text: finestra.cestino ? I18n.t("Elimina per sempre") : I18n.t("Elimina"); onTriggered: finestra.elimina(menuNota.idNota) }
    }
    Dialog {
        id: nuovaCartella
        anchors.centerIn: parent
        modal: true
        title: I18n.t("Nuova cartella")
        standardButtons: Dialog.Cancel | Dialog.Ok
        onOpened: { campoCartella.text = ""; campoCartella.forceActiveFocus() }
        onAccepted: { if (ponte.chiama("nuovaCartella", [campoCartella.text])) { finestra.aggiornaCartelle(); finestra.cartella = campoCartella.text.trim(); finestra.aggiornaElenco() } }
        CampoTesto { id: campoCartella; width: 260; placeholderText: I18n.t("Nome della cartella"); onAccepted: nuovaCartella.accept() }
    }
}
