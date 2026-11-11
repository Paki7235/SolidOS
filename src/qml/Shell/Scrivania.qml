// Scrivania (come Windows e Mac): sfondo e icone di ~/Scrivania sotto tutte le finestre.
// · clic seleziona, Ctrl/Maiusc+clic o rettangolo trascinando sul vuoto selezionano più icone
// · doppio clic (o Invio) apre; tasto destro: menu con Nuovo ›, Visualizza ›, Ordina per ›, Incolla…
// · le icone si spostano trascinandole (la posizione viene ricordata); su una cartella vi entrano
// · file trascinati da File o da altre app: spostati (stesso disco) o copiati qui
// · Canc cestino · F2 rinomina · Ctrl+A/C/X/V · Esc deseleziona
import QtQuick
import QtQuick.Controls
import QtQuick.Window
import org.kde.layershell 1.0 as LayerShell
import SolidUI

Window {
    id: scrivania
    property string sfondo: shell.chiama0("sfondo")
    property var elementi: shell.chiama0("scrivania")
    property var conf: shell.chiama0("scrivaniaImpostazioni")
    property var scelti: ({})
    property string ultimo: ""
    property string inRinomina: ""
    property var menuVoci: []
    property var trascinati: []            // icone della scrivania che si stanno trascinando
    property string afferrata: ""          // l'icona presa con il mouse
    property var cellaDiArrivo: null       // dove mettere i file appena arrivati
    property bool tagliati: false
    property var ultimaPressione: ({ percorso: "", t: 0 })
    property bool cestinoPieno: shell.chiama0("cestinoPieno")
    // tema chiaro/scuro: si passa alla versione dello sfondo adatta
    property bool temaChiaro: Tema.chiaro
    onTemaChiaroChanged: sfondo = shell.chiama0("sfondo") + "?" + Date.now()

    // ── Griglia ──────────────────────────────────────────────────────────────
    readonly property int lato: conf.lato || 52
    readonly property int cellaL: lato + 44
    readonly property int cellaA: lato + 54
    readonly property bool stileWindows: Tema.stileBarra === "windows"
    readonly property int margineAlto: stileWindows ? 12 : 40
    readonly property int margineBasso: stileWindows ? (Tema.dockLato || 48) + 12 : (Tema.dockLato || 48) + 44
    readonly property int righe: Math.max(1, Math.floor((height - margineAlto - margineBasso) / cellaA))
    readonly property int colonne: Math.max(1, Math.floor((width - 24) / cellaL))
    readonly property var disposti: disponi(elementi, conf, righe, colonne)

    function chiave(e) { return e.sistema ? e.percorso : e.percorso.split("/").pop() }
    function ordinati(arr, modo) {
        var c = arr.slice()
        c.sort(function (a, b) {
            if (!!a.sistema !== !!b.sistema) return a.sistema ? -1 : 1
            if (a.collegamento !== b.collegamento) return a.collegamento ? -1 : 1
            if (a.cartella !== b.cartella) return a.cartella ? -1 : 1
            var r = 0
            if (modo === "data") r = b.data - a.data
            else if (modo === "dimensione") r = b.dimensione - a.dimensione
            else if (modo === "tipo") r = (a.tipo || "").localeCompare(b.tipo || "")
            return r !== 0 ? r : a.nome.toLowerCase().localeCompare(b.nome.toLowerCase())
        })
        return c
    }
    // Posizione di ogni icona: quella salvata se libera, altrimenti la prima libera
    // dall'alto a sinistra, colonna per colonna (come Windows).
    function disponi(arr, cf, nR, nC) {
        var pos = cf.posizioni || {}, occupate = {}, out = [], liberi = []
        var lista = ordinati(arr, cf.ordina)
        lista.forEach(function (e) {
            var p = pos[chiave(e)]
            if (p && p[0] < nC && p[1] < nR && !occupate[p[0] + ":" + p[1]]) {
                occupate[p[0] + ":" + p[1]] = true
                out.push({ e: e, c: p[0], r: p[1] })
            } else liberi.push(e)
        })
        var c = 0, r = 0
        liberi.forEach(function (e) {
            while (occupate[c + ":" + r] && c < nC) { r++; if (r >= nR) { r = 0; c++ } }
            occupate[c + ":" + r] = true
            out.push({ e: e, c: Math.min(c, nC - 1), r: r })
        })
        return out
    }
    function xDi(c) { return 12 + c * cellaL }
    function yDi(r) { return margineAlto + r * cellaA }
    function cellaIn(x, y) {
        return [Math.max(0, Math.min(colonne - 1, Math.floor((x - 12) / cellaL))),
                Math.max(0, Math.min(righe - 1, Math.floor((y - margineAlto) / cellaA)))]
    }
    function salvaPosizioni(nuove) {
        var pos = Object.assign({}, conf.posizioni || {})
        for (var k in nuove) pos[k] = nuove[k]
        conf = shell.chiama("scrivaniaSalva", [{ posizioni: pos }])
    }
    function salva(cambi) { conf = shell.chiama("scrivaniaSalva", [cambi]) }

    function aggiorna() {
        elementi = shell.chiama0("scrivania")
        // file appena arrivati: messi dove sono stati lasciati
        if (cellaDiArrivo && cellaDiArrivo.nomi.length) {
            var nuove = {}, occ = {}, col = cellaDiArrivo.c, riga = cellaDiArrivo.r
            disposti.forEach(function (d) { if (cellaDiArrivo.nomi.indexOf(chiave(d.e)) < 0) occ[d.c + ":" + d.r] = true })
            cellaDiArrivo.nomi.forEach(function (n) {
                while (occ[col + ":" + riga] && col < colonne) { riga++; if (riga >= righe) { riga = 0; col++ } }
                occ[col + ":" + riga] = true
                nuove[n] = [Math.min(col, colonne - 1), riga]
            })
            cellaDiArrivo = null
            salvaPosizioni(nuove)
        }
    }
    function selezionati() { return elementi.filter(function (e) { return scelti[e.percorso] }) }
    function percorsiFile() { return selezionati().filter(function (e) { return !e.sistema }).map(function (e) { return e.percorso }) }
    function seleziona(e, mod) {
        var n = {}
        if (mod & Qt.ControlModifier) { n = Object.assign({}, scelti); if (n[e.percorso]) delete n[e.percorso]; else n[e.percorso] = true }
        else if ((mod & Qt.ShiftModifier) && ultimo) {
            var ord = disposti.slice().sort(function (a, b) { return a.c - b.c || a.r - b.r })
            var i1 = ord.findIndex(function (d) { return d.e.percorso === ultimo }), i2 = ord.findIndex(function (d) { return d.e.percorso === e.percorso })
            for (var i = Math.min(i1, i2); i <= Math.max(i1, i2); i++) if (i >= 0) n[ord[i].e.percorso] = true
        } else n[e.percorso] = true
        scelti = n; ultimo = e.percorso
    }
    function apriSelezionati() { selezionati().forEach(function (e) { shell.chiama("scrivaniaApri", [e.percorso]) }) }
    function cestina() { var p = percorsiFile(); if (p.length) { shell.chiama("scrivaniaCestino", [p]); scelti = ({}) } }
    function copia(taglia) { var p = percorsiFile(); if (p.length) { shell.chiama("appuntiCopia", [p, taglia]); tagliati = taglia } }
    function incolla(x, y) {
        var a = shell.chiama0("appunti")
        if (!a.uri || !a.uri.length) return
        var cella = cellaIn(x !== undefined ? x : 24, y !== undefined ? y : margineAlto + 10)
        cellaDiArrivo = { c: cella[0], r: cella[1], nomi: a.uri.map(function (u) { return decodeURIComponent(u.split("/").pop()) }) }
        tagliati = a.taglia
        shell.avvia("scrivaniaTrasferisci", [a.uri, "", a.taglia ? "sposta" : "copia"], "scrivania-op")
    }
    function apriMenu(voci, x, y) {
        menuVoci = voci
        menu.x = Math.max(6, Math.min(x, width - menu.width - 8))
        menu.y = Math.max(6, Math.min(y, height - menu.height - 8))
        menu.visible = true
        Qt.callLater(function () { menu.y = Math.max(6, Math.min(y, scrivania.height - menu.height - 8)) })
    }

    // ── Menu ─────────────────────────────────────────────────────────────────
    function menuSfondo(x, y) {
        var s = conf.sistema || {}
        function lato(l, t) { return { t: t, spunta: scrivania.lato === l, f: function () { scrivania.salva({ lato: l }) } } }
        function ord(k, t) { return { t: t, spunta: conf.ordina === k, f: function () { scrivania.salva({ ordina: k, posizioni: {} }) } } }
        function sis(k, t) { return { t: t, spunta: !!s[k], f: function () { var o = {}; o[k] = !s[k]; scrivania.salva({ sistema: o }) } } }
        var pieni = shell.chiama0("appunti").uri.length > 0
        apriMenu([
            { t: I18n.t("Visualizza"), sotto: [lato(72, I18n.t("Icone grandi")), lato(52, I18n.t("Icone medie")), lato(36, I18n.t("Icone piccole")), { sep: true },
                                               { t: I18n.t("Mostra le icone della scrivania"), spunta: conf.mostra !== false, f: function () { scrivania.salva({ mostra: conf.mostra === false }) } },
                                               { sep: true }, sis("home", I18n.t("Icona Home")), sis("computer", I18n.t("Icona Computer")), sis("cestino", I18n.t("Icona Cestino"))] },
            { t: I18n.t("Ordina per"), sotto: [ord("nome", I18n.t("Nome")), ord("data", I18n.t("Data di modifica")), ord("tipo", I18n.t("Tipo")), ord("dimensione", I18n.t("Dimensione"))] },
            { t: I18n.t("Aggiorna"), f: function () { scrivania.aggiorna() } },
            { sep: true },
            { t: I18n.t("Incolla") + "    Ctrl+V", disattiva: !pieni, f: function () { scrivania.incolla(x, y) } },
            { t: I18n.t("Nuovo"), sotto: [
                { t: I18n.t("Cartella"), f: function () { scrivania.nuovo("cartella", x, y) } },
                { t: I18n.t("Documento di testo"), f: function () { scrivania.nuovo("testo", x, y) } },
                { sep: true },
                { t: I18n.t("Collegamento a un'app…"), f: function () { shell.chiama0("mostraStart") } }] },
            { sep: true },
            { t: I18n.t("Apri nel terminale"), f: function () { shell.chiama("scrivaniaAzione", ["terminale", [shell.chiama0("scrivaniaCartella")]]) } },
            { t: I18n.t("Apri la Scrivania in File"), f: function () { shell.chiama("scrivaniaAzione", ["cartella", ["x"]]) } },
            { sep: true },
            { t: I18n.t("Cambia sfondo…"), f: function () { shell.chiama("apri", ["impostazioni", "aspetto"]) } },
            { t: I18n.t("Barra e Dock…"), f: function () { shell.chiama("apri", ["impostazioni", "pannello"]) } },
            { t: I18n.t("Impostazioni schermo…"), f: function () { shell.chiama("apri", ["impostazioni", "schermo"]) } }
        ], x, y)
    }
    function menuIcona(e, x, y) {
        if (!scelti[e.percorso]) { var n = {}; n[e.percorso] = true; scelti = n; ultimo = e.percorso }
        var sel = selezionati(), multi = sel.length > 1, p = percorsiFile()
        function az(a) { return function () { shell.chiama("scrivaniaAzione", [a, p]) } }
        var v = [{ t: I18n.t("Apri"), f: function () { scrivania.apriSelezionati() } }]
        if (e.sistema && !multi) {
            if (e.percorso === "cestino:") v.push({ t: I18n.t("Svuota il cestino…"), f: function () { shell.chiama0("cestinoSvuota") } })
            v.push({ sep: true })
            var k = e.percorso === "home:" ? "home" : (e.percorso === "computer:" ? "computer" : "cestino")
            v.push({ t: I18n.t("Togli dalla scrivania"), f: function () { var o = {}; o[k] = false; scrivania.salva({ sistema: o }) } })
            apriMenu(v, x, y); return
        }
        if (e.collegamento && !multi) {
            v.push({ sep: true })
            v.push({ t: I18n.t("Rinomina") + "    F2", f: function () { scrivania.inRinomina = e.percorso } })
            v.push({ t: I18n.t("Togli dalla scrivania"), f: function () { scrivania.cestina() } })
            apriMenu(v, x, y); return
        }
        if (!multi && !e.cartella) v.push({ t: I18n.t("Apri con…"), f: az("apricon") })
        v.push({ sep: true })
        v.push({ t: I18n.t("Taglia") + "    Ctrl+X", f: function () { scrivania.copia(true) } })
        v.push({ t: I18n.t("Copia") + "    Ctrl+C", f: function () { scrivania.copia(false) } })
        if (!multi) v.push({ t: I18n.t("Rinomina") + "    F2", f: function () { scrivania.inRinomina = e.percorso } })
        v.push({ sep: true })
        if (!multi && /\.(zip|tar|gz|tgz|bz2|xz|7z|rar)$/i.test(e.percorso)) v.push({ t: I18n.t("Estrai qui"), f: az("estrai") })
        else v.push({ t: I18n.t("Comprimi (zip)"), f: az("comprimi") })
        if (sel.some(function (x) { return !x.cartella && !/\.pdf$/i.test(x.percorso) })) v.push({ t: I18n.t("Converti in PDF"), f: az("pdf") })
        v.push({ t: I18n.t("Condividi…"), f: az("condividi") })
        if (!multi && e.cartella) v.push({ t: I18n.t("Apri nel terminale"), f: az("terminale") })
        v.push({ sep: true })
        v.push({ t: I18n.t("Sposta nel cestino") + "    Canc", f: function () { scrivania.cestina() } })
        if (!multi) { v.push({ sep: true }); v.push({ t: I18n.t("Proprietà"), f: az("proprieta") }) }
        apriMenu(v, x, y)
    }
    function nuovo(tipo, x, y) {
        var p = shell.chiama("scrivaniaNuova", [tipo])
        if (!p) return
        var cella = cellaIn(x, y), o = {}
        o[p.split("/").pop()] = cella
        // se la cella è occupata la nuova icona va nella prima libera
        if (disposti.some(function (d) { return d.c === cella[0] && d.r === cella[1] })) o = {}
        salvaPosizioni(o)
        aggiorna()
        inRinomina = p
        var n = {}; n[p] = true; scelti = n
    }

    LayerShell.Window.scope: "scrivania"
    LayerShell.Window.layer: LayerShell.Window.LayerBackground
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
    color: "#0B0E18"
    visible: true

    Connections {
        target: shell
        function onEvento(nome, dati) {
            if (nome === "sfondo") scrivania.sfondo = shell.chiama0("sfondo") + "?" + Date.now()
            else if (nome === "scrivania") scrivania.aggiorna()
            else if (nome === "cestino") scrivania.cestinoPieno = shell.chiama0("cestinoPieno")
        }
        function onCompletato(id, r) {
            if (id !== "scrivania-op") return
            if (scrivania.tagliati && r.ok) { shell.chiama0("appuntiSvuota"); scrivania.tagliati = false }
            if (r.nuovi && scrivania.cellaDiArrivo) scrivania.cellaDiArrivo.nomi = r.nuovi.map(function (u) { return decodeURIComponent(u.split("/").pop()) })
            scrivania.aggiorna()
        }
    }

    Image {
        anchors.fill: parent
        source: scrivania.sfondo
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: Screen.width
        sourceSize.height: Screen.height
        asynchronous: true
        cache: false
    }

    // Sul vuoto: clic deseleziona, trascinando si seleziona con un rettangolo, tasto destro menu
    MouseArea {
        id: vuoto
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        property point inizio
        property rect rettangolo: Qt.rect(0, 0, 0, 0)
        property bool attivo: false
        property var base: ({})
        onPressed: function (ev) {
            menu.visible = false
            scrivania.inRinomina = ""
            inizio = Qt.point(ev.x, ev.y)
            base = (ev.modifiers & Qt.ControlModifier) ? Object.assign({}, scrivania.scelti) : ({})
            if (ev.button === Qt.LeftButton && !(ev.modifiers & Qt.ControlModifier)) scrivania.scelti = ({})
            if (ev.button === Qt.RightButton) scrivania.menuSfondo(ev.x, ev.y)
        }
        onPositionChanged: function (ev) {
            if (!(ev.buttons & Qt.LeftButton)) return
            if (!attivo && Math.abs(ev.x - inizio.x) + Math.abs(ev.y - inizio.y) < 6) return
            attivo = true
            rettangolo = Qt.rect(Math.min(inizio.x, ev.x), Math.min(inizio.y, ev.y), Math.abs(ev.x - inizio.x), Math.abs(ev.y - inizio.y))
            var n = Object.assign({}, base)
            scrivania.disposti.forEach(function (d) {
                var x = scrivania.xDi(d.c), y = scrivania.yDi(d.r)
                if (x < rettangolo.x + rettangolo.width && x + scrivania.cellaL > rettangolo.x && y < rettangolo.y + rettangolo.height && y + scrivania.cellaA > rettangolo.y)
                    n[d.e.percorso] = true
            })
            scrivania.scelti = n
        }
        onReleased: attivo = false
        onCanceled: attivo = false
    }

    // File lasciati sulla scrivania
    DropArea {
        anchors.fill: parent
        onDropped: function (d) {
            if (!d.hasUrls) return
            var cella = scrivania.cellaIn(d.x, d.y)
            if (scrivania.trascinati.length) {
                // icone della scrivania spostate: si ricordano le nuove posizioni (relative a quella afferrata)
                var rif = scrivania.disposti.find(function (x) { return x.e.percorso === scrivania.afferrata })
                var nuove = {}
                scrivania.disposti.forEach(function (x) {
                    if (scrivania.trascinati.indexOf(x.e.percorso) < 0 || !rif) return
                    nuove[scrivania.chiave(x.e)] = [Math.max(0, Math.min(scrivania.colonne - 1, cella[0] + x.c - rif.c)),
                                                     Math.max(0, Math.min(scrivania.righe - 1, cella[1] + x.r - rif.r))]
                })
                // le icone che erano già lì si spostano dove c'era quella afferrata (scambio)
                if (rif) scrivania.disposti.forEach(function (x) {
                    if (scrivania.trascinati.indexOf(x.e.percorso) < 0 && x.c === cella[0] && x.r === cella[1]) nuove[scrivania.chiave(x.e)] = [rif.c, rif.r]
                })
                scrivania.salvaPosizioni(nuove)
                scrivania.trascinati = []
                d.acceptProposedAction()
                return
            }
            var u = Array.prototype.map.call(d.urls, function (x) { return x.toString() })
            scrivania.cellaDiArrivo = { c: cella[0], r: cella[1], nomi: u.map(function (x) { return decodeURIComponent(x.split("/").pop()) }) }
            var modo = (d.modifiers & Qt.ControlModifier) ? "copia" : ((d.modifiers & Qt.ShiftModifier) ? "sposta" : "auto")
            shell.avvia("scrivaniaTrasferisci", [u, "", modo], "scrivania-op")
            d.acceptProposedAction()
        }
    }

    // ── Icone ────────────────────────────────────────────────────────────────
    Repeater {
        model: scrivania.disposti
        Item {
            id: icona
            required property var modelData
            readonly property var e: modelData.e
            readonly property bool selezionata: !!scrivania.scelti[e.percorso]
            x: scrivania.xDi(modelData.c)
            y: scrivania.yDi(modelData.r)
            width: scrivania.cellaL - 4
            height: scrivania.cellaA - 4
            Behavior on x { enabled: Tema.animazioni; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on y { enabled: Tema.animazioni; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            opacity: scrivania.trascinati.indexOf(e.percorso) >= 0 && area.drag.active ? 0.5 : 1

            Item { id: fantasma }
            Drag.active: area.drag.active
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
            Drag.mimeData: { "text/uri-list": (icona.selezionata ? scrivania.selezionati() : [icona.e]).map(function (x) { return x.uri }).join("\r\n") }
            Drag.onDragFinished: function (azione) { scrivania.trascinati = []; fantasma.x = 0; fantasma.y = 0 }

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: dropCartella.containsDrag ? "#55FFFFFF" : (icona.selezionata ? "#40" + Tema.accento.substring(1) : (area.containsMouse ? "#1FFFFFFF" : "transparent"))
                border.color: icona.selezionata || dropCartella.containsDrag ? "#80FFFFFF" : "transparent"
            }
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 6
                width: scrivania.lato; height: scrivania.lato
                fillMode: Image.PreserveAspectFit
                sourceSize.width: scrivania.lato * 2; sourceSize.height: scrivania.lato * 2
                source: icona.e.anteprima || ("image://icona/" + (icona.e.percorso === "cestino:" && scrivania.cestinoPieno ? "user-trash-full" : icona.e.icona))
                asynchronous: true
            }
            // freccina dei collegamenti alle app (come Windows)
            Rectangle {
                visible: !!icona.e.collegamento
                x: (icona.width - scrivania.lato) / 2 - 2; y: 6 + scrivania.lato - 14
                width: 16; height: 16; radius: 4
                color: "#F2FFFFFF"
                Text { anchors.centerIn: parent; text: "↗"; color: "#1D1D1F"; font.pixelSize: 11; font.weight: Font.Bold }
            }
            Text {
                visible: scrivania.inRinomina !== icona.e.percorso
                anchors.horizontalCenter: parent.horizontalCenter
                y: scrivania.lato + 12
                width: parent.width - 6
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: icona.selezionata ? 4 : 2
                elide: Text.ElideRight
                text: icona.e.nome
                // nomi leggibili su ogni sfondo: scuri col tema chiaro, chiari col tema scuro
                color: Tema.chiaro ? "#1D1D1F" : "#FFFFFF"
                style: Text.Raised; styleColor: Tema.chiaro ? "#B3FFFFFF" : "#B3000000"
                font.family: Tema.font; font.pixelSize: 12
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                drag.target: scrivania.inRinomina === icona.e.percorso ? null : fantasma
                drag.threshold: 10
                drag.onActiveChanged: if (drag.active) {
                    scrivania.afferrata = icona.e.percorso
                    scrivania.trascinati = icona.selezionata ? scrivania.selezionati().map(function (x) { return x.percorso }) : [icona.e.percorso]
                }
                // Tutto avviene alla pressione del tasto: sullo sfondo del desktop il rilascio
                // può non arrivare, quindi doppio clic e menu non aspettano il «clic completo».
                onPressed: function (ev) {
                    menu.visible = false
                    if (ev.button === Qt.RightButton) {
                        var p = icona.mapToItem(scrivania.contentItem, ev.x, ev.y)
                        scrivania.menuIcona(icona.e, p.x, p.y)
                        return
                    }
                    var adesso = Date.now()
                    if (scrivania.ultimaPressione.percorso === icona.e.percorso && adesso - scrivania.ultimaPressione.t < 500) {
                        scrivania.ultimaPressione = { percorso: "", t: 0 }
                        shell.chiama("scrivaniaApri", [icona.e.percorso])
                        return
                    }
                    scrivania.ultimaPressione = { percorso: icona.e.percorso, t: adesso }
                    if (ev.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) scrivania.seleziona(icona.e, ev.modifiers)
                    else if (!icona.selezionata) { var n = {}; n[icona.e.percorso] = true; scrivania.scelti = n; scrivania.ultimo = icona.e.percorso }
                }
                onReleased: { fantasma.x = 0; fantasma.y = 0 }
            }
            // Cartelle e Cestino: ci si possono lasciare sopra file e icone
            DropArea {
                id: dropCartella
                anchors.fill: parent
                enabled: icona.e.cartella && icona.e.percorso !== "home:" && icona.e.percorso !== "computer:" && scrivania.trascinati.indexOf(icona.e.percorso) < 0
                onDropped: function (d) {
                    if (!d.hasUrls) return
                    var u = Array.prototype.map.call(d.urls, function (x) { return x.toString() })
                    if (icona.e.percorso === "cestino:") shell.chiama("cestinoSposta", [u])
                    else shell.avvia("scrivaniaTrasferisci", [u, icona.e.percorso, (d.modifiers & Qt.ControlModifier) ? "copia" : "auto"], "scrivania-op")
                    scrivania.trascinati = []
                    d.acceptProposedAction()
                }
            }
            // Rinomina sul posto
            CampoTesto {
                visible: scrivania.inRinomina === icona.e.percorso
                onVisibleChanged: if (visible) { text = icona.e.nome; forceActiveFocus(); var p = text.lastIndexOf("."); select(0, p > 0 && !icona.e.cartella ? p : text.length) }
                y: scrivania.lato + 10
                width: parent.width
                font.pixelSize: 12
                onAccepted: {
                    var vecchio = icona.e.percorso.split("/").pop(), nuovoNome = text.trim()
                    if (shell.chiama("scrivaniaRinomina", [icona.e.percorso, text])) {
                        var pos = Object.assign({}, scrivania.conf.posizioni || {})
                        if (pos[vecchio]) { pos[nuovoNome] = pos[vecchio]; delete pos[vecchio]; scrivania.salva({ posizioni: pos }) }
                    }
                    scrivania.inRinomina = ""
                }
                Keys.onEscapePressed: scrivania.inRinomina = ""
            }
        }
    }

    // Rettangolo di selezione
    Rectangle {
        visible: vuoto.attivo
        x: vuoto.rettangolo.x; y: vuoto.rettangolo.y
        width: vuoto.rettangolo.width; height: vuoto.rettangolo.height
        color: "#33" + Tema.accento.substring(1)
        border.color: Tema.accento
    }

    // Tastiera (quando la scrivania è in primo piano)
    Shortcut { sequences: [StandardKey.Delete]; enabled: !scrivania.inRinomina; onActivated: scrivania.cestina() }
    Shortcut { sequence: "F2"; onActivated: { var s = scrivania.selezionati(); if (s.length === 1 && !s[0].sistema) scrivania.inRinomina = s[0].percorso } }
    Shortcut { sequence: "Return"; enabled: !scrivania.inRinomina; onActivated: scrivania.apriSelezionati() }
    Shortcut { sequences: [StandardKey.SelectAll]; enabled: !scrivania.inRinomina; onActivated: { var n = {}; scrivania.elementi.forEach(function (e) { n[e.percorso] = true }); scrivania.scelti = n } }
    Shortcut { sequences: [StandardKey.Copy]; enabled: !scrivania.inRinomina; onActivated: scrivania.copia(false) }
    Shortcut { sequences: [StandardKey.Cut]; enabled: !scrivania.inRinomina; onActivated: scrivania.copia(true) }
    Shortcut { sequences: [StandardKey.Paste]; enabled: !scrivania.inRinomina; onActivated: scrivania.incolla() }
    Shortcut { sequence: "Escape"; onActivated: { menu.visible = false; scrivania.scelti = ({}); scrivania.inRinomina = "" } }
    Shortcut { sequence: "F5"; onActivated: scrivania.aggiorna() }

    MenuPopup {
        id: menu
        visible: false
        voci: scrivania.menuVoci
        onScelto: visible = false
    }
}
