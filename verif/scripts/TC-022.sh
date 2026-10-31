#!/usr/bin/env bash
#
# TC-022: recuperación después de reinicio (RF-13).
#
# Cubre los casos (a)-(i) de la sección 2.6 del diseño de RF-13:
#   (a) SIGTERM al demonio con un Job activo -> el coordinador de apagado
#       termina el grupo y persiste INTERRUPTED con motivo=apagado, sin
#       huérfanos.
#   (b) SIGKILL al demonio -> PDEATHSIG mata al hijo y no sobrevive RUNNING.
#   (c) fila RUNNING con el PID vivo de un proceso ajeno -> no se mata.
#   (d) QUEUED sigue pendiente y se ejecuta.
#   (e) estados terminales intactos y estado desconocido fail-closed.
#   (f) RNF-28: SIGKILL en plena ráfaga de escrituras -> jobs.json sigue parseando,
#       jobs.json.bak existe, y el arranque limpia los jobs.json.tmp.*
#       huérfanos (RNF-11).
#   (g) clean data tras una caída -> recupera antes de borrar y no arranca
#       un daemon (F12).
#   (h) nietos que sobreviven a PDEATHSIG -> recovery termina el grupo sin
#       líder usando el sid persistido y proceso_terminado refleja la realidad.
#   (i) fila RUNNING con pid=0 -> INTERRUPTED con motivo=sin_pid (caso
#       adicional: el diseño no le asigna letra, pero exige prueba dedicada).
#
# Además audita la prevención de F1 (los Jobs no heredan los locks) y que
# la identidad persistida (boot_id + starttime) coincida con /proc.

set -uo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
TEST_ROOT="$(mktemp -d)"
TEST_HOME="$TEST_ROOT/home"
DATA="$TEST_HOME/.local/share/hermes/data/jobs.json"
RESPALDO="$TEST_HOME/.local/share/hermes/data/jobs.json.bak"
LOCK="$TEST_HOME/.local/share/hermes/data/scheduler.lock"
JOBS_LOCK="$TEST_HOME/.local/share/hermes/data/jobs.lock"
RESULTS_DIR="$REPO/verif/results"
RESULTS_FILE="$RESULTS_DIR/results_TC-022.md"
FALLOS=0
VICTIMA=""
GRUPO_H=""

mkdir -p "$RESULTS_DIR"
{
    printf '\n## Ejecucion: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf '```text\n'
} >>"$RESULTS_FILE"
exec > >(tee -a "$RESULTS_FILE") 2>&1

fallo() {
    echo "FAIL: $*"
    FALLOS=$((FALLOS + 1))
}

ok() {
    echo "OK: $*"
}

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

esperar_sin_demonio() {
    local _
    for _ in $(seq 1 100); do
        [[ -z "$(find_scheduler_pid)" ]] && return 0
        sleep 0.1
    done
    return 1
}

detener_demonio() {
    local pid
    pid="$(find_scheduler_pid)"
    [[ -z "$pid" ]] && return 0
    kill -TERM "$pid" 2>/dev/null || true
    esperar_sin_demonio
}

matar_demonio() {
    local pid
    pid="$(find_scheduler_pid)"
    [[ -z "$pid" ]] && return 1
    kill -KILL "$pid" 2>/dev/null || true
    esperar_sin_demonio
}

cleanup() {
    local pid
    if [[ -n "$GRUPO_H" ]]; then
        kill -KILL -- -"$GRUPO_H" 2>/dev/null || true
    fi
    if [[ -n "$VICTIMA" ]]; then
        kill -KILL "$VICTIMA" 2>/dev/null || true
    fi
    pid="$(find_scheduler_pid)"
    if [[ -n "$pid" ]]; then
        kill -TERM "$pid" 2>/dev/null || true
        esperar_sin_demonio || true
    fi
    rm -rf "$TEST_ROOT"
    printf '```\n'
}
trap cleanup EXIT

leer_campo() {
    perl -MJSON::PP -e '
        use strict;
        use warnings;
        my ($path, $wanted_id, $field) = @ARGV;
        open my $file, "<", $path or exit 1;
        local $/;
        my $jobs = eval { decode_json(<$file>) };
        exit 1 unless $jobs && ref($jobs) eq "ARRAY";
        my ($job) = grep {
            ref($_) eq "HASH" && defined($_->{job_id}) &&
            $_->{job_id} == $wanted_id
        } @$jobs;
        exit 1 unless $job;
        my $value = $job->{$field};
        if (!defined $value) {
            print "";
        } elsif (ref($value) eq "JSON::PP::Boolean") {
            print $value ? "true" : "false";
        } else {
            print $value;
        }
    ' "$DATA" "$1" "$2"
}

cantidad_filas() {
    perl -MJSON::PP -e '
        use strict;
        use warnings;
        my ($path) = @ARGV;
        open my $file, "<", $path or exit 1;
        local $/;
        my $jobs = eval { decode_json(<$file>) };
        exit 1 unless $jobs && ref($jobs) eq "ARRAY";
        print scalar(@$jobs);
    ' "$DATA"
}

