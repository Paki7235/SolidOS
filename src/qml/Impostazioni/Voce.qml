// Una riga di un gruppo di impostazioni, disegnata in base al suo tipo.
// Le righe dopo la prima hanno una sottile linea di separazione in alto.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Item {
    id: radice
    property var voce: ({})
    property string filtro: ""
    property bool evidenziata: false
    property bool primaRiga: true
    signal cambia(var valore)
    signal esegui(string elemento, string azione, var dati)
    signal chiediDati(string elemento, string azione, var campi)
    signal chiediFile(string elemento, string azione)

    function corrisponde() {
        if (!filtro) return true
        var t = ((voce.titolo || "") + " " + (voce.descrizione || "") + " " + (voce.chiavi || "")).toLowerCase()
        return t.indexOf(filtro.toLowerCase()) >= 0
    }
    visible: corrisponde()
    implicitHeight: visible ? caricatore.implicitHeight : 0
    height: implicitHeight

    function avviaAzione(elemento, azione, campi, file) {
        if (file) chiediFile(elemento, azione)
        else if (campi && campi.length) chiediDati(elemento, azione, campi)
        else esegui(elemento, azione, {})
    }

    Rectangle {
        visible: !radice.primaRiga
        anchors.top: parent.top
        x: 14
        width: parent.width - 28
        height: 1
        color: Tema.chiaro ? "#E5E5EA" : "#14FFFFFF"
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
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
        id: compInterruttore
        RigaImpostazione {
            titolo: radice.voce.titolo
            descrizione: radice.voce.descrizione || ""
            Interruttore {
                checked: radice.voce.valore === true
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
            descrizione: radice.voce.descrizione || ""
            Row {
                spacing: 10
                Cursore {
                    id: cursore
                    width: 200
                    anchors.verticalCenter: parent.verticalCenter
                    from: radice.voce.minimo
                    to: radice.voce.massimo
                    stepSize: radice.voce.passo
                    value: radice.voce.valore
                    onPressedChanged: if (!pressed) radice.cambia(Math.round(value))
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    text: Math.round(cursore.value) + (radice.voce.unita || "")
                    color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
    Component {
        id: compCampo
        RigaImpostazione {
            titolo: radice.voce.titolo
            descrizione: radice.voce.descrizione || ""
            CampoTesto {
                width: 240
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
            Text {
                text: radice.voce.valore === undefined || radice.voce.valore === null ? "" : String(radice.voce.valore)
                color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13
                width: Math.min(implicitWidth, 360)
                elide: Text.ElideRight
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
        Column {
            width: radice.width
            Text {
                visible: (radice.voce.elementi || []).length === 0
                text: radice.voce.vuoto || ""
                color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 13
                leftPadding: 14; topPadding: 13; bottomPadding: 13
            }
            Repeater {
                model: radice.voce.elementi
                Item {
                    width: radice.width
                    height: Math.max(44, riga.implicitHeight + 14)
                    Rectangle { visible: index > 0; x: 14; width: parent.width - 28; height: 1; color: Tema.chiaro ? "#E5E5EA" : "#14FFFFFF" }
                    RowLayout {
                        id: riga
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10
                        // Utenti: la foto del profilo (o le iniziali) in un cerchio; altrimenti l'icona
                        FotoAccount {
                            visible: modelData.iniziali !== undefined
                            lato: visible ? 36 : 0
                            Layout.preferredWidth: lato; Layout.preferredHeight: lato
                            account: ({ foto: modelData.foto || "", iniziali: modelData.iniziali || "" })
                        }
                        Icona { nome: modelData.icona || ""; lato: 22; visible: !!modelData.icona && modelData.iniziali === undefined }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text { text: modelData.titolo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; font.weight: modelData.attivo ? Font.DemiBold : Font.Normal; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { text: modelData.sottotitolo || ""; visible: text !== ""; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                        Repeater {
                            model: modelData.azioni || []
                            Pulsante {
                                property string elemento: ""
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
