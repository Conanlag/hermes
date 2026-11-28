#!/usr/bin/env bash
# RNF-33 - Liberacion de recursos despues de estres local y TCP.
# TC-024: RSS, descriptores, sockets activos, hijos y temporales de servicios reales.
# Modo: local (Linux/WSL); no necesita PC B.
set -euo pipefail
umask 077
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
EVIDENCIA="$REPO/verif/results/results_TC-024.md"
for herramienta in python3 ss mktemp tee; do
    command -v "$herramienta" >/dev/null || { echo "ENTORNO: falta $herramienta"; exit 2; }
done
[[ -x "$REPO/src/hermes/hermes" ]] || { echo 'ENTORNO: compile con make -C src/hermes hermes'; exit 2; }
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/hermes-TC-024.XXXXXX")"
export HOME="$TEST_ROOT/driver-home" XDG_CONFIG_HOME="$TEST_ROOT/driver-xdg"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$REPO/verif/results"
cleanup() {
    local estado=$?
    trap - EXIT
    printf '\nCodigo de salida TC-024: %s\n```\n' "$estado"
    rm -rf -- "$TEST_ROOT"
    exit "$estado"
}
trap cleanup EXIT
{
    printf '\n## Ejecucion: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf -- '- Modo: local\n- Cliente: %s\n- Commit: %s\n' "${HERMES_TEST_CLIENT_ID:-PC-B}" "$(git -C "$REPO" rev-parse --short HEAD)"
    printf -- '- Kernel: %s\n- Carga por via (local/TCP): %s\n' "$(uname -r)" "${1:-100}"
    if [[ -n "$(git -C "$REPO" status --porcelain)" ]]; then
        printf -- '- Arbol: con cambios locales\n'
    else
        printf -- '- Arbol: limpio\n'
    fi
    printf '\n```text\n'
} >>"$EVIDENCIA"
exec > >(tee -a "$EVIDENCIA") 2>&1
python3 -u - "$REPO" "$TEST_ROOT" "${1:-100}" "$#" <<'PY'
from concurrent.futures import ThreadPoolExecutor
import fcntl
import json
import os
from pathlib import Path
import re
import signal
import socket
import struct
import subprocess
import sys
import time

repo,root=map(Path,sys.argv[1:3])
binary=str(repo/'src/hermes/hermes')
env=dict(os.environ,HOME=str(root/'service-home'),XDG_CONFIG_HOME=str(root/'service-xdg'))
conf=Path(env['XDG_CONFIG_HOME'])/'hermes/config.json'
data=Path(env['HOME'])/'.local/share/hermes/data'
network=Path(env['HOME'])/'.local/share/hermes/network/network.json'
server_log=root/'server.log'
server=None
owned_ports=set()
held=[]
scheduler=None
baseline=None
port=None
client=os.environ.get('HERMES_TEST_CLIENT_ID','PC-B')
TOLERANCE=8192

class EnvironmentErrorTC(Exception):
    pass

def check(condition,message):
    if not condition:
        raise AssertionError(message)

def passed(n,message):
    print(f'PASS V{n}/AC{n}: {message}',flush=True)

def run(*args):
    p=subprocess.run([binary,*args],env=env,capture_output=True,text=True,timeout=20)
    check(p.returncode==0,f'hermes {args}: codigo {p.returncode}: {p.stdout} {p.stderr}')
    return p.stdout

def listen(p):
    r=subprocess.run(['ss','-H','-ltn','sport','=',f':{p}'],capture_output=True,text=True,timeout=5)
    check(r.returncode==0,'ss no pudo consultar escucha')
    return r.stdout

def choose_port():
    requested=os.environ.get('HERMES_TEST_PORT')
    if requested is not None:
        try:
            p=int(requested)
            if not 1024<=p<=65535:
                raise ValueError()
        except ValueError as exc:
            raise EnvironmentErrorTC('HERMES_TEST_PORT debe estar entre 1024 y 65535') from exc
    else:
        with socket.socket() as s:
            s.bind(('127.0.0.1',0))
            p=s.getsockname()[1]
    if p==45820 or listen(p):
        raise EnvironmentErrorTC(f'Puerto {p} operativo/reservado u ocupado')
    with socket.socket() as s:
        s.bind(('127.0.0.1',p))
    return p

def wait_for(fn,message,seconds=10):
    end=time.monotonic()+seconds
    while time.monotonic()<end:
        if fn():
            return
        time.sleep(.05)
    raise AssertionError(message)

def scheduler_pids():
    result=set()
    for proc in Path('/proc').glob('[0-9]*'):
        try:
            for fd in (proc/'fd').iterdir():
                try:
                    if os.readlink(fd)==str(data/'scheduler.lock'):
                        result.add(int(proc.name))
                except OSError:
                    continue
        except OSError:
            continue
    return result