agregar_fila() {
    ROW_JSON="$1" perl -MJSON::PP -e '
        use strict;
        use warnings;
        my ($path) = @ARGV;
        open my $file, "<", $path or die "No se pudo abrir $path: $!";
        local $/;
        my $jobs = decode_json(<$file>);
        ref($jobs) eq "ARRAY" or die "jobs.json no es un arreglo\n";
        push @$jobs, decode_json($ENV{ROW_JSON});
        open my $out, ">", $path or die "No se pudo escribir $path: $!";
        print {$out} JSON::PP->new->utf8->canonical->pretty->encode($jobs);
        close $out or die "No se pudo cerrar $path: $!";
    ' "$DATA"
}

siguiente_id() {
    perl -MJSON::PP -e '
        use strict;
        use warnings;
        my ($path) = @ARGV;
        open my $file, "<", $path or exit 1;
        local $/;
        my $jobs = eval { decode_json(<$file>) };
        exit 1 unless defined $jobs && ref($jobs) eq "ARRAY";
        my $max = 0;
        for my $job (@$jobs) {
            next unless ref($job) eq "HASH" && defined($job->{job_id});
            $max = $job->{job_id} if $job->{job_id} > $max;
        }
        print $max + 1;
    ' "$DATA"
}

parsea_arreglo() {
    perl -MJSON::PP -e '
        use strict;
        use warnings;
        my ($path) = @ARGV;
        open my $file, "<", $path or exit 1;
        local $/;
        my $jobs = eval { decode_json(<$file>) };
        exit 1 unless defined $jobs && ref($jobs) eq "ARRAY";
    ' "$1"
}

starttime_proc() {
    perl -e '
        my ($pid) = @ARGV;
        open my $file, "<", "/proc/$pid/stat" or exit 1;
        local $/;
        my $line = <$file>;
        my $cierre = rindex($line, ")");
        exit 1 if $cierre < 0;
        my @campos = split / /, substr($line, $cierre + 2);
        print $campos[19];
    ' "$1"
}

# Campo de /proc/<pid>/stat posterior al comm: 0=state, 1=ppid,
# 2=pgrp, 3=session, 19=starttime.
campo_proc() {
    perl -e '
        my ($pid, $indice) = @ARGV;
        open my $file, "<", "/proc/$pid/stat" or exit 1;
        local $/;
        my $linea = <$file>;
        my $cierre = rindex($linea, ")");
        exit 1 if $cierre < 0;
        my @campos = split / /, substr($linea, $cierre + 2);
        print $campos[$indice];
    ' "$1" "$2"
}

hijos_de() {
    perl -e '
        my ($padre) = @ARGV;
        for my $ruta (glob "/proc/[0-9]*") {
            my ($pid) = $ruta =~ m{/proc/([0-9]+)$};
            next unless defined $pid;
            open my $file, "<", "$ruta/stat" or next;
            local $/;
            my $linea = <$file>;
            close $file;
            next unless defined $linea;
            my $cierre = rindex($linea, ")");
            next if $cierre < 0;
            my @campos = split / /, substr($linea, $cierre + 2);
            next unless @campos >= 2;
            print "$pid\n" if $campos[1] == $padre;
        }
    ' "$1"
}

miembros_grupo() {
    perl -e '
        my ($pgid, $sid) = @ARGV;
        for my $ruta (glob "/proc/[0-9]*") {
            my ($pid) = $ruta =~ m{/proc/([0-9]+)$};
            next unless defined $pid;
            open my $file, "<", "$ruta/stat" or next;
            local $/;
            my $linea = <$file>;
            close $file;
            next unless defined $linea;
            my $cierre = rindex($linea, ")");
            next if $cierre < 0;
            my @campos = split / /, substr($linea, $cierre + 2);
            next unless @campos >= 4;
            next if $campos[0] eq "Z" || $campos[0] eq "X";
            print "$pid\n" if $campos[2] == $pgid && $campos[3] == $sid;
        }
    ' "$1" "$2"
}

esperar_pid_job() {
    local id="$1" pid="" _
    for _ in $(seq 1 100); do
        pid="$(leer_campo "$id" pid 2>/dev/null || true)"
        if [[ "$pid" =~ ^[0-9]+$ ]] && (( pid > 0 )); then
            printf '%s\n' "$pid"
            return 0
        fi
        sleep 0.1
    done
    return 1
}

esperar_estado() {
    local id="$1" esperado="$2" estado="" _
    for _ in $(seq 1 150); do
        estado="$(leer_campo "$id" status 2>/dev/null || true)"
        [[ "$estado" == "$esperado" ]] && return 0
        sleep 0.1
    done
    return 1
}

disparar_recuperacion() {
    # Cualquier comando que no sea help/version/clean pasa por el arranque
    # del scheduler y, si no hay daemon vivo, ejecuta la recuperación.
    "$HERMES" filter status QUEUED >/dev/null 2>&1 || true
}

if [[ ! -x "$HERMES" ]]; then
    echo "FAIL: no existe $HERMES. Compila Hermes antes de ejecutar la prueba."
    exit 1
fi

command -v perl >/dev/null 2>&1 || {
    echo "FAIL: se necesita Perl con JSON::PP."
    exit 1
}

export HOME="$TEST_HOME"

echo "== (a) SIGTERM al demonio con un Job sleep activo: cierre ordenado =="
SALIDA_A="$("$HERMES" job sleep 30 2>&1)"
printf '%s\n' "$SALIDA_A"
ID_A="$(printf '%s\n' "$SALIDA_A" | sed -n 's/^job ID: *//p' | head -n 1)"
PID_A="$(esperar_pid_job "$ID_A" || true)"
if [[ ! "$ID_A" =~ ^[0-9]+$ ]] || [[ ! "$PID_A" =~ ^[0-9]+$ ]]; then
    fallo "(a) no se pudo crear el Job sleep activo."
