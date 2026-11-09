// Testo: editor semplice. Ctrl+N nuovo, Ctrl+O apri, Ctrl+S salva, Ctrl+F cerca.
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    width: 860
    height: 620
    property string percorso: ""
    property string nome: I18n.t("Senza titolo")
    property bool modificato: false
    property string daSalvare: ""
    title: (modificato ? "● " : "") + nome + " — " + I18n.t("Testo")

    function apri(p) {
        var r = ponte.chiama("apri", [p])
        if (!r.ok) { finestra.avviso(r.errore); return }
        area.text = r.testo; percorso = r.percorso; nome = r.nome; modificato = false
    }
    function salva(comeNuovo) {
        if (!percorso || comeNuovo) { dialogoSalva.open(); return }
        var r = ponte.chiama("salva", [percorso, area.text])
        if (r.ok) { modificato = false; finestra.avviso(I18n.t("Salvato")) } else finestra.avviso(r.errore)
    }
    function nuovo() { area.text = ""; percorso = ""; nome = I18n.t("Senza titolo"); modificato = false }

    Component.onCompleted: { var f = ponte.chiama0("fileIniziale"); if (f) apri(f) }

    Shortcut { sequence: StandardKey.New; onActivated: finestra.nuovo() }
    Shortcut { sequence: StandardKey.Open; onActivated: dialogoApri.open() }
    Shortcut { sequence: StandardKey.Save; onActivated: finestra.salva(false) }
    Shortcut { sequence: "Ctrl+Shift+S"; onActivated: finestra.salva(true) }
    Shortcut { sequence: StandardKey.Find; onActivated: { barraCerca.visible = true; campoCerca.forceActiveFocus() } }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Barra {
            Layout.fillWidth: true
            titolo: finestra.nome
            Pulsante { text: I18n.t("Nuovo"); onClicked: finestra.nuovo() }
            Pulsante { text: I18n.t("Apri…"); onClicked: dialogoApri.open() }
            Pulsante { text: I18n.t("Salva"); principale: finestra.modificato; onClicked: finestra.salva(false) }
            Pulsante { text: I18n.t("Cerca"); onClicked: { barraCerca.visible = !barraCerca.visible; if (barraCerca.visible) campoCerca.forceActiveFocus() } }
        }
        Rectangle {
            id: barraCerca
            visible: false
            Layout.fillWidth: true
            implicitHeight: 44
            color: Tema.superficie
            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: 14
                spacing: 8
                CampoRicerca {
                    id: campoCerca
                    width: 260
                    placeholderText: I18n.t("Cerca nel testo")
                    onAccepted: trova.esegui()
                    Keys.onEscapePressed: barraCerca.visible = false
                }
                Pulsante { id: trova; text: I18n.t("Trova successivo"); function esegui() {
                        var t = area.text.toLowerCase(), q = campoCerca.text.toLowerCase()
                        if (!q) return
                        var i = t.indexOf(q, area.cursorPosition)
                        if (i < 0) i = t.indexOf(q)
                        if (i >= 0) { area.select(i, i + q.length); area.forceActiveFocus() } else finestra.avviso(I18n.t("Non trovato"))
                    }
                    onClicked: esegui()
                }
            }
        }
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            TextArea {
                id: area
                wrapMode: TextArea.Wrap
                selectByMouse: true
                persistentSelection: true
                color: Tema.testo
                selectionColor: Tema.accento
                selectedTextColor: "#FFFFFF"
                font.family: Tema.font
                font.pixelSize: 14
                leftPadding: 18; rightPadding: 18; topPadding: 14
                background: Rectangle { color: Tema.sfondo }
                onTextChanged: finestra.modificato = true
                Component.onCompleted: forceActiveFocus()
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 26
            color: Tema.superficie
            Text {
                anchors.verticalCenter: parent.verticalCenter
                x: 14
                color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11
                text: {
                    var t = area.text
                    var righe = t.length ? t.split("\n").length : 0
                    var parole = t.trim().length ? t.trim().split(/\s+/).length : 0
                    return righe + " " + I18n.t("righe") + "  ·  " + parole + " " + I18n.t("parole") + "  ·  " + t.length + " " + I18n.t("caratteri")
                }
            }
        }
    }

    FileDialog { id: dialogoApri; onAccepted: finestra.apri(selectedFile.toString()) }
    FileDialog {
        id: dialogoSalva
        fileMode: FileDialog.SaveFile
        onAccepted: {
            var r = ponte.chiama("salva", [selectedFile.toString(), area.text])
            if (r.ok) { finestra.percorso = r.percorso; finestra.nome = r.nome; finestra.modificato = false } else finestra.avviso(r.errore)
        }
    }
}
