#!/usr/bin/env bash
# Controlli statici del progetto (non richiedono la build):
# sintassi Python e shell, modelli del branding, XML, TOML, registro delle app,
# file QML richiamati dal codice, chiavi dei pannelli. Uscita ≠ 0 se qualcosa non va.
set -uo pipefail
RADICE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$RADICE"
ERRORI=0
ok() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
ko() { printf '  \033[31m✗\033[0m %s\n' "$*"; ERRORI=$((ERRORI + 1)); }

echo "1. Python"
n=0
while IFS= read -r -d '' f; do
	n=$((n + 1))
	python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read(), sys.argv[1])" "$f" 2>/dev/null || ko "sintassi: $f"
done < <(find src -name '*.py' -print0)
python3 -c "import ast; ast.parse(open('src/libexec/helper').read())" || ko "sintassi: src/libexec/helper"
find src -name __pycache__ -type d -exec rm -rf {} + 2>/dev/null
ok "$n file Python"

echo "2. Shell"
for f in build.sh test-vm.sh scripts/*.sh scripts/lib/*.sh; do bash -n "$f" || ko "$f"; done
for f in src/libexec/*; do
	[ -f "$f" ] || continue
	head -1 "$f" | grep -q python && continue
	sh -n "$f" || ko "$f"
done
ok "script shell"

echo "3. Albero di build con il branding"
TMP=$(mktemp -d)
if scripts/genera-branding.sh "$TMP/albero" --senza-immagini >/dev/null; then
	ok "modelli elaborati"
	rimasti=$(grep -rIl --exclude='*.py' --exclude='*.toml' --exclude=branding.env '@[A-Z][A-Z0-9_]*@' "$TMP/albero" || true)
	for f in $rimasti; do
		grep -qE '@DEFAULT_AUDIO_(SINK|SOURCE)@' "$f" && ! grep -vE '@DEFAULT_AUDIO_(SINK|SOURCE)@' "$f" | grep -qE '@[A-Z][A-Z0-9_]*@' && continue
		ko "segnaposto non sostituito in ${f#"$TMP"/albero/}"
	done
	for f in $(find "$TMP/albero" -name '*.xml' -o -name '*.policy' -o -name '*.svg' -o -name 'local.conf'); do
		python3 -c "import sys, xml.dom.minidom as m; m.parse(sys.argv[1])" "$f" 2>/dev/null || ko "XML non valido: ${f#"$TMP"/albero/}"
	done
	ok "XML"
	for f in "$TMP"/albero/config/hooks/normal/* "$TMP"/albero/config/includes.chroot/usr/bin/* "$TMP"/albero/config/includes.chroot/usr/libexec/*/*; do
		head -1 "$f" | grep -q python && continue
		sh -n "$f" 2>/dev/null || bash -n "$f" 2>/dev/null || ko "shell: ${f#"$TMP"/albero/}"
	done
	ok "script generati"
	n_app=$(ls "$TMP"/albero/config/includes.chroot/usr/bin | wc -l | tr -d ' ')
	ok "$n_app comandi in /usr/bin"
else
	ko "generazione dell'albero non riuscita"
fi
rm -rf "$TMP"

echo "4. TOML e JSON"
python3 - <<'PY' || ERRORI=$((ERRORI + 1))
import glob, json, sys, tomllib
errori = 0
for f in glob.glob("src/dati/**/*.toml", recursive=True):
    try:
        tomllib.load(open(f, "rb"))
    except Exception as e:
        print(f"  ✗ {f}: {e}"); errori += 1
for f in glob.glob("src/dati/**/*.json", recursive=True):
    try:
        json.load(open(f))
    except Exception as e:
        print(f"  ✗ {f}: {e}"); errori += 1
print("  ✓ dati validi" if not errori else "")
sys.exit(1 if errori else 0)
PY

echo "5. Registro delle app e file QML"
python3 - <<'PY' || ERRORI=$((ERRORI + 1))
import pathlib, re, sys
errori = 0
for riga in open("src/app.tsv", encoding="utf-8"):
    if not riga.strip() or riga.startswith("#"):
        continue
    campi = riga.rstrip("\n").split("\t")
    modulo = campi[1]
    percorso = pathlib.Path("src") / modulo.replace(".", "/")
    if not (percorso.with_suffix(".py").exists() or (percorso / "__main__.py").exists()):
        print(f"  ✗ modulo mancante per «{campi[0]}»: {modulo}"); errori += 1
for f in pathlib.Path("src/nucleo").rglob("*.py"):
    for qml in re.findall(r'"([A-Za-z]+/[A-Za-z]+\.qml)"', f.read_text(encoding="utf-8")):
        if not (pathlib.Path("src/qml") / qml).exists():
            print(f"  ✗ {f}: QML mancante {qml}"); errori += 1
componenti = {p.stem for p in pathlib.Path("src/qml/SolidUI").glob("*.qml")}
dichiarati = {r.split()[0] for r in open("src/qml/SolidUI/qmldir") if r[0].isupper()}
if componenti != dichiarati:
    print(f"  ✗ qmldir di SolidUI non allineato: {componenti ^ dichiarati}"); errori += 1
# Id QML duplicati nello stesso file: il file non si carica affatto
for qml in sorted(pathlib.Path("src/qml").rglob("*.qml")):
    ids = re.findall(r"(?:^|[{;])\s*id:\s*(\w+)", qml.read_text(encoding="utf-8"), re.M)
    doppi = sorted({i for i in ids if ids.count(i) > 1})
    if doppi:
        print(f"  ✗ {qml}: id ripetuti {', '.join(doppi)}"); errori += 1
print("  ✓ moduli, QML e qmldir coerenti" if not errori else "")
sys.exit(1 if errori else 0)
PY

echo "6. QML (se qmllint è disponibile)"
if command -v qmllint >/dev/null; then
	find src/qml -name '*.qml' -print0 | xargs -0 qmllint -I src/qml >/dev/null 2>&1 && ok "qmllint" || ko "qmllint ha segnalato problemi"
else
	echo "  - qmllint non installato: controllo saltato (eseguito nella build)"
fi

echo
if [ "$ERRORI" -eq 0 ]; then echo "Tutti i controlli superati."; else echo "Problemi trovati: $ERRORI"; fi
exit $((ERRORI > 0))
