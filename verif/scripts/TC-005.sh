#!/usr/bin/env bash
# RF-10 - Cancelacion de trabajos en cola y ejecucion.
# TC-005: CLI local, estado persistido, proceso real y aislamiento entre Jobs.
# Modo: local (Linux/WSL); sin servidor TCP ni puertos.
set -euo pipefail
umask 077
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERMES="$REPO/src/hermes/hermes"
EVIDENCIA="$REPO/verif/results/results_TC-005.md"
for herramienta in python3 mktemp tee; do
    command -v "$herramienta" >/dev/null || { echo "ENTORNO: falta $herramienta"; exit 2; }
done
[[ -x "$HERMES" ]] || { echo 'ENTORNO: compile con make -C src/hermes hermes'; exit 2; }
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/hermes-TC-005.XXXXXX")"
export HOME="$TEST_ROOT/home" XDG_CONFIG_HOME="$TEST_ROOT/xdg"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$REPO/verif/results"
cleanup() {
    local estado=$?
    trap - EXIT
    printf '\nCodigo de salida TC-005: %s\n```\n' "$estado"
    rm -rf -- "$TEST_ROOT"
    exit "$estado"
}
trap cleanup EXIT
{
    printf '\n## Ejecucion: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf -- '- Modo: local\n- Destino: scheduler propio, sin TCP\n- Commit: %s\n' "$(git -C "$REPO" rev-parse --short HEAD)"
    printf -- '- Kernel: %s\n' "$(uname -r)"
    if [[ -n "$(git -C "$REPO" status --porcelain)" ]]; then
        printf -- '- Arbol: con cambios locales\n'
    else
        printf -- '- Arbol: limpio\n'
    fi
    printf '\n```text\n'
} >>"$EVIDENCIA"
exec > >(tee -a "$EVIDENCIA") 2>&1
python3 -u - "$REPO" "$TEST_ROOT" <<'PY'
import fcntl
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time

repo, root = map(Path, sys.argv[1:])
binary = str(repo/'src/hermes/hermes')
cases = []
valid_states = {'QUEUED','RUNNING','SUCCEEDED','FAILED','CANCELED','INTERRUPTED'}

class EnvironmentErrorTC(Exception):
    pass

def check(condition, message):
    if not condition:
        raise AssertionError(message)

def passed(n, message):
    print(f'PASS V{n}/AC{n}: {message}', flush=True)

def run(c, *args, expected=0):
    p = subprocess.run([binary,*map(str,args)],env=c['env'],capture_output=True,text=True,timeout=20)
    output = re.sub(r'\x1b\[[0-9;]*m','',p.stdout+p.stderr)
    print(f'  hermes {" ".join(map(str,args))} -> {p.returncode}: {output.strip()}',flush=True)
    accepted = expected if isinstance(expected,tuple) else (expected,)
    check(p.returncode in accepted, f'Codigo {p.returncode}; esperado {accepted}: {output}')
    return output

def scenario(name, workers, queue):
    folder=root/name
    env=dict(os.environ,HOME=str(folder/'home'),XDG_CONFIG_HOME=str(folder/'xdg'))
    conf=Path(env['XDG_CONFIG_HOME'])/'hermes/config.json'
    data=Path(env['HOME'])/'.local/share/hermes/data'
    network=Path(env['HOME'])/'.local/share/hermes/network/network.json'
    conf.parent.mkdir(parents=True)
    network.parent.mkdir(parents=True)
    conf.write_text(json.dumps({'trabajos_maximos':workers,'max_cola':queue,'interfaz':'127.0.0.1'}))
    network.write_text('{"habilitada":false,"clientes":[]}\n')
    c=dict(name=name,env=env,data=data,lock=data/'scheduler.lock')
    cases.append(c)
    print(f'Escenario: {name}; trabajos_maximos={workers}; max_cola={queue}')
    return c

def jobs(c):
    # Mismo bloqueo de almacenamiento que Hermes; no leer durante una transicion.
    with (c['data']/'jobs.lock').open('r') as lock:
        fcntl.flock(lock,fcntl.LOCK_SH)
        result=json.loads((c['data']/'jobs.json').read_text())
    check(isinstance(result,list) and all(j.get('status') in valid_states for j in result),'jobs.json invalido')
    return result

def job(c, ident):
    matches=[j for j in jobs(c) if j['job_id']==ident]
    check(len(matches)==1,f'Job {ident} ausente/duplicado')
    return matches[0]

def submit(c, program, *args, expected=0):
    output=run(c,'job',program,*args,expected=expected)
    matches=re.findall(r'^job ID:\s*(\d+)\s*$',output,re.M)
    check(len(matches)==1,'ID no identificado en admision')
    return int(matches[0])

def wait_for(fn,message,seconds=10):
    deadline=time.monotonic()+seconds
    while time.monotonic()<deadline:
        if fn():
            return
        time.sleep(.05)
    raise AssertionError(message)

