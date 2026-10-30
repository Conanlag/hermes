#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
TEST_HOME="$(mktemp -d)"
DATA="$TEST_HOME/.local/share/hermes/data/jobs.json"
EVENTS="$TEST_HOME/.local/share/hermes/data/events.jsonl"
OUTPUT_DIR="$TEST_HOME/output"
mkdir -p "$OUTPUT_DIR" "$TEST_HOME/.local/share/hermes/data"

cleanup() {
    local id
    if [[ -f "$DATA" ]]; then
        while IFS= read -r id; do
            [[ -n "$id" ]] && HOME="$TEST_HOME" "$HERMES" cancel "$id" >/dev/null 2>&1 || true
        done < <(perl -MJSON::PP -e '
            use strict;
            use warnings;
            local $/;
            my $jobs = decode_json(<>);
            print "$_->{job_id}\n"
                for grep {
                    ($_->{status} // "") eq "QUEUED" ||
                    ($_->{status} // "") eq "RUNNING"
                } @$jobs;
        ' "$DATA" 2>/dev/null || true)
    fi
    HOME="$TEST_HOME" "$HERMES" clean scheduler >/dev/null 2>&1 || true
    rm -rf "$TEST_HOME"
}
trap cleanup EXIT

if [[ ! -x "$HERMES" ]]; then
    echo "FAIL: no existe el ejecutable $HERMES. Compila Hermes antes de ejecutar la prueba."
    exit 1
fi

export HOME="$TEST_HOME"
printf '{\n  "trabajos_maximos": 2\n}\n' >"$TEST_HOME/.local/share/hermes/data/config.json"

SEED_OUTPUT="$("$HERMES" job --request-id rf25-seed sleep 30 2>&1)"
SEED_ID="$(printf '%s\n' "$SEED_OUTPUT" | sed -n 's/^job ID: *//p' | head -n 1)"
if [[ -z "$SEED_ID" ]]; then
    echo "FAIL: no se pudo crear el Job semilla."
    echo "$SEED_OUTPUT"
    exit 1
fi

declare -a PROCESS_IDS=()
for index in $(seq 1 8); do
    (
        if timeout 5 "$HERMES" job sleep 30 \
            >"$OUTPUT_DIR/request-$index.txt" 2>&1; then
            result=0
        else
            result=$?
        fi
        printf '%s\n' "$result" >"$OUTPUT_DIR/request-$index.exit"
    ) &
    PROCESS_IDS+=("$!")
done

for pid in "${PROCESS_IDS[@]}"; do
    wait "$pid" || true
done

ACCEPTED=0
REJECTED=0
for index in $(seq 1 8); do
    OUTPUT="$(cat "$OUTPUT_DIR/request-$index.txt")"
    EXIT_CODE="$(cat "$OUTPUT_DIR/request-$index.exit")"
    if grep -q '^job ID:' <<<"$OUTPUT"; then
        if [[ "$EXIT_CODE" -ne 0 ]]; then
            echo "FAIL: una solicitud aceptada terminó con código $EXIT_CODE."
            exit 1
        fi
        ACCEPTED=$((ACCEPTED + 1))
    elif grep -q 'La cola está llena' <<<"$OUTPUT"; then
        if [[ "$EXIT_CODE" -eq 0 ]]; then
            echo "FAIL: una solicitud rechazada terminó con código cero."
            exit 1
        fi
        REJECTED=$((REJECTED + 1))
    else
        echo "FAIL: respuesta inesperada en solicitud $index:"
        echo "$OUTPUT"
        exit 1
    fi
done

if [[ "$ACCEPTED" -ne 1 || "$REJECTED" -ne 7 ]]; then
    echo "FAIL: con un espacio restante se esperaba 1 aceptación y 7 rechazos; se observaron $ACCEPTED y $REJECTED."
    exit 1
fi

read_counts() {
    perl -MJSON::PP -e '
        use strict;
        use warnings;
        my $path = shift;
        open my $file, "<", $path or die "No se pudo abrir $path: $!";
        local $/;
        my $jobs = decode_json(<$file>);
        ref($jobs) eq "ARRAY" or die "jobs.json no es un arreglo\n";
        my $active = grep {
            ($_->{status} // "") eq "QUEUED" ||
            ($_->{status} // "") eq "RUNNING"
        } @$jobs;
        print scalar(@$jobs), " ", $active;
    ' "$DATA"
}

read -r TOTAL ACTIVE <<<"$(read_counts)"
if [[ "$TOTAL" -ne 2 || "$ACTIVE" -ne 2 ]]; then
    echo "FAIL: los rechazos no deben crear Jobs; se encontraron $TOTAL registros y $ACTIVE activos."
    exit 1
fi

perl -MJSON::PP -e '
    use strict;
    use warnings;
    my $path = shift;
    open my $file, "<", $path or die "No se pudo abrir $path: $!\n";
    my @events = map { decode_json($_) } <$file>;
    my @rejections = grep {
        ($_->{message} // "") eq "Solicitud rechazada: cola llena"
    } @events;
    @rejections == 7
        or die "Se esperaban 7 eventos de rechazo; se encontraron " . scalar(@rejections) . "\n";
    for my $event (@rejections) {
        ($event->{level} // "") eq "WARN"
            or die "El rechazo debe registrarse con nivel WARN\n";
        !defined($event->{job_id})
            or die "El rechazo previo a la creación debe tener job_id null\n";
        my $context = $event->{context};
        ref($context) eq "HASH"
            or die "El evento de rechazo debe incluir contexto\n";
        ($context->{motivo_del_rechazo} // "") eq "capacidad_de_trabajos_alcanzada"
            or die "El evento no identifica el límite excedido\n";
        ($context->{trabajos_activos} // 0) == 2 &&
            ($context->{capacidad} // 0) == 2
            or die "El evento no registra trabajos activos y capacidad\n";
    }
' "$EVENTS"

RETRY_OUTPUT="$("$HERMES" job --request-id rf25-seed sleep 30 2>&1)"
RETRY_ID="$(printf '%s\n' "$RETRY_OUTPUT" | sed -n 's/^job ID: *//p' | head -n 1)"
read -r TOTAL ACTIVE <<<"$(read_counts)"
if [[ "$RETRY_ID" != "$SEED_ID" || "$TOTAL" -ne 2 || "$ACTIVE" -ne 2 ]]; then
    echo "FAIL: el reintento idempotente debe reutilizar el Job existente aunque la cola esté llena."
    echo "$RETRY_OUTPUT"
    exit 1
fi

"$HERMES" cancel "$SEED_ID" >/dev/null
for _ in $(seq 1 50); do
    STATUS="$("$HERMES" filter id "$SEED_ID" 2>/dev/null | sed -n 's/^Estado: *//p')"
    [[ "$STATUS" == "CANCELED" ]] && break
    sleep 0.1
done

if [[ "$STATUS" != "CANCELED" ]]; then
    echo "FAIL: el Job semilla no liberó capacidad al cancelarse."
    exit 1
fi

RELEASED_OUTPUT="$("$HERMES" job true 2>&1)"
RELEASED_ID="$(printf '%s\n' "$RELEASED_OUTPUT" | sed -n 's/^job ID: *//p' | head -n 1)"
if [[ -z "$RELEASED_ID" ]]; then
    echo "FAIL: la capacidad no se liberó después de finalizar un Job."
    echo "$RELEASED_OUTPUT"
    exit 1
fi

echo "PASS: el límite concurrente rechazó sin persistir Jobs extra, registró los rechazos y liberó la capacidad."
