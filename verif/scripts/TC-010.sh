#!/usr/bin/env bash
# RF-18, RF-19, RNF-26 - Flujo remoto completo en LAN/VPN.
# TC-010: operaciones reales, equivalencia local y evidencia entre equipos.
# Modo: ambos. Cada variante devuelve 3 si falta la evidencia del otro modo.
set -euo pipefail
umask 077
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
EVIDENCIA="$REPO/verif/results/results_TC-010.md"
for herramienta in python3 ss mktemp tee; do
    command -v "$herramienta" >/dev/null || { echo "ENTORNO: falta $herramienta"; exit 2; }
done
[[ -x "$REPO/src/hermes/hermes" ]] || { echo 'ENTORNO: compile con make -C src/hermes hermes'; exit 2; }
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/hermes-TC-010.XXXXXX")"
export HOME="$TEST_ROOT/home" XDG_CONFIG_HOME="$TEST_ROOT/xdg"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$REPO/verif/results"
cerrar() {
    local estado=$?
    trap - EXIT
    printf '\nCodigo de salida TC-010: %s\n```\n' "$estado"
    rm -rf -- "$TEST_ROOT"
    exit "$estado"
}
trap cerrar EXIT
{
    printf '\n## Ejecucion: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf -- '- Commit: %s\n' "$(git -C "$REPO" rev-parse --short HEAD)"
    if [[ -n "$(git -C "$REPO" status --porcelain)" ]]; then
        printf -- '- Arbol: con cambios locales\n'
    else
        printf -- '- Arbol: limpio\n'
    fi
    printf '\n```text\n'
} >>"$EVIDENCIA"
exec > >(tee -a "$EVIDENCIA") 2>&1
python3 - "$REPO" "$TEST_ROOT" <<'PY'
import ipaddress
import json
import os
from pathlib import Path
import re
import signal
import socket
import subprocess
import sys
import time
import uuid

repo, root = map(Path, sys.argv[1:])
binary = str(repo / 'src/hermes/hermes')
host = os.environ.get('HERMES_TEST_HOST', '127.0.0.1')
mode = 'local' if host in ('localhost', '127.0.0.1') else 'remoto'
label = os.environ.get('HERMES_TEST_CLIENT_ID', 'PC-B')
token = 'tc010-' + uuid.uuid4().hex
terminal = {'SUCCEEDED', 'FAILED', 'CANCELED', 'INTERRUPTED'}
servers, environments, tracked = [], [], []
port = None
owned_port = False
result_code = 1

class EnvironmentErrorTC(Exception):
    pass

def require(condition, message):
    if not condition:
        raise AssertionError(message)

def allowed(address):
    address = ipaddress.IPv4Address(address)
    return any(address in ipaddress.IPv4Network(net) for net in (
        '127.0.0.0/8', '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16', '100.64.0.0/10'))

def config(env, **changes):
    folder = Path(env['XDG_CONFIG_HOME']) / 'hermes'
    folder.mkdir(parents=True, exist_ok=True)
    values = dict(interfaz='127.0.0.1', puerto=port, trabajos_maximos=1, max_cola=8)
    values.update(changes)
    (folder / 'config.json').write_text(json.dumps(values))

def environment(name):
    env = dict(os.environ, HOME=str(root / name / 'home'), XDG_CONFIG_HOME=str(root / name / 'xdg'))
    Path(env['HOME']).mkdir(parents=True)
    config(env)
    environments.append(env)
    return env

def cli(env, args, expected=0, show=True):
    p = subprocess.run([binary] + list(map(str, args)), env=env, text=True,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=35)
    if show:
        print('$ hermes ' + ' '.join(map(str, args)), flush=True)
        print(p.stdout.rstrip(), flush=True)
    if expected is not None:
        require(p.returncode == expected, f'CLI devolvio {p.returncode}, esperado {expected}: {p.stdout}')
    return p

