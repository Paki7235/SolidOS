// Menu Start (come su Windows): ricerca, tutte le app, pulsanti di sistema.
// Si apre con un clic sul logo in alto a sinistra o premendo da solo il tasto Super.
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: start
    signal chiudi()
    property var app: shell.chiama0("tutteLeApp")
    property string filtro: ricerca.text.toLowerCase()
    readonly property var visibili: filtro === "" ? app : app.filter(function (a) {
        return (a.nome + " " + a.descrizione + " " + a.chiavi).toLowerCase().indexOf(filtro) >= 0
    })
    function avvia(a) { shell.chiama("dockApri", [a.id]); start.chiudi() }

    width: 640
    height: 560
    radius: 14
    color: "#F21C1D22"
    border.color: "#24FFFFFF"
    border.width: 1
    MouseArea { anchors.fill: parent }   // i clic dentro non chiudono il menu

    Component.onCompleted: ricerca.forceActiveFocus()

    // Ricerca
    CampoRicerca {
        id: ricerca
        x: 20; y: 20
        width: parent.width - 40
        height: 36
        font.pixelSize: 15
        placeholderText: I18n.t("Cerca app e impostazioni")
        Keys.onReturnPressed: if (start.visibili.length) start.avvia(start.visibili[0])
        Keys.onEscapePressed: start.chiudi()
    }

    Text {
        x: 24; y: 70
        text: start.filtro ? I18n.t("Risultati") : I18n.t("Tutte le app")
        color: "#A1A1AA"; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold
    }

    // Griglia delle app
    GridView {
        id: griglia
        x: 14; y: 92
        width: parent.width - 28
        height: parent.height - 92 - 64
        clip: true
        cellWidth: width / 6
        cellHeight: 98
        model: start.visibili
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        delegate: Item {
            required property var modelData
            required property int index
            width: griglia.cellWidth
            height: griglia.cellHeight
            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: 10
                color: area.pressed ? "#33FFFFFF" : (area.containsMouse || (start.filtro && index === 0) ? "#1FFFFFFF" : "transparent")
            }
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 12
                width: 44; height: 44
                sourceSize.width: 88; sourceSize.height: 88
                source: "image://icona/" + modelData.icona
                asynchronous: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 62
                width: parent.width - 10
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
                text: modelData.nome
                color: "#F5F5F7"; font.family: Tema.font; font.pixelSize: 12
            }
            MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: start.avvia(modelData) }
        }
        Text {
            anchors.centerIn: parent
            visible: griglia.count === 0
            text: I18n.t("Nessuna app trovata")
            color: "#A1A1AA"; font.family: Tema.font; font.pixelSize: 13
        }
    }

    // Barra inferiore: utente e pulsanti di sistema
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 56
        radius: 14
        color: "#14FFFFFF"
        Rectangle { width: parent.width; height: 14; color: parent.color; anchors.top: parent.top; visible: false }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 20
            spacing: 10
            Rectangle {
                width: 30; height: 30; radius: 15
                anchors.verticalCenter: parent.verticalCenter
                gradient: Gradient { GradientStop { position: 0; color: "#A1A1AA" } GradientStop { position: 1; color: "#6E6E76" } }
                Text { anchors.centerIn: parent; text: Tema.nomeSistema.charAt(0); color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.DemiBold }
            }
            Text { anchors.verticalCenter: parent.verticalCenter; text: Tema.nomeSistema; color: "#F5F5F7"; font.family: Tema.font; font.pixelSize: 13 }
        }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 14
            spacing: 6
            Repeater {
                model: [
                    { t: I18n.t("Impostazioni"), i: "preferences-system", f: function () { shell.chiama("apri", ["impostazioni"]) } },
                    { t: I18n.t("Blocca"), i: "system-lock-screen", f: function () { shell.chiama("sessione", ["blocca"]) } },
                    { t: I18n.t("Riavvia"), i: "system-reboot", f: function () { shell.chiama("sessione", ["riavvia"]) } },
                    { t: I18n.t("Spegni"), i: "system-shutdown", f: function () { shell.chiama("sessione", ["spegni"]) } }
                ]
                Rectangle {
                    width: contenuto.width + 20
                    height: 34
                    radius: 8
                    color: ma.pressed ? "#33FFFFFF" : (ma.containsMouse ? "#24FFFFFF" : "transparent")
                    Row {
                        id: contenuto
                        anchors.centerIn: parent
                        spacing: 7
                        Image { width: 18; height: 18; sourceSize.width: 36; sourceSize.height: 36; source: "image://icona/" + modelData.i; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: modelData.t; color: "#F5F5F7"; font.family: Tema.font; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: { modelData.f(); start.chiudi() } }
                }
            }
        }
    }
}
