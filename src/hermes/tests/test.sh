#!/bin/bash

set -u

HERMES="./hermes"

PASS=0
FAIL=0

pass() {
    echo "[PASS] $1"
    PASS=$((PASS + 1))
}

fail() {
    echo "[FAIL] $1"
    FAIL=$((FAIL + 1))
}

# ----------------------------------------
# Esperar a que un job alcance un estado
# ----------------------------------------

wait_for_status() {
    JOB_ID="$1"
    EXPECTED_STATUS="$2"
    TIMEOUT=10

    for ((i=0; i<TIMEOUT; i++)); do
        RESULT=$("$HERMES" filter id "$JOB_ID" 2>/dev/null)

        if echo "$RESULT" | grep -q "$EXPECTED_STATUS"; then
            return 0
        fi

        sleep 1
    done

    return 1
}

# ----------------------------------------
# Obtener ID del job
# ----------------------------------------

get_job_id() {
    echo "$1" | grep "job ID:" | awk '{print $3}'
}

echo
echo "========================================"
echo "       PRUEBAS AUTOMATIZADAS HERMES"
echo "========================================"
echo

# ----------------------------------------
# 1. Verificar ejecutable
# ----------------------------------------

if [ -x "$HERMES" ]; then
    pass "El ejecutable hermes existe"
else
    fail "El ejecutable hermes no existe"
    exit 1
fi

# ----------------------------------------
# 2. Versión
# ----------------------------------------

if "$HERMES" --version > /dev/null 2>&1; then
    pass "hermes --version"
else
    fail "hermes --version"
fi

# ----------------------------------------
# 3. Crear y ejecutar job exitoso
# ----------------------------------------

OUTPUT=$("$HERMES" job echo Hola 2>&1)
JOB_ID=$(get_job_id "$OUTPUT")

if [ -n "$JOB_ID" ]; then
    pass "Creación de job"

    if wait_for_status "$JOB_ID" "SUCCEEDED"; then
        pass "Job echo termina en SUCCEEDED"
    else
        fail "Job echo no termina en SUCCEEDED"
    fi
else
    fail "Creación de job"
fi

# ----------------------------------------
# 4. Ejecutar proceso real
# ----------------------------------------

OUTPUT=$("$HERMES" job sleep 2 2>&1)
JOB_ID=$(get_job_id "$OUTPUT")

if [ -n "$JOB_ID" ]; then
    pass "Creación de job sleep"

    if wait_for_status "$JOB_ID" "SUCCEEDED"; then
        pass "Proceso real sleep termina en SUCCEEDED"
    else
        fail "Proceso real sleep no termina en SUCCEEDED"
    fi
else
    fail "Creación de job sleep"
fi

# ----------------------------------------
# 5. Programa inexistente
# ----------------------------------------

OUTPUT=$("$HERMES" job programa_que_no_existe 2>&1)
JOB_ID=$(get_job_id "$OUTPUT")

if [ -n "$JOB_ID" ]; then
    pass "Acepta job con programa inexistente"

    if wait_for_status "$JOB_ID" "FAILED"; then
        pass "Programa inexistente termina en FAILED"
    else
        fail "Programa inexistente no termina en FAILED"
    fi
else
    fail "No se pudo crear job con programa inexistente"
fi

# ----------------------------------------
# 6. Cancelar proceso durante su ejecución
# ----------------------------------------

TEMP_FILE=$(mktemp)

# Lanzar Hermes en segundo plano.
# El proceso ejecutado por Hermes tendrá una duración de 10 segundos.
"$HERMES" job sleep 10 > "$TEMP_FILE" 2>&1 &

HERMES_PID=$!

# Esperar 2 segundos antes de solicitar la cancelación.
sleep 2

# Recuperar la salida generada por Hermes.
OUTPUT=$(cat "$TEMP_FILE")

# Esperar a que el comando Hermes termine.
wait "$HERMES_PID" 2>/dev/null

rm -f "$TEMP_FILE"

JOB_ID=$(get_job_id "$OUTPUT")

if [ -n "$JOB_ID" ]; then
    pass "Creación de job para cancelación"

    # Solicitar la cancelación mientras sleep 10
    # todavía debería estar ejecutándose.
    CANCEL_OUTPUT=$("$HERMES" cancel "$JOB_ID" 2>&1)
    CANCEL_EXIT=$?

    if [ "$CANCEL_EXIT" -eq 0 ]; then
        pass "Comando cancel ejecutado"

        if wait_for_status "$JOB_ID" "CANCELED"; then
            pass "Job cancelado termina en CANCELED"
        else
            fail "Job cancelado no termina en CANCELED"
        fi
    else
        echo "$CANCEL_OUTPUT"
        fail "Comando cancel"
    fi
else
    fail "No se pudo crear job para cancelación"
fi

# ----------------------------------------
# 7. Filter por status
# ----------------------------------------

OUTPUT=$("$HERMES" filter status SUCCEEDED 2>&1)

if [ $? -eq 0 ]; then
    pass "Filtro por status"
else
    fail "Filtro por status"
fi

# ----------------------------------------
# Resultado final
# ----------------------------------------

echo
echo "========================================"
echo "RESULTADO"
echo "========================================"
echo "Pruebas exitosas: $PASS"
echo "Pruebas fallidas: $FAIL"
echo "========================================"

if [ "$FAIL" -eq 0 ]; then
    echo "TODAS LAS PRUEBAS PASARON"
    exit 0
else
    echo "ALGUNAS PRUEBAS FALLARON"
    exit 1
fi

