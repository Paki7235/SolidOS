// Registratore vocale: a sinistra le registrazioni (nome, data, durata) con il grande pulsante
// rosso in fondo; a destra la registrazione scelta con la forma d'onda, il nome da cambiare e i
// comandi (indietro 15 s, riproduci, avanti 15 s, velocità). Durante la registrazione a destra
// scorrono le barre del livello, con il tempo, la pausa e «Fine».
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Registratore")
    width: 940
    height: 620
    minimumWidth: 700
    minimumHeight: 460

    property var voci: []
    property string scelta: ""
    property var stato: ({ registra: false })
    readonly property var attuale: voci.find(function (v) { return v.id === scelta }) || null
    readonly property color rosso: "#EF4444"

    function tempo(s, decimi) {
        s = Math.max(0, s || 0)
        var m = Math.floor(s / 60), r = Math.floor(s % 60)
        var t = (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r
        if (decimi) t += "," + Math.floor((s * 10) % 10)
        return t
    }
    function ricarica() {
        voci = ponte.chiama0("elenco")
        if (!attuale && voci.length) scelta = voci[0].id
    }
    function registra() {
        lettore.stop()
        stato = ponte.chiama0("avvia")
        if (stato.errore) avviso.mostra(stato.errore)
    }
    function fine() {
        var r = ponte.chiama("ferma", [true])
        stato = { registra: false }
        ricarica()
        if (r.ok) scelta = r.id
    }
    Component.onCompleted: ricarica()
    Timer {
        interval: 60; repeat: true; running: finestra.stato.registra
        onTriggered: { finestra.stato = ponte.chiama0("stato"); if (finestra.stato.errore) { avviso.mostra(finestra.stato.errore); finestra.fine() } }
    }
    Shortcut { sequence: "Space"; enabled: !finestra.stato.registra && !!finestra.attuale; onActivated: lettore.playbackState === MediaPlayer.PlayingState ? lettore.pause() : lettore.play() }

    MediaPlayer {
        id: lettore
        source: finestra.attuale ? finestra.attuale.percorso : ""
        audioOutput: AudioOutput { volume: 1.0 }
        playbackRate: velocita.valore
    }

    // forma d'onda: barre simmetriche, quelle già ascoltate colorate
    component Onde: Item {
        id: onde
        property var livelli: []
        property real avanzamento: -1      // 0..1, -1 = nessuno
        property color colore: Tema.testoSecondario
        property color coloreAscoltato: finestra.rosso
        property real larghezzaBarra: 3
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.max(1, (onde.width - onde.livelli.length * onde.larghezzaBarra) / Math.max(1, onde.livelli.length - 1))
            Repeater {
                model: onde.livelli
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: onde.larghezzaBarra; radius: width / 2
                    height: Math.max(3, modelData * onde.height)
                    color: onde.avanzamento >= 0 && index / onde.livelli.length <= onde.avanzamento ? onde.coloreAscoltato : onde.colore
                }
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Elenco ──
        Rectangle {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            color: Tema.superficie
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: 16
                    Text { text: I18n.t("Registrazioni"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 20; font.weight: Font.Bold; Layout.fillWidth: true }
                    Rectangle {
                        width: 30; height: 30; radius: 8
                        color: sopraC.hovered ? Tema.superficieAlta : "transparent"
                        HoverHandler { id: sopraC }
                        Simbolo { anchors.centerIn: parent; nome: "file"; lato: 17; colore: Tema.testoSecondario }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ponte.chiama0("apriCartella") }
                        ToolTip.visible: sopraC.hovered; ToolTip.text: I18n.t("Apri la cartella")
                    }
                }
                ListView {
                    id: elenco
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: finestra.voci
                    ScrollBar.vertical: ScrollBar {}
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool scelta: finestra.scelta === modelData.id
                        width: elenco.width - 16; x: 8
                        height: 62
                        radius: 10
                        color: scelta ? Tema.superficieAlta : (sopraV.hovered ? Qt.rgba(0.5, 0.5, 0.5, 0.07) : "transparent")
                        HoverHandler { id: sopraV }
                        ColumnLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: 3
                            Item { Layout.fillHeight: true }
                            Text { Layout.fillWidth: true; text: modelData.nome; elide: Text.ElideRight; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: modelData.data; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12; Layout.fillWidth: true }
                                Text { text: finestra.tempo(modelData.durata); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12; font.features: { "tnum": 1 } }
                            }
                            Item { Layout.fillHeight: true }
                        }
                        MouseArea { anchors.fill: parent; enabled: !finestra.stato.registra; cursorShape: Qt.PointingHandCursor; onClicked: { lettore.stop(); finestra.scelta = modelData.id } }
                    }
                    Column {
                        anchors.centerIn: parent
                        visible: elenco.count === 0 && !finestra.stato.registra
                        spacing: 8
                        width: parent.width - 40
                        Simbolo { anchors.horizontalCenter: parent.horizontalCenter; nome: "microfono"; lato: 40; colore: Tema.testoSecondario; opacity: 0.6 }
                        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; text: I18n.t("Nessuna registrazione. Premi il pulsante rosso per iniziare."); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13 }
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: Tema.bordo }
                // pulsante rosso
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 96
                    Rectangle {
                        id: anello
                        anchors.centerIn: parent
                        width: 62; height: 62; radius: 31
                        color: "transparent"
                        border.color: Tema.testoSecondario; border.width: 3
                        Rectangle {
                            anchors.centerIn: parent
                            width: finestra.stato.registra ? 24 : 48
                            height: width
                            radius: finestra.stato.registra ? 6 : width / 2
                            color: finestra.rosso
                            scale: premi.pressed ? 0.9 : 1
                            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on radius { NumberAnimation { duration: 180 } }
                            Behavior on scale { NumberAnimation { duration: 100 } }
                        }
                        MouseArea { id: premi; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: finestra.stato.registra ? finestra.fine() : finestra.registra() }
                        Accessible.name: finestra.stato.registra ? I18n.t("Ferma") : I18n.t("Registra")
                        Accessible.role: Accessible.Button
                    }
                }
            }
        }
        Rectangle { Layout.fillHeight: true; width: 1; color: Tema.bordo }

        // ── Registrazione in corso ──
        ColumnLayout {
            visible: finestra.stato.registra
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 18
            Item { Layout.fillHeight: true }
            Text { Layout.alignment: Qt.AlignHCenter; text: finestra.stato.nome || ""; color: Tema.testo; font.family: Tema.font; font.pixelSize: 20; font.weight: Font.DemiBold }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: finestra.tempo(finestra.stato.secondi, true)
                color: Tema.testo; font.family: Tema.font; font.pixelSize: 54; font.weight: Font.Light; font.features: { "tnum": 1 }
            }
            Onde {
                Layout.fillWidth: true
                Layout.leftMargin: 40; Layout.rightMargin: 40
                Layout.preferredHeight: 150
                livelli: {
                    var l = (finestra.stato.livelli || []).slice(-100)
                    while (l.length < 100) l.unshift(0)
                    return l
                }
                colore: finestra.stato.pausa ? Tema.testoSecondario : finestra.rosso
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: !!finestra.stato.pausa
                text: I18n.t("In pausa"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12
                Pulsante { text: finestra.stato.pausa ? I18n.t("Riprendi") : I18n.t("Pausa"); onClicked: finestra.stato = ponte.chiama("pausa", [!finestra.stato.pausa]) }
                Pulsante { text: I18n.t("Fine"); principale: true; onClicked: finestra.fine() }
                Pulsante { text: I18n.t("Annulla"); onClicked: { ponte.chiama("ferma", [false]); finestra.stato = { registra: false } } }
            }
            Item { Layout.fillHeight: true }
        }

        // ── Registrazione scelta ──
        ColumnLayout {
            visible: !finestra.stato.registra
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14
            Item { Layout.fillHeight: true; visible: !finestra.attuale }
            Text {
                visible: !finestra.attuale
                Layout.alignment: Qt.AlignHCenter
                text: I18n.t("Le registrazioni si salvano in Musica, cartella Registrazioni.")
                color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 14
            }
            Item { Layout.fillHeight: true; visible: !finestra.attuale }

            RowLayout {
                visible: !!finestra.attuale
                Layout.fillWidth: true
                Layout.leftMargin: 32; Layout.rightMargin: 24; Layout.topMargin: 24
                spacing: 8
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 2
                    TextInput {
                        id: nome
                        Layout.fillWidth: true
                        text: finestra.attuale ? finestra.attuale.nome : ""
                        color: Tema.testo; font.family: Tema.font; font.pixelSize: 24; font.weight: Font.Bold
                        selectByMouse: true
                        onEditingFinished: {
                            if (!finestra.attuale || !text.trim() || text === finestra.attuale.nome) return
                            lettore.stop()
                            var r = ponte.chiama("rinomina", [finestra.attuale.id, text])
                            if (r.ok) { finestra.scelta = r.id; finestra.ricarica() } else { avviso.mostra(r.messaggio || I18n.t("Nome non valido")); text = finestra.attuale.nome }
                        }
                    }
                    Text { text: finestra.attuale ? finestra.attuale.data : ""; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13 }
                }
                Repeater {
                    model: [{ s: "matita", t: I18n.t("Rinomina") }, { s: "cestino", t: I18n.t("Elimina") }]
                    Rectangle {
                        width: 34; height: 34; radius: 8
                        color: sopraA.hovered ? Tema.superficieAlta : "transparent"
                        HoverHandler { id: sopraA }
                        Simbolo { anchors.centerIn: parent; nome: modelData.s; lato: 18; colore: modelData.s === "cestino" ? finestra.rosso : Tema.testo }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.s === "matita") { nome.forceActiveFocus(); nome.selectAll() }
                                else { lettore.stop(); ponte.chiama("elimina", [finestra.attuale.id]); finestra.scelta = ""; finestra.ricarica(); avviso.mostra(I18n.t("Registrazione spostata nel cestino")) }
                            }
                        }
                        ToolTip.visible: sopraA.hovered; ToolTip.text: modelData.t
                    }
                }
            }
            Item { Layout.fillHeight: true; visible: !!finestra.attuale }
            // forma d'onda con il punto di ascolto (clic o trascinamento per spostarsi)
            Item {
                visible: !!finestra.attuale
                Layout.fillWidth: true
                Layout.leftMargin: 32; Layout.rightMargin: 32
                Layout.preferredHeight: 160
                Onde {
                    anchors.fill: parent
                    livelli: finestra.attuale && finestra.attuale.onde.length ? finestra.attuale.onde : Array(80).fill(0.15)
                    avanzamento: lettore.duration > 0 ? lettore.position / lettore.duration : 0
                    larghezzaBarra: 4
                }
                Rectangle {
                    x: (lettore.duration > 0 ? lettore.position / lettore.duration : 0) * (parent.width - 2)
                    width: 2; height: parent.height; radius: 1
                    color: finestra.rosso
                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: -4; width: 10; height: 10; radius: 5; color: finestra.rosso }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function vai(x) { if (lettore.duration > 0) lettore.position = Math.max(0, Math.min(1, x / width)) * lettore.duration }
                    onPressed: function (m) { vai(m.x) }
                    onPositionChanged: function (m) { if (pressed) vai(m.x) }
                }
            }
            RowLayout {
                visible: !!finestra.attuale
                Layout.fillWidth: true
                Layout.leftMargin: 32; Layout.rightMargin: 32
                Text { text: finestra.tempo(lettore.position / 1000); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12; font.features: { "tnum": 1 } }
                Item { Layout.fillWidth: true }
                Text { text: "−" + finestra.tempo(((lettore.duration || (finestra.attuale ? finestra.attuale.durata * 1000 : 0)) - lettore.position) / 1000); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12; font.features: { "tnum": 1 } }
            }
            RowLayout {
                visible: !!finestra.attuale
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 8
                spacing: 26
                // velocità
                Rectangle {
                    id: velocita
                    readonly property var passi: [1, 1.25, 1.5, 2, 0.75]
                    property int i: 0
                    readonly property real valore: passi[i]
                    width: 52; height: 30; radius: 15
                    color: Tema.superficieAlta
                    Text { anchors.centerIn: parent; text: String(velocita.valore).replace(".", ",") + "×"; color: Tema.testo; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: velocita.i = (velocita.i + 1) % velocita.passi.length }
                    ToolTip.visible: sopraVel.hovered; ToolTip.text: I18n.t("Velocità")
                    HoverHandler { id: sopraVel }
                }
                Repeater {
                    model: [{ s: "freccia-giro", d: -15000 }, { s: "", d: 0 }, { s: "freccia-giro", d: 15000 }]
                    Item {
                        width: modelData.d === 0 ? 60 : 44; height: 60
                        Rectangle {
                            visible: modelData.d === 0
                            anchors.fill: parent; radius: 30
                            color: Tema.testo
                            Simbolo {
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: lettore.playbackState === MediaPlayer.PlayingState ? 0 : 2
                                nome: lettore.playbackState === MediaPlayer.PlayingState ? "pausa" : "play"
                                lato: 26; colore: Tema.sfondo
                            }
                        }
                        Simbolo {
                            visible: modelData.d !== 0
                            anchors.centerIn: parent; anchors.verticalCenterOffset: -6
                            nome: "freccia-giro"; lato: 26; colore: Tema.testo
                            transform: Scale { origin.x: 13; xScale: modelData.d > 0 ? -1 : 1 }
                        }
                        Text {
                            visible: modelData.d !== 0
                            anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                            text: "15"; color: Tema.testo; font.family: Tema.font; font.pixelSize: 11; font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.d === 0) lettore.playbackState === MediaPlayer.PlayingState ? lettore.pause() : lettore.play()
                                else lettore.position = Math.max(0, Math.min(lettore.duration, lettore.position + modelData.d))
                            }
                        }
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.d === 0 ? I18n.t("Riproduci") : (modelData.d < 0 ? I18n.t("Indietro di 15 secondi") : I18n.t("Avanti di 15 secondi"))
                    }
                }
                Item { width: 52; height: 30 }
            }
            Item { Layout.preferredHeight: 30; visible: !!finestra.attuale }
        }
    }
    Messaggio { id: avviso }
}