else
    DEMONIO_A="$(find_scheduler_pid)"
    if [[ -z "$DEMONIO_A" ]]; then
        fallo "(a) no se encontró el demonio que posee scheduler.lock."
    elif ! detener_demonio; then
        fallo "(a) el demonio no liberó scheduler.lock tras SIGTERM."
    else
        # El coordinador persiste el estado final antes de que el proceso
        # libere el lock, así que al volver de detener_demonio la fila ya
        # debe estar escrita: no hace falta disparar la recuperación.
        HIJO_VIVO=1
        for _ in $(seq 1 100); do
            if [[ ! -e "/proc/$PID_A" ]]; then
                HIJO_VIVO=0
                break
            fi
            sleep 0.1
        done
        if (( HIJO_VIVO != 0 )); then
            fallo "(a) el hijo $PID_A sobrevivió al apagado ordenado."
        else
            ok "(a) el coordinador terminó el grupo del hijo."
        fi

        if ! esperar_estado "$ID_A" INTERRUPTED; then
            fallo "(a) el Job $ID_A no quedó INTERRUPTED."
        else
            MOTIVO_A="$(leer_campo "$ID_A" motivo)"
            TERMINADO_A="$(leer_campo "$ID_A" proceso_terminado)"
            MENSAJE_A="$(leer_campo "$ID_A" mensaje_error)"
            CODIGO_A="$(leer_campo "$ID_A" codigo_salida)"

            [[ "$MOTIVO_A" == "apagado" ]] \
                || fallo "(a) motivo esperado apagado, obtenido '$MOTIVO_A'."
            [[ "$TERMINADO_A" == "true" ]] \
                || fallo "(a) proceso_terminado esperado true, obtenido '$TERMINADO_A'."
            [[ "$CODIGO_A" == "-1" ]] \
                || fallo "(a) codigo_salida esperado -1, obtenido '$CODIGO_A'."
            [[ "$MENSAJE_A" =~ apagado\ ordenado ]] \
                || fallo "(a) falta el mensaje de apagado ordenado: '$MENSAJE_A'."

            if [[ "$MOTIVO_A" == "apagado" && "$TERMINADO_A" == "true" ]]; then
                ok "(a) fila INTERRUPTED (motivo=apagado, proceso_terminado=true), sin huérfano."
            fi

            # La recuperación del siguiente arranque no debe reescribir un
            # estado que ya escribió el coordinador.
            disparar_recuperacion
            ESTADO_A2="$(leer_campo "$ID_A" status)"
            MOTIVO_A2="$(leer_campo "$ID_A" motivo)"
            [[ "$ESTADO_A2" == "INTERRUPTED" && "$MOTIVO_A2" == "apagado" ]] \
                || fallo "(a) la recuperación alteró el cierre ordenado (estado='$ESTADO_A2', motivo='$MOTIVO_A2')."
        fi
    fi
fi

echo
echo "== (b) SIGKILL al demonio con un Job sleep activo =="
SALIDA_B="$("$HERMES" job sleep 30 2>&1)"
printf '%s\n' "$SALIDA_B"
ID_B="$(printf '%s\n' "$SALIDA_B" | sed -n 's/^job ID: *//p' | head -n 1)"
PID_B="$(esperar_pid_job "$ID_B" || true)"
if [[ ! "$ID_B" =~ ^[0-9]+$ ]] || [[ ! "$PID_B" =~ ^[0-9]+$ ]]; then
    fallo "(b) no se pudo crear el Job sleep activo."
else
    if ! matar_demonio; then
        fallo "(b) no se encontró el demonio para SIGKILL."
    else
        HIJO_VIVO=1
        for _ in $(seq 1 100); do
            if [[ ! -e "/proc/$PID_B" ]]; then
                HIJO_VIVO=0
                break
            fi
            sleep 0.1
        done
        if (( HIJO_VIVO != 0 )); then
            fallo "(b) el hijo $PID_B sobrevivió al SIGKILL del demonio."
        else
            ok "(b) PDEATHSIG mató al hijo tras SIGKILL."
        fi

        disparar_recuperacion
        if ! esperar_estado "$ID_B" INTERRUPTED; then
            fallo "(b) el Job $ID_B no quedó INTERRUPTED."
        else
            TERMINADO_B="$(leer_campo "$ID_B" proceso_terminado)"
            [[ "$TERMINADO_B" == "true" ]] \
                || fallo "(b) proceso_terminado esperado true, obtenido '$TERMINADO_B'."
        fi

        SALIDA_RUNNING="$("$HERMES" filter status RUNNING 2>&1 || true)"
        if printf '%s\n' "$SALIDA_RUNNING" | grep -q '^Job ID:'; then
            fallo "(b) todavía hay filas RUNNING tras la recuperación."
            printf '%s\n' "$SALIDA_RUNNING"
        else
            ok "(b) no sobrevive ninguna fila RUNNING al reinicio."
        fi
    fi
fi

echo
echo "== (c) fila RUNNING con el PID vivo de un proceso ajeno =="
if ! detener_demonio; then
    fallo "(c) no se pudo detener el demonio antes de fabricar la fila."
