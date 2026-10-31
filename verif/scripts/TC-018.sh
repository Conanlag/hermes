#!/usr/bin/env bash
set -uo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
TRABAJOS="${1:-5}"
CANCELACIONES_POR_JOB=3
TEST_ROOT="$(mktemp -d)"
TEST_HOME="$TEST_ROOT/home"
DATA="$TEST_HOME/.local/share/hermes/data/jobs.json"
LOCK="$TEST_HOME/.local/share/hermes/data/scheduler.lock"
OUTPUT_DIR="$TEST_ROOT/output"
OBSERVACIONES="$TEST_ROOT/transiciones.log"
DETENER_MONITOR="$TEST_ROOT/stop-monitor"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-018.md"
FALLOS=0
MONITOR_PID=""

mkdir -p "$OUTPUT_DIR" "$RESULTS_DIR"
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

cleanup() {
    local scheduler_pid
    if [[ -n "$MONITOR_PID" ]]; then
        touch "$DETENER_MONITOR"
        wait "$MONITOR_PID" 2>/dev/null || true
    fi
    scheduler_pid="$(find_scheduler_pid)"
    if [[ -n "$scheduler_pid" ]]; then
        kill "$scheduler_pid" 2>/dev/null || true
    fi
    rm -rf "$TEST_ROOT"
    printf '```\n'
}
trap cleanup EXIT

if [[ ! "$TRABAJOS" =~ ^[0-9]+$ ]] || (( TRABAJOS < 1 )); then
    echo "FAIL: indica al menos un Job (uso: bash verif/scripts/TC-018.sh [cantidad])."
    exit 1
fi

if [[ ! -x "$HERMES" ]]; then
    echo "FAIL: no existe $HERMES. Compila Hermes antes de ejecutar la prueba."
    exit 1
fi

export HOME="$TEST_HOME"

declare -a SUBMISSIONS=()
for ((index = 1; index <= TRABAJOS; index++)); do
    "$HERMES" job sleep 30 >"$OUTPUT_DIR/job-$index.log" 2>&1 &
    SUBMISSIONS+=("$!")
done

for pid in "${SUBMISSIONS[@]}"; do
    if ! wait "$pid"; then
        echo "FAIL: no se pudo registrar uno de los Jobs."
        exit 1
    fi
done

declare -a JOB_IDS=()
for ((index = 1; index <= TRABAJOS; index++)); do
    job_id="$(
        sed -n 's/^job ID: *//p' "$OUTPUT_DIR/job-$index.log" | head -n 1
    )"
    if [[ ! "$job_id" =~ ^[0-9]+$ ]]; then
        echo "FAIL: no se obtuvo un ID válido para el Job $index."
        cat "$OUTPUT_DIR/job-$index.log"
        exit 1
    fi
    JOB_IDS+=("$job_id")
done

export STOP_FILE="$DETENER_MONITOR"
perl -MJSON::PP -e '
    use strict;
    use warnings;
    my ($path, @ids) = @ARGV;
    my %wanted = map { $_ => 1 } @ids;
    while (!-e $ENV{STOP_FILE}) {
        if (open my $file, "<", $path) {
            local $/;
            my $jobs = eval { decode_json(<$file>) };
            if ($jobs && ref($jobs) eq "ARRAY") {
                for my $job (@$jobs) {
                    next unless defined $job->{job_id} &&
                        $wanted{$job->{job_id}};
                    print "$job->{job_id} $job->{status}\n";
                }
            }
            close $file;
        }
        select undef, undef, undef, 0.02;
    }
' "$DATA" "${JOB_IDS[@]}" >"$OBSERVACIONES" &
MONITOR_PID=$!

declare -a CANCELLATIONS=()
for job_id in "${JOB_IDS[@]}"; do
    for ((attempt = 1; attempt <= CANCELACIONES_POR_JOB; attempt++)); do
        "$HERMES" cancel "$job_id" \
            >"$OUTPUT_DIR/cancel-$job_id-$attempt.log" 2>&1 &
        CANCELLATIONS+=("$!")
    done
done

for pid in "${CANCELLATIONS[@]}"; do
    if wait "$pid"; then
        :
    else
        rc=$?
        if (( rc > 1 )); then
            echo "FAIL: cancel devolvió un código inesperado ($rc)."
            FALLOS=$((FALLOS + 1))
        fi
    fi
done

