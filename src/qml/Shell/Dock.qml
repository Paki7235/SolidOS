// Dock in basso al centro: app fissate e app aperte, puntino sotto quelle aperte,
// nome al passaggio del mouse, saltello durante l'avvio, menu con il tasto destro.
import QtQuick
import QtQuick.Window
import org.kde.layershell 1.0 as LayerShell
import SolidUI

Window {
    id: dock
    property var voci: []
    property var inAvvio: ({})
    property string sopra: ""
    signal menu(var voce, real centroX)

    function aggiorna() {
        voci = shell.chiama0("dock")
        var nuovi = {}
        for (var k in inAvvio) {
            var v = voci.find(function (x) { return x.id === k })
            if (!(v && v.aperta) && Date.now() - inAvvio[k] < 12000) nuovi[k] = inAvvio[k]
        }
        inAvvio = nuovi
    }
    function clic(voce) {
        var esito = shell.chiama("dockClic", [voce.id])
        if (esito === "avviata") { var a = Object.assign({}, inAvvio); a[voce.id] = Date.now(); inAvvio = a }
    }

    readonly property int lato: 48
    readonly property int passo: 58
    readonly property int etichetta: 30

    LayerShell.Window.scope: "dock"
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.anchors: LayerShell.Window.AnchorBottom
    LayerShell.Window.exclusionZone: 74
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
    width: Math.max(200, fila.width + 24)
    height: 74 + etichetta
    color: "transparent"
    visible: true

    Timer { interval: 1500; repeat: true; running: Object.keys(dock.inAvvio).length > 0; onTriggered: dock.aggiorna() }

    // Nome dell'app sotto il puntatore
    Rectangle {
        visible: dock.sopra !== ""
        y: 2
        x: Math.max(0, Math.min(dock.width - width, etichettaX - width / 2))
        property real etichettaX: 0
        id: nuvola
        width: testoNuvola.implicitWidth + 20
        height: 24
        radius: 7
        color: "#E6202126"
        border.color: "#1FFFFFFF"
        Text { id: testoNuvola; anchors.centerIn: parent; text: dock.sopra; color: "#F5F5F7"; font.family: Tema.font; font.pixelSize: 12 }
    }

    // Fondo del dock
    Rectangle {
        id: fondo
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        width: fila.width + 16
        height: 64
        radius: 20
        color: "#B8282A32"
        border.color: "#24FFFFFF"
        border.width: 1

        Row {
            id: fila
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -2
            spacing: 2
            Repeater {
                model: dock.voci
                Item {
                    id: cella
                    required property var modelData
                    required property int index
                    readonly property bool avvio: dock.inAvvio[modelData.id] !== undefined
                    width: dock.passo
                    height: 58
                    // separatore tra fissate e solo aperte
                    Rectangle {
                        visible: !cella.modelData.fissata && (cella.index === 0 || dock.voci[cella.index - 1].fissata)
                        x: -3; y: 10; width: 1; height: 38
                        color: "#33FFFFFF"
                    }
                    Rectangle {
                        anchors.centerIn: icona
                        width: dock.lato + 8; height: dock.lato + 8; radius: 12
                        color: area.pressed ? "#33FFFFFF" : (area.containsMouse ? "#1AFFFFFF" : "transparent")
                    }
                    Image {
                        id: icona
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 3
                        width: dock.lato; height: dock.lato
                        sourceSize.width: dock.lato * 2; sourceSize.height: dock.lato * 2
                        source: "image://icona/" + cella.modelData.icona
                        smooth: true
                        SequentialAnimation on y {
                            running: cella.avvio && Tema.animazioni
                            loops: Animation.Infinite
                            NumberAnimation { to: -9; duration: 260; easing.type: Easing.OutQuad }
                            NumberAnimation { to: 3; duration: 260; easing.type: Easing.InQuad }
                            onRunningChanged: if (!running) icona.y = 3
                        }
                        opacity: cella.avvio && !Tema.animazioni ? 0.6 : 1
                    }
                    // Puntino: app aperta (più largo se è quella in primo piano)
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 0
                        visible: cella.modelData.aperta
                        width: cella.modelData.attiva ? 14 : 5
                        height: 5
                        radius: 2.5
                        color: cella.modelData.attiva ? "#FFFFFF" : "#B8B8C0"
                        Behavior on width { enabled: Tema.animazioni; NumberAnimation { duration: 150 } }
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onEntered: { dock.sopra = cella.modelData.nome; nuvola.etichettaX = fondo.x + fila.x + cella.x + cella.width / 2 }
                        onExited: if (dock.sopra === cella.modelData.nome) dock.sopra = ""
                        onClicked: function (ev) {
                            dock.sopra = ""
                            if (ev.button === Qt.RightButton) dock.menu(cella.modelData, fondo.x + fila.x + cella.x + cella.width / 2)
                            else if (ev.button === Qt.MiddleButton) shell.chiama("dockApri", [cella.modelData.id])
                            else dock.clic(cella.modelData)
                        }
                    }
                }
            }
        }
    }
    Component.onCompleted: aggiorna()
}
