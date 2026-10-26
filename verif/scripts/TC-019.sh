#!/usr/bin/env bash
set -u -o pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
ITERACIONES="${1:-10}"
TEST_HOME="$(mktemp -d)"
DATA="$TEST_HOME/.local/share/hermes/data/jobs.json"
LOCK="$TEST_HOME/.local/share/hermes/data/scheduler.lock"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-019.md"
FALLOS=0

mkdir -p "$RESULTS_DIR"
{
    printf '\n## Ejecucion: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf '```text\n'
} >>"$RESULTS_FILE"
exec > >(perl -pe 's/\e\[[0-9;]*m//g' | tee -a "$RESULTS_FILE") 2>&1

cleanup() {
    local descriptor pid
    if [[ -e "$LOCK" ]]; then
        for descriptor in /proc/[0-9]*/fd/*; do
            [[ -e "$descriptor" ]] || continue
            if [[ "$(readlink "$descriptor" 2>/dev/null || true)" == "$LOCK" ]]; then
                pid="${descriptor#/proc/}"
                pid="${pid%%/*}"
                kill "$pid" 2>/dev/null || true
                break
            fi
        done
    fi
    rm -rf "$TEST_HOME"
    printf '```\n'
}
trap cleanup EXIT

if [[ ! -x "$HERMES" ]]; then
    echo "ERROR: no existe el ejecutable $HERMES. Compila Hermes antes de ejecutar la prueba."
    exit 1
fi

export HOME="$TEST_HOME"

for ((i = 1; i <= ITERACIONES; i++)); do
    echo
    echo "=== Prueba $i/$ITERACIONES ==="

    SALIDA="$("$HERMES" job sleep 60 2>&1)"
    echo "$SALIDA"

    ID="$(printf '%s\n' "$SALIDA" | sed -n 's/^job ID: *//p' | head -n 1)"
    if [[ -z "$ID" ]]; then
        echo "FALLO: no se pudo obtener el ID del trabajo."
        FALLOS=$((FALLOS + 1))
        continue
    fi

    sleep 0.3

    TMP1="$(mktemp)"
    TMP2="$(mktemp)"

    "$HERMES" cancel "$ID" >"$TMP1" 2>&1 &
    P1=$!
    "$HERMES" cancel "$ID" >"$TMP2" 2>&1 &
    P2=$!

    wait "$P1"; RC1=$?
    wait "$P2"; RC2=$?

    echo "--- Respuesta 1 (código $RC1) ---"
    cat "$TMP1"
    echo "--- Respuesta 2 (código $RC2) ---"
    cat "$TMP2"

    rm -f "$TMP1" "$TMP2"

    ESTADO=""
    for ((j = 1; j <= 40; j++)); do
        ESTADO="$(perl -MJSON::PP -e '
            use strict;
            use warnings;
            my ($path, $wanted_id) = @ARGV;
            open my $file, "<", $path or die "No se pudo abrir $path: $!";
            local $/;
            my $jobs = decode_json(<$file>);
            ref($jobs) eq "ARRAY" or die "jobs.json no es un arreglo\n";
            my ($job) = grep {
                ref($_) eq "HASH" && defined($_->{job_id}) &&
                $_->{job_id} eq $wanted_id
            } @$jobs;
            print $job ? ($job->{status} // "SIN_ESTADO") : "NO_ENCONTRADO";
        ' "$DATA" "$ID")" || {
            echo "FALLO: no se pudo leer jobs.json."
            FALLOS=$((FALLOS + 1))
            break
        }
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

    if ! perl -MJSON::PP -e '
        use strict;
        use warnings;
        local $/;
        my $jobs = decode_json(<>);
        ref($jobs) eq "ARRAY" or die "jobs.json no es un arreglo\n";
    ' "$DATA" >/dev/null 2>&1; then
        echo "FALLO: jobs.json no es JSON válido."
        FALLOS=$((FALLOS + 1))
    fi
done

TOTAL="$(perl -MJSON::PP -e 'local $/; my $jobs=decode_json(<>); print scalar(@$jobs)' "$DATA")"
echo
echo "=== Resultado ==="
echo "Iteraciones: $ITERACIONES"
echo "Fallos: $FALLOS"
echo "Registros persistidos en HOME temporal: $TOTAL"

if [[ "$FALLOS" -ne 0 ]]; then
    exit 1
fi
echo "Todas las pruebas terminaron con CANCELED y JSON válido."
