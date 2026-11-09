// Scrivania: sfondo e icone dei file in ~/Scrivania, sotto tutte le finestre.
// Doppio clic apre, tasto destro mostra il menu, si possono trascinare file qui sopra.
import QtQuick
import QtQuick.Controls
import QtQuick.Window
import org.kde.layershell 1.0 as LayerShell
import SolidUI

Window {
    id: scrivania
    property string sfondo: shell.chiama0("sfondo")
    property var elementi: shell.chiama0("scrivania")
    property string scelto: ""
    property string inRinomina: ""
    property var menuVoci: []
    function aggiorna() { elementi = shell.chiama0("scrivania") }
    function apriMenu(voci, x, y) { menuVoci = voci; menu.x = Math.min(x, width - menu.width - 8); menu.y = Math.min(y, height - menu.height - 8); menu.visible = true }

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

    // Clic sul vuoto: deseleziona; tasto destro: menu della scrivania
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function (ev) {
            menu.visible = false
            scrivania.scelto = ""; scrivania.inRinomina = ""
            if (ev.button === Qt.RightButton) scrivania.apriMenu([
                { t: I18n.t("Nuova cartella"), f: function () { shell.chiama("scrivaniaNuova", ["cartella"]) } },
                { t: I18n.t("Nuovo documento di testo"), f: function () { shell.chiama("scrivaniaNuova", ["testo"]) } },
                { sep: true },
                { t: I18n.t("Apri la Scrivania in File"), f: function () { shell.chiama("scrivaniaApri", [shell.chiama0("scrivaniaCartella")]) } },
                { t: I18n.t("Cambia sfondo…"), f: function () { shell.chiama("apri", ["impostazioni", "aspetto"]) } },
                { t: I18n.t("Impostazioni schermo…"), f: function () { shell.chiama("apri", ["impostazioni", "schermo"]) } }
            ], ev.x, ev.y)
        }
    }

    // File trascinati sulla scrivania: copiati nella cartella Scrivania
    DropArea {
        anchors.fill: parent
        onDropped: function (drop) {
            if (drop.hasUrls) { shell.chiama("scrivaniaCopia", [Array.prototype.map.call(drop.urls, function (u) { return u.toString() })]); drop.acceptProposedAction() }
        }
    }

    // Icone in colonne dall'alto a sinistra (sotto la barra, sopra il dock)
    Grid {
        id: griglia
        x: 16
        y: 40
        flow: Grid.TopToBottom
        rows: Math.max(1, Math.floor((scrivania.height - 40 - 90) / 104))
        columnSpacing: 6
        rowSpacing: 4
        Repeater {
            model: scrivania.elementi
            Item {
                id: icona
                required property var modelData
                readonly property bool selezionata: scrivania.scelto === modelData.percorso
                width: 92
                height: 100
                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: icona.selezionata ? "#40FFFFFF" : (area.containsMouse ? "#1FFFFFFF" : "transparent")
                    border.color: icona.selezionata ? "#66FFFFFF" : "transparent"
                }
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 6
                    width: 52; height: 52
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 104; sourceSize.height: 104
                    source: icona.modelData.anteprima || ("image://icona/" + icona.modelData.icona)
                    asynchronous: true
                }
                Text {
                    visible: scrivania.inRinomina !== icona.modelData.percorso
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 62
                    width: parent.width - 6
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: icona.modelData.nome
                    color: "#FFFFFF"
                    style: Text.Raised; styleColor: "#99000000"
                    font.family: Tema.font; font.pixelSize: 12
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: function (ev) {
                        menu.visible = false
                        scrivania.scelto = icona.modelData.percorso
                        if (ev.button === Qt.RightButton) {
                            var p = icona.mapToItem(scrivania.contentItem, ev.x, ev.y)
                            var percorso = icona.modelData.percorso
                            scrivania.apriMenu([
                                { t: I18n.t("Apri"), f: function () { shell.chiama("scrivaniaApri", [percorso]) } },
                                { t: I18n.t("Rinomina"), f: function () { scrivania.inRinomina = percorso } },
                                { sep: true },
                                { t: I18n.t("Sposta nel cestino"), f: function () { shell.chiama("scrivaniaCestino", [percorso]) } }
                            ], p.x, p.y)
                        }
                    }
                    onDoubleClicked: shell.chiama("scrivaniaApri", [icona.modelData.percorso])
                }
                // Rinomina sul posto
                CampoTesto {
                    visible: scrivania.inRinomina === icona.modelData.percorso
                    onVisibleChanged: if (visible) { text = icona.modelData.nome; forceActiveFocus(); selectAll() }
                    y: 62
                    width: parent.width
                    font.pixelSize: 12
                    onAccepted: { shell.chiama("scrivaniaRinomina", [icona.modelData.percorso, text]); scrivania.inRinomina = "" }
                    Keys.onEscapePressed: scrivania.inRinomina = ""
                }
            }
        }
    }

    MenuPopup {
        id: menu
        visible: false
        voci: scrivania.menuVoci
        onScelto: visible = false
    }
}
