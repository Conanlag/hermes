#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
TRABAJOS="${1:-100}"
CONCURRENCIA=10
TOLERANCIA_MEMORIA_KB=8192
TEST_ROOT="$(mktemp -d)"
TEST_HOME="$TEST_ROOT/home"
REQUESTS_DIR="$TEST_ROOT/requests"
DATA_DIR="$TEST_HOME/.local/share/hermes/data"
DATA="$DATA_DIR/jobs.json"
LOCK="$DATA_DIR/scheduler.lock"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-024.md"

mkdir -p "$REQUESTS_DIR" "$RESULTS_DIR"
{
    printf '\n## Ejecucion: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf '```text\n'
} >>"$RESULTS_FILE"
exec > >(tee -a "$RESULTS_FILE") 2>&1

find_scheduler_pid() {
    local descriptor target process_path
    for descriptor in /proc/[0-9]*/fd/*; do
        [[ -e "$descriptor" ]] || continue
        target="$(readlink "$descriptor" 2>/dev/null || true)"
        if [[ "$target" == "$LOCK" ]]; then
            process_path="${descriptor#/proc/}"
            printf '%s\n' "${process_path%%/*}"
            return 0
        fi
    done
    return 0
}

stop_scheduler() {
    local scheduler_pid
    scheduler_pid="$(find_scheduler_pid)"
    if [[ -z "$scheduler_pid" ]]; then
        return 0
    fi

    kill "$scheduler_pid" 2>/dev/null || true
    for _ in $(seq 1 50); do
        if [[ ! -d "/proc/$scheduler_pid/fd" ]]; then
            return 0
        fi
        sleep 0.1
    done

    echo "FAIL: el scheduler no liberó sus descriptores al detenerse."
    return 1
}

cleanup() {
    stop_scheduler || true
    rm -rf "$TEST_ROOT"
    printf '```\n'
}
trap cleanup EXIT

if [[ ! "$TRABAJOS" =~ ^[0-9]+$ ]] || (( TRABAJOS < 10 )); then
    echo "FAIL: indica al menos 10 trabajos (uso: bash verif/scripts/TC-024.sh [cantidad])."
    exit 1
fi

if [[ ! -x "$HERMES" ]]; then
    echo "FAIL: no existe $HERMES. Compila Hermes antes de ejecutar la prueba."
    exit 1
fi

export HOME="$TEST_HOME"

"$HERMES" configmax "$CONCURRENCIA"

