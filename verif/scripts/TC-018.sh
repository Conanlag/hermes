#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
FIXTURE="$REPO/verif/json_test/TC-18/jobs.json"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-018.md"
TEST_ROOT="$(mktemp -d)"
TEST_HOME="$TEST_ROOT/home"
DATA_DIR="$TEST_HOME/.local/share/hermes/data"
DATA="$DATA_DIR/jobs.json"
OUTPUT="$TEST_ROOT/query.txt"
TIME_OUTPUT="$TEST_ROOT/time.txt"
SCHEDULER_LOCK="$DATA_DIR/scheduler.lock"

mkdir -p "$RESULTS_DIR"
{
    printf '\n## Ejecucion: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf '```text\n'
} >>"$RESULTS_FILE"
exec > >(tee -a "$RESULTS_FILE") 2>&1

cleanup() {
    local descriptor pid
    if [[ -e "$SCHEDULER_LOCK" ]]; then
        for descriptor in /proc/[0-9]*/fd/*; do
            [[ -e "$descriptor" ]] || continue
            if [[ "$(readlink "$descriptor" 2>/dev/null || true)" == "$SCHEDULER_LOCK" ]]; then
                pid="${descriptor#/proc/}"
                pid="${pid%%/*}"
                kill "$pid" 2>/dev/null || true
                break
            fi
        done
    fi
    rm -rf "$TEST_ROOT"
    printf '```\n'
}
trap cleanup EXIT

if [[ ! -x "$HERMES" ]]; then
    echo "FAIL: no existe el ejecutable $HERMES. Compila Hermes antes de ejecutar la prueba."
    exit 1
fi

if [[ ! -f "$FIXTURE" ]]; then
    echo "FAIL: no se encontro el fixture $FIXTURE."
    exit 1
fi

mkdir -p "$DATA_DIR"
cp "$FIXTURE" "$DATA"

if ! perl -MJSON::PP -e '
    use strict;
    use warnings;
    my $path = shift;
    open my $file, "<", $path or die "No se pudo abrir $path: $!";
    local $/;
    my $jobs = decode_json(<$file>);
    ref($jobs) eq "ARRAY" or die "jobs.json debe contener un arreglo\n";
    scalar(@$jobs) >= 500 or die "Se esperaban al menos 500 Jobs\n";
    my %ids;
    for my $job (@$jobs) {
        ref($job) eq "HASH" or die "Registro de Job invalido\n";
        for my $field (qw(job_id pid programa argumentos status tiempo_recepcion tiempo_inicio tiempo_terminacion codigo_salida)) {
            exists $job->{$field} or die "Falta $field en un Job\n";
        }
        defined($job->{job_id}) && !$ids{$job->{job_id}}++ or die "job_id duplicado o invalido\n";
        ref($job->{argumentos}) eq "ARRAY" or die "argumentos debe ser arreglo\n";
        $job->{programa} =~ /\A[^\r\n]+\z/ or die "programa invalido\n";
        $job->{status} =~ /\A(?:QUEUED|RUNNING|SUCCEEDED|FAILED|CANCELED|PAUSED_QUEUED|PAUSED_RUNNING)\z/
            or die "status invalido\n";
        $job->{tiempo_recepcion} ne "" or die "tiempo_recepcion vacio\n";
        if ($job->{status} =~ /\A(?:SUCCEEDED|FAILED|CANCELED)\z/) {
            $job->{tiempo_inicio} ne "" or die "tiempo_inicio vacio en Job terminado\n";
            $job->{tiempo_terminacion} ne "" or die "tiempo_terminacion vacio en Job terminado\n";
            defined($job->{codigo_salida}) or die "codigo_salida ausente en Job terminado\n";
        }
    }
    print scalar(@$jobs);
' "$DATA" >"$TEST_ROOT/job-count.txt"; then
    echo "FAIL: el fixture no conserva los metadatos esperados."
    exit 1
fi

JOB_COUNT="$(cat "$TEST_ROOT/job-count.txt")"
if [[ "$JOB_COUNT" -lt 500 ]]; then
    echo "FAIL: el fixture solo contiene $JOB_COUNT registros."
    exit 1
fi

TIMEFORMAT='%3R'
{ time HOME="$TEST_HOME" "$HERMES" filter programa echo >"$OUTPUT"; } \
    2>"$TIME_OUTPUT"
QUERY_SECONDS="$(tail -n 1 "$TIME_OUTPUT")"
QUERY_COUNT="$(grep -c '^Job ID: ' "$OUTPUT" || true)"

if [[ "$QUERY_COUNT" -lt 100 ]]; then
    echo "FAIL: la consulta devolvio $QUERY_COUNT Jobs echo; se esperaban al menos 100."
    exit 1
fi

if ! awk -v duration="$QUERY_SECONDS" \
    'BEGIN { exit !(duration < 1.0) }'; then
    echo "FAIL: la consulta sobre $JOB_COUNT Jobs tardo ${QUERY_SECONDS}s; debe ser menor a 1s."
    exit 1
fi

if ! cmp -s "$FIXTURE" "$DATA"; then
    echo "FAIL: Hermes modifico la copia de prueba del fixture."
    exit 1
fi

echo "RNF-05: time hermes filter programa echo con $JOB_COUNT registros = ${QUERY_SECONDS}s"
echo "RNF-06: $JOB_COUNT Jobs del fixture conservan IDs, metadatos y resultados."
echo "PASS: RNF-05 y RNF-06"