def identity(pid):
    try:
        fields=Path(f'/proc/{pid}/stat').read_text().rsplit(')',1)[1].split()
        return fields[19]  # Campo 22: starttime; protege frente a reutilizacion de PID.
    except FileNotFoundError:
        return None

def alive(pid, starttime):
    return identity(pid)==starttime

def events(c):
    path=c['data']/'events.jsonl'
    if not path.exists():
        return []
    with path.open() as stream:
        fcntl.flock(stream,fcntl.LOCK_SH)
        return [json.loads(line) for line in stream if line.strip()]

def schedulers(c):
    pids=set()
    for proc in Path('/proc').glob('[0-9]*'):
        try:
            for fd in (proc/'fd').iterdir():
                try:
                    if os.readlink(fd)==str(c['lock']):
                        pids.add(int(proc.name))
                except OSError:
                    continue
        except OSError:
            continue
    return pids

def own_processes():
    homes={('HOME='+c['env']['HOME']).encode() for c in cases}
    found={}
    for proc in Path('/proc').glob('[0-9]*'):
        try:
            if homes.intersection((proc/'environ').read_bytes().split(b'\0')):
                found[int(proc.name)]=identity(int(proc.name))
        except OSError:
            continue
    return found

def cleanup_processes():
    errors=[]
    for c in cases:
        if schedulers(c):
            try:
                run(c,'clean','scheduler')
                wait_for(lambda: not schedulers(c),'Scheduler no libero bloqueo',5)
            except BaseException as exc:
                errors.append(str(exc))
                for pid in schedulers(c):
                    try:
                        os.kill(pid,signal.SIGTERM)
                    except ProcessLookupError:
                        pass
    # Recuperacion de limpieza acotada, solo procesos con HOME propio e identidad igual.
    remaining=own_processes()
    if remaining:
        for pid,starttime in remaining.items():
            if alive(pid,starttime):
                try:
                    os.kill(pid,signal.SIGTERM)
                except ProcessLookupError:
                    pass
        deadline=time.monotonic()+5
        while own_processes() and time.monotonic()<deadline:
            time.sleep(.05)
        for pid,starttime in own_processes().items():
            if alive(pid,starttime):
                try:
                    os.kill(pid,signal.SIGKILL)
                except ProcessLookupError:
                    pass
                errors.append(f'Proceso propio {pid} requirio SIGKILL')
        deadline=time.monotonic()+3
        while own_processes() and time.monotonic()<deadline:
            time.sleep(.05)
    check(not own_processes(),'Quedan procesos con HOME temporal')
    check(not errors,'; '.join(errors))