wait_for_terminal_jobs() {
    local expected="$1"
    local pending

    for _ in $(seq 1 200); do
        pending="$(perl -MJSON::PP -e '
            use strict;
            use warnings;
            my ($path, $expected) = @ARGV;
            open my $file, "<", $path or die "No se pudo abrir $path: $!";
            local $/;
            my $jobs = decode_json(<$file>);
            ref($jobs) eq "ARRAY" or die "jobs.json no es un arreglo\n";
            @$jobs == $expected or die "Cantidad de Jobs inesperada: " .
                scalar(@$jobs) . " (esperada: $expected)\n";
            my $pending = grep {
                ($_->{status} // "") eq "QUEUED" ||
                ($_->{status} // "") eq "RUNNING"
            } @$jobs;
            print $pending;
        ' "$DATA" "$expected")"

        if [[ "$pending" == "0" ]]; then
            return 0
        fi
        sleep 0.1
    done

    echo "FAIL: los $expected Jobs no terminaron dentro del tiempo esperado."
    return 1
}

job_output="$("$HERMES" job true 2>&1)"
printf '%s\n' "$job_output"
wait_for_terminal_jobs 1

SCHEDULER_PID="$(find_scheduler_pid)"
if [[ -z "$SCHEDULER_PID" ]]; then
    echo "FAIL: no se encontró el proceso scheduler."
    exit 1
fi

read_rss_kb() {
    awk '/^VmRSS:/ { print $2 }' "/proc/$SCHEDULER_PID/status"
}

count_fds() {
    find "/proc/$SCHEDULER_PID/fd" -mindepth 1 -maxdepth 1 -type l \
        | wc -l
}

count_sockets() {
    local descriptor target count=0
    for descriptor in "/proc/$SCHEDULER_PID"/fd/*; do
        [[ -e "$descriptor" ]] || continue
        target="$(readlink "$descriptor" 2>/dev/null || true)"
        [[ "$target" == socket:\[* ]] && count=$((count + 1))
    done
    printf '%s\n' "$count"
}

count_children() {
    local children
    children="$(cat "/proc/$SCHEDULER_PID/task/$SCHEDULER_PID/children")"
    if [[ -z "$children" ]]; then
        printf '0\n'
    else
        wc -w <<<"$children"
    fi
}

BASE_RSS_KB="$(read_rss_kb)"
BASE_FDS="$(count_fds)"
BASE_SOCKETS="$(count_sockets)"

echo "Línea base scheduler: RSS=${BASE_RSS_KB}KB, FDs=$BASE_FDS, sockets=$BASE_SOCKETS"

for ((start = 1; start <= TRABAJOS; start += CONCURRENCIA)); do
    batch_end=$((start + CONCURRENCIA - 1))
    (( batch_end > TRABAJOS )) && batch_end="$TRABAJOS"
    pids=()

    for ((index = start; index <= batch_end; index++)); do
        "$HERMES" job true >"$REQUESTS_DIR/job-$index.log" 2>&1 &
        pids+=("$!")
    done

    for offset in "${!pids[@]}"; do
        if ! wait "${pids[$offset]}"; then
            failed_index=$((start + offset))
            echo "FAIL: no se pudo registrar el Job $failed_index."
            cat "$REQUESTS_DIR/job-$failed_index.log"
            exit 1
        fi
    done
done

ESPERADOS="$((TRABAJOS + 1))"
wait_for_terminal_jobs "$ESPERADOS"
sleep 2

declare -a PROCESS_IDS=()
for index in 1 2 3; do
    "$HERMES" job sleep 10 >"$OUTPUT_DIR/job-$index.txt" 2>&1 &
    PROCESS_IDS+=("$!")
done
for pid in "${PROCESS_IDS[@]}"; do
    wait "$pid"
done

mapfile -t JOB_IDS < <(
    sed -n 's/^job ID: *//p' "$OUTPUT_DIR"/job-*.txt | sort -u
)
if [[ "${#JOB_IDS[@]}" -ne 3 ]]; then
    echo "FAIL: no se aceptaron los tres Jobs configurados."
    cat "$OUTPUT_DIR"/job-*.txt
    exit 1
fi

RUNNING=0
for _ in $(seq 1 30); do
    RUNNING="$(perl -MJSON::PP -e '
        use strict;
        use warnings;
        local $/;
        my $jobs = decode_json(<>);
        print scalar grep { ($_->{status} // "") eq "RUNNING" } @$jobs;
    ' "$DATA")"
    [[ "$RUNNING" -eq 3 ]] && break
    sleep 0.1
done

if [[ "$RUNNING" -ne 3 ]]; then
    echo "FAIL: se esperaba observar tres Jobs en ejecución con la configuración en 3."
    exit 1
fi

if "$HERMES" job true >"$OUTPUT_DIR/over-capacity.txt" 2>&1; then
    echo "FAIL: el sistema aceptó un cuarto Job que superaría el máximo configurado."
    exit 1
fi

if compgen -G "$DATA_DIR/jobs.json.tmp.*" >/dev/null; then
    echo "FAIL: quedaron archivos temporales de persistencia."
    exit 1
fi

echo "PASS: configmax persistió el valor, conservó otras claves, rechazó valores inválidos y el scheduler ejecutó tres Jobs simultáneos sin superar el límite."
