// Calendario: barra in alto (Oggi, frecce, mese, Giorno/Settimana/Mese, Nuovo evento), a sinistra
// i calendari con i colori e cosa c'è oggi, al centro la vista; a destra il pannello per creare
// o modificare un evento (titolo, calendario, tutto il giorno, inizio e fine, ripeti, avviso,
// luogo, note). Gli avvisi arrivano anche ad app chiusa.
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Calendario")
    width: 1180
    height: 760
    minimumWidth: 820
    minimumHeight: 560

    property string vista: "mese"            // giorno | settimana | mese
    property var giorno: new Date()          // giorno di riferimento della vista
    property var calendari: []
    property var eventi: []
    property var opzioni: ({ ripeti: [], avvisi: [], colori: [] })
    property var oggiPromemoria: []
    property var bozza: null                 // evento in modifica
    readonly property var mesi: ["Gennaio", "Febbraio", "Marzo", "Aprile", "Maggio", "Giugno", "Luglio", "Agosto", "Settembre", "Ottobre", "Novembre", "Dicembre"]
    readonly property var giorniBrevi: ["lun", "mar", "mer", "gio", "ven", "sab", "dom"]
    readonly property real oraAltezza: 52

    function due(n) { return (n < 10 ? "0" : "") + n }
    function iso(d) { return d.getFullYear() + "-" + due(d.getMonth() + 1) + "-" + due(d.getDate()) }
    function giornoSettimana(d) { return (d.getDay() + 6) % 7 }      // lunedì = 0
    function aggiungiGiorni(d, n) { var x = new Date(d); x.setDate(x.getDate() + n); return x }
    function inizioSettimana(d) { return aggiungiGiorni(new Date(d.getFullYear(), d.getMonth(), d.getDate()), -giornoSettimana(d)) }
    readonly property var primoGriglia: { var p = new Date(giorno.getFullYear(), giorno.getMonth(), 1); return aggiungiGiorni(p, -giornoSettimana(p)) }
    readonly property var giorniVista: {
        var n = vista === "mese" ? 42 : (vista === "settimana" ? 7 : 1)
        var inizio = vista === "mese" ? primoGriglia : (vista === "settimana" ? inizioSettimana(giorno) : giorno)
        var out = []
        for (var i = 0; i < n; i++) out.push(aggiungiGiorni(inizio, i))
        return out
    }
    readonly property string titolo: {
        if (vista === "giorno") return giorno.toLocaleDateString(Qt.locale("it_IT"), "dddd d MMMM yyyy")
        if (vista === "settimana") {
            var a = giorniVista[0], b = giorniVista[6]
            return a.getDate() + (a.getMonth() !== b.getMonth() ? " " + I18n.t(mesi[a.getMonth()]).slice(0, 3).toLowerCase() : "") + " – " + b.getDate() + " " + I18n.t(mesi[b.getMonth()]) + " " + b.getFullYear()
        }
        return I18n.t(mesi[giorno.getMonth()]) + " " + giorno.getFullYear()
    }
    function ricarica() {
        calendari = ponte.chiama0("calendari")
        var g = giorniVista
        eventi = ponte.chiama("eventi", [iso(g[0]), iso(g[g.length - 1])])
        oggiPromemoria = ponte.chiama0("promemoriaOggi")
    }
    // eventi con l'orario che si sovrappongono: affiancati in colonne
    function disponi(lista) {
        function min(o) { return parseInt(o.slice(0, 2)) * 60 + parseInt(o.slice(3, 5)) }
        var ev = lista.map(function (e) { var x = Object.assign({}, e); x._da = min(e.ora); x._a = e.fine.slice(0, 10) !== e.giorno ? 1440 : Math.max(x._da + 20, min(e.oraFine)); return x })
        ev.sort(function (a, b) { return a._da - b._da || b._a - a._a })
        var gruppo = [], fineGruppo = -1, colonne = []
        function chiudi() { gruppo.forEach(function (x) { x._n = colonne.length }); gruppo = []; colonne = [] }
        ev.forEach(function (x) {
            if (x._da >= fineGruppo) chiudi()
            var c = 0
            while (c < colonne.length && colonne[c] > x._da) c++
            colonne[c] = x._a; x._col = c
            gruppo.push(x); fineGruppo = Math.max(fineGruppo, x._a)
        })
        chiudi()
        return ev
    }
    function eventiDel(d) { var k = iso(d); return eventi.filter(function (e) { return e.giorno === k }) }
    function sposta(n) {
        var g = new Date(giorno)
        if (vista === "mese") g = new Date(g.getFullYear(), g.getMonth() + n, 1)
        else g = aggiungiGiorni(g, vista === "settimana" ? 7 * n : n)
        giorno = g
    }
    function nuovo(d, ora) {
        var data = d || giorno, h = ora === undefined ? 9 : ora
        bozza = { titolo: "", calendario: calendari.length ? calendari[0].id : "personale", tuttoGiorno: false,
                  dataInizio: due(data.getDate()) + "/" + due(data.getMonth() + 1) + "/" + data.getFullYear(), oraInizio: due(h) + ":00",
                  dataFine: due(data.getDate()) + "/" + due(data.getMonth() + 1) + "/" + data.getFullYear(), oraFine: due(Math.min(23, h + 1)) + ":00",
                  ripeti: "", avviso: 15, luogo: "", note: "" }
    }
    function modifica(e) {
        var s = e.inizio, f = e.fine
        // per gli eventi ripetuti si modifica l'evento intero (la prima volta)
        bozza = { id: e.id, titolo: e.titolo, calendario: e.calendario, tuttoGiorno: e.tuttoGiorno,
                  dataInizio: s.slice(8, 10) + "/" + s.slice(5, 7) + "/" + s.slice(0, 4), oraInizio: e.tuttoGiorno ? "09:00" : s.slice(11, 16),
                  dataFine: f.slice(8, 10) + "/" + f.slice(5, 7) + "/" + f.slice(0, 4), oraFine: e.tuttoGiorno ? "10:00" : f.slice(11, 16),
                  ripeti: e.ripeti, avviso: e.avviso, luogo: e.luogo, note: e.note, ripetuto: !!e.ripeti }
    }
    function dataIso(testo) {
        var p = testo.trim().split(/[\/.\-]/)
        if (p.length !== 3) return ""
        var g = parseInt(p[0]), m = parseInt(p[1]), a = parseInt(p[2])
        if (a < 100) a += 2000
        if (!(g >= 1 && g <= 31 && m >= 1 && m <= 12 && a > 1900)) return ""
        return a + "-" + due(m) + "-" + due(g)
    }
    function salva() {
        var b = bozza
        var di = dataIso(campoDataInizio.text), df = dataIso(campoDataFine.text)
        if (!di || !df) { avviso.mostra(I18n.t("Scrivi le date come 24/11/2026")); return }
        var oi = campoOraInizio.text.trim(), of = campoOraFine.text.trim()
        if (!b.tuttoGiorno && (!/^\d{1,2}:\d{2}$/.test(oi) || !/^\d{1,2}:\d{2}$/.test(of))) { avviso.mostra(I18n.t("Scrivi le ore come 09:30")); return }
        function ora(o) { var x = o.split(":"); return due(parseInt(x[0])) + ":" + x[1] }
        var e = { id: b.id, titolo: campoTitolo.text, calendario: b.calendario, tuttoGiorno: b.tuttoGiorno,
                  inizio: b.tuttoGiorno ? di : di + "T" + ora(oi), fine: b.tuttoGiorno ? df : df + "T" + ora(of),
                  ripeti: b.ripeti, avviso: b.avviso, luogo: campoLuogo.text, note: campoNote.text }
        var r = ponte.chiama("salvaEvento", [e])
        avviso.mostra(r.messaggio)
        if (r.ok) { bozza = null; ricarica() }
    }
    onGiorniVistaChanged: ricarica()
    Component.onCompleted: { opzioni = ponte.chiama0("opzioni"); ricarica() }
    Timer { interval: 60000; repeat: true; running: true; onTriggered: finestra.ricarica() }

    FileDialog { id: sceltaIcs; nameFilters: [I18n.t("Calendari") + " (*.ics)"]; onAccepted: { avviso.mostra(ponte.chiama("importa", [selectedFile.toString(), finestra.calendari.length ? finestra.calendari[0].id : "personale"]).messaggio); finestra.ricarica() } }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Barra ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: Tema.superficie
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                spacing: 10
                Pulsante { text: I18n.t("Oggi"); onClicked: finestra.giorno = new Date() }
                Repeater {
                    model: [{ s: "freccia-sinistra", n: -1 }, { s: "freccia-destra", n: 1 }]
                    Rectangle {
                        width: 32; height: 32; radius: 8
                        color: sopraF.hovered ? Tema.superficieAlta : "transparent"
                        HoverHandler { id: sopraF }
                        Simbolo { anchors.centerIn: parent; nome: modelData.s; lato: 18; colore: Tema.testo }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: finestra.sposta(modelData.n) }
                    }
                }
                Text { text: finestra.titolo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 22; font.weight: Font.Bold; Layout.fillWidth: true; elide: Text.ElideRight
                       font.capitalization: finestra.vista === "giorno" ? Font.Capitalize : Font.MixedCase }
                Rectangle {
                    Layout.preferredWidth: rigaV.implicitWidth + 8; Layout.preferredHeight: 34; radius: 17
                    color: Tema.superficieAlta
                    Row {
                        id: rigaV; anchors.centerIn: parent; spacing: 2
                        Repeater {
                            model: [{ id: "giorno", t: I18n.t("Giorno") }, { id: "settimana", t: I18n.t("Settimana") }, { id: "mese", t: I18n.t("Mese") }]
                            Rectangle {
                                width: tv.implicitWidth + 24; height: 28; radius: 14
                                color: finestra.vista === modelData.id ? Tema.accento : "transparent"
                                Text { id: tv; anchors.centerIn: parent; text: modelData.t; color: finestra.vista === modelData.id ? "white" : Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: finestra.vista = modelData.id }
                            }
                        }
                    }
                }
                Pulsante { text: I18n.t("Nuovo evento"); principale: true; onClicked: finestra.nuovo() }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Tema.bordo }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ── Calendari e oggi ──
            Rectangle {
                Layout.preferredWidth: 230
                Layout.fillHeight: true
                color: Tema.superficie
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 14
                    spacing: 8
                    Text { text: I18n.t("Calendari"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                    Repeater {
                        model: finestra.calendari
                        RowLayout {
                            Layout.fillWidth: true; spacing: 10
                            Rectangle {
                                width: 18; height: 18; radius: 5
                                color: modelData.visibile ? modelData.colore : "transparent"
                                border.color: modelData.colore; border.width: 2
                                Simbolo { anchors.centerIn: parent; visible: modelData.visibile; nome: "spunta"; lato: 12; colore: "#FFFFFF" }
                                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: { ponte.chiama("mostraCalendario", [modelData.id, !modelData.visibile]); finestra.ricarica() } }
                            }
                            Text { text: modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; Layout.fillWidth: true }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        CampoTesto { id: nuovoCal; Layout.fillWidth: true; placeholderText: I18n.t("Nuovo calendario") }
                        Pulsante { text: "+"; enabled: nuovoCal.text.length > 0; onClicked: { finestra.calendari = ponte.chiama("salvaCalendario", [{ nome: nuovoCal.text }]); nuovoCal.text = "" } }
                    }
                    Rectangle { Layout.fillWidth: true; Layout.topMargin: 8; height: 1; color: Tema.bordo }
                    Text { text: I18n.t("Oggi"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                    Repeater {
                        model: finestra.eventiDel(new Date())
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Rectangle { width: 4; height: 30; radius: 2; color: modelData.colore }
                            ColumnLayout {
                                spacing: 0; Layout.fillWidth: true
                                Text { text: modelData.titolo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                Text { text: modelData.tuttoGiorno ? I18n.t("Tutto il giorno") : modelData.ora + " – " + modelData.oraFine; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
                            }
                        }
                    }
                    Repeater {
                        model: finestra.oggiPromemoria
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Simbolo { nome: "cerchio-spunta"; lato: 16; colore: modelData.colore }
                            Text { text: modelData.titolo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                    }
                    Text {
                        visible: finestra.eventiDel(new Date()).length === 0 && finestra.oggiPromemoria.length === 0
                        text: I18n.t("Niente in programma"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13
                    }
                    Item { Layout.fillHeight: true }
                    RowLayout {
                        Layout.fillWidth: true
                        Pulsante { text: I18n.t("Importa…"); onClicked: sceltaIcs.open() }
                        Pulsante { text: I18n.t("Esporta"); onClicked: avviso.mostra(ponte.chiama0("esporta").messaggio) }
                    }
                }
            }
            Rectangle { Layout.fillHeight: true; width: 1; color: Tema.bordo }

            // ── Mese ──
            ColumnLayout {
                visible: finestra.vista === "mese"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0
                Row {
                    Layout.fillWidth: true
                    Repeater {
                        model: finestra.giorniBrevi
                        Text { width: (finestra.width - 231 - (finestra.bozza ? 361 : 0)) / 7; height: 30; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignRight; rightPadding: 10
                               text: I18n.t(modelData); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold; font.capitalization: Font.Capitalize }
                    }
                }
                Grid {
                    id: griglia
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 7
                    readonly property real cella: width / 7
                    readonly property real riga: height / 6
                    Repeater {
                        model: finestra.giorniVista
                        Rectangle {
                            id: cella
                            required property var modelData
                            readonly property bool fuori: modelData.getMonth() !== finestra.giorno.getMonth()
                            readonly property bool oggi: finestra.iso(modelData) === finestra.iso(new Date())
                            readonly property var lista: finestra.eventiDel(modelData)
                            width: griglia.cella; height: griglia.riga
                            color: sopraC.hovered ? Tema.superficie : "transparent"
                            border.color: Tema.bordo; border.width: 0.5
                            HoverHandler { id: sopraC }
                            Rectangle {
                                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 6
                                width: 28; height: 28; radius: 14
                                color: cella.oggi ? Tema.accento : "transparent"
                                Text { anchors.centerIn: parent; text: cella.modelData.getDate(); color: cella.oggi ? "white" : (cella.fuori ? Tema.testoSecondario : Tema.testo); font.family: Tema.font; font.pixelSize: 14; font.weight: cella.oggi ? Font.Bold : Font.Normal }
                            }
                            Column {
                                x: 4; y: 36; width: parent.width - 8
                                spacing: 2
                                Repeater {
                                    model: cella.lista.slice(0, Math.max(1, Math.floor((cella.height - 40) / 20)))
                                    Rectangle {
                                        width: parent.width; height: 18; radius: 4
                                        color: modelData.tuttoGiorno ? Qt.rgba(Qt.color(modelData.colore).r, Qt.color(modelData.colore).g, Qt.color(modelData.colore).b, 0.85) : "transparent"
                                        Row {
                                            anchors.verticalCenter: parent.verticalCenter; x: 4; spacing: 4
                                            Rectangle { visible: !modelData.tuttoGiorno; anchors.verticalCenter: parent.verticalCenter; width: 7; height: 7; radius: 4; color: modelData.colore }
                                            Text {
                                                width: cella.width - 24; elide: Text.ElideRight
                                                text: (modelData.tuttoGiorno ? "" : modelData.ora + " ") + modelData.titolo
                                                color: modelData.tuttoGiorno ? "white" : Tema.testo; font.family: Tema.font; font.pixelSize: 11
                                            }
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: finestra.modifica(modelData) }
                                    }
                                }
                                Text {
                                    visible: cella.lista.length > Math.max(1, Math.floor((cella.height - 40) / 20))
                                    text: "+" + (cella.lista.length - Math.max(1, Math.floor((cella.height - 40) / 20))) + " " + I18n.t("altri")
                                    color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11; leftPadding: 4
                                }
                            }
                            MouseArea {
                                anchors.fill: parent; z: -1
                                onClicked: finestra.giorno = cella.modelData
                                onDoubleClicked: { finestra.giorno = cella.modelData; finestra.nuovo(cella.modelData) }
                            }
                        }
                    }
                }
            }

            // ── Settimana e giorno ──
            ColumnLayout {
                visible: finestra.vista !== "mese"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0
                readonly property real colonna: (width - 56) / finestra.giorniVista.length
                // intestazione dei giorni e tutto il giorno
                Row {
                    Layout.fillWidth: true
                    x: 56
                    Item { width: 56; height: 1 }
                    Repeater {
                        model: finestra.giorniVista
                        Column {
                            width: parent.parent.colonna
                            spacing: 2
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter; spacing: 6; topPadding: 6
                                Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.t(finestra.giorniBrevi[finestra.giornoSettimana(modelData)]); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12; font.capitalization: Font.Capitalize }
                                Rectangle {
                                    width: 30; height: 30; radius: 15
                                    readonly property bool oggi: finestra.iso(modelData) === finestra.iso(new Date())
                                    color: oggi ? Tema.accento : "transparent"
                                    Text { anchors.centerIn: parent; text: modelData.getDate(); color: parent.oggi ? "white" : Tema.testo; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.DemiBold }
                                }
                            }
                            Repeater {
                                model: finestra.eventiDel(modelData).filter(function (e) { return e.tuttoGiorno })
                                Rectangle {
                                    width: parent.width - 6; x: 3; height: 20; radius: 4; color: modelData.colore
                                    Text { x: 6; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 10; elide: Text.ElideRight; text: modelData.titolo; color: "white"; font.family: Tema.font; font.pixelSize: 11; font.weight: Font.DemiBold }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: finestra.modifica(modelData) }
                                }
                            }
                        }
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: Tema.bordo }
                Flickable {
                    id: ore
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: 24 * finestra.oraAltezza
                    clip: true
                    contentY: 7 * finestra.oraAltezza - 10
                    ScrollBar.vertical: ScrollBar {}
                    Item {
                        width: ore.width; height: 24 * finestra.oraAltezza
                        Repeater {
                            model: 24
                            Item {
                                y: index * finestra.oraAltezza; width: parent.width; height: finestra.oraAltezza
                                Text { x: 6; y: -7; visible: index > 0; text: finestra.due(index) + ":00"; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
                                Rectangle { x: 56; width: parent.width - 56; height: 1; color: Tema.bordo; opacity: 0.6 }
                            }
                        }
                        Repeater {
                            model: finestra.giorniVista
                            Item {
                                id: col
                                required property var modelData
                                required property int index
                                x: 56 + index * (ore.width - 56) / finestra.giorniVista.length
                                width: (ore.width - 56) / finestra.giorniVista.length
                                height: parent.height
                                Rectangle { width: 1; height: parent.height; color: Tema.bordo; opacity: 0.6 }
                                MouseArea { anchors.fill: parent; onDoubleClicked: function (m) { finestra.nuovo(col.modelData, Math.floor(m.y / finestra.oraAltezza)) } }
                                Repeater {
                                    model: finestra.disponi(finestra.eventiDel(col.modelData).filter(function (e) { return !e.tuttoGiorno }))
                                    Rectangle {
                                        readonly property real inizio: parseInt(modelData.ora.slice(0, 2)) + parseInt(modelData.ora.slice(3, 5)) / 60
                                        readonly property real fine: modelData.fine.slice(0, 10) !== modelData.giorno ? 24 : parseInt(modelData.oraFine.slice(0, 2)) + parseInt(modelData.oraFine.slice(3, 5)) / 60
                                        x: 3 + modelData._col * (col.width - 6) / modelData._n; y: inizio * finestra.oraAltezza + 1
                                        width: (col.width - 6) / modelData._n - (modelData._n > 1 ? 2 : 0); height: Math.max(22, (fine - inizio) * finestra.oraAltezza - 2)
                                        radius: 6
                                        color: Qt.rgba(Qt.color(modelData.colore).r, Qt.color(modelData.colore).g, Qt.color(modelData.colore).b, 0.22)
                                        Rectangle { width: 3; height: parent.height; radius: 2; color: modelData.colore }
                                        Column {
                                            x: 8; y: 4; width: parent.width - 12
                                            Text { width: parent.width; text: modelData.titolo; elide: Text.ElideRight; color: Tema.testo; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                                            Text { width: parent.width; text: modelData.ora + (modelData.luogo ? " · " + modelData.luogo : ""); elide: Text.ElideRight; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: finestra.modifica(modelData) }
                                    }
                                }
                                // linea rossa dell'ora attuale
                                Rectangle {
                                    visible: finestra.iso(col.modelData) === finestra.iso(new Date())
                                    y: (new Date().getHours() + new Date().getMinutes() / 60) * finestra.oraAltezza
                                    width: parent.width; height: 2; color: "#EF4444"
                                    Rectangle { x: -4; y: -3; width: 8; height: 8; radius: 4; color: "#EF4444" }
                                }
                            }
                        }
                    }
                }
            }

            // ── Pannello dell'evento ──
            Rectangle { visible: !!finestra.bozza; Layout.fillHeight: true; width: 1; color: Tema.bordo }
            Rectangle {
                visible: !!finestra.bozza
                Layout.preferredWidth: 360
                Layout.fillHeight: true
                color: Tema.superficie
                Flickable {
                    anchors.fill: parent; anchors.margins: 16
                    contentHeight: modulo.implicitHeight
                    clip: true
                    ColumnLayout {
                        id: modulo
                        width: parent.width
                        spacing: 10
                        Text { text: finestra.bozza && finestra.bozza.id ? I18n.t("Modifica evento") : I18n.t("Nuovo evento"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 18; font.weight: Font.Bold }
                        CampoTesto { id: campoTitolo; objectName: "campoTitolo"; Layout.fillWidth: true; placeholderText: I18n.t("Titolo"); text: finestra.bozza ? finestra.bozza.titolo : "" }
                        Flow {
                            Layout.fillWidth: true; spacing: 6
                            Repeater {
                                model: finestra.calendari
                                Rectangle {
                                    readonly property bool scelto: !!finestra.bozza && finestra.bozza.calendario === modelData.id
                                    width: tc.implicitWidth + 30; height: 28; radius: 14
                                    color: scelto ? modelData.colore : Tema.superficieAlta
                                    Row {
                                        id: tc; anchors.centerIn: parent; spacing: 6
                                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: parent.parent.scelto ? "white" : modelData.colore }
                                        Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.nome; color: parent.parent.scelto ? "white" : Tema.testo; font.family: Tema.font; font.pixelSize: 12 }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: finestra.bozza = Object.assign({}, finestra.bozza, { calendario: modelData.id }) }
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: I18n.t("Tutto il giorno"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; Layout.fillWidth: true }
                            Interruttore { checked: !!finestra.bozza && finestra.bozza.tuttoGiorno; onToggled: finestra.bozza = Object.assign({}, finestra.bozza, { tuttoGiorno: checked }) }
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3; columnSpacing: 8; rowSpacing: 8
                            Text { text: I18n.t("Inizio"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13 }
                            CampoTesto { id: campoDataInizio; Layout.fillWidth: true; text: finestra.bozza ? finestra.bozza.dataInizio : ""; placeholderText: "24/11/2026"; onEditingFinished: if (campoDataFine.text < text || finestra.dataIso(campoDataFine.text) < finestra.dataIso(text)) campoDataFine.text = text }
                            CampoTesto { id: campoOraInizio; Layout.preferredWidth: 72; visible: !!finestra.bozza && !finestra.bozza.tuttoGiorno; text: finestra.bozza ? finestra.bozza.oraInizio : ""; placeholderText: "09:00" }
                            Text { text: I18n.t("Fine"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13 }
                            CampoTesto { id: campoDataFine; Layout.fillWidth: true; text: finestra.bozza ? finestra.bozza.dataFine : ""; placeholderText: "24/11/2026" }
                            CampoTesto { id: campoOraFine; Layout.preferredWidth: 72; visible: !!finestra.bozza && !finestra.bozza.tuttoGiorno; text: finestra.bozza ? finestra.bozza.oraFine : ""; placeholderText: "10:00" }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Simbolo { nome: "ripeti"; lato: 16; colore: Tema.testoSecondario }
                            Scelta {
                                Layout.fillWidth: true
                                model: finestra.opzioni.ripeti; textRole: "nome"; valueRole: "id"
                                currentIndex: finestra.bozza ? Math.max(0, finestra.opzioni.ripeti.findIndex(function (x) { return x.id === finestra.bozza.ripeti })) : 0
                                onActivated: finestra.bozza = Object.assign({}, finestra.bozza, { ripeti: currentValue })
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Simbolo { nome: "campana"; lato: 16; colore: Tema.testoSecondario }
                            Scelta {
                                Layout.fillWidth: true
                                model: finestra.opzioni.avvisi; textRole: "nome"; valueRole: "id"
                                currentIndex: finestra.bozza ? Math.max(0, finestra.opzioni.avvisi.findIndex(function (x) { return x.id === finestra.bozza.avviso })) : 0
                                onActivated: finestra.bozza = Object.assign({}, finestra.bozza, { avviso: currentValue })
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Simbolo { nome: "dove"; lato: 16; colore: Tema.testoSecondario }
                            CampoTesto { id: campoLuogo; Layout.fillWidth: true; placeholderText: I18n.t("Luogo"); text: finestra.bozza ? finestra.bozza.luogo : "" }
                        }
                        TextArea {
                            id: campoNote
                            Layout.fillWidth: true; Layout.preferredHeight: 90
                            placeholderText: I18n.t("Note"); wrapMode: TextEdit.Wrap
                            text: finestra.bozza ? finestra.bozza.note : ""
                            color: Tema.testo; font.family: Tema.font
                            background: Rectangle { radius: 8; color: Tema.superficieAlta }
                        }
                        Text {
                            visible: !!finestra.bozza && finestra.bozza.ripetuto === true
                            Layout.fillWidth: true; wrapMode: Text.WordWrap
                            text: I18n.t("È un evento che si ripete: le modifiche valgono per tutte le volte.")
                            color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                        }
                        RowLayout {
                            Layout.fillWidth: true; Layout.topMargin: 6
                            Pulsante { visible: !!finestra.bozza && !!finestra.bozza.id; text: I18n.t("Elimina"); pericoloso: true; onClicked: { ponte.chiama("eliminaEvento", [finestra.bozza.id]); finestra.bozza = null; finestra.ricarica() } }
                            Item { Layout.fillWidth: true }
                            Pulsante { text: I18n.t("Annulla"); onClicked: finestra.bozza = null }
                            Pulsante { text: I18n.t("Salva"); principale: true; onClicked: finestra.salva() }
                        }
                    }
                }
            }
        }
    }
    Messaggio { id: avviso }
}
