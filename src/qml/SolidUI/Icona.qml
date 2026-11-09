// Icona del tema di sistema: Icona { nome: "network-wireless"; lato: 24 }
import QtQuick

Image {
    property string nome: ""
    property int lato: 24
    width: lato
    height: lato
    // Nei layout conta la dimensione implicita: senza queste righe l'icona prende
    // la grandezza dell'immagine caricata (il doppio) e sborda.
    implicitWidth: lato
    implicitHeight: lato
    sourceSize.width: lato * 2
    sourceSize.height: lato * 2
    source: nome ? "image://icona/" + nome : ""
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    smooth: true
}