signal.signal(signal.SIGTERM,lambda signum,frame: sys.exit(1))
code=1
finished=False
try:
    if os.geteuid()==0:
        raise EnvironmentErrorTC('Hermes requiere usuario sin privilegios')
    if os.environ.get('HERMES_TEST_HOST','127.0.0.1') not in ('127.0.0.1','localhost'):
        raise EnvironmentErrorTC('TC-005 valida cancelacion local; no acepta servidor remoto')

    queued=scenario('cola-real',1,1)
    blocker=submit(queued,'sleep','120')
    wait_for(lambda: job(queued,blocker)['status']=='RUNNING' and job(queued,blocker)['pid']>0,'Bloqueador sin RUNNING/PID')
    blocker_before=job(queued,blocker)
    blocker_identity=identity(blocker_before['pid'])
    check(blocker_identity is not None,'Proceso bloqueador no existe')
    pending=submit(queued,'sleep','120')
    before=job(queued,pending)
    check(before['status']=='QUEUED' and before['pid']==0 and not before['tiempo_inicio'],'No se formo cola real')
    passed(1,f'cola real con 1 worker y 1 cupo; Jobs {blocker}=RUNNING y {pending}=QUEUED sin PID')

    response=run(queued,'cancel',pending)
    canceled=job(queued,pending)
    check(f'Job cancelado: {pending}' in response and canceled['status']=='CANCELED' and
          canceled['codigo_salida']==-1 and canceled['pid']==0 and not canceled['tiempo_inicio'] and
          canceled['tiempo_terminacion'],'Cancelacion QUEUED no fue directa/sin proceso')
    check(job(queued,blocker)==blocker_before and alive(blocker_before['pid'],blocker_identity),'Cancelar cola afecto al bloqueador')
    wait_for(lambda: any(str(e.get('job_id'))==str(pending) and e.get('context',{}).get('accion')=='CANCELADO_EN_COLA'
                         for e in events(queued)),'Falta evento CANCELADO_EN_COLA')
    passed(2,'QUEUED -> CANCELED/-1 sin iniciar proceso; bloqueador intacto y evento de cola')
    run(queued,'cancel',blocker)
    wait_for(lambda: job(queued,blocker)['status']=='CANCELED','Bloqueador no termino')
    after=job(queued,pending)
    check(after==canceled,'Job cancelado en cola se ejecuto al liberar worker')

    running=scenario('ejecucion-real',2,1)
    target=submit(running,'sleep','120')
    witness=submit(running,'sleep','120')
    wait_for(lambda: all(job(running,j)['status']=='RUNNING' and job(running,j)['pid']>0 for j in (target,witness)),
             'No hay dos procesos reales RUNNING')
    target_before=job(running,target)
    target_identity=identity(target_before['pid'])
    witness_before=job(running,witness)
    witness_identity=identity(witness_before['pid'])
    check(target_identity is not None and witness_identity is not None,'Procesos reales no encontrados')
    response=run(running,'cancel',target)
    check(f'Cancelación solicitada para el Job: {target}' in response,'No se acepto solicitud RUNNING')
    wait_for(lambda: job(running,target)['status']=='CANCELED','Estado final CANCELED no observado')
    final=job(running,target)
    check(final['cancel_requested'] is True and final['codigo_salida']==-signal.SIGTERM and final['tiempo_terminacion'],
          'RUNNING no persistio intencion, senal y terminacion')
    wait_for(lambda: not alive(target_before['pid'],target_identity),'Proceso cancelado sigue presente')
    detail=run(running,'filter','id',target)
    check('Estado: CANCELED' in detail and 'Codigo de salida: -15' in detail,'CLI no refleja CANCELED/-15')
    passed(3,f'RUNNING -> solicitud registrada -> CANCELED/-15; proceso {target_before["pid"]} terminado')

    check(job(running,witness)==witness_before and alive(witness_before['pid'],witness_identity),'Cancelacion afecto al testigo RUNNING')
    success=submit(running,'true')
    wait_for(lambda: job(running,success)['status']=='SUCCEEDED','Servicio no ejecuto trabajo posterior')
    check(job(running,success)['codigo_salida']==0,'Trabajo posterior no termino con cero')
    # El CLI puede observar FAILED antes de imprimir admision y devolver 1;
    # si aun no termino devuelve 0. En ambos casos exigir ID y FAILED persistido.
    failure=submit(running,'false',expected=(0,1))
    wait_for(lambda: job(running,failure)['status']=='FAILED','Trabajo false no llego a FAILED')
    passed(4,'testigo RUNNING intacto y scheduler continua ejecutando trabajos posteriores')

    for ident in (target,success,failure):
        snapshot=jobs(running)
        state=job(running,ident)['status']
        response=run(running,'cancel',ident,expected=1)
        check(f'no se puede cancelar (estado: {state})' in response,'Rechazo terminal sin causa')
        check(jobs(running)==snapshot,'Rechazo terminal modifico Jobs')
    nonexistent=max(j['job_id'] for j in jobs(running))+100
    snapshot=jobs(running)
    check(f'No existe el Job ID: {nonexistent}' in run(running,'cancel',nonexistent,expected=1),'ID ausente sin diagnostico')
    for invalid in ('0','-1','abc'):
        run(running,'cancel',invalid,expected=1)
    run(running,'cancel',expected=1)
    check(jobs(running)==snapshot,'ID invalido modifico Jobs')
    passed(5,'CANCELED/SUCCEEDED/FAILED, ID inexistente y argumentos invalidos: codigo 1 sin alterar Jobs')

    wait_for(lambda: any(str(e.get('job_id'))==str(target) and e.get('message')=='Cancelación exitosa' and
                         e.get('context',{}).get('exit_code')==-15 for e in events(running)),
             'Falta evento Cancelacion exitosa')
    log=events(running)
    check(any(str(e.get('job_id'))==str(target) and e.get('message')=='Cancelación solicitada' for e in log),'Falta solicitud en bitacora')
    check(any(e.get('level')=='WARN' and e.get('context',{}).get('motivo')=='No existe el Job' for e in log),'Falta registro de rechazo')
    check(job(running,witness)==witness_before and alive(witness_before['pid'],witness_identity),'Testigo alterado despues de rechazos')
    passed(6,'persistencia integra, solicitud y cancelacion correlacionadas por job_id, rechazo registrado')
    finished=True
    code=0
except (EnvironmentErrorTC,PermissionError) as exc:
    print('ENTORNO:',exc,flush=True)
    code=2
except BaseException as exc:
    print(f'FAIL: {type(exc).__name__}: {exc}',flush=True)
    code=1
finally:
    signal.signal(signal.SIGINT,signal.SIG_IGN)
    signal.signal(signal.SIGTERM,signal.SIG_IGN)
    try:
        cleanup_processes()
        if finished:
            passed(7,'schedulers propios detenidos, sin procesos supervivientes; temporales eliminados al salir')
    except BaseException as exc:
        print('FALLO DE LIMPIEZA:',exc,flush=True)
        code=1
    if code==0:
        print('PASS: RF-10 TC-005 sin fallos.')
    print('Resultado:',code,flush=True)
sys.exit(code)
PY