def rpc(operation, params=None, rid=None):
    rid = rid or token + '-' + uuid.uuid4().hex[:8]
    message = dict(version=1, request_id=rid, operation=operation, params=params or {})
    with socket.create_connection((host, port), timeout=20) as s:
        s.sendall((json.dumps(message) + '\n').encode())
        data = b''
        while b'\n' not in data:
            chunk = s.recv(4096)
            require(bool(chunk), 'Servidor cerro sin respuesta JSON')
            data += chunk
            require(len(data) <= 262145, 'Respuesta excedida')
    response = json.loads(data.split(b'\n', 1)[0])
    require(response.get('version') == 1 and response.get('request_id') == rid,
            'Sobre de respuesta sin version/ID esperado')
    return response

def query(env, jid, remote):
    if remote:
        answer = rpc('query', {'job_id': jid})
        require(answer.get('ok') is True, f'query {jid}: {answer}')
        return answer['result']
    rows = json.loads((Path(env['HOME']) / '.local/share/hermes/data/jobs.json').read_text())
    return next(row for row in rows if row['job_id'] == jid)

def wait(env, jid, status, remote):
    deadline = time.monotonic() + 30
    while True:
        job = query(env, jid, remote)
        if job['status'] == status:
            return job
        require(job['status'] not in terminal, f'Job {jid}: {job["status"]}, esperado {status}')
        require(time.monotonic() < deadline, f'Job {jid} no alcanzo {status} en 30 s')
        time.sleep(.1)

def admit(env, program, arguments, rid, remote):
    prefix = ['red', 'job', host] if remote else ['job']
    p = cli(env, prefix + ['--request-id', rid, program] + arguments, expected=None)
    match = re.search(r'^job ID: ([0-9]+)\s*$', p.stdout, re.M)
    require(match is not None, f'Admision sin job ID: {p.stdout}')
    jid = int(match[1])
    # Registrar antes de cualquier otra asercion para poder limpiar tras un fallo.
    tracked.append((env, jid, remote))
    # El CLI local puede observar el FAILED de false antes de devolver la admision.
    require(p.returncode == 0 or (not remote and program == 'false' and p.returncode == 1),
            f'Admision rechazada: {p.stdout}')
    return jid, p.stdout

def detail(env, jid, remote, status):
    prefix = ['red', 'filter', host] if remote else ['filter']
    text = cli(env, prefix + ['id', jid]).stdout
    require(f'Job ID: {jid}\n' in text and f'Estado: {status}' in text, 'Detalle CLI incompleto')
    return text

def cancel(env, jid, remote, expected=0):
    prefix = ['red', 'cancel', host] if remote else ['cancel']
    return cli(env, prefix + [jid], expected=expected)

def flow(env, remote):
    name = 'remoto' if remote else 'local'
    records = []
    for program, state, code in [('true', 'SUCCEEDED', 0), ('false', 'FAILED', 1)]:
        jid, _ = admit(env, program, [], token + '-' + name + '-' + program, remote)
        job = wait(env, jid, state, remote)
        require(job['programa'] == program and job['argumentos'] == [] and job['codigo_salida'] == code,
                'Resultado del programa incoherente')
        require(all(job.get(k) for k in ('tiempo_recepcion', 'tiempo_inicio', 'tiempo_terminacion')),
                'Tiempos de trabajo terminal incompletos')
        detail(env, jid, remote, state)
        records.append((state, code))
        if remote:
            print(f'PASS V{2 if program == "true" else 3}/AC{2 if program == "true" else 3}: {program} -> {state}, codigo {code}')
    rid = token + '-' + name + '-sleep'
    jid, _ = admit(env, 'sleep', ['120'], rid, remote)
    wait(env, jid, 'RUNNING', remote)
    detail(env, jid, remote, 'RUNNING')
    prefix = ['red', 'filter', host] if remote else ['filter']
    for kind, value in [('status', 'RUNNING'), ('programa', 'sleep')]:
        listing = cli(env, prefix + [kind, value]).stdout
        require(re.search(rf'^Job ID: {jid}\s*$', listing, re.M), 'Listado no incluye el trabajo propio')
    if remote:
        print('PASS V4/AC4: RUNNING y filtros por id, estado y programa')
    duplicated, text = admit(env, 'sleep', ['120'], rid, remote)
    require(duplicated == jid and 'Solicitud duplicada' in text, 'Deduplicacion incorrecta')
    job_prefix = ['red', 'job', host] if remote else ['job']
    rejected = cli(env, job_prefix + ['--request-id', rid, 'sleep', '119'], expected=1)
    if remote:
        rejection = rpc('submit', {'programa': 'sleep', 'argumentos': ['119']}, rid=rid)
        require(rejection.get('ok') is False and rejection.get('error') == 'JOB_OPERATION_FAILED',
                f'Conflicto de request_id sin codigo esperado: {rejection}')
        print('  Rechazo JSON:', json.dumps(rejection))
        print('PASS V5/AC5: duplicado reutiliza ID; argumentos distintos rechazados')
    cancel(env, jid, remote)
    wait(env, jid, 'CANCELED', remote)
    detail(env, jid, remote, 'CANCELED')
    rejected = cancel(env, jid, remote, expected=1)
    if remote:
        rejection = rpc('cancel', {'job_id': jid})
        require(rejection.get('ok') is False and rejection.get('error') == 'NOT_CANCELABLE',
                f'Rechazo terminal inesperado: {rejection}')
        print('  Rechazo JSON:', json.dumps(rejection))
        print('PASS V6/AC6: cancelacion RUNNING confirmada y rechazo terminal')
    records.append(('CANCELED', None))
    return records

