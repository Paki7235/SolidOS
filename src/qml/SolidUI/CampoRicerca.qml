import QtQuick
import QtQuick.Controls

CampoTesto {
    leftPadding: 36
    placeholderText: I18n.t("Cerca…")
    Icona { nome: "edit-find"; lato: 16; x: 12; anchors.verticalCenter: parent.verticalCenter; opacity: 0.7 }
    Keys.onEscapePressed: text = ""
}
