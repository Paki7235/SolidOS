// Barra in alto: menu di sistema (logo), nome dell'app in primo piano;
// a destra processore, rete, batteria, volume, centro di controllo e orologio.
import QtQuick
import QtQuick.Window
import org.kde.layershell 1.0 as LayerShell
import SolidUI

Window {
    id: barra
    property var stato: ({})
    property var attiva: ({})
    property var prestazioni: ({})
    property string ora: ""
    signal menuSistema()
    signal controllo()
    signal notifiche()

    function aggiorna() {
        attiva = shell.chiama0("finestraAttiva")
    }
    function aggiornaStato() {
        stato = shell.chiama0("stato")
        prestazioni = shell.chiama0("prestazioni")
    }
    function aggiornaOra() {
        var d = new Date()
        ora = d.toLocaleString(Qt.locale(), "ddd d MMM") + "   " + d.toLocaleTimeString(Qt.locale(), "HH:mm")
    }

    LayerShell.Window.scope: "barra-superiore"
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: 28
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
    height: 28
    color: "#C70C0E14"
    visible: true

    Timer { interval: 1000; repeat: true; running: true; triggeredOnStart: true; onTriggered: barra.aggiornaOra() }
    Timer { interval: 4000; repeat: true; running: true; triggeredOnStart: true; onTriggered: barra.aggiornaStato() }

    component Pulsantino: Rectangle {
        id: p
        property alias contenuto: interno.data
        signal premuto()
        width: interno.childrenRect.width + 16
        height: 22
        radius: 5
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: ma.pressed ? "#40FFFFFF" : (ma.containsMouse ? "#26FFFFFF" : "transparent")
        Item { id: interno; x: 8; width: childrenRect.width; height: parent.height }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: p.premuto() }
    }

    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#14FFFFFF" }

    // ── Sinistra ───────────────────────────────────────────────────────────
    Row {
        anchors.left: parent.left
        anchors.leftMargin: 8
        height: parent.height
        spacing: 4
        Pulsantino {
            onPremuto: barra.menuSistema()
            contenuto: Image {
                y: 4; width: 14; height: 14
                sourceSize.width: 28; sourceSize.height: 28
                source: "file:///usr/share/" + Tema.idSistema + "/logo-chiaro.svg"
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: barra.attiva.nome || ""
            color: "#F5F5F7"
            font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold
            leftPadding: 4
        }
    }

    // ── Destra ─────────────────────────────────────────────────────────────
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 8
        height: parent.height
        spacing: 2
        Pulsantino {
            onPremuto: shell.chiama("apri", ["monitor"])
            contenuto: Text { y: 4; text: Math.round(barra.prestazioni.cpu || 0) + "%  ·  " + (barra.prestazioni.memoriaUsata || 0).toLocaleString(Qt.locale(), "f", 1) + " GB"; color: "#D4D4D8"; font.family: Tema.font; font.pixelSize: 12; font.features: ({ "tnum": 1 }) }
        }
        Pulsantino {
            visible: barra.stato.connesso !== undefined
            onPremuto: barra.controllo()
            contenuto: Image {
                y: 3; width: 16; height: 16; sourceSize.width: 32; sourceSize.height: 32
                source: "image://icona/" + (barra.stato.reteTipo === "ethernet" ? "network-wired-symbolic" : (barra.stato.connesso ? "network-wireless-signal-excellent-symbolic" : "network-wireless-offline-symbolic"))
            }
        }
        Pulsantino {
            visible: !!(barra.stato.batteria && barra.stato.batteria.percentuale !== undefined)
            onPremuto: barra.controllo()
            contenuto: Row {
                y: 4; spacing: 5
                Item {
                    width: 24; height: 12; anchors.verticalCenter: parent.verticalCenter
                    Rectangle { x: 0; width: 21; height: 12; radius: 3; color: "transparent"; border.color: "#8CF5F5F7"; border.width: 1 }
                    Rectangle { x: 2; y: 2; height: 8; radius: 1.5; width: 17 * Math.max(0.08, (barra.stato.batteria ? barra.stato.batteria.percentuale : 0) / 100); color: (barra.stato.batteria && barra.stato.batteria.percentuale <= 15) ? "#FF453A" : "#F5F5F7" }
                    Rectangle { x: 22; y: 4; width: 2; height: 4; radius: 1; color: "#8CF5F5F7" }
                }
                Text { text: (barra.stato.batteria ? barra.stato.batteria.percentuale : 0) + "%"; color: "#F5F5F7"; font.family: Tema.font; font.pixelSize: 12 }
            }
        }
        Pulsantino {
            onPremuto: barra.controllo()
            contenuto: Image {
                y: 3; width: 16; height: 16; sourceSize.width: 32; sourceSize.height: 32
                source: "image://icona/" + (barra.stato.muto ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic")
            }
        }
        Pulsantino {
            onPremuto: barra.controllo()
            contenuto: Image {
                y: 3; width: 18; height: 16; sourceSize.width: 36; sourceSize.height: 32
                source: "image://icona/" + Tema.idSistema + "-centro-controllo"
            }
        }
        Pulsantino {
            onPremuto: barra.notifiche()
            contenuto: Text { y: 4; text: barra.ora; color: "#F5F5F7"; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.Medium; font.features: ({ "tnum": 1 }) }
        }
    }
}
