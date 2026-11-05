// Modalità Salvataggio: procedura guidata per riparare e recuperare.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Salvataggio")
    width: 1000
    height: 700
    visibility: Window.Maximized
    property var partizioni: ponte.chiama0("partizioni")
    property var aperta: null
    property var cartelle: []
    property var scelte: ({})
    property var avanzamento: null
    property string occupato: ""

    function sorgentiScelte() { var s = []; for (var k in scelte) if (scelte[k]) s.push(k); return s }
    Connections {
        target: ponte
        function onEvento(nome, dati) { if (nome === "avanzamento") finestra.avanzamento = dati }
        function onCompletato(id, r) {
            finestra.occupato = ""
            finestra.avanzamento = null
            if (id === "copia") esitoCopia.mostra(r)
            else if (id === "salute") esitoSalute.mostra(r)
            else if (id === "utentiWindows") { if (r.ok) utentiWin.model = r.utenti; else finestra.avviso(r.messaggio) }
            else finestra.avviso(r.messaggio || (r.ok ? I18n.t("Fatto") : I18n.t("Operazione non riuscita")))
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Barra {
            Layout.fillWidth: true
            titolo: I18n.t("Salvataggio") + " — " + I18n.t("ripara e recupera il tuo computer")
            Pulsante { text: I18n.t("Riavvia"); icona: "system-reboot"; onClicked: ponte.chiama0("riavvia") }
        }
        TabBar {
            id: schede
            Layout.fillWidth: true
            TabButton { text: I18n.t("Recupera file") }
            TabButton { text: I18n.t("Controlla disco e memoria") }
            TabButton { text: I18n.t("Clona disco") }
            TabButton { text: I18n.t("Password di Windows") }
        }
        BarraProgresso {
            Layout.fillWidth: true
            visible: finestra.occupato !== "" || finestra.avanzamento !== null
            indeterminate: finestra.avanzamento === null
            value: finestra.avanzamento ? finestra.avanzamento.fatto / finestra.avanzamento.totale : 0
        }
        Testo { Layout.leftMargin: 16; visible: text !== ""; text: finestra.avanzamento ? finestra.avanzamento.nome : finestra.occupato }

        StackLayout {
            currentIndex: schede.currentIndex
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 16

            // ── Recupera file ────────────────────────────────────────────
            RowLayout {
                spacing: 16
                ColumnLayout {
                    Layout.preferredWidth: 340
                    Layout.fillHeight: true
                    Titolo { livello: 3; text: "1. " + I18n.t("Scegli il disco di Windows") }
                    ListView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 200
                        clip: true
                        model: finestra.partizioni
                        delegate: VoceElenco {
                            width: ListView.view.width
                            icona: modelData.bitlocker ? "security-high" : "drive-harddisk"
                            titolo: (modelData.etichetta || modelData.percorso) + " · " + modelData.dimensione + " GB"
                            sottotitolo: modelData.bitlocker ? I18n.t("Cifrato con BitLocker: serve la chiave di ripristino") : "NTFS"
                            onClicked: {
                                if (modelData.bitlocker) { bitlocker.percorso = modelData.percorso; bitlocker.open(); return }
                                var r = ponte.chiama("apri", [modelData.percorso])
                                if (r.ok) finestra.aperta = r; else finestra.avviso(r.messaggio)
                            }
                        }
                    }
                    Pulsante { text: I18n.t("Aggiorna elenco"); onClicked: finestra.partizioni = ponte.chiama0("partizioni") }
                    Titolo { livello: 3; text: "2. " + I18n.t("Scegli l'utente"); visible: finestra.aperta !== null }
                    Repeater {
                        model: finestra.aperta ? finestra.aperta.utenti : []
                        VoceElenco {
                            Layout.fillWidth: true
                            icona: "user-identity"
                            titolo: modelData.nome
                            onClicked: { finestra.occupato = I18n.t("Calcolo delle dimensioni…"); ponte.avvia("cartelle", [modelData.percorso], "cartelle-" + index) }
                        }
                    }
                    Connections {
                        target: ponte
                        function onCompletato(id, r) { if (id.indexOf("cartelle-") === 0) finestra.cartelle = r }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Titolo { livello: 3; text: "3. " + I18n.t("Cosa vuoi salvare?") }
                    Repeater {
                        model: finestra.cartelle
                        RigaImpostazione {
                            Layout.fillWidth: true
                            titolo: modelData.nome
                            descrizione: modelData.dimensione + " MB"
                            Interruttore { onToggled: { var s = finestra.scelte; s[modelData.percorso] = checked; finestra.scelte = s } }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Titolo { livello: 3; text: "4. " + I18n.t("Dove?") }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: ponte.chiama0("destinazioni")
                            Pulsante {
                                text: I18n.t("Copia su") + " " + modelData.nome
                                icona: "drive-removable-media"
                                enabled: finestra.sorgentiScelte().length > 0
                                onClicked: { finestra.occupato = I18n.t("Copia in corso…"); ponte.avvia("copia", [finestra.sorgentiScelte(), modelData.percorso], "copia") }
                            }
                        }
                        Pulsante {
                            principale: true
                            text: I18n.t("Invia al telefono")
                            icona: "document-send"
                            enabled: finestra.sorgentiScelte().length > 0
                            onClicked: ponte.chiama("inviaTelefono", [finestra.sorgentiScelte()])
                        }
                    }
                    Testo { secondario: true; Layout.fillWidth: true; text: I18n.t("Collega una chiavetta o un disco esterno per copiare i file, oppure inviali al telefono con Condivisione Vicina (anche solo con un codice QR).") }
                }
            }

            // ── Diagnosi ─────────────────────────────────────────────────
            ColumnLayout {
                spacing: 12
                Titolo { livello: 3; text: I18n.t("Salute dei dischi") }
                Repeater {
                    model: ponte.chiama0("dischi")
                    RigaImpostazione {
                        Layout.fillWidth: true
                        icona: "drive-harddisk"
                        titolo: modelData.modello
                        descrizione: modelData.percorso + " · " + modelData.dimensione + " GB"
                        Pulsante { text: I18n.t("Controlla"); onClicked: { finestra.occupato = I18n.t("Lettura dei dati SMART…"); ponte.avvia("salute", [modelData.percorso], "salute") } }
                    }
                }
                Separatore { Layout.fillWidth: true }
                Titolo { livello: 3; text: I18n.t("Memoria (RAM)") }
                RigaImpostazione {
                    Layout.fillWidth: true
                    titolo: I18n.t("Test rapido della memoria")
                    descrizione: I18n.t("Prova 256 MB senza riavviare (qualche minuto)")
                    Pulsante { text: I18n.t("Avvia"); onClicked: { finestra.occupato = I18n.t("Test della memoria in corso…"); ponte.avvia("testRam", [256], "ram") } }
                }
                Testo { secondario: true; Layout.fillWidth: true; text: I18n.t("Per un test completo riavvia e scegli «Test della memoria (RAM)» nel menu di avvio.") }
                Item { Layout.fillHeight: true }
            }

            // ── Clona ────────────────────────────────────────────────────
            ColumnLayout {
                spacing: 12
                Testo { Layout.fillWidth: true; text: I18n.t("Copia un intero disco su un altro, anche se ha settori danneggiati. Il disco di destinazione verrà completamente sovrascritto.") }
                RowLayout {
                    Testo { text: I18n.t("Da:") }
                    Scelta { id: da; model: ponte.chiama0("dischi").map(function (d) { return { testo: d.modello + " (" + d.dimensione + " GB)", valore: d.percorso } }) }
                    Testo { text: I18n.t("A:") }
                    Scelta { id: a; model: da.model }
                }
                Pulsante {
                    pericoloso: true
                    text: I18n.t("Clona")
                    enabled: da.currentValue !== a.currentValue
                    onClicked: confermaClona.open()
                }
                Item { Layout.fillHeight: true }
            }

            // ── Password Windows ─────────────────────────────────────────
            ColumnLayout {
                spacing: 12
                Testo { Layout.fillWidth: true; text: I18n.t("Rimuove la password di un account LOCALE di Windows, per entrare di nuovo nel tuo computer. Non funziona con gli account Microsoft (email) né con dischi cifrati senza chiave. Usalo solo sui tuoi account.") }
                RowLayout {
                    Scelta { id: partWin; model: finestra.partizioni.filter(function (p) { return !p.bitlocker }).map(function (p) { return { testo: (p.etichetta || p.percorso) + " (" + p.dimensione + " GB)", valore: p.percorso } }) }
                    Pulsante { text: I18n.t("Mostra gli account"); onClicked: { finestra.occupato = "…"; ponte.avvia("utentiWindows", [partWin.currentValue], "utentiWindows") } }
                }
                ListView {
                    id: utentiWin
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: []
                    delegate: RigaImpostazione {
                        width: ListView.view.width
                        icona: "user-identity"
                        titolo: modelData
                        Pulsante { text: I18n.t("Rimuovi password"); onClicked: { finestra.occupato = "…"; ponte.avvia("resetPassword", [partWin.currentValue, modelData], "password") } }
                    }
                }
            }
        }
    }

    Dialog {
        id: bitlocker
        property string percorso: ""
        title: I18n.t("Chiave di ripristino BitLocker")
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Cancel | Dialog.Ok
        ColumnLayout {
            Testo { text: I18n.t("La trovi su account.microsoft.com/devices/recoverykey (48 cifre)."); Layout.maximumWidth: 420 }
            CampoTesto { id: chiaveBl; Layout.preferredWidth: 420; placeholderText: "000000-000000-…" }
        }
        onAccepted: {
            var r = ponte.chiama("sblocca", [percorso, chiaveBl.text])
            if (!r.ok) { finestra.avviso(r.messaggio || I18n.t("Chiave non valida")); return }
            var a = ponte.chiama("apri", [r.dispositivo])
            if (a.ok) finestra.aperta = a; else finestra.avviso(a.messaggio)
        }
    }
    Dialog {
        id: confermaClona
        title: I18n.t("Sei sicuro?")
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Cancel | Dialog.Ok
        Testo { text: I18n.t("Tutto il contenuto del disco di destinazione verrà cancellato."); color: Tema.pericolo }
        onAccepted: { finestra.occupato = I18n.t("Clonazione in corso: può richiedere ore"); ponte.avvia("clona", [da.currentValue, a.currentValue], "clona") }
    }
    Dialog {
        id: esitoCopia
        function mostra(r) { testoCopia.text = I18n.t("File copiati:") + " " + r.copiati + (r.errori ? "\n" + I18n.t("File illeggibili saltati:") + " " + r.errori : "") + "\n" + r.cartella; open() }
        title: I18n.t("Recupero completato")
        anchors.centerIn: parent
        standardButtons: Dialog.Ok
        Testo { id: testoCopia }
    }
    Dialog {
        id: esitoSalute
        function mostra(r) {
            testoSalute.text = !r.ok ? r.messaggio : ((r.superato ? "✅ " + I18n.t("Il disco è in buona salute") : "⚠️ " + I18n.t("Il disco segnala un guasto: recupera subito i file")) +
                "\n" + I18n.t("Ore di accensione") + ": " + (r.ore || "?") + "\n" + I18n.t("Settori riallocati") + ": " + r.settoriRiallocati +
                "\n" + I18n.t("Settori in sospeso") + ": " + r.settoriInSospeso)
            open()
        }
        title: I18n.t("Salute del disco")
        anchors.centerIn: parent
        standardButtons: Dialog.Ok
        Testo { id: testoSalute }
    }
}
