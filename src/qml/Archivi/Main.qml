// Archivi: apri un archivio per vederne il contenuto ed estrarlo; trascina dei file per creare uno zip.
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    width: 820
    height: 580
    property string percorso: ""
    property var dati: ({ voci: [] })
    property bool lavoro: false
    title: (dati.nome ? dati.nome + " — " : "") + I18n.t("Archivi")

    function apri(p) {
        percorso = p.replace("file://", "")
        var r = ponte.chiama("contenuto", [percorso])
        if (!r.ok) { finestra.avviso(r.errore); return }
        dati = r
    }
    function estrai(dest) { lavoro = true; ponte.avvia("estrai", [percorso, dest || ""], "estrai") }
    function dimensione(b) {
        if (b < 1024) return b + " B"
        if (b < 1048576) return (b / 1024).toLocaleString(Qt.locale(), "f", 1) + " KB"
        if (b < 1073741824) return (b / 1048576).toLocaleString(Qt.locale(), "f", 1) + " MB"
        return (b / 1073741824).toLocaleString(Qt.locale(), "f", 2) + " GB"
    }

    Component.onCompleted: { var f = ponte.chiama0("fileIniziale"); if (f) apri(f) }
    Connections {
        target: ponte
        function onCompletato(id, r) {
            finestra.lavoro = false
            if (id === "estrai") {
                if (r.ok) { finestra.avviso(I18n.t("Estratto in") + " " + r.cartella.split("/").pop()); ponte.chiama("mostra", [r.cartella]) }
                else finestra.avviso(r.errore)
            } else if (id === "comprimi") {
                if (r.ok) { finestra.avviso(I18n.t("Creato") + " " + r.percorso.split("/").pop()); finestra.apri(r.percorso) }
                else finestra.avviso(r.errore)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Barra {
            Layout.fillWidth: true
            titolo: finestra.dati.nome ? finestra.dati.totale + " " + I18n.t("elementi") + " · " + finestra.dimensione(finestra.dati.dimensione || 0) : I18n.t("Archivi")
            Pulsante { text: I18n.t("Apri…"); onClicked: dialogoApri.open() }
            Pulsante { text: I18n.t("Estrai qui"); principale: true; enabled: !!finestra.percorso && !finestra.lavoro; onClicked: finestra.estrai("") }
            Pulsante { text: I18n.t("Estrai in…"); enabled: !!finestra.percorso && !finestra.lavoro; onClicked: dialogoCartella.open() }
        }
        BarraProgresso { Layout.fillWidth: true; indeterminate: true; visible: finestra.lavoro }
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: finestra.dati.voci.length > 0
            clip: true
            model: finestra.dati.voci
            ScrollBar.vertical: ScrollBar {}
            delegate: Rectangle {
                required property var modelData
                required property int index
                width: ListView.view.width
                height: 32
                color: index % 2 ? (Tema.chiaro ? "#05000000" : "#08FFFFFF") : "transparent"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 10
                    Image { width: 18; height: 18; sourceSize.width: 36; sourceSize.height: 36; source: "image://icona/" + (modelData.cartella ? "folder" : "text-x-generic") }
                    Text { Layout.fillWidth: true; text: modelData.nome; elide: Text.ElideMiddle; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                    Text { text: modelData.cartella ? "" : finestra.dimensione(modelData.dimensione); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
                }
            }
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: finestra.dati.voci.length === 0
            Column {
                anchors.centerIn: parent
                spacing: 12
                Image { anchors.horizontalCenter: parent.horizontalCenter; width: 72; height: 72; sourceSize.width: 144; sourceSize.height: 144; source: "image://icona/package-x-generic" }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Apri un archivio, oppure trascina qui dei file per creare uno zip"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 14 }
                Pulsante { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Apri un archivio…"); principale: true; onClicked: dialogoApri.open() }
            }
        }
    }
    DropArea {
        anchors.fill: parent
        onDropped: function (d) {
            if (!d.hasUrls) return
            var urls = Array.prototype.map.call(d.urls, function (u) { return u.toString() })
            var p = urls[0].toLowerCase()
            if (urls.length === 1 && /\.(zip|tar|gz|tgz|bz2|xz|7z|rar|iso)$/.test(p)) finestra.apri(urls[0])
            else { finestra.lavoro = true; ponte.avvia("comprimi", [urls], "comprimi") }
        }
    }
    FileDialog { id: dialogoApri; nameFilters: [I18n.t("Archivi") + " (*.zip *.tar *.gz *.tgz *.bz2 *.xz *.7z *.rar *.iso)"]; onAccepted: finestra.apri(selectedFile.toString()) }
    FolderDialog { id: dialogoCartella; onAccepted: finestra.estrai(selectedFolder.toString()) }
}
