// Finestra principale delle app: sfondo, colori e font del tema.
import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: finestra
    width: 960
    height: 640
    minimumWidth: 480
    minimumHeight: 360
    visible: true
    color: Tema.sfondo
    font.family: Tema.font
    font.pointSize: Tema.fontDimensione
    palette.window: Tema.sfondo
    palette.windowText: Tema.testo
    palette.base: Tema.superficie
    palette.text: Tema.testo
    palette.button: Tema.superficieAlta
    palette.buttonText: Tema.testo
    palette.highlight: Tema.accento
    palette.highlightedText: "#FFFFFF"
    palette.placeholderText: Tema.testoSecondario

    // Messaggio temporaneo in basso: finestra.avviso("Fatto")
    function avviso(testo) { toast.mostra(testo) }

    Messaggio { id: toast; z: 1000 }
}
