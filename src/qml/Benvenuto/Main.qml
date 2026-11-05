// Benvenuto: configurazione guidata al primo avvio.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Benvenuto in") + " " + Tema.nomeSistema
    width: 820
    height: 600
    property var info: ponte.chiama0("info")
    property var reti: []
    property string tema: "scuro"
    property string accento: Tema.accento
    property var statoCondivisione: ({})

    PassiGuidati {
        id: passi
        anchors.fill: parent
        testoFine: I18n.t("Inizia a usare") + " " + Tema.nomeSistema
        pagine: [pBenvenuto, pLingua, pWifi, pAccount, pAspetto, pWindows, pPrestazioni, pCondivisione, pFine]
        onCambioPagina: function (i) { if (i === 2) ponte.avvia("reti", [], "reti") }
        onFinito: { ponte.chiama0("fine"); Qt.quit() }
    }
    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id === "reti") finestra.reti = r
            else if (id === "connetti") { finestra.avviso(r.ok ? I18n.t("Connesso") : r.messaggio); ponte.avvia("reti", [], "reti") }
            else if (id === "condivisione") finestra.statoCondivisione = r
        }
    }

    Component {
        id: pBenvenuto
        ColumnLayout {
            spacing: 18
            Item { Layout.fillHeight: true }
            Image { Layout.alignment: Qt.AlignHCenter; source: "image://icona/" + Tema.logo; sourceSize.width: 128; sourceSize.height: 128 }
            Titolo { Layout.alignment: Qt.AlignHCenter; text: I18n.t("Benvenuto in") + " " + Tema.nomeSistema }
            Testo { Layout.alignment: Qt.AlignHCenter; secondario: true; text: I18n.t("Il sistema che non si rompe, non rallenta e ricorda tutto.") }
            Testo { Layout.alignment: Qt.AlignHCenter; text: I18n.t("Bastano un paio di minuti per sistemare tutto.") }
            Pulsante {
                Layout.alignment: Qt.AlignHCenter
                visible: finestra.info.live
                principale: true
                icona: "system-software-install"
                text: I18n.t("Installa") + " " + Tema.nomeSistema + " " + I18n.t("su questo computer")
                onClicked: ponte.chiama0("installa")
            }
            Testo { Layout.alignment: Qt.AlignHCenter; visible: finestra.info.live; secondario: true; text: I18n.t("Oppure continua per provarlo senza modificare nulla.") }
            Item { Layout.fillHeight: true }
        }
    }
    Component {
        id: pLingua
        ColumnLayout {
            spacing: 14
            Titolo { text: I18n.t("Lingua") }
            Scelta {
                Layout.preferredWidth: 320
                model: ponte.chiama0("lingue")
                Component.onCompleted: currentIndex = Math.max(0, indexOfValue(finestra.info.lingua))
                onActivated: ponte.chiama("impostaLingua", [currentValue])
            }
            Testo { secondario: true; text: I18n.t("La lingua scelta vale dal prossimo accesso.") }
            Item { Layout.fillHeight: true }
        }
    }
    Component {
        id: pWifi
        ColumnLayout {
            spacing: 10
            Titolo { text: I18n.t("Connettiti a Internet") }
            Testo { secondario: true; text: ponte.chiama0("connesso") ? "✅ " + I18n.t("Sei già connesso.") : I18n.t("Scegli la tua rete Wi-Fi (puoi anche saltare questo passo).") }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: finestra.reti
                delegate: VoceElenco {
                    width: ListView.view.width
                    icona: "network-wireless"
                    titolo: modelData.ssid + (modelData.connessa ? "  ✓" : "")
                    sottotitolo: (modelData.protetta ? "🔒 " : "") + modelData.segnale + "%"
                    onClicked: { password.ssid = modelData.ssid; if (modelData.protetta) password.open(); else ponte.avvia("connetti", [modelData.ssid, ""], "connetti") }
                }
                Testo { anchors.centerIn: parent; visible: parent.count === 0; secondario: true; text: I18n.t("Ricerca delle reti…") }
            }
        }
    }
    Component {
        id: pAccount
        ColumnLayout {
            spacing: 14
            Titolo { text: I18n.t("Il tuo account") }
            RowLayout {
                spacing: 16
                Rectangle { width: 72; height: 72; radius: 36; color: Tema.accento; Testo { anchors.centerIn: parent; color: "#FFFFFF"; font.pointSize: 26; text: finestra.info.nome ? finestra.info.nome.charAt(0).toUpperCase() : "?" } }
                ColumnLayout {
                    Titolo { livello: 2; text: finestra.info.nome || "" }
                    Testo { secondario: true; text: I18n.t("Nome utente:") + " " + (finestra.info.utente || "") }
                }
            }
            Testo { Layout.fillWidth: true; text: I18n.t("Altre persone usano questo computer? Ognuna può avere il proprio account con file e impostazioni separati.") }
            Pulsante { text: I18n.t("Aggiungi un'altra persona"); icona: "list-add-user"; onClicked: ponte.chiama0("utenti") }
            Item { Layout.fillHeight: true }
        }
    }
    Component {
        id: pAspetto
        ColumnLayout {
            spacing: 16
            Titolo { text: I18n.t("Scegli l'aspetto") }
            RowLayout {
                spacing: 20
                Repeater {
                    model: [{ id: "scuro", nome: I18n.t("Scuro"), sfondo: "#0B1220", testo: "#E8EEF8" }, { id: "chiaro", nome: I18n.t("Chiaro"), sfondo: "#F5F7FB", testo: "#0F172A" }]
                    Rectangle {
                        width: 200; height: 130; radius: 14
                        color: modelData.sfondo
                        border.width: finestra.tema === modelData.id ? 3 : 1
                        border.color: finestra.tema === modelData.id ? finestra.accento : Tema.bordo
                        Text { anchors.centerIn: parent; text: modelData.nome; color: modelData.testo; font.pointSize: 14 }
                        MouseArea { anchors.fill: parent; onClicked: { finestra.tema = modelData.id; ponte.chiama("tema", [finestra.tema, finestra.accento]) } }
                    }
                }
            }
            Testo { text: I18n.t("Colore d'accento") }
            Row {
                spacing: 10
                Repeater {
                    model: ["#3B82F6", "#8B5CF6", "#EC4899", "#EF4444", "#F97316", "#EAB308", "#22C55E", "#14B8A6", "#64748B"]
                    Rectangle {
                        width: 34; height: 34; radius: 17; color: modelData
                        border.width: finestra.accento === modelData ? 3 : 0
                        border.color: Tema.testo
                        MouseArea { anchors.fill: parent; onClicked: { finestra.accento = modelData; ponte.chiama("tema", [finestra.tema, finestra.accento]) } }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }
    Component {
        id: pWindows
        ColumnLayout {
            spacing: 14
            Titolo { text: I18n.t("Arrivi da Windows?") }
            Testo { Layout.fillWidth: true; text: I18n.t("Puoi importare documenti, foto, musica, sfondo, preferiti del browser e reti Wi-Fi dal tuo vecchio Windows, anche se è su questo stesso computer.") }
            Pulsante { text: I18n.t("Importa da Windows"); icona: "folder-download"; principale: true; onClicked: ponte.chiama0("migrazione") }
            Testo { secondario: true; text: I18n.t("Puoi farlo anche più tardi dal menu: «Migrazione da Windows».") }
            Item { Layout.fillHeight: true }
        }
    }
    Component {
        id: pPrestazioni
        ColumnLayout {
            spacing: 14
            Titolo { text: I18n.t("Prestazioni") }
            Testo { Layout.fillWidth: true; text: I18n.t("Questo computer ha") + " " + finestra.info.ram + " MB " + I18n.t("di memoria.") + " " + (finestra.info.leggero ? I18n.t("Abbiamo attivato il profilo «PC vecchio» per mantenerlo veloce.") : I18n.t("Le prestazioni sono buone: puoi usare il profilo completo.")) }
            RigaImpostazione {
                Layout.fillWidth: true
                titolo: I18n.t("Profilo «PC vecchio»")
                descrizione: I18n.t("Meno animazioni ed effetti, browser più leggero, più memoria compressa")
                Interruttore { checked: finestra.info.leggero; onToggled: ponte.avvia("profiloLeggero", [checked], "profilo") }
            }
            Item { Layout.fillHeight: true }
        }
    }
    Component {
        id: pCondivisione
        ColumnLayout {
            spacing: 12
            Titolo { text: I18n.t("Condivisione Vicina") }
            Testo { Layout.fillWidth: true; text: I18n.t("Scambia file con telefoni Android, iPhone e altri computer. Chi può vedere questo computer?") }
            Scelta {
                id: vis
                Layout.preferredWidth: 320
                model: [{ testo: I18n.t("Nessuno (consigliato, la attivi quando serve)"), valore: "nessuno" }, { testo: I18n.t("Solo dispositivi associati"), valore: "associati" }, { testo: I18n.t("Tutti per 10 minuti"), valore: "tutti10" }]
            }
            CampoTesto { id: nomeDisp; Layout.preferredWidth: 320; placeholderText: I18n.t("Nome del computer sui telefoni (facoltativo)") }
            Pulsante { text: I18n.t("Salva e verifica la compatibilità"); onClicked: ponte.avvia("condivisione", [vis.currentValue, nomeDisp.text], "condivisione") }
            Repeater {
                model: Object.keys(finestra.statoCondivisione)
                Testo { Layout.fillWidth: true; text: ({ quickshare: "Android", airdrop: "iPhone/Mac (AirDrop)", localsend: "LocalSend", qr: "QR" })[modelData] + ": " + (finestra.statoCondivisione[modelData][0] ? "✅ " : "⚠️ ") + finestra.statoCondivisione[modelData][1] }
            }
            Item { Layout.fillHeight: true }
        }
    }
    Component {
        id: pFine
        ColumnLayout {
            spacing: 14
            Item { Layout.fillHeight: true }
            Titolo { Layout.alignment: Qt.AlignHCenter; text: I18n.t("Tutto pronto!") }
            Testo { Layout.alignment: Qt.AlignHCenter; text: I18n.t("Qualche scorciatoia utile:") }
            GridLayout {
                Layout.alignment: Qt.AlignHCenter
                columns: 2
                columnSpacing: 24
                Testo { text: "Super + " + I18n.t("Spazio"); font.weight: Font.DemiBold } Testo { text: I18n.t("Barra Unica: cerca e fai qualsiasi cosa") }
                Testo { text: "Super + A"; font.weight: Font.DemiBold } Testo { text: I18n.t("Centro di controllo") }
                Testo { text: "Super + T"; font.weight: Font.DemiBold } Testo { text: I18n.t("Linea del Tempo") }
                Testo { text: "Super + E"; font.weight: Font.DemiBold } Testo { text: I18n.t("File") }
            }
            Item { Layout.fillHeight: true }
        }
    }

    Dialog {
        id: password
        property string ssid: ""
        title: ssid
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Cancel | Dialog.Ok
        CampoTesto { id: campoPassword; echoMode: TextInput.Password; placeholderText: I18n.t("Password del Wi-Fi"); width: 300 }
        onAccepted: { ponte.avvia("connetti", [ssid, campoPassword.text], "connetti"); campoPassword.text = "" }
    }
}
