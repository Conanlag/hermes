#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
TEST_HOME="$(mktemp -d)"
DATA="$TEST_HOME/.local/share/hermes/data/jobs.json"
LOCK="$TEST_HOME/.local/share/hermes/data/scheduler.lock"
OUTPUT_DIR="$TEST_HOME/output"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-017.md"
mkdir -p "$OUTPUT_DIR" "$RESULTS_DIR"

{
    printf '\n## Ejecucion: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf '```text\n'
} >>"$RESULTS_FILE"
exec > >(tee -a "$RESULTS_FILE") 2>&1

find_scheduler_pid() {
    local descriptor target
    for descriptor in /proc/[0-9]*/fd/*; do
        [[ -e "$descriptor" ]] || continue
        target="$(readlink "$descriptor" 2>/dev/null || true)"
        if [[ "$target" == "$LOCK" ]]; then
            local process_path="${descriptor#/proc/}"
            printf '%s\n' "${process_path%%/*}"
            return 0
        fi
    done
    return 0
}

read_job_value() {
    local job_id="$1"
    local field="$2"
    perl -MJSON::PP -e '
        use strict;
        use warnings;
        my ($path, $wanted_id, $field) = @ARGV;
        open my $file, "<", $path or die "No se pudo abrir $path: $!";
        local $/;
        my $jobs = decode_json(<$file>);
        ref($jobs) eq "ARRAY" or die "jobs.json no es un arreglo\n";
        my ($job) = grep {
            ref($_) eq "HASH" && defined($_->{job_id}) &&
            $_->{job_id} eq $wanted_id
        } @$jobs;
        die "No existe el Job $wanted_id\n" unless $job;
        my $value = $job->{$field};
        if (!defined $value) {
            print "";
        } elsif (ref($value) eq "ARRAY" || ref($value) eq "HASH") {
            print encode_json($value);
        } else {
            print $value;
        }
    ' "$DATA" "$job_id" "$field"
}

cleanup() {
    local id scheduler_pid
    if [[ -f "$DATA" ]]; then
        while IFS= read -r id; do
            [[ -n "$id" ]] && "$HERMES" cancel "$id" >/dev/null 2>&1 || true
        done < <(perl -MJSON::PP -e '
            use strict;
            use warnings;
            local $/;
            my $jobs = decode_json(<>);
            for my $job (@$jobs) {
                print "$job->{job_id}\n"
                    if ($job->{status} // "") eq "QUEUED" ||
                       ($job->{status} // "") eq "RUNNING";
            }
        ' "$DATA" 2>/dev/null || true)
    fi

    scheduler_pid="$(find_scheduler_pid)"
    if [[ -n "$scheduler_pid" ]]; then
        kill "$scheduler_pid" 2>/dev/null || true
        sleep 0.1
    fi
    rm -rf "$TEST_HOME"
    printf '```\n'
}
trap cleanup EXIT

if [[ ! -x "$HERMES" ]]; then
    echo "FAIL: no existe el ejecutable $HERMES. Compila Hermes antes de ejecutar la prueba."
    exit 1
fi

export HOME="$TEST_HOME"

declare -a PROCESS_IDS=()
for index in $(seq 1 8); do
    "$HERMES" job --request-id rf27-concurrent sleep 30 \
        >"$OUTPUT_DIR/request-$index.txt" 2>&1 &
    PROCESS_IDS+=("$!")
done

for pid in "${PROCESS_IDS[@]}"; do
    wait "$pid"
done

mapfile -t JOB_IDS < <(
    sed -n 's/^job ID: *//p' "$OUTPUT_DIR"/request-*.txt | sort -u
)

if [[ "${#JOB_IDS[@]}" -ne 1 ]]; then
    echo "FAIL: solicitudes simultaneas con la misma clave crearon Jobs diferentes."
    exit 1
fi

