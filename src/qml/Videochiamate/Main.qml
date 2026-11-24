// Videochiamate: in alto si scrive l'email del Solid ID da chiamare (video o solo audio); sotto
// i preferiti, le chiamate recenti (in uscita, in arrivo, perse) e i contatti con un'email.
// Durante la chiamata la finestra mostra la pagina della chiamata (Chiamata.qml).
// Aperta dal servizio degli avvisi con una chiamata in arrivo, mostra subito Rispondi e Rifiuta.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Videochiamate")
    width: 980
    height: 680
    minimumWidth: 480
    minimumHeight: 520

    property var conf: ({})
    property var recenti: []
    property var preferiti: []
    property var contatti: []
    property bool inChiamata: false
    property bool soloArrivo: false        // aperta per una chiamata in arrivo: alla fine si chiude
    property bool uscendo: false
    property var attuale: null              // {id, nome, email, verso, video}
    property var daAvviare: null
    property bool cercando: false
    property bool videoScelto: true

    function ricarica() {
        conf = ponte.chiama0("configurazione")
        recenti = ponte.chiama0("recenti")
        preferiti = ponte.chiama0("preferiti")
        contatti = ponte.chiama0("contatti")
    }
    function chiamaEmail(email, video) {
        if (!conf.ok) { avviso.mostra(conf.motivo); return }
        cercando = true; videoScelto = video
        ponte.avvia("persona", [email], "persona")
    }
    function chiama(p, video) {
        conf = ponte.chiama0("configurazione")
        if (!conf.ok) { avviso.mostra(conf.motivo); return }
        attuale = { id: p.id, nome: p.nome, email: p.email, verso: "uscita", video: video }
        daAvviare = { modo: "chiama", a: p.id, nome: p.nome, email: p.email, video: video }
        inizia()
    }
    function arrivo(off) {
        conf = ponte.chiama0("configurazione")
        if (!conf.ok) { Qt.quit(); return }
        soloArrivo = true
        finestra.width = 440; finestra.height = 640
        attuale = { id: off.da, nome: off.dati.nome || off.dati.email || I18n.t("Chiamata"), email: off.dati.email || "", verso: "entrata", video: !!off.dati.video, chiamata: off.chiamata }
        daAvviare = { modo: "arrivo", nome: attuale.nome, offerta: off }
        inizia()
    }
    function inizia() {
        inChiamata = true
        ponte.chiama("inChiamata", [true])
        vistaChiamata.active = true
        if (vistaChiamata.status === Loader.Error) { avviso.mostra(I18n.t("Il motore web per le chiamate non è disponibile")); finita({ motivo: "errore", durata: 0 }) }
    }
    function finita(d) {
        ponte.chiama("squillo", [false])
        ponte.chiama("inChiamata", [false])
        if (attuale) {
            var verso = attuale.verso === "entrata" && !d.connessa && d.motivo !== "rifiutata-da-me" && d.motivo !== "altrove" ? "persa" : attuale.verso
            if (d.motivo !== "altrove")
                ponte.chiama("registra", [{ chiamata: d.chiamata || attuale.chiamata, id: attuale.id, nome: attuale.nome, email: attuale.email, verso: verso, video: d.video !== undefined ? d.video : attuale.video, durata: d.durata || 0 }])
            if (verso === "persa") ponte.chiama("avvisoPersa", [attuale.nome])
        }
        inChiamata = false
        vistaChiamata.active = false
        attuale = null
        if (soloArrivo || uscendo) { Qt.quit(); return }
        ricarica()
    }

    Component.onCompleted: {
        ricarica()
        var a = ponte.chiama0("avvio")
        if (a.inArrivo) arrivo(a.inArrivo)
        else if (a.chiama) chiamaEmail(a.chiama, true)
    }
    onClosing: function (chiusura) {
        if (inChiamata && !uscendo) {
            chiusura.accepted = false
            uscendo = true
            if (vistaChiamata.item) vistaChiamata.item.chiudi()
            esci.start()
        }
    }
    Timer { id: esci; interval: 2500; onTriggered: Qt.quit() }
    // il token di Solid ID dura un'ora: durante la chiamata si rinnova
    Timer { interval: 20 * 60 * 1000; repeat: true; running: finestra.inChiamata; onTriggered: if (vistaChiamata.item) vistaChiamata.item.token(ponte.chiama0("token")) }

    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id !== "persona") return
            finestra.cercando = false
            if (r.ok) finestra.chiama(r, finestra.videoScelto)
            else avviso.mostra(r.messaggio)
        }
    }

    // ── Chiamata ──
    Loader {
        id: vistaChiamata
        anchors.fill: parent
        z: 10
        active: false
        visible: active
        source: "Chiamata.qml"
        onStatusChanged: if (status === Loader.Error && finestra.inChiamata) { avviso.mostra(I18n.t("Il motore web per le chiamate non è disponibile")); finestra.finita({ motivo: "errore", durata: 0 }) }
    }
    Connections {
        target: vistaChiamata.item
        ignoreUnknownSignals: true
        function onPronta() { if (finestra.daAvviare) { vistaChiamata.item.avvia(finestra.conf, finestra.daAvviare, ponte.chiama0("traduzioni")); finestra.daAvviare = null } }
        function onEvento(nome, d) {
            if (nome === "squillo") ponte.chiama("squillo", [d.attivo, !!d.uscita])
            else if (nome === "iniziata" && finestra.attuale) { var a = finestra.attuale; a.chiamata = d.chiamata; finestra.attuale = a }
            else if (nome === "fine") finestra.finita(d)
        }
    }

    // ── Elenco ──
    Flickable {
        anchors.fill: parent
        visible: !finestra.inChiamata
        contentHeight: colonna.implicitHeight + 40
        clip: true
        ScrollBar.vertical: ScrollBar {}
        ColumnLayout {
            id: colonna
            width: Math.min(parent.width - 48, 760)
            x: (parent.width - width) / 2
            y: 24
            spacing: 18

            Text { text: I18n.t("Videochiamate"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 28; font.weight: Font.Bold }

            // senza Solid ID
            Rectangle {
                visible: !finestra.conf.ok
                Layout.fillWidth: true
                Layout.preferredHeight: testoAccesso.implicitHeight + 32
                radius: 12; color: Tema.superficie
                RowLayout {
                    anchors.fill: parent; anchors.margins: 16; spacing: 12
                    Simbolo { nome: "info"; lato: 22; colore: Tema.accento }
                    Text { id: testoAccesso; Layout.fillWidth: true; wrapMode: Text.WordWrap; text: finestra.conf.motivo || ""; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
                    Pulsante { text: I18n.t("Riprova"); onClicked: finestra.ricarica() }
                }
            }

            // chiama un Solid ID
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                radius: 14; color: Tema.superficie
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 10
                    spacing: 10
                    Simbolo { nome: "cerca"; lato: 18; colore: Tema.testoSecondario }
                    TextField {
                        id: campoEmail
                        Layout.fillWidth: true
                        placeholderText: I18n.t("Email del Solid ID da chiamare")
                        color: Tema.testo; placeholderTextColor: Tema.testoSecondario
                        font.family: Tema.font; font.pixelSize: 15
                        background: null
                        inputMethodHints: Qt.ImhEmailCharactersOnly
                        onAccepted: if (text.includes("@")) finestra.chiamaEmail(text, true)
                    }
                    BusyIndicator { visible: finestra.cercando; running: visible; Layout.preferredWidth: 24; Layout.preferredHeight: 24 }
                    TastoChiamata { simbolo: "telefono"; suggerimento: I18n.t("Chiamata audio"); attivo: campoEmail.text.includes("@") && !finestra.cercando; onClicked: finestra.chiamaEmail(campoEmail.text, false) }
                    TastoChiamata { simbolo: "video"; suggerimento: I18n.t("Videochiamata"); principale: true; attivo: campoEmail.text.includes("@") && !finestra.cercando; onClicked: finestra.chiamaEmail(campoEmail.text, true) }
                }
            }
            Text {
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                text: I18n.t("Audio e video vanno direttamente da un dispositivo all'altro, cifrati. Puoi chiamare chi ha un Solid ID, sul computer o sul telefono, e anche i tuoi altri dispositivi con la tua email.")
                color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
            }

            // preferiti
            Text { visible: finestra.preferiti.length > 0; text: I18n.t("Preferiti"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 17; font.weight: Font.Bold }
            Flow {
                visible: finestra.preferiti.length > 0
                Layout.fillWidth: true; spacing: 18
                Repeater {
                    model: finestra.preferiti
                    Column {
                        spacing: 6
                        width: 84
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 64; height: 64; radius: 32
                            color: finestra.colore(modelData.email)
                            Text { anchors.centerIn: parent; text: (modelData.nome || "?").charAt(0).toUpperCase(); color: "white"; font.family: Tema.font; font.pixelSize: 26; font.weight: Font.Bold }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: finestra.chiama(modelData, true) }
                        }
                        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 12 }
                    }
                }
            }

            // recenti
            RowLayout {
                Layout.fillWidth: true
                Text { text: I18n.t("Recenti"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 17; font.weight: Font.Bold; Layout.fillWidth: true }
                Text {
                    visible: finestra.recenti.length > 0
                    text: I18n.t("Cancella"); color: Tema.accento; font.family: Tema.font; font.pixelSize: 13
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ponte.chiama0("cancellaRecenti"); finestra.ricarica() } }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: finestra.recenti.length ? listaRecenti.implicitHeight : 64
                radius: 12; color: Tema.superficie
                Text { anchors.centerIn: parent; visible: finestra.recenti.length === 0; text: I18n.t("Nessuna chiamata"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 14 }
                ColumnLayout {
                    id: listaRecenti
                    width: parent.width
                    spacing: 0
                    Repeater {
                        model: finestra.recenti.slice(0, 30)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 58
                            color: sopraR.hovered ? Qt.rgba(0.5, 0.5, 0.5, 0.07) : "transparent"
                            radius: 12
                            HoverHandler { id: sopraR }
                            readonly property bool preferito: finestra.preferiti.some(function (p) { return p.id === modelData.id })
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 10
                                spacing: 12
                                Rectangle {
                                    width: 38; height: 38; radius: 19; color: finestra.colore(modelData.email)
                                    Text { anchors.centerIn: parent; text: (modelData.nome || "?").charAt(0).toUpperCase(); color: "white"; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.Bold }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 1
                                    Text { text: modelData.nome; color: modelData.verso === "persa" ? "#EF4444" : Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                    RowLayout {
                                        spacing: 5
                                        Simbolo { nome: modelData.video ? "video" : "telefono"; lato: 13; colore: Tema.testoSecondario }
                                        Text {
                                            text: (modelData.verso === "uscita" ? I18n.t("In uscita") : modelData.verso === "entrata" ? I18n.t("In arrivo") : I18n.t("Persa"))
                                                  + (modelData.durataTesto ? " · " + modelData.durataTesto : "")
                                            color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                                        }
                                    }
                                }
                                Text { text: modelData.quando; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                                Simbolo {
                                    visible: sopraR.hovered || parent.parent.preferito
                                    nome: parent.parent.preferito ? "stella-piena" : "stella"; lato: 17; colore: parent.parent.preferito ? "#F59E0B" : Tema.testoSecondario
                                    MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: finestra.preferiti = ponte.chiama("preferito", [modelData, !parent.parent.parent.preferito]) }
                                }
                                TastoChiamata { simbolo: "telefono"; suggerimento: I18n.t("Chiamata audio"); onClicked: finestra.chiama(modelData, false) }
                                TastoChiamata { simbolo: "video"; suggerimento: I18n.t("Videochiamata"); onClicked: finestra.chiama(modelData, true) }
                            }
                        }
                    }
                }
            }

            // contatti
            Text { visible: finestra.contatti.length > 0; text: I18n.t("Contatti"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 17; font.weight: Font.Bold }
            Rectangle {
                visible: finestra.contatti.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: listaContatti.implicitHeight
                radius: 12; color: Tema.superficie
                ColumnLayout {
                    id: listaContatti
                    width: parent.width
                    spacing: 0
                    Repeater {
                        model: finestra.contatti
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            radius: 12
                            color: sopraC.hovered ? Qt.rgba(0.5, 0.5, 0.5, 0.07) : "transparent"
                            HoverHandler { id: sopraC }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 10
                                spacing: 12
                                Rectangle {
                                    width: 34; height: 34; radius: 17; color: finestra.colore(modelData.email)
                                    Text { anchors.centerIn: parent; text: modelData.nome.charAt(0).toUpperCase(); color: "white"; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.Bold }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 0
                                    Text { text: modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }
                                    Text { text: modelData.email; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                                }
                                TastoChiamata { simbolo: "telefono"; suggerimento: I18n.t("Chiamata audio"); onClicked: finestra.chiamaEmail(modelData.email, false) }
                                TastoChiamata { simbolo: "video"; suggerimento: I18n.t("Videochiamata"); onClicked: finestra.chiamaEmail(modelData.email, true) }
                            }
                        }
                    }
                }
            }
        }
    }

    function colore(t) {
        var c = ["#3B82F6", "#8B5CF6", "#EC4899", "#F97316", "#14B8A6", "#22C55E", "#64748B"], h = 0
        t = t || ""
        for (var i = 0; i < t.length; i++) h = (h * 31 + t.charCodeAt(i)) % 997
        return c[h % c.length]
    }

    component TastoChiamata: Rectangle {
        property string simbolo
        property string suggerimento
        property bool principale: false
        property bool attivo: true
        signal clicked()
        width: 38; height: 38; radius: 19
        opacity: attivo ? 1 : 0.4
        color: principale ? "#22C55E" : (sopraT.hovered ? Tema.superficieAlta : Qt.rgba(0.13, 0.77, 0.37, 0.14))
        HoverHandler { id: sopraT }
        Simbolo { anchors.centerIn: parent; nome: parent.simbolo; lato: 18; colore: parent.principale ? "#FFFFFF" : "#22C55E" }
        MouseArea { anchors.fill: parent; enabled: parent.attivo; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
        ToolTip.visible: sopraT.hovered; ToolTip.text: suggerimento; ToolTip.delay: 500
        Accessible.role: Accessible.Button; Accessible.name: suggerimento
    }

    Messaggio { id: avviso }
}
