#!/usr/bin/env bash
# RF-20, RNF-12, RNF-13 - Restriccion de red.
# TC-011: escucha segura, reglas IPv4/CIDR y rechazo de origen observado.
# Modo: local. No modifica el servicio LAN ni necesita PC B.
set -euo pipefail
umask 077
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
EVIDENCIA="$REPO/verif/results/results_TC-011.md"
for herramienta in python3 ss mktemp tee; do
    command -v "$herramienta" >/dev/null || { echo "ENTORNO: falta $herramienta"; exit 2; }
done
[[ -x "$REPO/src/hermes/hermes" ]] || { echo 'ENTORNO: compile con make -C src/hermes hermes'; exit 2; }
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/hermes-TC-011.XXXXXX")"
export HOME="$TEST_ROOT/home" XDG_CONFIG_HOME="$TEST_ROOT/xdg"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$REPO/verif/results"
cleanup() {
    local estado=$?
    trap - EXIT
    printf '\nCodigo de salida TC-011: %s\n```\n' "$estado"
    rm -rf -- "$TEST_ROOT"
    exit "$estado"
}
trap cleanup EXIT
{
    printf '\n## Ejecucion: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf -- '- Modo: local\n- Commit: %s\n' "$(git -C "$REPO" rev-parse --short HEAD)"
    if [[ -n "$(git -C "$REPO" status --porcelain)" ]]; then
        printf -- '- Arbol: con cambios locales\n'
    else
        printf -- '- Arbol: limpio\n'
    fi
    printf '\n```text\n'
} >>"$EVIDENCIA"
exec > >(tee -a "$EVIDENCIA") 2>&1
python3 - "$REPO" "$TEST_ROOT" <<'PY'
import errno
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import time
from contextlib import contextmanager

repo, root = map(Path, sys.argv[1:])
binary = str(repo / 'src/hermes/hermes')
cases, active, used_ports = [], [], set()
failure = False
requested = os.environ.get('HERMES_TEST_PORT')

class EnvironmentErrorTC(Exception):
    pass

def require(condition, message):
    if not condition:
        raise AssertionError(message)

def listening(port):
    p = subprocess.run(['ss', '-H', '-ltn', 'sport', '=', ':' + str(port)],
                       capture_output=True, text=True, timeout=5)
    require(p.returncode == 0, 'ss no pudo inspeccionar sockets')
    return p.stdout

def choose_port():
    if requested:
        try:
            port = int(requested)
            if not 1024 <= port <= 65535:
                raise ValueError()
        except ValueError as exc:
            raise EnvironmentErrorTC('HERMES_TEST_PORT debe estar entre 1024 y 65535') from exc
    else:
        with socket.socket() as s:
            s.bind(('127.0.0.1', 0))
            port = s.getsockname()[1]
    if listening(port):
        raise EnvironmentErrorTC(f'Puerto {port} ocupado; no se modifica al propietario')
    return port

def scenario(name, **changes):
    port = choose_port()
    folder = root / f'{len(cases):02}-{name}'
    env = dict(os.environ, HOME=str(folder / 'home'), XDG_CONFIG_HOME=str(folder / 'xdg'))
    conf = Path(env['XDG_CONFIG_HOME']) / 'hermes/config.json'
    net = Path(env['HOME']) / '.local/share/hermes/network/network.json'
    conf.parent.mkdir(parents=True)
    net.parent.mkdir(parents=True)
    config = {'puerto': port, 'trabajos_maximos': 1, 'max_cola': 1}
    config.update(changes)
    conf.write_text(json.dumps(config))
    net.write_text(json.dumps({'habilitada': True, 'clientes': []}))
    case = dict(name=name, env=env, conf=conf, port=port, log=folder / 'server.log',
                data=Path(env['HOME']) / '.local/share/hermes/data', spawned=False)
    cases.append(case)
    print(f'Escenario: {name}; destino 127.0.0.1:{port}; config={json.dumps(config)}', flush=True)
    return case

def events(case):
    path = case['data'] / 'events.jsonl'
    return [json.loads(line) for line in path.read_text().splitlines() if line] if path.exists() else []

