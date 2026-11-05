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

    Component.onCompleted: aggiornaStato()
}
