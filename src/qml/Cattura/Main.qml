import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Cattura")
    width: 460
    height: 420
    property bool registrando: false
    property string ultimo: ""
    property string area: ""

    function cattura(tipo) {
        finestra.visible = false
        ritardo.tipo = tipo
        ritardo.interval = Math.max(300, attesa.value * 1000)
        ritardo.start()
    }
    Timer {
        id: ritardo
        property string tipo: ""
        onTriggered: {
            var a = ""
            if (tipo === "area" || tipo === "video-area") { a = ponte.chiama0("area"); if (!a) { finestra.visible = true; return } }
            if (tipo === "video" || tipo === "video-area") {
                ponte.chiama("avviaRegistrazione", [a, audio.checked]); finestra.registrando = true
            } else {
                var r = ponte.chiama("schermata", [a, appunti.checked]); if (r.ok) finestra.ultimo = r.file
            }
            finestra.visible = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16
        Titolo { text: I18n.t("Cattura dello schermo") }
        GridLayout {
            columns: 2
            columnSpacing: 12
            rowSpacing: 12
            Layout.fillWidth: true
            Pulsante { Layout.fillWidth: true; icona: "camera-photo"; text: I18n.t("Schermo intero"); principale: true; onClicked: finestra.cattura("schermo") }
            Pulsante { Layout.fillWidth: true; icona: "edit-select"; text: I18n.t("Area"); onClicked: finestra.cattura("area") }
            Pulsante { Layout.fillWidth: true; icona: "media-record"; text: I18n.t("Registra schermo"); visible: !finestra.registrando; onClicked: finestra.cattura("video") }
            Pulsante { Layout.fillWidth: true; icona: "media-record"; text: I18n.t("Registra area"); visible: !finestra.registrando; onClicked: finestra.cattura("video-area") }
            Pulsante {
                Layout.fillWidth: true; Layout.columnSpan: 2
                visible: finestra.registrando; pericoloso: true; icona: "media-playback-stop"
                text: I18n.t("Ferma registrazione")
                onClicked: { var r = ponte.chiama0("fermaRegistrazione"); finestra.registrando = false; if (r.ok) finestra.ultimo = r.file }
            }
        }
        RigaImpostazione {
            titolo: I18n.t("Attesa prima della cattura")
            descrizione: attesa.value + " " + I18n.t("secondi")
            Cursore { id: attesa; from: 0; to: 10; stepSize: 1; value: 0; width: 160 }
        }
        RigaImpostazione { titolo: I18n.t("Copia anche negli appunti"); Interruttore { id: appunti; checked: true } }
        RigaImpostazione { titolo: I18n.t("Registra anche l'audio"); Interruttore { id: audio } }
        Item { Layout.fillHeight: true }
        Pulsante { visible: finestra.ultimo !== ""; text: I18n.t("Apri l'ultima cattura"); onClicked: ponte.chiama("apri", [finestra.ultimo]) }
    }
}
