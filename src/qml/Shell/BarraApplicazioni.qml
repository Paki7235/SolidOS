// Barra delle applicazioni come su Windows 11: una sola barra in basso.
// Al centro il pulsante S (Start), le app fissate e aperte e il Cestino;
// a destra rete, volume, batteria (centro di controllo) e data/ora (notifiche);
// all'estremità destra la striscia «Mostra desktop».
import QtQuick
import QtQuick.Window
import org.kde.layershell 1.0 as LayerShell
import SolidUI

Window {
    id: barra
    property var voci: []
    property var inAvvio: ({})
    property var stato: ({})
    property var prestazioni: ({})
    property bool cestinoPieno: false
    property string ora: ""
    property string giorno: ""
    // Trascinamento per riordinare (come nel Dock)
    property int trascinaDa: -1
    property int trascinaA: -1
    property real spostamento: 0
    property bool appenaTrascinato: false
    readonly property int quanteFissate: voci.filter(function (v) { return v.fissata }).length
    // Impostazioni › Barra e Dock › Dimensione delle icone: piccole / medie / grandi
    readonly property int lato: (Tema.dockLato || 48) <= 40 ? 22 : ((Tema.dockLato || 48) >= 56 ? 32 : 26)
    readonly property int altezza: lato + 22
    readonly property int passo: lato + 18
    signal menu(var voce, real centroX)
    signal start()
    signal controllo()
    signal notifiche()

    function aggiorna() {
        voci = shell.chiama0("dock")
        cestinoPieno = shell.chiama0("cestinoPieno")
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
    function fineTrascinamento() {
        var da = trascinaDa, a = trascinaA
        var ids = voci.map(function (v) { return v.id })
        var trascinata = voci[da]
        if (a !== da || (!trascinata.fissata && a < quanteFissate)) {
            ids.splice(a, 0, ids.splice(da, 1)[0])
            var fissate = []
            for (var i = 0; i < ids.length; i++) {
                var v = voci.find(function (x) { return x.id === ids[i] })
                if (v.fissata || (v.id === trascinata.id && a < quanteFissate + (trascinata.fissata ? 0 : 1)))
                    fissate.push(ids[i])
            }
            shell.chiama("dockOrdina", [fissate])
        }
        trascinaDa = -1; trascinaA = -1; spostamento = 0
        appenaTrascinato = true
    }
    function aggiornaOra() {
        var d = new Date()
        ora = d.toLocaleTimeString(Qt.locale(), "HH:mm")
        giorno = d.toLocaleDateString(Qt.locale(), "dd/MM/yyyy")
    }
    function centro(item) { var p = item.mapToItem(barra.contentItem, item.width / 2, 0); return p.x }

    LayerShell.Window.scope: "barra-applicazioni"
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.anchors: LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: altezza
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
    width: Screen.width
    height: altezza
    color: Tema.vetro
    visible: Tema.stileBarra === "windows"
    onVisibleChanged: if (visible) aggiorna()

    Timer { interval: 1000; repeat: true; running: barra.visible; triggeredOnStart: true; onTriggered: barra.aggiornaOra() }
    Timer { interval: 1500; repeat: true; running: barra.visible && Object.keys(barra.inAvvio).length > 0; onTriggered: barra.aggiorna() }
    Connections { target: shell; function onEvento(nome, dati) { if (nome === "cestino") barra.cestinoPieno = shell.chiama0("cestinoPieno") } }

    Rectangle { width: parent.width; height: 1; color: Tema.separatore }

    // Pulsante della barra: fondo al passaggio del mouse
    component Tasto: Rectangle {
        id: t
        property alias area: ma
        signal premuto(var ev)
        radius: 6
        color: ma.pressed ? Tema.premuto : (ma.containsMouse ? Tema.sopra : "transparent")
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton; onClicked: function (ev) { t.premuto(ev) } }
    }

    // ── Centro: S, app, Cestino ────────────────────────────────────────────
    Row {
        id: centrale
        anchors.centerIn: parent
        spacing: 2

        Tasto {
            id: tastoStart
            width: barra.passo; height: barra.altezza - 8
            anchors.verticalCenter: parent.verticalCenter
            onPremuto: barra.start()
            Rectangle {
                anchors.centerIn: parent
                width: barra.lato + 6; height: barra.lato + 6
                radius: 8
                color: tastoStart.area.pressed ? Qt.darker(Tema.accento, 1.2) : (tastoStart.area.containsMouse ? Qt.lighter(Tema.accento, 1.12) : Tema.accento)
                Image {
                    anchors.centerIn: parent
                    width: barra.lato - 6; height: barra.lato - 6
                    sourceSize.width: 64; sourceSize.height: 64
                    source: "file:///usr/share/" + Tema.idSistema + "/logo-chiaro.svg"
                }
            }
        }

        Repeater {
            model: barra.voci
            Item {
                id: cella
                required property var modelData
                required property int index
                readonly property bool avvio: barra.inAvvio[modelData.id] !== undefined
                width: barra.passo
                height: barra.altezza
                z: barra.trascinaDa === index ? 2 : 1
                transform: Translate {
                    x: barra.trascinaDa === cella.index ? barra.spostamento
                       : (barra.trascinaDa >= 0 && cella.index > barra.trascinaDa && cella.index <= barra.trascinaA) ? -barra.passo
                       : (barra.trascinaDa >= 0 && cella.index < barra.trascinaDa && cella.index >= barra.trascinaA) ? barra.passo : 0
                    Behavior on x { enabled: Tema.animazioni && barra.trascinaDa !== cella.index; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: barra.passo - 4; height: barra.altezza - 8; radius: 6
                    color: area.pressed ? Tema.premuto : (area.containsMouse || cella.modelData.attiva ? Tema.sopra : "transparent")
                }
                Image {
                    id: icona
                    anchors.centerIn: parent
                    width: barra.lato; height: barra.lato
                    sourceSize.width: barra.lato * 2; sourceSize.height: barra.lato * 2
                    source: "image://icona/" + cella.modelData.icona
                    smooth: true
                    opacity: cella.avvio ? 0.55 : 1
                    Behavior on opacity { enabled: Tema.animazioni; NumberAnimation { duration: 300 } }
                }
                // Lineetta sotto le app aperte (più lunga e colorata per quella in primo piano)
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    visible: cella.modelData.aperta || cella.avvio
                    width: cella.modelData.attiva ? 16 : 6
                    height: 3
                    radius: 1.5
                    color: cella.modelData.attiva ? Tema.accento : Tema.testoVetroSecondario
                    Behavior on width { enabled: Tema.animazioni; NumberAnimation { duration: 150 } }
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    property real inizioX: 0
                    onPressed: function (ev) { inizioX = mapToItem(centrale, ev.x, ev.y).x; barra.appenaTrascinato = false }
                    onPositionChanged: function (ev) {
                        if (!pressed || ev.buttons !== Qt.LeftButton) return
                        var x = mapToItem(centrale, ev.x, ev.y).x
                        if (barra.trascinaDa < 0 && Math.abs(x - inizioX) > 10) { barra.trascinaDa = cella.index; barra.trascinaA = cella.index }
                        if (barra.trascinaDa === cella.index) {
                            barra.spostamento = x - inizioX
                            var c = cella.x - tastoStart.width - centrale.spacing + cella.width / 2 + barra.spostamento
                            barra.trascinaA = Math.max(0, Math.min(barra.voci.length - 1, Math.floor(c / (barra.passo + centrale.spacing))))
                        }
                    }
                    onReleased: if (barra.trascinaDa === cella.index) barra.fineTrascinamento()
                    onClicked: function (ev) {
                        if (barra.appenaTrascinato) { barra.appenaTrascinato = false; return }
                        if (ev.button === Qt.RightButton) barra.menu(cella.modelData, barra.centro(cella))
                        else if (ev.button === Qt.MiddleButton) shell.chiama("dockApri", [cella.modelData.id])
                        else barra.clic(cella.modelData)
                    }
                }
            }
        }

        Rectangle { width: 1; height: 24; anchors.verticalCenter: parent.verticalCenter; color: Tema.separatore }

        // Cestino: sempre presente, non si può togliere
        Tasto {
            id: tastoCestino
            width: barra.passo; height: barra.altezza - 8
            anchors.verticalCenter: parent.verticalCenter
            color: dropCestino.containsDrag ? Tema.premuto : (area.pressed ? Tema.premuto : (area.containsMouse ? Tema.sopra : "transparent"))
            onPremuto: function (ev) {
                if (ev.button === Qt.RightButton) barra.menu({ cestino: true, nome: I18n.t("Cestino"), pieno: barra.cestinoPieno }, barra.centro(tastoCestino))
                else shell.chiama0("cestinoApri")
            }
            Image {
                anchors.centerIn: parent
                width: barra.lato; height: barra.lato
                sourceSize.width: barra.lato * 2; sourceSize.height: barra.lato * 2
                source: "image://icona/" + (barra.cestinoPieno ? "user-trash-full" : "user-trash")
            }
            DropArea {
                id: dropCestino
                anchors.fill: parent
                onDropped: function (d) {
                    if (!d.hasUrls) return
                    shell.chiama("cestinoSposta", [Array.prototype.map.call(d.urls, function (u) { return u.toString() })])
                    d.acceptProposedAction()
                }
            }
        }
    }

    // ── Destra: stato del sistema, data e ora, «Mostra desktop» ────────────
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 0
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Tasto {
            visible: Tema.barraPrestazioni !== false
            width: testoPrestazioni.implicitWidth + 16; height: barra.altezza - 8
            anchors.verticalCenter: parent.verticalCenter
            onPremuto: shell.chiama("apri", ["monitor"])
            Text {
                id: testoPrestazioni
                anchors.centerIn: parent
                text: Math.round(barra.prestazioni.cpu || 0) + "%  ·  " + (barra.prestazioni.memoriaUsata || 0).toLocaleString(Qt.locale(), "f", 1) + " GB"
                color: Tema.testoVetroSecondario; font.family: Tema.font; font.pixelSize: 12; font.features: ({ "tnum": 1 })
            }
        }
        // Rete, volume e batteria: un solo pulsante, apre il centro di controllo
        Tasto {
            width: iconeStato.width + 20; height: barra.altezza - 8
            anchors.verticalCenter: parent.verticalCenter
            onPremuto: barra.controllo()
            Row {
                id: iconeStato
                anchors.centerIn: parent
                spacing: 10
                Item {
                    visible: barra.stato.connesso !== undefined
                    width: 18; height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    Image {
                        visible: barra.stato.reteTipo === "ethernet"
                        anchors.centerIn: parent
                        width: 16; height: 16; sourceSize.width: 32; sourceSize.height: 32
                        source: "image://icona/network-wired-symbolic" + (Tema.chiaro ? "?c" : "")
                    }
                    SegnaleWifi {
                        visible: barra.stato.reteTipo !== "ethernet"
                        anchors.centerIn: parent
                        connesso: !!barra.stato.connesso
                        percento: barra.stato.segnale || 0
                    }
                }
                Image {
                    width: 16; height: 16; sourceSize.width: 32; sourceSize.height: 32
                    anchors.verticalCenter: parent.verticalCenter
                    source: "image://icona/" + (barra.stato.muto ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic") + (Tema.chiaro ? "?c" : "")
                }
                Row {
                    visible: !!(barra.stato.batteria && barra.stato.batteria.percentuale !== undefined)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Item {
                        width: 24; height: 12; anchors.verticalCenter: parent.verticalCenter
                        Rectangle { width: 21; height: 12; radius: 3; color: "transparent"; border.color: Tema.testoVetroSecondario; border.width: 1 }
                        Rectangle { x: 2; y: 2; height: 8; radius: 1.5; width: 17 * Math.max(0.08, (barra.stato.batteria ? barra.stato.batteria.percentuale : 0) / 100); color: (barra.stato.batteria && barra.stato.batteria.percentuale <= 15) ? "#FF453A" : Tema.testoVetro }
                        Rectangle { x: 22; y: 4; width: 2; height: 4; radius: 1; color: Tema.testoVetroSecondario }
                    }
                    Text { text: (barra.stato.batteria ? barra.stato.batteria.percentuale : 0) + "%"; color: Tema.testoVetro; font.family: Tema.font; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
        // Data e ora: apre le notifiche
        Tasto {
            width: Math.max(testoOra.implicitWidth, testoData.implicitWidth) + 20; height: barra.altezza - 8
            anchors.verticalCenter: parent.verticalCenter
            onPremuto: barra.notifiche()
            Column {
                anchors.centerIn: parent
                Text { id: testoOra; anchors.right: parent.right; text: barra.ora; color: Tema.testoVetro; font.family: Tema.font; font.pixelSize: 12; font.features: ({ "tnum": 1 }) }
                Text { id: testoData; anchors.right: parent.right; text: barra.giorno; color: Tema.testoVetro; font.family: Tema.font; font.pixelSize: 12; font.features: ({ "tnum": 1 }) }
            }
        }
        // Striscia «Mostra desktop» (come su Windows)
        Rectangle {
            width: 10; height: barra.altezza
            color: mostraDesktop.containsMouse ? Tema.sopra : "transparent"
            Rectangle { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: 1; height: 20; color: Tema.separatore }
            MouseArea { id: mostraDesktop; anchors.fill: parent; hoverEnabled: true; onClicked: shell.chiama("appAttiva", ["scrivania"]) }
        }
    }

    Component.onCompleted: aggiorna()
}