TERMINADOS=0
for _ in $(seq 1 200); do
    TERMINADOS="$(perl -MJSON::PP -e '
        use strict;
        use warnings;
        my ($path, $expected) = @ARGV;
        open my $file, "<", $path or die "No se pudo abrir $path: $!";
        local $/;
        my $jobs = decode_json(<$file>);
        ref($jobs) eq "ARRAY" or die "jobs.json no es un arreglo\n";
        my $selected = grep {
            my $id = $_->{job_id};
            defined($id) && $id >= 1 && $id <= $expected
        } @$jobs;
        $selected == $expected or die "Cantidad inesperada de Jobs\n";
        print scalar grep {
            ($_->{status} // "") =~ /\A(?:SUCCEEDED|FAILED|CANCELED)\z/
        } grep {
            defined($_->{job_id}) && $_->{job_id} >= 1 &&
                $_->{job_id} <= $expected
        } @$jobs;
    ' "$DATA" "$TRABAJOS")" || {
        echo "FAIL: no se pudo leer correctamente el historial."
        exit 1
    }
    (( TERMINADOS == TRABAJOS )) && break
    sleep 0.1
done

if (( TERMINADOS != TRABAJOS )); then
    echo "FAIL: terminaron $TERMINADOS de $TRABAJOS Jobs."
    exit 1
fi

touch "$DETENER_MONITOR"
wait "$MONITOR_PID"
MONITOR_PID=""

if ! perl -MJSON::PP -e '
    use strict;
    use warnings;
    my ($path, $trace_path, $expected) = @ARGV;
    open my $file, "<", $path or die "No se pudo abrir $path: $!";
    my $jobs;
    {
        local $/;
        $jobs = decode_json(<$file>);
    }
    ref($jobs) eq "ARRAY" or die "jobs.json no es un arreglo\n";
    my %by_id = map { $_->{job_id} => $_ } @$jobs;
    my %previous;
    my %observed;
    if (open my $trace, "<", $trace_path) {
        while (my $line = <$trace>) {
            chomp $line;
            my ($id, $status) = split / /, $line, 2;
            next unless defined $status && $id >= 1 && $id <= $expected;
            $status =~ /\A(?:QUEUED|RUNNING|SUCCEEDED|FAILED|CANCELED)\z/
                or die "Estado imposible observado: $status\n";
            if (defined $previous{$id} && $previous{$id} ne $status) {
                my $from = $previous{$id};
                my %allowed = (
                    QUEUED => { RUNNING => 1, CANCELED => 1 },
                    RUNNING => {
                        SUCCEEDED => 1,
                        FAILED => 1,
                        CANCELED => 1
                    },
                    SUCCEEDED => {},
                    FAILED => {},
                    CANCELED => {}
                );
                $allowed{$from}{$status}
                    or die "Regresión o transición imposible: $id $from -> $status\n";
            }
            $previous{$id} = $status;
            $observed{$id} = 1;
        }
        close $trace;
    }

    for my $id (1 .. $expected) {
        my $job = $by_id{$id} or die "Falta el Job $id\n";
        $job->{status} eq "CANCELED"
            or die "El Job $id terminó con estado inesperado: $job->{status}\n";
        ($job->{codigo_salida} // 0) != 0
            or die "El Job cancelado $id tiene código de éxito\n";
        defined($job->{tiempo_terminacion}) &&
            $job->{tiempo_terminacion} ne ""
            or die "El Job $id no tiene tiempo de terminación\n";
    }

    print "Transiciones observadas para " . scalar(keys %observed) .
        " Jobs; estados finales terminales y coherentes para $expected Jobs.\n";
' "$DATA" "$OBSERVACIONES" "$TRABAJOS"; then
    echo "FAIL: se detectó un estado inválido, una regresión o un resultado incoherente."
    FALLOS=$((FALLOS + 1))
fi

if ! perl -MJSON::PP -e '
    use strict;
    use warnings;
    local $/;
    my $jobs = decode_json(<>);
    ref($jobs) eq "ARRAY" or die "jobs.json no es un arreglo\n";
' "$DATA" >/dev/null 2>&1; then
    echo "FAIL: jobs.json no es JSON válido al concluir las solicitudes concurrentes."
    FALLOS=$((FALLOS + 1))
fi

if (( FALLOS != 0 )); then
    echo "FAIL: TC-018 detectó $FALLOS problema(s)."
    exit 1
fi

echo "PASS: $TRABAJOS Jobs recibieron $((TRABAJOS * CANCELACIONES_POR_JOB)) solicitudes concurrentes; no se observaron regresiones y todos terminaron CANCELED."
