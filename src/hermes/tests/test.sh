#!/bin/bash

set -u

HERMES="./hermes"

PASS=
FAIL=

pass() {
    echo "[PASS] $"
    PASS=$((PASS + ))
}

fail() {
    echo "[FAIL] $"
    FAIL=$((FAIL + ))
}

# ----------------------------------------
# Esperar a que un job alcance un estado
# ----------------------------------------

wait_for_status() {
    JOB_ID="$"
    EXPECTED_STATUS="$2"
    TIMEOUT=

    for ((i=; i<TIMEOUT; i++)); do
        RESULT=$("$HERMES" filter id "$JOB_ID" 2>/dev/null)

        if echo "$RESULT" | grep -q "$EXPECTED_STATUS"; then
            return 
        fi

        sleep 
    done

    return 
}

# ----------------------------------------
# Obtener ID del job
# ----------------------------------------

get_job_id() {
    echo "$" | grep "job ID:" | awk '{print $3}'
}

echo
echo "========================================"
echo "       PRUEBAS AUTOMATIZADAS HERMES"
echo "========================================"
echo

# ----------------------------------------
# . Verificar ejecutable
# ----------------------------------------

if [ -x "$HERMES" ]; then
    pass "El ejecutable hermes existe"
else
    fail "El ejecutable hermes no existe"
    exit 
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
# . Programa inexistente
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
# El proceso ejecutado por Hermes tendrá una duración de  segundos.
"$HERMES" job sleep  > "$TEMP_FILE" 2>&1 &

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

    # Solicitar la cancelación mientras sleep 
    # todavía debería estar ejecutándose.
    CANCEL_OUTPUT=$("$HERMES" cancel "$JOB_ID" 2>&1)
    CANCEL_EXIT=$?

    if [ "$CANCEL_EXIT" -eq  ]; then
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

if [ $? -eq  ]; then
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

if [ "$FAIL" -eq  ]; then
    echo "TODAS LAS PRUEBAS PASARON"
    exit 
else
    echo "ALGUNAS PRUEBAS FALLARON"
    exit 
fi

