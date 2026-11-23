// SolidOS App: lo store di sistema, completo come un App Store.
// Barra laterale (ricerca, Scopri, Raccolte, categorie, Installate, Aggiornamenti), vetrina con
// un'app in evidenza, le raccolte scelte da SolidOS, le più amate e le collezioni di Flathub, e
// una pagina per ogni app con foto dello schermo, descrizione, dimensioni, raccolte e le
// recensioni di chi usa SolidOS (scritte con il Solid ID). Compaiono solo le app che esistono
// per il processore di questo computer.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: Tema.nomeSistema + " App"
    width: 1120
    height: 760

    // ── Stato ──────────────────────────────────────────────────────────────
    property string pagina: "scopri"          // scopri | raccolte | raccolta | categoria | cerca | installate | aggiornamenti | app
    property var raccolte: []
    property var raccolta: null               // raccolta aperta
    property var piuAmate: []
    property var recensioni: ({ riepilogo: { media: 0, totale: 0, distribuzione: [0, 0, 0, 0, 0] }, elenco: [], account: { collegato: false } })
    property var raccolteApp: []              // raccolte che contengono l'app aperta
    property string paginaPrima: "scopri"     // dove tornare dalla pagina di un'app
    property string categoriaScelta: ""
    property string nomeCategoria: ""
    property var popolari: []
    property var tendenza: []
    property var nuove: []
    property var elencoCategoria: []
    property var risultati: []
    property var installate: []
    property var aggiornamenti: []
    property var categorie: []
    property var idInstallate: ({})           // id → true, per «Ottieni» / «Apri»
    property var scheda: null                 // dettagli dell'app aperta
    property string occupata: ""
    property var avanzamento: ({})            // id → percentuale dello scaricamento
    property var account: ({ collegato: false, elenco: [], automatiche: true })   // «Le mie app» del Solid ID
    readonly property var altrove: account.elenco.filter(function (x) { return !x.installata && !finestra.installata(x.app) })
    property int caricamenti: 0
    readonly property bool caricando: caricamenti > 0

    function chiedi(metodo, argomenti, ident) { caricamenti++; ponte.avvia(metodo, argomenti, ident) }
    function aggiornaInstallate() {
        ponte.avvia("installateId", [], "idInstallate")
        ponte.avvia("installate", [], "installate")
        ponte.avvia("aggiornamenti", [], "aggiornamenti")
    }
    function vai(p) { pagina = p; vista.contentY = 0 }
    function apriApp(app) {
        if (pagina !== "app") paginaPrima = pagina
        scheda = { id: app.id, nome: app.nome, descrizioneBreve: app.descrizione || "", icona: app.icona || "", origine: app.origine || "flatpak", caricata: false }
        vai("app")
        if ((app.origine || "flatpak") === "flatpak") chiedi("dettagli", [app.id], "dettagli")
        recensioni = { riepilogo: { media: 0, totale: 0, distribuzione: [0, 0, 0, 0, 0] }, elenco: [], account: recensioni.account }
        raccolteApp = ponte.chiama("raccolteDi", [app.id])
        ponte.avvia("recensioni", [app.id], "recensioni")
    }
    function apriRaccolta(r) { if (pagina !== "app") paginaPrima = pagina; raccolta = r; vai("raccolta") }
    function installata(id) { return finestra.idInstallate[id] === true }
    function installa(app) {
        occupata = app.id
        var v = Object.assign({}, avanzamento); v[app.id] = 0; avanzamento = v
        ponte.avvia("installa", [app.id, app.origine || "flatpak", app.nome || "", app.icona || ""], "installa")
    }
    function rimuovi(app) { occupata = app.id; ponte.avvia("rimuovi", [app.id, app.origine || "flatpak", app.sistema === true], "rimuovi") }
    function apri(app) { ponte.avvia("apri", [app.id, app.origine || "flatpak"], "apri") }
    function cerca(t) {
        if (t.trim().length < 2) { if (pagina === "cerca") vai("scopri"); return }
        vai("cerca"); risultati = []; chiedi("cercaCatalogo", [t], "cerca")
    }

    Component.onCompleted: {
        categorie = ponte.chiama0("categorie")
        ponte.avvia("prepara", [], "prepara")
        chiedi("collezione", ["popular"], "popular")
        chiedi("collezione", ["trending"], "trending")
        chiedi("collezione", ["recently-updated"], "recently-updated")
        ponte.avvia("raccolte", [], "raccolte")
        ponte.avvia("piuAmate", [], "piuAmate")
        aggiornaInstallate()
        ponte.avvia("mieApp", [], "mieApp")
        ponte.avvia("scaricaMie", [], "scaricaMie")   // le app prese sul telefono arrivano da sole
        var iniziale = ponte.chiama0("ricercaIniziale")
        if (iniziale) { ricerca.text = iniziale; cerca(iniziale) }
    }
    Connections {
        target: ponte
        function onEvento(nome, d) {
            if (nome === "avanzamento") { var v = Object.assign({}, finestra.avanzamento); v[d.id] = d.percento; finestra.avanzamento = v }
            else if (nome === "scaricata") { finestra.avviso(d.nome + ": " + I18n.t("scaricata dalle tue app")); finestra.aggiornaInstallate() }
        }
        function onCompletato(id, r) {
            var risposte = ["popular", "trending", "recently-updated", "categoria", "cerca", "dettagli"]
            if (risposte.indexOf(id) >= 0) finestra.caricamenti = Math.max(0, finestra.caricamenti - 1)
            if (id === "popular") finestra.popolari = r
            else if (id === "trending") finestra.tendenza = r
            else if (id === "recently-updated") finestra.nuove = r
            else if (id === "categoria") finestra.elencoCategoria = r
            else if (id === "cerca") finestra.risultati = r
            else if (id === "installate") finestra.installate = r
            else if (id === "raccolte") finestra.raccolte = r
            else if (id === "piuAmate") finestra.piuAmate = r
            else if (id === "mieApp") finestra.account = r
            else if (id === "scaricaMie") { if (r.scaricate) ponte.avvia("mieApp", [], "mieApp") }
            else if (id === "recensioni") finestra.recensioni = r
            else if (id === "scriviRecensione" || id === "cancellaRecensione" || id === "utile") {
                finestra.avviso(r.messaggio)
                if (r.ok) { scrittura.close(); if (finestra.scheda) ponte.avvia("recensioni", [finestra.scheda.id], "recensioni"); ponte.avvia("piuAmate", [], "piuAmate") }
            }
            else if (id === "aggiornamenti") finestra.aggiornamenti = r
            else if (id === "idInstallate") {
                var m = {}
                for (var i = 0; i < r.length; i++) m[r[i]] = true
                finestra.idInstallate = m
            }
            else if (id === "dettagli") {
                if (r.ok && finestra.scheda && r.id === finestra.scheda.id) finestra.scheda = Object.assign({ caricata: true }, r)
                else if (!r.ok) finestra.avviso(r.messaggio)
            }
            else if (id === "prepara") { if (!r.ok) finestra.avviso(r.messaggio) }
            else if (id === "apri") { if (!r.ok) finestra.avviso(r.messaggio) }
            else if (id === "installa" || id === "rimuovi" || id === "aggiorna" || id === "aggiornaApp") {
                finestra.occupata = ""
                finestra.avanzamento = ({})
                ponte.avvia("mieApp", [], "mieApp")
                finestra.avviso(r.ok ? (r.messaggio || I18n.t("Fatto")) : (r.messaggio || I18n.t("Operazione non riuscita")))
                finestra.aggiornaInstallate()
            }
        }
    }

    // ── Componenti ─────────────────────────────────────────────────────────
    // Icona di un'app: dal catalogo (indirizzo web) oppure dal tema di sistema
    component IconaApp: Item {
        property var app: ({})
        property int lato: 56
        width: lato; height: lato
        Image {
            id: daRete
            anchors.fill: parent
            visible: status === Image.Ready
            source: (parent.app.icona || "").indexOf("http") === 0 ? parent.app.icona : ""
            sourceSize.width: parent.lato * 2; sourceSize.height: parent.lato * 2
            fillMode: Image.PreserveAspectFit; asynchronous: true; smooth: true
        }
        Icona { anchors.fill: parent; visible: daRete.status !== Image.Ready; nome: (parent.app.icona || "").indexOf("http") === 0 ? parent.app.id : (parent.app.icona || parent.app.id || "application-x-executable"); lato: parent.lato }
    }
    // Pulsante piccolo «Ottieni» / «Apri» / «Attendi…»
    component PulsanteApp: Rectangle {
        property var app: ({})
        readonly property bool presente: finestra.installata(app.id) || app.installata === true
        readonly property bool inCorso: finestra.occupata === app.id
        // Durante lo scaricamento il pulsante diventa una barra che si riempie
        readonly property int percento: finestra.avanzamento[app.id] !== undefined ? finestra.avanzamento[app.id] : -1
        id: pa
        width: Math.max(percento >= 0 ? 110 : 76, etichetta.implicitWidth + 28); height: 30; radius: 15
        color: percento >= 0 || presente ? (Tema.chiaro ? "#E9EDF1" : "#2A3243") : Tema.accento
        opacity: finestra.occupata !== "" && !inCorso ? 0.5 : 1
        clip: true
        Rectangle {
            visible: pa.percento >= 0
            width: Math.max(pa.height, pa.width * pa.percento / 100); height: pa.height; radius: pa.radius
            color: Tema.accento
            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        }
        Text {
            id: etichetta
            anchors.centerIn: parent
            text: pa.percento >= 0 ? (pa.percento >= 100 ? I18n.t("Installo…") : pa.percento + "%")
                  : parent.inCorso ? I18n.t("Attendi…") : (parent.presente ? I18n.t("Apri") : I18n.t("Ottieni"))
            color: pa.percento >= 0 ? (pa.percento > 45 ? "#FFFFFF" : Tema.testo) : (parent.presente ? Tema.accento : "#FFFFFF")
            font.family: Tema.font; font.pixelSize: 13; font.weight: Font.Bold
        }
        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            enabled: finestra.occupata === ""
            onClicked: parent.presente ? finestra.apri(parent.app) : finestra.installa(parent.app)
        }
    }
    // Scheda di un'app nelle griglie
    component SchedaApp: Rectangle {
        id: sa
        property var app: ({})
        width: 300; height: 96; radius: 14
        color: zona.containsMouse ? (Tema.chiaro ? "#F1F4F8" : "#232A3A") : (Tema.chiaro ? "#FFFFFF" : "#1A2030")
        border.color: Tema.chiaro ? "#E2E8F0" : "#262F42"
        MouseArea { id: zona; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: finestra.apriApp(sa.app) }
        RowLayout {
            anchors.fill: parent; anchors.margins: 14
            spacing: 12
            IconaApp { app: sa.app; lato: 60 }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Text { Layout.fillWidth: true; text: sa.app.nome || ""; elide: Text.ElideRight; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                Text { Layout.fillWidth: true; text: sa.app.descrizione || ""; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                Row {
                    visible: (sa.app.totale || 0) > 0; spacing: 5
                    Stelle { voto: sa.app.media || 0; lato: 11; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: String(sa.app.media || 0).replace(".", ",") + " (" + (sa.app.totale || 0) + ")"; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11; font.weight: Font.DemiBold }
                }
            }
            PulsanteApp { app: sa.app; Layout.alignment: Qt.AlignVCenter }
        }
    }
    // Cinque stelle (voto da 0 a 5)
    component Stelle: Row {
        property real voto: 0
        property int lato: 12
        spacing: 1
        Repeater {
            model: 5
            Text {
                required property int index
                text: "★"; font.pixelSize: parent.lato
                color: index < Math.round(parent.voto) ? "#F5A524" : (Tema.chiaro ? "#D4D4D8" : "#4A4B52")
            }
        }
    }
    // Copertina di una raccolta: sfumatura con le icone delle prime app sovrapposte
    component Copertina: Rectangle {
        id: cop
        property var r: ({})
        radius: 16; clip: true
        color: Tema.chiaro ? "#FFFFFF" : "#26272D"
        border.color: zonaCop.containsMouse ? Tema.accento : "transparent"
        MouseArea { id: zonaCop; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: finestra.apriRaccolta(cop.r) }
        Rectangle {
            id: fascia
            width: parent.width; height: 104; radius: 16
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: (cop.r.colori || ["#4C7DFF"])[0] }
                GradientStop { position: 1; color: (cop.r.colori || ["#4C7DFF", "#8B5CF6"])[1] }
            }
            Row {
                anchors.centerIn: parent
                spacing: -12
                Repeater { model: (cop.r.app || []).slice(0, 4); IconaApp { required property var modelData; app: modelData; lato: 52 } }
            }
        }
        Column {
            x: 14; anchors.top: fascia.bottom; anchors.topMargin: 10
            width: parent.width - 28; spacing: 2
            Text { width: parent.width; elide: Text.ElideRight; text: cop.r.nome || ""; color: Tema.testo; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.Bold }
            Text { width: parent.width; elide: Text.ElideRight; text: cop.r.sotto || ""; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
        }
    }
    // Sezione con titolo e griglia di app
    component Sezione: ColumnLayout {
        id: sezione
        property string titolo: ""
        property var elenco: []
        property int quante: 9
        Layout.fillWidth: true
        spacing: 12
        visible: elenco.length > 0
        Text { text: sezione.titolo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 20; font.weight: Font.Bold }
        Flow {
            Layout.fillWidth: true
            spacing: 12
            // tante colonne quante ne entrano (schede di almeno 290 px), tutte della stessa larghezza
            readonly property int colonne: Math.max(1, Math.floor((width + 12) / 302))
            Repeater { model: sezione.elenco.slice(0, sezione.quante); SchedaApp { required property var modelData; app: modelData; width: Math.floor((parent.width - (parent.colonne - 1) * 12) / parent.colonne) } }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Barra laterale ─────────────────────────────────────────────────
        Rectangle {
            Layout.preferredWidth: 236
            Layout.fillHeight: true
            color: Tema.chiaro ? "#F1F4F8" : "#141A27"
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 14
                spacing: 4
                CampoRicerca {
                    id: ricerca
                    Layout.fillWidth: true
                    placeholderText: I18n.t("Cerca app e giochi")
                    onAccepted: finestra.cerca(text)
                    onTextChanged: ritardoRicerca.restart()
                }
                Timer { id: ritardoRicerca; interval: 450; onTriggered: finestra.cerca(ricerca.text) }
                Item { Layout.preferredHeight: 8 }
                VoceElenco { Layout.fillWidth: true; icona: "starred-symbolic"; titolo: I18n.t("Scopri"); selezionata: finestra.pagina === "scopri"; onClicked: { ricerca.text = ""; finestra.vai("scopri") } }
                VoceElenco { Layout.fillWidth: true; icona: "view-app-grid-symbolic"; titolo: I18n.t("Raccolte"); selezionata: finestra.pagina === "raccolte" || finestra.pagina === "raccolta"; onClicked: { ricerca.text = ""; finestra.vai("raccolte") } }
                Text { Layout.topMargin: 12; Layout.leftMargin: 8; text: I18n.t("Categorie"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11; font.weight: Font.DemiBold }
                Repeater {
                    model: finestra.categorie
                    VoceElenco {
                        required property var modelData
                        Layout.fillWidth: true; icona: modelData.icona; titolo: modelData.nome
                        selezionata: finestra.pagina === "categoria" && finestra.categoriaScelta === modelData.id
                        onClicked: {
                            finestra.categoriaScelta = modelData.id; finestra.nomeCategoria = modelData.nome
                            finestra.elencoCategoria = []; finestra.vai("categoria")
                            finestra.chiedi("categoria", [modelData.id], "categoria")
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                VoceElenco {
                    Layout.fillWidth: true; icona: "avatar-default-symbolic"; titolo: I18n.t("Le mie app")
                    sottotitolo: finestra.account.collegato ? (finestra.altrove.length ? finestra.altrove.length + " " + I18n.t("dagli altri dispositivi") : I18n.t("Legate al Solid ID")) : I18n.t("Accedi al Solid ID")
                    selezionata: finestra.pagina === "mie"; onClicked: { finestra.vai("mie"); ponte.avvia("mieApp", [], "mieApp") }
                }
                VoceElenco { Layout.fillWidth: true; icona: "emblem-ok-symbolic"; titolo: I18n.t("Installate"); sottotitolo: finestra.installate.length + " " + I18n.t("app"); selezionata: finestra.pagina === "installate"; onClicked: finestra.vai("installate") }
                VoceElenco {
                    Layout.fillWidth: true; icona: "software-update-available-symbolic"; titolo: I18n.t("Aggiornamenti")
                    sottotitolo: finestra.aggiornamenti.length ? finestra.aggiornamenti.length + " " + I18n.t("disponibili") : I18n.t("Tutto aggiornato")
                    selezionata: finestra.pagina === "aggiornamenti"; onClicked: finestra.vai("aggiornamenti")
                }
            }
        }

        // ── Contenuto ──────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Tema.chiaro ? "#F8FAFC" : "#0F1422"
            BarraProgresso { anchors.top: parent.top; width: parent.width; indeterminate: true; visible: finestra.caricando || finestra.occupata !== ""; z: 5 }

            Flickable {
                id: vista
                anchors.fill: parent
                contentHeight: colonna.implicitHeight + 64
                clip: true
                ScrollBar.vertical: ScrollBar {}
                ColumnLayout {
                    id: colonna
                    x: 32; y: 28
                    width: vista.width - 64
                    spacing: 28

                    // ══ Scopri ══════════════════════════════════════════════
                    // App in evidenza: la più scaricata del mese
                    Rectangle {
                        id: evidenza
                        visible: finestra.pagina === "scopri" && finestra.popolari.length > 0
                        Layout.fillWidth: true; Layout.preferredHeight: 200
                        radius: 22
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Tema.accento }
                            GradientStop { position: 1; color: Qt.darker(Tema.accento, 1.8) }
                        }
                        readonly property var app: finestra.popolari.length ? finestra.popolari[0] : ({})
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: finestra.apriApp(evidenza.app) }
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 32
                            spacing: 26
                            Rectangle {
                                Layout.preferredWidth: 120; Layout.preferredHeight: 120; radius: 28; color: "#26FFFFFF"
                                IconaApp { anchors.centerIn: parent; app: evidenza.app; lato: 96 }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 6
                                Text { text: I18n.t("IN EVIDENZA"); color: "#CCFFFFFF"; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 1.2 }
                                Text { Layout.fillWidth: true; text: evidenza.app.nome || ""; elide: Text.ElideRight; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: 30; font.weight: Font.Bold }
                                Text { Layout.fillWidth: true; text: evidenza.app.descrizione || ""; elide: Text.ElideRight; color: "#E6FFFFFF"; font.family: Tema.font; font.pixelSize: 15 }
                                Item { Layout.preferredHeight: 6 }
                                PulsanteApp { app: evidenza.app }
                            }
                        }
                    }
                    // Raccolte (le prime 4) e «Vedi tutte»
                    ColumnLayout {
                        visible: (finestra.pagina === "scopri" || finestra.pagina === "raccolte") && finestra.raccolte.length > 0
                        Layout.fillWidth: true; spacing: 12
                        RowLayout {
                            Layout.fillWidth: true
                            Text { Layout.fillWidth: true; text: I18n.t("Raccolte"); color: Tema.testo; font.family: Tema.font; font.pixelSize: finestra.pagina === "raccolte" ? 26 : 20; font.weight: Font.Bold }
                            Text {
                                visible: finestra.pagina === "scopri"
                                text: I18n.t("Vedi tutte") + " ›"; color: Tema.accento; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold
                                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: finestra.vai("raccolte") }
                            }
                        }
                        Text { visible: finestra.pagina === "raccolte"; text: I18n.t("Gruppi di app scelti da SolidOS per fare una cosa sola, bene."); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 14 }
                        Grid {
                            id: grigliaRaccolte
                            Layout.fillWidth: true
                            columns: Math.max(2, Math.floor((width + 16) / 236)); spacing: 16
                            Repeater {
                                model: finestra.pagina === "raccolte" ? finestra.raccolte : finestra.raccolte.slice(0, grigliaRaccolte.columns)
                                Copertina {
                                    required property var modelData
                                    r: modelData
                                    width: Math.floor((grigliaRaccolte.width - (grigliaRaccolte.columns - 1) * 16) / grigliaRaccolte.columns); height: 168
                                }
                            }
                        }
                    }
                    Sezione { visible: finestra.pagina === "scopri" && elenco.length > 0; titolo: I18n.t("Le più amate su SolidOS"); elenco: finestra.piuAmate }
                    Sezione { visible: finestra.pagina === "scopri" && elenco.length > 0; titolo: I18n.t("Le più popolari"); elenco: finestra.popolari.slice(1) }
                    Sezione { visible: finestra.pagina === "scopri" && elenco.length > 0; titolo: I18n.t("Di tendenza"); elenco: finestra.tendenza }
                    Sezione { visible: finestra.pagina === "scopri" && elenco.length > 0; titolo: I18n.t("Nuove e aggiornate"); elenco: finestra.nuove }
                    Text {
                        visible: finestra.pagina === "scopri" && !finestra.caricando && finestra.popolari.length === 0
                        Layout.fillWidth: true; wrapMode: Text.Wrap
                        text: I18n.t("Non riesco a leggere il catalogo delle app: controlla la connessione a Internet e riapri lo store.")
                        color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 14
                    }

                    // ══ Una raccolta ═══════════════════════════════════════
                    Rectangle {
                        id: testaRaccolta
                        visible: finestra.pagina === "raccolta" && finestra.raccolta !== null
                        Layout.fillWidth: true; Layout.preferredHeight: 190; radius: 22
                        readonly property var r: finestra.raccolta || ({})
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: (testaRaccolta.r.colori || ["#4C7DFF"])[0] }
                            GradientStop { position: 1; color: (testaRaccolta.r.colori || ["#4C7DFF", "#8B5CF6"])[1] }
                        }
                        Text {
                            x: 24; y: 18; text: "‹ " + I18n.t("Indietro"); color: "#E6FFFFFF"; font.family: Tema.font; font.pixelSize: 14
                            MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: finestra.vai(finestra.paginaPrima === "raccolta" ? "raccolte" : finestra.paginaPrima) }
                        }
                        Column {
                            x: 28; anchors.bottom: parent.bottom; anchors.bottomMargin: 24; spacing: 6
                            Row { spacing: -12; Repeater { model: (parent.parent.parent.r.app || []).slice(0, 5); IconaApp { required property var modelData; app: modelData; lato: 48 } } }
                            Text { text: parent.parent.r.nome || ""; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: 30; font.weight: Font.Bold }
                            Text { text: (parent.parent.r.sotto || "") + " · " + I18n.t("scelte da") + " " + Tema.nomeSistema; color: "#E6FFFFFF"; font.family: Tema.font; font.pixelSize: 14 }
                        }
                    }
                    Sezione {
                        visible: finestra.pagina === "raccolta" && finestra.raccolta !== null
                        titolo: I18n.t("Le app"); elenco: finestra.raccolta ? finestra.raccolta.app : []; quante: 30
                    }

                    // ══ Categoria e ricerca ═════════════════════════════════
                    Sezione {
                        visible: finestra.pagina === "categoria"
                        titolo: finestra.nomeCategoria; elenco: finestra.elencoCategoria; quante: 60
                    }
                    Sezione {
                        visible: finestra.pagina === "cerca"
                        titolo: I18n.t("Risultati per") + " «" + ricerca.text + "»"; elenco: finestra.risultati; quante: 60
                    }
                    Text {
                        visible: (finestra.pagina === "cerca" && finestra.risultati.length === 0 || finestra.pagina === "categoria" && finestra.elencoCategoria.length === 0) && !finestra.caricando
                        text: finestra.pagina === "cerca" ? I18n.t("Nessuna app trovata: prova con un'altra parola") : I18n.t("Nessuna app in questa categoria per questo computer")
                        color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 14
                    }

                    // ══ Installate e aggiornamenti ══════════════════════════
                    ColumnLayout {
                        visible: finestra.pagina === "installate" || finestra.pagina === "aggiornamenti"
                        Layout.fillWidth: true; spacing: 10
                        RowLayout {
                            Layout.fillWidth: true
                            Text { Layout.fillWidth: true; text: finestra.pagina === "installate" ? I18n.t("Installate") : I18n.t("Aggiornamenti"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 26; font.weight: Font.Bold }
                            Pulsante {
                                visible: finestra.pagina === "aggiornamenti" && finestra.aggiornamenti.length > 0
                                principale: true; text: I18n.t("Aggiorna tutto"); icona: "system-software-update"
                                enabled: finestra.occupata === ""
                                onClicked: { finestra.occupata = "*"; ponte.avvia("aggiorna", [], "aggiorna") }
                            }
                        }
                        Text {
                            visible: (finestra.pagina === "installate" ? finestra.installate : finestra.aggiornamenti).length === 0
                            text: finestra.pagina === "installate" ? I18n.t("Nessuna app installata dallo store") : I18n.t("Tutte le app sono aggiornate")
                            color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 14
                        }
                        Repeater {
                            model: finestra.pagina === "installate" ? finestra.installate : (finestra.pagina === "aggiornamenti" ? finestra.aggiornamenti : [])
                            Rectangle {
                                id: riga
                                required property var modelData
                                Layout.fillWidth: true; Layout.preferredHeight: 72; radius: 14
                                color: Tema.chiaro ? "#FFFFFF" : "#1A2030"; border.color: Tema.chiaro ? "#E2E8F0" : "#262F42"
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 14; spacing: 14
                                    Icona { nome: riga.modelData.id; lato: 44 }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 2
                                        Text { Layout.fillWidth: true; elide: Text.ElideRight; text: riga.modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                                        Text { Layout.fillWidth: true; elide: Text.ElideRight; text: (riga.modelData.versione ? I18n.t("Versione") + " " + riga.modelData.versione + " · " : "") + (riga.modelData.descrizione || ""); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                                    }
                                    Pulsante { text: I18n.t("Apri"); visible: finestra.pagina === "installate"; enabled: finestra.occupata === ""; onClicked: finestra.apri(riga.modelData) }
                                    Pulsante { text: I18n.t("Aggiorna"); principale: true; visible: finestra.pagina === "aggiornamenti"; enabled: finestra.occupata === ""; onClicked: { finestra.occupata = riga.modelData.id; ponte.avvia("aggiornaApp", [riga.modelData.id], "aggiornaApp") } }
                                    Pulsante { text: I18n.t("Rimuovi"); pericoloso: true; visible: finestra.pagina === "installate"; enabled: finestra.occupata === ""; onClicked: finestra.rimuovi(riga.modelData) }
                                }
                            }
                        }
                    }

                    // ══ Le mie app (Solid ID) ═══════════════════════════════
                    ColumnLayout {
                        visible: finestra.pagina === "mie"
                        Layout.fillWidth: true; spacing: 12
                        Text { text: I18n.t("Le mie app"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 26; font.weight: Font.Bold }
                        Text {
                            Layout.fillWidth: true; wrapMode: Text.Wrap
                            text: finestra.account.collegato
                                  ? I18n.t("Ogni app che prendi dallo Store, qui o sul telefono, resta nel tuo Solid ID: la ritrovi su tutti i tuoi dispositivi.")
                                  : I18n.t("Accedi al Solid ID (Impostazioni › Solid ID): le app che prendi sul telefono compariranno anche qui, e al contrario.")
                            color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 14
                        }
                        RowLayout {
                            visible: finestra.account.collegato
                            Layout.fillWidth: true; spacing: 12
                            Text { Layout.fillWidth: true; text: I18n.t("Scarica da sole le app prese sul telefono"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
                            Interruttore {
                                checked: finestra.account.automatiche
                                onToggled: {
                                    ponte.chiama("impostaAutomatiche", [checked])
                                    finestra.account = Object.assign({}, finestra.account, { automatiche: checked })
                                    if (checked) ponte.avvia("scaricaMie", [], "scaricaMie")
                                }
                            }
                        }
                        Text {
                            visible: finestra.altrove.length > 0
                            text: I18n.t("Dagli altri dispositivi"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 18; font.weight: Font.Bold
                        }
                        Repeater {
                            model: finestra.pagina === "mie" ? finestra.account.elenco : []
                            Rectangle {
                                id: rigaMia
                                required property var modelData
                                readonly property var a: ({ id: modelData.app, nome: modelData.nome, icona: modelData.icona || "", origine: "flatpak" })
                                Layout.fillWidth: true; Layout.preferredHeight: 72; radius: 14
                                color: Tema.chiaro ? "#FFFFFF" : "#1A2030"; border.color: Tema.chiaro ? "#E2E8F0" : "#262F42"
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 14; spacing: 14
                                    IconaApp { app: rigaMia.a; lato: 44 }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 2
                                        Text { Layout.fillWidth: true; elide: Text.ElideRight; text: rigaMia.modelData.nome || rigaMia.modelData.app; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                                        Text { Layout.fillWidth: true; elide: Text.ElideRight; text: rigaMia.modelData.dispositivo === "telefono" ? I18n.t("Presa sul telefono") : I18n.t("Presa su un PC"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                                    }
                                    PulsanteApp { app: rigaMia.a }
                                }
                                MouseArea { anchors.fill: parent; anchors.rightMargin: 140; cursorShape: Qt.PointingHandCursor; onClicked: finestra.apriApp(rigaMia.a) }
                            }
                        }
                    }

                    // ══ Pagina di un'app ════════════════════════════════════
                    ColumnLayout {
                        id: paginaApp
                        visible: finestra.pagina === "app" && finestra.scheda !== null
                        Layout.fillWidth: true; spacing: 22
                        readonly property var s: finestra.scheda || ({})
                        Text {
                            text: "‹ " + I18n.t("Indietro"); color: Tema.accento; font.family: Tema.font; font.pixelSize: 14
                            MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: finestra.vai(finestra.paginaPrima) }
                        }
                        // Intestazione: icona, nome, sviluppatore, pulsanti
                        RowLayout {
                            Layout.fillWidth: true; spacing: 22
                            IconaApp { app: paginaApp.s; lato: 120 }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 4
                                Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: paginaApp.s.nome || ""; color: Tema.testo; font.family: Tema.font; font.pixelSize: 30; font.weight: Font.Bold }
                                Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: paginaApp.s.descrizioneBreve || ""; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 15 }
                                Text { visible: text !== ""; text: paginaApp.s.sviluppatore || ""; color: Tema.accento; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.Medium }
                                Item { Layout.preferredHeight: 6 }
                                RowLayout {
                                    spacing: 10
                                    PulsanteApp { app: paginaApp.s; visible: paginaApp.s.disponibile !== false }
                                    Pulsante {
                                        visible: finestra.installata(paginaApp.s.id || "")
                                        text: I18n.t("Rimuovi"); pericoloso: true; enabled: finestra.occupata === ""
                                        onClicked: finestra.rimuovi(paginaApp.s)
                                    }
                                    Text { visible: paginaApp.s.disponibile === false; text: I18n.t("Non disponibile per questo computer"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13 }
                                }
                            }
                        }
                        // Informazioni in breve
                        Rectangle {
                            visible: paginaApp.s.caricata === true
                            Layout.fillWidth: true; Layout.preferredHeight: 74; radius: 14
                            color: Tema.chiaro ? "#FFFFFF" : "#1A2030"; border.color: Tema.chiaro ? "#E2E8F0" : "#262F42"
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 6; spacing: 0
                                Repeater {
                                    model: [
                                        { t: I18n.t("Versione"), v: paginaApp.s.versione || "—" },
                                        { t: I18n.t("Download"), v: paginaApp.s.scarica || "—" },
                                        { t: I18n.t("Spazio"), v: paginaApp.s.occupa || "—" },
                                        { t: I18n.t("Licenza"), v: paginaApp.s.libera ? I18n.t("Libera") : I18n.t("Proprietaria") },
                                        { t: I18n.t("Aggiornata"), v: paginaApp.s.data || "—" }
                                    ]
                                    ColumnLayout {
                                        required property var modelData
                                        Layout.fillWidth: true; spacing: 2
                                        Text { Layout.alignment: Qt.AlignHCenter; text: parent.modelData.t.toUpperCase(); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 0.8 }
                                        Text { Layout.alignment: Qt.AlignHCenter; text: parent.modelData.v; color: Tema.testo; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.DemiBold }
                                    }
                                }
                            }
                        }
                        // Foto dello schermo
                        ListView {
                            visible: (paginaApp.s.foto || []).length > 0
                            Layout.fillWidth: true; Layout.preferredHeight: 340
                            orientation: ListView.Horizontal
                            spacing: 14; clip: true
                            model: paginaApp.s.foto || []
                            ScrollBar.horizontal: ScrollBar {}
                            delegate: Rectangle {
                                required property var modelData
                                height: 324; width: Math.max(200, foto.status === Image.Ready ? foto.implicitWidth * height / Math.max(1, foto.implicitHeight) : 560)
                                radius: 14; clip: true
                                color: Tema.chiaro ? "#E9EDF1" : "#1A2030"
                                Image {
                                    id: foto
                                    anchors.fill: parent
                                    source: parent.modelData.url
                                    fillMode: Image.PreserveAspectFit; asynchronous: true; smooth: true
                                    sourceSize.height: 648
                                }
                                Text { anchors.centerIn: parent; visible: foto.status !== Image.Ready; text: I18n.t("Caricamento…"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13 }
                            }
                        }
                        // Descrizione e novità
                        Text {
                            visible: text !== ""
                            Layout.fillWidth: true; wrapMode: Text.Wrap; textFormat: Text.RichText
                            text: paginaApp.s.descrizione || ""
                            color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; lineHeight: 1.3
                        }
                        ColumnLayout {
                            visible: (paginaApp.s.novita || "") !== ""
                            Layout.fillWidth: true; spacing: 8
                            Text { text: I18n.t("Novità") + (paginaApp.s.versione ? " · " + I18n.t("versione") + " " + paginaApp.s.versione : ""); color: Tema.testo; font.family: Tema.font; font.pixelSize: 18; font.weight: Font.Bold }
                            Text { Layout.fillWidth: true; wrapMode: Text.Wrap; textFormat: Text.RichText; text: paginaApp.s.novita || ""; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13; lineHeight: 1.3 }
                        }
                        // Nelle raccolte
                        ColumnLayout {
                            visible: finestra.raccolteApp.length > 0
                            Layout.fillWidth: true; spacing: 10
                            Text { text: I18n.t("Nelle raccolte"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 18; font.weight: Font.Bold }
                            Flow {
                                Layout.fillWidth: true; spacing: 10
                                Repeater {
                                    model: finestra.raccolteApp
                                    Rectangle {
                                        id: chipRaccolta
                                        required property var modelData
                                        height: 46; width: nomeR.implicitWidth + 64; radius: 12
                                        color: Tema.chiaro ? "#FFFFFF" : "#26272D"
                                        Rectangle {
                                            x: 7; anchors.verticalCenter: parent.verticalCenter; width: 32; height: 32; radius: 9
                                            gradient: Gradient { GradientStop { position: 0; color: chipRaccolta.modelData.colori[0] } GradientStop { position: 1; color: chipRaccolta.modelData.colori[1] } }
                                        }
                                        Text { id: nomeR; x: 50; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: { var id = parent.modelData.id; var t = finestra.raccolte.filter(function (x) { return x.id === id }); if (t.length) finestra.apriRaccolta(t[0]) }
                                        }
                                    }
                                }
                            }
                        }
                        // Recensioni di chi usa SolidOS
                        ColumnLayout {
                            visible: paginaApp.s.origine !== "apt"
                            Layout.fillWidth: true; spacing: 12
                            readonly property var rr: finestra.recensioni.riepilogo || ({ media: 0, totale: 0, distribuzione: [0, 0, 0, 0, 0] })
                            RowLayout {
                                Layout.fillWidth: true
                                Text { Layout.fillWidth: true; text: I18n.t("Recensioni"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 18; font.weight: Font.Bold }
                                Pulsante {
                                    text: (finestra.recensioni.elenco || []).some(function (x) { return x.mia }) ? I18n.t("Modifica la tua") : I18n.t("Scrivi una recensione")
                                    icona: "document-edit-symbolic"
                                    onClicked: scrittura.apri()
                                }
                            }
                            RowLayout {
                                visible: parent.rr.totale > 0
                                Layout.fillWidth: true; spacing: 22
                                ColumnLayout {
                                    spacing: 0
                                    Text { Layout.alignment: Qt.AlignHCenter; text: String(parent.parent.parent.rr.media).replace(".", ","); color: Tema.testo; font.family: Tema.font; font.pixelSize: 46; font.weight: Font.Bold }
                                    Text { Layout.alignment: Qt.AlignHCenter; text: I18n.t("su 5"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                                }
                                ColumnLayout {
                                    Layout.preferredWidth: 280; spacing: 4
                                    Repeater {
                                        model: 5
                                        RowLayout {
                                            required property int index
                                            spacing: 8
                                            Text { text: 5 - parent.index; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11; font.weight: Font.DemiBold }
                                            Rectangle {
                                                Layout.fillWidth: true; height: 6; radius: 3; color: Tema.chiaro ? "#E9E9EE" : "#2F3037"
                                                readonly property var rr: finestra.recensioni.riepilogo
                                                Rectangle { height: parent.height; radius: 3; color: Tema.testoSecondario
                                                            width: parent.width * (parent.rr.totale ? parent.rr.distribuzione[parent.parent.index] / parent.rr.totale : 0) }
                                            }
                                        }
                                    }
                                }
                                Text { Layout.fillWidth: true; text: parent.parent.rr.totale + " " + (parent.parent.rr.totale === 1 ? I18n.t("voto") : I18n.t("voti")); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                            }
                            Text {
                                visible: parent.rr.totale === 0
                                text: I18n.t("Nessuna recensione ancora: scrivi la prima.")
                                color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 14
                            }
                            Repeater {
                                model: finestra.recensioni.elenco || []
                                Rectangle {
                                    id: rec
                                    required property var modelData
                                    Layout.fillWidth: true; Layout.preferredHeight: colRec.implicitHeight + 24; radius: 14
                                    color: Tema.chiaro ? "#FFFFFF" : "#26272D"
                                    ColumnLayout {
                                        id: colRec
                                        x: 16; y: 12; width: parent.width - 32; spacing: 4
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: 8
                                            Stelle { voto: rec.modelData.voto; lato: 12 }
                                            Text { Layout.fillWidth: true; elide: Text.ElideRight; text: (rec.modelData.titolo ? rec.modelData.titolo + " · " : "") + rec.modelData.nome + (rec.modelData.mia ? " (" + I18n.t("tu") + ")" : ""); color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                                            Text { text: rec.modelData.quando || ""; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                                        }
                                        Text { Layout.fillWidth: true; visible: text !== ""; wrapMode: Text.Wrap; text: rec.modelData.testo || ""; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13; lineHeight: 1.25 }
                                        Text {
                                            visible: !rec.modelData.mia
                                            text: I18n.t("Utile") + (rec.modelData.utili ? " (" + rec.modelData.utili + ")" : ""); color: Tema.accento; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold
                                            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: ponte.avvia("recensioneUtile", [rec.modelData.id], "utile") }
                                        }
                                    }
                                }
                            }
                        }
                        Text {
                            visible: (paginaApp.s.sito || "") !== ""
                            text: I18n.t("Sito dello sviluppatore") + " ›"
                            color: Tema.accento; font.family: Tema.font; font.pixelSize: 14
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Qt.openUrlExternally(paginaApp.s.sito) }
                        }
                    }
                }
            }
        }
    }

    // ── Scrivi una recensione ──────────────────────────────────────────────
    Popup {
        id: scrittura
        property int voto: 0
        function apri() {
            var mia = (finestra.recensioni.elenco || []).filter(function (x) { return x.mia })
            voto = mia.length ? mia[0].voto : 0
            titoloRec.text = mia.length ? mia[0].titolo : ""
            testoRec.text = mia.length ? mia[0].testo : ""
            open()
        }
        anchors.centerIn: parent
        width: 480; modal: true; padding: 24
        background: Rectangle { radius: 18; color: Tema.chiaro ? "#FFFFFF" : "#26272D"; border.color: Tema.chiaro ? "#E5E5EA" : "#3A3B42" }
        contentItem: ColumnLayout {
            spacing: 14
            Text { text: I18n.t("Scrivi una recensione"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 20; font.weight: Font.Bold }
            Text {
                visible: !finestra.recensioni.account || !finestra.recensioni.account.collegato
                Layout.fillWidth: true; wrapMode: Text.Wrap
                text: I18n.t("Per scrivere una recensione accedi al Solid ID da Impostazioni › Account.")
                color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13
            }
            RowLayout {
                spacing: 8
                Repeater {
                    model: 5
                    Text {
                        required property int index
                        text: "★"; font.pixelSize: 36
                        color: index < scrittura.voto ? "#F5A524" : (Tema.chiaro ? "#D4D4D8" : "#4A4B52")
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scrittura.voto = parent.index + 1 }
                    }
                }
                Text { text: scrittura.voto ? ["", I18n.t("Pessima"), I18n.t("Così così"), I18n.t("Buona"), I18n.t("Molto buona"), I18n.t("Ottima")][scrittura.voto] : I18n.t("Tocca le stelle"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13 }
            }
            CampoTesto { id: titoloRec; Layout.fillWidth: true; placeholderText: I18n.t("Titolo (facoltativo)"); maximumLength: 80 }
            ScrollView {
                Layout.fillWidth: true; Layout.preferredHeight: 130
                TextArea {
                    id: testoRec
                    wrapMode: TextArea.Wrap
                    placeholderText: I18n.t("Cosa ti piace, cosa no, a cosa ti serve…")
                    color: Tema.testo; font.family: Tema.font; font.pixelSize: 14
                    background: Rectangle { radius: 10; color: Tema.chiaro ? "#F2F2F7" : "#2F3037" }
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                Pulsante {
                    visible: (finestra.recensioni.elenco || []).some(function (x) { return x.mia })
                    text: I18n.t("Togli la mia"); pericoloso: true
                    onClicked: ponte.avvia("cancellaRecensione", [finestra.scheda.id], "cancellaRecensione")
                }
                Item { Layout.fillWidth: true }
                Pulsante { text: I18n.t("Annulla"); onClicked: scrittura.close() }
                Pulsante {
                    principale: true; text: I18n.t("Pubblica")
                    enabled: scrittura.voto > 0 && finestra.recensioni.account && finestra.recensioni.account.collegato
                    onClicked: ponte.avvia("scriviRecensione", [finestra.scheda.id, scrittura.voto, titoloRec.text, testoRec.text], "scriviRecensione")
                }
            }
        }
    }
}
