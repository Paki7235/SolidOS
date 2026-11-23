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
    // Trascinamento per riordinare: indice di partenza, posizione d'arrivo, spostamento in px
    property int trascinaDa: -1
    property int trascinaA: -1
    property real spostamento: 0
    property real alzata: 0
    property bool appenaTrascinato: false
    readonly property int quanteFissate: voci.filter(function (v) { return v.fissata }).length
    property bool cestinoPieno: false
    // Con un'app ingrandita o a tutto schermo il Dock si nasconde e
    // riappare portando il mouse sul bordo in basso (la barra unica in basso resta fissa).
    property bool coperta: false
    onCopertaChanged: console.log("dock: app ingrandita sullo schermo =", coperta)
    property bool tenuta: false          // menu del tasto destro aperto: resta visibile
    property bool rivelata: false
    readonly property bool mostrata: !coperta || rivelata || tenuta || trascinaDa >= 0
    readonly property int pieno: altezza + etichetta
    property real scostamento: mostrata ? 0 : pieno
    Behavior on scostamento { enabled: Tema.animazioni; NumberAnimation { duration: dock.mostrata ? 260 : 200; easing.type: dock.mostrata ? Easing.OutCubic : Easing.InCubic } }
    // Il gestore sta sul contenuto della finestra (un HoverHandler messo direttamente
    // nella Window non ha un elemento a cui agganciarsi e non vede mai il mouse)
    HoverHandler {
        id: passaggio
        parent: dock.contentItem
        onHoveredChanged: if (hovered) { nascondi.stop(); dock.rivelata = true } else nascondi.restart()
    }
    Timer { id: nascondi; interval: 700; onTriggered: if (!passaggio.hovered) dock.rivelata = false }
    signal menu(var voce, real centroX)
    function aggiornaCestino() { cestinoPieno = shell.chiama0("cestinoPieno") }

    function fineTrascinamento() {
        var da = trascinaDa, a = trascinaA
        var ids = voci.map(function (v) { return v.id })
        var trascinata = voci[da]
        if (alzata < -60 && trascinata.fissata) {
            shell.chiama("dockFissa", [trascinata.id, false])          // trascinata fuori: tolta dal dock
        } else if (a !== da || (!trascinata.fissata && a < quanteFissate)) {
            ids.splice(a, 0, ids.splice(da, 1)[0])
            var fissate = []
            for (var i = 0; i < ids.length; i++) {
                var v = voci.find(function (x) { return x.id === ids[i] })
                if (v.fissata || (v.id === trascinata.id && a < quanteFissate + (trascinata.fissata ? 0 : 1)))
                    fissate.push(ids[i])
            }
            shell.chiama("dockOrdina", [fissate])
        }
        trascinaDa = -1; trascinaA = -1; spostamento = 0; alzata = 0
        appenaTrascinato = true
    }

    function aggiorna() {
        voci = shell.chiama0("dock")
        coperta = Tema.stileBarra !== "windows" && shell.chiama0("finestraGrande") === true
        aggiornaCestino()
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

    readonly property int lato: Tema.dockLato || 48
    readonly property int passo: lato + 10
    readonly property int etichetta: 30
    readonly property int altezza: lato + 26

    LayerShell.Window.scope: "dock"
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.anchors: LayerShell.Window.AnchorBottom
    LayerShell.Window.exclusionZone: coperta ? 0 : altezza
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
    width: Math.max(200, fila.width + 24)
    // Nascosto resta solo una striscia di 4 px sul bordo, che non copre i clic dell'app
    height: (mostrata || scostamento < pieno - 0.5) ? pieno : 4
    color: "transparent"
    visible: Tema.stileBarra !== "windows"

    Timer { interval: 1500; repeat: true; running: Object.keys(dock.inAvvio).length > 0; onTriggered: dock.aggiorna() }

    // Nome dell'app sotto il puntatore
    Rectangle {
        visible: dock.sopra !== ""
        y: 2
        x: Math.max(0, Math.min(dock.width - width, etichettaX - width / 2))
        property real etichettaX: 0
        id: nuvola
        transform: Translate { y: dock.scostamento }
        width: testoNuvola.implicitWidth + 20
        height: 24
        radius: 7
        color: Tema.nuvola
        border.color: Tema.vetroBordo
        Text { id: testoNuvola; anchors.centerIn: parent; text: dock.sopra; color: Tema.testoVetro; font.family: Tema.font; font.pixelSize: 12 }
    }

    // Fondo del dock
    Rectangle {
        id: fondo
        transform: Translate { y: dock.scostamento }
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        width: fila.width + 16
        height: dock.lato + 16
        radius: 20
        color: Tema.dock
        border.color: Tema.vetroBordo
        border.width: 1

        Row {
            id: fila
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -2
            spacing: 0
            Repeater {
                model: dock.voci
                Item {
                    id: cella
                    required property var modelData
                    required property int index
                    readonly property bool avvio: dock.inAvvio[modelData.id] !== undefined
                    width: dock.passo
                    height: dock.lato + 10
                    z: dock.trascinaDa === index ? 2 : 1
                    // Durante il trascinamento: l'icona trascinata segue il mouse, le altre fanno posto
                    transform: Translate {
                        x: dock.trascinaDa === cella.index ? dock.spostamento
                           : (dock.trascinaDa >= 0 && cella.index > dock.trascinaDa && cella.index <= dock.trascinaA) ? -dock.passo
                           : (dock.trascinaDa >= 0 && cella.index < dock.trascinaDa && cella.index >= dock.trascinaA) ? dock.passo : 0
                        y: dock.trascinaDa === cella.index ? Math.min(0, dock.alzata) : 0
                        Behavior on x { enabled: Tema.animazioni && dock.trascinaDa !== cella.index; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    }
                    opacity: dock.trascinaDa === cella.index && dock.alzata < -60 && cella.modelData.fissata ? 0.4 : 1
                    // separatore tra fissate e solo aperte
                    Rectangle {
                        visible: !cella.modelData.fissata && (cella.index === 0 || dock.voci[cella.index - 1].fissata)
                        x: -3; y: 10; width: 1; height: dock.lato - 10
                        color: Tema.separatore
                    }
                    Rectangle {
                        anchors.centerIn: icona
                        width: dock.lato + 8; height: dock.lato + 8; radius: 12
                        color: area.pressed ? Tema.premuto : (area.containsMouse ? Tema.sopra : "transparent")
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
                        color: cella.modelData.attiva ? Tema.testoVetro : Tema.testoVetroSecondario
                        Behavior on width { enabled: Tema.animazioni; NumberAnimation { duration: 150 } }
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onEntered: { dock.sopra = cella.modelData.nome; nuvola.etichettaX = fondo.x + fila.x + cella.x + cella.width / 2 }
                        onExited: if (dock.sopra === cella.modelData.nome) dock.sopra = ""
                        property real inizioX: 0
                        property real inizioY: 0
                        onPressed: function (ev) { var p = mapToItem(fila, ev.x, ev.y); inizioX = p.x; inizioY = p.y; dock.appenaTrascinato = false }
                        onPositionChanged: function (ev) {
                            if (!pressed || ev.buttons !== Qt.LeftButton) return
                            var p = mapToItem(fila, ev.x, ev.y)
                            if (dock.trascinaDa < 0 && (Math.abs(p.x - inizioX) > 10 || Math.abs(p.y - inizioY) > 14)) {
                                dock.trascinaDa = cella.index; dock.trascinaA = cella.index; dock.sopra = ""
                            }
                            if (dock.trascinaDa === cella.index) {
                                dock.spostamento = p.x - inizioX
                                dock.alzata = p.y - inizioY
                                var centro = cella.x + cella.width / 2 + dock.spostamento
                                dock.trascinaA = Math.max(0, Math.min(dock.voci.length - 1, Math.floor(centro / dock.passo)))
                            }
                        }
                        onReleased: if (dock.trascinaDa === cella.index) dock.fineTrascinamento()
                        onClicked: function (ev) {
                            if (dock.appenaTrascinato) { dock.appenaTrascinato = false; return }
                            dock.sopra = ""
                            if (ev.button === Qt.RightButton) dock.menu(cella.modelData, fondo.x + fila.x + cella.x + cella.width / 2)
                            else if (ev.button === Qt.MiddleButton) shell.chiama("dockApri", [cella.modelData.id])
                            else dock.clic(cella.modelData)
                        }
                    }
                }
            }
            // ── Cestino: sempre in fondo, non si può togliere ──
            Item {
                id: cellaCestino
                width: dock.passo
                height: dock.lato + 10
                Rectangle { x: 4; y: 10; width: 1; height: dock.lato - 10; color: Tema.separatore }
                Rectangle {
                    anchors.centerIn: iconaCestino
                    width: dock.lato + 8; height: dock.lato + 8; radius: 12
                    color: dropCestino.containsDrag ? Tema.premuto : (areaCestino.pressed ? Tema.premuto : (areaCestino.containsMouse ? Tema.sopra : "transparent"))
                }
                Image {
                    id: iconaCestino
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: 4
                    y: 3
                    width: dock.lato; height: dock.lato
                    sourceSize.width: dock.lato * 2; sourceSize.height: dock.lato * 2
                    source: "image://icona/" + (dock.cestinoPieno ? "user-trash-full" : "user-trash")
                }
                MouseArea {
                    id: areaCestino
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onEntered: { dock.sopra = I18n.t("Cestino"); nuvola.etichettaX = fondo.x + fila.x + cellaCestino.x + cellaCestino.width / 2 }
                    onExited: if (dock.sopra === I18n.t("Cestino")) dock.sopra = ""
                    onClicked: function (ev) {
                        dock.sopra = ""
                        if (ev.button === Qt.RightButton) dock.menu({ cestino: true, nome: I18n.t("Cestino"), pieno: dock.cestinoPieno }, fondo.x + fila.x + cellaCestino.x + cellaCestino.width / 2)
                        else shell.chiama0("cestinoApri")
                    }
                }
                // File trascinati sul cestino: spostati nel cestino
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
    }
    Connections { target: shell; function onEvento(nome, dati) { if (nome === "cestino") dock.aggiornaCestino() } }
    Component.onCompleted: aggiorna()
}
