#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
TEST_ROOT="$(mktemp -d)"
TEST_HOME="$TEST_ROOT/home"
DATA="$TEST_HOME/.local/share/hermes/data/jobs.json"
LOCK="$TEST_HOME/.local/share/hermes/data/scheduler.lock"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-016.md"

mkdir -p "$RESULTS_DIR"
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
    if [[ -n "$scheduler_pid" ]]; then
        kill "$scheduler_pid" 2>/dev/null || true
        for _ in $(seq 1 50); do
            [[ -z "$(find_scheduler_pid)" ]] && return 0
            sleep 0.1
        done
        echo "FAIL: el scheduler no libero scheduler.lock."
        return 1
    fi
}

cleanup() {
    local scheduler_pid
    scheduler_pid="$(find_scheduler_pid)"
    if [[ -n "$scheduler_pid" ]]; then
        kill "$scheduler_pid" 2>/dev/null || true
    fi
    rm -rf "$TEST_ROOT"
    printf '```\n'
}
trap cleanup EXIT

read_job_field() {
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
        print defined($value) ? $value : "";
    ' "$DATA" "$1" "$2"
}

if [[ ! -x "$HERMES" ]]; then
    echo "FAIL: no existe $HERMES. Compila Hermes antes de ejecutar la prueba."
    exit 1
fi

export HOME="$TEST_HOME"

SALIDA="$("$HERMES" job true 2>&1)"
printf '%s\n' "$SALIDA"
JOB_ID="$(printf '%s\n' "$SALIDA" | sed -n 's/^job ID: *//p' | head -n 1)"
if [[ ! "$JOB_ID" =~ ^[0-9]+$ ]]; then
    echo "FAIL: no se pudo obtener un ID válido para el Job terminado."
    exit 1
fi

ESTADO=""
for _ in $(seq 1 100); do
    ESTADO="$(read_job_field "$JOB_ID" status)"
    [[ "$ESTADO" == "SUCCEEDED" ]] && break
    sleep 0.1
done
if [[ "$ESTADO" != "SUCCEEDED" ]]; then
    echo "FAIL: el Job $JOB_ID no alcanzó SUCCEEDED."
    exit 1
fi
echo "Job terminado antes del reinicio: $JOB_ID ($ESTADO)"

stop_scheduler

INTERRUPTED_ID="$((JOB_ID + 1))"
perl -MJSON::PP -e '
    use strict;
    use warnings;
    my ($path, $id) = @ARGV;
    open my $file, "<", $path or die "No se pudo abrir $path: $!";
    local $/;
    my $jobs = decode_json(<$file>);
    push @$jobs, {
        job_id => 0 + $id,
        pid => 999999,
        programa => "proceso-interrumpido",
        argumentos => ["argumento-prueba"],
        status => "RUNNING",
        tiempo_recepcion => "2026-01-02 03:04:05",
        tiempo_inicio => "2026-01-02 03:04:06",
        tiempo_terminacion => "",
        codigo_salida => -1,
        cancel_requested => JSON::PP::false
    };
    open my $out, ">", $path or die "No se pudo escribir $path: $!";
    print {$out} JSON::PP->new->utf8->canonical->pretty->encode($jobs);
    close $out or die "No se pudo cerrar $path: $!";
' "$DATA" "$INTERRUPTED_ID"

"$HERMES" filter id "$JOB_ID" >/dev/null

ESTADO=""
for _ in $(seq 1 100); do
    ESTADO="$(read_job_field "$INTERRUPTED_ID" status)"
    [[ "$ESTADO" == "INTERRUPTED" ]] && break
    sleep 0.1
done
if [[ "$ESTADO" != "INTERRUPTED" ]]; then
    echo "FAIL: el Job $INTERRUPTED_ID no se recuperó como INTERRUPTED."
    exit 1
fi

if ! perl -MJSON::PP -e '
    use strict;
    use warnings;
    my ($path, $completed_id, $interrupted_id) = @ARGV;
    open my $file, "<", $path or die "No se pudo abrir $path: $!";
    local $/;
    my $jobs = decode_json(<$file>);
    ref($jobs) eq "ARRAY" or die "jobs.json no es un arreglo\n";
    my %by_id = map { $_->{job_id} => $_ } @$jobs;
    my $completed = $by_id{$completed_id}
        or die "Se perdió el Job terminado\n";
    $completed->{status} eq "SUCCEEDED"
        or die "Cambió el estado del Job terminado\n";
    $completed->{programa} eq "true"
        or die "Se perdió el programa del Job terminado\n";
    ref($completed->{argumentos}) eq "ARRAY" &&
        @{$completed->{argumentos}} == 0
        or die "Se perdieron los argumentos del Job terminado\n";
    $completed->{codigo_salida} == 0
        or die "Se perdió el resultado del Job terminado\n";
    for my $field (qw(tiempo_recepcion tiempo_inicio tiempo_terminacion)) {
        defined($completed->{$field}) && $completed->{$field} ne ""
            or die "Se perdió $field del Job terminado\n";
    }

    my $interrupted = $by_id{$interrupted_id}
        or die "Se perdió el Job interrumpido\n";
    $interrupted->{status} eq "INTERRUPTED"
        or die "El Job interrumpido no quedó en INTERRUPTED\n";
    $interrupted->{motivo} eq "sin_identidad"
        or die "El motivo del Job interrumpido no es sin_identidad\n";
    !$interrupted->{proceso_terminado}
        or die "No se debe afirmar terminación de un proceso no verificable\n";
    $interrupted->{programa} eq "proceso-interrumpido"
        or die "Se perdió el programa del Job interrumpido\n";
    ref($interrupted->{argumentos}) eq "ARRAY" &&
        @{$interrupted->{argumentos}} == 1 &&
        $interrupted->{argumentos}[0] eq "argumento-prueba"
        or die "Se perdieron los argumentos del Job interrumpido\n";
    $interrupted->{tiempo_recepcion} eq "2026-01-02 03:04:05"
        or die "Se perdió tiempo_recepcion del Job interrumpido\n";
    $interrupted->{tiempo_inicio} eq "2026-01-02 03:04:06"
        or die "Se perdió tiempo_inicio del Job interrumpido\n";
    $interrupted->{codigo_salida} == -1
        or die "El código de salida del Job interrumpido es incorrecto\n";
    defined($interrupted->{mensaje_error}) &&
        $interrupted->{mensaje_error} =~ /interrumpido por reinicio/
        or die "Falta el mensaje de interrupción\n";
    defined($interrupted->{tiempo_terminacion}) &&
        $interrupted->{tiempo_terminacion} ne ""
        or die "Falta el tiempo de terminación del Job interrumpido\n";
    print "Metadatos y resultados verificados para ambos Jobs.\n";
' "$DATA" "$JOB_ID" "$INTERRUPTED_ID"; then
    echo "FAIL: la persistencia posterior al reinicio no coincide con lo esperado."
    exit 1
fi

echo "PASS: los Jobs terminados conservan metadatos y resultados; los RUNNING no verificables se recuperan como INTERRUPTED."
