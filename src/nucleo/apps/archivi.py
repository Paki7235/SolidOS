"""Archivi: apri, estrai e crea archivi (sostituisce LXQt Archiver).

zip e tar (anche .gz .bz2 .xz) con la libreria di Python; 7z, rar e iso con «7z» se installato.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import tarfile
import zipfile
from pathlib import Path

from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app


def _tipo(p: Path) -> str:
    nome = p.name.lower()
    if nome.endswith(".zip") or zipfile.is_zipfile(p):
        return "zip"
    if any(nome.endswith(e) for e in (".tar", ".tar.gz", ".tgz", ".tar.bz2", ".tbz2", ".tar.xz", ".txz")) or tarfile.is_tarfile(p):
        return "tar"
    return "7z"


def _sicuro(dest: Path, nome: str) -> bool:
    """Impedisce che un archivio scriva fuori dalla cartella di destinazione."""
    return (dest / nome).resolve().is_relative_to(dest.resolve())


class BackendArchivi(Backend):
    def fileIniziale(self) -> str:
        argomenti = [a for a in sys.argv[1:] if not a.startswith("-")]
        return str(Path(argomenti[0]).resolve()) if argomenti else ""

    def contenuto(self, percorso: str) -> dict:
        p = Path(percorso.replace("file://", ""))
        try:
            tipo = _tipo(p)
            if tipo == "zip":
                with zipfile.ZipFile(p) as z:
                    voci = [{"nome": i.filename, "dimensione": i.file_size, "cartella": i.is_dir()} for i in z.infolist()]
            elif tipo == "tar":
                with tarfile.open(p) as t:
                    voci = [{"nome": m.name, "dimensione": m.size, "cartella": m.isdir()} for m in t.getmembers()]
            else:
                if not shutil.which("7z"):
                    return {"ok": False, "errore": "Per questo formato serve 7-Zip (installalo dallo Store)"}
                out = subprocess.run(["7z", "l", "-slt", "-ba", str(p)], capture_output=True, text=True, timeout=60).stdout
                voci, voce = [], {}
                for riga in out.splitlines() + [""]:
                    if not riga.strip():
                        if "Path" in voce:
                            voci.append({"nome": voce["Path"], "dimensione": int(voce.get("Size") or 0),
                                         "cartella": voce.get("Folder") == "+"})
                        voce = {}
                    elif " = " in riga:
                        k, v = riga.split(" = ", 1)
                        voce[k] = v
        except (OSError, zipfile.BadZipFile, tarfile.TarError, subprocess.TimeoutExpired) as e:
            return {"ok": False, "errore": str(e)}
        return {"ok": True, "nome": p.name, "voci": voci[:5000], "totale": len(voci),
                "dimensione": sum(v["dimensione"] for v in voci)}

    def estrai(self, percorso: str, destinazione: str = "") -> dict:
        p = Path(percorso.replace("file://", ""))
        base = p.name
        for est in (".tar.gz", ".tar.bz2", ".tar.xz", ".tgz", ".tbz2", ".txz", ".zip", ".tar", ".7z", ".rar", ".iso"):
            if base.lower().endswith(est):
                base = base[: -len(est)]
                break
        dest = Path(destinazione.replace("file://", "")) if destinazione else p.parent / base
        n = 2
        while not destinazione and dest.exists():
            dest = p.parent / f"{base} ({n})"
            n += 1
        dest.mkdir(parents=True, exist_ok=True)
        try:
            tipo = _tipo(p)
            if tipo == "zip":
                with zipfile.ZipFile(p) as z:
                    for nome in z.namelist():
                        if _sicuro(dest, nome):
                            z.extract(nome, dest)
            elif tipo == "tar":
                with tarfile.open(p) as t:
                    t.extractall(dest, filter="data")
            else:
                r = subprocess.run(["7z", "x", "-y", f"-o{dest}", str(p)], capture_output=True, text=True)
                if r.returncode != 0:
                    return {"ok": False, "errore": r.stderr.strip()[-300:] or "estrazione non riuscita"}
        except (OSError, zipfile.BadZipFile, tarfile.TarError) as e:
            return {"ok": False, "errore": str(e)}
        return {"ok": True, "cartella": str(dest)}

    def comprimi(self, indirizzi) -> dict:
        """Crea «Archivio.zip» accanto al primo file con tutti i file trascinati."""
        file = [Path(str(u).replace("file://", "")) for u in indirizzi]
        file = [f for f in file if f.exists()]
        if not file:
            return {"ok": False, "errore": "nessun file"}
        nome = file[0].stem if len(file) == 1 else "Archivio"
        dest = file[0].parent / f"{nome}.zip"
        n = 2
        while dest.exists():
            dest = file[0].parent / f"{nome} ({n}).zip"
            n += 1
        with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as z:
            for f in file:
                if f.is_dir():
                    for sotto in f.rglob("*"):
                        z.write(sotto, sotto.relative_to(f.parent))
                else:
                    z.write(f, f.name)
        return {"ok": True, "percorso": str(dest)}

    def mostra(self, percorso: str) -> None:
        from ..sistema import avvia

        avvia(["pcmanfm-qt", percorso])


def main() -> int:
    return esegui_app("archivi", "Archivi/Main.qml", lambda app: {"ponte": crea_ponte(BackendArchivi())})


if __name__ == "__main__":
    sys.exit(main())
