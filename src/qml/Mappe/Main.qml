// Mappe: la carta di SolidOS a tutta finestra e, a sinistra, un pannello per cercare luoghi,
// vedere la scheda del luogo, chiedere le indicazioni (auto, bici, a piedi) e partire.
// Durante la guida: in alto la prossima manovra grande, in basso arrivo, tempo e km che restano.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Mappe")
    width: 1180
    height: 760
    minimumWidth: 760
    minimumHeight: 520

    property var qui: null                 // la mia posizione {lat, lon, precisione}
    property var risultati: []
    property var luogo: null               // il luogo scelto
    property var partenza: null            // null = la mia posizione
    property var percorso: null
    property string mezzo: "auto"
    property bool calcolo: false
    property var salvati: ({ preferiti: [], recenti: [] })
    // guida
    property bool guidando: false
    property bool prova: false             // «Prova il percorso»: la posizione scorre da sola
    property var stato: null               // risposta di ponte.guida
    property int indiceProva: 0
    property bool voce: true
    property string ultimoAnnuncio: ""
    property bool seguendo: true

    function cerca(t) { if (t.length < 2) { risultati = []; return } ponte.avvia("cerca", [t, qui ? qui.lat : "", qui ? qui.lon : ""], "cerca") }
    function scegli(l) {
        luogo = l; percorso = null; risultati = []
        carta.centra(l.lat, l.lon, Math.max(carta.zoom, 15))
        ponte.chiama("ricorda", [l]); salvati = ponte.chiama0("salvati")
    }
    function indicazioni() {
        if (!luogo) return
        var da = partenza || qui
        if (!da) { avviso.mostra(I18n.t("Non so ancora dove sei: scegli una partenza o premi «Dove sono»")); return }
        calcolo = true
        ponte.avvia("percorso", [{ lat: da.lat, lon: da.lon }, { lat: luogo.lat, lon: luogo.lon }, mezzo], "percorso")
    }
    function avvia(simulata) {
        if (!percorso) return
        prova = simulata; guidando = true; seguendo = true; indiceProva = 0; ultimoAnnuncio = ""
        carta.zoom = 16
        aggiornaGuida(simulata ? { lat: percorso.forma[0][0], lon: percorso.forma[0][1] } : qui)
    }
    function termina() { guidando = false; prova = false; stato = null; carta.fattoFino = 0; carta.inquadra(percorso ? percorso.forma : []) }
    function aggiornaGuida(pos) {
        if (!pos) return
        var g = ponte.chiama("guida", [pos.lat, pos.lon, stato ? stato.indice : 0])
        if (!g.ok) return
        stato = g
        carta.fattoFino = g.indice
        if (seguendo) carta.centra(pos.lat, pos.lon)
        if (g.arrivato) { if (voce) ponte.chiama("parla", [I18n.t("Sei arrivato")]); avviso.mostra(I18n.t("Sei arrivato a destinazione")); termina(); return }
        if (g.fuori && !prova) { avviso.mostra(I18n.t("Fuori percorso: ricalcolo…")); partenza = null; qui = pos; indicazioni(); return }
        // annuncio a voce a 300 m e poco prima della manovra
        var chiave = g.manovra.inizio + (g.metriAllaManovra < 60 ? "-ora" : (g.metriAllaManovra < 320 ? "-presto" : ""))
        if (voce && chiave !== ultimoAnnuncio && (g.metriAllaManovra < 60 || g.metriAllaManovra < 320)) {
            ultimoAnnuncio = chiave
            ponte.chiama("parla", [g.metriAllaManovra < 60 ? g.manovra.testo : I18n.t("Tra") + " " + g.allaManovra + ", " + g.manovra.annuncio])
        }
    }
    // freccia della manovra (tipi di Valhalla)
    function freccia(tipo) {
        if ([4, 5, 6].indexOf(tipo) >= 0) return "⚑"
        if ([9, 18, 20, 23].indexOf(tipo) >= 0) return "↗"
        if ([10].indexOf(tipo) >= 0) return "→"
        if ([11].indexOf(tipo) >= 0) return "↘"
        if ([12, 13].indexOf(tipo) >= 0) return "↶"
        if ([14].indexOf(tipo) >= 0) return "↙"
        if ([15].indexOf(tipo) >= 0) return "←"
        if ([16, 19, 21, 24].indexOf(tipo) >= 0) return "↖"
        if ([26, 27].indexOf(tipo) >= 0) return "⟳"
        return "↑"
    }

    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id === "posizione") {
                if (r && r.lat !== undefined) {
                    finestra.qui = r
                    if (!finestra.luogo && !finestra.guidando) carta.centra(r.lat, r.lon, r.fonte === "wifi" ? 15 : 12)
                }
            } else if (id === "cerca") finestra.risultati = r
            else if (id === "percorso") {
                finestra.calcolo = false
                if (!r.ok) { avviso.mostra(r.messaggio); return }
                finestra.percorso = r
                carta.forma = r.forma
                if (!finestra.guidando) carta.inquadra(r.forma)
            } else if (id === "punto") finestra.scegli(r)
        }
    }
    Component.onCompleted: { salvati = ponte.chiama0("salvati"); ponte.avvia("posizione", [], "posizione") }

    // posizione vera durante la guida; «prova» fa scorrere il percorso a 50 km/h circa
    Timer {
        interval: finestra.prova ? 700 : 3000
        repeat: true
        running: finestra.guidando
        onTriggered: {
            if (finestra.prova) {
                var f = finestra.percorso.forma
                var passo = finestra.mezzo === "piedi" ? 1 : (finestra.mezzo === "bici" ? 2 : 4)
                finestra.indiceProva = Math.min(f.length - 1, finestra.indiceProva + passo)
                var p = { lat: f[finestra.indiceProva][0], lon: f[finestra.indiceProva][1] }
                var prossimo = f[Math.min(f.length - 1, finestra.indiceProva + 1)]
                p.direzione = Math.atan2((prossimo[1] - p.lon) * Math.cos(p.lat * Math.PI / 180), prossimo[0] - p.lat) * 180 / Math.PI
                finestra.qui = p
                finestra.aggiornaGuida(p)
            } else ponte.avvia("posizione", [], "posizioneGuida")
        }
    }
    Connections {
        target: ponte
        function onCompletato(id, r) { if (id === "posizioneGuida" && r && r.lat !== undefined) { finestra.qui = r; finestra.aggiornaGuida(r) } }
    }

    Carta {
        id: carta
        objectName: "carta"
        anchors.fill: parent
        zoom: 6; lat: 42.5; lon: 12.5
        forma: finestra.percorso ? finestra.percorso.forma : []
        posizione: finestra.qui
        segnaposti: {
            var s = []
            if (finestra.luogo) s.push({ id: "luogo", lat: finestra.luogo.lat, lon: finestra.luogo.lon, nome: finestra.luogo.nome, colore: "#EF4444" })
            for (var i = 0; i < finestra.risultati.length; i++)
                s.push({ id: "r" + i, lat: finestra.risultati[i].lat, lon: finestra.risultati[i].lon, nome: "", colore: "#F97316" })
            return s
        }
        onSegnapostoScelto: function (ident) { if (ident.charAt(0) === "r") finestra.scegli(finestra.risultati[parseInt(ident.slice(1))]) }
        onPuntoScelto: function (la, lo) { ponte.avvia("indirizzo", [la, lo], "punto") }
        onSpostataAMano: finestra.seguendo = false
    }

    // ── Pannello di ricerca e indicazioni ──
    Rectangle {
        id: pannello
        visible: !finestra.guidando
        x: 14; y: 14
        width: 360
        height: Math.min(finestra.height - 28, colPannello.implicitHeight + 28)
        radius: 16
        color: Tema.chiaro ? "#F7FFFFFF" : "#F01C1F26"
        border.color: Tema.bordo
        Flickable {
            anchors.fill: parent; anchors.margins: 14
            contentHeight: colPannello.implicitHeight
            clip: true
            ColumnLayout {
                id: colPannello
                width: parent.width
                spacing: 10
                CampoRicerca {
                    id: ricerca
                    Layout.fillWidth: true
                    placeholderText: I18n.t("Cerca un luogo o un indirizzo")
                    onTextChanged: attesaRicerca.restart()
                    Timer { id: attesaRicerca; interval: 500; onTriggered: finestra.cerca(ricerca.text) }
                }
                // risultati
                Repeater {
                    model: finestra.risultati
                    Rectangle {
                        Layout.fillWidth: true
                        height: 50; radius: 10
                        color: sopraR.hovered ? Tema.superficieAlta : "transparent"
                        HoverHandler { id: sopraR }
                        ColumnLayout {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                            spacing: 0
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                Text { visible: modelData.distanza !== undefined; text: modelData.distanza !== undefined ? ponte.chiama("testoDistanza", [modelData.distanza]) : ""; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
                            }
                            Text { text: modelData.dettaglio; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                        MouseArea { anchors.fill: parent; onClicked: finestra.scegli(modelData) }
                    }
                }
                // preferiti e recenti (quando non si cerca e non c'è un luogo)
                ColumnLayout {
                    visible: finestra.risultati.length === 0 && !finestra.luogo
                    Layout.fillWidth: true
                    spacing: 4
                    Text { visible: finestra.salvati.preferiti.length > 0; text: I18n.t("Preferiti"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                    Repeater {
                        model: finestra.salvati.preferiti
                        Text {
                            text: "★  " + (modelData.etichetta ? modelData.etichetta + " · " : "") + modelData.nome
                            color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: finestra.scegli(modelData) }
                        }
                    }
                    Text { visible: finestra.salvati.recenti.length > 0; Layout.topMargin: 6; text: I18n.t("Recenti"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                    Repeater {
                        model: finestra.salvati.recenti.slice(0, 6)
                        Text {
                            text: "🕘  " + modelData.nome
                            color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: finestra.scegli(modelData) }
                        }
                    }
                    Text {
                        visible: finestra.salvati.preferiti.length === 0 && finestra.salvati.recenti.length === 0
                        Layout.fillWidth: true; wrapMode: Text.WordWrap
                        text: I18n.t("Cerca un luogo, oppure tieni premuto un punto della mappa.")
                        color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13
                    }
                }
                // scheda del luogo
                ColumnLayout {
                    visible: !!finestra.luogo && finestra.risultati.length === 0
                    Layout.fillWidth: true
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: finestra.luogo ? finestra.luogo.nome : ""; color: Tema.testo; font.family: Tema.font; font.pixelSize: 20; font.weight: Font.Bold; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        Text {
                            text: "✕"; color: Tema.testoSecondario; font.pixelSize: 16
                            MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: { finestra.luogo = null; finestra.percorso = null } }
                        }
                    }
                    Text { text: finestra.luogo ? finestra.luogo.dettaglio : ""; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                    RowLayout {
                        spacing: 8
                        Pulsante { text: I18n.t("Indicazioni"); principale: true; onClicked: finestra.indicazioni() }
                        Pulsante {
                            text: finestra.salvati.preferiti.some(function (p) { return finestra.luogo && p.lat === finestra.luogo.lat && p.lon === finestra.luogo.lon }) ? "★" : "☆"
                            onClicked: finestra.salvati = ponte.chiama("preferito", [finestra.luogo, ""])
                        }
                        Pulsante { text: I18n.t("Casa"); onClicked: finestra.salvati = ponte.chiama("preferito", [finestra.luogo, I18n.t("Casa")]) }
                        Pulsante { text: I18n.t("Lavoro"); onClicked: finestra.salvati = ponte.chiama("preferito", [finestra.luogo, I18n.t("Lavoro")]) }
                    }
                }
                // percorso
                ColumnLayout {
                    visible: !!finestra.percorso || finestra.calcolo
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle { Layout.fillWidth: true; height: 1; color: Tema.bordo }
                    RowLayout {
                        spacing: 6
                        Repeater {
                            model: [{ id: "auto", t: "🚗 " + I18n.t("Auto") }, { id: "bici", t: "🚲 " + I18n.t("Bici") }, { id: "piedi", t: "🚶 " + I18n.t("A piedi") }]
                            Rectangle {
                                width: testoMezzo.implicitWidth + 20; height: 30; radius: 15
                                color: finestra.mezzo === modelData.id ? Tema.accento : Tema.superficieAlta
                                Text { id: testoMezzo; anchors.centerIn: parent; text: modelData.t; color: finestra.mezzo === modelData.id ? "white" : Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                                MouseArea { anchors.fill: parent; onClicked: { finestra.mezzo = modelData.id; finestra.indicazioni() } }
                            }
                        }
                    }
                    BusyIndicator { visible: finestra.calcolo; running: visible; implicitWidth: 26; implicitHeight: 26 }
                    RowLayout {
                        visible: !!finestra.percorso && !finestra.calcolo
                        Text { text: finestra.percorso ? finestra.percorso.tempo : ""; color: Tema.testo; font.family: Tema.font; font.pixelSize: 24; font.weight: Font.Bold }
                        Text { text: finestra.percorso ? finestra.percorso.distanza + " · " + I18n.t("arrivo alle") + " " + finestra.percorso.arrivo : ""; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13; Layout.leftMargin: 8 }
                    }
                    RowLayout {
                        visible: !!finestra.percorso && !finestra.calcolo
                        spacing: 8
                        Pulsante { text: I18n.t("Avvia"); principale: true; onClicked: finestra.avvia(false) }
                        Pulsante { text: I18n.t("Prova il percorso"); onClicked: finestra.avvia(true) }
                    }
                    Repeater {
                        model: finestra.percorso && !finestra.calcolo ? finestra.percorso.manovre : []
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Text { text: finestra.freccia(modelData.tipo); color: Tema.accento; font.pixelSize: 18; Layout.preferredWidth: 22; horizontalAlignment: Text.AlignHCenter }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 0
                                Text { text: modelData.testo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                Text { visible: modelData.metri > 0; text: ponte.chiama("testoDistanza", [modelData.metri]); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Guida: prossima manovra in alto ──
    Rectangle {
        visible: finestra.guidando && !!finestra.stato
        anchors.horizontalCenter: parent.horizontalCenter
        y: 14
        width: Math.min(640, finestra.width - 28); height: 96
        radius: 18
        color: "#1E3A8A"
        RowLayout {
            anchors.fill: parent; anchors.margins: 16
            spacing: 18
            Text { text: finestra.stato ? finestra.freccia(finestra.stato.manovra.tipo) : ""; color: "white"; font.pixelSize: 46; font.weight: Font.Bold }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Text { text: finestra.stato ? finestra.stato.allaManovra : ""; color: "white"; font.family: Tema.font; font.pixelSize: 26; font.weight: Font.Bold }
                Text { text: finestra.stato ? finestra.stato.manovra.testo : ""; color: "#E0E7FF"; font.family: Tema.font; font.pixelSize: 16; elide: Text.ElideRight; Layout.fillWidth: true }
            }
        }
    }
    // ── Guida: arrivo e comandi in basso ──
    Rectangle {
        visible: finestra.guidando
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 16
        width: Math.min(640, finestra.width - 28); height: 70
        radius: 18
        color: Tema.chiaro ? "#F7FFFFFF" : "#F01C1F26"
        border.color: Tema.bordo
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 12
            spacing: 14
            ColumnLayout {
                spacing: 0
                Text { text: finestra.stato ? finestra.stato.arrivo : ""; color: Tema.testo; font.family: Tema.font; font.pixelSize: 22; font.weight: Font.Bold }
                Text { text: I18n.t("arrivo"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
            }
            ColumnLayout {
                spacing: 0
                Text { text: finestra.stato ? finestra.stato.tempo : ""; color: Tema.testo; font.family: Tema.font; font.pixelSize: 18; font.weight: Font.DemiBold }
                Text { text: finestra.stato ? finestra.stato.resta : ""; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
            }
            Item { Layout.fillWidth: true }
            Pulsante { text: finestra.voce ? "🔊" : "🔇"; onClicked: finestra.voce = !finestra.voce }
            Pulsante { visible: !finestra.seguendo; text: I18n.t("Ricentra"); onClicked: { finestra.seguendo = true; if (finestra.qui) carta.centra(finestra.qui.lat, finestra.qui.lon, 16) } }
            Pulsante { text: I18n.t("Termina"); pericoloso: true; onClicked: finestra.termina() }
        }
    }

    // Dove sono
    Rectangle {
        visible: !finestra.guidando
        anchors.right: parent.right; anchors.rightMargin: 14
        anchors.bottom: parent.bottom; anchors.bottomMargin: 96
        width: 34; height: 34; radius: 8
        color: sopraQui.hovered ? Tema.superficieAlta : Tema.superficie
        border.color: Tema.bordo
        HoverHandler { id: sopraQui }
        Text { anchors.centerIn: parent; text: "➤"; rotation: -45; color: Tema.accento; font.pixelSize: 16 }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (finestra.qui) carta.centra(finestra.qui.lat, finestra.qui.lon, Math.max(carta.zoom, 15))
                ponte.avvia("posizione", [], "posizione")
            }
        }
        ToolTip.visible: sopraQui.hovered; ToolTip.text: I18n.t("Dove sono")
    }
    Messaggio { id: avviso }
}
