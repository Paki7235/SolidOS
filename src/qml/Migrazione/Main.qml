// Trasferisci file: porta qui documenti, foto, musica… da qualsiasi posto, in tre passi.
// 1. Da dove?  (Windows · disco esterno/chiavetta/Mac · telefono · altro computer in rete)
// 2. Cosa?     (le cartelle trovate, già tutte selezionate)
// 3. Fatto     (con il pulsante per aprire i file copiati)
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import SolidUI

Finestra {
    id: finestra
    title: I18n.t("Trasferisci file")
    width: 820
    height: 620
    property int passo: 0
    property var sorgenti: ({ windows: [], dischi: [] })
    property var utenti: []
    property string origine: ""
    property var elementi: []
    property var scelti: ({})
    property var avanzamento: null
    property var esito: null
    property bool occupato: false

    function analizza(percorso, nome) {
        origine = nome
        elementi = []; esito = null
        occupato = true; passo = 1
        ponte.avvia("analizza", [percorso], "elementi")
    }
    function apriWindows(p) {
        occupato = true
        var r = ponte.chiama("apri", [p.percorso])
        occupato = false
        if (!r.ok) { finestra.avviso(r.messaggio || I18n.t("Impossibile aprire il disco")); return }
        if (r.utenti.length === 1) { occupato = true; origine = "Windows · " + r.utenti[0].nome; passo = 1; ponte.avvia("elementi", [r.utenti[0].percorso], "elementi") }
        else { utenti = r.utenti; origine = "Windows"; passo = 4 }
    }
    function scegliDisco(d) {
        var u = ponte.chiama("utentiIn", [d.percorso])
        if (u.length > 1) { utenti = u; origine = d.nome; passo = 4 }
        else analizza(d.percorso, d.nome)
    }

    Component.onCompleted: ponte.avvia("sorgenti", [], "sorgenti")
    Connections {
        target: ponte
        function onEvento(nome, d) { if (nome === "avanzamento") finestra.avanzamento = d }
        function onCompletato(id, r) {
            finestra.occupato = false
            if (id === "sorgenti") finestra.sorgenti = r
            else if (id === "elementi") { finestra.elementi = r; var s = {}; r.forEach(function (e) { s[e.id] = true }); finestra.scelti = s }
            else if (id === "importa") { finestra.esito = r; finestra.avanzamento = null; finestra.passo = 2 }
        }
    }

    FolderDialog {
        id: sceltaCartella
        title: I18n.t("Scegli la cartella da cui prendere i file")
        onAccepted: { var p = selectedFolder.toString().replace("file://", ""); finestra.analizza(decodeURIComponent(p), decodeURIComponent(p.split("/").pop())) }
    }

    // Grande scheda cliccabile del passo 1
    component Sorgente: Rectangle {
        id: sc
        property string icona: ""
        property string titolo: ""
        property string testo: ""
        signal scelta()
        Layout.fillWidth: true
        implicitHeight: 76
        radius: 12
        color: ma.containsMouse ? Qt.lighter(Tema.superficie, Tema.chiaro ? 0.97 : 1.18) : Tema.superficie
        border.color: ma.containsMouse ? Tema.accento : Tema.bordo
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18; anchors.rightMargin: 18
            spacing: 16
            Icona { nome: sc.icona; lato: 36 }
            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true
                Text { text: sc.titolo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.DemiBold }
                Text { text: sc.testo; Layout.fillWidth: true; wrapMode: Text.Wrap; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 12 }
            }
            Text { text: "›"; color: Tema.testoSecondario; font.pixelSize: 22 }
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sc.scelta() }
    }

    StackLayout {
        anchors.fill: parent
        anchors.margins: 26
        currentIndex: finestra.passo === 4 ? 3 : finestra.passo

        // ── 1. Da dove? ──────────────────────────────────────────────────────
        ScrollView {
            contentWidth: availableWidth
            ColumnLayout {
                width: parent.width
                spacing: 12
                Titolo { text: I18n.t("Da dove arrivano i tuoi file?") }
                Testo { secondario: true; Layout.fillWidth: true; text: I18n.t("Scegli e al resto pensiamo noi: troviamo Documenti, Immagini, Musica, Video, Scrivania e Scaricati e li copiamo nelle cartelle giuste. L'originale non viene toccato.") }
                Repeater {
                    model: finestra.sorgenti.windows
                    Sorgente {
                        required property var modelData
                        icona: "drive-harddisk"
                        titolo: I18n.t("Windows su questo computer") + " · " + (modelData.etichetta || modelData.percorso)
                        testo: modelData.dimensione + " GB · " + I18n.t("anche sfondo e preferiti del browser")
                        onScelta: finestra.apriWindows(modelData)
                    }
                }
                Repeater {
                    model: finestra.sorgenti.dischi
                    Sorgente {
                        required property var modelData
                        icona: "drive-removable-media"
                        titolo: modelData.nome
                        testo: I18n.t("Disco esterno, chiavetta o disco di un Mac / di un altro PC")
                        onScelta: finestra.scegliDisco(modelData)
                    }
                }
                Sorgente {
                    icona: "folder-open"
                    titolo: I18n.t("Scegli una cartella…")
                    testo: I18n.t("Un backup, una cartella di rete o di un disco: prendo tutto quello che contiene")
                    onScelta: sceltaCartella.open()
                }
                Sorgente {
                    icona: "phone"
                    titolo: I18n.t("Dal telefono")
                    testo: I18n.t("Android con Quick Share, iPhone inquadrando un codice QR: i file arrivano in Scaricati › Ricevuti")
                    onScelta: ponte.chiama0("apriCondivisione")
                }
                Sorgente {
                    icona: "network-workgroup"
                    titolo: I18n.t("Da un altro computer in rete")
                    testo: I18n.t("Apre la rete in File: entra nelle cartelle condivise e trascina qui quello che ti serve")
                    onScelta: ponte.chiama0("apriRete")
                }
                Testo { visible: finestra.sorgenti.windows.length === 0 && finestra.sorgenti.dischi.length === 0; secondario: true; Layout.fillWidth: true; text: I18n.t("Collega la chiavetta o il disco: comparirà qui da solo.") }
                Timer { interval: 4000; running: finestra.passo === 0; repeat: true; onTriggered: ponte.avvia("sorgenti", [], "sorgenti") }
            }
        }

        // ── 2. Cosa? ─────────────────────────────────────────────────────────
        ColumnLayout {
            spacing: 12
            Titolo { text: I18n.t("Cosa vuoi portare?") }
            Testo { secondario: true; text: I18n.t("Da") + ": " + finestra.origine }
            BarraProgresso { Layout.fillWidth: true; visible: finestra.occupato || finestra.avanzamento !== null; indeterminate: finestra.avanzamento === null; value: finestra.avanzamento ? finestra.avanzamento.fatto / finestra.avanzamento.totale : 0 }
            Testo { visible: !!finestra.avanzamento; secondario: true; text: finestra.avanzamento ? I18n.t("Copia in corso") + ": " + (finestra.avanzamento.nome || "") : ""; elide: Text.ElideMiddle; Layout.fillWidth: true }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: finestra.elementi
                delegate: RigaImpostazione {
                    width: ListView.view.width
                    icona: modelData.tipo === "cartella" ? "folder" : (modelData.tipo === "wifi" ? "network-wireless" : (modelData.tipo === "sfondo" ? "preferences-desktop-wallpaper" : "bookmarks"))
                    titolo: modelData.nome
                    descrizione: modelData.dimensione ? (modelData.dimensione >= 1024 ? (modelData.dimensione / 1024).toFixed(1).replace(".", ",") + " GB" : modelData.dimensione + " MB") : ""
                    Interruttore { checked: true; onToggled: { var s = Object.assign({}, finestra.scelti); s[modelData.id] = checked; finestra.scelti = s } }
                }
                Testo { anchors.centerIn: parent; visible: parent.count === 0 && !finestra.occupato; secondario: true; text: I18n.t("Qui non ho trovato file da portare") }
            }
            RowLayout {
                Pulsante { text: I18n.t("Indietro"); enabled: !finestra.occupato; onClicked: { finestra.passo = 0; finestra.elementi = [] } }
                Item { Layout.fillWidth: true }
                Pulsante {
                    principale: true
                    text: I18n.t("Trasferisci")
                    enabled: finestra.elementi.some(function (e) { return finestra.scelti[e.id] }) && !finestra.occupato
                    onClicked: {
                        finestra.occupato = true
                        ponte.avvia("importa", [finestra.elementi.filter(function (e) { return finestra.scelti[e.id] })], "importa")
                    }
                }
            }
        }

        // ── 3. Fatto ─────────────────────────────────────────────────────────
        ColumnLayout {
            spacing: 14
            Item { Layout.fillHeight: true }
            Icona { Layout.alignment: Qt.AlignHCenter; nome: "emblem-ok-symbolic"; lato: 64 }
            Titolo { Layout.alignment: Qt.AlignHCenter; text: I18n.t("Fatto!") }
            Testo { Layout.alignment: Qt.AlignHCenter; horizontalAlignment: Text.AlignHCenter; text: finestra.esito ? finestra.esito.riepilogo.join("\n") : "" }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10
                Pulsante { principale: true; text: I18n.t("Apri i documenti"); onClicked: ponte.chiama("apriCartella", ["DOCUMENTS"]) }
                Pulsante { text: I18n.t("Trasferisci altro"); onClicked: { finestra.passo = 0; finestra.esito = null } }
            }
            Item { Layout.fillHeight: true }
        }

        // ── (1b) Quale utente? ───────────────────────────────────────────────
        ColumnLayout {
            spacing: 12
            Titolo { text: I18n.t("Di chi sono i file?") }
            Testo { secondario: true; text: I18n.t("Su") + " " + finestra.origine + " " + I18n.t("ci sono più account: scegli il tuo.") }
            Repeater {
                model: finestra.utenti
                Sorgente {
                    required property var modelData
                    icona: "user-info"
                    titolo: modelData.nome
                    testo: modelData.percorso
                    onScelta: finestra.analizza(modelData.percorso, finestra.origine + " · " + modelData.nome)
                }
            }
            Item { Layout.fillHeight: true }
            Pulsante { text: I18n.t("Indietro"); onClicked: finestra.passo = 0 }
        }
    }
}
