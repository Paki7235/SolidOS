// Documenti: lettore di PDF. Ctrl+F cerca, Ctrl++ / Ctrl+- zoom, Ctrl+P stampa.
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Pdf
import SolidUI

Finestra {
    id: finestra
    width: 980
    height: 720
    property string percorso: ""
    title: (percorso ? percorso.split("/").pop() + " — " : "") + I18n.t("Documenti")

    function apri(p) { percorso = p.replace("file://", ""); documento.source = "file://" + percorso }
    Component.onCompleted: { var f = ponte.chiama0("fileIniziale"); if (f) apri(f) }

    PdfDocument {
        id: documento
        onStatusChanged: if (status === PdfDocument.Error) finestra.avviso(I18n.t("Impossibile aprire il documento"))
    }

    Shortcut { sequence: StandardKey.Open; onActivated: dialogoApri.open() }
    Shortcut { sequence: StandardKey.Find; onActivated: cerca.forceActiveFocus() }
    Shortcut { sequence: StandardKey.ZoomIn; onActivated: vista.renderScale *= 1.2 }
    Shortcut { sequence: StandardKey.ZoomOut; onActivated: vista.renderScale /= 1.2 }
    Shortcut { sequence: StandardKey.Print; onActivated: if (finestra.percorso) ponte.chiama("stampa", [finestra.percorso]) }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Barra {
            Layout.fillWidth: true
            titolo: documento.pageCount ? I18n.t("Pagina") + " " + (vista.currentPage + 1) + " " + I18n.t("di") + " " + documento.pageCount : I18n.t("Documenti")
            Pulsante { text: I18n.t("Apri…"); onClicked: dialogoApri.open() }
            Pulsante { icona: "zoom-out-symbolic"; enabled: documento.pageCount > 0; onClicked: vista.renderScale /= 1.2 }
            Pulsante { text: Math.round(vista.renderScale * 100) + "%"; enabled: documento.pageCount > 0; onClicked: vista.scaleToWidth(vista.width, vista.height) }
            Pulsante { icona: "zoom-in-symbolic"; enabled: documento.pageCount > 0; onClicked: vista.renderScale *= 1.2 }
            CampoRicerca {
                id: cerca
                width: 200
                placeholderText: I18n.t("Cerca nel documento")
                onTextChanged: vista.searchString = text
                onAccepted: vista.searchForward()
            }
            Pulsante { text: I18n.t("Stampa"); enabled: !!finestra.percorso; onClicked: ponte.chiama("stampa", [finestra.percorso]) ? finestra.avviso(I18n.t("Inviato alla stampante")) : finestra.avviso(I18n.t("Nessuna stampante disponibile")) }
        }
        PdfMultiPageView {
            id: vista
            Layout.fillWidth: true
            Layout.fillHeight: true
            document: documento
            visible: documento.pageCount > 0
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: documento.pageCount === 0
            DropArea { anchors.fill: parent; onDropped: function (d) { if (d.hasUrls) finestra.apri(d.urls[0].toString()) } }
            Column {
                anchors.centerIn: parent
                spacing: 12
                Image { anchors.horizontalCenter: parent.horizontalCenter; width: 72; height: 72; sourceSize.width: 144; sourceSize.height: 144; source: "image://icona/application-pdf" }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Trascina qui un PDF"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 15 }
                Pulsante { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Apri un documento…"); principale: true; onClicked: dialogoApri.open() }
            }
        }
    }
    FileDialog { id: dialogoApri; nameFilters: ["PDF (*.pdf)"]; onAccepted: finestra.apri(selectedFile.toString()) }
}