def free_port():
    with socket.socket() as s:
        s.bind(('127.0.0.1', 0))
        return s.getsockname()[1]

def listening(number):
    p = subprocess.run(['ss', '-H', '-ltn', 'sport', '=', ':' + str(number)],
                       capture_output=True, text=True, timeout=5)
    require(p.returncode == 0, 'ss no pudo consultar los sockets')
    return bool(p.stdout.strip())

def server(env, tag):
    log = root / (tag + '.log')
    with log.open('w') as output:
        p = subprocess.Popen([binary, 'red', 'start'], env=env, stdout=output, stderr=subprocess.STDOUT)
    servers.append((p, log))
    return p, log

def start(env):
    global port, owned_port
    for attempt in range(3):
        if not os.environ.get('HERMES_TEST_PORT'):
            port = free_port()
            config(env)
        if listening(port):
            raise EnvironmentErrorTC(f'Puerto {port} ocupado; no se modifica su propietario')
        p, log = server(env, 'server-' + str(attempt))
        deadline = time.monotonic() + 10
        while p.poll() is None and time.monotonic() < deadline:
            if 'Hermes Red escuchando en' in log.read_text() and listening(port):
                owned_port = True
                return
            time.sleep(.1)
        print(log.read_text())
        if p.poll() is None:
            p.terminate()
            p.wait(timeout=8)
        if os.environ.get('HERMES_TEST_PORT'):
            break
    raise AssertionError('Servidor propio no llego a escuchar')

def queued(env, remote):
    blocker, _ = admit(env, 'sleep', ['120'], token + '-block-' + str(remote), remote)
    wait(env, blocker, 'RUNNING', remote)
    jid, _ = admit(env, 'sleep', ['120'], token + '-queue-' + str(remote), remote)
    require(query(env, jid, remote)['status'] == 'QUEUED', 'No se genero trabajo en cola')
    cancel(env, jid, remote)
    job = wait(env, jid, 'CANCELED', remote)
    require(not job.get('tiempo_inicio') and job.get('pid', 0) == 0, 'Trabajo en cola llego a ejecutarse')
    cancel(env, blocker, remote)
    wait(env, blocker, 'CANCELED', remote)

def persisted(env):
    data = Path(env['HOME']) / '.local/share/hermes/data'
    jobs = json.loads((data / 'jobs.json').read_text())
    ids = [j['job_id'] for j in jobs]
    require(len(set(ids)) == len(ids), 'IDs persistidos duplicados')
    requests = [j.get('request_id') for j in jobs]
    require(len(set(requests)) == len(requests), 'Solicitudes persistidas duplicadas')
    events = [json.loads(line) for line in (data / 'events.jsonl').read_text().splitlines() if line]
    for job in jobs:
        require(job['status'] in terminal, 'Trabajo no terminal al verificar persistencia')
        require(job.get('propietario_remoto') == 'tcp-tc010-local' and job.get('tipo_ejecucion') == 'remote',
                'Propietario/tipo remoto incoherente')
        related = [e for e in events if str(e.get('job_id')) == str(job['job_id'])]
        require(len(related) >= 2, 'Faltan eventos de creacion/transicion correlacionados')
    print('PASS V9/AC9: jobs.json integro, propiedad, unicidad y eventos correlacionados')

