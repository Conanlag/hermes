#!/bin/bash
# TC-015: Usabilidad documental local (RF-17, RNF-21, RNF-23)
# Uso: bash verif/scripts/TC-015.sh
# Evidencia: verif/results/tc015.log

echo "=== Ejecutando TC-015 ==="

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO/src/hermes" || exit 1

mkdir -p "$REPO/verif/results"
LOG="$REPO/verif/results/tc015.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

# Aislamiento: HOME temporal por prueba. Hermes resuelve sus datos con
# $HOME (data_paths.h), asi que cada test usa su propia carpeta y no toca
# los datos reales ni depende del symlink src/hermes/data.
TEST_HOME="$(mktemp -d)"
export HOME="$TEST_HOME"
DATA="$HOME/.local/share/hermes/data/jobs.json"
LOCK="$HOME/.local/share/hermes/data/scheduler.lock"

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
    scheduler_pid="$(find_scheduler_pid)"
    if [[ -n "$scheduler_pid" ]]; then
        kill "$scheduler_pid" 2>/dev/null || true
        for _ in $(seq 1 20); do
            kill -0 "$scheduler_pid" 2>/dev/null || break
            sleep 0.1
        done
    fi
    rm -rf "$TEST_HOME"
}
trap cleanup EXIT

rm -f "$DATA"

# Paso 1: Compilación y ayuda de uso
make clean && make > /dev/null
echo "Compilación OK"

H1=$(./hermes 2>&1); C1=$?
H2=$(./hermes --version 2>&1); C2=$?
H3=$(./hermes --help 2>&1); C3=$?

# Sin argumentos el binario muestra el banner "HERMES" y sale con 0; la guia
# completa (uso, comandos, estados, ejemplos y codigos de salida) esta en --help.
if [ $C1 -eq 0 ] && echo "$H1" | grep -qi "hermes" \
   && [ $C2 -eq 0 ] && echo "$H2" | grep -qi "version" \
   && [ $C3 -eq 0 ] \
   && echo "$H3" | grep -qi "uso" \
   && echo "$H3" | grep -qi "comando" \
   && echo "$H3" | grep -qi "estados" \
   && echo "$H3" | grep -qi "ejemplos" \
   && echo "$H3" | grep -qi "codigos de salida"; then
    echo "Paso 1 OK (Ayuda, versión y --help correctos)"
else
    echo "Paso 1 FAIL (Problema con mensajes de ayuda o códigos de salida)"
    exit 1
fi

# Paso 2: Códigos de salida (0 para éxito, 1 para error)
./hermes job echo hola > /dev/null 2>&1; C_JOB=$?
./hermes foo > /dev/null 2>&1; C_FOO=$?

if [ $C_JOB -eq 0 ] && [ $C_FOO -eq 1 ]; then
    echo "Paso 2 OK (Códigos 0 y 1 devueltos correctamente)"
else
    echo "Paso 2 FAIL (Códigos devueltos: JOB=$C_JOB, FOO=$C_FOO)"
    exit 1
fi

# Paso 3: Mensaje con causa (Causa y acción, sin buscar palabras fantasma)
M3=$(./hermes filter id abc 2>&1); C3_ERR=$?
if [ $C3_ERR -eq 1 ] && echo "$M3" | grep -qi "mal formado" && echo "$M3" | grep -qi "entero positivo"; then
    echo "Paso 3 OK (Mensaje de error indica causa y acción sugerida)"
else
    echo "Paso 3 FAIL (Mensaje devuelto: $M3)"
    exit 1
fi

# Paso 4: Mensaje inexistente
M4=$(./hermes cancel 999999 2>&1); C4_ERR=$?
if [ $C4_ERR -eq 1 ] && echo "$M4" | grep -qi "no existe"; then
    echo "Paso 4 OK (Mensaje de inexistencia correcto)"
else
    echo "Paso 4 FAIL (Mensaje devuelto: $M4)"
    exit 1
fi

# Paso 5: Guía documental
if [ -f "$REPO/README.md" ]; then
    echo "Paso 5 OK (Guía de usuario README.md detectada para flujo manual)"
else
    echo "Paso 5 FAIL (No se encontró la guía de usuario)"
    exit 1
fi

# Veredicto final
echo "[PASS] TC-015"
exit 0