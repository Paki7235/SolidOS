// Aggiornamento software, come su Mac e iPhone: una scheda sola che dice se il sistema è
// aggiornato o cosa c'è di nuovo, quanto pesa, e un pulsante «Aggiorna ora» con la barra
// di avanzamento (scaricamento, verifica, punto di ripristino, installazione); alla fine
// «Riavvia ora» o «Più tardi».
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Aggiornamento software")
    width: 620
    height: 540
    minimumWidth: 480
    minimumHeight: 460

    // controllo | aggiornato | disponibile | installa | fatto | errore | offline
    property string stato: "controllo"
    property var info: ({})
    property var passo: ({})
    property string messaggio: ""
    readonly property string titoloVersione: (info.nome || Tema.nomeSistema) + " " + (info.versioneSistema || "")

    function cerca() {
        stato = "controllo"
        ponte.avvia("controlla", [], "controlla")
    }
    function aggiorna() {
        stato = "installa"
        passo = ({ fase: "controllo", percento: 0 })
        ponte.avvia("installa", [], "installa")
    }
    readonly property var nomiFasi: ({
        controllo: I18n.t("Preparazione…"),
        scarica: I18n.t("Scaricamento…"),
        verifica: I18n.t("Verifica dell'aggiornamento…"),
        ripristino: I18n.t("Creazione di un punto di ripristino…"),
        installa: I18n.t("Installazione…")
    })
    // la barra avanza per tutte le fasi insieme, come su Mac
    readonly property real totale: {
        var f = passo.fase || "controllo", p = (passo.percento || 0) / 100
        if (f === "scarica") return 0.05 + 0.55 * p
        if (f === "verifica") return 0.62
        if (f === "ripristino") return 0.66
        if (f === "installa") return 0.70 + 0.28 * p
        return 0.02
    }

    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id === "controlla") {
                finestra.info = r
                if (r.disponibile === null || r.disponibile === undefined) { finestra.messaggio = r.errore || ""; finestra.stato = "offline" }
                else finestra.stato = r.nuova ? "disponibile" : "aggiornato"
            } else if (id === "installa") {
                if (r.ok) finestra.stato = "fatto"
                else { finestra.messaggio = r.messaggio; finestra.stato = "errore" }
            } else if (id === "altri") {
                finestra.messaggio = ""
            }
        }
        function onErrore(id, m) { finestra.messaggio = m; finestra.stato = id === "controlla" ? "offline" : "errore" }
    }
    Timer {
        interval: 300; repeat: true; running: finestra.stato === "installa"
        onTriggered: {
            var a = ponte.chiama0("avanzamento")
            // «fatto» ed «errore» arrivano dall'esito vero dell'installazione, non dal file
            if (a && a.fase && a.fase !== "fatto" && a.fase !== "errore") finestra.passo = a
        }
    }
    Component.onCompleted: cerca()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 18

        // ── Intestazione ──
        RowLayout {
            spacing: 14
            // Simbolo dell'app: quadrato col colore del sistema e una freccia circolare
            Rectangle {
                width: 48; height: 48; radius: 12
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.lighter(Tema.accento, 1.25) }
                    GradientStop { position: 1; color: Tema.accento }
                }
                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        var g = getContext("2d"); g.reset()
                        g.strokeStyle = "white"; g.fillStyle = "white"; g.lineWidth = 3.2; g.lineCap = "round"
                        g.beginPath(); g.arc(24, 24, 12, Math.PI * 0.15, Math.PI * 1.75); g.stroke()
                        g.beginPath(); g.moveTo(33.5, 9.5); g.lineTo(35.5, 18.5); g.lineTo(26.5, 17); g.closePath(); g.fill()
                    }
                }
            }
            ColumnLayout {
                spacing: 2
                Text { text: I18n.t("Aggiornamento software"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 22; font.weight: Font.Bold }
                Text {
                    text: finestra.info.installata ? I18n.t("Sul computer: {s} build {n}").replace("{s}", finestra.titoloVersione).replace("{n}", finestra.info.installata)
                                                   : I18n.t("Le nuove versioni arrivano da sole, con un punto di ripristino prima")
                    color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13
                }
            }
        }

        // ── La scheda principale ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: contenuto.implicitHeight + 44
            radius: 14
            color: Tema.superficie
            border.color: Tema.bordo
            Behavior on Layout.preferredHeight { enabled: Tema.animazioni; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            ColumnLayout {
                id: contenuto
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 22
                spacing: 12

                // Ricerca in corso
                RowLayout {
                    visible: finestra.stato === "controllo"
                    spacing: 12
                    BusyIndicator { running: parent.visible; implicitWidth: 28; implicitHeight: 28 }
                    Text { text: I18n.t("Ricerca di aggiornamenti…"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 15 }
                }

                // Già aggiornato
                ColumnLayout {
                    visible: finestra.stato === "aggiornato"
                    spacing: 6
                    Layout.fillWidth: true
                    RowLayout {
                        spacing: 10
                        Rectangle {
                            width: 26; height: 26; radius: 13; color: "#22C55E"
                            Text { anchors.centerIn: parent; text: "✓"; color: "white"; font.pixelSize: 15; font.weight: Font.Bold }
                        }
                        Text { text: I18n.t("{s} è aggiornato").replace("{s}", finestra.info.nome || Tema.nomeSistema); color: Tema.testo; font.family: Tema.font; font.pixelSize: 17; font.weight: Font.DemiBold }
                    }
                    Text {
                        text: finestra.titoloVersione + " — build " + (finestra.info.installata || "")
                        color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13
                    }
                    Text {
                        visible: !!finestra.info.novitaInstallata
                        Layout.fillWidth: true; Layout.topMargin: 6
                        text: I18n.t("Novità di questa versione:") + " " + (finestra.info.novitaInstallata || "")
                        wrapMode: Text.WordWrap; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13
                    }
                }

                // Nuova versione disponibile
                ColumnLayout {
                    visible: finestra.stato === "disponibile"
                    spacing: 8
                    Layout.fillWidth: true
                    Text { text: I18n.t("Aggiornamento disponibile"); color: Tema.accento; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase }
                    Text {
                        text: finestra.titoloVersione + " — build " + (finestra.info.disponibile || "")
                        color: Tema.testo; font.family: Tema.font; font.pixelSize: 19; font.weight: Font.Bold
                    }
                    Text {
                        visible: !!finestra.info.peso
                        text: finestra.info.peso || ""
                        color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13
                    }
                    Text {
                        Layout.fillWidth: true
                        text: finestra.info.novita || I18n.t("Miglioramenti e correzioni.")
                        wrapMode: Text.WordWrap; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14
                        lineHeight: 1.25
                    }
                    Text {
                        Layout.fillWidth: true
                        text: I18n.t("Prima di installare viene creato un punto di ripristino: se qualcosa non va, torni indietro dalla Linea del Tempo.")
                        wrapMode: Text.WordWrap; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                    }
                    Pulsante {
                        Layout.topMargin: 6
                        text: I18n.t("Aggiorna ora")
                        principale: true
                        onClicked: finestra.aggiorna()
                    }
                }

                // Installazione in corso
                ColumnLayout {
                    visible: finestra.stato === "installa"
                    spacing: 10
                    Layout.fillWidth: true
                    Text {
                        text: I18n.t("Installazione di {s} build {n}").replace("{s}", finestra.titoloVersione).replace("{n}", finestra.info.disponibile || "")
                        color: Tema.testo; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.DemiBold
                    }
                    BarraProgresso {
                        Layout.fillWidth: true
                        from: 0; to: 1
                        value: finestra.totale
                        Behavior on value { enabled: Tema.animazioni; NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: finestra.nomiFasi[finestra.passo.fase || "controllo"] || ""; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13; Layout.fillWidth: true }
                        Text { text: finestra.passo.fase === "scarica" ? (finestra.passo.testo || "") : ""; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13 }
                    }
                    Text {
                        text: I18n.t("Puoi continuare a usare il computer mentre si aggiorna.")
                        color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                    }
                }

                // Installato: riavvia
                ColumnLayout {
                    visible: finestra.stato === "fatto"
                    spacing: 8
                    Layout.fillWidth: true
                    RowLayout {
                        spacing: 10
                        Rectangle {
                            width: 26; height: 26; radius: 13; color: "#22C55E"
                            Text { anchors.centerIn: parent; text: "✓"; color: "white"; font.pixelSize: 15; font.weight: Font.Bold }
                        }
                        Text { text: I18n.t("Aggiornamento installato"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 17; font.weight: Font.DemiBold }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: I18n.t("Per usare la nuova versione riavvia il computer. Le finestre aperte si chiudono: salva prima il tuo lavoro.")
                        wrapMode: Text.WordWrap; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13
                    }
                    RowLayout {
                        Layout.topMargin: 6
                        spacing: 10
                        Pulsante { text: I18n.t("Riavvia ora"); principale: true; onClicked: ponte.chiama0("riavvia") }
                        Pulsante { text: I18n.t("Più tardi"); onClicked: finestra.close() }
                    }
                }

                // Errore o nessuna connessione
                ColumnLayout {
                    visible: finestra.stato === "errore" || finestra.stato === "offline"
                    spacing: 8
                    Layout.fillWidth: true
                    Text {
                        text: finestra.stato === "offline" ? I18n.t("Impossibile cercare aggiornamenti") : I18n.t("L'aggiornamento non è riuscito")
                        color: Tema.testo; font.family: Tema.font; font.pixelSize: 17; font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: finestra.messaggio || (finestra.stato === "offline" ? I18n.t("Controlla la connessione a internet.") : "")
                        wrapMode: Text.WordWrap; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13
                    }
                    Text {
                        visible: finestra.stato === "errore"
                        Layout.fillWidth: true
                        text: I18n.t("Il computer non è stato modificato oppure puoi tornare al punto di ripristino dalla Linea del Tempo.")
                        wrapMode: Text.WordWrap; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                    }
                    Pulsante { Layout.topMargin: 6; text: I18n.t("Riprova"); principale: true; onClicked: finestra.cerca() }
                }
            }
        }

        // ── Sotto la scheda: altri aggiornamenti e automatici ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: altri.implicitHeight + 28
            radius: 14
            color: Tema.superficie
            border.color: Tema.bordo
            visible: finestra.stato !== "controllo"
            ColumnLayout {
                id: altri
                anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 18
                spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text { text: I18n.t("Sistema di base e app"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
                        Text {
                            text: (finestra.info.altri || 0) > 0 ? I18n.t("{n} aggiornamenti disponibili").replace("{n}", finestra.info.altri) : I18n.t("Tutto aggiornato")
                            color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Pulsante {
                        visible: (finestra.info.altri || 0) > 0
                        text: I18n.t("Aggiorna")
                        onClicked: { ponte.avvia("altri", [], "altri"); finestra.info = Object.assign({}, finestra.info, { altri: 0 }) }
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: Tema.bordo }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: I18n.t("Aggiornamenti automatici"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; Layout.fillWidth: true }
                    Text { text: I18n.t("Attivi, ogni giorno"); color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13 }
                }
            }
        }
        Item { Layout.fillHeight: true }
    }
}