def policy():
    bad = environment('invalid-network')
    net = Path(bad['HOME']) / '.local/share/hermes/network'
    net.mkdir(parents=True)
    (net / 'network.json').write_text(json.dumps({'habilitada': True, 'clientes': [{
        'id': 'invalid', 'direcciones': ['203.0.113.1'], 'operaciones': ['submit'], 'programas': ['true']}]}))
    p = cli(bad, ['red', 'start'], expected=1)
    require('IPv4' in p.stdout, 'Configuracion publica sin rechazo esperado')
    for address in ('0.0.0.0', '203.0.113.1'):
        safe = environment('fallback-' + address)
        config(safe, interfaz=address, puerto=free_port())
        p, log = server(safe, 'fallback-' + address)
        deadline = time.monotonic() + 5
        while 'Hermes Red escuchando en' not in log.read_text():
            require(p.poll() is None and time.monotonic() < deadline, log.read_text())
            time.sleep(.05)
        require('Hermes Red escuchando en 127.0.0.1:' in log.read_text(), 'Fallback fuera de loopback')
        p.terminate()
        require(p.wait(timeout=8) == 0, 'Fallo de cierre de variante fallback')
        fallback_port = json.loads((Path(safe['XDG_CONFIG_HOME']) / 'hermes/config.json').read_text())['puerto']
        require(not listening(fallback_port), 'Puerto fallback sin liberar')
    cli(bad, ['red', 'job', '203.0.113.1', 'true'], expected=1)
    print('PASS V10/AC10: destinos publicos rechazados; interfaz invalida solo usa loopback')

def interrupted(signum, frame):
    raise KeyboardInterrupt('Interrumpido por senal ' + str(signum))

signal.signal(signal.SIGTERM, interrupted)
try:
    require(re.fullmatch(r'[A-Za-z0-9._:-]{1,128}', label), 'ID de cliente invalido')
    try:
        require(host == 'localhost' or allowed(host), 'Destino fuera de loopback/LAN privada/VPN')
        requested = os.environ.get('HERMES_TEST_PORT')
        if mode == 'remoto' and not requested:
            raise EnvironmentErrorTC('Falta HERMES_TEST_PORT en modo remoto')
        port = int(requested) if requested else free_port()
        if not 1024 <= port <= 65535:
            raise ValueError('puerto fuera de 1024..65535')
    except (ValueError, AssertionError) as exc:
        raise EnvironmentErrorTC(str(exc)) from exc
    print(f'Modo: {mode}\nDestino solicitado: {host}:{port}\nCliente (etiqueta): {label}\nEjecucion: {token}', flush=True)
    env = environment('client-server')
    if mode == 'local':
        net = Path(env['HOME']) / '.local/share/hermes/network'
        net.mkdir(parents=True)
        (net / 'network.json').write_text(json.dumps({'habilitada': True, 'clientes': [{
            'id': label, 'ambito_trabajos': 'tc010-local', 'direcciones': ['127.0.0.1'],
            'operaciones': ['submit', 'query', 'list', 'cancel'], 'programas': ['true', 'false', 'sleep']}]}))
        start(env)
        print(f'Destino efectivo: {host}:{port}')
    try:
        answer = rpc('ping')
    except OSError as exc:
        if mode == 'remoto':
            raise EnvironmentErrorTC('PC A inalcanzable; revisar escucha, proxy y firewall') from exc
        raise
    require(answer.get('ok') is True and answer.get('result', {}).get('message') == 'pong', 'ping invalido')
    print('PASS V1/AC1: configuracion aislada y ping JSON correlacionado')
    remote_records = flow(env, True)
    if mode == 'local':
        baseline = environment('baseline')
        require(flow(baseline, False) == remote_records, 'Diferencias de resultado local/remoto')
        print('PASS V7/AC7: equivalencia de resultados, filtros, duplicados y cancelacion')
        queued(env, True)
        queued(baseline, False)
        print('PASS V8/AC8: cancelacion QUEUED local y remota sin ejecucion')
        persisted(env)
        policy()
        print('SKIP: AC11 recorrido entre equipos LAN/VPN (modo local)')
    else:
        print('PASS V11/AC11: flujo desde el cliente al destino LAN/VPN indicado por el operador')
        print('AVISO: conservar topologia PC B -> PC A; el script no certifica que sean equipos distintos')
        for ac in (7, 8, 9, 10, 12):
            print(f'SKIP: AC{ac} requiere controlar/inspeccionar servidor propio (modo remoto)')
    result_code = 3