else
    setsid sleep 300 >/dev/null 2>&1 &
    VICTIMA=$!
    sleep 0.1

    if [[ ! -e "/proc/$VICTIMA" ]]; then
        fallo "(c) no se pudo crear el proceso víctima."
    else
        GRUPO_VICTIMA="$(perl -e '
            open my $f, "<", "/proc/$ARGV[0]/stat" or exit 1;
            local $/; my $l = <$f>;
            my $c = rindex($l, ")");
            my @c = split / /, substr($l, $c + 2);
            print $c[2];
        ' "$VICTIMA")"
        BOOT_ID="$(tr -d '\n' < /proc/sys/kernel/random/boot_id)"
        INICIO_VICTIMA="$(starttime_proc "$VICTIMA")"

        if [[ "$GRUPO_VICTIMA" != "$VICTIMA" ]]; then
            fallo "(c) la víctima no quedó en su propio grupo (pgrp=$GRUPO_VICTIMA)."
        fi

        ID_C="$((ID_B + 1))"
        INICIO_FALSO=$((INICIO_VICTIMA + 1))
        agregar_fila "{
            \"job_id\": $ID_C,
            \"pid\": $VICTIMA,
            \"boot_id\": \"$BOOT_ID\",
            \"pid_inicio\": $INICIO_FALSO,
            \"programa\": \"proceso-ajeno\",
            \"argumentos\": [],
            \"status\": \"RUNNING\",
            \"tiempo_recepcion\": \"2026-01-01 00:00:00\",
            \"tiempo_inicio\": \"2026-01-01 00:00:01\",
            \"tiempo_terminacion\": \"\",
            \"codigo_salida\": -1
        }"

        disparar_recuperacion

        if ! esperar_estado "$ID_C" INTERRUPTED; then
            fallo "(c) la fila fabricada no quedó INTERRUPTED."
        else
            MOTIVO_C="$(leer_campo "$ID_C" motivo)"
            [[ "$MOTIVO_C" == "pid_reutilizado" ]] \
                || fallo "(c) motivo esperado pid_reutilizado, obtenido '$MOTIVO_C'."
        fi

        if kill -0 "$VICTIMA" 2>/dev/null; then
            ok "(c) el proceso ajeno $VICTIMA sigue vivo: no se señaló un PID no verificado."
        else
            fallo "(c) la recuperación mató al proceso ajeno $VICTIMA."
        fi

        kill -TERM "$VICTIMA" 2>/dev/null || true
        VICTIMA=""
    fi
fi

echo
echo "== (d) QUEUED sigue pendiente y se ejecuta =="
if ! detener_demonio; then
    fallo "(d) no se pudo detener el demonio antes de fabricar la fila."
else
    MARCADOR="$TEST_ROOT/queued-ejecutado"
    ID_D="$((ID_C + 1))"
    agregar_fila "{
        \"job_id\": $ID_D,
        \"pid\": 0,
        \"programa\": \"touch\",
        \"argumentos\": [\"$MARCADOR\"],
        \"status\": \"QUEUED\",
        \"tiempo_recepcion\": \"2026-01-01 00:00:00\",
        \"tiempo_inicio\": \"\",
        \"tiempo_terminacion\": \"\",
        \"codigo_salida\": -1
    }"

    disparar_recuperacion

    if ! esperar_estado "$ID_D" SUCCEEDED; then
        ESTADO_D="$(leer_campo "$ID_D" status 2>/dev/null || true)"
        fallo "(d) el Job QUEUED no terminó SUCCEEDED (estado: '$ESTADO_D')."
    else
        if [[ -f "$MARCADOR" ]]; then
            ok "(d) el Job QUEUED se conservó y se ejecutó (marcador creado)."
        else
            fallo "(d) el Job figura SUCCEEDED pero no se creó el marcador."
        fi
    fi
fi

echo
echo "== (e) estados terminales intactos y estado desconocido fail-closed =="
if ! detener_demonio; then
    fallo "(e) no se pudo detener el demonio antes de fabricar las filas."
