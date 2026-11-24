// Ripiego senza motore web: il messaggio come testo ricco di Qt (niente immagini remote).
import QtQuick
import QtQuick.Controls

Flickable {
    id: vista
    property string pagina: ""
    signal collegamento(string url)
    contentHeight: testo.implicitHeight + 24
    clip: true
    ScrollBar.vertical: ScrollBar {}
    TextEdit {
        id: testo
        width: vista.width
        readOnly: true
        selectByMouse: true
        textFormat: TextEdit.RichText
        wrapMode: TextEdit.Wrap
        color: Tema.testo
        font.family: Tema.font
        font.pixelSize: 14
        text: vista.pagina.replace(/<style[\s\S]*?<\/style>/gi, "").replace(/<meta[^>]*>/gi, "")
        onLinkActivated: function (url) { vista.collegamento(url) }
        HoverHandler { cursorShape: testo.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor }
    }
}
