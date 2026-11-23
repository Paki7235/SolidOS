// Mappe: la carta di SolidOS a tutta finestra e, a sinistra, un pannello per cercare (anche per
// categoria: ristoranti, benzina, farmacie…), vedere la scheda del luogo (orari, telefono, sito),
// chiedere le indicazioni (auto, bici, a piedi, mezzi pubblici; tappe; evita pedaggi, autostrade,
// traghetti; percorsi alternativi) e partire. Durante la guida: manovra e quella dopo in alto,
// limite di velocità e via attuale, arrivo e tempo in basso, voce, mappa che gira col percorso.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Mappe")
    width: 1200
    height: 780
    minimumWidth: 780
    minimumHeight: 540

    property var qui: null                 // la mia posizione {lat, lon, precisione, direzione}
    property var risultati: []
    property string categoria: ""          // categoria cercata (chip)
    property bool cercando: false
    property var luogo: null               // luogo scelto (con i dettagli quando arrivano)
    property var partenza: null            // null = la mia posizione
    property var tappe: []
    property string modoCerca: "luogo"     // luogo | partenza | tappa
    property var percorsi: []              // percorso migliore + alternative
    property int scelto: 0
    readonly property var percorso: percorsi.length ? percorsi[Math.min(scelto, percorsi.length - 1)] : null
    property string mezzo: "auto"
    property var opzioni: ({ pedaggi: true, autostrade: true, traghetti: true })   // true = si possono usare
    property bool calcolo: false
    property bool mostraIndicazioni: false
    property var salvati: ({ preferiti: [], recenti: [] })
    property var categorie: []
    // guida
    property bool guidando: false
    property bool prova: false
    property var stato: null
    property int indiceProva: 0
    property bool voce: true
    property bool ruota: true              // la mappa gira con la direzione di marcia
    property string ultimoAnnuncio: ""
    property bool seguendo: true
    // mappe senza rete
    property var scarica: ({ attivo: false, fatte: 0, totale: 0 })
    property string spazio: ""
    // ogni richiesta ha un numero: le risposte arrivate tardi (di richieste superate) si ignorano
    property int nRicerca: 0
    property int nPercorso: 0

    function dove() { return qui ? qui : { lat: carta.lat, lon: carta.lon } }
    function cerca(t) {
        categoria = ""
        if (t.length < 2) { risultati = []; return }
        cercando = true
        var p = dove()
        nRicerca++
        ponte.avvia("cerca", [t, p.lat, p.lon], "cerca:" + nRicerca)
    }
    function cercaCategoria(c) {
        categoria = c.id; luogo = null; percorsi = []; cercando = true; ricerca.text = ""
        nRicerca++
        ponte.avvia("vicini", [c.id, carta.lat, carta.lon], "vicini:" + nRicerca)
    }
    function scegli(l) {
        if (modoCerca === "partenza") { partenza = l; modoCerca = "luogo"; risultati = []; ricerca.text = ""; indicazioni(); return }
        if (modoCerca === "tappa") { tappe = tappe.concat([l]); modoCerca = "luogo"; risultati = []; ricerca.text = ""; indicazioni(); return }
        nRicerca++; cercando = false
        luogo = l; percorsi = []; risultati = []; categoria = ""; mostraIndicazioni = false
        carta.centra(l.lat, l.lon, Math.max(carta.zoom, 16))
        ponte.chiama("ricorda", [l]); salvati = ponte.chiama0("salvati")
        if (l.osm) ponte.avvia("dettagli", [l], "dettagli")
    }
    function indicazioni() {
        if (!luogo) return
        var da = partenza || qui
        if (!da) { avviso.mostra(I18n.t("Non so ancora dove sei: scegli da dove partire")); modoCerca = "partenza"; ricerca.forceActiveFocus(); return }
        calcolo = true; scelto = 0
        nPercorso++
        var tp = mezzo === "mezzi" ? [] : tappe.map(function (t) { return { lat: t.lat, lon: t.lon } })
        ponte.avvia("percorso", [{ lat: da.lat, lon: da.lon }, { lat: luogo.lat, lon: luogo.lon }, mezzo, opzioni, tp], "percorso:" + nPercorso)
    }
    function scegliPercorso(i) { scelto = i; ponte.chiama("scegliPercorso", [percorsi[i]]); carta.inquadra(percorsi[i].forma) }
    function avvia(simulata) {
        if (!percorso || mezzo === "mezzi") return
        prova = simulata; guidando = true; seguendo = true; indiceProva = 0; ultimoAnnuncio = ""
        carta.zoom = 16
        aggiornaGuida(simulata ? { lat: percorso.forma[0][0], lon: percorso.forma[0][1] } : qui)
    }
    function termina() { guidando = false; prova = false; stato = null; carta.fattoFino = 0; if (percorso) carta.inquadra(percorso.forma) }
    function aggiornaGuida(pos) {
        if (!pos) return
        var g = ponte.chiama("guida", [pos.lat, pos.lon, stato ? stato.indice : 0])
        if (!g.ok) return
        stato = g
        carta.fattoFino = g.indice
        if (seguendo) carta.centra(pos.lat, pos.lon)
        if (g.arrivato) { if (voce) ponte.chiama("parla", [I18n.t("Sei arrivato")]); avviso.mostra(I18n.t("Sei arrivato a destinazione")); termina(); return }
        if (g.fuori && !prova) { avviso.mostra(I18n.t("Fuori percorso: ricalcolo…")); partenza = null; qui = pos; indicazioni(); return }
        var chiave = g.manovra.inizio + (g.metriAllaManovra < 60 ? "-ora" : (g.metriAllaManovra < 320 ? "-presto" : ""))
        if (voce && chiave !== ultimoAnnuncio && g.metriAllaManovra < 320) {
            ultimoAnnuncio = chiave
            ponte.chiama("parla", [g.metriAllaManovra < 60 ? g.manovra.testo : I18n.t("Tra") + " " + g.allaManovra + ", " + g.manovra.annuncio])
        }
    }
    function freccia(tipo) {
        if ([4, 5, 6].indexOf(tipo) >= 0) return "⚑"
        if ([9, 18, 20, 23].indexOf(tipo) >= 0) return "↗"
        if (tipo === 10) return "→"
        if (tipo === 11) return "↘"
        if ([12, 13].indexOf(tipo) >= 0) return "↶"
        if (tipo === 14) return "↙"
        if (tipo === 15) return "←"
        if ([16, 19, 21, 24].indexOf(tipo) >= 0) return "↖"
        if ([26, 27].indexOf(tipo) >= 0) return "⟳"
        return "↑"
    }
    function simboloMezzo(m) {
        return ({ WALK: "🚶", BUS: "🚌", TRAM: "🚋", SUBWAY: "🚇", METRO: "🚇", RAIL: "🚆", REGIONAL_RAIL: "🚆", HIGHSPEED_RAIL: "🚄",
                  LONG_DISTANCE: "🚆", SUBURBAN: "🚆", FERRY: "⛴", COACH: "🚌", FUNICULAR: "🚞", CABLE_CAR: "🚡", AERIAL_LIFT: "🚡" })[m] || "🚏"
    }
    function zonaVisibile() {
        return [carta.latDa(carta.cy + carta.height / 2), carta.lonDa(carta.cx - carta.width / 2),
                carta.latDa(carta.cy - carta.height / 2), carta.lonDa(carta.cx + carta.width / 2)]
    }

    Connections {
        target: ponte
        function onCompletato(id, r) {
            var parti = id.split(":")
            if (parti.length === 2) {
                if ((parti[0] === "cerca" || parti[0] === "vicini") && parseInt(parti[1]) !== finestra.nRicerca) return
                if (parti[0] === "percorso" && parseInt(parti[1]) !== finestra.nPercorso) return
                id = parti[0]
            }
            if (id === "posizione" || id === "posizioneGuida") {
                if (!r || r.lat === undefined) return
                if (finestra.qui && finestra.qui.lat !== undefined && r.direzione === undefined) {
                    var d = Math.abs(r.lat - finestra.qui.lat) + Math.abs(r.lon - finestra.qui.lon)
                    if (d > 0.00005) r.direzione = Math.atan2((r.lon - finestra.qui.lon) * Math.cos(r.lat * Math.PI / 180), r.lat - finestra.qui.lat) * 180 / Math.PI
                }
                finestra.qui = r
                if (id === "posizioneGuida") finestra.aggiornaGuida(r)
                else if (!finestra.luogo && !finestra.guidando) carta.centra(r.lat, r.lon, r.fonte === "ip" ? 12 : 15)
            } else if (id === "cerca" || id === "vicini") {
                finestra.cercando = false
                finestra.risultati = r || []
                if (id === "vicini" && !r.length) avviso.mostra(I18n.t("Niente di questo tipo qui vicino"))
            } else if (id === "dettagli") {
                if (finestra.luogo && r && Math.abs(r.lat - finestra.luogo.lat) < 0.01) finestra.luogo = r
            } else if (id === "percorso") {
                finestra.calcolo = false
                if (!r.ok) { avviso.mostra(r.messaggio); finestra.percorsi = []; return }
                finestra.percorsi = [r].concat(r.alternative || [])
                if (!finestra.guidando) carta.inquadra(r.forma)
            } else if (id === "punto") finestra.scegli(r)
        }
    }
    Component.onCompleted: {
        salvati = ponte.chiama0("salvati")
        categorie = ponte.chiama0("categorie")
        spazio = ponte.chiama0("spazioMappe")
        ponte.avvia("posizione", [], "posizione")
    }

    // posizione durante la guida; «Prova il percorso» scorre lungo il percorso a velocità realistica
    Timer {
        interval: finestra.prova ? 700 : 3000
        repeat: true
        running: finestra.guidando
        onTriggered: {
            if (finestra.prova) {
                var f = finestra.percorso.forma
                finestra.indiceProva = Math.min(f.length - 1, finestra.indiceProva + (finestra.mezzo === "piedi" ? 1 : (finestra.mezzo === "bici" ? 2 : 4)))
                var p = { lat: f[finestra.indiceProva][0], lon: f[finestra.indiceProva][1] }
                var s = f[Math.min(f.length - 1, finestra.indiceProva + 2)]
                if (s[0] !== p.lat || s[1] !== p.lon)
                    p.direzione = Math.atan2((s[1] - p.lon) * Math.cos(p.lat * Math.PI / 180), s[0] - p.lat) * 180 / Math.PI
                else if (finestra.qui) p.direzione = finestra.qui.direzione
                finestra.qui = p
                finestra.aggiornaGuida(p)
            } else ponte.avvia("posizione", [], "posizioneGuida")
        }
    }
    Timer {
        interval: 800; repeat: true; running: finestra.scarica.attivo
        onTriggered: {
            finestra.scarica = ponte.chiama0("statoScarica")
            if (!finestra.scarica.attivo) { finestra.spazio = ponte.chiama0("spazioMappe"); avviso.mostra(I18n.t("Zona scaricata: la mappa si vede anche senza rete")) }
        }
    }

    // ── La carta (gira con la direzione di marcia durante la guida) ──
    Item {
        anchors.fill: parent
        clip: true
        readonly property bool gira: finestra.guidando && finestra.ruota && !!finestra.qui && finestra.qui.direzione !== undefined && finestra.seguendo
        Carta {
            id: carta
            objectName: "carta"
            anchors.centerIn: parent
            width: parent.gira ? Math.hypot(parent.width, parent.height) : parent.width
            height: parent.gira ? Math.hypot(parent.width, parent.height) : parent.height
            rotation: parent.gira ? -finestra.qui.direzione : 0
            Behavior on rotation { enabled: Tema.animazioni; RotationAnimation { duration: 600; direction: RotationAnimation.Shortest } }
            zoom: 6; lat: 42.5; lon: 12.5
            forma: finestra.percorso ? finestra.percorso.forma : []
            altre: finestra.guidando ? [] : finestra.percorsi.filter(function (x, i) { return i !== finestra.scelto }).map(function (x) { return x.forma })
            posizione: finestra.qui
            segnaposti: {
                var s = []
                if (finestra.luogo) s.push({ id: "luogo", lat: finestra.luogo.lat, lon: finestra.luogo.lon, nome: finestra.luogo.nome, colore: "#EF4444" })
                if (finestra.partenza) s.push({ id: "partenza", lat: finestra.partenza.lat, lon: finestra.partenza.lon, nome: "", colore: "#22C55E" })
                for (var t = 0; t < finestra.tappe.length; t++) s.push({ id: "t" + t, lat: finestra.tappe[t].lat, lon: finestra.tappe[t].lon, nome: "", colore: "#A855F7" })
                for (var i = 0; i < finestra.risultati.length; i++)
                    s.push({ id: "r" + i, lat: finestra.risultati[i].lat, lon: finestra.risultati[i].lon, nome: finestra.categoria ? finestra.risultati[i].nome : "", colore: "#F97316" })
                return s
            }
            onSegnapostoScelto: function (ident) { if (ident.charAt(0) === "r") finestra.scegli(finestra.risultati[parseInt(ident.slice(1))]) }
            onPuntoScelto: function (la, lo) { ponte.avvia("indirizzo", [la, lo], "punto") }
            onSpostataAMano: finestra.seguendo = false
        }
    }

    // ── Pannello ──
    Rectangle {
        id: pannello
        visible: !finestra.guidando
        x: 14; y: 14
        width: 380
        height: Math.min(finestra.height - 28, colPannello.implicitHeight + 28)
        radius: 16
        color: Tema.chiaro ? "#F7FFFFFF" : "#F21C1F26"
        border.color: Tema.bordo
        Flickable {
            anchors.fill: parent; anchors.margins: 14
            contentHeight: colPannello.implicitHeight
            clip: true
            ScrollBar.vertical: ScrollBar {}
            ColumnLayout {
                id: colPannello
                width: parent.width - 6
                spacing: 10

                // modo di ricerca: partenza o tappa
                RowLayout {
                    visible: finestra.modoCerca !== "luogo"
                    Layout.fillWidth: true
                    Text {
                        text: finestra.modoCerca === "partenza" ? I18n.t("Da dove parti?") : I18n.t("Aggiungi una tappa")
                        color: Tema.accento; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.fillWidth: true
                    }
                    Text {
                        text: I18n.t("Annulla"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { finestra.modoCerca = "luogo"; finestra.risultati = []; ricerca.text = "" } }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    CampoRicerca {
                        id: ricerca
                        Layout.fillWidth: true
                        placeholderText: finestra.modoCerca === "luogo" ? I18n.t("Cerca un luogo o un indirizzo") : I18n.t("Cerca o tieni premuto sulla mappa")
                        onTextChanged: attesaRicerca.restart()
                        Timer { id: attesaRicerca; interval: 450; onTriggered: finestra.cerca(ricerca.text) }
                    }
                    BusyIndicator { visible: finestra.cercando; running: visible; implicitWidth: 22; implicitHeight: 22 }
                }
                Pulsante {
                    visible: finestra.modoCerca === "partenza"
                    text: "➤ " + I18n.t("La mia posizione")
                    onClicked: { finestra.partenza = null; finestra.modoCerca = "luogo"; finestra.indicazioni() }
                }

                // categorie vicine
                Flow {
                    visible: !finestra.luogo && finestra.modoCerca === "luogo" && !ricerca.text
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: finestra.categorie
                        Rectangle {
                            width: testoCat.implicitWidth + 22; height: 30; radius: 15
                            color: finestra.categoria === modelData.id ? Tema.accento : Tema.superficieAlta
                            Text { id: testoCat; anchors.centerIn: parent; text: modelData.simbolo + "  " + modelData.nome; color: finestra.categoria === modelData.id ? "white" : Tema.testo; font.family: Tema.font; font.pixelSize: 12 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: finestra.cercaCategoria(modelData) }
                        }
                    }
                }

                // risultati
                Text {
                    visible: finestra.categoria !== "" && finestra.risultati.length > 0
                    text: I18n.t("Nella zona che vedi, dal più vicino")
                    color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                }
                Repeater {
                    model: finestra.risultati
                    Rectangle {
                        Layout.fillWidth: true
                        height: 56; radius: 10
                        color: sopraR.hovered ? Tema.superficieAlta : "transparent"
                        HoverHandler { id: sopraR }
                        ColumnLayout {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                            spacing: 1
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                Text { visible: modelData.distanza !== undefined; text: modelData.distanza !== undefined ? ponte.chiama("testoDistanza", [modelData.distanza]) : ""; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    visible: modelData.aperto === true || modelData.aperto === false
                                    text: modelData.aperto ? I18n.t("Aperto") : I18n.t("Chiuso")
                                    color: modelData.aperto ? "#16A34A" : "#DC2626"; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold
                                }
                                Text { text: modelData.dettaglio || ""; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: finestra.scegli(modelData) }
                    }
                }

                // preferiti, recenti, mappe senza rete
                ColumnLayout {
                    visible: finestra.risultati.length === 0 && !finestra.luogo && finestra.modoCerca === "luogo" && !ricerca.text
                    Layout.fillWidth: true
                    spacing: 4
                    Text { visible: finestra.salvati.preferiti.length > 0; Layout.topMargin: 4; text: I18n.t("Preferiti"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                    Repeater {
                        model: finestra.salvati.preferiti
                        Text {
                            text: (modelData.etichetta === I18n.t("Casa") ? "🏠  " : (modelData.etichetta === I18n.t("Lavoro") ? "💼  " : "★  ")) + (modelData.etichetta ? modelData.etichetta + " · " : "") + modelData.nome
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
                    Rectangle { Layout.fillWidth: true; Layout.topMargin: 8; height: 1; color: Tema.bordo }
                    Text { Layout.topMargin: 4; text: I18n.t("Mappe senza rete"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                    Text {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap
                        text: I18n.t("Scarica la zona che vedi: la mappa si vedrà anche senza internet (per cercare e calcolare i percorsi la rete serve ancora).")
                        color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                    }
                    BarraProgresso { visible: finestra.scarica.attivo; Layout.fillWidth: true; from: 0; to: Math.max(1, finestra.scarica.totale); value: finestra.scarica.fatte }
                    RowLayout {
                        Layout.fillWidth: true
                        Pulsante {
                            text: finestra.scarica.attivo ? I18n.t("Scaricamento…") : I18n.t("Scarica questa zona")
                            enabled: !finestra.scarica.attivo
                            onClicked: {
                                var z = finestra.zonaVisibile()
                                var r = ponte.chiama("scaricaZona", z)
                                if (r.ok === false) avviso.mostra(r.messaggio); else finestra.scarica = r
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Text { text: finestra.spazio; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                        Text {
                            text: I18n.t("Svuota"); color: Tema.accento; font.family: Tema.font; font.pixelSize: 12
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ponte.chiama0("cancellaMappe"); finestra.spazio = ponte.chiama0("spazioMappe") } }
                        }
                    }
                }

                // ── Scheda del luogo ──
                ColumnLayout {
                    visible: !!finestra.luogo && finestra.risultati.length === 0 && finestra.modoCerca === "luogo"
                    Layout.fillWidth: true
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: finestra.luogo ? finestra.luogo.nome : ""; color: Tema.testo; font.family: Tema.font; font.pixelSize: 21; font.weight: Font.Bold; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        Text {
                            text: "✕"; color: Tema.testoSecondario; font.pixelSize: 16
                            MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: { finestra.luogo = null; finestra.percorsi = []; finestra.tappe = []; finestra.partenza = null } }
                        }
                    }
                    RowLayout {
                        spacing: 8
                        Text {
                            visible: !!finestra.luogo && (finestra.luogo.aperto === true || finestra.luogo.aperto === false)
                            text: finestra.luogo && finestra.luogo.aperto ? I18n.t("Aperto ora") : I18n.t("Chiuso ora")
                            color: finestra.luogo && finestra.luogo.aperto ? "#16A34A" : "#DC2626"; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold
                        }
                        Text { text: finestra.luogo && finestra.luogo.cucina ? finestra.luogo.cucina : ""; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13 }
                    }
                    Text { text: finestra.luogo ? (finestra.luogo.indirizzo || finestra.luogo.dettaglio || "") : ""; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                    // azioni
                    RowLayout {
                        Layout.topMargin: 4
                        spacing: 6
                        Pulsante { text: I18n.t("Indicazioni"); principale: true; onClicked: finestra.indicazioni() }
                        Pulsante {
                            text: finestra.salvati.preferiti.some(function (p) { return finestra.luogo && p.lat === finestra.luogo.lat && p.lon === finestra.luogo.lon }) ? "★ " + I18n.t("Salvato") : "☆ " + I18n.t("Salva")
                            onClicked: finestra.salvati = ponte.chiama("preferito", [finestra.luogo, ""])
                        }
                        Pulsante {
                            text: I18n.t("Condividi")
                            onClicked: { ponte.chiama("copia", [ponte.chiama("collegamento", [finestra.luogo.lat, finestra.luogo.lon])]); avviso.mostra(I18n.t("Collegamento copiato: incollalo dove vuoi")) }
                        }
                    }
                    // informazioni
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        Layout.preferredHeight: infoCol.implicitHeight + 16
                        visible: !!finestra.luogo && !!(finestra.luogo.orari || finestra.luogo.telefono || finestra.luogo.sito)
                        radius: 12; color: Tema.superficie; border.color: Tema.bordo
                        ColumnLayout {
                            id: infoCol
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10
                            spacing: 8
                            ColumnLayout {
                                visible: !!(finestra.luogo && finestra.luogo.orari)
                                spacing: 1
                                Text { text: I18n.t("Orari"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
                                Text { text: finestra.luogo ? (finestra.luogo.orari || "") : ""; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                            }
                            ColumnLayout {
                                visible: !!(finestra.luogo && finestra.luogo.telefono)
                                spacing: 1
                                Text { text: I18n.t("Telefono"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
                                Text {
                                    text: finestra.luogo ? (finestra.luogo.telefono || "") : ""; color: Tema.accento; font.family: Tema.font; font.pixelSize: 13
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ponte.chiama("apri", ["tel:" + finestra.luogo.telefono.replace(/\s/g, "")]) }
                                }
                            }
                            ColumnLayout {
                                visible: !!(finestra.luogo && finestra.luogo.sito)
                                spacing: 1
                                Text { text: I18n.t("Sito"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
                                Text {
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                    text: finestra.luogo ? (finestra.luogo.sito || "").replace(/^https?:\/\//, "") : ""; color: Tema.accento; font.family: Tema.font; font.pixelSize: 13
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ponte.chiama("apri", [finestra.luogo.sito]) }
                                }
                            }
                        }
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: "🏠 " + I18n.t("Imposta come Casa"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { finestra.salvati = ponte.chiama("preferito", [finestra.luogo, I18n.t("Casa")]); avviso.mostra(I18n.t("Salvato come Casa")) } }
                        }
                        Text { text: "·"; color: Tema.testoSecondario }
                        Text {
                            text: "💼 " + I18n.t("come Lavoro"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { finestra.salvati = ponte.chiama("preferito", [finestra.luogo, I18n.t("Lavoro")]); avviso.mostra(I18n.t("Salvato come Lavoro")) } }
                        }
                        Text { text: "·"; color: Tema.testoSecondario }
                        Text {
                            text: I18n.t("Copia coordinate"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ponte.chiama("copia", [finestra.luogo.lat.toFixed(6) + ", " + finestra.luogo.lon.toFixed(6)]); avviso.mostra(I18n.t("Coordinate copiate")) } }
                        }
                    }
                }

                // ── Indicazioni ──
                ColumnLayout {
                    visible: (finestra.percorsi.length > 0 || finestra.calcolo) && finestra.modoCerca === "luogo"
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle { Layout.fillWidth: true; height: 1; color: Tema.bordo }
                    // da / tappe / a
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "●"; color: "#22C55E"; font.pixelSize: 12 }
                        Text { text: I18n.t("Da") + ": " + (finestra.partenza ? finestra.partenza.nome : I18n.t("La mia posizione")); color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text {
                            text: I18n.t("Cambia"); color: Tema.accento; font.family: Tema.font; font.pixelSize: 12
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { finestra.modoCerca = "partenza"; ricerca.forceActiveFocus() } }
                        }
                    }
                    Repeater {
                        model: finestra.mezzo === "mezzi" ? [] : finestra.tappe
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "●"; color: "#A855F7"; font.pixelSize: 12 }
                            Text { text: I18n.t("Tappa") + ": " + modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text {
                                text: "✕"; color: Tema.testoSecondario; font.pixelSize: 12
                                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: { var t = finestra.tappe.slice(); t.splice(index, 1); finestra.tappe = t; finestra.indicazioni() } }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "●"; color: "#EF4444"; font.pixelSize: 12 }
                        Text { text: I18n.t("A") + ": " + (finestra.luogo ? finestra.luogo.nome : ""); color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text {
                            visible: finestra.mezzo !== "mezzi"
                            text: "+ " + I18n.t("Tappa"); color: Tema.accento; font.family: Tema.font; font.pixelSize: 12
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { finestra.modoCerca = "tappa"; ricerca.forceActiveFocus() } }
                        }
                    }
                    // mezzo
                    RowLayout {
                        spacing: 6
                        Repeater {
                            model: [{ id: "auto", t: "🚗 " + I18n.t("Auto") }, { id: "mezzi", t: "🚆 " + I18n.t("Mezzi") }, { id: "bici", t: "🚲 " + I18n.t("Bici") }, { id: "piedi", t: "🚶 " + I18n.t("A piedi") }]
                            Rectangle {
                                width: testoMezzo.implicitWidth + 18; height: 30; radius: 15
                                color: finestra.mezzo === modelData.id ? Tema.accento : Tema.superficieAlta
                                Text { id: testoMezzo; anchors.centerIn: parent; text: modelData.t; color: finestra.mezzo === modelData.id ? "white" : Tema.testo; font.family: Tema.font; font.pixelSize: 12 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { finestra.mezzo = modelData.id; finestra.indicazioni() } }
                            }
                        }
                    }
                    // opzioni (auto)
                    ColumnLayout {
                        visible: finestra.mezzo === "auto"
                        Layout.fillWidth: true
                        spacing: 2
                        Repeater {
                            model: [{ k: "pedaggi", t: I18n.t("Evita pedaggi") }, { k: "autostrade", t: I18n.t("Evita autostrade") }, { k: "traghetti", t: I18n.t("Evita traghetti") }]
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: modelData.t; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; Layout.fillWidth: true }
                                Interruttore {
                                    checked: finestra.opzioni[modelData.k] === false
                                    onToggled: { var o = Object.assign({}, finestra.opzioni); o[modelData.k] = !checked; finestra.opzioni = o; finestra.indicazioni() }
                                }
                            }
                        }
                    }
                    BusyIndicator { visible: finestra.calcolo; running: visible; implicitWidth: 26; implicitHeight: 26 }

                    // percorsi (migliore e alternative) o soluzioni con i mezzi
                    Repeater {
                        model: finestra.calcolo ? [] : finestra.percorsi
                        Rectangle {
                            id: schedaRett
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredHeight: schedaPerc.implicitHeight + 18
                            radius: 12
                            color: index === finestra.scelto ? (Tema.chiaro ? "#E8EFFE" : "#1E2A44") : Tema.superficie
                            border.color: index === finestra.scelto ? Tema.accento : Tema.bordo
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: finestra.scegliPercorso(schedaRett.index) }
                            ColumnLayout {
                                id: schedaPerc
                                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10
                                spacing: 4
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: schedaRett.modelData.tempo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 20; font.weight: Font.Bold }
                                    Text {
                                        text: schedaRett.modelData.mezzo === "mezzi" ? schedaRett.modelData.parte + " – " + schedaRett.modelData.arrivo
                                              : schedaRett.modelData.distanza + " · " + I18n.t("arrivo") + " " + schedaRett.modelData.arrivo
                                        color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight
                                    }
                                }
                                Text {
                                    visible: schedaRett.modelData.mezzo !== "mezzi"
                                    text: (schedaRett.index === 0 ? I18n.t("Il più veloce") : I18n.t("Alternativa"))
                                          + (schedaRett.modelData.pedaggi ? " · " + I18n.t("pedaggi") : "")
                                          + (schedaRett.modelData.autostrade ? " · " + I18n.t("autostrade") : "")
                                          + (schedaRett.modelData.traghetti ? " · " + I18n.t("traghetto") : "")
                                    color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                                }
                                Flow {
                                    visible: schedaRett.modelData.mezzo === "mezzi"
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Repeater {
                                        model: schedaRett.modelData.tratti || []
                                        Rectangle {
                                            visible: modelData.mezzo !== "WALK" || modelData.minuti > 0
                                            height: 22; radius: 6; width: tTratto.implicitWidth + 12
                                            color: modelData.mezzo === "WALK" ? "transparent" : modelData.colore
                                            Text {
                                                id: tTratto; anchors.centerIn: parent
                                                text: finestra.simboloMezzo(modelData.mezzo) + (modelData.linea ? " " + modelData.linea : "") + (modelData.mezzo === "WALK" ? " " + modelData.minuti + "′" : "")
                                                color: modelData.mezzo === "WALK" ? Tema.testoSecondario : "white"; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold
                                            }
                                        }
                                    }
                                }
                                // dettaglio dei mezzi per la soluzione scelta
                                ColumnLayout {
                                    visible: schedaRett.modelData.mezzo === "mezzi" && schedaRett.index === finestra.scelto
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Repeater {
                                        model: schedaRett.modelData.tratti || []
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0
                                            Text {
                                                text: modelData.parte + "  " + finestra.simboloMezzo(modelData.mezzo) + "  " + (modelData.mezzo === "WALK" ? I18n.t("A piedi") + " " + modelData.minuti + " min" : modelData.nome + " " + modelData.linea + (modelData.direzione ? " → " + modelData.direzione : ""))
                                                color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; font.weight: modelData.mezzo === "WALK" ? Font.Normal : Font.DemiBold; wrapMode: Text.WordWrap; Layout.fillWidth: true
                                            }
                                            Text {
                                                visible: modelData.mezzo !== "WALK"
                                                text: I18n.t("da") + " " + modelData.da + " " + I18n.t("a") + " " + modelData.a + " · " + modelData.fermate + " " + I18n.t("fermate") + (modelData.azienda ? " · " + modelData.azienda : "")
                                                color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    RowLayout {
                        visible: !!finestra.percorso && !finestra.calcolo && finestra.mezzo !== "mezzi"
                        spacing: 8
                        Pulsante { text: I18n.t("Avvia"); principale: true; onClicked: finestra.avvia(false) }
                        Pulsante { text: I18n.t("Prova il percorso"); onClicked: finestra.avvia(true) }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: finestra.mostraIndicazioni ? I18n.t("Nascondi passi") : I18n.t("Tutti i passi")
                            color: Tema.accento; font.family: Tema.font; font.pixelSize: 12
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: finestra.mostraIndicazioni = !finestra.mostraIndicazioni }
                        }
                    }
                    Repeater {
                        model: finestra.mostraIndicazioni && finestra.percorso && !finestra.calcolo ? finestra.percorso.manovre : []
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

    // ── Guida: manovra (e quella dopo) in alto ──
    Column {
        visible: finestra.guidando && !!finestra.stato
        anchors.horizontalCenter: parent.horizontalCenter
        y: 14
        spacing: 0
        Rectangle {
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
        Rectangle {
            visible: !!(finestra.stato && finestra.stato.dopo)
            x: 18
            width: testoDopo.implicitWidth + 28; height: 34
            radius: 10
            color: "#172E6E"
            Text {
                id: testoDopo
                anchors.centerIn: parent
                text: finestra.stato && finestra.stato.dopo ? I18n.t("Poi") + "  " + finestra.freccia(finestra.stato.dopo.tipo) + "  " + (finestra.stato.dopo.via || finestra.stato.dopo.testo) : ""
                color: "#E0E7FF"; font.family: Tema.font; font.pixelSize: 13
            }
        }
    }
    // limite di velocità (cartello)
    Rectangle {
        visible: finestra.guidando && !!finestra.stato && finestra.stato.limite > 0
        anchors.left: parent.left; anchors.leftMargin: 20
        anchors.bottom: parent.bottom; anchors.bottomMargin: 110
        width: 64; height: 64; radius: 32
        color: "white"
        border.color: "#DC2626"; border.width: 7
        Text { anchors.centerIn: parent; text: finestra.stato ? finestra.stato.limite : ""; color: "#111111"; font.family: Tema.font; font.pixelSize: 22; font.weight: Font.Bold }
    }
    // ── Guida: via, arrivo e comandi in basso ──
    Rectangle {
        visible: finestra.guidando
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 16
        width: Math.min(760, finestra.width - 28); height: 78
        radius: 18
        color: Tema.chiaro ? "#F7FFFFFF" : "#F21C1F26"
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
            Text {
                Layout.fillWidth: true
                text: finestra.stato && finestra.stato.via ? finestra.stato.via : ""
                color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.Medium
                elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
            }
            Pulsante { text: finestra.voce ? "🔊" : "🔇"; onClicked: finestra.voce = !finestra.voce }
            Pulsante { text: finestra.ruota ? "🧭" : "⬆"; onClicked: finestra.ruota = !finestra.ruota }
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
