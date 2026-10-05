#!/bin/bash
# TC-008: Aislamiento de fallos y comandos inválidos locales (RNF-08, RNF-09)
# Uso: bash verif/scripts/TC-008.sh
# Evidencia: verif/results/tc008.log

echo "=== Ejecutando TC-008 ==="

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO/src/hermes" || exit 1

mkdir -p "$REPO/verif/results"
LOG="$REPO/verif/results/tc008.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

rm -f data/jobs.json

# Paso 1: Compilación limpia
make clean && make > /dev/null
echo "Paso 1 OK (compilación limpia)"

# Precondición: Crear el trabajo testigo que debe sobrevivir a toda la prueba
./hermes job echo testigo-principal > /tmp/h_t1.txt
T1=$(grep -oP 'job ID: \K[0-9]+' /tmp/h_t1.txt)

# Paso 2: Comandos inválidos (Evaluación individual para evitar word-splitting)
# 1. Comando que no existe
S1=$(./hermes foo 2>&1); C1=$?
# 2. Argumentos mal formados
S2=$(./hermes filter id abc 2>&1); C2=$?
# 3. Programa vacío
S3=$(./hermes job "" 2>&1); C3=$?
# 4. ID inexistente
S4=$(./hermes cancel 999999 2>&1); C4=$?

if [ $C1 -eq 1 ] && [ $C2 -eq 1 ] && [ $C3 -eq 1 ] && [ $C4 -eq 1 ]; then
    echo "Paso 2 OK (4 solicitudes inválidas rechazadas limpiamente con código 1)"
else
    echo "Paso 2 FAIL (Códigos de salida no coinciden con 1)"
    exit 1
fi

# Paso 3: Confirmar operatividad tras los fallos
./hermes job echo testigo-post > /tmp/h_t2.txt
T2=$(grep -oP 'job ID: \K[0-9]+' /tmp/h_t2.txt)
if [ -n "$T2" ]; then
    echo "Paso 3 OK (Servicio vivo tras rechazos, job $T2 creado con éxito)"
else
    echo "Paso 3 FAIL (El servicio colapsó y no pudo crear más trabajos)"
    exit 1
fi

# Paso 4: Fallo normal aislado (Comando false)
./hermes job false > /tmp/h_f.txt
F=$(grep -oP 'job ID: \K[0-9]+' /tmp/h_f.txt)
sleep 2

ST_F=$(./hermes filter id "$F")
if echo "$ST_F" | grep -q "Estado: FAILED"; then
    echo "Paso 4 OK (Trabajo 'false' se aisló y terminó en FAILED)"
else
    echo "Paso 4 FAIL (No se registró el FAILED)"
    exit 1
fi

# Paso 5: Programa inexistente
./hermes job programa_que_no_existe_xyz > /tmp/h_x.txt
X=$(grep -oP 'job ID: \K[0-9]+' /tmp/h_x.txt)
sleep 2

ST_X=$(./hermes filter id "$X")
if echo "$ST_X" | grep -q "Estado: FAILED"; then
    echo "Paso 5 OK (Programa inválido se aisló y terminó en FAILED)"
else
    echo "Paso 5 FAIL (No se registró el FAILED del programa inexistente)"
    exit 1
fi

# Paso 6: Señal aislada y validación del testigo principal
./hermes job sleep 30 > /tmp/h_s.txt
S=$(grep -oP 'job ID: \K[0-9]+' /tmp/h_s.txt)
./hermes cancel "$S" > /dev/null
sleep 2

ST_S=$(./hermes filter id "$S")
ST_T1=$(./hermes filter id "$T1")

if echo "$ST_S" | grep -q "Estado: CANCELED" && echo "$ST_T1" | grep -q "Estado: SUCCEEDED"; then
    echo "Paso 6 OK (Señal aislada en CANCELED. Testigo principal quedó intacto)"
else
    echo "Paso 6 FAIL (Fallo en aislamiento de cancelación o testigo principal fue afectado)"
    exit 1
fi

# Veredicto final
echo "[PASS] TC-008"
exit 0