def stop_scheduler(case):
    if (case['data'] / 'scheduler.lock').exists():
        p = subprocess.run([binary, 'clean', 'scheduler'], env=case['env'], capture_output=True,
                           text=True, timeout=35)
        require(p.returncode == 0, 'No se pudo detener scheduler propio: ' + p.stdout + p.stderr)

def close_server(case, p):
    global failure
    try:
        if p.poll() is None:
            p.terminate()
            try:
                p.wait(timeout=8)
            except subprocess.TimeoutExpired:
                p.kill()
                p.wait(timeout=5)
                raise AssertionError('Servidor requirio SIGKILL para detenerse')
        require(p.returncode == 0 and 'Hermes Red detenido' in case['log'].read_text(),
                'Servidor no cerro ordenadamente')
        require(not listening(case['port']), 'Escucha no liberada')
        require(any(e.get('message') == 'Hermes Red detenido' for e in events(case)), 'Falta evento de parada')
    except BaseException as exc:
        failure = True
        print(f'FALLO DE LIMPIEZA servidor {case["name"]}: {exc}', flush=True)
    finally:
        stop_scheduler(case)

@contextmanager
def running(case):
    # Puerto automatico: hasta tres intentos para la carrera bind(0) -> red start.
    for attempt in range(3):
        if attempt:
            require(not requested, 'Puerto solicitado no pudo abrirse')
            case['port'] = choose_port()
            config = json.loads(case['conf'].read_text())
            config['puerto'] = case['port']
            case['conf'].write_text(json.dumps(config))
        with case['log'].open('w') as output:
            p = subprocess.Popen([binary, 'red', 'start'], env=case['env'], stdout=output,
                                 stderr=subprocess.STDOUT)
        active.append((case, p))
        deadline = time.monotonic() + 10
        while p.poll() is None and time.monotonic() < deadline:
            log = case['log'].read_text()
            if 'Hermes Red escuchando en' in log and listening(case['port']):
                case['spawned'] = True
                used_ports.add(case['port'])
                break
            time.sleep(.05)
        if case['spawned']:
            break
        if p.poll() is None:
            p.terminate()
            p.wait(timeout=8)
        stop_scheduler(case)
        active.remove((case, p))
        if requested:
            raise AssertionError('Servidor no abrio el puerto solicitado: ' + case['log'].read_text())
    require(case['spawned'], 'Servidor no llego a escuchar: ' + case['log'].read_text())
    try:
        # Asegurar interfaz real mediante ss, no solamente mensaje de arranque.
        rows = listening(case['port']).splitlines()
        require(rows and all(row.split()[3] == f'127.0.0.1:{case["port"]}' for row in rows),
                'Escucha fuera de loopback: ' + '\n'.join(rows))
        yield p
    finally:
        close_server(case, p)
        active.remove((case, p))
        case['spawned'] = False

def probe(case, source='127.0.0.1', denied=False, operation='ping'):
    request = dict(version=1, request_id='tc011-' + source, operation=operation,
                   params={} if operation == 'ping' else {'programa': 'true', 'argumentos': []})
    with socket.socket() as s:
        s.settimeout(3)
        try:
            s.bind((source, 0))
        except OSError as exc:
            raise EnvironmentErrorTC(f'No se pudo usar origen loopback {source}: {exc}') from exc
        s.connect(('127.0.0.1', case['port']))
        try:
            s.sendall((json.dumps(request) + '\n').encode())
            response = b''
            while b'\n' not in response:
                data = s.recv(4096)
                if not data:
                    break
                response += data
                require(len(response) < 262145, 'Respuesta demasiado grande')
        except (ConnectionResetError, BrokenPipeError):
            require(denied, 'Conexion permitida reiniciada inesperadamente')
            response = b''
    if denied:
        require(not response, 'Origen rechazado recibio datos de aplicacion')
        require(any(e.get('message') == 'Conexión rechazada' and
                    e.get('context', {}).get('motivo') == 'ORIGEN_RECHAZADO' and
                    e.get('context', {}).get('ip') == source for e in events(case)),
                'Falta evento de rechazo para el origen observado')
        print(f'  origen {source}: cierre sin respuesta y ORIGEN_RECHAZADO')
        return
    answer = json.loads(response)
    require(answer.get('request_id') == request['request_id'] and answer.get('version') == 1,
            'Respuesta no correlacionada')
    if operation == 'ping':
        require(answer.get('ok') is True and answer.get('result', {}).get('message') == 'pong',
                'Origen autorizado no recibio pong')
    else:
        require(answer.get('ok') is False and answer.get('error') == 'UNAUTHORIZED',
                'Origen sin registro pudo operar trabajos')
    print(f'  origen {source}: {answer}')

