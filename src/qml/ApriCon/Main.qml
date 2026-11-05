import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Apri con…")
    width: 760
    height: 560
    property string file: ponte.chiama0("file")
    property var info: file ? ponte.chiama("analizza", [file]) : ({ compatibili: [], tutte: [], suggerite: [] })
    property bool mostraTutte: false

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12
        Titolo { text: finestra.info.nome || ""; livello: 2 }
        Testo { secondario: true; text: (finestra.info.descrizione || finestra.info.mime || "") + " · " + (finestra.info.dimensione || 0) + " KB"; Layout.fillWidth: true }
        Scheda {
            Layout.fillWidth: true
            visible: finestra.info.sospetto === true
            color: "#33E5484D"
            Testo { width: parent.width; text: "⚠️ " + I18n.t("Attenzione: questo file sembra un documento ma in realtà è un programma. Non aprirlo se non sai da dove arriva.") }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16
            ColumnLayout {
                Layout.preferredWidth: 320
                Layout.fillHeight: true
                Testo { text: finestra.mostraTutte ? I18n.t("Tutte le app") : I18n.t("App consigliate"); font.weight: Font.DemiBold }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: finestra.mostraTutte ? finestra.info.tutte : finestra.info.compatibili
                    delegate: VoceElenco {
                        width: ListView.view.width
                        icona: modelData.icona
                        titolo: modelData.nome
                        onClicked: { ponte.chiama("apri", [finestra.file, modelData.desktop, ricorda.checked]); Qt.quit() }
                    }
                    Testo { anchors.centerIn: parent; visible: parent.count === 0; secondario: true; text: I18n.t("Nessuna app installata apre questo file") }
                }
                Pulsante { text: finestra.mostraTutte ? I18n.t("Solo consigliate") : I18n.t("Mostra tutte le app"); onClicked: finestra.mostraTutte = !finestra.mostraTutte }
                Interruttore { id: ricorda; text: I18n.t("Usa sempre per questo tipo di file") }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Testo { text: I18n.t("Anteprima"); font.weight: Font.DemiBold }
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    TextArea {
                        readOnly: true
                        text: finestra.info.anteprima || ""
                        font.family: "monospace"
                        color: Tema.testo
                        wrapMode: TextEdit.WrapAnywhere
                        background: Rectangle { color: Tema.superficie; radius: 8 }
                    }
                }
                Testo { text: I18n.t("Puoi installare"); font.weight: Font.DemiBold; visible: (finestra.info.suggerite || []).length > 0 }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: finestra.info.suggerite
                        Pulsante { text: modelData.nome; icona: "system-software-install"; onClicked: ponte.chiama("installaApp", [modelData.id]) }
                    }
                }
                Pulsante { visible: finestra.info.installabile === true; principale: true; text: I18n.t("Installa questo programma"); onClicked: { ponte.chiama("installaFile", [finestra.file]); Qt.quit() } }
            }
        }
    }
}
