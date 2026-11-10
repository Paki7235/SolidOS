// File: gestore dei file di SolidOS.
// Doppio clic apre · tasto destro menu · Ctrl+C/X/V copia/taglia/incolla · Canc cestino
// F2 rinomina · Ctrl+A tutto · Ctrl+H file nascosti · Alt+← → cronologia · Ctrl+L indirizzo
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
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
    // Visualizzazione (ricordata tra un'apertura e l'altra)
    property string ordina: "nome"          // nome · data · dimensione · tipo
    property bool crescente: true
    property int latoIcone: 52              // 32 piccole · 52 medie · 80 grandi
    property bool dettagli: false           // riquadro dei dettagli a destra (Alt+P)
    property var avanzamento: null          // {fatti, totale, nome} durante copie lunghe
    readonly property var voci: ordinate(risultati !== null ? risultati : dati.voci)
    readonly property var elencoScelti: voci.filter(function (v) { return scelti[v.uri] })

    Settings {
        category: "vista"
        property alias griglia: finestra.griglia
        property alias ordina: finestra.ordina
        property alias crescente: finestra.crescente
        property alias latoIcone: finestra.latoIcone
        property alias dettagli: finestra.dettagli
    }

    function ordinate(arr) {
        var c = (arr || []).slice(), chiave = ordina, verso = crescente ? 1 : -1
        c.sort(function (a, b) {
            if (a.cartella !== b.cartella) return a.cartella ? -1 : 1
            var r = 0
            if (chiave === "data") r = (a.ordinaData || 0) - (b.ordinaData || 0)
            else if (chiave === "dimensione") r = (a.dimensione || 0) - (b.dimensione || 0)
            else if (chiave === "tipo") r = (a.tipo || "").localeCompare(b.tipo || "")
            if (r === 0) r = a.nome.toLowerCase().localeCompare(b.nome.toLowerCase())
            return r * verso
        })
        return c
    }
    function cambiaOrdine(k) { if (ordina === k) crescente = !crescente; else { ordina = k; crescente = k === "nome" || k === "tipo" } }
    function vociOrdina() {
        function v(k, t) { return { t: t, spunta: finestra.ordina === k, f: function () { finestra.cambiaOrdine(k) } } }
        return [v("nome", I18n.t("Nome")), v("data", I18n.t("Data di modifica")), v("dimensione", I18n.t("Dimensione")), v("tipo", I18n.t("Tipo")),
                { sep: true },
                { t: I18n.t("Crescente"), spunta: finestra.crescente, f: function () { finestra.crescente = true } },
                { t: I18n.t("Decrescente"), spunta: !finestra.crescente, f: function () { finestra.crescente = false } }]
    }
    function vociVista() {
        function g(l, t) { return { t: t, spunta: finestra.griglia && finestra.latoIcone === l, f: function () { finestra.griglia = true; finestra.latoIcone = l } } }
        return [g(80, I18n.t("Icone grandi")), g(52, I18n.t("Icone medie")), g(32, I18n.t("Icone piccole")),
                { t: I18n.t("Dettagli (elenco)"), spunta: !finestra.griglia, f: function () { finestra.griglia = false } },
                { sep: true },
                { t: I18n.t("Riquadro dei dettagli") + "    Alt+P", spunta: finestra.dettagli, f: function () { finestra.dettagli = !finestra.dettagli } },
                { t: I18n.t("File nascosti") + "    Ctrl+H", spunta: finestra.nascosti, f: function () { finestra.nascosti = !finestra.nascosti; finestra.ricarica() } }]
    }
    function vociNuovo() {
        return [{ t: I18n.t("Cartella") + "    Ctrl+Maiusc+N", f: function () { finestra.nuovaCartella() } },
                { t: I18n.t("Documento di testo"), f: function () { var r = ponte.chiama("nuovoFile", [finestra.uri, I18n.t("Nuovo documento") + ".txt"]); finestra.esito(r); if (r.ok) finestra.inRinomina = r.uri } }]
    }
    function nuovaCartella() { var r = ponte.chiama("nuovaCartella", [finestra.uri]); finestra.esito(r); if (r.ok) finestra.inRinomina = r.uri }
    // Trascinare o incollare: «auto» come Windows (stesso disco = sposta, altro disco = copia)
    function trasferisci(u, dest, modo) {
        if (!u.length || finestra.dati.cestino) return
        finestra.caricamento = true
        ponte.avvia("trasferisci", [u, dest, modo], "operazione")
    }
    function modoDa(mod) { return (mod & Qt.ControlModifier) ? "copia" : ((mod & Qt.ShiftModifier) ? "sposta" : "auto") }

    function vai(u, daStoria) {
        if (!u) return
        caricamento = true; risultati = null; ricerca = ""; campoCerca.text = ""
        ponte.avvia("elenco", [u, nascosti], "elenco:" + u)
        if (!daStoria) { storia = storia.slice(0, posizione + 1).concat([u]); posizione = storia.length - 1 }
        uri = u; scelti = ({}); ultimoScelto = -1; inRinomina = ""
    }
    function ricarica() { ponte.avvia("elenco", [uri, nascosti], "elenco:" + uri) }
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
    property bool tagliati: false
    function incolla() {
        var a = ponte.chiama0("appunti")
        if (!a.uri || !a.uri.length) { finestra.avviso(I18n.t("Negli appunti non ci sono file")); return }
        tagliati = a.taglia
        trasferisci(a.uri, uri, a.taglia ? "sposta" : "copia")
    }
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
            { t: I18n.t("Visualizza"), sotto: vociVista() },
            { t: I18n.t("Ordina per"), sotto: vociOrdina() },
            { t: I18n.t("Aggiorna") + "    F5", f: function () { finestra.ricarica() } },
            { sep: true },
            { t: I18n.t("Incolla") + "    Ctrl+V", disattiva: !ponte.chiama0("appuntiPieni"), f: function () { finestra.incolla() } },
            { t: I18n.t("Nuovo"), sotto: vociNuovo() },
            { sep: true },
            { t: I18n.t("Apri nel terminale"), f: function () { ponte.chiama("terminaleQui", [finestra.uri]) } },
            { t: I18n.t("Aggiungi ai Preferiti"), f: function () { ponte.chiama("aggiungiSegnalibro", [finestra.uri]); finestra.luoghi = ponte.chiama0("luoghi") } },
            { sep: true },
            { t: I18n.t("Proprietà"), f: function () { proprieta.apri(finestra.uri) } }]
        menu.mostra(voci, x, y)
    }

    Component.onCompleted: {
        luoghi = ponte.chiama0("luoghi")
        ponte.chiama0("osservaVolumi")
        vai(ponte.chiama0("iniziale"), false)
        var r = ponte.chiama0("richiesta")
        if (r === "svuota") svuota.open()
        else if (r === "proprieta") Qt.callLater(function () { proprieta.apri(ponte.chiama0("bersaglio") || finestra.uri) })
    }
    // Tornando alla finestra si rilegge solo la cartella (in background, senza bloccare)
    onActiveChanged: if (active && uri && !caricamento) ricarica()
    Connections {
        target: ponte
        function onEvento(nome, d) {
            if (nome === "avanzamento") finestra.avanzamento = (d.totale > 0 && d.fatti < d.totale) ? d : null
            else if (nome === "luoghi") finestra.luoghi = ponte.chiama0("luoghi")
        }
        function onCompletato(id, r) {
            if (id === "elenco:" + finestra.uri) {
                finestra.caricamento = false
                if (r.ok) finestra.dati = r
                else if (r.montare) collega.apri(finestra.uri, "")
                else { finestra.dati = { voci: [], briciole: [], titolo: "" }; finestra.avviso(r.errore) }
            } else if (id === "operazione") {
                finestra.caricamento = false; finestra.avanzamento = null
                if (finestra.tagliati && r.ok) { ponte.chiama0("svuotaAppunti"); finestra.tagliati = false }
                var testo = r.ok ? (r.spostati && !r.copiati ? r.spostati + " " + I18n.t("spostati") : (r.copiati ? r.copiati + " " + I18n.t("copiati") : I18n.t("Fatto"))) : ""
                finestra.esito(r, r.fatti === 0 && r.ok ? "" : testo)
            }
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
    Shortcut { sequence: "Ctrl+Shift+N"; onActivated: finestra.nuovaCartella() }
    Shortcut { sequence: "Alt+P"; onActivated: finestra.dettagli = !finestra.dettagli }
    Shortcut { sequence: "Alt+Return"; onActivated: proprieta.apri(finestra.elencoScelti.length === 1 ? finestra.elencoScelti[0].uri : finestra.uri) }
    Shortcut { sequence: "Backspace"; onActivated: if (finestra.posizione > 0 && !finestra.inRinomina) { finestra.posizione--; finestra.vai(finestra.storia[finestra.posizione], true) } }
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
                                selezionata: finestra.uri === modelData.uri || dropLuogo.containsDrag
                                onClicked: modelData.uri.indexOf("volume:") === 0 ? (finestra.caricamento = true, ponte.avvia("collega", [modelData.uri, "", "", ""], "collega")) : finestra.vai(modelData.uri, false)
                            }
                            // File trascinati su un luogo: spostati/copiati lì (sul Cestino: nel cestino)
                            DropArea {
                                id: dropLuogo
                                anchors.fill: parent
                                enabled: modelData.uri.indexOf("volume:") !== 0 && modelData.uri !== "network:///" && modelData.uri !== "file:///"
                                onDropped: function (d) {
                                    if (!d.hasUrls) return
                                    var u = Array.prototype.map.call(d.urls, function (x) { return x.toString() })
                                    if (modelData.uri.indexOf("trash:") === 0) finestra.esito(ponte.chiama("cestino", [u]), I18n.t("Spostato nel cestino"))
                                    else finestra.trasferisci(u, modelData.uri, finestra.modoDa(d.modifiers))
                                    d.acceptProposedAction()
                                }
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
                    CampoRicerca {
                        id: campoCerca
                        Layout.preferredWidth: 190
                        placeholderText: I18n.t("Cerca qui")
                        onAccepted: if (text.length > 0) { finestra.caricamento = true; ponte.avvia("cerca", [finestra.uri, text], "cerca") }
                        onTextChanged: if (text.length === 0) finestra.risultati = null
                    }
                }
            }
            // Barra dei comandi: Nuovo, Taglia, Copia, Incolla, Rinomina, Condividi, Elimina, Ordina, Visualizza
            Rectangle {
                visible: !finestra.dati.cestino
                Layout.fillWidth: true
                implicitHeight: 40
                color: Tema.chiaro ? "#F6F6F9" : Tema.superficie
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Tema.chiaro ? "#12000000" : "#40000000" }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 10
                    spacing: 2
                    Comando { id: cmdNuovo; icona: "list-add-symbolic"; testo: I18n.t("Nuovo"); freccia: true; onPremuto: { var p = cmdNuovo.mapToItem(finestra.contentItem, 0, cmdNuovo.height + 4); menu.mostra(finestra.vociNuovo(), p.x, p.y) } }
                    Rectangle { width: 1; height: 22; anchors.verticalCenter: parent.verticalCenter; color: Tema.chiaro ? "#1A000000" : "#1FFFFFFF" }
                    Comando { icona: "edit-cut-symbolic"; suggerimento: I18n.t("Taglia") + " (Ctrl+X)"; attivo: finestra.elencoScelti.length > 0; onPremuto: ponte.chiama("copia", [finestra.uriScelti(), true]) }
                    Comando { icona: "edit-copy-symbolic"; suggerimento: I18n.t("Copia") + " (Ctrl+C)"; attivo: finestra.elencoScelti.length > 0; onPremuto: ponte.chiama("copia", [finestra.uriScelti(), false]) }
                    Comando { icona: "edit-paste-symbolic"; suggerimento: I18n.t("Incolla") + " (Ctrl+V)"; onPremuto: finestra.incolla() }
                    Comando { icona: "edit-rename-symbolic"; suggerimento: I18n.t("Rinomina") + " (F2)"; attivo: finestra.elencoScelti.length === 1; onPremuto: finestra.inRinomina = finestra.elencoScelti[0].uri }
                    Comando { icona: "emblem-shared-symbolic"; suggerimento: I18n.t("Condividi"); attivo: finestra.elencoScelti.length > 0; onPremuto: ponte.chiama("condividi", [finestra.uriScelti()]) }
                    Comando { icona: "user-trash-symbolic"; suggerimento: I18n.t("Sposta nel cestino") + " (Canc)"; attivo: finestra.elencoScelti.length > 0; onPremuto: finestra.cestina() }
                    Rectangle { width: 1; height: 22; anchors.verticalCenter: parent.verticalCenter; color: Tema.chiaro ? "#1A000000" : "#1FFFFFFF" }
                    Comando { id: cmdOrdina; icona: "view-sort-ascending-symbolic"; testo: I18n.t("Ordina"); freccia: true; onPremuto: { var p = cmdOrdina.mapToItem(finestra.contentItem, 0, cmdOrdina.height + 4); menu.mostra(finestra.vociOrdina(), p.x, p.y) } }
                    Comando { id: cmdVista; icona: finestra.griglia ? "view-grid-symbolic" : "view-list-symbolic"; testo: I18n.t("Visualizza"); freccia: true; onPremuto: { var p = cmdVista.mapToItem(finestra.contentItem, 0, cmdVista.height + 4); menu.mostra(finestra.vociVista(), p.x, p.y) } }
                }
                Comando {
                    anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                    icona: "view-reveal-symbolic"; testo: I18n.t("Dettagli"); acceso: finestra.dettagli
                    onPremuto: finestra.dettagli = !finestra.dettagli
                }
            }
            BarraProgresso { Layout.fillWidth: true; Layout.preferredHeight: 2; indeterminate: true; visible: finestra.caricamento && !finestra.avanzamento }
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

            // Vista dei file (+ riquadro dei dettagli a destra)
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0
            Item {
                id: areaVista
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                readonly property int cellaL: finestra.latoIcone + 56
                readonly property int cellaA: finestra.latoIcone + 60
                property rect rettangolo: Qt.rect(0, 0, 0, 0)
                property bool selezionando: false
                // Selezione a rettangolo: trascinando sul vuoto si selezionano più file
                function selezionaRettangolo(base) {
                    var r = rettangolo, n = Object.assign({}, base)
                    for (var i = 0; i < finestra.voci.length; i++) {
                        var x, y, w, h
                        if (finestra.griglia) {
                            var col = Math.max(1, Math.floor(vistaGriglia.width / vistaGriglia.cellWidth))
                            x = 10 + (i % col) * vistaGriglia.cellWidth; y = 10 + Math.floor(i / col) * vistaGriglia.cellHeight - vistaGriglia.contentY
                            w = vistaGriglia.cellWidth - 4; h = vistaGriglia.cellHeight - 4
                        } else {
                            x = 0; y = 28 + i * 30 - vistaElenco.contentY - vistaElenco.originY; w = Math.min(vistaElenco.width, 420); h = 30
                        }
                        if (x < r.x + r.width && x + w > r.x && y < r.y + r.height && y + h > r.y) n[finestra.voci[i].uri] = true
                    }
                    finestra.scelti = n
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    property point inizio
                    property var base: ({})
                    onPressed: function (ev) {
                        if (ev.button !== Qt.LeftButton) return
                        inizio = Qt.point(ev.x, ev.y)
                        base = (ev.modifiers & Qt.ControlModifier) ? Object.assign({}, finestra.scelti) : ({})
                        finestra.inRinomina = ""
                    }
                    onPositionChanged: function (ev) {
                        if (!pressed || !(ev.buttons & Qt.LeftButton)) return
                        if (!areaVista.selezionando && Math.abs(ev.x - inizio.x) + Math.abs(ev.y - inizio.y) < 6) return
                        areaVista.selezionando = true
                        areaVista.rettangolo = Qt.rect(Math.min(inizio.x, ev.x), Math.min(inizio.y, ev.y), Math.abs(ev.x - inizio.x), Math.abs(ev.y - inizio.y))
                        areaVista.selezionaRettangolo(base)
                    }
                    onReleased: areaVista.selezionando = false
                    onClicked: function (ev) {
                        if (areaVista.rettangolo.width > 0) { areaVista.rettangolo = Qt.rect(0, 0, 0, 0); return }
                        finestra.scelti = ({}); finestra.inRinomina = ""
                        if (ev.button === Qt.RightButton) { var p = mapToItem(finestra.contentItem, ev.x, ev.y); finestra.menuSfondo(p.x, p.y) }
                    }
                    onCanceled: areaVista.selezionando = false
                }
                // la rotellina scorre la vista (le viste non si trascinano: il trascinamento seleziona)
                WheelHandler {
                    onWheel: function (ev) {
                        var v = finestra.griglia ? vistaGriglia : vistaElenco
                        var massimo = Math.max(0, v.contentHeight - v.height + (finestra.griglia ? 0 : 28))
                        v.contentY = Math.max(v.originY, Math.min(v.originY + massimo, v.contentY - ev.angleDelta.y))
                    }
                }
                DropArea {
                    anchors.fill: parent
                    onDropped: function (d) {
                        if (!d.hasUrls || finestra.dati.cestino) return
                        finestra.trasferisci(Array.prototype.map.call(d.urls, function (x) { return x.toString() }), finestra.uri, finestra.modoDa(d.modifiers))
                        d.acceptProposedAction()
                    }
                }
                GridView {
                    id: vistaGriglia
                    visible: finestra.griglia
                    interactive: false
                    anchors.fill: parent
                    anchors.margins: 10
                    cellWidth: areaVista.cellaL
                    cellHeight: areaVista.cellaA
                    model: finestra.voci
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}
                    delegate: Elemento { larghezza: areaVista.cellaL - 4; altezza: areaVista.cellaA - 4; vistaGriglia: true }
                }
                ListView {
                    id: vistaElenco
                    visible: !finestra.griglia
                    interactive: false
                    anchors.fill: parent
                    model: finestra.voci
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}
                    // Intestazione: un clic su una colonna ordina (di nuovo: inverte)
                    header: Rectangle {
                        width: vistaElenco.width; height: 28; color: Tema.sfondo; z: 3
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 44; anchors.rightMargin: 16
                            Repeater {
                                model: [{ k: "nome", t: I18n.t("Nome"), l: -1 }, { k: "data", t: I18n.t("Modificato"), l: 130 }, { k: "dimensione", t: I18n.t("Dimensione"), l: 90 }, { k: "tipo", t: I18n.t("Tipo"), l: 150 }]
                                Text {
                                    required property var modelData
                                    Layout.fillWidth: modelData.l < 0
                                    Layout.preferredWidth: modelData.l > 0 ? modelData.l : -1
                                    horizontalAlignment: modelData.k === "dimensione" ? Text.AlignRight : Text.AlignLeft
                                    text: modelData.t + (finestra.ordina === modelData.k ? (finestra.crescente ? "  ▴" : "  ▾") : "")
                                    color: finestra.ordina === modelData.k ? Tema.testo : Tema.testoSecondario
                                    font.family: Tema.font; font.pixelSize: 11; font.weight: finestra.ordina === modelData.k ? Font.DemiBold : Font.Normal
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: finestra.cambiaOrdine(modelData.k) }
                                }
                            }
                        }
                    }
                    delegate: Elemento { larghezza: vistaElenco.width; altezza: 30; vistaGriglia: false }
                }
                // Rettangolo di selezione
                Rectangle {
                    visible: areaVista.selezionando
                    x: areaVista.rettangolo.x; y: areaVista.rettangolo.y
                    width: areaVista.rettangolo.width; height: areaVista.rettangolo.height
                    color: "#26" + Tema.accento.substring(1)
                    border.color: Tema.accento
                    border.width: 1
                }
                Column {
                    anchors.centerIn: parent
                    visible: finestra.voci.length === 0 && !finestra.caricamento
                    spacing: 8
                    Image { anchors.horizontalCenter: parent.horizontalCenter; width: 56; height: 56; sourceSize.width: 112; sourceSize.height: 112; opacity: 0.6; source: "image://icona/" + (finestra.dati.cestino ? "user-trash" : "folder") }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: finestra.risultati !== null ? I18n.t("Nessun risultato") : (finestra.dati.cestino ? I18n.t("Il cestino è vuoto") : I18n.t("Questa cartella è vuota")); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13 }
                }
            }
            // Riquadro dei dettagli (Alt+P)
            Rectangle {
                visible: finestra.dettagli
                Layout.preferredWidth: 260
                Layout.fillHeight: true
                color: Tema.chiaro ? "#F6F6F9" : Tema.superficie
                Rectangle { width: 1; height: parent.height; color: Tema.chiaro ? "#12000000" : "#40000000" }
                readonly property var v: finestra.elencoScelti.length === 1 ? finestra.elencoScelti[0] : null
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 10
                    Image {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 160; Layout.preferredHeight: 120
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: 320; sourceSize.height: 240
                        asynchronous: true
                        readonly property var v: parent.parent.v
                        source: v ? (v.miniatura || v.anteprima || (v.icona.indexOf("/") === 0 ? "file://" + v.icona : "image://icona/" + v.icona))
                                  : "image://icona/" + (finestra.elencoScelti.length > 1 ? "edit-copy" : (finestra.dati.cestino ? "user-trash" : "folder"))
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        readonly property var v: parent.parent.v
                        text: v ? v.nome : (finestra.elencoScelti.length > 1 ? finestra.elencoScelti.length + " " + I18n.t("elementi selezionati") : (finestra.dati.titolo || ""))
                        color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.DemiBold
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Tema.chiaro ? "#12000000" : "#1FFFFFFF" }
                    Repeater {
                        model: {
                            var v = parent.parent.v
                            if (v) return [{ k: I18n.t("Tipo"), t: v.tipo }, { k: I18n.t("Dimensione"), t: v.testoDimensione }, { k: I18n.t("Modificato"), t: v.modificato }]
                            if (finestra.elencoScelti.length > 1) {
                                var tot = 0; finestra.elencoScelti.forEach(function (x) { if (x.dimensione > 0) tot += x.dimensione })
                                return [{ k: I18n.t("Dimensione totale"), t: tot >= 1048576 ? (tot / 1048576).toFixed(1).replace(".", ",") + " MB" : Math.round(tot / 1024) + " KB" }]
                            }
                            return [{ k: I18n.t("Contenuto"), t: finestra.voci.length + " " + I18n.t("elementi") }]
                        }
                        ColumnLayout {
                            required property var modelData
                            visible: !!modelData.t
                            spacing: 1
                            Text { text: modelData.k; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
                            Text { text: modelData.t || ""; Layout.maximumWidth: 220; elide: Text.ElideRight; color: Tema.testo; font.family: Tema.font; font.pixelSize: 12 }
                        }
                    }
                    Pulsante {
                        visible: finestra.elencoScelti.length === 1
                        text: I18n.t("Proprietà")
                        onClicked: proprieta.apri(finestra.elencoScelti[0].uri)
                    }
                    Item { Layout.fillHeight: true }
                }
            }
            }
            // Barra di stato (con l'avanzamento delle copie lunghe)
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 26
                color: Tema.superficie
                Text {
                    visible: !finestra.avanzamento
                    anchors.verticalCenter: parent.verticalCenter; x: 14
                    color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11
                    text: finestra.elencoScelti.length > 0 ? finestra.elencoScelti.length + " " + I18n.t("selezionati su") + " " + finestra.voci.length
                                                          : finestra.voci.length + " " + I18n.t("elementi")
                }
                Row {
                    visible: !!finestra.avanzamento
                    anchors.verticalCenter: parent.verticalCenter; x: 14
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 260; elide: Text.ElideMiddle
                        text: finestra.avanzamento ? I18n.t("Trasferimento") + ": " + finestra.avanzamento.nome : ""
                        color: Tema.testo; font.family: Tema.font; font.pixelSize: 11
                    }
                    BarraProgresso { width: 200; anchors.verticalCenter: parent.verticalCenter; value: finestra.avanzamento ? finestra.avanzamento.fatti / finestra.avanzamento.totale : 0 }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: finestra.avanzamento ? Math.round(100 * finestra.avanzamento.fatti / finestra.avanzamento.totale) + "%" : ""
                        color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11
                    }
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
            width: finestra.latoIcone; height: finestra.latoIcone
            fillMode: Image.PreserveAspectFit
            sourceSize.width: finestra.latoIcone * 2; sourceSize.height: finestra.latoIcone * 2
            asynchronous: true
            source: el.modelData.miniatura || el.modelData.anteprima || (el.modelData.icona.indexOf("/") === 0 ? "file://" + el.modelData.icona : "image://icona/" + el.modelData.icona)
        }
        Text {
            visible: el.vistaGriglia && finestra.inRinomina !== el.modelData.uri
            anchors.horizontalCenter: parent.horizontalCenter
            y: finestra.latoIcone + 14
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
                finestra.trasferisci(u, el.modelData.uri, finestra.modoDa(d.modifiers))
                d.acceptProposedAction()
            }
        }
        // Rinomina sul posto
        CampoTesto {
            visible: finestra.inRinomina === el.modelData.uri
            x: el.vistaGriglia ? 2 : 44
            y: el.vistaGriglia ? finestra.latoIcone + 12 : 1
            width: el.vistaGriglia ? parent.width - 4 : parent.width * 0.4
            font.pixelSize: 12
            onVisibleChanged: if (visible) { text = el.modelData.nome; forceActiveFocus(); var p = text.lastIndexOf("."); select(0, p > 0 && !el.modelData.cartella ? p : text.length) }
            onAccepted: { var r = ponte.chiama("rinomina", [el.modelData.uri, text]); finestra.inRinomina = ""; finestra.esito(r) }
            Keys.onEscapePressed: finestra.inRinomina = ""
        }
    }

    // ── Pulsante piatto della barra dei comandi ─────────────────────────────
    component Comando: Rectangle {
        id: c
        property string icona: ""
        property string testo: ""
        property string suggerimento: ""
        property bool freccia: false
        property bool attivo: true
        property bool acceso: false
        signal premuto()
        width: rigaComando.implicitWidth + 16
        height: 30
        radius: 6
        opacity: attivo ? 1 : 0.4
        color: acceso ? (Tema.chiaro ? "#1A000000" : "#24FFFFFF") : (maC.pressed ? (Tema.chiaro ? "#1A000000" : "#24FFFFFF") : (maC.containsMouse && attivo ? (Tema.chiaro ? "#0F000000" : "#14FFFFFF") : "transparent"))
        Row {
            id: rigaComando
            anchors.centerIn: parent
            spacing: 6
            Icona { nome: c.icona + (Tema.chiaro ? "?c" : ""); lato: 16; anchors.verticalCenter: parent.verticalCenter }
            Text { visible: c.testo !== ""; text: c.testo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            Text { visible: c.freccia; text: "▾"; color: Tema.testoSecondario; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: maC; anchors.fill: parent; hoverEnabled: true; onClicked: if (c.attivo) c.premuto() }
        ToolTip.visible: maC.containsMouse && c.suggerimento !== ""
        ToolTip.delay: 600
        ToolTip.text: c.suggerimento
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
