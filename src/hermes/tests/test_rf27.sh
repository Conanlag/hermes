#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HERMES="$ROOT/hermes"
TEST_HOME="$(mktemp -d)"
DATA="$TEST_HOME/.local/share/hermes/data/jobs.json"
LOCK="$TEST_HOME/.local/share/hermes/data/scheduler.lock"
OUTPUT_DIR="$TEST_HOME/output"
mkdir -p "$OUTPUT_DIR"
SCHEDULER_PID=""

find_scheduler_pid() {
    python3 - "$LOCK" <<'PY'
import os
import pathlib
import sys

for process in pathlib.Path("/proc").glob("[0-9]*"):
    for descriptor in (process / "fd").glob("*"):
        try:
            if os.readlink(descriptor) == sys.argv[1]:
                print(process.name)
                raise SystemExit(0)
        except (FileNotFoundError, PermissionError):
            continue
PY
}

cleanup() {
    if [[ -f "$DATA" ]]; then
        mapfile -t ACTIVE_IDS < <(python3 - "$DATA" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as data_file:
    jobs = json.load(data_file)
for job in jobs:
    if job.get("status") in ("QUEUED", "RUNNING"):
        print(job["job_id"])
PY
)
        for id in "${ACTIVE_IDS[@]}"; do
            "$HERMES" cancel "$id" >/dev/null 2>&1 || true
        done
    fi

    if [[ -z "$SCHEDULER_PID" ]]; then
        SCHEDULER_PID="$(find_scheduler_pid)"
    fi
    if [[ -n "$SCHEDULER_PID" ]]; then
        kill "$SCHEDULER_PID" 2>/dev/null || true
        sleep 0.1
    fi
    rm -rf "$TEST_HOME"
}
trap cleanup EXIT

export HOME="$TEST_HOME"

declare -a PROCESS_IDS=()
for index in $(seq 1 8); do
    "$HERMES" job --request-id rf27-concurrent sleep 30 \
        >"$OUTPUT_DIR/request-$index.txt" 2>&1 &
    PROCESS_IDS+=("$!")
done

for pid in "${PROCESS_IDS[@]}"; do
    wait "$pid"
done

mapfile -t JOB_IDS < <(
    sed -n 's/^job ID: *//p' "$OUTPUT_DIR"/request-*.txt | sort -u
)

if [[ "${#JOB_IDS[@]}" -ne 1 ]]; then
    echo "FAIL: solicitudes simultaneas con la misma clave crearon Jobs diferentes."
    exit 1
fi

KEYED_COUNT="$(python3 - "$DATA" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as data_file:
    jobs = json.load(data_file)
print(sum(job.get("request_id") == "rf27-concurrent" for job in jobs))
PY
)"

if [[ "$KEYED_COUNT" -ne 1 ]]; then
    echo "FAIL: jobs.json debe contener exactamente un registro para la clave."
    exit 1
fi

if "$HERMES" job --request-id rf27-concurrent sleep 31 \
    >"$OUTPUT_DIR/conflict.txt" 2>&1; then
    echo "FAIL: la misma clave no debe aceptar un payload diferente."
    exit 1
fi

if ! grep -q "otro programa o argumentos" "$OUTPUT_DIR/conflict.txt"; then
    echo "FAIL: el conflicto no produjo un mensaje explicito."
    cat "$OUTPUT_DIR/conflict.txt"
    exit 1
fi

JOB_COUNT="$(python3 - "$DATA" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as data_file:
    print(len(json.load(data_file)))
PY
)"
if [[ "$JOB_COUNT" -ne 1 ]]; then
    echo "FAIL: el payload incompatible modifico jobs.json."
    exit 1
fi

"$HERMES" job sleep 30 >"$OUTPUT_DIR/unkeyed.txt" 2>&1
UNKEYED_ID="$(sed -n 's/^job ID: *//p' "$OUTPUT_DIR/unkeyed.txt")"
if [[ -z "$UNKEYED_ID" || "$UNKEYED_ID" == "${JOB_IDS[0]}" ]]; then
    echo "FAIL: las solicitudes sin clave deben conservar la semantica no idempotente."
    exit 1
fi

"$HERMES" cancel "${JOB_IDS[0]}" >/dev/null
"$HERMES" cancel "$UNKEYED_ID" >/dev/null

"$HERMES" job --request-id rf27-terminal true \
    >"$OUTPUT_DIR/terminal.txt" 2>&1
TERMINAL_ID="$(sed -n 's/^job ID: *//p' "$OUTPUT_DIR/terminal.txt")"

for _ in $(seq 1 50); do
    TERMINAL_STATUS="$(python3 - "$DATA" "$TERMINAL_ID" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as data_file:
    jobs = json.load(data_file)
print(next(job["status"] for job in jobs if job["job_id"] == int(sys.argv[2])))
PY
)"
    [[ "$TERMINAL_STATUS" == "SUCCEEDED" ]] && break
    sleep 0.1
done

if [[ "$TERMINAL_STATUS" != "SUCCEEDED" ]]; then
    echo "FAIL: el Job de comprobacion no alcanzo SUCCEEDED."
    exit 1
fi

BEFORE_TERMINAL="$(python3 - "$DATA" "$TERMINAL_ID" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as data_file:
    jobs = json.load(data_file)
job = next(job for job in jobs if job["job_id"] == int(sys.argv[2]))
print(job["status"], job["tiempo_terminacion"])
PY
)"
"$HERMES" job --request-id rf27-terminal true \
    >"$OUTPUT_DIR/terminal-retry.txt" 2>&1
RETRIED_TERMINAL_ID="$(
    sed -n 's/^job ID: *//p' "$OUTPUT_DIR/terminal-retry.txt"
)"
AFTER_TERMINAL="$(python3 - "$DATA" "$TERMINAL_ID" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as data_file:
    jobs = json.load(data_file)
job = next(job for job in jobs if job["job_id"] == int(sys.argv[2]))
print(job["status"], job["tiempo_terminacion"])
PY
)"

if [[ "$RETRIED_TERMINAL_ID" != "$TERMINAL_ID" ||
      "$AFTER_TERMINAL" != "$BEFORE_TERMINAL" ]]; then
    echo "FAIL: el reintento no preservo el Job terminal existente."
    exit 1
fi

SCHEDULER_PID="$(find_scheduler_pid)"
if [[ -z "$SCHEDULER_PID" ]]; then
    echo "FAIL: no se encontro el scheduler de prueba."
    exit 1
fi

echo "PASS: claves repetidas son atomicas, reutilizan el Job y rechazan payloads distintos."
