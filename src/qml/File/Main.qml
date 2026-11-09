// File: gestore dei file di SolidOS.
// Doppio clic apre · tasto destro menu · Ctrl+C/X/V copia/taglia/incolla · Canc cestino
// F2 rinomina · Ctrl+A tutto · Ctrl+H file nascosti · Alt+← → cronologia · Ctrl+L indirizzo
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    width: 1040
    height: 660
    title: dati.titolo ? dati.titolo + " — " + I18n.t("File") : I18n.t("File")

    property string uri: ""
    property var dati: ({ voci: [], briciole: [] })
    property var luoghi: []
    property var scelti: ({})
    property int ultimoScelto: -1
    property var storia: []
    property int posizione: -1
    property bool griglia: true
    property bool nascosti: false
    property string inRinomina: ""
    property string ricerca: ""
    property var risultati: null
    property bool caricamento: false
    readonly property var voci: risultati !== null ? risultati : dati.voci
    readonly property var elencoScelti: voci.filter(function (v) { return scelti[v.uri] })

    function vai(u, daStoria) {
        if (!u) return
        caricamento = true; risultati = null; ricerca = ""; campoCerca.text = ""
        ponte.avvia("elenco", [u, nascosti], "elenco:" + u)
        if (!daStoria) { storia = storia.slice(0, posizione + 1).concat([u]); posizione = storia.length - 1 }
        uri = u; scelti = ({}); ultimoScelto = -1; inRinomina = ""
    }
    function ricarica() { ponte.avvia("elenco", [uri, nascosti], "elenco:" + uri); luoghi = ponte.chiama0("luoghi") }
    function apriVoce(v) {
        if (v.cartella) vai(v.uri, false)
        else ponte.chiama("apri", [v.uri])
    }
    function seleziona(indice, modificatori) {
        var v = voci[indice], nuovi = {}
        if (modificatori & Qt.ControlModifier) { nuovi = Object.assign({}, scelti); if (nuovi[v.uri]) delete nuovi[v.uri]; else nuovi[v.uri] = true }
        else if ((modificatori & Qt.ShiftModifier) && ultimoScelto >= 0) {
            for (var i = Math.min(indice, ultimoScelto); i <= Math.max(indice, ultimoScelto); i++) nuovi[voci[i].uri] = true
        } else nuovi[v.uri] = true
        scelti = nuovi; ultimoScelto = indice
    }
    function uriScelti() { return elencoScelti.map(function (v) { return v.uri }) }
    function esito(r, ok) { if (r && r.ok === false && r.errore) finestra.avviso(r.errore); else if (ok) finestra.avviso(ok); ricarica() }
    function incolla() { if (ponte.chiama0("appuntiPieni")) { caricamento = true; ponte.avvia("incolla", [uri], "operazione") } }
    function cestina() {
        var u = uriScelti(); if (!u.length) return
        if (dati.cestino) eliminaDialogo.apri(u)
        else esito(ponte.chiama("cestino", [u]), u.length === 1 ? I18n.t("Spostato nel cestino") : u.length + " " + I18n.t("elementi spostati nel cestino"))
    }
    function menuVoce(v, x, y) {
        if (!scelti[v.uri]) { var n = {}; n[v.uri] = true; scelti = n }
        var u = uriScelti(), multi = u.length > 1
        var voci = []
        if (dati.cestino) {
            voci = [{ t: I18n.t("Ripristina"), f: function () { finestra.esito(ponte.chiama("ripristina", [u]), I18n.t("Ripristinato")) } },
                    { t: I18n.t("Elimina definitivamente"), f: function () { eliminaDialogo.apri(u) } }]
        } else {
            voci.push({ t: v.cartella ? I18n.t("Apri") : I18n.t("Apri"), f: function () { finestra.apriVoce(v) } })
            if (!v.cartella && !multi) voci.push({ t: I18n.t("Apri con…"), f: function () { apriCon.apri(v) } })
            if (v.cartella && !multi) voci.push({ t: I18n.t("Apri nel terminale"), f: function () { ponte.chiama("terminaleQui", [v.uri]) } })
            voci.push({ sep: true })
            voci.push({ t: I18n.t("Taglia") + "    Ctrl+X", f: function () { ponte.chiama("copia", [u, true]) } })
            voci.push({ t: I18n.t("Copia") + "    Ctrl+C", f: function () { ponte.chiama("copia", [u, false]) } })
            if (!multi) voci.push({ t: I18n.t("Rinomina") + "    F2", f: function () { finestra.inRinomina = v.uri } })
            voci.push({ sep: true })
            if (/\.(zip|tar|gz|tgz|bz2|xz|7z|rar)$/i.test(v.uri)) voci.push({ t: I18n.t("Estrai qui"), f: function () { ponte.chiama("estrai", [u]); finestra.avviso(I18n.t("Estrazione avviata")) } })
            else voci.push({ t: I18n.t("Comprimi (zip)"), f: function () { ponte.chiama("comprimi", [u]); finestra.avviso(I18n.t("Compressione avviata")) } })
            if (!v.cartella) voci.push({ t: I18n.t("Converti in PDF"), f: function () { ponte.chiama("convertiPdf", [u]); finestra.avviso(I18n.t("Conversione avviata: il PDF sarà in questa cartella")) } })
            voci.push({ t: I18n.t("Condividi…"), f: function () { ponte.chiama("condividi", [u]) } })
            if (v.cartella && !multi) voci.push({ t: I18n.t("Aggiungi ai Preferiti"), f: function () { ponte.chiama("aggiungiSegnalibro", [v.uri]); finestra.luoghi = ponte.chiama0("luoghi") } })
            voci.push({ sep: true })
            voci.push({ t: I18n.t("Sposta nel cestino") + "    Canc", f: function () { finestra.cestina() } })
            voci.push({ sep: true })
            voci.push({ t: I18n.t("Proprietà"), f: function () { proprieta.apri(v.uri) } })
        }
        menu.mostra(voci, x, y)
    }
    function menuSfondo(x, y) {
        scelti = ({})
        var voci = dati.cestino ? [{ t: I18n.t("Svuota il cestino"), f: function () { svuota.open() } }] : [
            { t: I18n.t("Nuova cartella"), f: function () { var r = ponte.chiama("nuovaCartella", [finestra.uri]); finestra.esito(r); if (r.ok) finestra.inRinomina = r.uri } },
            { t: I18n.t("Incolla") + "    Ctrl+V", f: function () { finestra.incolla() } },
            { sep: true },
            { t: I18n.t("Apri nel terminale"), f: function () { ponte.chiama("terminaleQui", [finestra.uri]) } },
            { t: finestra.nascosti ? I18n.t("Nascondi file nascosti") : I18n.t("Mostra file nascosti"), f: function () { finestra.nascosti = !finestra.nascosti; finestra.ricarica() } },
            { sep: true },
            { t: I18n.t("Proprietà della cartella"), f: function () { proprieta.apri(finestra.uri) } }]
        menu.mostra(voci, x, y)
    }

    Component.onCompleted: { luoghi = ponte.chiama0("luoghi"); vai(ponte.chiama0("iniziale"), false) }
    onActiveChanged: if (active && uri) ricarica()
    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id === "elenco:" + finestra.uri) {
                finestra.caricamento = false
                if (r.ok) finestra.dati = r
                else if (r.montare) collega.apri(finestra.uri, "")
                else { finestra.dati = { voci: [], briciole: [], titolo: "" }; finestra.avviso(r.errore) }
            } else if (id === "operazione") { finestra.caricamento = false; finestra.esito(r, r.ok ? I18n.t("Fatto") : "") }
            else if (id === "cerca") { finestra.caricamento = false; finestra.risultati = r }
            else if (id === "contenuto") proprieta.contenuto = r.testo
            else if (id === "collega") {
                finestra.caricamento = false
                if (r.ok) { collega.close(); finestra.luoghi = ponte.chiama0("luoghi"); finestra.vai(r.uri || collega.indirizzo, false) }
                else { collega.errore = r.errore; collega.chiediPassword = true; collega.open() }
            }
        }
    }

    Shortcut { sequence: StandardKey.Copy; onActivated: ponte.chiama("copia", [finestra.uriScelti(), false]) }
    Shortcut { sequence: StandardKey.Cut; onActivated: ponte.chiama("copia", [finestra.uriScelti(), true]) }
    Shortcut { sequence: StandardKey.Paste; onActivated: finestra.incolla() }
    Shortcut { sequence: StandardKey.Delete; onActivated: finestra.cestina() }
    Shortcut { sequence: "Shift+Delete"; onActivated: { var u = finestra.uriScelti(); if (u.length) eliminaDialogo.apri(u) } }
    Shortcut { sequence: "F2"; onActivated: if (finestra.elencoScelti.length === 1) finestra.inRinomina = finestra.elencoScelti[0].uri }
    Shortcut { sequence: StandardKey.SelectAll; onActivated: { var n = {}; finestra.voci.forEach(function (v) { n[v.uri] = true }); finestra.scelti = n } }
    Shortcut { sequence: "Ctrl+H"; onActivated: { finestra.nascosti = !finestra.nascosti; finestra.ricarica() } }
    Shortcut { sequence: "Alt+Left"; onActivated: if (finestra.posizione > 0) { finestra.posizione--; finestra.vai(finestra.storia[finestra.posizione], true) } }
    Shortcut { sequence: "Alt+Right"; onActivated: if (finestra.posizione < finestra.storia.length - 1) { finestra.posizione++; finestra.vai(finestra.storia[finestra.posizione], true) } }
    Shortcut { sequence: "Alt+Up"; onActivated: if (finestra.dati.genitore) finestra.vai(finestra.dati.genitore, false) }
    Shortcut { sequence: "Ctrl+L"; onActivated: { indirizzo.modifica = true; campoIndirizzo.forceActiveFocus(); campoIndirizzo.selectAll() } }
    Shortcut { sequence: StandardKey.Refresh; onActivated: finestra.ricarica() }
    Shortcut { sequence: StandardKey.Find; onActivated: campoCerca.forceActiveFocus() }
    Shortcut { sequence: "Return"; onActivated: if (finestra.elencoScelti.length === 1 && !finestra.inRinomina) finestra.apriVoce(finestra.elencoScelti[0]) }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Barra laterale ────────────────────────────────────────────────
        Rectangle {
            Layout.preferredWidth: 210
            Layout.fillHeight: true
            color: Tema.chiaro ? "#E9E9EE" : "#232428"
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Tema.chiaro ? "#1A000000" : "#66000000" }
            ListView {
                anchors.fill: parent
                anchors.margins: 8
                anchors.topMargin: 12
                clip: true
                model: finestra.luoghi
                delegate: Column {
                    required property var modelData
                    width: ListView.view.width
                    visible: modelData.voci.length > 0
                    Text { text: modelData.titolo; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11; font.weight: Font.DemiBold; leftPadding: 10; topPadding: 10; bottomPadding: 4 }
                    Repeater {
                        model: modelData.voci
                        Item {
                            required property var modelData
                            width: parent.width
                            height: 30
                            VoceElenco {
                                anchors.fill: parent
                                icona: modelData.icona
                                titolo: modelData.nome
                                selezionata: finestra.uri === modelData.uri
                                onClicked: modelData.uri.indexOf("volume:") === 0 ? (finestra.caricamento = true, ponte.avvia("collega", [modelData.uri, "", "", ""], "collega")) : finestra.vai(modelData.uri, false)
                            }
                            Rectangle {
                                visible: !!modelData.espellibile
                                anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                                width: 20; height: 20; radius: 5
                                color: espelli.containsMouse ? "#33FFFFFF" : "transparent"
                                Image { anchors.centerIn: parent; width: 14; height: 14; sourceSize.width: 28; sourceSize.height: 28; source: "image://icona/media-eject-symbolic" }
                                MouseArea { id: espelli; anchors.fill: parent; hoverEnabled: true; onClicked: { var r = ponte.chiama("espelli", [modelData.uri]); finestra.esito(r, r.ok ? I18n.t("Puoi scollegare il dispositivo") : ""); if (r.ok) finestra.vai(ponte.chiama0("iniziale"), false) } }
                            }
                        }
                    }
                }
                footer: Item {
                    width: ListView.view.width; height: 44
                    VoceElenco { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 30; icona: "list-add-symbolic"; titolo: I18n.t("Connetti a un server…"); onClicked: collega.apri("", "") }
                }
            }
        }

        // ── Contenuto ─────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            // Barra degli strumenti
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                color: Tema.chiaro ? "#F6F6F9" : Tema.superficie
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Tema.chiaro ? "#1A000000" : "#66000000" }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 6
                    Pulsante { icona: "go-previous-symbolic"; enabled: finestra.posizione > 0; onClicked: { finestra.posizione--; finestra.vai(finestra.storia[finestra.posizione], true) } }
                    Pulsante { icona: "go-next-symbolic"; enabled: finestra.posizione < finestra.storia.length - 1; onClicked: { finestra.posizione++; finestra.vai(finestra.storia[finestra.posizione], true) } }
                    Pulsante { icona: "go-up-symbolic"; enabled: !!finestra.dati.genitore; onClicked: finestra.vai(finestra.dati.genitore, false) }
                    // Percorso a «briciole», clic per modificarlo
                    Item {
                        id: indirizzo
                        property bool modifica: false
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        Row {
                            visible: !indirizzo.modifica
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            clip: true
                            width: parent.width
                            Repeater {
                                model: finestra.dati.briciole
                                Row {
                                    spacing: 2
                                    Text { visible: index > 0; text: "›"; color: Tema.testoSecondario; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                                    Rectangle {
                                        width: testoBriciola.implicitWidth + 14; height: 26; radius: 6
                                        color: maBriciola.containsMouse ? (Tema.chiaro ? "#14000000" : "#1FFFFFFF") : "transparent"
                                        Text { id: testoBriciola; anchors.centerIn: parent; text: modelData.nome; color: index === finestra.dati.briciole.length - 1 ? Tema.testo : Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13; font.weight: index === finestra.dati.briciole.length - 1 ? Font.DemiBold : Font.Normal }
                                        MouseArea { id: maBriciola; anchors.fill: parent; hoverEnabled: true; onClicked: finestra.vai(modelData.uri, false); onDoubleClicked: { indirizzo.modifica = true; campoIndirizzo.forceActiveFocus() } }
                                    }
                                }
                            }
                        }
                        MouseArea { anchors.fill: parent; z: -1; onDoubleClicked: { indirizzo.modifica = true; campoIndirizzo.forceActiveFocus() } }
                        CampoTesto {
                            id: campoIndirizzo
                            visible: indirizzo.modifica
                            anchors.fill: parent
                            text: finestra.dati.percorso || finestra.uri
                            onAccepted: { indirizzo.modifica = false; var t = text.trim(); finestra.vai(t.indexOf("://") > 0 || t.indexOf("/") === 0 ? t : finestra.uri + "/" + t, false) }
                            onActiveFocusChanged: if (!activeFocus) indirizzo.modifica = false
                            Keys.onEscapePressed: indirizzo.modifica = false
                        }
                    }
                    Pulsante { icona: finestra.griglia ? "view-list-symbolic" : "view-grid-symbolic"; onClicked: finestra.griglia = !finestra.griglia }
                    CampoRicerca {
                        id: campoCerca
                        Layout.preferredWidth: 190
                        placeholderText: I18n.t("Cerca qui")
                        onAccepted: if (text.length > 0) { finestra.caricamento = true; ponte.avvia("cerca", [finestra.uri, text], "cerca") }
                        onTextChanged: if (text.length === 0) finestra.risultati = null
                    }
                }
            }
            BarraProgresso { Layout.fillWidth: true; Layout.preferredHeight: 2; indeterminate: true; visible: finestra.caricamento }
            // Cestino: barra con «Svuota»
            Rectangle {
                visible: !!finestra.dati.cestino
                Layout.fillWidth: true
                implicitHeight: 40
                color: Tema.superficie
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 12
                    Text { Layout.fillWidth: true; text: I18n.t("Gli elementi nel cestino si possono ripristinare con il tasto destro."); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                    Pulsante { text: I18n.t("Svuota il cestino"); pericoloso: true; enabled: finestra.voci.length > 0; onClicked: svuota.open() }
                }
            }

            // Vista dei file
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: function (ev) { finestra.scelti = ({}); finestra.inRinomina = ""; if (ev.button === Qt.RightButton) finestra.menuSfondo(ev.x, ev.y) }
                }
                DropArea {
                    anchors.fill: parent
                    onDropped: function (d) {
                        if (!d.hasUrls || finestra.dati.cestino) return
                        var u = Array.prototype.map.call(d.urls, function (x) { return x.toString() })
                        finestra.caricamento = true
                        ponte.avvia("trasferisci", [u, finestra.uri, (d.modifiers & Qt.ShiftModifier) !== 0, false], "operazione")
                        d.acceptProposedAction()
                    }
                }
                GridView {
                    id: vistaGriglia
                    visible: finestra.griglia
                    anchors.fill: parent
                    anchors.margins: 10
                    cellWidth: 108
                    cellHeight: 112
                    model: finestra.voci
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}
                    delegate: Elemento { larghezza: 104; altezza: 108; vistaGriglia: true }
                }
                ListView {
                    id: vistaElenco
                    visible: !finestra.griglia
                    anchors.fill: parent
                    model: finestra.voci
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}
                    header: Rectangle {
                        width: vistaElenco.width; height: 28; color: Tema.sfondo
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 44; anchors.rightMargin: 16
                            Text { text: I18n.t("Nome"); Layout.fillWidth: true; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
                            Text { text: I18n.t("Modificato"); Layout.preferredWidth: 130; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
                            Text { text: I18n.t("Dimensione"); Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
                            Text { text: I18n.t("Tipo"); Layout.preferredWidth: 150; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
                        }
                    }
                    delegate: Elemento { larghezza: vistaElenco.width; altezza: 30; vistaGriglia: false }
                }
                Column {
                    anchors.centerIn: parent
                    visible: finestra.voci.length === 0 && !finestra.caricamento
                    spacing: 8
                    Image { anchors.horizontalCenter: parent.horizontalCenter; width: 56; height: 56; sourceSize.width: 112; sourceSize.height: 112; opacity: 0.6; source: "image://icona/" + (finestra.dati.cestino ? "user-trash" : "folder") }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: finestra.risultati !== null ? I18n.t("Nessun risultato") : (finestra.dati.cestino ? I18n.t("Il cestino è vuoto") : I18n.t("Questa cartella è vuota")); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13 }
                }
            }
            // Barra di stato
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 26
                color: Tema.superficie
                Text {
                    anchors.verticalCenter: parent.verticalCenter; x: 14
                    color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11
                    text: finestra.elencoScelti.length > 0 ? finestra.elencoScelti.length + " " + I18n.t("selezionati su") + " " + finestra.voci.length
                                                          : finestra.voci.length + " " + I18n.t("elementi")
                }
            }
        }
    }

    // ── Un elemento (icona in griglia o riga in elenco) ───────────────────────
    component Elemento: Item {
        id: el
        required property var modelData
        required property int index
        property int larghezza: 104
        property int altezza: 108
        property bool vistaGriglia: true
        readonly property bool scelto: !!finestra.scelti[modelData.uri]
        width: larghezza
        height: altezza
        Item { id: fantasma }   // bersaglio fittizio: il trascinamento vero è quello del sistema (Drag.Automatic)
        Drag.active: trascina.drag.active
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
        Drag.mimeData: { "text/uri-list": (finestra.scelti[modelData.uri] ? finestra.uriScelti() : [modelData.uri]).join("\r\n") }
        Rectangle {
            anchors.fill: parent
            anchors.margins: el.vistaGriglia ? 2 : 0
            radius: el.vistaGriglia ? 8 : 0
            color: el.scelto ? (el.vistaGriglia ? "#4D" + Tema.accento.substring(1) : Tema.accento) : (trascina.containsMouse ? (Tema.chiaro ? "#0F000000" : "#14FFFFFF") : (!el.vistaGriglia && el.index % 2 ? (Tema.chiaro ? "#05000000" : "#06FFFFFF") : "transparent"))
            border.color: dropSu.containsDrag ? Tema.accento : "transparent"
            border.width: 2
        }
        // Griglia
        Image {
            visible: el.vistaGriglia
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8
            width: 52; height: 52
            fillMode: Image.PreserveAspectFit
            sourceSize.width: 104; sourceSize.height: 104
            asynchronous: true
            source: el.modelData.miniatura || el.modelData.anteprima || (el.modelData.icona.indexOf("/") === 0 ? "file://" + el.modelData.icona : "image://icona/" + el.modelData.icona)
        }
        Text {
            visible: el.vistaGriglia && finestra.inRinomina !== el.modelData.uri
            anchors.horizontalCenter: parent.horizontalCenter
            y: 66
            width: parent.width - 8
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideMiddle
            text: el.modelData.nome
            color: Tema.testo; font.family: Tema.font; font.pixelSize: 12
        }
        // Elenco
        RowLayout {
            visible: !el.vistaGriglia
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 16
            spacing: 10
            Image { Layout.preferredWidth: 20; Layout.preferredHeight: 20; sourceSize.width: 40; sourceSize.height: 40; asynchronous: true; source: el.modelData.icona.indexOf("/") === 0 ? "file://" + el.modelData.icona : "image://icona/" + el.modelData.icona }
            Text { visible: finestra.inRinomina !== el.modelData.uri; Layout.fillWidth: true; text: el.modelData.nome; elide: Text.ElideMiddle; color: el.scelto ? "#FFFFFF" : Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
            Item { visible: finestra.inRinomina === el.modelData.uri; Layout.fillWidth: true }
            Text { text: el.modelData.modificato; Layout.preferredWidth: 130; color: el.scelto ? "#FFFFFF" : Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
            Text { text: el.modelData.testoDimensione; Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight; color: el.scelto ? "#FFFFFF" : Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
            Text { text: el.modelData.tipo; Layout.preferredWidth: 150; elide: Text.ElideRight; color: el.scelto ? "#FFFFFF" : Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
        }
        MouseArea {
            id: trascina
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            drag.target: finestra.inRinomina === el.modelData.uri ? null : fantasma
            drag.threshold: 12
            onPressed: function (ev) { if (ev.button === Qt.LeftButton && !el.scelto) finestra.seleziona(el.index, ev.modifiers) }
            onClicked: function (ev) {
                if (ev.button === Qt.RightButton) { var p = mapToItem(finestra.contentItem, ev.x, ev.y); finestra.menuVoce(el.modelData, p.x, p.y) }
                else if (ev.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) { if (el.scelto && !(ev.modifiers & Qt.ShiftModifier)) finestra.seleziona(el.index, ev.modifiers) }
                else finestra.seleziona(el.index, 0)
            }
            onDoubleClicked: finestra.apriVoce(el.modelData)
            onReleased: { fantasma.x = 0; fantasma.y = 0 }
        }
        // Rilascio di file su una cartella: copiati (Maiusc: spostati) dentro
        DropArea {
            id: dropSu
            anchors.fill: parent
            enabled: el.modelData.cartella
            onDropped: function (d) {
                if (!d.hasUrls) return
                var u = Array.prototype.map.call(d.urls, function (x) { return x.toString() }).filter(function (x) { return x !== el.modelData.uri })
                if (!u.length) return
                finestra.caricamento = true
                ponte.avvia("trasferisci", [u, el.modelData.uri, (d.modifiers & Qt.ShiftModifier) !== 0, false], "operazione")
                d.acceptProposedAction()
            }
        }
        // Rinomina sul posto
        CampoTesto {
            visible: finestra.inRinomina === el.modelData.uri
            x: el.vistaGriglia ? 2 : 44
            y: el.vistaGriglia ? 64 : 1
            width: el.vistaGriglia ? parent.width - 4 : parent.width * 0.4
            font.pixelSize: 12
            onVisibleChanged: if (visible) { text = el.modelData.nome; forceActiveFocus(); var p = text.lastIndexOf("."); select(0, p > 0 && !el.modelData.cartella ? p : text.length) }
            onAccepted: { var r = ponte.chiama("rinomina", [el.modelData.uri, text]); finestra.inRinomina = ""; finestra.esito(r) }
            Keys.onEscapePressed: finestra.inRinomina = ""
        }
    }

    // ── Menu ─────────────────────────────────────────────────────────────────
    MenuFile { id: menu }

    // ── Proprietà ────────────────────────────────────────────────────────────
    Dialog {
        id: proprieta
        property var p: ({})
        property string contenuto: ""
        function apri(u) {
            p = ponte.chiama("proprieta", [u]); contenuto = ""
            if (!p.ok) { finestra.avviso(p.errore); return }
            if (p.cartella) { contenuto = I18n.t("Calcolo in corso…"); ponte.avvia("contenutoCartella", [u], "contenuto") }
            open()
        }
        anchors.centerIn: parent
        width: 440
        modal: true
        padding: 20
        title: I18n.t("Proprietà")
        standardButtons: Dialog.Close
        background: Rectangle { color: Tema.superficie; radius: 12; border.color: Tema.bordo }
        ColumnLayout {
            width: parent.width
            spacing: 12
            RowLayout {
                spacing: 12
                Image { Layout.preferredWidth: 48; Layout.preferredHeight: 48; sourceSize.width: 96; sourceSize.height: 96; source: proprieta.p.icona ? (proprieta.p.icona.indexOf("/") === 0 ? "file://" + proprieta.p.icona : "image://icona/" + proprieta.p.icona) : "" }
                ColumnLayout {
                    spacing: 2
                    Text { text: proprieta.p.nome || ""; color: Tema.testo; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideMiddle; Layout.maximumWidth: 330 }
                    Text { text: proprieta.p.tipo || ""; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                }
            }
            GridLayout {
                columns: 2
                columnSpacing: 14
                rowSpacing: 7
                Layout.fillWidth: true
                Repeater {
                    model: [
                        { k: I18n.t("Contenuto"), v: proprieta.contenuto, vis: !!proprieta.p.cartella },
                        { k: I18n.t("Dimensione"), v: proprieta.p.dimensione, vis: !proprieta.p.cartella },
                        { k: I18n.t("Posizione"), v: proprieta.p.posizione, vis: true },
                        { k: I18n.t("Modificato"), v: proprieta.p.modificato, vis: true },
                        { k: I18n.t("Ultimo accesso"), v: proprieta.p.accesso, vis: true },
                        { k: I18n.t("Creato"), v: proprieta.p.creato, vis: true },
                        { k: I18n.t("Proprietario"), v: proprieta.p.proprietario, vis: true },
                        { k: I18n.t("Permessi"), v: proprieta.p.permessi, vis: true },
                        { k: I18n.t("Spazio sul disco"), v: proprieta.p.spazio, vis: true }
                    ]
                    delegate: Item {
                        required property var modelData
                        visible: modelData.vis && !!modelData.v
                        Layout.columnSpan: 2
                        Layout.fillWidth: true
                        implicitHeight: riga.implicitHeight
                        RowLayout {
                            id: riga
                            width: parent.width
                            Text { text: modelData.k; Layout.preferredWidth: 120; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                            Text { text: modelData.v || ""; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere; color: Tema.testo; font.family: Tema.font; font.pixelSize: 12 }
                        }
                    }
                }
            }
            RowLayout {
                visible: !proprieta.p.cartella && !!proprieta.p.permessi
                Interruttore { checked: !!proprieta.p.eseguibile; onToggled: ponte.chiama("impostaEseguibile", [proprieta.p.uri, checked]) }
                Text { text: I18n.t("Consenti di eseguire come programma"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 12 }
            }
        }
    }

    // ── Apri con ─────────────────────────────────────────────────────────────
    Dialog {
        id: apriCon
        property var voce: ({})
        property var app: []
        function apri(v) { voce = v; app = ponte.chiama("appPer", [v.uri]); open() }
        anchors.centerIn: parent
        width: 380
        height: Math.min(480, 110 + app.length * 34)
        modal: true
        title: I18n.t("Apri con")
        standardButtons: Dialog.Cancel
        background: Rectangle { color: Tema.superficie; radius: 12; border.color: Tema.bordo }
        ListView {
            anchors.fill: parent
            clip: true
            model: apriCon.app
            delegate: VoceElenco {
                width: ListView.view.width
                icona: modelData.icona
                titolo: modelData.nome
                onClicked: { ponte.chiama("apriCon", [modelData.id, apriCon.voce.uri]); apriCon.close() }
            }
            Text { anchors.centerIn: parent; visible: apriCon.app.length === 0; text: I18n.t("Nessuna app per questo tipo di file"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13 }
        }
    }

    // ── Connetti a un server / posizione protetta ────────────────────────────
    Dialog {
        id: collega
        property string indirizzo: ""
        property string errore: ""
        property bool chiediPassword: false
        function apri(u, e) { indirizzo = u; errore = e; chiediPassword = false; campoServer.text = u; open() }
        anchors.centerIn: parent
        width: 440
        modal: true
        title: I18n.t("Connetti a un server")
        standardButtons: Dialog.Cancel | Dialog.Ok
        background: Rectangle { color: Tema.superficie; radius: 12; border.color: Tema.bordo }
        onAccepted: {
            indirizzo = campoServer.text.trim()
            if (indirizzo.indexOf("://") < 0) indirizzo = "smb://" + indirizzo
            finestra.caricamento = true
            ponte.avvia("collega", [indirizzo, campoUtente.text, campoPassword.text, campoDominio.text], "collega")
        }
        ColumnLayout {
            width: parent.width
            spacing: 8
            Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: I18n.t("Esempi: smb://192.168.1.10/condivisa · smb://nome-pc · sftp://utente@server · ftp://server · dav://server/cartella"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
            CampoTesto { id: campoServer; Layout.fillWidth: true; placeholderText: I18n.t("Indirizzo del server") }
            Text { visible: collega.chiediPassword; text: I18n.t("Accesso richiesto (lascia vuoto per accedere come ospite)"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 12 }
            CampoTesto { id: campoUtente; visible: collega.chiediPassword; Layout.fillWidth: true; placeholderText: I18n.t("Nome utente") }
            CampoTesto { id: campoPassword; visible: collega.chiediPassword; Layout.fillWidth: true; placeholderText: I18n.t("Password"); echoMode: TextInput.Password }
            CampoTesto { id: campoDominio; visible: collega.chiediPassword; Layout.fillWidth: true; placeholderText: I18n.t("Dominio o gruppo di lavoro (facoltativo)") }
            Text { visible: !!collega.errore; Layout.fillWidth: true; wrapMode: Text.Wrap; text: collega.errore; color: Tema.pericolo; font.family: Tema.font; font.pixelSize: 12 }
        }
    }

    Dialog {
        id: svuota
        anchors.centerIn: parent
        modal: true
        title: I18n.t("Svuotare il cestino? Gli elementi verranno eliminati per sempre.")
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: { finestra.caricamento = true; ponte.avvia("svuotaCestino", [], "operazione") }
    }
    Dialog {
        id: eliminaDialogo
        property var elenco: []
        function apri(u) { elenco = u; open() }
        anchors.centerIn: parent
        modal: true
        title: I18n.t("Eliminare definitivamente? Non si potrà recuperare.")
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: { finestra.caricamento = true; ponte.avvia("eliminaDefinitivamente", [elenco], "operazione") }
    }
}