else
    ID_E_SUC="$((ID_D + 1))"
    ID_E_FAL="$((ID_D + 2))"
    ID_E_CAN="$((ID_D + 3))"
    ID_E_INT="$((ID_D + 4))"
    ID_E_DES="$((ID_D + 5))"

    agregar_fila "{
        \"job_id\": $ID_E_SUC, \"pid\": 0, \"programa\": \"terminal-succeeded\",
        \"argumentos\": [], \"status\": \"SUCCEEDED\",
        \"tiempo_recepcion\": \"2026-01-01 00:00:00\",
        \"tiempo_inicio\": \"2026-01-01 00:00:01\",
        \"tiempo_terminacion\": \"2026-01-01 00:00:02\",
        \"codigo_salida\": 0, \"mensaje_error\": \"succeeded-intacto\"
    }"
    agregar_fila "{
        \"job_id\": $ID_E_FAL, \"pid\": 0, \"programa\": \"terminal-failed\",
        \"argumentos\": [], \"status\": \"FAILED\",
        \"tiempo_recepcion\": \"2026-01-01 00:00:00\",
        \"tiempo_inicio\": \"2026-01-01 00:00:01\",
        \"tiempo_terminacion\": \"2026-01-01 00:00:02\",
        \"codigo_salida\": 7, \"mensaje_error\": \"failed-intacto\"
    }"
    agregar_fila "{
        \"job_id\": $ID_E_CAN, \"pid\": 0, \"programa\": \"terminal-canceled\",
        \"argumentos\": [], \"status\": \"CANCELED\",
        \"tiempo_recepcion\": \"2026-01-01 00:00:00\",
        \"tiempo_inicio\": \"2026-01-01 00:00:01\",
        \"tiempo_terminacion\": \"2026-01-01 00:00:02\",
        \"codigo_salida\": -15, \"mensaje_error\": \"canceled-intacto\"
    }"
    agregar_fila "{
        \"job_id\": $ID_E_INT, \"pid\": 0, \"programa\": \"terminal-interrupted\",
        \"argumentos\": [], \"status\": \"INTERRUPTED\",
        \"tiempo_recepcion\": \"2026-01-01 00:00:00\",
        \"tiempo_inicio\": \"2026-01-01 00:00:01\",
        \"tiempo_terminacion\": \"2026-01-01 00:00:02\",
        \"codigo_salida\": -1, \"motivo\": \"caida\",
        \"mensaje_error\": \"interrupted-intacto\"
    }"
    agregar_fila "{
        \"job_id\": $ID_E_DES, \"pid\": 0, \"programa\": \"estado-desconocido\",
        \"argumentos\": [], \"status\": \"ESTADO_INEXISTENTE\",
        \"tiempo_recepcion\": \"2026-01-01 00:00:00\",
        \"tiempo_inicio\": \"\",
        \"tiempo_terminacion\": \"\",
        \"codigo_salida\": -1
    }"

    disparar_recuperacion

    for caso in \
        "$ID_E_SUC:SUCCEEDED:0:succeeded-intacto" \
        "$ID_E_FAL:FAILED:7:failed-intacto" \
        "$ID_E_CAN:CANCELED:-15:canceled-intacto" \
        "$ID_E_INT:INTERRUPTED:-1:interrupted-intacto"; do
        IFS=: read -r id esperado codigo mensaje <<<"$caso"
        estado="$(leer_campo "$id" status 2>/dev/null || true)"
        codigo_real="$(leer_campo "$id" codigo_salida 2>/dev/null || true)"
        mensaje_real="$(leer_campo "$id" mensaje_error 2>/dev/null || true)"
        terminacion="$(leer_campo "$id" tiempo_terminacion 2>/dev/null || true)"
        if [[ "$estado" == "$esperado" && "$codigo_real" == "$codigo" &&
              "$mensaje_real" == "$mensaje" &&
              "$terminacion" == "2026-01-01 00:00:02" ]]; then
            ok "(e) Job $id terminal intacto ($esperado)."
        else
            fallo "(e) Job $id alterado: estado='$estado', codigo='$codigo_real', mensaje='$mensaje_real', terminacion='$terminacion'."
        fi
    done

    if esperar_estado "$ID_E_DES" INTERRUPTED; then
        MOTIVO_DES="$(leer_campo "$ID_E_DES" motivo)"
        [[ "$MOTIVO_DES" == "estado_desconocido" ]] \
            || fallo "(e) motivo esperado estado_desconocido, obtenido '$MOTIVO_DES'."
        [[ "$MOTIVO_DES" == "estado_desconocido" ]] \
            && ok "(e) estado desconocido se reclasificó INTERRUPTED (fail-closed)."
    else
        fallo "(e) el estado desconocido no se reclasificó INTERRUPTED."
    fi

    SALIDA_FILTRO="$("$HERMES" filter status ESTADO_INEXISTENTE 2>&1)"
    RC_FILTRO=$?
    if (( RC_FILTRO == 1 )) && \
       printf '%s\n' "$SALIDA_FILTRO" | grep -q 'INTERRUPTED'; then
        ok "(e) el filtro rechaza estados fuera del dominio y anuncia INTERRUPTED."
    else
        fallo "(e) el filtro no rechazó ESTADO_INEXISTENTE como se esperaba (rc=$RC_FILTRO)."
    fi

    SALIDA_INT="$("$HERMES" filter status INTERRUPTED 2>&1 || true)"
    if printf '%s\n' "$SALIDA_INT" | grep -q '^Job ID:'; then
        ok "(e) el filtro acepta INTERRUPTED y lista las filas recuperadas."
    else
        fallo "(e) el filtro INTERRUPTED no listó ninguna fila."
    fi

    if "$HERMES" --help 2>&1 | grep -q 'INTERRUPTED'; then
        ok "(e) la ayuda documenta el estado INTERRUPTED."
    else
        fallo "(e) la ayuda no menciona INTERRUPTED."
    fi
fi

echo
echo "== (f) RNF-28: SIGKILL durante escrituras; jobs.json se conserva o recupera =="
if ! detener_demonio; then
    fallo "(f) no se pudo detener el demonio antes de la ráfaga."
