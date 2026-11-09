// Lettore: Spazio pausa, ← → 10 secondi, ↑ ↓ volume, F schermo intero, M muto.
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window
import QtMultimedia
import SolidUI

Finestra {
    id: finestra
    width: 960
    height: 600
    color: "#000000"
    property var scaletta: []
    property int indice: -1
    readonly property string corrente: indice >= 0 && indice < scaletta.length ? scaletta[indice] : ""
    readonly property bool soloAudio: lettore.hasAudio && !lettore.hasVideo
    title: (corrente ? corrente.split("/").pop() + " — " : "") + I18n.t("Lettore")

    function apri(p) {
        p = p.replace("file://", "")
        scaletta = ponte.chiama("cartella", [p])
        indice = Math.max(0, scaletta.indexOf(p))
        lettore.play()
    }
    function vai(d) { if (scaletta.length) { indice = (indice + d + scaletta.length) % scaletta.length; lettore.play() } }
    function tempo(ms) {
        var s = Math.floor(ms / 1000), m = Math.floor(s / 60), h = Math.floor(m / 60)
        function due(n) { return (n < 10 ? "0" : "") + n }
        return (h > 0 ? h + ":" + due(m % 60) : m) + ":" + due(s % 60)
    }

    Component.onCompleted: { var f = ponte.chiama0("fileIniziale"); if (f.length) apri(f[0]) }

    MediaPlayer {
        id: lettore
        source: finestra.corrente ? "file://" + finestra.corrente : ""
        videoOutput: video
        audioOutput: AudioOutput { id: audio; volume: 0.8 }
        onMediaStatusChanged: if (mediaStatus === MediaPlayer.EndOfMedia && finestra.indice < finestra.scaletta.length - 1) finestra.vai(1)
        onErrorOccurred: function (e, s) { finestra.avviso(s) }
    }

    Shortcut { sequence: "Space"; onActivated: lettore.playbackState === MediaPlayer.PlayingState ? lettore.pause() : lettore.play() }
    Shortcut { sequence: "Right"; onActivated: lettore.position = Math.min(lettore.duration, lettore.position + 10000) }
    Shortcut { sequence: "Left"; onActivated: lettore.position = Math.max(0, lettore.position - 10000) }
    Shortcut { sequence: "Up"; onActivated: audio.volume = Math.min(1, audio.volume + 0.1) }
    Shortcut { sequence: "Down"; onActivated: audio.volume = Math.max(0, audio.volume - 0.1) }
    Shortcut { sequence: "M"; onActivated: audio.muted = !audio.muted }
    Shortcut { sequence: "F"; onActivated: finestra.visibility = finestra.visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen }
    Shortcut { sequence: "Escape"; onActivated: if (finestra.visibility === Window.FullScreen) finestra.visibility = Window.Windowed }
    Shortcut { sequence: StandardKey.Open; onActivated: dialogoApri.open() }

    VideoOutput {
        id: video
        anchors.fill: parent
        anchors.bottomMargin: comandi.visible ? comandi.height : 0
        visible: !finestra.soloAudio
        MouseArea { anchors.fill: parent; onDoubleClicked: finestra.visibility = finestra.visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen; onClicked: lettore.playbackState === MediaPlayer.PlayingState ? lettore.pause() : lettore.play() }
    }

    // Copertina per la musica / schermata iniziale
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -comandi.height / 2
        spacing: 14
        visible: finestra.soloAudio || !finestra.corrente
        Image { anchors.horizontalCenter: parent.horizontalCenter; width: 96; height: 96; sourceSize.width: 192; sourceSize.height: 192; source: "image://icona/" + (finestra.corrente ? "audio-x-generic" : "video-x-generic") }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: finestra.corrente ? (lettore.metaData.stringValue(MediaMetaData.Title) || finestra.corrente.split("/").pop()) : I18n.t("Trascina qui un video o una canzone")
            color: "#F5F5F7"; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.DemiBold
        }
        Text { anchors.horizontalCenter: parent.horizontalCenter; visible: !!finestra.corrente; text: lettore.metaData.stringValue(MediaMetaData.ContributingArtist) || ""; color: "#A1A1AA"; font.family: Tema.font; font.pixelSize: 13 }
        Pulsante { anchors.horizontalCenter: parent.horizontalCenter; visible: !finestra.corrente; text: I18n.t("Apri un file…"); principale: true; onClicked: dialogoApri.open() }
    }
    DropArea { anchors.fill: parent; onDropped: function (d) { if (d.hasUrls) finestra.apri(d.urls[0].toString()) } }

    // Comandi
    Rectangle {
        id: comandi
        anchors.bottom: parent.bottom
        width: parent.width
        height: 78
        color: "#E61C1D22"
        visible: finestra.visibility !== Window.FullScreen || areaComandi.containsMouse
        MouseArea { id: areaComandi; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text { text: finestra.tempo(lettore.position); color: "#D4D4D8"; font.family: Tema.font; font.pixelSize: 12; font.features: ({ "tnum": 1 }) }
                Cursore {
                    Layout.fillWidth: true
                    from: 0; to: Math.max(1, lettore.duration)
                    value: lettore.position
                    enabled: lettore.seekable
                    onMoved: lettore.position = value
                }
                Text { text: finestra.tempo(lettore.duration); color: "#D4D4D8"; font.family: Tema.font; font.pixelSize: 12; font.features: ({ "tnum": 1 }) }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Pulsante { icona: "media-skip-backward-symbolic"; enabled: finestra.scaletta.length > 1; onClicked: finestra.vai(-1) }
                Pulsante { icona: lettore.playbackState === MediaPlayer.PlayingState ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"; principale: true; enabled: !!finestra.corrente; onClicked: lettore.playbackState === MediaPlayer.PlayingState ? lettore.pause() : lettore.play() }
                Pulsante { icona: "media-skip-forward-symbolic"; enabled: finestra.scaletta.length > 1; onClicked: finestra.vai(1) }
                Text { Layout.fillWidth: true; Layout.leftMargin: 8; elide: Text.ElideRight; text: finestra.corrente ? finestra.corrente.split("/").pop() + (finestra.scaletta.length > 1 ? "  (" + (finestra.indice + 1) + "/" + finestra.scaletta.length + ")" : "") : ""; color: "#D4D4D8"; font.family: Tema.font; font.pixelSize: 12 }
                Pulsante { icona: audio.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"; onClicked: audio.muted = !audio.muted }
                Cursore { Layout.preferredWidth: 110; from: 0; to: 1; value: audio.volume; onMoved: audio.volume = value }
                Pulsante { text: I18n.t("Apri…"); onClicked: dialogoApri.open() }
                Pulsante { icona: "view-fullscreen-symbolic"; onClicked: finestra.visibility = finestra.visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen }
            }
        }
    }
    FileDialog { id: dialogoApri; nameFilters: [I18n.t("Video e audio") + " (*.mp4 *.mkv *.webm *.avi *.mov *.m4v *.mpg *.mp3 *.flac *.ogg *.opus *.wav *.m4a *.aac)"]; onAccepted: finestra.apri(selectedFile.toString()) }
}
