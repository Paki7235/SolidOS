#!/usr/bin/python3
"""Primo aggiornamento per i PC SolidOS installati PRIMA che esistessero gli aggiornamenti
di SolidOS (build 72 o precedenti): quei sistemi non hanno ancora il programma che li cerca.

Da eseguire una volta sola, come amministratore, sul PC da aggiornare:

    sudo python3 -c "import urllib.request as u; exec(u.urlopen('https://raw.githubusercontent.com/Paki7235/SolidOS/main/scripts/primo-aggiornamento.py').read())"

Cosa fa:
1. scarica la scheda dell'ultima versione e il suo pacchetto, e controlla la somma SHA-256;
2. dal pacchetto copia solo il necessario per aggiornarsi (il programma degli aggiornamenti,
   la chiave pubblica di SolidOS e l'indirizzo degli aggiornamenti);
3. avvia quel programma, che verifica la FIRMA della scheda, crea un punto di ripristino e
   installa tutta la nuova versione. Dalla volta dopo basta Impostazioni › Aggiornamenti.
"""

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path

URL = "https://github.com/Paki7235/SolidOS/releases/download/aggiornamento"
NECESSARI = {
    "./usr/lib/python3/dist-packages/nucleo/aggiornamento.py",
    "./usr/libexec/nucleo/aggiorna-solidos",
    "./usr/share/nucleo/chiave-aggiornamenti.pem",
    "./usr/share/nucleo/branding.env",
}


def scarica(nome: str, dest: Path | None = None) -> bytes:
    richiesta = urllib.request.Request(f"{URL}/{nome}", headers={"User-Agent": "SolidOS-PrimoAggiornamento"})
    with urllib.request.urlopen(richiesta, timeout=120) as r:
        if dest is None:
            return r.read()
        with open(dest, "wb") as f:
            shutil.copyfileobj(r, f)
    return b""


def principale() -> int:
    if os.geteuid() != 0:
        print("Serve l'amministratore: scrivi il comando con «sudo» davanti.")
        return 1
    print("1/3  Leggo l'ultima versione di SolidOS…")
    scheda = json.loads(scarica("versione.json"))
    nome = str(scheda["file"])
    if "/" in nome or not nome.endswith(".tar.xz"):
        print("Scheda non valida.")
        return 1
    with tempfile.TemporaryDirectory(prefix="primo-aggiornamento-") as cartella:
        pacchetto = Path(cartella) / nome
        print(f"2/3  Scarico la versione {scheda['versione']} per prendere il programma degli aggiornamenti…")
        scarica(nome, pacchetto)
        if hashlib.sha256(pacchetto.read_bytes()).hexdigest() != str(scheda["sha256"]).lower():
            print("Il file scaricato è danneggiato: riprova più tardi.")
            return 1
        with tarfile.open(pacchetto) as t:
            for m in t.getmembers():
                if m.name in NECESSARI and m.isfile():
                    destinazione = Path("/") / m.name.lstrip("./")
                    destinazione.parent.mkdir(parents=True, exist_ok=True)
                    with t.extractfile(m) as sorgente:
                        destinazione.write_bytes(sorgente.read())
                    destinazione.chmod(0o755 if "libexec" in m.name else 0o644)
    print("3/3  Installo la nuova versione (prima viene creato un punto di ripristino)…")
    r = subprocess.run(["/usr/libexec/nucleo/aggiorna-solidos", "--forza"])
    if r.returncode == 0:
        print("\nFatto. Riavvia il computer per usare la nuova versione.")
        print("Da ora gli aggiornamenti arrivano da soli: Impostazioni › Aggiornamenti › Aggiornamento software.")
    return r.returncode


if __name__ == "__main__" or __name__ == "builtins":
    sys.exit(principale())