else
    # Ráfaga: el demonio reserva y finaliza Jobs mientras se le mata. Cada
    # `hermes job` espera a que el demonio le asigne PID, así que hay
    # escrituras de almacenamiento en curso durante toda la ventana.
    (
        for _ in $(seq 1 40); do
            "$HERMES" job sh -c 'sleep 0.1' >/dev/null 2>&1 || true
        done
    ) &
    ENCOLADOR=$!

    sleep 0.4

    if ! matar_demonio; then
        fallo "(f) no se encontró el demonio para SIGKILL durante la ráfaga."
    else
        # La invariante que se prueba es la del archivo, no un instante
        # concreto de escritura: el rename atómico debe dejar siempre una
        # versión completa aunque el proceso muera a mitad.
        if parsea_arreglo "$DATA"; then
            ok "(f) jobs.json parsea como arreglo tras el SIGKILL en escrituras."
        else
            fallo "(f) jobs.json quedó ilegible tras el SIGKILL en escrituras."
        fi

        if [[ -e "$RESPALDO" ]]; then
            if parsea_arreglo "$RESPALDO"; then
                ok "(f) jobs.json.bak existe y parsea como arreglo."
            else
                fallo "(f) jobs.json.bak existe pero no parsea."
            fi
        else
            fallo "(f) no se creó jobs.json.bak junto a jobs.json."
        fi
    fi

    wait "$ENCOLADOR" 2>/dev/null || true

    # El encolador pudo arrancar un demonio nuevo tras la muerte del anterior.
    detener_demonio || true

    # Temporal huérfano con un PID que no puede pertenecer a ningún proceso
    # vivo de la prueba: la limpieza del arranque (paso 3) debe borrarlo.
    TEMPORAL_FALSO="$DATA.tmp.999999.7"
    printf 'basura' >"$TEMPORAL_FALSO"

    disparar_recuperacion

    if [[ ! -e "$TEMPORAL_FALSO" ]]; then
        ok "(f) el arranque eliminó el jobs.json.tmp.* huérfano."
    else
        fallo "(f) el temporal huérfano $TEMPORAL_FALSO sobrevivió al arranque."
        rm -f "$TEMPORAL_FALSO"
    fi

    if parsea_arreglo "$DATA"; then
        ok "(f) jobs.json sigue parseando después de la recuperación."
    else
        fallo "(f) jobs.json dejó de parsear después de la recuperación."
    fi

    # Fallback de lectura: con jobs.json corrupto, la cadena
    # jobs.json -> .bak -> error explícito debe responder y reparar el
    # archivo principal. ID_E_SUC es una fila terminal de (e) que ningún
    # worker posterior modifica, así que el respaldo debe contenerla.
    detener_demonio || true

    if [[ ! "${ID_E_SUC:-}" =~ ^[0-9]+$ ]]; then
        fallo "(f) no hay una fila terminal de (e) para probar el respaldo."
    else
        printf '{ esto no es json valido' >"$DATA"

        SALIDA_RESPALDO="$("$HERMES" filter id "$ID_E_SUC" 2>&1 || true)"
        if printf '%s\n' "$SALIDA_RESPALDO" | grep -q "Job ID: $ID_E_SUC"; then
            ok "(f) con jobs.json corrupto se leyó jobs.json.bak y se conservó la fila $ID_E_SUC."
        else
            fallo "(f) el fallback a jobs.json.bak no devolvió la fila $ID_E_SUC."
            printf '%s\n' "$SALIDA_RESPALDO"
        fi

        if parsea_arreglo "$DATA"; then
            ok "(f) jobs.json se reparó desde jobs.json.bak."
        else
            fallo "(f) jobs.json no se reparó tras leer jobs.json.bak."
        fi
    fi

    detener_demonio || true
fi

echo
echo "== (i) fila RUNNING con pid=0: motivo=sin_pid =="
if ! detener_demonio; then
    fallo "(i) no se pudo detener el demonio antes de fabricar la fila."
else
    ID_I="$(siguiente_id 2>/dev/null || true)"
    if [[ ! "$ID_I" =~ ^[0-9]+$ ]]; then
        fallo "(i) no se pudo calcular el siguiente job_id."
    else
        agregar_fila "{
            \"job_id\": $ID_I,
            \"pid\": 0,
            \"programa\": \"sin-pid\",
            \"argumentos\": [],
            \"status\": \"RUNNING\",
            \"tiempo_recepcion\": \"2026-01-01 00:00:00\",
            \"tiempo_inicio\": \"2026-01-01 00:00:01\",
            \"tiempo_terminacion\": \"\",
            \"codigo_salida\": -1
        }"

        disparar_recuperacion

        if ! esperar_estado "$ID_I" INTERRUPTED; then
            ESTADO_I="$(leer_campo "$ID_I" status 2>/dev/null || true)"
            fallo "(i) la fila RUNNING con pid=0 no quedó INTERRUPTED (estado: '$ESTADO_I')."
        else
            MOTIVO_I="$(leer_campo "$ID_I" motivo)"
            TERMINADO_I="$(leer_campo "$ID_I" proceso_terminado)"
            CODIGO_I="$(leer_campo "$ID_I" codigo_salida)"
            MENSAJE_I="$(leer_campo "$ID_I" mensaje_error)"

            [[ "$MOTIVO_I" == "sin_pid" ]] \
                || fallo "(i) motivo esperado sin_pid, obtenido '$MOTIVO_I'."
            [[ "$TERMINADO_I" == "false" ]] \
                || fallo "(i) proceso_terminado esperado false, obtenido '$TERMINADO_I'."
            [[ "$CODIGO_I" == "-1" ]] \
                || fallo "(i) codigo_salida esperado -1, obtenido '$CODIGO_I'."
            [[ "$MENSAJE_I" =~ PID\ verificable ]] \
                || fallo "(i) el mensaje no explica la falta de PID: '$MENSAJE_I'."

            if [[ "$MOTIVO_I" == "sin_pid" && "$TERMINADO_I" == "false" ]]; then
                ok "(i) sin_pid queda INTERRUPTED sin afirmar una terminación que no ocurrió."
            fi
        fi
    fi