def fails_start(case, message):
    # Nunca se prueba a costa de un puerto de otro proceso.
    p = subprocess.run([binary, 'red', 'start'], env=case['env'], capture_output=True,
                       text=True, timeout=10)
    print('  rechazo arranque:', p.stderr.strip())
    require(p.returncode == 1 and message in p.stderr, 'Arranque no fallo segun el contrato')
    require(not listening(case['port']), 'Arranque rechazado dejo escucha abierta')
    stop_scheduler(case)

def interrupt(signum, frame):
    raise KeyboardInterrupt('Interrumpido por senal ' + str(signum))

signal.signal(signal.SIGTERM, interrupt)
code = 1
try:
    if os.environ.get('HERMES_TEST_HOST', '127.0.0.1') not in ('127.0.0.1', 'localhost'):
        raise EnvironmentErrorTC('TC-011 es local; no admite modificar/inspeccionar un servidor remoto')
    default = scenario('predeterminados')
    with running(default):
        probe(default)
        probe(default, '127.0.0.2')
    print('PASS V1/AC1: interfaz predeterminada loopback y regla 127/8, con puerto aislado')

    for rule in ('127.0.0.1', '127.0.0.1/32'):
        exact = scenario('ip-exacta', redes_permitidas=[rule])
        with running(exact) as process:
            probe(exact)
            probe(exact, '127.0.0.2', denied=True)
            probe(exact)
            require(process.poll() is None, 'Servicio murio tras rechazar origen')
    print('PASS V2/AC2: IP individual y /32 equivalentes; rechazo no termina el servicio')

    subnet = scenario('cidr-normalizado', redes_permitidas=['127.0.0.5/30'])
    with running(subnet):
        probe(subnet, '127.0.0.5')
        probe(subnet, '127.0.0.1', denied=True)
        probe(subnet, '127.0.0.5')
    print('PASS V3/AC3: CIDR normaliza bits de host y aplica pertenencia')

    for rules in ([], ['10.0.0.0/8']):
        deny = scenario('lista-deniega', redes_permitidas=rules)
        with running(deny) as process:
            probe(deny, denied=True)
            require(process.poll() is None, 'Servicio no sobrevivio al rechazo')
    print('PASS V4/AC4: lista vacia deniega todo; lista explicita reemplaza el valor local')

    valid = ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16', '100.64.0.0/10',
             '10.2.3.4/24', '172.31.255.255/32', '192.168.255.255', '100.127.255.255/32']
    for rule in valid:
        accepted = scenario('espacio-valido', redes_permitidas=['127.0.0.1', rule])
        with running(accepted):
            probe(accepted)
    print(f'PASS V5/AC5: {len(valid)} reglas privadas/VPN validas aceptadas por el servidor')

    invalid = ['127.0.0.0/33', '127.0.0.0/-1', 'localhost', '::1', '127.0.0.1\0',
               '0.0.0.0/0', '0.1.2.3', '203.0.113.1', '203.0.113.0/24', '169.254.1.1',
               '224.0.0.1', '255.255.255.255', '10.0.0.0/7', '172.16.0.0/11',
               '100.63.255.255', '100.128.0.1', 42]
    variants = [['127.0.0.1', rule] for rule in invalid] + [None, '127.0.0.1', {'red': '127/8'}]
    for rules in variants:
        bad = scenario('reglas-invalidas', redes_permitidas=rules)
        fails_start(bad, 'redes_permitidas inválida')
        require(not (bad['data'] / 'scheduler.lock').exists(), 'Reglas invalidas iniciaron scheduler')
        require(any(e.get('message') == 'redes_permitidas inválida; se deniega el acceso de red'
                    for e in events(bad)), 'Falta diagnostico de configuracion invalida')
    print(f'PASS V6/AC6: {len(variants)} listas invalidas abortan antes de escuchar, sin aceptar parcialmente')

    for interface in ('0.0.0.0', '203.0.113.1', '::1', 'localhost'):
        fallback = scenario('fallback-seguro', interfaz=interface)
        with running(fallback):
            probe(fallback)
            require(any(e.get('message') == 'Valor inválido en config.json; se utiliza el valor por defecto'
                        and e.get('context', {}).get('clave') == 'interfaz' for e in events(fallback)),
                    'Falta advertencia de interfaz invalida')
    print('PASS V7/AC7: interfaz invalida o comodin vuelve solo a 127.0.0.1')

    reload = scenario('reinicio', redes_permitidas=['127.0.0.1'])
    with running(reload):
        probe(reload)
        config = json.loads(reload['conf'].read_text())
        config['redes_permitidas'] = []
        reload['conf'].write_text(json.dumps(config))
        probe(reload)
    with running(reload):
        probe(reload, denied=True)
    print('PASS V8/AC8: las reglas cambian al reiniciar, no a mitad de la ejecucion')

    occupied = scenario('puerto-ocupado')
    with socket.socket() as owner:
        owner.bind(('127.0.0.1', occupied['port']))
        owner.listen()
        p = subprocess.run([binary, 'red', 'start'], env=occupied['env'], capture_output=True,
                           text=True, timeout=10)
        require(p.returncode == 1 and 'No se pudo escuchar' in p.stderr, 'Puerto ocupado no produjo error')
        require(listening(occupied['port']), 'Se altero la escucha del propietario del puerto')
        stop_scheduler(occupied)
    require(not listening(occupied['port']), 'Socket propio de prueba no se libero')
    # Elegir una IP privada comprobada como no asignada; no depender de una IP supuesta.
    unassigned = None
    for ip in ('10.254.254.254', '192.168.254.254', '172.31.254.254'):
        with socket.socket() as check:
            try:
                check.bind((ip, 0))
            except OSError as exc:
                if exc.errno == errno.EADDRNOTAVAIL:
                    unassigned = ip
                    break
                raise
    if unassigned is None:
        raise EnvironmentErrorTC('No se encontro una IP privada no asignada para probar bind')
    fails_start(scenario('interfaz-no-local', interfaz=unassigned), 'No se pudo escuchar')
    print('PASS V9/AC9: puerto ocupado y direccion privada no local fallan sin fallback de bind')

    distinct = scenario('red-no-es-permiso', redes_permitidas=['127.0.0.1'])
    with running(distinct):
        probe(distinct)
        probe(distinct, operation='submit')
        require(json.loads((distinct['data'] / 'jobs.json').read_text()) == [], 'Se creo trabajo sin permiso')
    print('PASS V10/AC10: origen permitido sin registro recibe pong pero no puede crear trabajos')
    code = 0
