// Benvenuto: configurazione guidata al primo avvio.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Benvenuto in") + " " + Tema.nomeSistema
    width: 820
    height: 600
    property var info: ponte.chiama0("info")
    property var reti: []
    property string tema: "scuro"
    property string stile: Tema.stileBarra
    property string accento: Tema.accento
    property var statoCondivisione: ({})
    property var account: ponte.chiama0("account")
    property bool accountInCorso: false
    function azioneAccount(metodo, argomenti) { accountInCorso = true; ponte.avvia(metodo, argomenti, "account") }

    PassiGuidati {
        id: passi
        anchors.fill: parent
        testoFine: I18n.t("Inizia a usare") + " " + Tema.nomeSistema
        pagine: [pBenvenuto, pLingua, pWifi, pAccount, pSolidID, pAspetto, pStile, pWindows, pPrestazioni, pCondivisione, pFine]
        onCambioPagina: function (i) { if (i === 2) ponte.avvia("reti", [], "reti") }
        onFinito: { ponte.chiama0("fine"); Qt.quit() }
    }
    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id === "reti") finestra.reti = r
            else if (id === "connetti") { finestra.avviso(r.ok ? I18n.t("Connesso") : r.messaggio); ponte.avvia("reti", [], "reti") }
            else if (id === "condivisione") finestra.statoCondivisione = r
            else if (id === "account") { finestra.accountInCorso = false; if (r.account) finestra.account = r.account; if (r.messaggio) finestra.avviso(r.messaggio) }
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
            spacing: 12
            Titolo { text: I18n.t("Il tuo account") }
            Testo { Layout.fillWidth: true; secondario: true; text: I18n.t("Nome e foto compaiono quando accendi il computer e nella schermata di blocco.") }
            Testo {
                Layout.fillWidth: true
                visible: finestra.info.live === true
                text: "ℹ️ " + I18n.t("Nella prova dalla chiavetta l'account è temporaneo: nome e password li scegli durante l'installazione e qui potrai cambiarli al primo avvio.")
            }
            RowLayout {
                spacing: 18
                enabled: !finestra.info.live && !finestra.accountInCorso
                FotoAccount { lato: 84; account: finestra.account }
                ColumnLayout {
                    spacing: 8
                    RowLayout {
                        CampoTesto {
                            id: campoNome
                            Layout.preferredWidth: 260
                            text: finestra.account.nome || ""
                            placeholderText: I18n.t("Nome e cognome")
                            onAccepted: if (text.trim() && text.trim() !== finestra.account.nome) finestra.azioneAccount("accountNome", [text])
                        }
                        Pulsante {
                            text: I18n.t("Salva nome")
                            enabled: campoNome.text.trim() !== "" && campoNome.text.trim() !== finestra.account.nome
                            onClicked: finestra.azioneAccount("accountNome", [campoNome.text])
                        }
                    }
                    RowLayout {
                        Pulsante { text: I18n.t("Scegli una foto…"); icona: "camera-photo"; onClicked: sceltaFoto.open() }
                        Pulsante { text: I18n.t("Togli la foto"); visible: !!finestra.account.foto; onClicked: finestra.azioneAccount("accountTogliFoto", []) }
                    }
                    Testo { secondario: true; text: I18n.t("Nome utente:") + " " + (finestra.account.utente || "") }
                }
            }
            Separatore { Layout.fillWidth: true }
            RigaImpostazione {
                Layout.fillWidth: true
                enabled: !finestra.info.live && !finestra.accountInCorso
                titolo: I18n.t("Chiedi la password")
                descrizione: chiedi.checked ? I18n.t("Serve per entrare all'accensione e per sbloccare lo schermo")
                                            : I18n.t("Per entrare e sbloccare basta premere Invio: chiunque può usare il computer")
                Interruttore {
                    id: chiedi
                    checked: finestra.account.password !== false
                    onToggled: if (!checked && finestra.account.password) finestra.azioneAccount("accountSenzaPassword", [])
                }
            }
            RowLayout {
                visible: chiedi.checked && !finestra.info.live
                enabled: !finestra.accountInCorso
                spacing: 8
                CampoTesto { id: pw1; Layout.preferredWidth: 200; echoMode: TextInput.Password; placeholderText: finestra.account.password ? I18n.t("Nuova password") : I18n.t("Scegli una password") }
                CampoTesto { id: pw2; Layout.preferredWidth: 200; echoMode: TextInput.Password; placeholderText: I18n.t("Ripetila"); onAccepted: imposta.clicked() }
                Pulsante {
                    id: imposta
                    principale: true
                    text: finestra.account.password ? I18n.t("Cambia") : I18n.t("Imposta")
                    enabled: pw1.text.length > 0
                    onClicked: { finestra.azioneAccount("accountPassword", [pw1.text, pw2.text]); pw1.text = ""; pw2.text = "" }
                }
            }
            Testo { Layout.fillWidth: true; visible: !finestra.info.live; secondario: true; text: I18n.t("Puoi cambiare tutto anche dopo, in Impostazioni › Utenti e account.") }
            Item { Layout.fillHeight: true }
            RowLayout {
                Testo { Layout.fillWidth: true; text: I18n.t("Altre persone usano questo computer? Ognuna può avere il proprio account con file e impostazioni separati.") }
                Pulsante { text: I18n.t("Aggiungi un'altra persona"); icona: "list-add-user"; onClicked: ponte.chiama0("utenti") }
            }
        }
    }
    Component {
        id: pSolidID
        ColumnLayout {
            spacing: 14
            Titolo { text: I18n.t("Solid ID") }
            Testo { Layout.fillWidth: true; text: I18n.t("Un solo account per tutti i tuoi dispositivi SolidOS. Con «Dov'è» ritrovi computer e telefoni sulla mappa, li fai suonare o li blocchi con un messaggio se li perdi.") }
            Testo { Layout.fillWidth: true; secondario: true; text: I18n.t("È facoltativo: puoi crearlo o accedere anche più tardi, in Impostazioni › Solid ID.") }
            RowLayout {
                spacing: 10
                Pulsante { principale: true; icona: "avatar-default"; text: I18n.t("Accedi o crea il Solid ID"); onClicked: ponte.chiama0("solidID") }
                Pulsante { text: I18n.t("Più tardi"); onClicked: passi.avanti() }
            }
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
        id: pStile
        ColumnLayout {
            spacing: 16
            Titolo { text: I18n.t("Come preferisci la barra?") }
            Testo { Layout.fillWidth: true; secondario: true; text: I18n.t("Puoi cambiarla quando vuoi in Impostazioni › Barra e Dock.") }
            RowLayout {
                spacing: 24
                Repeater {
                    model: [{ id: "mac", nome: I18n.t("Barra in alto e Dock"), testo: I18n.t("Barra in alto con orologio e menu, Dock in basso") },
                            { id: "windows", nome: I18n.t("Barra unica in basso"), testo: I18n.t("Una barra in basso: S, app, orologio e Wi-Fi a destra") }]
                    ColumnLayout {
                        spacing: 8
                        Rectangle {
                            id: anteprima
                            width: 260; height: 160; radius: 12
                            color: "#2B3550"
                            border.width: finestra.stile === modelData.id ? 3 : 1
                            border.color: finestra.stile === modelData.id ? Tema.accento : Tema.bordo
                            clip: true
                            // finestra di esempio
                            Rectangle { x: 40; y: modelData.id === "mac" ? 34 : 22; width: 150; height: 82; radius: 6; color: "#E9EAEE"
                                Rectangle { width: parent.width; height: 12; radius: 6; color: "#C9CBD2" } }
                            // barra in alto + Dock
                            Rectangle { visible: modelData.id === "mac"; x: 3; y: 3; width: parent.width - 6; height: 12; radius: 9; color: "#CC0C0E14"
                                Rectangle { x: 6; y: 3; width: 6; height: 6; radius: 3; color: "#FFFFFF" }
                                Rectangle { anchors.right: parent.right; anchors.rightMargin: 8; y: 4; width: 34; height: 4; radius: 2; color: "#FFFFFF" } }
                            Rectangle { visible: modelData.id === "mac"; anchors.horizontalCenter: parent.horizontalCenter; y: parent.height - 26; width: 118; height: 20; radius: 7; color: "#B8282A32"
                                Row { anchors.centerIn: parent; spacing: 5; Repeater { model: 6; Rectangle { width: 12; height: 12; radius: 3; color: ["#3B82F6", "#F97316", "#22C55E", "#EAB308", "#8B5CF6", "#9CA3AF"][index] } } } }
                            // una barra in basso
                            Rectangle { visible: modelData.id === "windows"; x: 0; y: parent.height - 22; width: parent.width; height: 22; color: "#F21C1D22"
                                Row { anchors.centerIn: parent; spacing: 5
                                    Rectangle { width: 12; height: 12; radius: 3; color: "#FFFFFF" }
                                    Repeater { model: 5; Rectangle { width: 12; height: 12; radius: 3; color: ["#3B82F6", "#F97316", "#22C55E", "#EAB308", "#9CA3AF"][index] } } }
                                Rectangle { anchors.right: parent.right; anchors.rightMargin: 8; y: 6; width: 40; height: 10; radius: 3; color: "#66FFFFFF" } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { finestra.stile = modelData.id; ponte.chiama("stileBarra", [modelData.id]) } }
                        }
                        Testo { text: modelData.nome; font.weight: Font.DemiBold }
                        Testo { Layout.preferredWidth: 260; secondario: true; wrapMode: Text.Wrap; text: modelData.testo }
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
            Titolo { text: I18n.t("Porta qui i tuoi file") }
            Testo { Layout.fillWidth: true; text: I18n.t("Documenti, foto, musica, sfondo e preferiti del browser dal sistema operativo di prima (anche se è su questo computer), da un disco esterno, dal telefono o da un altro computer.") }
            Pulsante { text: I18n.t("Trasferisci i miei file"); icona: "folder-download"; principale: true; onClicked: ponte.chiama0("migrazione") }
            Testo { secondario: true; text: I18n.t("Puoi farlo anche più tardi: menu S › «Trasferisci file».") }
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
            Testo { Layout.fillWidth: true; text: I18n.t("Scambia file con i telefoni (Quick Share o codice QR) e con altri computer. Chi può vedere questo computer?") }
            Scelta {
                id: vis
                Layout.preferredWidth: 320
                model: [{ testo: I18n.t("Nessuno (consigliato, la attivi quando serve)"), valore: "nessuno" }, { testo: I18n.t("Solo dispositivi associati"), valore: "associati" }, { testo: I18n.t("Tutti per 10 minuti"), valore: "tutti10" }]
            }
            CampoTesto { id: nomeDisp; Layout.preferredWidth: 320; placeholderText: I18n.t("Nome di questo computer, es. «PC di Anna»") }
            Pulsante { text: I18n.t("Salva e verifica la compatibilità"); onClicked: ponte.avvia("condivisione", [vis.currentValue, nomeDisp.text], "condivisione") }
            Repeater {
                model: Object.keys(finestra.statoCondivisione)
                Testo { Layout.fillWidth: true; text: ({ quickshare: "Quick Share", localsend: "LocalSend", qr: "QR" })[modelData] + ": " + (finestra.statoCondivisione[modelData][0] ? "✅ " : "⚠️ ") + finestra.statoCondivisione[modelData][1] }
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

    FileDialog {
        id: sceltaFoto
        title: I18n.t("Scegli la tua foto")
        currentFolder: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
        nameFilters: [I18n.t("Immagini") + " (*.png *.jpg *.jpeg *.webp *.bmp *.heic)"]
        onAccepted: finestra.azioneAccount("accountFoto", [selectedFile.toString()])
    }
}