fi

echo
echo "== (h) nietos que sobreviven a PDEATHSIG: el grupo sin líder se termina =="
if ! detener_demonio; then
    fallo "(h) no se pudo detener el demonio antes de crear el Job."
else
    SALIDA_H="$("$HERMES" job sh -c 'sleep 300 & wait' 2>&1)"
    printf '%s\n' "$SALIDA_H"
    ID_H="$(printf '%s\n' "$SALIDA_H" | sed -n 's/^job ID: *//p' | head -n 1)"
    PID_H="$(esperar_pid_job "$ID_H" || true)"

    if [[ ! "$ID_H" =~ ^[0-9]+$ ]] || [[ ! "$PID_H" =~ ^[0-9]+$ ]]; then
        fallo "(h) no se pudo crear el Job con nietos."
    else
        GRUPO_H="$PID_H"
        NIETO_H=""
        for _ in $(seq 1 100); do
            NIETO_H="$(hijos_de "$PID_H" | head -n 1)"
            [[ -n "$NIETO_H" ]] && break
            sleep 0.1
        done

        DEMONIO_H="$(find_scheduler_pid)"

        if [[ -z "$NIETO_H" || -z "$DEMONIO_H" ]]; then
            fallo "(h) no se encontró el nieto o el demonio (nieto='$NIETO_H')."
        else
            SID_H="$(campo_proc "$PID_H" 3)"
            PGRP_NIETO="$(campo_proc "$NIETO_H" 2)"
            SID_NIETO="$(campo_proc "$NIETO_H" 3)"

            if [[ "$SID_H" == "$DEMONIO_H" &&
                  "$PGRP_NIETO" == "$PID_H" &&
                  "$SID_NIETO" == "$SID_H" ]]; then
                ok "(h) el líder y su nieto comparten grupo y sesión privada (sid=$SID_H)."
            else
                fallo "(h) grupo/sesión inesperados: sid_lider='$SID_H', pgrp_nieto='$PGRP_NIETO', sid_nieto='$SID_NIETO', demonio='$DEMONIO_H'."
            fi

            if ! matar_demonio; then
                fallo "(h) no se pudo matar el demonio con SIGKILL."
            else
                LIDER_VIVO=1
                for _ in $(seq 1 100); do
                    if [[ ! -e "/proc/$PID_H" ]]; then
                        LIDER_VIVO=0
                        break
                    fi
                    sleep 0.1
                done

                if (( LIDER_VIVO != 0 )); then
                    fallo "(h) el líder $PID_H no murió tras SIGKILL."
                elif [[ ! -e "/proc/$NIETO_H" ]]; then
                    fallo "(h) el nieto $NIETO_H no sobrevivió; el caso no reproduce el hueco."
                else
                    ok "(h) el líder murió y el nieto $NIETO_H sobrevivió (hueco reproducido)."

                    disparar_recuperacion

                    if ! esperar_estado "$ID_H" INTERRUPTED; then
                        fallo "(h) el Job $ID_H no quedó INTERRUPTED."
                    else
                        MOTIVO_H="$(leer_campo "$ID_H" motivo)"
                        TERMINADO_H="$(leer_campo "$ID_H" proceso_terminado)"
                        SID_GUARDADO="$(leer_campo "$ID_H" sid)"

                        [[ "$MOTIVO_H" == "caida" ]] \
                            || fallo "(h) motivo esperado caida, obtenido '$MOTIVO_H'."
                        [[ "$TERMINADO_H" == "true" ]] \
                            || fallo "(h) proceso_terminado esperado true, obtenido '$TERMINADO_H'."
                        [[ "$SID_GUARDADO" == "$SID_H" ]] \
                            || fallo "(h) sid guardado '$SID_GUARDADO' != sid real '$SID_H'."

                        RESTANTES="$(miembros_grupo "$PID_H" "$SID_H")"
                        if [[ -n "$RESTANTES" ]]; then
                            fallo "(h) quedan miembros del grupo tras la recuperación: $RESTANTES"
                            printf '%s\n' "$RESTANTES" | while read -r pid; do
                                kill -KILL "$pid" 2>/dev/null || true
                            done
                        else
                            ok "(h) no queda ningún miembro vivo del grupo (proceso_terminado real)."
                        fi
                    fi
                fi
            fi
        fi
    fi
fi

echo
echo "== Auditoría F1: los Jobs no heredan los locks del demonio =="
SALIDA_FD="$("$HERMES" job sleep 30 2>&1)"
ID_FD="$(printf '%s\n' "$SALIDA_FD" | sed -n 's/^job ID: *//p' | head -n 1)"
PID_FD="$(esperar_pid_job "$ID_FD" || true)"

if [[ ! "$PID_FD" =~ ^[0-9]+$ ]]; then
    fallo "(F1) no se pudo crear el Job para auditar descriptores."
