import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: Tema.nomeSistema + " App"
    width: 1000
    height: 680
    property var vetrina: ponte.chiama0("vetrina")
    property var risultati: []
    property var installate: []
    property int scheda: 0
    property string occupata: ""
    property bool cercando: false
    property bool preparando: true        // all'apertura scarica il catalogo di Flathub

    function cerca(t) { if (t.length < 2) { risultati = []; return } cercando = true; ponte.avvia("cerca", [t], "cerca") }
    function aggiornaInstallate() { ponte.avvia("installate", [], "installate") }
    function installa(app) { occupata = app.id; ponte.avvia("installa", [app.id, app.origine], "installa") }
    function rimuovi(app) { occupata = app.id; ponte.avvia("rimuovi", [app.id, app.origine, app.sistema === true], "rimuovi") }

    Component.onCompleted: {
        ponte.avvia("prepara", [], "prepara")
        aggiornaInstallate()
        var iniziale = ponte.chiama0("ricercaIniziale")
        if (iniziale) { ricerca.text = iniziale; cerca(iniziale) }
    }
    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id === "prepara") {
                finestra.preparando = false
                if (!r.ok) finestra.avviso(r.messaggio)
                else if (ricerca.text.length >= 2) finestra.cerca(ricerca.text)
            }
            else if (id === "cerca") { finestra.risultati = r; finestra.cercando = false }
            else if (id === "installate") finestra.installate = r
            else if (id === "installa" || id === "rimuovi" || id === "aggiorna") {
                finestra.occupata = ""
                finestra.avviso(r.ok ? (r.messaggio || I18n.t("Fatto")) : (r.messaggio || I18n.t("Operazione non riuscita")))
                finestra.aggiornaInstallate()
                if (ricerca.text) finestra.cerca(ricerca.text)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 72
            color: Tema.superficie
            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                TabBar {
                    id: schede
                    onCurrentIndexChanged: finestra.scheda = currentIndex
                    background: Item {}
                    TabButton { text: I18n.t("Scopri"); width: implicitWidth + 20 }
                    TabButton { text: I18n.t("Installate"); width: implicitWidth + 20 }
                }
                CampoRicerca {
                    id: ricerca
                    Layout.fillWidth: true
                    placeholderText: I18n.t("Cerca app, giochi, strumenti…")
                    onAccepted: { schede.currentIndex = 0; finestra.cerca(text) }
                }
                Pulsante { text: I18n.t("Aggiorna tutto"); icona: "system-software-update"; onClicked: { finestra.occupata = "*"; ponte.avvia("aggiorna", [], "aggiorna") } }
            }
        }
        BarraProgresso { Layout.fillWidth: true; indeterminate: true; visible: finestra.preparando || finestra.cercando || finestra.occupata !== "" }
        Testo {
            visible: finestra.preparando || finestra.occupata !== ""
            Layout.fillWidth: true; Layout.leftMargin: 16; Layout.topMargin: 6
            secondario: true
            text: finestra.occupata !== "" ? I18n.t("Download e installazione in corso: può volerci qualche minuto…")
                                           : I18n.t("Preparo il catalogo delle app (la prima volta può volerci un minuto)…")
        }
        GridView {
            id: griglia
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 16
            clip: true
            cellWidth: Math.max(300, width / Math.floor(width / 300))
            cellHeight: 130
            model: finestra.scheda === 1 ? finestra.installate : (ricerca.text.length >= 2 ? finestra.risultati : finestra.vetrina)
            delegate: Item {
                width: griglia.cellWidth
                height: griglia.cellHeight
                Scheda {
                    anchors.fill: parent
                    anchors.margins: 6
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 4
                        RowLayout {
                            Icona { nome: modelData.icona || modelData.id; lato: 36 }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Testo { text: modelData.nome; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                                Testo { text: modelData.origine === "flatpak" ? "Flathub" : (modelData.origine === "apt" ? "Debian" : "AppImage"); secondario: true; font.pointSize: Tema.fontDimensione - 2 }
                            }
                            Pulsante {
                                Layout.alignment: Qt.AlignVCenter
                                enabled: finestra.occupata === ""
                                principale: !modelData.installata && finestra.scheda === 0
                                pericoloso: finestra.scheda === 1
                                text: finestra.occupata === modelData.id ? I18n.t("Attendi…") : (finestra.scheda === 1 ? I18n.t("Rimuovi") : (modelData.installata ? I18n.t("Installata") : I18n.t("Installa")))
                                onClicked: finestra.scheda === 1 ? finestra.rimuovi(modelData) : (!modelData.installata && finestra.installa(modelData))
                            }
                        }
                        Testo { text: modelData.descrizione || ""; secondario: true; maximumLineCount: 2; elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                }
            }
            Testo {
                anchors.centerIn: parent
                visible: griglia.count === 0 && !finestra.cercando
                secondario: true
                text: finestra.scheda === 1 ? I18n.t("Nessuna app installata dallo store")
                      : (finestra.preparando ? I18n.t("Catalogo in preparazione…") : I18n.t("Nessun risultato: prova con un'altra parola"))
            }
        }
    }
}