def snapshot(pid):
    status=Path(f'/proc/{pid}/status').read_text()
    rss=re.search(r'^VmRSS:\s+(\d+)\s+kB$',status,re.M)
    check(rss is not None,f'Sin RSS de proceso {pid}')
    targets=[]
    for fd in Path(f'/proc/{pid}/fd').iterdir():
        try:
            targets.append(os.readlink(fd))
        except FileNotFoundError:
            pass  # Puede cerrarse entre listar y readlink; exigir estabilidad despues.
    children=set()
    for task in Path(f'/proc/{pid}/task').iterdir():
        try:
            children.update((task/'children').read_text().split())
        except FileNotFoundError:
            pass
    # El servidor inicia al scheduler con fork: ese hijo es infraestructura
    # persistente, no un proceso Job filtrado. Se mide por separado.
    service_children={str(scheduler)} & children if pid==server.pid else set()
    return dict(rss=int(rss[1]),fds=len(targets),sockets=sum(t.startswith('socket:[') for t in targets),
                children=len(children-service_children),service_children=len(service_children))

def stable(base=None):
    previous=None
    count=0
    result=None
    def sample():
        nonlocal previous,count,result
        check(server.poll() is None,'Servidor termino durante carga')
        result={'servidor':snapshot(server.pid),'scheduler':snapshot(scheduler)}
        shape={name:(s['fds'],s['sockets'],s['children']) for name,s in result.items()}
        desired=all(s['children']==0 for s in result.values())
        if base is not None:
            desired=desired and all((s['fds'],s['sockets'])==(base[name]['fds'],base[name]['sockets']) for name,s in result.items())
        count=count+1 if desired and shape==previous else (1 if desired else 0)
        previous=shape
        return count>=5
    try:
        wait_for(sample,'Recursos no regresaron a reposo',15)
    except AssertionError as exc:
        raise AssertionError(f'{exc}; base={base}; observado={result}') from exc
    return result

def jobs():
    with (data/'jobs.lock').open() as lock:
        fcntl.flock(lock,fcntl.LOCK_SH)
        content=json.loads((data/'jobs.json').read_text())
    check(isinstance(content,list) and all(j.get('status') in {'QUEUED','RUNNING','SUCCEEDED','FAILED','CANCELED','INTERRUPTED'} for j in content),'jobs.json invalido')
    return content

def wait_jobs(expected):
    def done():
        content=jobs()
        check(len(content)==expected,f'Cantidad de Jobs {len(content)} != {expected}')
        if any(j['status'] in ('RUNNING','QUEUED') for j in content):
            return False
        check(all(j['status']=='SUCCEEDED' and j['codigo_salida']==0 for j in content),'true no termino SUCCEEDED/0')
        return True
    wait_for(done,f'Jobs no terminaron; esperados={expected}',30)

def submit(remote):
    out=run(*(['red','job','127.0.0.1','true'] if remote else ['job','true']))
    ids=re.findall(r'^job ID:\s*(\d+)\s*$',out,re.M)
    check(len(ids)==1,'Admision sin ID: '+out)
    return int(ids[0])

def load(count,remote):
    ids=[]
    initial=len(jobs())
    with ThreadPoolExecutor(max_workers=10) as executor:
        for start in range(0,count,10):
            ids.extend(executor.map(submit,[remote]*min(10,count-start)))
            # submit TCP solo confirma admision y ya no espera al scheduler.
            # Drenar el lote evita probar saturacion (RF-23) en vez de recursos.
            wait_jobs(initial+len(ids))
    check(len(ids)==len(set(ids))==count,'IDs de carga duplicados')

def connect():
    s=socket.create_connection(('127.0.0.1',port),timeout=3)
    s.settimeout(3)
    held.append(s)
    return s

def close(s,rst=False):
    if rst:
        s.setsockopt(socket.SOL_SOCKET,socket.SO_LINGER,struct.pack('ii',1,0))
    s.close()
    held.remove(s)

def message(s,request_id):
    s.sendall((json.dumps({'version':1,'request_id':request_id,'operation':'ping','params':{}})+'\n').encode())
    response=b''
    while b'\n' not in response:
        block=s.recv(4096)
        check(block,'Cierre antes de pong')
        response+=block
        check(len(response)<=262144,'Respuesta excesiva')
    answer=json.loads(response)
    check(answer.get('ok') is True and answer.get('request_id')==request_id and answer.get('result',{}).get('message')=='pong','Respuesta ping invalida')

def own_processes():
    expected=('HOME='+env['HOME']).encode()
    result=[]
    for proc in Path('/proc').glob('[0-9]*'):
        try:
            if expected in (proc/'environ').read_bytes().split(b'\0'):
                result.append(int(proc.name))
        except OSError:
            pass
    return result

