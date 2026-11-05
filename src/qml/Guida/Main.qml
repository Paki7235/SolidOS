import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Guida") + " — " + Tema.nomeSistema
    property var argomenti: ponte.chiama0("argomenti")
    property string corrente: argomenti.length ? argomenti[0].id : ""
    Component.onCompleted: {
        var richiesto = Qt.application.arguments.length > 1 ? Qt.application.arguments[Qt.application.arguments.length - 1] : ""
        for (var i = 0; i < argomenti.length; i++) if (argomenti[i].id === richiesto) corrente = richiesto
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.preferredWidth: 280
            Layout.fillHeight: true
            color: Tema.superficie
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                CampoRicerca {
                    id: ricerca
                    Layout.fillWidth: true
                    placeholderText: I18n.t("Cerca nella guida…")
                    onTextChanged: finestra.argomenti = ponte.chiama("cerca", [text])
                }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: finestra.argomenti
                    delegate: VoceElenco {
                        width: ListView.view.width
                        titolo: modelData.titolo
                        sottotitolo: modelData.estratto || ""
                        selezionata: modelData.id === finestra.corrente
                        onClicked: finestra.corrente = modelData.id
                    }
                }
            }
        }
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            TextArea {
                readOnly: true
                textFormat: TextEdit.MarkdownText
                text: finestra.corrente ? ponte.chiama("pagina", [finestra.corrente]) : ""
                wrapMode: TextEdit.Wrap
                color: Tema.testo
                leftPadding: 32; rightPadding: 32; topPadding: 24
                background: Rectangle { color: Tema.sfondo }
                onLinkActivated: function (l) { if (l.indexOf("guida:") === 0) finestra.corrente = l.substring(6); else Qt.openUrlExternally(l) }
            }
        }
    }
}
