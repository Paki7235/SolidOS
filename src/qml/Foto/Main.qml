// Foto: la Libreria come sul telefono (per giorno, Preferite, Schermate, Scaricati, foto degli
// account collegati con il simbolino del servizio) e il visualizzatore:
// frecce ← → per scorrere, rotella per lo zoom, R per ruotare, F schermo intero, Esc torna alla Libreria.
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window
import SolidUI

Finestra {
    id: finestra
    width: 1000
    height: 700
    color: pagina === "visore" ? "#0E0F12" : Tema.sfondo
    property string pagina: "libreria"     // libreria | account | visore
    property string album: "tutte"          // tutte | preferite | schermate | scaricati | account
    property var libreria: []
    property var servizi: []
    property bool daLibreria: false
    readonly property var mostrate: libreria.filter(function (f) {
        if (album === "preferite") return f.preferita
        if (album === "schermate") return f.album === "schermate"
        if (album === "scaricati") return f.album === "scaricati"
        if (album === "account") return f.fonte !== "computer"
        return true
    })
    // le foto raggruppate per giorno: [{giorno, foto: [...]}]
    readonly property var giorni: {
        var g = [], ultimo = null
        for (var i = 0; i < mostrate.length; i++) {
            if (!ultimo || ultimo.giorno !== mostrate[i].giorno) { ultimo = { giorno: mostrate[i].giorno, foto: [] }; g.push(ultimo) }
            ultimo.foto.push(mostrate[i])
        }
        return g
    }
    readonly property var coloriFonte: ({ nextcloud: "#0082C9", casa: "#30A46C", onedrive: "#0078D4", dropbox: "#0061FE", google: "#4285F4" })
    function ricaricaLibreria() { libreria = ponte.chiama0("libreria"); servizi = ponte.chiama0("servizi") }
    function apriDallaLibreria(percorso) {
        elenco = mostrate.map(function (f) { return f.percorso })
        indice = Math.max(0, elenco.indexOf(percorso))
        zoom = 1; rotazione = 0
        daLibreria = true
        pagina = "visore"
    }
    function preferitaCorrente() {
        for (var i = 0; i < libreria.length; i++) if (libreria[i].percorso === corrente) return libreria[i].preferita === true
        return false
    }
    function alternaPreferita(percorso) {
        var lib = libreria.slice()
        for (var i = 0; i < lib.length; i++) if (lib[i].percorso === percorso) {
            lib[i] = Object.assign({}, lib[i], { preferita: !lib[i].preferita })
            ponte.chiama("preferita", [percorso, lib[i].preferita])
        }
        libreria = lib
    }
    property var elenco: []
    property int indice: -1
    readonly property string corrente: indice >= 0 && indice < elenco.length ? elenco[indice] : ""
    property real zoom: 1
    property int rotazione: 0
    title: (corrente ? corrente.split("/").pop() + " — " : "") + I18n.t("Foto")

    function apri(p) {
        p = p.replace("file://", "")
        pagina = "visore"
        elenco = ponte.chiama("elenco", [p])
        indice = Math.max(0, elenco.indexOf(p))
        zoom = 1; rotazione = 0
    }
    function vai(d) { if (elenco.length) { indice = (indice + d + elenco.length) % elenco.length; zoom = 1; rotazione = 0 } }

    Component.onCompleted: {
        var f = ponte.chiama0("fileIniziale")
        if (f) apri(f)
        else { ricaricaLibreria(); ponte.avvia("sincronizza", [], "sincronizza") }   // foto nuove degli account
    }
    Connections {
        target: ponte
        function onCompletato(id, r) { if (id === "sincronizza") finestra.libreria = ponte.chiama0("libreria") }
    }

    Shortcut { sequence: "Right"; onActivated: finestra.vai(1) }
    Shortcut { sequence: "Left"; onActivated: finestra.vai(-1) }
    Shortcut { sequence: "R"; onActivated: finestra.rotazione = (finestra.rotazione + 90) % 360 }
    Shortcut { sequence: "F"; onActivated: finestra.visibility = finestra.visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen }
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (finestra.visibility === Window.FullScreen) finestra.visibility = Window.Windowed
            else if (finestra.pagina === "visore") { finestra.pagina = "libreria"; if (!finestra.libreria.length) finestra.ricaricaLibreria() }
        }
    }
    Shortcut { sequence: "Delete"; onActivated: elimina.open() }
    Shortcut { sequence: StandardKey.Open; onActivated: dialogoApri.open() }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        visible: finestra.pagina === "visore"
        Barra {
            Layout.fillWidth: true
            visible: finestra.visibility !== Window.FullScreen
            titolo: finestra.elenco.length ? (finestra.indice + 1) + " " + I18n.t("di") + " " + finestra.elenco.length : I18n.t("Foto")
            Pulsante { text: "‹ " + I18n.t("Libreria"); onClicked: { finestra.pagina = "libreria"; if (!finestra.libreria.length) finestra.ricaricaLibreria() } }
            Pulsante { text: I18n.t("Apri…"); onClicked: dialogoApri.open() }
            Pulsante {
                text: finestra.preferitaCorrente() ? "♥" : "♡"
                enabled: !!finestra.corrente
                onClicked: { if (!finestra.libreria.length) finestra.ricaricaLibreria(); finestra.alternaPreferita(finestra.corrente) }
            }
            Pulsante { icona: "object-rotate-left-symbolic"; enabled: !!finestra.corrente; onClicked: finestra.rotazione = (finestra.rotazione + 270) % 360 }
            Pulsante { icona: "object-rotate-right-symbolic"; enabled: !!finestra.corrente; onClicked: finestra.rotazione = (finestra.rotazione + 90) % 360 }
            Pulsante { text: presentazione.running ? I18n.t("Ferma") : I18n.t("Presentazione"); enabled: finestra.elenco.length > 1; onClicked: presentazione.running = !presentazione.running }
            Pulsante { text: I18n.t("Usa come sfondo"); enabled: !!finestra.corrente; onClicked: { ponte.chiama("usaComeSfondo", [finestra.corrente]); finestra.avviso(I18n.t("Sfondo cambiato")) } }
            Pulsante { text: I18n.t("Elimina"); pericoloso: true; enabled: !!finestra.corrente; onClicked: elimina.open() }
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            Image {
                id: immagine
                anchors.centerIn: parent
                width: parent.width; height: parent.height
                source: finestra.corrente ? "file://" + finestra.corrente : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                autoTransform: true
                smooth: true
                mipmap: true
                scale: finestra.zoom
                rotation: finestra.rotazione
                Behavior on rotation { enabled: Tema.animazioni; NumberAnimation { duration: 160 } }
            }
            BusyIndicator { anchors.centerIn: parent; running: immagine.status === Image.Loading }
            Column {
                anchors.centerIn: parent
                visible: !finestra.corrente
                spacing: 12
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Nessuna immagine aperta"); color: "#A1A1AA"; font.family: Tema.font; font.pixelSize: 15 }
                Pulsante { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Apri un'immagine…"); principale: true; onClicked: dialogoApri.open() }
            }
            MouseArea {
                anchors.fill: parent
                onWheel: function (w) { finestra.zoom = Math.max(0.2, Math.min(8, finestra.zoom * (w.angleDelta.y > 0 ? 1.15 : 1 / 1.15))) }
                onDoubleClicked: finestra.zoom = finestra.zoom === 1 ? 2 : 1
            }
            // Frecce ai lati
            Repeater {
                model: [-1, 1]
                Rectangle {
                    visible: finestra.elenco.length > 1
                    width: 44; height: 44; radius: 22
                    anchors.verticalCenter: parent.verticalCenter
                    x: modelData < 0 ? 16 : parent.width - width - 16
                    color: ma.containsMouse ? "#99000000" : "#55000000"
                    Text { anchors.centerIn: parent; text: modelData < 0 ? "‹" : "›"; color: "#FFFFFF"; font.pixelSize: 28 }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: finestra.vai(modelData) }
                }
            }
            DropArea { anchors.fill: parent; onDropped: function (d) { if (d.hasUrls) finestra.apri(d.urls[0].toString()) } }
        }
    }
    // ── Libreria e Account collegati ──
    RowLayout {
        anchors.fill: parent
        spacing: 0
        visible: finestra.pagina !== "visore"

        Rectangle {
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            color: Tema.superficie
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 2
                Text { text: I18n.t("Foto"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 20; font.weight: Font.Bold; Layout.bottomMargin: 10; Layout.leftMargin: 6 }
                Repeater {
                    model: [
                        { id: "tutte", t: I18n.t("Libreria"), s: "▦" }, { id: "preferite", t: I18n.t("Preferite"), s: "♥" },
                        { id: "schermate", t: I18n.t("Schermate"), s: "▭" }, { id: "scaricati", t: I18n.t("Scaricati"), s: "↓" },
                        { id: "account", t: I18n.t("Dagli account"), s: "☁" }
                    ]
                    Rectangle {
                        Layout.fillWidth: true
                        height: 34; radius: 8
                        readonly property bool attivo: finestra.pagina === "libreria" && finestra.album === modelData.id
                        color: attivo ? Tema.accento : (sopraVoce.hovered ? Tema.superficieAlta : "transparent")
                        HoverHandler { id: sopraVoce }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter; x: 10; spacing: 10
                            Text { text: modelData.s; width: 16; horizontalAlignment: Text.AlignHCenter; color: parent.parent.attivo ? "white" : Tema.accento; font.pixelSize: 14 }
                            Text { text: modelData.t; color: parent.parent.attivo ? "white" : Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
                        }
                        MouseArea { anchors.fill: parent; onClicked: { finestra.album = modelData.id; finestra.pagina = "libreria" } }
                    }
                }
                Text { text: I18n.t("Account"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11; font.weight: Font.DemiBold; Layout.topMargin: 16; Layout.leftMargin: 8 }
                Rectangle {
                    Layout.fillWidth: true
                    height: 34; radius: 8
                    readonly property bool attivo: finestra.pagina === "account"
                    color: attivo ? Tema.accento : (sopraAcc.hovered ? Tema.superficieAlta : "transparent")
                    HoverHandler { id: sopraAcc }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter; x: 10; spacing: 10
                        Text { text: "⚙"; width: 16; horizontalAlignment: Text.AlignHCenter; color: parent.parent.attivo ? "white" : Tema.accento; font.pixelSize: 14 }
                        Text { text: I18n.t("Account collegati"); color: parent.parent.attivo ? "white" : Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
                    }
                    MouseArea { anchors.fill: parent; onClicked: { finestra.servizi = ponte.chiama0("servizi"); finestra.pagina = "account" } }
                }
                Item { Layout.fillHeight: true }
                Pulsante { Layout.fillWidth: true; text: I18n.t("Apri un'immagine…"); onClicked: dialogoApri.open() }
            }
        }
        Rectangle { Layout.fillHeight: true; width: 1; color: Tema.bordo }

        // Griglia per giorno
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: finestra.pagina === "libreria"
            ListView {
                id: vistaGiorni
                anchors.fill: parent
                anchors.margins: 16
                clip: true
                spacing: 18
                model: finestra.giorni
                ScrollBar.vertical: ScrollBar {}
                readonly property int lato: Math.floor((width - 6 * 4) / Math.max(2, Math.round(width / 170)))
                delegate: Column {
                    width: vistaGiorni.width
                    spacing: 8
                    Text { text: modelData.giorno; color: Tema.testo; font.family: Tema.font; font.pixelSize: 17; font.weight: Font.DemiBold }
                    Flow {
                        width: parent.width
                        spacing: 4
                        Repeater {
                            model: modelData.foto
                            Item {
                                width: vistaGiorni.lato; height: vistaGiorni.lato
                                Rectangle { anchors.fill: parent; color: Tema.superficieAlta; radius: 4 }
                                Image {
                                    anchors.fill: parent
                                    source: modelData.uri
                                    sourceSize.width: 320; sourceSize.height: 320
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    autoTransform: true
                                    cache: true
                                    scale: tocco.pressed ? 0.97 : 1
                                    Behavior on scale { enabled: Tema.animazioni; NumberAnimation { duration: 90 } }
                                }
                                // simbolino del servizio da cui arriva la foto
                                Rectangle {
                                    visible: modelData.fonte !== "computer"
                                    x: 6; y: parent.height - 24; width: 18; height: 18; radius: 9
                                    color: finestra.coloriFonte[modelData.fonte] || "#666"
                                    Text { anchors.centerIn: parent; text: (modelData.fonte || "?").charAt(0).toUpperCase(); color: "white"; font.pixelSize: 10; font.weight: Font.Bold }
                                }
                                Text {
                                    visible: modelData.preferita === true || sopraFoto.hovered
                                    anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 6
                                    text: modelData.preferita ? "♥" : "♡"
                                    color: "white"; style: Text.Raised; styleColor: "#80000000"; font.pixelSize: 16
                                    MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: finestra.alternaPreferita(modelData.percorso) }
                                }
                                HoverHandler { id: sopraFoto }
                                MouseArea {
                                    id: tocco
                                    anchors.fill: parent
                                    z: -1
                                    onDoubleClicked: finestra.apriDallaLibreria(modelData.percorso)
                                    onClicked: finestra.apriDallaLibreria(modelData.percorso)
                                }
                            }
                        }
                    }
                }
            }
            Column {
                anchors.centerIn: parent
                visible: finestra.giorni.length === 0
                spacing: 8
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: finestra.album === "preferite" ? I18n.t("Nessuna foto preferita") : I18n.t("Nessuna foto")
                    color: Tema.testo; font.family: Tema.font; font.pixelSize: 17; font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: finestra.album === "preferite" ? I18n.t("Tocca ♡ su una foto per ritrovarla qui") : I18n.t("Le foto di Immagini e Scaricati compaiono qui, insieme a quelle degli account collegati")
                    color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13
                }
            }
        }

        // Account collegati
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: finestra.pagina === "account"
            contentHeight: colAccount.implicitHeight + 40
            clip: true
            ColumnLayout {
                id: colAccount
                x: 24; y: 20
                width: Math.min(640, parent.width - 48)
                spacing: 10
                Text { text: I18n.t("Account collegati"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 22; font.weight: Font.Bold }
                Text {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: I18n.t("Le foto dei tuoi servizi accanto a quelle del computer, come sul telefono. Si scaricano in una cartella a parte e si aggiornano quando apri Foto.")
                    color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13
                }
                // Questo computer come server di casa per il telefono
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: rigaCond.implicitHeight + 24
                    radius: 12
                    color: Tema.superficie
                    border.color: Tema.bordo
                    property var stato: finestra.pagina === "account" ? ponte.chiama0("condivisione") : ({})
                    RowLayout {
                        id: rigaCond
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 12
                        spacing: 12
                        Rectangle {
                            width: 36; height: 36; radius: 9; color: "#30A46C"
                            Text { anchors.centerIn: parent; text: "⌂"; color: "white"; font.pixelSize: 18 }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 1
                            Text { text: I18n.t("Condividi le foto di questo computer con i tuoi telefoni"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.DemiBold; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            Text {
                                Layout.fillWidth: true; wrapMode: Text.WordWrap
                                text: parent.parent.parent.stato.attiva
                                      ? I18n.t("Attiva: sul telefono, Foto › Account collegati › Server di casa lo trova da solo") + (parent.parent.parent.stato.indirizzo ? " (" + parent.parent.parent.stato.indirizzo + ")" : "")
                                      : I18n.t("La cartella Immagini, in sola lettura, solo nella rete di casa")
                                color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                            }
                        }
                        Interruttore {
                            checked: parent.parent.stato.attiva === true
                            onToggled: parent.parent.stato = ponte.chiama("condividi", [checked])
                        }
                    }
                }
                Repeater {
                    model: finestra.servizi
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: rigaServ.implicitHeight + 24
                        radius: 12
                        color: Tema.superficie
                        border.color: Tema.bordo
                        property bool aperto: false
                        ColumnLayout {
                            id: rigaServ
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                            anchors.margins: 12
                            spacing: 10
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                Rectangle {
                                    width: 36; height: 36; radius: 9; color: modelData.colore
                                    Text { anchors.centerIn: parent; text: modelData.lettera; color: "white"; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.Bold }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 1
                                    Text { text: modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.DemiBold }
                                    Text {
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                        text: modelData.stato === "collegato" ? I18n.t("Collegato") + (modelData.account.utente ? " · " + modelData.account.utente : "")
                                            : modelData.stato === "da_attivare" ? I18n.t("Da attivare: serve la registrazione di SolidOS presso il servizio")
                                            : modelData.descrizione
                                        color: modelData.stato === "collegato" ? "#22C55E" : Tema.testoSecondario
                                        font.family: Tema.font; font.pixelSize: 12
                                    }
                                }
                                Pulsante {
                                    visible: modelData.stato === "collegato"
                                    text: I18n.t("Scollega")
                                    onClicked: { avvisoFoto.mostra(ponte.chiama("scollega", [modelData.id]).messaggio); finestra.ricaricaLibreria() }
                                }
                                Pulsante {
                                    visible: modelData.stato === "collegabile"
                                    text: parent.parent.parent.aperto ? I18n.t("Chiudi") : I18n.t("Collega")
                                    principale: !parent.parent.parent.aperto
                                    onClicked: {
                                        var scheda = parent.parent.parent
                                        scheda.aperto = !scheda.aperto
                                        if (scheda.aperto && modelData.id === "casa") trovati.model = ponte.chiama0("scopriServer")
                                    }
                                }
                            }
                            // Modulo di collegamento (Nextcloud o server di casa)
                            ColumnLayout {
                                visible: parent.parent.aperto
                                Layout.fillWidth: true
                                spacing: 6
                                Repeater {
                                    id: trovati
                                    model: []
                                    Pulsante {
                                        text: "⌂ " + modelData.nome + "  (" + modelData.indirizzo + ")"
                                        onClicked: indirizzo.text = modelData.indirizzo
                                    }
                                }
                                CampoTesto { id: indirizzo; Layout.fillWidth: true; placeholderText: modelData.id === "casa" ? I18n.t("Indirizzo, es. 192.168.1.10:8765") : I18n.t("Indirizzo, es. cloud.esempio.it") }
                                CampoTesto { id: utente; Layout.fillWidth: true; placeholderText: modelData.id === "casa" ? I18n.t("Utente (se serve)") : I18n.t("Utente") }
                                CampoTesto { id: password; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: modelData.id === "casa" ? I18n.t("Password (se serve)") : I18n.t("Password per le app (Nextcloud › Impostazioni › Sicurezza)") }
                                CampoTesto { id: cartellaNc; visible: modelData.id === "nextcloud"; Layout.fillWidth: true; placeholderText: I18n.t("Cartella delle foto (Photos)") }
                                Pulsante {
                                    text: I18n.t("Collega")
                                    principale: true
                                    onClicked: {
                                        var r = modelData.id === "casa" ? ponte.chiama("collegaServer", [indirizzo.text, utente.text, password.text])
                                                                        : ponte.chiama("collegaNextcloud", [indirizzo.text, utente.text, password.text, cartellaNc.text])
                                        avvisoFoto.mostra(r.messaggio)
                                        if (r.ok) { finestra.servizi = ponte.chiama0("servizi"); ponte.avvia("sincronizza", [], "sincronizza") }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Messaggio { id: avvisoFoto }

    Timer { id: presentazione; interval: 4000; repeat: true; onTriggered: finestra.vai(1) }
    FileDialog { id: dialogoApri; nameFilters: [I18n.t("Immagini") + " (*.png *.jpg *.jpeg *.webp *.gif *.bmp *.svg *.tif *.tiff *.avif *.heic)"]; onAccepted: finestra.apri(selectedFile.toString()) }
    Dialog {
        id: elimina
        anchors.centerIn: parent
        modal: true
        title: I18n.t("Spostare l'immagine nel cestino?")
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: {
            var p = finestra.corrente
            if (ponte.chiama("cestino", [p])) { finestra.elenco = finestra.elenco.filter(function (x) { return x !== p }); finestra.indice = Math.min(finestra.indice, finestra.elenco.length - 1) }
        }
    }
}