except (EnvironmentErrorTC, PermissionError) as exc:
    print('ENTORNO: ' + str(exc), flush=True)
    code = 2
except BaseException as exc:
    print(f'FAIL: {type(exc).__name__}: {exc}', flush=True)
    code = 1
finally:
    signal.signal(signal.SIGINT, signal.SIG_IGN)
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    for case, process in active:
        close_server(case, process)
    for case in cases:
        try:
            stop_scheduler(case)
        except BaseException as exc:
            failure = True
            print('FALLO DE LIMPIEZA scheduler: ' + str(exc))
    try:
        for port in used_ports:
            require(not listening(port), f'Puerto {port} sigue ocupado')
        homes = {case['env']['HOME'] for case in cases}
        for process in Path('/proc').glob('[0-9]*'):
            if int(process.name) == os.getpid():
                continue
            try:
                env = (process / 'environ').read_bytes().split(b'\0')
            except OSError:
                continue
            require(not any(('HOME=' + home).encode() in env for home in homes),
                    f'Quedo proceso de prueba {process.name}')
    except BaseException as exc:
        failure = True
        print('FALLO DE LIMPIEZA recursos: ' + str(exc))
    if failure:
        code = 1
    if code == 0:
        print('PASS V11/AC11: SIGTERM, wait, eventos de parada, schedulers y puertos liberados; sin huerfanos')
        print('PASS: RF-20 RNF-12 RNF-13 TC-011 sin fallos.')
    print('Resultado:', code, flush=True)
sys.exit(code)
PY