else
    DEMONIO_FD="$(find_scheduler_pid)"
    if [[ -z "$DEMONIO_FD" ]]; then
        fallo "(F1) no se encontró el demonio."
    else
        if readlink "/proc/$DEMONIO_FD/fd/"* 2>/dev/null | grep -qx "$LOCK"; then
            ok "(F1) el demonio sí conserva scheduler.lock."
        else
            fallo "(F1) el demonio no conserva scheduler.lock."
        fi
    fi

    FILTRADOS=0
    for descriptor in /proc/"$PID_FD"/fd/*; do
        [[ -e "$descriptor" ]] || continue
        destino="$(readlink "$descriptor" 2>/dev/null || true)"
        if [[ "$destino" == "$LOCK" || "$destino" == "$JOBS_LOCK" ||
              "$destino" == "$TEST_HOME"/.local/share/hermes/data/* ]]; then
            FILTRADOS=$((FILTRADOS + 1))
            echo "  descriptor heredado: $descriptor -> $destino"
        fi
    done

    if (( FILTRADOS == 0 )); then
        ok "(F1) el Job $PID_FD no heredó scheduler.lock, jobs.lock ni archivos de datos."
    else
        fallo "(F1) el Job heredó $FILTRADOS descriptor(es) del demonio."
    fi

    GRUPO_FD="$(perl -e '
        open my $f, "<", "/proc/$ARGV[0]/stat" or exit 1;
        local $/; my $l = <$f>;
        my $c = rindex($l, ")");
        my @c = split / /, substr($l, $c + 2);
        print $c[2];
    ' "$PID_FD")"
    if [[ "$GRUPO_FD" == "$PID_FD" ]]; then
        ok "(F1) el Job corre en su propio grupo (pgrp=pid=$PID_FD)."
    else
        fallo "(F1) el Job no tiene grupo propio (pgrp=$GRUPO_FD, pid=$PID_FD)."
    fi

    BOOT_GUARDADO="$(leer_campo "$ID_FD" boot_id)"
    INICIO_GUARDADO="$(leer_campo "$ID_FD" pid_inicio)"
    BOOT_ACTUAL="$(tr -d '\n' < /proc/sys/kernel/random/boot_id)"
    INICIO_ACTUAL="$(starttime_proc "$PID_FD")"
    if [[ "$BOOT_GUARDADO" == "$BOOT_ACTUAL" &&
          "$INICIO_GUARDADO" == "$INICIO_ACTUAL" ]]; then
        ok "(F1) la identidad persistida coincide con /proc (boot_id + starttime)."
    else
        fallo "(F1) identidad persistida incoherente: boot='$BOOT_GUARDADO'/'$BOOT_ACTUAL', inicio='$INICIO_GUARDADO'/'$INICIO_ACTUAL'."
    fi

    "$HERMES" cancel "$ID_FD" >/dev/null 2>&1 || true
    esperar_estado "$ID_FD" CANCELED || true
fi

echo
echo "== (g) clean data tras una caída: recupera antes de borrar y no arranca daemon =="
if ! detener_demonio; then
    fallo "(g) no se pudo detener el demonio antes de la caída."
else
    SALIDA_G="$("$HERMES" job sleep 30 2>&1)"
    printf '%s\n' "$SALIDA_G"
    ID_G="$(printf '%s\n' "$SALIDA_G" | sed -n 's/^job ID: *//p' | head -n 1)"
    PID_G="$(esperar_pid_job "$ID_G" || true)"

    if [[ ! "$ID_G" =~ ^[0-9]+$ ]] || [[ ! "$PID_G" =~ ^[0-9]+$ ]]; then
        fallo "(g) no se pudo crear el Job sleep activo."
    elif ! matar_demonio; then
        fallo "(g) no se encontró el demonio para SIGKILL."
    else
        # La fila queda RUNNING con un proceso que ya murió por PDEATHSIG:
        # exactamente el estado que antes bloqueaba `clean data` para siempre.
        ESTADO_G="$(leer_campo "$ID_G" status)"
        [[ "$ESTADO_G" == "RUNNING" ]] \
            || fallo "(g) la caída no dejó la fila RUNNING (estado '$ESTADO_G')."

        SALIDA_CLEAN_G="$("$HERMES" clean data 2>&1)"
        RC_G=$?
        printf '%s\n' "$SALIDA_CLEAN_G"

        if (( RC_G != 0 )); then
            fallo "(g) clean data devolvió $RC_G con una fila RUNNING obsoleta."
        else
            FILAS_G="$(cantidad_filas 2>/dev/null || echo '?')"
            if [[ "$FILAS_G" != "0" ]]; then
                fallo "(g) clean data no vació el historial (filas: $FILAS_G)."
            else
                ok "(g) clean data recuperó la caída y limpió el historial."
            fi
        fi

        if [[ -n "$(find_scheduler_pid)" ]]; then
            fallo "(g) clean data arrancó un daemon que no debía iniciar."
        else
            ok "(g) clean data no arrancó el scheduler."
        fi
    fi
fi

echo
if (( FALLOS != 0 )); then
    echo "FAIL: TC-022 detectó $FALLOS problema(s)."
    exit 1
fi

echo "PASS: TC-022 cubrió (a) apagado ordenado con motivo=apagado y sin huérfanos, (b) sin RUNNING tras SIGKILL, (c) no mata PIDs ajenos, (d) QUEUED se ejecuta, (e) terminales intactos y estado desconocido fail-closed, (f) jobs.json y .bak parsean y los .tmp se limpian tras SIGKILL en escrituras, (g) clean data recupera una caída antes de borrar y no arranca daemon, (h) grupo sin líder terminado por sid, (i) sin_pid sin afirmar terminación; además, los Jobs no heredan locks."