def cleanup_services():
    errors=[]
    for s in list(held):
        close(s)
    if server is not None and server.poll() is None:
        server.terminate()
        try:
            server.wait(timeout=8)
        except subprocess.TimeoutExpired:
            server.kill()
            server.wait(timeout=5)
            errors.append('Servidor requirio SIGKILL')
    if scheduler_pids():
        try:
            run('clean','scheduler')
        except BaseException as exc:
            errors.append(str(exc))
            for pid in scheduler_pids():
                try:
                    os.kill(pid,signal.SIGTERM)
                except ProcessLookupError:
                    pass
    deadline=time.monotonic()+5
    while own_processes() and time.monotonic()<deadline:
        time.sleep(.05)
    for pid in own_processes():
        try:
            os.kill(pid,signal.SIGKILL)
            errors.append(f'Proceso propio {pid} requirio SIGKILL')
        except ProcessLookupError:
            pass
    check(not own_processes(),'Procesos propios supervivientes')
    for p in owned_ports:
        check(not listen(p),f'Puerto propio {p} sigue escuchando')
    check(not errors,'; '.join(errors))

signal.signal(signal.SIGTERM,lambda signum,frame: sys.exit(1))
code=1
finished=False
try:
    try:
        count=int(sys.argv[3])
        if not re.fullmatch(r'[0-9]+',sys.argv[3]) or count<10 or int(sys.argv[4])>1:
            raise ValueError()
    except ValueError as exc:
        raise EnvironmentErrorTC('Uso: bash verif/scripts/TC-024.sh [cantidad >= 10]') from exc
    if os.geteuid()==0:
        raise EnvironmentErrorTC('Ejecute como usuario sin privilegios')
    if os.environ.get('HERMES_TEST_HOST','127.0.0.1') not in ('127.0.0.1','localhost'):
        raise EnvironmentErrorTC('TC-024 requiere servidor propio; modo remoto no permite medir recursos')
    if re.fullmatch(r'[A-Za-z0-9._:-]{1,128}',client) is None:
        raise EnvironmentErrorTC('HERMES_TEST_CLIENT_ID invalido')
    conf.parent.mkdir(parents=True)
    network.parent.mkdir(parents=True)
    network.write_text(json.dumps({'habilitada':True,'clientes':[{'id':client,'ambito_trabajos':'tc024',
        'direcciones':['127.0.0.1'],'operaciones':['submit','query','list','cancel'],'programas':['true']}]}))
    for attempt in range(3):
        port=choose_port()
        settings={'interfaz':'127.0.0.1','puerto':port,'redes_permitidas':['127.0.0.0/8'],'trabajos_maximos':10,'max_cola':10}
        conf.write_text(json.dumps(settings))
        with server_log.open('w') as output:
            server=subprocess.Popen([binary,'red','start'],env=env,stdout=output,stderr=subprocess.STDOUT)
        deadline=time.monotonic()+10
        ready=False
        while server.poll() is None and time.monotonic()<deadline:
            if 'Hermes Red escuchando en' in server_log.read_text() and listen(port):
                ready=True
                break
            time.sleep(.05)
        if ready:
            owned_ports.add(port)
            break
        if server.poll() is None:
            server.terminate()
            server.wait(timeout=8)
        if os.environ.get('HERMES_TEST_PORT') or attempt==2:
            raise AssertionError('Arranque no disponible: '+server_log.read_text()[-4000:])
    check(all(row.split()[3]==f'127.0.0.1:{port}' for row in listen(port).splitlines()),'Escucha fuera de loopback')
    wait_for(lambda: len(scheduler_pids())==1,'Scheduler propio no identificado')
    scheduler=next(iter(scheduler_pids()))
    print(f'Destino: 127.0.0.1:{port}; servidor PID={server.pid}; scheduler PID={scheduler}; config={json.dumps(settings)}')
    submit(False)
    submit(True)
    wait_jobs(2)
    baseline=stable()
    print('Linea base:',json.dumps(baseline))
    check(baseline['servidor']['sockets']==1 and baseline['scheduler']['sockets']==0,'Linea base de sockets inesperada')
    passed(1,'servidor/scheduler reales, calentamiento local/TCP y linea base estable')

    expected=2
    for round_no,size in enumerate((count//2,count-count//2),1):
        load(size,False)
        expected+=size
        wait_jobs(expected)
        load(size,True)
        expected+=size
        wait_jobs(expected)
        # Conexiones simultaneas confirmadas con pong y /proc, no solo intentos connect.
        wave=[]
        for i in range(16):
            s=connect()
            message(s,f'tc024-r{round_no}-hold{i}')
            wave.append(s)
        peak=snapshot(server.pid)
        print(f'Ronda {round_no}: {size} Jobs locales + {size} TCP; pico servidor={json.dumps(peak)}')
        check(peak['sockets']>=baseline['servidor']['sockets']+16,'No se observaron 16 sockets aceptados')
        for i,s in enumerate(wave):
            close(s,rst=(i%2==1))
        for i in range(size):
            s=connect()
            message(s,f'tc024-r{round_no}-cycle{i}')
            close(s,rst=(i%2==1))
        # Abortos a mitad de un mensaje: no deben retener sockets ni crear Jobs.
        for i in range(8):
            s=connect()
            s.sendall(b'{"version":1,"request_id":"tc024-incompleto"')
            close(s,rst=True)
        after=stable(baseline)
        print(f'Reposo ronda {round_no}:',json.dumps(after))
        for name,sample in after.items():
            delta=sample['rss']-baseline[name]['rss']
            print(f'  {name}: delta RSS={delta} KiB; tolerancia={TOLERANCE} KiB')
            check(delta<=TOLERANCE,f'{name}: RSS supera tolerancia de {TOLERANCE} KiB')
        check(not list(data.glob('jobs.json.tmp.*')),'Temporales jobs.json.tmp.* supervivientes')
        passed(2 if round_no==1 else 3,f'ronda {round_no}: Jobs completados; sockets/FDs regresan a base; sin hijos ni temporales; RSS dentro de tolerancia')

    content=jobs()
    check(len(content)==2*count+2,'Cantidad final incorrecta')
    check(sum(j.get('tipo_ejecucion')=='remote' for j in content)==count+1,'No se ejercito admision TCP real')
    print(f'Jobs finales: {len(content)}; locales={count+1}; TCP={count+1}; todos SUCCEEDED/0')
    logfile=data/'events.jsonl'
    with logfile.open() as stream:
        fcntl.flock(stream,fcntl.LOCK_SH)
        entries=[json.loads(line) for line in stream if line.strip()]
    check(all(isinstance(e,dict) for e in entries),'Bitacora no integra')
    probe=connect()
    message(probe,'tc024-final')
    close(probe)
    stable(baseline)
    passed(4,'persistencia/bitacora integras y servidor sigue respondiendo despues de la carga')

    # Detener con clientes aun abiertos acredita cierre del lado servidor.
    clients=[connect() for _ in range(4)]
    for i,s in enumerate(clients):
        message(s,f'tc024-stop{i}')
    server.terminate()
    server.wait(timeout=8)
    check(server.returncode==0 and 'Hermes Red detenido' in server_log.read_text(),'Parada TCP no ordenada')
    for s in clients:
        check(s.recv(1)==b'','Cliente abierto no recibio EOF en parada')
        close(s)
    check(not listen(port),'Escucha no liberada')
    with socket.socket() as reuse:
        reuse.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
        reuse.bind(('127.0.0.1',port))
        reuse.listen()
    passed(5,'SIGTERM cierra clientes abiertos y escucha, wait recoge servidor y puerto vuelve a enlazarse')
    run('clean','scheduler')
    wait_for(lambda: not Path(f'/proc/{scheduler}/fd').exists() or not list(Path(f'/proc/{scheduler}/fd').iterdir()),
             'Scheduler no libero descriptores',8)
    check(not list(data.glob('jobs.json.tmp.*')),'Temporales despues de parada')
    finished=True
    code=0
except (EnvironmentErrorTC,PermissionError) as exc:
    print('ENTORNO:',exc,flush=True)
    code=2
except BaseException as exc:
    print(f'FAIL: {type(exc).__name__}: {exc}',flush=True)
    if (data/'events.jsonl').exists():
        with (data/'events.jsonl').open() as stream:
            fcntl.flock(stream,fcntl.LOCK_SH)
            errors=[]
            for line in stream:
                try:
                    event=json.loads(line)
                    if event.get('level')=='ERROR':
                        errors.append(event)
                        errors=errors[-10:]
                except json.JSONDecodeError:
                    continue
        print('Ultimos ERROR registrados:',json.dumps(errors,ensure_ascii=False))
    if server_log.exists():
        print('Ultimas lineas servidor:\n'+'\n'.join(server_log.read_text().splitlines()[-20:]))
    code=1
finally:
    signal.signal(signal.SIGINT,signal.SIG_IGN)
    signal.signal(signal.SIGTERM,signal.SIG_IGN)
    try:
        cleanup_services()
        if finished:
            passed(6,'scheduler sin descriptores, ningun proceso propio ni puerto abierto; temporales eliminados al salir')
    except BaseException as exc:
        print('FALLO DE LIMPIEZA:',exc,flush=True)
        code=1
    if code==0:
        print('PASS: RNF-33 TC-024 sin fallos.')
    print('Resultado:',code,flush=True)
sys.exit(code)
PY
