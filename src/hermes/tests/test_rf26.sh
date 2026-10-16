#!/usr/bin/env bash
set -u

DATA="$HOME/.local/share/hermes/data/jobs.json"
ITERACIONES="${1:-10}"
FALLOS=0

if ! command -v hermes >/dev/null 2>&1; then
    echo "ERROR: hermes no está en PATH."
    exit 1
fi

for ((i = 1; i <= ITERACIONES; i++)); do
    echo
    echo "=== Prueba $i/$ITERACIONES ==="

    SALIDA="$(hermes job sleep 60 2>&1)"
    echo "$SALIDA"

    ID="$(printf '%s\n' "$SALIDA" | sed -n 's/^job ID: *//p' | head -n 1)"
    if [[ -z "$ID" ]]; then
        echo "FALLO: no se pudo obtener el ID del trabajo."
        FALLOS=$((FALLOS + 1))
        continue
    fi

    # Dar tiempo al scheduler para reclamar el trabajo.
    sleep 0.3

    TMP1="$(mktemp)"
    TMP2="$(mktemp)"

    hermes cancel "$ID" >"$TMP1" 2>&1 &
    P1=$!
    hermes cancel "$ID" >"$TMP2" 2>&1 &
    P2=$!

    wait "$P1"; RC1=$?
    wait "$P2"; RC2=$?

    echo "--- Respuesta 1 (código $RC1) ---"
    cat "$TMP1"
    echo "--- Respuesta 2 (código $RC2) ---"
    cat "$TMP2"

    rm -f "$TMP1" "$TMP2"

    # Esperar hasta 8 segundos por el estado terminal.
    ESTADO=""
    for ((j = 1; j <= 40; j++)); do
        ESTADO="$(python3 - "$DATA" "$ID" <<'PY'
import json
import sys

path, wanted_id = sys.argv[1], int(sys.argv[2])
try:
    with open(path, encoding="utf-8") as f:
        jobs = json.load(f)
    job = next((x for x in jobs if int(x.get("job_id", -1)) == wanted_id), None)
    print(job.get("status", "SIN_ESTADO") if job else "NO_ENCONTRADO")
except Exception as e:
    print("JSON_INVALIDO")
    print(str(e), file=sys.stderr)
    sys.exit(2)
PY
)"
        case "$ESTADO" in
            CANCELED|SUCCEEDED|FAILED) break ;;
        esac
        sleep 0.2
    done

    echo "Estado final del job $ID: $ESTADO"

    if [[ "$ESTADO" != "CANCELED" ]]; then
        echo "FALLO: se esperaba CANCELED."
        FALLOS=$((FALLOS + 1))
    fi

    if ! python3 -m json.tool "$DATA" >/dev/null 2>&1; then
        echo "FALLO: jobs.json no es JSON válido."
        FALLOS=$((FALLOS + 1))
    fi
done

echo
echo "=== Resultado ==="
echo "Iteraciones: $ITERACIONES"
echo "Fallos: $FALLOS"

if [[ "$FALLOS" -ne 0 ]]; then
    exit 1
fi
echo "Todas las pruebas terminaron con CANCELED y JSON válido."
