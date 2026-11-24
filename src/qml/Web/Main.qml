// Vela: il browser di SolidOS.
// Schede in alto · barra degli indirizzi che apre i siti o cerca · stella per i preferiti ·
// pagina «Nuova scheda» con ricerca e siti più visitati · download · cronologia ·
// finestra privata · zoom · trova nella pagina · tutto schermo per i video ·
// password: «Salvare la password?» dopo l'accesso a un sito e la chiave per compilare
// (cassaforte dell'app Password; lo script nelle pagine è password.js, in un mondo separato).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtWebEngine
import QtWebChannel
import SolidUI

Finestra {
    id: finestra
    width: 1200
    height: 780
    minimumWidth: 520
    readonly property bool privata: ponte.chiama0("privata")
    title: (vista && vista.title ? vista.title + " — " : "") + "Vela" + (privata ? " (" + I18n.t("privata") + ")" : "")
    property int corrente: 0
    property int contatore: 0
    readonly property var vista: ripetitore.count > corrente ? ripetitore.itemAt(corrente) : null
    property var conf: ponte.chiama0("impostazioni")
    property var preferiti: ponte.chiama0("preferiti")
    property var scaricamenti: []
    property var chiuse: []                 // per riaprire l'ultima scheda chiusa (Ctrl+Maiusc+T)
    property string linkSotto: ""
    property bool schermoIntero: false
    readonly property color accentoWeb: privata ? "#8B5CF6" : Tema.accento
    readonly property bool scaricando: scaricamenti.some(function (d) { return d && !d.isFinished })

    // ── Schede ───────────────────────────────────────────────────────────
    function nuovaScheda(url, inPrimoPiano) {
        contatore++
        schede.append({ uid: contatore, iniziale: url || "" })
        if (inPrimoPiano !== false) corrente = schede.count - 1
        if (!url) Qt.callLater(function () { campoNuova.forceActiveFocus() })
        return ripetitore.itemAt(schede.count - 1)
    }
    function chiudiScheda(i) {
        var v = ripetitore.itemAt(i)
        if (v && v.url.toString()) chiuse = chiuse.concat([v.url.toString()]).slice(-20)
        if (schede.count === 1) { Qt.quit(); return }
        schede.remove(i)
        if (corrente >= schede.count) corrente = schede.count - 1
        else if (i < corrente) corrente--
    }
    function vai(testo) {
        var u = ponte.chiama("indirizzo", [testo])
        if (!u) return
        if (!vista) nuovaScheda(u)
        else vista.url = u
        vista.forceActiveFocus()
        suggerimenti.close()
    }
    function nuovaPagina(v) { return !v || v.url.toString() === "" || v.url.toString() === "about:blank" }
    function testoIndirizzo(v) {
        if (nuovaPagina(v)) return ""
        return v.url.toString()
    }
    property string trovati: ""
    function richiesta(f) {
        if (f === WebEngineView.Notifications) return I18n.t("vuole mostrarti notifiche")
        if (f === WebEngineView.Geolocation) return I18n.t("vuole conoscere la tua posizione")
        if (f === WebEngineView.MediaAudioCapture) return I18n.t("vuole usare il microfono")
        if (f === WebEngineView.MediaVideoCapture) return I18n.t("vuole usare la fotocamera")
        if (f === WebEngineView.MediaAudioVideoCapture) return I18n.t("vuole usare fotocamera e microfono")
        if (f === WebEngineView.DesktopVideoCapture || f === WebEngineView.DesktopAudioVideoCapture) return I18n.t("vuole registrare lo schermo")
        return I18n.t("chiede un permesso")
    }
    // ── Password ─────────────────────────────────────────────────────────
    property var barraPassword: null            // {tipo: "salva" | "sblocca", dati, poi}
    function compila(v, ident) {
        var c = ponte.chiama("credenziali", [ident])
        if (!c.password || !v) return
        v.runJavaScript("window.__solidosRiempi && window.__solidosRiempi(" + JSON.stringify(c.utente) + "," + JSON.stringify(c.password) + ")",
                        WebEngineScript.ApplicationWorld)
    }
    function chiavePremuta() {
        var v = vista
        if (!v) return
        var r = ponte.chiama("accountSito", [v.url.toString()])
        if (r.bloccata) { barraPassword = { tipo: "sblocca", poi: "compila", vista: v }; return }
        if (r.account.length === 0) { avvisoBreve.mostra(I18n.t("Nessuna password salvata per questo sito")); return }
        if (r.account.length === 1) { compila(v, r.account[0].id); return }
        menuAccount.account = r.account; menuAccount.vista = v
        menuAccount.popup(tastoChiave, 0, tastoChiave.height + 4)
    }
    function accessoInviato(v, dati) {
        if (!dati.password || !ponte.chiama("daSalvare", [dati.url, dati.utente, dati.password])) return
        barraPassword = { tipo: "salva", dati: dati, vista: v }
    }
    function salvaPassword() {
        var r = ponte.chiama("salvaPassword", [barraPassword.dati.url, barraPassword.dati.utente, barraPassword.dati.password])
        if (r.bloccata) { barraPassword = { tipo: "sblocca", poi: "salva", dati: barraPassword.dati, vista: barraPassword.vista }; return }
        barraPassword = null
        if (r.messaggio) avvisoBreve.mostra(r.messaggio)
    }
    function sblocca(pw) {
        var r = ponte.chiama("sbloccaPassword", [pw])
        if (!r.ok) { campoSblocca.text = ""; erroreSblocca.text = r.messaggio || ""; return }
        erroreSblocca.text = ""; campoSblocca.text = ""
        var b = barraPassword
        barraPassword = null
        if (b.poi === "salva") { barraPassword = { tipo: "salva", dati: b.dati, vista: b.vista }; salvaPassword() }
        else chiavePremuta()
    }
    function aggiornaPreferiti() { preferiti = ponte.chiama0("preferiti") }
    function zoom(passo) { if (vista) vista.zoomFactor = passo === 0 ? 1.0 : Math.max(0.3, Math.min(3.0, vista.zoomFactor + passo)) }
    function dimensione(b) { return b >= 1073741824 ? (b / 1073741824).toFixed(1).replace(".", ",") + " GB" : (b >= 1048576 ? (b / 1048576).toFixed(1).replace(".", ",") + " MB" : Math.round(b / 1024) + " KB") }

    Component.onCompleted: {
        var iniziali = ponte.chiama0("indirizziIniziali")
        if (iniziali.length) iniziali.forEach(function (u) { finestra.nuovaScheda(u) })
        else nuovaScheda(conf.paginaIniziale || "")
        corrente = 0
    }

    // ── Profilo: dati del browser (nella finestra privata non si salva nulla) ──
    WebEngineProfile {
        id: profilo
        storageName: finestra.privata ? "" : "Web"
        offTheRecord: finestra.privata
        persistentCookiesPolicy: finestra.privata ? WebEngineProfile.NoPersistentCookies : WebEngineProfile.AllowPersistentCookies
        httpCacheType: finestra.privata ? WebEngineProfile.MemoryHttpCache : WebEngineProfile.DiskHttpCache
        downloadPath: ponte.chiama0("cartellaDownload")
        Component.onCompleted: {
            httpUserAgent = httpUserAgent.replace(/QtWebEngine\/[\d.]+ /, "")
            // QWebChannel e lo script delle password, nel mondo separato (le pagine non li vedono)
            var canale = WebEngine.script()
            canale.name = "qwebchannel"
            canale.sourceUrl = "qrc:///qtwebchannel/qwebchannel.js"
            canale.injectionPoint = WebEngineScript.DocumentCreation
            canale.worldId = WebEngineScript.ApplicationWorld
            var pw = WebEngine.script()
            pw.name = "password"
            pw.sourceUrl = Qt.resolvedUrl("password.js")
            pw.injectionPoint = WebEngineScript.DocumentReady
            pw.worldId = WebEngineScript.ApplicationWorld
            userScripts.collection = [canale, pw]
        }
        onDownloadRequested: function (d) {
            d.accept()
            finestra.scaricamenti = [d].concat(finestra.scaricamenti).slice(0, 30)
            pannelloDownload.open()
        }
    }

    ListModel { id: schede }

    // ── Tasto piatto delle barre ────────────────────────────────────────────
    component Tasto: Rectangle {
        id: t
        property string icona: ""
        property string testo: ""
        property string suggerimento: ""
        property bool attivo: true
        property bool acceso: false
        signal premuto()
        width: testo ? etichetta.implicitWidth + 20 : 32
        height: 32; radius: 8
        opacity: attivo ? 1 : 0.35
        color: acceso ? (Tema.chiaro ? "#1A000000" : "#24FFFFFF") : (ma.pressed && attivo ? (Tema.chiaro ? "#1F000000" : "#2AFFFFFF") : (ma.containsMouse && attivo ? (Tema.chiaro ? "#12000000" : "#18FFFFFF") : "transparent"))
        Icona { visible: t.icona !== ""; anchors.centerIn: parent; nome: t.icona + (Tema.chiaro ? "?c" : ""); lato: 16 }
        Text { id: etichetta; visible: t.testo !== ""; anchors.centerIn: parent; text: t.testo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 15 }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: if (t.attivo) t.premuto() }
        ToolTip.visible: ma.containsMouse && t.suggerimento !== ""
        ToolTip.delay: 700
        ToolTip.text: t.suggerimento
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Barra delle schede ───────────────────────────────────────────────
        Rectangle {
            visible: !finestra.schermoIntero
            Layout.fillWidth: true
            implicitHeight: 40
            color: finestra.privata ? (Tema.chiaro ? "#E9E3F8" : "#1E1730") : (Tema.chiaro ? "#E4E4E9" : "#1A1B1F")
            Row {
                id: filaSchede
                x: 8; anchors.bottom: parent.bottom
                spacing: 2
                readonly property real larghezza: Math.max(60, Math.min(230, (finestra.width - 70) / Math.max(1, schede.count)))
                Repeater {
                    model: schede
                    Rectangle {
                        id: scheda
                        required property int index
                        readonly property var v: ripetitore.count > index ? ripetitore.itemAt(index) : null
                        readonly property bool attiva: index === finestra.corrente
                        width: filaSchede.larghezza
                        height: 34
                        radius: 8
                        color: attiva ? Tema.sfondo : (maScheda.containsMouse ? (Tema.chiaro ? "#0F000000" : "#12FFFFFF") : "transparent")
                        Rectangle { visible: scheda.attiva; anchors.bottom: parent.bottom; width: parent.width; height: 8; color: Tema.sfondo }
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 6
                            spacing: 7
                            BusyIndicator { visible: !!(scheda.v && scheda.v.loading); running: visible; Layout.preferredWidth: 16; Layout.preferredHeight: 16 }
                            Image {
                                visible: !(scheda.v && scheda.v.loading)
                                Layout.preferredWidth: 16; Layout.preferredHeight: 16
                                sourceSize.width: 32; sourceSize.height: 32
                                source: scheda.v && scheda.v.icon.toString() ? scheda.v.icon : "image://icona/" + (finestra.privata ? "security-high" : "applications-internet")
                            }
                            Text {
                                Layout.fillWidth: true
                                text: scheda.v ? (scheda.v.title || (finestra.nuovaPagina(scheda.v) ? I18n.t("Nuova scheda") : scheda.v.url.toString())) : ""
                                elide: Text.ElideRight
                                color: scheda.attiva ? Tema.testo : Tema.testoSecondario
                                font.family: Tema.font; font.pixelSize: 12
                            }
                            Rectangle {
                                visible: scheda.attiva || maScheda.containsMouse
                                Layout.preferredWidth: 20; Layout.preferredHeight: 20; radius: 5
                                color: maChiudi.containsMouse ? (Tema.chiaro ? "#1F000000" : "#2AFFFFFF") : "transparent"
                                Text { anchors.centerIn: parent; text: "×"; color: Tema.testoSecondario; font.pixelSize: 16 }
                                MouseArea { id: maChiudi; anchors.fill: parent; hoverEnabled: true; onClicked: finestra.chiudiScheda(scheda.index) }
                            }
                        }
                        MouseArea {
                            id: maScheda
                            anchors.fill: parent
                            z: -1
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onClicked: function (ev) { if (ev.button === Qt.MiddleButton) finestra.chiudiScheda(scheda.index); else finestra.corrente = scheda.index }
                        }
                        ToolTip.visible: maScheda.containsMouse && !!(scheda.v && scheda.v.title)
                        ToolTip.delay: 900
                        ToolTip.text: scheda.v ? scheda.v.title : ""
                    }
                }
                Tasto { anchors.verticalCenter: parent.verticalCenter; testo: "+"; suggerimento: I18n.t("Nuova scheda") + " (Ctrl+T)"; onPremuto: finestra.nuovaScheda("") }
            }
        }

        // ── Barra degli indirizzi ────────────────────────────────────────────
        Rectangle {
            visible: !finestra.schermoIntero
            Layout.fillWidth: true
            implicitHeight: 46
            color: Tema.sfondo
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8; anchors.rightMargin: 8
                spacing: 2
                Tasto { icona: "go-previous-symbolic"; suggerimento: I18n.t("Indietro") + " (Alt+←)"; attivo: !!(finestra.vista && finestra.vista.canGoBack); onPremuto: finestra.vista.goBack() }
                Tasto { icona: "go-next-symbolic"; suggerimento: I18n.t("Avanti") + " (Alt+→)"; attivo: !!(finestra.vista && finestra.vista.canGoForward); onPremuto: finestra.vista.goForward() }
                Tasto {
                    icona: finestra.vista && finestra.vista.loading ? "process-stop-symbolic" : "view-refresh-symbolic"
                    suggerimento: finestra.vista && finestra.vista.loading ? I18n.t("Ferma") : I18n.t("Ricarica") + " (F5)"
                    onPremuto: if (finestra.vista) { if (finestra.vista.loading) finestra.vista.stop(); else finestra.vista.reload() }
                }
                // Campo dell'indirizzo
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 6; Layout.rightMargin: 6
                    height: 34; radius: 17
                    color: Tema.chiaro ? "#EFEFF3" : "#2A2B31"
                    border.width: campo.activeFocus ? 2 : 0
                    border.color: finestra.accentoWeb
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 6
                        spacing: 6
                        Icona {
                            lato: 14
                            nome: (finestra.vista && finestra.vista.url.toString().indexOf("https://") === 0 ? "channel-secure-symbolic"
                                   : (finestra.nuovaPagina(finestra.vista) ? "system-search-symbolic" : "channel-insecure-symbolic")) + (Tema.chiaro ? "?c" : "")
                        }
                        TextField {
                            id: campo
                            Layout.fillWidth: true
                            background: null
                            color: Tema.testo
                            font.family: Tema.font; font.pixelSize: 14
                            selectByMouse: true
                            placeholderText: I18n.t("Cerca o scrivi un indirizzo")
                            placeholderTextColor: Tema.testoSecondario
                            text: finestra.testoIndirizzo(finestra.vista)
                            onActiveFocusChanged: if (activeFocus) Qt.callLater(selectAll)
                            onTextEdited: {
                                elencoSuggerimenti.model = ponte.chiama("suggerimenti", [text])
                                if (elencoSuggerimenti.model.length) suggerimenti.open(); else suggerimenti.close()
                            }
                            onAccepted: finestra.vai(text)
                            Keys.onEscapePressed: { text = finestra.testoIndirizzo(finestra.vista); suggerimenti.close(); if (finestra.vista) finestra.vista.forceActiveFocus() }
                            Keys.onDownPressed: if (suggerimenti.visible) elencoSuggerimenti.forceActiveFocus()
                        }
                        Text {
                            visible: !!(finestra.vista && Math.abs(finestra.vista.zoomFactor - 1) > 0.01)
                            text: finestra.vista ? Math.round(finestra.vista.zoomFactor * 100) + "%" : ""
                            color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11
                            MouseArea { anchors.fill: parent; onClicked: finestra.zoom(0) }
                        }
                        Rectangle {
                            id: tastoChiave
                            visible: !!(finestra.vista && finestra.vista.moduloAccesso)
                            width: 28; height: 28; radius: 8
                            color: maChiave.containsMouse ? (Tema.chiaro ? "#12000000" : "#18FFFFFF") : "transparent"
                            Simbolo { anchors.centerIn: parent; nome: "chiave"; lato: 16; colore: finestra.accentoWeb }
                            MouseArea { id: maChiave; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: finestra.chiavePremuta() }
                            ToolTip.visible: maChiave.containsMouse; ToolTip.delay: 600; ToolTip.text: I18n.t("Compila con una password salvata")
                        }
                        Tasto {
                            visible: !finestra.nuovaPagina(finestra.vista)
                            width: 28; height: 28
                            testo: finestra.vista && finestra.preferiti.some(function (p) { return p.url === finestra.vista.url.toString() }) ? "★" : "☆"
                            suggerimento: I18n.t("Aggiungi ai preferiti") + " (Ctrl+D)"
                            onPremuto: azionePreferito.trigger()
                        }
                    }
                    // suggerimenti dalla cronologia e dai preferiti
                    Popup {
                        id: suggerimenti
                        y: parent.height + 4
                        width: parent.width
                        padding: 6
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
                        background: Rectangle { radius: 12; color: Tema.chiaro ? "#FFFFFF" : "#2C2D33"; border.color: Tema.chiaro ? "#1F000000" : "#24FFFFFF" }
                        contentItem: ListView {
                            id: elencoSuggerimenti
                            implicitHeight: contentHeight
                            interactive: false
                            keyNavigationEnabled: true
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: ListView.view.width; height: 40; radius: 7
                                color: maS.containsMouse || ListView.isCurrentItem && elencoSuggerimenti.activeFocus ? (Tema.chiaro ? "#0F000000" : "#16FFFFFF") : "transparent"
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                                    spacing: 10
                                    Simbolo { nome: modelData.tipo === "preferito" ? "stella" : "cronologia"; lato: 14; colore: Tema.testoSecondario }
                                    Column {
                                        Layout.fillWidth: true
                                        Text { width: parent.width; text: modelData.titolo; elide: Text.ElideRight; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                                        Text { width: parent.width; text: modelData.url; elide: Text.ElideMiddle; color: finestra.accentoWeb; font.family: Tema.font; font.pixelSize: 11 }
                                    }
                                }
                                MouseArea { id: maS; anchors.fill: parent; hoverEnabled: true; onClicked: finestra.vai(modelData.url) }
                                Keys.onReturnPressed: finestra.vai(modelData.url)
                            }
                        }
                    }
                }
                Tasto {
                    icona: "folder-download-symbolic"
                    visible: finestra.scaricamenti.length > 0
                    acceso: finestra.scaricando
                    suggerimento: I18n.t("Download") + " (Ctrl+J)"
                    onPremuto: pannelloDownload.open()
                }
                Tasto { id: tastoMenu; icona: "open-menu-symbolic"; suggerimento: I18n.t("Menu"); onPremuto: menuPrincipale.popup(tastoMenu, tastoMenu.width - menuPrincipale.width, tastoMenu.height + 4) }
            }
            // avanzamento del caricamento
            Rectangle {
                anchors.bottom: parent.bottom
                height: 2
                width: finestra.vista && finestra.vista.loading ? parent.width * Math.max(0.05, finestra.vista.loadProgress / 100) : 0
                color: finestra.accentoWeb
                visible: width > 0
                Behavior on width { enabled: Tema.animazioni; NumberAnimation { duration: 150 } }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Tema.chiaro ? "#14000000" : "#40000000"; z: -1 }
        }

        // ── Barra dei preferiti ──────────────────────────────────────────────
        Rectangle {
            visible: !finestra.schermoIntero && finestra.conf.barraPreferiti !== false && finestra.preferiti.length > 0
            Layout.fillWidth: true
            implicitHeight: 30
            color: Tema.sfondo
            Row {
                x: 10; anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Repeater {
                    model: finestra.preferiti.slice(0, 14)
                    Rectangle {
                        required property var modelData
                        width: Math.min(160, testoPref.implicitWidth + 34); height: 24; radius: 6
                        color: maP.containsMouse ? (Tema.chiaro ? "#0F000000" : "#16FFFFFF") : "transparent"
                        Row {
                            anchors.verticalCenter: parent.verticalCenter; x: 8; spacing: 6
                            Text { text: "★"; color: Tema.testoSecondario; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                            Text { id: testoPref; width: Math.min(implicitWidth, 120); text: modelData.titolo; elide: Text.ElideRight; color: Tema.testo; font.family: Tema.font; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                            id: maP; anchors.fill: parent; hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onClicked: function (ev) { if (ev.button === Qt.MiddleButton) finestra.nuovaScheda(modelData.url, false); else finestra.vai(modelData.url) }
                        }
                    }
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Tema.chiaro ? "#14000000" : "#40000000" }
        }

        // ── Avvisi (permessi, certificati) ───────────────────────────────────
        Rectangle {
            id: avvisoPermesso
            property url origine
            property int funzione: -1
            property var vistaRichiesta: null
            visible: funzione >= 0
            Layout.fillWidth: true
            implicitHeight: 44
            color: Tema.chiaro ? "#FFF6DA" : "#3A3218"
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 10
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    color: Tema.testo; font.family: Tema.font; font.pixelSize: 13
                    text: avvisoPermesso.origine.toString().replace(/^https?:\/\//, "").replace(/\/$/, "") + " " + finestra.richiesta(avvisoPermesso.funzione)
                }
                Pulsante { text: I18n.t("Blocca"); onClicked: { avvisoPermesso.vistaRichiesta.grantFeaturePermission(avvisoPermesso.origine, avvisoPermesso.funzione, false); avvisoPermesso.funzione = -1 } }
                Pulsante { principale: true; text: I18n.t("Consenti"); onClicked: { avvisoPermesso.vistaRichiesta.grantFeaturePermission(avvisoPermesso.origine, avvisoPermesso.funzione, true); avvisoPermesso.funzione = -1 } }
            }
        }
        Rectangle {
            id: avvisoCertificato
            property var errore: null
            visible: errore !== null
            Layout.fillWidth: true
            implicitHeight: 48
            color: Tema.chiaro ? "#FDE2E1" : "#45201F"
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 10
                Text { Layout.fillWidth: true; elide: Text.ElideRight; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; text: I18n.t("Connessione non sicura: il certificato del sito non è valido.") + (avvisoCertificato.errore ? " " + avvisoCertificato.errore.description : "") }
                Pulsante { principale: true; text: I18n.t("Torna indietro"); onClicked: { avvisoCertificato.errore.rejectCertificate(); avvisoCertificato.errore = null } }
                Pulsante { text: I18n.t("Continua comunque"); onClicked: { avvisoCertificato.errore.acceptCertificate(); avvisoCertificato.errore = null } }
            }
        }

        Rectangle {
            id: barraPw
            visible: finestra.barraPassword !== null
            Layout.fillWidth: true
            implicitHeight: finestra.barraPassword && finestra.barraPassword.tipo === "sblocca" && erroreSblocca.text ? 70 : 50
            color: Tema.chiaro ? "#EEF2FF" : "#1E2238"
            RowLayout {
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                height: 50; anchors.leftMargin: 16; anchors.rightMargin: 10
                spacing: 10
                Simbolo { nome: "chiave"; lato: 18; colore: finestra.accentoWeb }
                Text {
                    Layout.fillWidth: true; elide: Text.ElideRight
                    color: Tema.testo; font.family: Tema.font; font.pixelSize: 13
                    text: !finestra.barraPassword ? "" : finestra.barraPassword.tipo === "salva"
                          ? I18n.t("Salvare la password per {s}?").replace("{s}", (finestra.barraPassword.dati.url.split("/")[2] || "").replace(/^www\./, ""))
                            + (finestra.barraPassword.dati.utente ? "  ·  " + finestra.barraPassword.dati.utente : "")
                          : I18n.t("Scrivi la password di SolidOS per usare le password salvate")
                }
                // salva
                Pulsante { visible: !!finestra.barraPassword && finestra.barraPassword.tipo === "salva"; text: I18n.t("Mai per questo sito"); onClicked: { ponte.chiama("maiPerSito", [finestra.barraPassword.dati.url]); finestra.barraPassword = null } }
                Pulsante { visible: !!finestra.barraPassword && finestra.barraPassword.tipo === "salva"; text: I18n.t("Non ora"); onClicked: finestra.barraPassword = null }
                Pulsante { visible: !!finestra.barraPassword && finestra.barraPassword.tipo === "salva"; text: I18n.t("Salva"); principale: true; onClicked: finestra.salvaPassword() }
                // sblocca
                CampoTesto {
                    id: campoSblocca
                    visible: !!finestra.barraPassword && finestra.barraPassword.tipo === "sblocca"
                    Layout.preferredWidth: 220
                    echoMode: TextInput.Password
                    placeholderText: I18n.t("Password di SolidOS")
                    onVisibleChanged: if (visible) forceActiveFocus()
                    onAccepted: finestra.sblocca(text)
                }
                Pulsante { visible: campoSblocca.visible; text: I18n.t("Annulla"); onClicked: { finestra.barraPassword = null; erroreSblocca.text = "" } }
                Pulsante { visible: campoSblocca.visible; text: I18n.t("Sblocca"); principale: true; onClicked: finestra.sblocca(campoSblocca.text) }
            }
            Text { id: erroreSblocca; visible: text !== ""; x: 44; y: 48; color: "#EF4444"; font.family: Tema.font; font.pixelSize: 12 }
        }

        // ── Pagine ───────────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            StackLayout {
                id: pila
                anchors.fill: parent
                currentIndex: finestra.corrente
                Repeater {
                    id: ripetitore
                    model: schede
                    WebEngineView {
                        id: pagina
                        required property string iniziale
                        profile: profilo
                        url: iniziale
                        property bool moduloAccesso: false
                        webChannelWorld: WebEngineScript.ApplicationWorld
                        webChannel: WebChannel { registeredObjects: [pontePassword] }
                        QtObject {
                            id: pontePassword
                            WebChannel.id: "solidosPassword"
                            function modulo(indirizzo, presente) {
                                pagina.moduloAccesso = presente
                                if (!presente) return
                                // cassaforte aperta e un solo account esatto per il sito: si compila da solo
                                var r = ponte.chiama("accountSito", [indirizzo])
                                if (!r.bloccata && r.account.length === 1 && r.account[0].esatto) finestra.compila(pagina, r.account[0].id)
                            }
                            function inviato(json) { finestra.accessoInviato(pagina, JSON.parse(json)) }
                        }
                        onUrlChanged: moduloAccesso = false
                        settings.fullScreenSupportEnabled: true
                        settings.pluginsEnabled: true
                        settings.dnsPrefetchEnabled: true
                        settings.scrollAnimatorEnabled: Tema.animazioni
                        settings.focusOnNavigationEnabled: true
                        onNewWindowRequested: function (richiesta) {
                            var nuova = finestra.nuovaScheda("", richiesta.userInitiated !== false)
                            richiesta.openIn(nuova)
                        }
                        onLoadingChanged: function (info) {
                            if (info.status === WebEngineView.LoadSucceededStatus && !finestra.privata) ponte.chiama("visita", [url.toString(), title])
                        }
                        onTitleChanged: if (!loading && !finestra.privata && title) ponte.chiama("visita", [url.toString(), title])
                        onLinkHovered: function (u) { finestra.linkSotto = u.toString() }
                        onFullScreenRequested: function (r) {
                            r.accept()
                            finestra.schermoIntero = r.toggleOn
                            if (r.toggleOn) finestra.showFullScreen(); else finestra.showNormal()
                        }
                        onFeaturePermissionRequested: function (origine, funzione) {
                            avvisoPermesso.vistaRichiesta = pagina
                            avvisoPermesso.origine = origine
                            avvisoPermesso.funzione = funzione
                        }
                        onCertificateError: function (e) { e.defer(); avvisoCertificato.errore = e }
                        onWindowCloseRequested: finestra.chiudiScheda(finestra.corrente)
                        onFindTextFinished: function (r) { finestra.trovati = r.numberOfMatches > 0 ? r.activeMatch + "/" + r.numberOfMatches : I18n.t("nessuno") }
                    }
                }
            }

            // Pagina «Nuova scheda»
            Rectangle {
                anchors.fill: parent
                visible: finestra.nuovaPagina(finestra.vista)
                color: Tema.sfondo
                property var siti: visible ? ponte.chiama0("piuVisitati") : []
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.max(40, parent.height * 0.2)
                    width: Math.min(640, parent.width - 60)
                    spacing: 26
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12
                        Image { width: 44; height: 44; sourceSize.width: 88; sourceSize.height: 88; source: "image://icona/" + (finestra.privata ? "security-high" : Tema.logo) }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: finestra.privata ? I18n.t("Navigazione privata") : "Vela"
                            color: Tema.testo; font.family: Tema.font; font.pixelSize: 28; font.weight: Font.DemiBold
                        }
                    }
                    Text {
                        visible: finestra.privata
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: I18n.t("In questa finestra non vengono salvati cronologia, cookie e dati dei moduli. I download e i preferiti restano.")
                        color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13
                    }
                    Rectangle {
                        width: parent.width; height: 52; radius: 26
                        color: Tema.chiaro ? "#FFFFFF" : "#2A2B31"
                        border.color: campoNuova.activeFocus ? finestra.accentoWeb : (Tema.chiaro ? "#1F000000" : "#24FFFFFF")
                        border.width: campoNuova.activeFocus ? 2 : 1
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 20
                            Icona { nome: "system-search-symbolic" + (Tema.chiaro ? "?c" : ""); lato: 18 }
                            TextField {
                                id: campoNuova
                                Layout.fillWidth: true
                                background: null
                                color: Tema.testo
                                font.family: Tema.font; font.pixelSize: 16
                                placeholderText: I18n.t("Cerca con") + " " + ((finestra.conf.motori || []).find(function (m) { return m.valore === finestra.conf.motore }) || { testo: "Google" }).testo + " " + I18n.t("o scrivi un indirizzo")
                                placeholderTextColor: Tema.testoSecondario
                                onAccepted: { finestra.vai(text); text = "" }
                            }
                        }
                    }
                    Flow {
                        width: parent.width
                        spacing: 14
                        Repeater {
                            model: parent.parent.parent.siti
                            Rectangle {
                                required property var modelData
                                width: (parent.width - 3 * 14) / 4; height: 92; radius: 14
                                color: maSito.containsMouse ? (Tema.chiaro ? "#EDEDF2" : "#2E2F36") : (Tema.chiaro ? "#F6F6F9" : "#24252A")
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 40; height: 40; radius: 12
                                        color: Qt.hsla((modelData.dominio.charCodeAt(0) * 37 % 360) / 360, 0.55, 0.5, 1)
                                        Text { anchors.centerIn: parent; text: modelData.dominio.charAt(0).toUpperCase(); color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: 18; font.weight: Font.DemiBold }
                                    }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; width: 120; horizontalAlignment: Text.AlignHCenter; text: modelData.dominio; elide: Text.ElideRight; color: Tema.testo; font.family: Tema.font; font.pixelSize: 12 }
                                }
                                MouseArea { id: maSito; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: finestra.vai(modelData.url) }
                            }
                        }
                    }
                }
            }

            // Indirizzo del link sotto il mouse (in basso a sinistra)
            Rectangle {
                visible: finestra.linkSotto !== ""
                anchors.left: parent.left; anchors.bottom: parent.bottom
                anchors.margins: 4
                width: Math.min(testoLink.implicitWidth + 16, parent.width * 0.6); height: 22; radius: 6
                color: Tema.chiaro ? "#F2FFFFFF" : "#F22A2B31"
                border.color: Tema.chiaro ? "#1F000000" : "#24FFFFFF"
                Text { id: testoLink; anchors.verticalCenter: parent.verticalCenter; x: 8; width: parent.width - 16; elide: Text.ElideMiddle; text: finestra.linkSotto; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
            }

            // Trova nella pagina (Ctrl+F)
            Rectangle {
                id: barraTrova
                visible: false
                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10
                width: 360; height: 44; radius: 10
                color: Tema.chiaro ? "#FFFFFF" : "#2C2D33"
                border.color: Tema.chiaro ? "#1F000000" : "#24FFFFFF"
                function apri() { visible = true; campoTrova.forceActiveFocus(); campoTrova.selectAll() }
                function chiudi() { visible = false; if (finestra.vista) { finestra.vista.findText(""); finestra.vista.forceActiveFocus() } }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 6
                    TextField {
                        id: campoTrova
                        Layout.fillWidth: true
                        background: null
                        color: Tema.testo; font.family: Tema.font; font.pixelSize: 13
                        placeholderText: I18n.t("Trova nella pagina")
                        placeholderTextColor: Tema.testoSecondario
                        onTextChanged: if (finestra.vista) finestra.vista.findText(text)
                        onAccepted: if (finestra.vista) finestra.vista.findText(text)
                        Keys.onEscapePressed: barraTrova.chiudi()
                    }
                    Text {
                        text: campoTrova.text ? finestra.trovati : ""
                        color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                    }
                    Tasto { icona: "go-up-symbolic"; onPremuto: finestra.vista.findText(campoTrova.text, WebEngineView.FindBackward) }
                    Tasto { icona: "go-down-symbolic"; onPremuto: finestra.vista.findText(campoTrova.text) }
                    Tasto { testo: "×"; onPremuto: barraTrova.chiudi() }
                }
            }
        }
    }

    // ── Menu principale ───────────────────────────────────────────────────────
    Action { id: azionePreferito; onTriggered: { if (!finestra.vista || finestra.nuovaPagina(finestra.vista)) return; var u = finestra.vista.url.toString(); finestra.preferiti = ponte.chiama("preferito", [u, finestra.vista.title, !finestra.preferiti.some(function (p) { return p.url === u })]) } }
    Menu {
        id: menuPrincipale
        width: 290
        MenuItem { text: I18n.t("Nuova scheda") + "\tCtrl+T"; onTriggered: finestra.nuovaScheda("") }
        MenuItem { text: I18n.t("Nuova finestra") + "\tCtrl+N"; onTriggered: ponte.chiama("nuovaFinestra", [false, ""]) }
        MenuItem { text: I18n.t("Nuova finestra privata") + "\tCtrl+Maiusc+N"; onTriggered: ponte.chiama("nuovaFinestra", [true, ""]) }
        MenuSeparator {}
        MenuItem { text: I18n.t("Preferiti"); onTriggered: { pannello.modo = "preferiti"; pannello.open() } }
        MenuItem { text: I18n.t("Cronologia") + "\tCtrl+H"; enabled: !finestra.privata; onTriggered: { pannello.modo = "cronologia"; pannello.open() } }
        MenuItem { text: I18n.t("Download") + "\tCtrl+J"; onTriggered: pannelloDownload.open() }
        MenuSeparator {}
        MenuItem { text: I18n.t("Trova nella pagina") + "\tCtrl+F"; onTriggered: barraTrova.apri() }
        MenuItem { text: I18n.t("Ingrandisci") + "\tCtrl++"; onTriggered: finestra.zoom(0.1) }
        MenuItem { text: I18n.t("Riduci") + "\tCtrl+-"; onTriggered: finestra.zoom(-0.1) }
        MenuItem { text: I18n.t("Dimensione normale") + "\tCtrl+0"; onTriggered: finestra.zoom(0) }
        MenuItem { text: I18n.t("Salva la pagina come PDF"); onTriggered: if (finestra.vista) finestra.vista.printToPdf(ponte.chiama0("cartellaDownload") + "/" + (finestra.vista.title || "pagina").replace(/[\/\\:*?"<>|]/g, "-") + ".pdf") }
        MenuSeparator {}
        MenuItem { text: I18n.t("Impostazioni del browser"); onTriggered: impostazioni.open() }
    }

    // ── Preferiti / Cronologia (pannello a destra) ───────────────────────────
    Drawer {
        id: pannello
        property string modo: "preferiti"
        property var voci: []
        function carica() { voci = modo === "preferiti" ? finestra.preferiti : ponte.chiama("cronologia", [cercaPannello.text]) }
        edge: Qt.RightEdge
        width: 380
        height: finestra.height
        onOpened: { cercaPannello.text = ""; carica() }
        background: Rectangle { color: Tema.superficie; Rectangle { width: 1; height: parent.height; color: Tema.bordo } }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10
            RowLayout {
                Titolo { livello: 2; text: pannello.modo === "preferiti" ? I18n.t("Preferiti") : I18n.t("Cronologia"); Layout.fillWidth: true }
                Pulsante { visible: pannello.modo === "cronologia"; pericoloso: true; text: I18n.t("Cancella tutto"); onClicked: { ponte.chiama0("cancellaCronologia"); profilo.clearHttpCache(); pannello.carica() } }
                Pulsante { visible: pannello.modo === "preferiti"; text: I18n.t("Importa"); onClicked: { var n = ponte.chiama0("importaPreferiti"); finestra.aggiornaPreferiti(); pannello.carica(); finestra.avviso(n + " " + I18n.t("preferiti importati")) } }
            }
            CampoRicerca { id: cercaPannello; Layout.fillWidth: true; placeholderText: I18n.t("Cerca"); visible: pannello.modo === "cronologia"; onTextChanged: pannello.carica() }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: pannello.voci
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width; height: 48; radius: 8
                    color: maV.containsMouse ? (Tema.chiaro ? "#0F000000" : "#16FFFFFF") : "transparent"
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 10; width: parent.width - 50
                        Text { width: parent.width; text: modelData.titolo; elide: Text.ElideRight; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                        Text { width: parent.width; text: (modelData.quando ? modelData.quando + " · " : "") + modelData.url; elide: Text.ElideMiddle; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11 }
                    }
                    MouseArea { id: maV; anchors.fill: parent; hoverEnabled: true; onClicked: { finestra.vai(modelData.url); pannello.close() } }
                    Tasto {
                        visible: pannello.modo === "preferiti"
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        testo: "×"; suggerimento: I18n.t("Togli dai preferiti")
                        onPremuto: { finestra.preferiti = ponte.chiama("preferito", [modelData.url, "", false]); pannello.carica() }
                    }
                }
                Text { anchors.centerIn: parent; visible: parent.count === 0; text: pannello.modo === "preferiti" ? I18n.t("Nessun preferito: premi ☆ nella barra dell'indirizzo") : I18n.t("Nessuna pagina visitata"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13; width: parent.width - 20; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter }
            }
        }
    }

    // ── Download ─────────────────────────────────────────────────────────────
    Popup {
        id: pannelloDownload
        x: finestra.width - width - 10
        y: 88
        width: 380
        height: Math.min(420, 70 + finestra.scaricamenti.length * 64)
        padding: 12
        background: Rectangle { radius: 12; color: Tema.chiaro ? "#FFFFFF" : "#2C2D33"; border.color: Tema.chiaro ? "#1F000000" : "#24FFFFFF" }
        ColumnLayout {
            anchors.fill: parent
            spacing: 6
            Text { text: I18n.t("Download"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.DemiBold }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: finestra.scaricamenti
                delegate: Item {
                    required property var modelData
                    width: ListView.view.width; height: 60
                    readonly property bool finito: modelData.state === WebEngineDownloadRequest.DownloadCompleted
                    readonly property string percorso: modelData.downloadDirectory + "/" + modelData.downloadFileName
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.rightMargin: 70
                        spacing: 3
                        Text { Layout.fillWidth: true; text: modelData.downloadFileName; elide: Text.ElideMiddle; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                        BarraProgresso { Layout.fillWidth: true; visible: !modelData.isFinished; value: modelData.totalBytes > 0 ? modelData.receivedBytes / modelData.totalBytes : 0; indeterminate: modelData.totalBytes <= 0 }
                        Text {
                            text: parent.parent.finito ? I18n.t("Completato") + " · " + finestra.dimensione(modelData.receivedBytes)
                                  : (modelData.isFinished ? I18n.t("Interrotto") : finestra.dimensione(modelData.receivedBytes) + (modelData.totalBytes > 0 ? " / " + finestra.dimensione(modelData.totalBytes) : ""))
                            color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11
                        }
                    }
                    Row {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        Tasto { visible: parent.parent.finito; icona: "document-open-symbolic"; suggerimento: I18n.t("Apri"); onPremuto: ponte.chiama("apriFile", [parent.parent.percorso]) }
                        Tasto { visible: parent.parent.finito; icona: "folder-open-symbolic"; suggerimento: I18n.t("Mostra nella cartella"); onPremuto: ponte.chiama("mostraNellaCartella", [parent.parent.percorso]) }
                        Tasto { visible: !modelData.isFinished; testo: "×"; suggerimento: I18n.t("Annulla"); onPremuto: modelData.cancel() }
                    }
                }
            }
        }
    }

    // ── Impostazioni del browser ─────────────────────────────────────────────
    Dialog {
        id: impostazioni
        anchors.centerIn: parent
        width: 460
        modal: true
        title: I18n.t("Impostazioni del browser")
        standardButtons: Dialog.Close
        background: Rectangle { color: Tema.superficie; radius: 12; border.color: Tema.bordo }
        ColumnLayout {
            width: parent.width
            spacing: 12
            RigaImpostazione {
                Layout.fillWidth: true
                titolo: I18n.t("Motore di ricerca")
                Scelta {
                    model: finestra.conf.motori
                    Component.onCompleted: currentIndex = Math.max(0, indexOfValue(finestra.conf.motore))
                    onActivated: finestra.conf = ponte.chiama("imposta", ["motore", currentValue])
                }
            }
            RigaImpostazione {
                Layout.fillWidth: true
                titolo: I18n.t("Barra dei preferiti")
                Interruttore { checked: finestra.conf.barraPreferiti !== false; onToggled: finestra.conf = ponte.chiama("imposta", ["barraPreferiti", checked]) }
            }
            RigaImpostazione {
                Layout.fillWidth: true
                titolo: I18n.t("Pagina iniziale")
                descrizione: I18n.t("Vuota = pagina «Nuova scheda»")
                CampoTesto { Layout.preferredWidth: 200; text: finestra.conf.paginaIniziale || ""; onEditingFinished: finestra.conf = ponte.chiama("imposta", ["paginaIniziale", text]) }
            }
            Pulsante {
                text: I18n.t("Cancella cookie, cache e dati dei siti")
                pericoloso: true
                onClicked: { profilo.clearHttpCache(); ponte.chiama0("cancellaDatiSiti"); finestra.avviso(I18n.t("Cache cancellata; cookie e dati dei siti spariranno alla prossima apertura")) }
            }
        }
    }

    // ── Scorciatoie ──────────────────────────────────────────────────────────
    Shortcut { sequence: "Ctrl+T"; onActivated: finestra.nuovaScheda("") }
    Shortcut { sequence: "Ctrl+W"; onActivated: finestra.chiudiScheda(finestra.corrente) }
    Shortcut { sequence: "Ctrl+N"; onActivated: ponte.chiama("nuovaFinestra", [false, ""]) }
    Shortcut { sequence: "Ctrl+Shift+N"; onActivated: ponte.chiama("nuovaFinestra", [true, ""]) }
    Shortcut { sequence: "Ctrl+Shift+T"; onActivated: if (finestra.chiuse.length) { var u = finestra.chiuse[finestra.chiuse.length - 1]; finestra.chiuse = finestra.chiuse.slice(0, -1); finestra.nuovaScheda(u) } }
    Shortcut { sequence: "Ctrl+L"; onActivated: { campo.forceActiveFocus(); campo.selectAll() } }
    Shortcut { sequence: "F6"; onActivated: { campo.forceActiveFocus(); campo.selectAll() } }
    Shortcut { sequence: "Ctrl+R"; onActivated: if (finestra.vista) finestra.vista.reload() }
    Shortcut { sequence: "F5"; onActivated: if (finestra.vista) finestra.vista.reload() }
    Shortcut { sequence: "Alt+Left"; onActivated: if (finestra.vista) finestra.vista.goBack() }
    Shortcut { sequence: "Alt+Right"; onActivated: if (finestra.vista) finestra.vista.goForward() }
    Shortcut { sequence: "Ctrl+Tab"; onActivated: finestra.corrente = (finestra.corrente + 1) % schede.count }
    Shortcut { sequence: "Ctrl+Shift+Tab"; onActivated: finestra.corrente = (finestra.corrente - 1 + schede.count) % schede.count }
    Shortcut { sequence: "Ctrl+D"; onActivated: azionePreferito.trigger() }
    Shortcut { sequence: "Ctrl+H"; onActivated: if (!finestra.privata) { pannello.modo = "cronologia"; pannello.open() } }
    Shortcut { sequence: "Ctrl+J"; onActivated: pannelloDownload.open() }
    Shortcut { sequence: "Ctrl+F"; onActivated: barraTrova.apri() }
    Shortcut { sequence: "Ctrl++"; onActivated: finestra.zoom(0.1) }
    Shortcut { sequence: "Ctrl+="; onActivated: finestra.zoom(0.1) }
    Shortcut { sequence: "Ctrl+-"; onActivated: finestra.zoom(-0.1) }
    Shortcut { sequence: "Ctrl+0"; onActivated: finestra.zoom(0) }
    Shortcut { sequence: "F11"; onActivated: { finestra.schermoIntero = !finestra.schermoIntero; if (finestra.schermoIntero) finestra.showFullScreen(); else finestra.showNormal() } }
    Shortcut { sequence: "Escape"; enabled: finestra.schermoIntero; onActivated: { if (finestra.vista) finestra.vista.triggerWebAction(WebEngineView.ExitFullScreen); finestra.schermoIntero = false; finestra.showNormal() } }
    // account del sito da scegliere (se ce n'è più di uno)
    Menu {
        id: menuAccount
        property var account: []
        property var vista: null
        Instantiator {
            model: menuAccount.account
            MenuItem { text: (modelData.utente || I18n.t("(senza nome utente)")) + (modelData.esatto ? "" : "  ·  " + modelData.titolo); onTriggered: finestra.compila(menuAccount.vista, modelData.id) }
            onObjectAdded: function (i, o) { menuAccount.insertItem(i, o) }
            onObjectRemoved: function (i, o) { menuAccount.removeItem(o) }
        }
    }
    Messaggio { id: avvisoBreve }
}
