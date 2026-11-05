import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Migrazione da Windows")
    width: 820
    height: 620
    property var partizioni: ponte.chiama0("partizioni")
    property var aperta: null
    property var elementi: []
    property var scelti: ({})
    property var avanzamento: null
    property var esito: null
    property bool occupato: false

    Connections {
        target: ponte
        function onEvento(nome, d) { if (nome === "avanzamento") finestra.avanzamento = d }
        function onCompletato(id, r) {
            finestra.occupato = false
            if (id === "elementi") { finestra.elementi = r; var s = {}; r.forEach(function (e) { s[e.id] = true }); finestra.scelti = s }
            else if (id === "importa") { finestra.esito = r; finestra.avanzamento = null }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 14
        Titolo { text: I18n.t("Porta con te i tuoi file da Windows") }
        Testo { secondario: true; Layout.fillWidth: true; text: I18n.t("Funziona con Windows installato su questo computer o su un disco collegato. Nulla viene modificato su Windows.") }

        RowLayout {
            Testo { text: I18n.t("Disco di Windows:") }
            Scelta {
                id: disco
                Layout.fillWidth: true
                model: finestra.partizioni.map(function (p) { return { testo: (p.etichetta || p.percorso) + " · " + p.dimensione + " GB", valore: p.percorso } })
            }
            Pulsante {
                text: I18n.t("Apri")
                enabled: finestra.partizioni.length > 0
                onClicked: { var r = ponte.chiama("apri", [disco.currentValue]); if (r.ok) finestra.aperta = r; else finestra.avviso(r.messaggio) }
            }
        }
        Testo { visible: finestra.partizioni.length === 0; color: Tema.avviso; text: I18n.t("Nessun disco di Windows trovato. Se è cifrato con BitLocker, sbloccalo prima da «Dischi».") }

        RowLayout {
            visible: finestra.aperta !== null
            Testo { text: I18n.t("Utente:") }
            Scelta {
                id: utente
                Layout.fillWidth: true
                model: finestra.aperta ? finestra.aperta.utenti.map(function (u) { return { testo: u.nome, valore: u.percorso } }) : []
            }
            Pulsante { text: I18n.t("Analizza"); onClicked: { finestra.occupato = true; ponte.avvia("elementi", [utente.currentValue], "elementi") } }
        }
        BarraProgresso { Layout.fillWidth: true; visible: finestra.occupato || finestra.avanzamento !== null; indeterminate: finestra.avanzamento === null; value: finestra.avanzamento ? finestra.avanzamento.fatto / finestra.avanzamento.totale : 0 }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: finestra.elementi
            delegate: RigaImpostazione {
                width: ListView.view.width
                icona: modelData.tipo === "cartella" ? "folder" : (modelData.tipo === "wifi" ? "network-wireless" : (modelData.tipo === "sfondo" ? "preferences-desktop-wallpaper" : "bookmarks"))
                titolo: modelData.nome
                descrizione: modelData.dimensione ? modelData.dimensione + " MB" : ""
                Interruttore { checked: true; onToggled: { var s = finestra.scelti; s[modelData.id] = checked; finestra.scelti = s } }
            }
        }
        Testo {
            Layout.fillWidth: true
            secondario: true
            text: I18n.t("Reti Wi-Fi: su Windows esegui «esporta-wifi.bat» (lo trovi nella cartella «windows» della chiavetta di installazione, copialo sul Desktop di Windows) e poi riapri questa finestra.")
        }
        Testo { visible: finestra.esito !== null; Layout.fillWidth: true; color: Tema.successo; text: finestra.esito ? "✅ " + finestra.esito.riepilogo.join("\n") : "" }
        Pulsante {
            Layout.alignment: Qt.AlignRight
            principale: true
            text: I18n.t("Importa")
            enabled: finestra.elementi.length > 0 && !finestra.occupato
            onClicked: {
                finestra.occupato = true
                finestra.esito = null
                ponte.avvia("importa", [finestra.elementi.filter(function (e) { return finestra.scelti[e.id] })], "importa")
            }
        }
    }
}
