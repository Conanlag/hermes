#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
TEST_HOME="$(mktemp -d)"
DATA="$TEST_HOME/.local/share/hermes/data/jobs.json"
CONFIG="$TEST_HOME/.local/share/hermes/data/config.json"
SCHEDULER_LOCK="$TEST_HOME/.local/share/hermes/data/scheduler.lock"
OUTPUT_DIR="$TEST_HOME/output"
mkdir -p "$OUTPUT_DIR"

cleanup() {
    if [[ -f "$DATA" ]]; then
        while IFS= read -r id; do
            [[ -n "$id" ]] && HOME="$TEST_HOME" "$HERMES" cancel "$id" >/dev/null 2>&1 || true
        done < <(perl -MJSON::PP -e '
            use strict;
            use warnings;
            local $/;
            my $jobs = decode_json(<>);
            print "$_->{job_id}\n"
                for grep {
                    ($_->{status} // "") eq "QUEUED" ||
                    ($_->{status} // "") eq "RUNNING"
                } @$jobs;
        ' "$DATA" 2>/dev/null || true)
    fi
    HOME="$TEST_HOME" "$HERMES" clean scheduler >/dev/null 2>&1 || true
    rm -rf "$TEST_HOME"
}
trap cleanup EXIT

if [[ ! -x "$HERMES" ]]; then
    echo "FAIL: no existe el ejecutable $HERMES. Compila Hermes antes de ejecutar la prueba."
    exit 1
fi

export HOME="$TEST_HOME"

"$HERMES" configmax 2
if [[ ! -f "$CONFIG" ]]; then
    echo "FAIL: configmax no creó config.json."
    exit 1
fi
if [[ -e "$SCHEDULER_LOCK" ]]; then
    echo "FAIL: configmax no debe iniciar el scheduler."
    exit 1
fi

perl -MJSON::PP -e '
    use strict;
    use warnings;
    my $path = shift;
    open my $file, "<", $path or die "No se pudo abrir $path: $!";
    local $/;
    my $config = decode_json(<$file>);
    $config->{extension_prueba} = "preservar";
    open my $out, ">", $path or die "No se pudo actualizar $path: $!";
    print {$out} encode_json($config);
' "$CONFIG"

"$HERMES" configmax 3
perl -MJSON::PP -e '
    use strict;
    use warnings;
    local $/;
    my $config = decode_json(<>);
    die "No se persistió trabajos_maximos=3\n"
        unless $config->{trabajos_maximos} == 3;
    die "Se perdió una clave de configuración no relacionada\n"
        unless $config->{extension_prueba} eq "preservar";
' "$CONFIG"

for valor in 0 65 invalido; do
    if "$HERMES" configmax "$valor" \
        >"$OUTPUT_DIR/invalid-$valor.txt" 2>&1; then
        echo "FAIL: se aceptó el valor inválido '$valor'."
        exit 1
    fi
done

for valor in 1 64; do
    "$HERMES" configmax "$valor"
    if ! perl -MJSON::PP -e '
        use strict;
        use warnings;
        my $wanted = shift;
        local $/;
        my $config = decode_json(<>);
        exit(($config->{trabajos_maximos} // 0) == $wanted ? 0 : 1);
    ' "$valor" "$CONFIG"; then
        echo "FAIL: no se persistió el valor válido de frontera '$valor'."
        exit 1
    fi
done

"$HERMES" configmax 3

if ! perl -MJSON::PP -e '
    use strict;
    use warnings;
    local $/;
    my $config = decode_json(<>);
    exit(($config->{trabajos_maximos} // 0) == 3 ? 0 : 1);
' "$CONFIG"; then
    echo "FAIL: un intento inválido modificó config.json."
    cat "$CONFIG"
    exit 1
fi

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
if ! grep -q 'La cola está llena' "$OUTPUT_DIR/over-capacity.txt"; then
    echo "FAIL: no se rechazó explícitamente el Job por capacidad."
    cat "$OUTPUT_DIR/over-capacity.txt"
    exit 1
fi

echo "PASS: configmax persistió el valor, conservó otras claves, rechazó valores inválidos y el scheduler ejecutó tres Jobs simultáneos sin superar el límite."
