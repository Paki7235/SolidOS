"""Montaggio automatico delle unità esterne tramite UDisks2 (bus di sistema).

Quando compare un file system su un'unità rimovibile o USB:
- lo monta (NTFS con ntfs3, HFS+ e APFS in sola lettura secondo udisks2.conf);
- se NTFS è «sporco» (l'altro sistema in ibernazione/avvio rapido) riprova in sola lettura e lo spiega;
- mostra una notifica con «Apri».
Le partizioni cifrate (LUKS, BitLocker) vengono segnalate: lo sblocco si fa dal file manager o da Dischi.
"""

from __future__ import annotations

import dbus

from ..i18n import T
from ..sistema import avvia, notifica

UD = "org.freedesktop.UDisks2"
IF_BLOCK = "org.freedesktop.UDisks2.Block"
IF_FS = "org.freedesktop.UDisks2.Filesystem"
IF_DRIVE = "org.freedesktop.UDisks2.Drive"


class Automount:
    def __init__(self):
        self.bus = dbus.SystemBus()
        self.bus.add_signal_receiver(self._aggiunto, signal_name="InterfacesAdded",
                                     dbus_interface="org.freedesktop.DBus.ObjectManager", bus_name=UD)

    def _proprieta(self, percorso, interfaccia):
        oggetto = self.bus.get_object(UD, percorso)
        return oggetto.GetAll(interfaccia, dbus_interface="org.freedesktop.DBus.Properties")

    def _esterno(self, blocco: dict) -> bool:
        if blocco.get("HintIgnore") or blocco.get("HintSystem", True) and not blocco.get("HintAuto", False):
            return False
        try:
            drive = self._proprieta(blocco["Drive"], IF_DRIVE)
        except dbus.exceptions.DBusException:
            return False
        return bool(drive.get("Removable") or drive.get("MediaRemovable") or
                    str(drive.get("ConnectionBus", "")) in ("usb", "sdio", "ieee1394"))

    def _aggiunto(self, percorso, interfacce):
        if IF_BLOCK not in interfacce:
            return
        blocco = interfacce[IF_BLOCK]
        etichetta = str(blocco.get("IdLabel", "")) or T("Unità esterna")
        tipo = str(blocco.get("IdType", ""))
        if not self._esterno(blocco):
            return
        if tipo in ("crypto_LUKS", "BitLocker"):
            notifica(T("Unità cifrata collegata"), T("Apri «Dischi» o il file manager per sbloccarla con la password o la chiave di ripristino."),
                     icona="drive-removable-media")
            return
        if IF_FS not in interfacce:
            return
        self._monta(percorso, etichetta, tipo)

    def _monta(self, percorso, etichetta, tipo):
        fs = dbus.Interface(self.bus.get_object(UD, percorso), IF_FS)

        def riuscito(punto):
            avvia_apri = str(punto)
            notifica(T("{e} collegata", e=etichetta), T("Pronta all'uso in {p}", p=avvia_apri), icona="drive-removable-media")

        def fallito(errore):
            messaggio = str(errore)
            if tipo == "ntfs" and ("dirty" in messaggio or "hibernat" in messaggio.lower() or "wrong fs" in messaggio):
                fs.Mount({"options": "ro"}, reply_handler=lambda p: notifica(
                    T("{e} aperta in sola lettura", e=etichetta),
                    T("L'altro sistema operativo su questo disco non è stato spento del tutto (ibernazione o «avvio rapido»). "
                      "Per scrivere sul disco, spegnilo tenendo premuto Maiusc mentre scegli Arresta."), icona="dialog-warning"),
                    error_handler=lambda e: None)
            elif "NotAuthorized" not in messaggio and "AlreadyMounted" not in messaggio:
                notifica(T("Impossibile aprire {e}", e=etichetta), messaggio[:200], icona="dialog-error")

        fs.Mount({"auth.no_user_interaction": dbus.Boolean(True)}, reply_handler=riuscito, error_handler=fallito)


def avvia_automount() -> Automount | None:
    try:
        return Automount()
    except dbus.exceptions.DBusException:
        return None
