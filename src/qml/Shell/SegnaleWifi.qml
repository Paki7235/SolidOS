// Il simbolo vero del Wi-Fi (il ventaglio: un punto e tre archi), come su Mac, Windows e telefono.
// Le parti accese dicono quanto è forte il segnale, cioè quanto si è vicini al modem:
// tutto acceso = vicino, solo il punto = molto lontano. Senza rete: ventaglio spento e barretta.
import QtQuick

Item {
    id: segnale
    property int percento: 0          // 0-100 (qualità del collegamento)
    property bool connesso: false
    property color colore: Tema.testoVetro
    readonly property int tacche: !connesso ? 0 : (percento >= 75 ? 4 : percento >= 50 ? 3 : percento >= 25 ? 2 : 1)
    width: 19
    height: 15

    onTaccheChanged: ventaglio.requestPaint()
    onColoreChanged: ventaglio.requestPaint()

    Canvas {
        id: ventaglio
        anchors.fill: parent
        antialiasing: true
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var g = getContext("2d")
            g.reset()
            var c = segnale.colore
            var acceso = Qt.rgba(c.r, c.g, c.b, 1)
            var spento = Qt.rgba(c.r, c.g, c.b, 0.28)
            var cx = width / 2
            var cy = height - 1.2                 // vertice del ventaglio, in basso al centro
            var passo = Math.min(cy - 0.9, (width / 2 - 0.6) / 0.707) / 3.99   // distanza tra gli archi: tutto dentro il riquadro
            var spessore = passo * 0.62
            var inizio = Math.PI * 1.25, fine = Math.PI * 1.75   // 90° di apertura, verso l'alto
            // Punto (prima tacca)
            g.fillStyle = segnale.tacche >= 1 ? acceso : spento
            g.beginPath()
            g.moveTo(cx, cy)
            g.arc(cx, cy, passo * 1.05, inizio, fine, false)
            g.closePath()
            g.fill()
            // Tre archi
            g.lineCap = "round"
            g.lineWidth = spessore
            for (var i = 1; i <= 3; i++) {
                g.strokeStyle = segnale.tacche >= i + 1 ? acceso : spento
                g.beginPath()
                g.arc(cx, cy, passo * (1.05 + i * 0.98) - spessore / 2 + 0.6, inizio + 0.06, fine - 0.06, false)
                g.stroke()
            }
        }
    }
    // Nessuna connessione: barretta obliqua sopra il ventaglio spento
    Rectangle {
        visible: !segnale.connesso
        anchors.centerIn: parent
        width: 2; height: parent.height + 2; radius: 1
        rotation: -40
        color: segnale.colore
    }
}
