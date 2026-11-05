// Disegna una voce di impostazione in base al suo tipo.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Item {
    id: radice
    property var voce: ({})
    property string filtro: ""
    property bool evidenziata: false
    signal cambia(var valore)
    signal esegui(string elemento, string azione, var dati)
    signal chiediDati(string elemento, string azione, var campi)
    signal chiediFile(string elemento, string azione)

    function corrisponde() {
        if (!filtro) return true
        var t = ((voce.titolo || "") + " " + (voce.descrizione || "") + " " + (voce.chiavi || "")).toLowerCase()
        return t.indexOf(filtro.toLowerCase()) >= 0
    }
    visible: voce.tipo === "intestazione" ? !filtro : corrisponde()
    implicitHeight: visible ? caricatore.implicitHeight : 0

    function avviaAzione(elemento, azione, campi, file) {
        if (file) chiediFile(elemento, azione)
        else if (campi && campi.length) chiediDati(elemento, azione, campi)
        else esegui(elemento, azione, {})
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: 8
        color: "transparent"
        border.color: Tema.accento
        border.width: 2
        visible: radice.evidenziata
    }

    Loader {
        id: caricatore
        width: parent.width
        sourceComponent: {
            switch (radice.voce.tipo) {
            case "intestazione": return compIntestazione
            case "interruttore": return compInterruttore
            case "scelta": return compScelta
            case "cursore": return compCursore
            case "campo": return compCampo
            case "azione": return compAzione
            case "elenco": return compElenco
            default: return compInfo
            }
        }
    }

    Component {
        id: compIntestazione
        Titolo { text: radice.voce.titolo; livello: 3; topPadding: 16; bottomPadding: 2 }
    }
    Component {
        id: compInterruttore
        RigaImpostazione {
            titolo: radice.voce.titolo
            descrizione: radice.voce.descrizione || ""
            Interruttore {
                checked: radice.voce.valore
                enabled: radice.voce.abilitata !== false
                onToggled: radice.cambia(checked)
            }
        }
    }
    Component {
        id: compScelta
        RigaImpostazione {
            titolo: radice.voce.titolo
            descrizione: radice.voce.descrizione || ""
            Scelta {
                model: radice.voce.opzioni
                Component.onCompleted: currentIndex = Math.max(0, indexOfValue(radice.voce.valore))
                onActivated: radice.cambia(currentValue)
            }
        }
    }
    Component {
        id: compCursore
        RigaImpostazione {
            titolo: radice.voce.titolo
            descrizione: Math.round(cursore.value) + (radice.voce.unita || "")
            Cursore {
                id: cursore
                width: 240
                from: radice.voce.minimo
                to: radice.voce.massimo
                stepSize: radice.voce.passo
                value: radice.voce.valore
                onPressedChanged: if (!pressed) radice.cambia(Math.round(value))
            }
        }
    }
    Component {
        id: compCampo
        RigaImpostazione {
            titolo: radice.voce.titolo
            descrizione: radice.voce.descrizione || ""
            CampoTesto {
                width: 280
                text: radice.voce.valore
                echoMode: radice.voce.segreto ? TextInput.Password : TextInput.Normal
                onEditingFinished: if (text !== radice.voce.valore) radice.cambia(text)
            }
        }
    }
    Component {
        id: compInfo
        RigaImpostazione {
            titolo: radice.voce.titolo
            descrizione: radice.voce.descrizione || ""
            Testo {
                text: radice.voce.valore || ""
                secondario: true
                width: Math.min(implicitWidth, 420)
                horizontalAlignment: Text.AlignRight
            }
        }
    }
    Component {
        id: compAzione
        RigaImpostazione {
            titolo: radice.voce.titolo
            descrizione: radice.voce.descrizione || ""
            Pulsante {
                text: radice.voce.pulsante
                pericoloso: radice.voce.pericolosa === true
                onClicked: radice.avviaAzione("", "esegui", radice.voce.richiede, radice.voce.file)
            }
        }
    }
    Component {
        id: compElenco
        ColumnLayout {
            spacing: 4
            Testo { text: radice.voce.titolo; secondario: true; topPadding: 6 }
            Scheda {
                Layout.fillWidth: true
                margine: 6
                ColumnLayout {
                    width: parent.width
                    spacing: 2
                    Testo {
                        visible: (radice.voce.elementi || []).length === 0
                        text: radice.voce.vuoto
                        secondario: true
                        padding: 10
                    }
                    Repeater {
                        model: radice.voce.elementi
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Icona { nome: modelData.icona || ""; lato: 24; Layout.leftMargin: 8; visible: !!modelData.icona }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 6
                                Layout.bottomMargin: 6
                                spacing: 0
                                Testo { text: modelData.titolo; font.weight: modelData.attivo ? Font.DemiBold : Font.Normal; Layout.fillWidth: true; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                                Testo { text: modelData.sottotitolo || ""; secondario: true; visible: text !== ""; font.pointSize: Tema.fontDimensione - 1; Layout.fillWidth: true; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                            }
                            Repeater {
                                model: modelData.azioni || []
                                Pulsante {
                                    text: modelData.testo
                                    pericoloso: modelData.pericolosa === true
                                    onClicked: radice.avviaAzione(elementoId.text, modelData.id, modelData.richiede, false)
                                }
                            }
                            Text { id: elementoId; text: modelData.id; visible: false }
                        }
                    }
                }
            }
        }
    }
}