KEYED_COUNT="$(perl -MJSON::PP -e '
    use strict;
    use warnings;
    my $path = shift;
    open my $file, "<", $path or die "No se pudo abrir $path: $!";
    local $/;
    my $jobs = decode_json(<$file>);
    print scalar grep {
        ($_->{request_id} // "") eq "rf27-concurrent"
    } @$jobs;
' "$DATA")"

if [[ "$KEYED_COUNT" -ne 1 ]]; then
    echo "FAIL: jobs.json debe contener exactamente un registro para la clave."
    exit 1
fi

if "$HERMES" job --request-id rf27-concurrent sleep 31 \
    >"$OUTPUT_DIR/conflict.txt" 2>&1; then
    echo "FAIL: la misma clave no debe aceptar un payload diferente."
    exit 1
fi

if ! grep -q "otro programa o argumentos" "$OUTPUT_DIR/conflict.txt"; then
    echo "FAIL: el conflicto no produjo un mensaje explicito."
    cat "$OUTPUT_DIR/conflict.txt"
    exit 1
fi

JOB_COUNT="$(perl -MJSON::PP -e 'local $/; print scalar @{decode_json(<>)}' "$DATA")"
if [[ "$JOB_COUNT" -ne 1 ]]; then
    echo "FAIL: el payload incompatible modifico jobs.json."
    exit 1
fi

"$HERMES" job sleep 30 >"$OUTPUT_DIR/unkeyed.txt" 2>&1
UNKEYED_ID="$(sed -n 's/^job ID: *//p' "$OUTPUT_DIR/unkeyed.txt")"
if [[ -z "$UNKEYED_ID" || "$UNKEYED_ID" == "${JOB_IDS[0]}" ]]; then
    echo "FAIL: las solicitudes sin clave deben conservar la semantica no idempotente."
    exit 1
fi

"$HERMES" cancel "${JOB_IDS[0]}" >/dev/null
"$HERMES" cancel "$UNKEYED_ID" >/dev/null

"$HERMES" job --request-id rf27-terminal true \
    >"$OUTPUT_DIR/terminal.txt" 2>&1
TERMINAL_ID="$(sed -n 's/^job ID: *//p' "$OUTPUT_DIR/terminal.txt")"

TERMINAL_STATUS=""
for _ in $(seq 1 50); do
    TERMINAL_STATUS="$(read_job_value "$TERMINAL_ID" status)"
    [[ "$TERMINAL_STATUS" == "SUCCEEDED" ]] && break
    sleep 0.1
done

if [[ "$TERMINAL_STATUS" != "SUCCEEDED" ]]; then
    echo "FAIL: el Job de comprobacion no alcanzo SUCCEEDED."
    exit 1
fi

BEFORE_TERMINAL="$(read_job_value "$TERMINAL_ID" status) $(read_job_value "$TERMINAL_ID" tiempo_terminacion)"
"$HERMES" job --request-id rf27-terminal true \
    >"$OUTPUT_DIR/terminal-retry.txt" 2>&1
RETRIED_TERMINAL_ID="$(
    sed -n 's/^job ID: *//p' "$OUTPUT_DIR/terminal-retry.txt"
)"
AFTER_TERMINAL="$(read_job_value "$TERMINAL_ID" status) $(read_job_value "$TERMINAL_ID" tiempo_terminacion)"

if [[ "$RETRIED_TERMINAL_ID" != "$TERMINAL_ID" ||
      "$AFTER_TERMINAL" != "$BEFORE_TERMINAL" ]]; then
    echo "FAIL: el reintento no preservo el Job terminal existente."
    exit 1
fi

SCHEDULER_PID="$(find_scheduler_pid)"
if [[ -z "$SCHEDULER_PID" ]]; then
    echo "FAIL: no se encontro el scheduler de prueba."
    exit 1
fi

echo "PASS: claves repetidas son atomicas, reutilizan el Job y rechazan payloads distintos."
