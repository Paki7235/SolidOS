"""App Impostazioni: un pannello per ogni area del sistema, con ricerca."""

from .pannelli_account import PannelloSolidID
from .pannelli_aspetto import (PannelloAccessibilita, PannelloAspetto, PannelloNotifiche,
                               PannelloPannello, PannelloSpazi)
from .pannelli_dispositivi import (PannelloArchiviazione, PannelloAudio, PannelloEnergia,
                                   PannelloMouse, PannelloSchermo, PannelloStampanti,
                                   PannelloTastiera)
from .pannelli_rete import PannelloBluetooth, PannelloCondivisione, PannelloRete
from .pannelli_sistema import (PannelloAggiornamenti, PannelloAppPredefinite, PannelloDataOra,
                               PannelloInformazioni, PannelloLingua, PannelloPrivacy,
                               PannelloSicurezza, PannelloSnapshot, PannelloUtenti)

PANNELLI = [
    PannelloSolidID,
    PannelloRete, PannelloBluetooth, PannelloCondivisione,
    PannelloSchermo, PannelloAudio, PannelloEnergia, PannelloTastiera, PannelloMouse, PannelloStampanti,
    PannelloAspetto, PannelloPannello, PannelloNotifiche, PannelloSpazi, PannelloAccessibilita,
    PannelloUtenti, PannelloPrivacy, PannelloSicurezza, PannelloAggiornamenti, PannelloSnapshot,
    PannelloAppPredefinite, PannelloLingua, PannelloDataOra, PannelloArchiviazione, PannelloInformazioni,
]
