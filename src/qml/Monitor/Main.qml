import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Monitor di sistema")
    property var dati: ({ memoria: {}, swap: {}, rete: {}, dischi: [], processi: [], cpuCore: [] })
    property string ordine: "cpu"
    function aggiorna() { dati = ponte.chiama("istantanea", [ordine, ricerca.text]) }
    Timer { interval: 2000; running: finestra.visible; repeat: true; triggeredOnStart: true; onTriggered: finestra.aggiorna() }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Repeater {
                model: [
                    { t: I18n.t("Processore"), v: finestra.dati.cpu + "%", p: finestra.dati.cpu / 100 },
                    { t: I18n.t("Memoria"), v: finestra.dati.memoria.usata + " / " + finestra.dati.memoria.totale + " MB", p: finestra.dati.memoria.percentuale / 100 },
                    { t: I18n.t("Swap (zram)"), v: finestra.dati.swap.usata + " / " + finestra.dati.swap.totale + " MB", p: finestra.dati.swap.totale ? finestra.dati.swap.usata / finestra.dati.swap.totale : 0 },
                    { t: I18n.t("Rete"), v: "↓ " + finestra.dati.rete.giu + "  ↑ " + finestra.dati.rete.su + " KB/s", p: -1 }
                ]
                Scheda {
                    Layout.fillWidth: true
                    implicitHeight: 92
                    ColumnLayout {
                        anchors.fill: parent
                        Testo { text: modelData.t; secondario: true }
                        Titolo { text: modelData.v || "…"; livello: 3 }
                        BarraProgresso { Layout.fillWidth: true; value: modelData.p; visible: modelData.p >= 0 }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            CampoRicerca { id: ricerca; Layout.fillWidth: true; placeholderText: I18n.t("Cerca un processo…"); onTextChanged: finestra.aggiorna() }
            Scelta {
                model: [{ testo: I18n.t("Ordina per CPU"), valore: "cpu" }, { testo: I18n.t("Ordina per memoria"), valore: "memoria" }, { testo: I18n.t("Ordina per nome"), valore: "nome" }]
                onActivated: { finestra.ordine = currentValue; finestra.aggiorna() }
            }
        }
        Scheda {
            Layout.fillWidth: true
            Layout.fillHeight: true
            margine: 4
            ListView {
                anchors.fill: parent
                clip: true
                model: finestra.dati.processi
                header: RowLayout {
                    width: ListView.view.width
                    Testo { text: I18n.t("Nome"); secondario: true; Layout.fillWidth: true; leftPadding: 8 }
                    Testo { text: "CPU %"; secondario: true; Layout.preferredWidth: 70 }
                    Testo { text: I18n.t("Memoria MB"); secondario: true; Layout.preferredWidth: 100 }
                    Item { Layout.preferredWidth: 110 }
                }
                delegate: RowLayout {
                    width: ListView.view.width
                    height: 34
                    Testo { text: modelData.nome + "  (" + modelData.pid + ")"; Layout.fillWidth: true; elide: Text.ElideRight; wrapMode: Text.NoWrap; leftPadding: 8 }
                    Testo { text: modelData.cpu; Layout.preferredWidth: 70 }
                    Testo { text: modelData.memoria; Layout.preferredWidth: 100 }
                    Pulsante { text: I18n.t("Termina"); enabled: modelData.mio; Layout.preferredWidth: 110; onClicked: { ponte.chiama("termina", [modelData.pid, false]); finestra.aggiorna() } }
                }
            }
        }
        Testo { secondario: true; text: I18n.t("Acceso dal") + " " + (finestra.dati.avvio || "") }
    }
}
