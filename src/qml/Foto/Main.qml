// Foto: frecce ← → per scorrere, rotella per lo zoom, R per ruotare, F schermo intero.
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window
import SolidUI

Finestra {
    id: finestra
    width: 1000
    height: 700
    color: "#0E0F12"
    property var elenco: []
    property int indice: -1
    readonly property string corrente: indice >= 0 && indice < elenco.length ? elenco[indice] : ""
    property real zoom: 1
    property int rotazione: 0
    title: (corrente ? corrente.split("/").pop() + " — " : "") + I18n.t("Foto")

    function apri(p) {
        p = p.replace("file://", "")
        elenco = ponte.chiama("elenco", [p])
        indice = Math.max(0, elenco.indexOf(p))
        zoom = 1; rotazione = 0
    }
    function vai(d) { if (elenco.length) { indice = (indice + d + elenco.length) % elenco.length; zoom = 1; rotazione = 0 } }

    Component.onCompleted: { var f = ponte.chiama0("fileIniziale"); if (f) apri(f) }

    Shortcut { sequence: "Right"; onActivated: finestra.vai(1) }
    Shortcut { sequence: "Left"; onActivated: finestra.vai(-1) }
    Shortcut { sequence: "R"; onActivated: finestra.rotazione = (finestra.rotazione + 90) % 360 }
    Shortcut { sequence: "F"; onActivated: finestra.visibility = finestra.visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen }
    Shortcut { sequence: "Escape"; onActivated: if (finestra.visibility === Window.FullScreen) finestra.visibility = Window.Windowed }
    Shortcut { sequence: "Delete"; onActivated: elimina.open() }
    Shortcut { sequence: StandardKey.Open; onActivated: dialogoApri.open() }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Barra {
            Layout.fillWidth: true
            visible: finestra.visibility !== Window.FullScreen
            titolo: finestra.elenco.length ? (finestra.indice + 1) + " " + I18n.t("di") + " " + finestra.elenco.length : I18n.t("Foto")
            Pulsante { text: I18n.t("Apri…"); onClicked: dialogoApri.open() }
            Pulsante { icona: "object-rotate-left-symbolic"; enabled: !!finestra.corrente; onClicked: finestra.rotazione = (finestra.rotazione + 270) % 360 }
            Pulsante { icona: "object-rotate-right-symbolic"; enabled: !!finestra.corrente; onClicked: finestra.rotazione = (finestra.rotazione + 90) % 360 }
            Pulsante { text: presentazione.running ? I18n.t("Ferma") : I18n.t("Presentazione"); enabled: finestra.elenco.length > 1; onClicked: presentazione.running = !presentazione.running }
            Pulsante { text: I18n.t("Usa come sfondo"); enabled: !!finestra.corrente; onClicked: { ponte.chiama("usaComeSfondo", [finestra.corrente]); finestra.avviso(I18n.t("Sfondo cambiato")) } }
            Pulsante { text: I18n.t("Elimina"); pericoloso: true; enabled: !!finestra.corrente; onClicked: elimina.open() }
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            Image {
                id: immagine
                anchors.centerIn: parent
                width: parent.width; height: parent.height
                source: finestra.corrente ? "file://" + finestra.corrente : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                autoTransform: true
                smooth: true
                mipmap: true
                scale: finestra.zoom
                rotation: finestra.rotazione
                Behavior on rotation { enabled: Tema.animazioni; NumberAnimation { duration: 160 } }
            }
            BusyIndicator { anchors.centerIn: parent; running: immagine.status === Image.Loading }
            Column {
                anchors.centerIn: parent
                visible: !finestra.corrente
                spacing: 12
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Nessuna immagine aperta"); color: "#A1A1AA"; font.family: Tema.font; font.pixelSize: 15 }
                Pulsante { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Apri un'immagine…"); principale: true; onClicked: dialogoApri.open() }
            }
            MouseArea {
                anchors.fill: parent
                onWheel: function (w) { finestra.zoom = Math.max(0.2, Math.min(8, finestra.zoom * (w.angleDelta.y > 0 ? 1.15 : 1 / 1.15))) }
                onDoubleClicked: finestra.zoom = finestra.zoom === 1 ? 2 : 1
            }
            // Frecce ai lati
            Repeater {
                model: [-1, 1]
                Rectangle {
                    visible: finestra.elenco.length > 1
                    width: 44; height: 44; radius: 22
                    anchors.verticalCenter: parent.verticalCenter
                    x: modelData < 0 ? 16 : parent.width - width - 16
                    color: ma.containsMouse ? "#99000000" : "#55000000"
                    Text { anchors.centerIn: parent; text: modelData < 0 ? "‹" : "›"; color: "#FFFFFF"; font.pixelSize: 28 }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: finestra.vai(modelData) }
                }
            }
            DropArea { anchors.fill: parent; onDropped: function (d) { if (d.hasUrls) finestra.apri(d.urls[0].toString()) } }
        }
    }
    Timer { id: presentazione; interval: 4000; repeat: true; onTriggered: finestra.vai(1) }
    FileDialog { id: dialogoApri; nameFilters: [I18n.t("Immagini") + " (*.png *.jpg *.jpeg *.webp *.gif *.bmp *.svg *.tif *.tiff *.avif *.heic)"]; onAccepted: finestra.apri(selectedFile.toString()) }
    Dialog {
        id: elimina
        anchors.centerIn: parent
        modal: true
        title: I18n.t("Spostare l'immagine nel cestino?")
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: {
            var p = finestra.corrente
            if (ponte.chiama("cestino", [p])) { finestra.elenco = finestra.elenco.filter(function (x) { return x !== p }); finestra.indice = Math.min(finestra.indice, finestra.elenco.length - 1) }
        }
    }
}
