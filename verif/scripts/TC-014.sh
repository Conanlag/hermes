#!/bin/bash
# TC-014: Construcción reproducible desde clon limpio (RNF-01, RNF-02, RNF-03)
# Uso (WSL): bash verif/scripts/TC-014.sh   (desde la raíz del repo)
# Evidencia: verif/results/tc014.log
# Requiere: Linux/WSL con git, g++ y make. No usa sudo en ningún paso.

echo "=== Ejecutando TC-014 ==="

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$REPO/verif/results"
LOG="$REPO/verif/results/tc014.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

FALLOS=0

# Paso 1: clon limpio (origen del propio repo o su remoto)
ORIGEN=$(git -C "$REPO" remote get-url origin 2>/dev/null || echo "$REPO")
CLON=/tmp/hermes-limpio-tc014
rm -rf "$CLON"
if git clone "$ORIGEN" "$CLON" 2>&1; then
    echo "Paso 1 OK (clon limpio en $CLON)"
else
    echo "Paso 1 FAIL (no se pudo clonar $ORIGEN)"
    FALLOS=1
fi

# Paso 2: dependencias documentadas
for DEP in "g++ --version" "make --version"; do
    if $DEP > /dev/null 2>&1; then
        echo "Paso 2 OK ($DEP presente)"
    else
        echo "Paso 2 FAIL (falta: $DEP)"
        FALLOS=1
    fi
done

# Paso 3: construcción desde cero
cd "$CLON/ppl/src/hermes" 2>/dev/null || cd "$CLON/src/hermes" || { echo "Paso 3 FAIL (estructura inesperada)"; FALLOS=1; }
if [ $FALLOS -eq 0 ]; then
    make clean && make
    if [ $? -eq 0 ] && [ -x ./hermes ]; then
        echo "Paso 3 OK (binario ./hermes generado)"
    else
        echo "Paso 3 FAIL (compilación)"
        FALLOS=1
    fi
fi

# Paso 4: usuario normal, sin sudo en todo el script
if [ "$(whoami)" != "root" ] && [ "$(id -u)" -ne 0 ]; then
    echo "Paso 4 OK (usuario $(whoami), sin root)"
else
    echo "Paso 4 FAIL (corriendo como root)"
    FALLOS=1
fi

# Paso 5: humo funcional
if ./hermes --version > /dev/null 2>&1; then
    echo "Paso 5 OK (--version, código 0)"
else
    echo "Paso 5 FAIL (--version)"
    FALLOS=1
fi
HID=$(./hermes job echo hola 2>&1 | grep -oP 'job ID: \K[0-9]+')
if [ -n "$HID" ] && ./hermes filter id "$HID" > /dev/null 2>&1; then
    echo "Paso 5 OK (job $HID + filter, código 0)"
else
    echo "Paso 5 FAIL (job/filter)"
    FALLOS=1
fi

# Paso 6: install sin root (ruta de usuario)
if make install > /dev/null 2>&1 && [ -x "$HOME/.local/bin/hermes" ]; then
    echo "Paso 6 OK (instalado en \$HOME/.local/bin sin sudo)"
else
    echo "Paso 6 FAIL (make install)"
    FALLOS=1
fi

rm -rf "$CLON"

if [ $FALLOS -eq 0 ]; then
    echo "[PASS] TC-014"
    exit 0
else
    echo "[FAIL] TC-014"
    exit 1
fi