except EnvironmentErrorTC as exc:
    print('ENTORNO: ' + str(exc), flush=True)
    result_code = 2
except PermissionError as exc:
    print(f'ENTORNO: permisos insuficientes para la prueba: {exc}', flush=True)
    result_code = 2
except BaseException as exc:
    print(f'FAIL: {type(exc).__name__}: {exc}', flush=True)
    result_code = 1
finally:
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    signal.signal(signal.SIGINT, signal.SIG_IGN)
    try:
        # Solo se cancelan IDs creados por esta ejecucion. Nunca se borra historial remoto.
        for own_env, jid, remote in dict.fromkeys((e['HOME'], j, r) for e, j, r in tracked):
            actual = next(e for e in environments if e['HOME'] == own_env)
            job = query(actual, jid, remote)
            if job['status'] not in terminal:
                cancel(actual, jid, remote)
                # Si el scheduler remoto esta caido, no se promete limpieza exitosa.
                wait(actual, jid, 'CANCELED', remote)
    except BaseException as exc:
        print(f'FALLO DE LIMPIEZA de trabajos propios: {exc}')
        result_code = 1
    for p, log in servers:
        try:
            if p.poll() is None:
                p.terminate()
                try:
                    p.wait(timeout=8)
                except subprocess.TimeoutExpired:
                    p.kill()
                    p.wait(timeout=5)
                    raise AssertionError('Servidor requirio SIGKILL')
            # Las variantes de servidor iniciadas correctamente deben cerrar ordenadamente.
            if 'Hermes Red escuchando en' in log.read_text():
                require(p.returncode == 0 and 'Hermes Red detenido' in log.read_text(), 'Cierre no ordenado')
        except BaseException as exc:
            print(f'FALLO DE LIMPIEZA servidor: {exc}')
            result_code = 1
    for own_env in environments:
        if (Path(own_env['HOME']) / '.local/share/hermes/data/scheduler.lock').exists():
            try:
                # clean scheduler usa el lock de este HOME, nunca procesos por nombre.
                cli(own_env, ['clean', 'scheduler'])
            except BaseException as exc:
                print(f'FALLO DE LIMPIEZA scheduler: {exc}')
                result_code = 1
    try:
        if owned_port:
            require(not listening(port), 'Puerto principal sigue ocupado')
        homes = {e['HOME'] for e in environments}
        for process in Path('/proc').glob('[0-9]*'):
            if int(process.name) == os.getpid():
                continue
            try:
                entries = (process / 'environ').read_bytes().split(b'\0')
            except (OSError, PermissionError):
                continue
            require(not any(('HOME=' + home).encode() in entries for home in homes),
                    f'Quedo proceso de prueba PID {process.name}')
        if mode == 'local' and owned_port:
            print('PASS V12/AC12: cierre ordenado, scheduler detenido, puerto y procesos liberados')
    except BaseException as exc:
        print(f'FALLO DE LIMPIEZA: {exc}')
        result_code = 1
    if result_code == 3:
        print('PASS PARCIAL: RF-18 RF-19 RNF-26 TC-010; combinar evidencias local y LAN/VPN para cerrar el caso.')
    print(f'Resultado: {result_code}', flush=True)
sys.exit(result_code)
PY
