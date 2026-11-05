// Shell del desktop: finestre layer-shell per notifiche, centro di controllo,
// centro notifiche e OSD. Un solo processo, un solo motore QML.
import QtQuick
import QtQuick.Window
import org.kde.layershell 1.0 as LayerShell
import SolidUI

QtObject {
    id: radice

    property var stato: ({})
    property var popup: []          // notifiche visibili in alto a destra
    property var storico: []

    function aggiornaStato() { radice.stato = shell.chiama0("stato") }
    function aggiornaStorico() { radice.storico = shell.chiama0("storico") }

    function mostra(cosa) {
        controllo.visible = (cosa === "controllo") ? !controllo.visible : false
        centroNotifiche.visible = (cosa === "notifiche") ? !centroNotifiche.visible : false
        barra.visible = (cosa === "barra") ? !barra.visible : false
        if (controllo.visible) aggiornaStato()
        if (centroNotifiche.visible) aggiornaStorico()
    }

    function aggiungiPopup(n) {
        var nuovi = radice.popup.filter(function (p) { return p.id !== n.id })
        nuovi.unshift(n)
        radice.popup = nuovi.slice(0, 4)
    }
    function togliPopup(id) {
        radice.popup = radice.popup.filter(function (p) { return p.id !== id })
    }

    property Connections collegamento: Connections {
        target: shell
        function onEvento(nome, dati) {
            if (nome === "notifica") {
                if (dati.mostra) radice.aggiungiPopup(dati.notifica)
                if (centroNotifiche.visible) radice.aggiornaStorico()
            } else if (nome === "chiusa") {
                radice.togliPopup(dati.id)
            } else if (nome === "mostra") {
                radice.mostra(dati)
            } else if (nome === "osd") {
                osd.mostra(dati)
            } else if (nome === "stato") {
                radice.aggiornaStato()
            }
        }
    }

    // ── Notifiche a comparsa ────────────────────────────────────────────────
    property Window finestraPopup: Window {
        id: finestraPopup
        LayerShell.Window.scope: "notifiche"
        LayerShell.Window.layer: LayerShell.Window.LayerOverlay
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorRight
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
        width: 400
        height: Math.max(colonnaPopup.implicitHeight + 24, 1)
        color: "transparent"
        visible: radice.popup.length > 0
        Column {
            id: colonnaPopup
            x: 12; y: 12
            width: parent.width - 24
            spacing: 10
            Repeater {
                model: radice.popup
                SchedaNotifica {
                    width: colonnaPopup.width
                    notifica: modelData
                    aComparsa: true
                    onChiusa: { shell.chiama("chiudiNotifica", [modelData.id]); radice.togliPopup(modelData.id) }
                    onScaduta: { shell.chiama("scadutaNotifica", [modelData.id]); radice.togliPopup(modelData.id) }
                    onAzione: function (chiave) { shell.chiama("azioneNotifica", [modelData.id, chiave]); radice.togliPopup(modelData.id) }
                }
            }
        }
    }

    // ── Centro di controllo rapido ──────────────────────────────────────────
    property Window controllo: Window {
        id: controllo
        LayerShell.Window.scope: "controllo"
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
        color: "transparent"
        visible: false
        MouseArea { anchors.fill: parent; onClicked: controllo.visible = false }
        CentroControllo {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 12
            anchors.bottomMargin: 56
            stato: radice.stato
            onChiudi: controllo.visible = false
            onAggiorna: radice.aggiornaStato()
        }
        Shortcut { sequence: "Escape"; onActivated: controllo.visible = false }
    }

    // ── Centro notifiche ────────────────────────────────────────────────────
    property Window centroNotifiche: Window {
        id: centroNotifiche
        LayerShell.Window.scope: "centro-notifiche"
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
        color: "transparent"
        visible: false
        MouseArea { anchors.fill: parent; onClicked: centroNotifiche.visible = false }
        CentroNotifiche {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 12
            anchors.bottomMargin: 56
            width: 400
            storico: radice.storico
            nonDisturbare: radice.stato.nonDisturbare === true
            onAggiorna: radice.aggiornaStorico()
            onCambiaNonDisturbare: function (v) { shell.chiama("nonDisturbare", [v]); radice.aggiornaStato() }
        }
        Shortcut { sequence: "Escape"; onActivated: centroNotifiche.visible = false }
    }

    // ── Barra Unica ─────────────────────────────────────────────────────────
    property Window barra: Window {
        id: barra
        LayerShell.Window.scope: "barra-unica"
        LayerShell.Window.layer: LayerShell.Window.LayerOverlay
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityExclusive
        color: "#66000000"
        visible: false
        MouseArea { anchors.fill: parent; onClicked: barra.visible = false }
        BarraUnica {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.18
            width: Math.min(680, parent.width - 40)
            attiva: barra.visible
            onChiudi: barra.visible = false
        }
    }

    // ── OSD volume / luminosità ─────────────────────────────────────────────
    property Window osd: Window {
        id: osd
        function mostra(d) {
            icona.nome = d.tipo === "volume" ? (d.muto ? "audio-volume-muted" : "audio-volume-high") : "display-brightness"
            barra.value = d.muto ? 0 : Math.min(d.valore, 100) / 100
            etichetta.text = d.muto ? I18n.t("Muto") : d.valore + "%"
            osd.visible = true
            timerOsd.restart()
        }
        LayerShell.Window.scope: "osd"
        LayerShell.Window.layer: LayerShell.Window.LayerOverlay
        LayerShell.Window.anchors: LayerShell.Window.AnchorBottom
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
        width: 300
        height: 140
        color: "transparent"
        visible: false
        Rectangle {
            anchors.fill: parent
            anchors.margins: 12
            anchors.bottomMargin: 72
            radius: 14
            color: Tema.superficie
            border.color: Tema.bordo
            Row {
                anchors.centerIn: parent
                spacing: 12
                Icona { id: icona; lato: 24; anchors.verticalCenter: parent.verticalCenter }
                BarraProgresso { id: barra; width: 160; anchors.verticalCenter: parent.verticalCenter }
                Testo { id: etichetta; width: 44; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        Timer { id: timerOsd; interval: 1500; onTriggered: osd.visible = false }
    }

    // ── Indicatore delle prestazioni (Super+P), sempre in primo piano ───────
    property Connections collegamentoPrestazioni: Connections {
        target: shell
        function onEvento(nome, dati) {
            if (nome === "prestazioni") {
                hud.visible = !hud.visible
                if (hud.visible) { hud.storia = []; hud.aggiorna() }
            }
        }
    }
    property Window hud: Window {
        id: hud
        property var dati: ({})
        property var storia: []
        function aggiorna() {
            dati = shell.chiama0("prestazioni")
            var s = storia.slice(-29)
            s.push(dati.cpu || 0)
            storia = s
            grafico.requestPaint()
        }
        LayerShell.Window.scope: "prestazioni"
        LayerShell.Window.layer: LayerShell.Window.LayerOverlay
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorLeft
        LayerShell.Window.exclusionZone: 0
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
        width: 248
        height: 228
        color: "transparent"
        visible: false
        Timer { interval: 1000; repeat: true; running: hud.visible; onTriggered: hud.aggiorna() }
        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.topMargin: 12
            anchors.rightMargin: 4
            anchors.bottomMargin: 2
            radius: 14
            color: "#CC121318"
            border.color: "#1FFFFFFF"
            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 9
                Item {
                    width: parent.width; height: 16
                    Text { text: I18n.t("Prestazioni"); color: "#F5F5F7"; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                    Text { anchors.right: parent.right; text: "Super + P"; color: "#8E8E96"; font.family: Tema.font; font.pixelSize: 11 }
                }
                Item {
                    width: parent.width; height: 14
                    Text { text: I18n.t("Processore"); color: "#8E8E96"; font.family: Tema.font; font.pixelSize: 11 }
                    Text { anchors.right: parent.right; text: Math.round(hud.dati.cpu || 0) + "%"; color: "#F5F5F7"; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                }
                Canvas {
                    id: grafico
                    width: parent.width; height: 28
                    onPaint: {
                        var c = getContext("2d"); c.reset()
                        var s = hud.storia; if (s.length < 2) return
                        var passo = width / 29
                        c.beginPath()
                        for (var i = 0; i < s.length; i++) {
                            var x = (29 - (s.length - 1) + i) * passo, y = height - 2 - (height - 4) * s[i] / 100
                            if (i === 0) c.moveTo(x, y); else c.lineTo(x, y)
                        }
                        c.strokeStyle = "#30D158"; c.lineWidth = 1.6; c.stroke()
                    }
                }
                Item {
                    width: parent.width; height: 14
                    Text { text: I18n.t("Memoria"); color: "#8E8E96"; font.family: Tema.font; font.pixelSize: 11 }
                    Text { anchors.right: parent.right; text: (hud.dati.memoriaUsata || 0).toLocaleString(Qt.locale(), "f", 1) + " di " + (hud.dati.memoriaTotale || 0).toLocaleString(Qt.locale(), "f", 1) + " GB"; color: "#F5F5F7"; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                }
                Rectangle {
                    width: parent.width; height: 4; radius: 2; color: "#1FFFFFFF"
                    Rectangle { width: parent.width * (hud.dati.memoriaPercento || 0) / 100; height: 4; radius: 2; color: "#F5F5F7" }
                }
                Rectangle { width: parent.width; height: 1; color: "#1AFFFFFF" }
                Row {
                    width: parent.width
                    Repeater {
                        model: [
                            { t: I18n.t("Disco"), v: (hud.dati.disco || 0) + " MB/s" },
                            { t: I18n.t("Rete"), v: (hud.dati.rete || 0) + " MB/s" },
                            { t: I18n.t("Temp."), v: hud.dati.temperatura > 0 ? hud.dati.temperatura + " °C" : "—" }
                        ]
                        Column {
                            width: parent.width / 3
                            spacing: 2
                            Text { text: modelData.t; color: "#8E8E96"; font.family: Tema.font; font.pixelSize: 11 }
                            Text { text: modelData.v; color: "#F5F5F7"; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: aggiornaStato()
}
