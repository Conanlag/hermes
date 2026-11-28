#!/usr/bin/env bash
# RF-16, RF-24 - Configuracion y salud.
# TC-013: configuracion aislada, servicios reales y resumen administrativo.
# Modo: local (Linux/WSL). No necesita PC B.
set -euo pipefail
umask 077
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
EVIDENCIA="$REPO/verif/results/results_TC-013.md"
for herramienta in python3 ss mktemp tee g++; do
    command -v "$herramienta" >/dev/null || { echo "ENTORNO: falta $herramienta"; exit 2; }
done
[[ -x "$REPO/src/hermes/hermes" ]] || { echo 'ENTORNO: compile con make -C src/hermes hermes'; exit 2; }
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/hermes-TC-013.XXXXXX")"
export HOME="$TEST_ROOT/home" XDG_CONFIG_HOME="$TEST_ROOT/xdg"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$REPO/verif/results"
cleanup() {
    local estado=$?
    trap - EXIT
    printf '\nCodigo de salida TC-013: %s\n```\n' "$estado"
    rm -rf -- "$TEST_ROOT"
    exit "$estado"
}
trap cleanup EXIT
{
    printf '\n## Ejecucion: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf -- '- Modo: local\n- Cliente: %s\n- Commit: %s\n' "${HERMES_TEST_CLIENT_ID:-PC-B}" "$(git -C "$REPO" rev-parse --short HEAD)"
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
import errno
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import time

repo, root = map(Path, sys.argv[1:])
binary = str(repo / 'src/hermes/hermes')
cases, processes, ports = [], [], set()
findings = []
finished = False
cleanup_ok = False
requested = os.environ.get('HERMES_TEST_PORT')
client = os.environ.get('HERMES_TEST_CLIENT_ID', 'PC-B')

class EnvironmentErrorTC(Exception):
    pass

def check(condition, message):
    if not condition:
        raise AssertionError(message)

def passed(n, message):
    print(f'PASS V{n}/AC{n}: {message}', flush=True)

def run(c, *args, code=0):
    p = subprocess.run([binary, *args], env=c['env'], capture_output=True, text=True, timeout=35)
    check(p.returncode == code, f'{args}: codigo {p.returncode}, esperado {code}: {p.stdout} {p.stderr}')
    return p

def health(c, code=0):
    p = run(c, 'health', '--json', code=code)
    result = json.loads(p.stdout)
    check(result['completo'] == (code == 0), 'Indicador completo incoherente')
    return result

def scenario(name, config=None, xdg=None):
    folder = root / f'{len(cases):02}-{name}'
    env = dict(os.environ, HOME=str(folder/'home'), XDG_CONFIG_HOME=str(folder/'xdg'))
    if xdg is not None:
        env['XDG_CONFIG_HOME'] = xdg
    confbase = Path(env['XDG_CONFIG_HOME']) if Path(env['XDG_CONFIG_HOME']).is_absolute() else Path(env['HOME'])/'.config'
    c = dict(name=name, folder=folder, env=env, conf=confbase/'hermes/config.json',
             data=Path(env['HOME'])/'.local/share/hermes/data',
             net=Path(env['HOME'])/'.local/share/hermes/network/network.json')
    c['conf'].parent.mkdir(parents=True)
    if config is not None:
        c['conf'].write_text(json.dumps(config))
    cases.append(c)
    print('Escenario:', name)
    return c

def config(c, **changes):
    content = json.loads(c['conf'].read_text())
    content.update(changes)
    c['conf'].write_text(json.dumps(content))

def events(c):
    return [json.loads(line) for line in (c['data']/'events.jsonl').read_text().splitlines() if line]

def listening(port):
    p = subprocess.run(['ss','-H','-ltn','sport','=',f':{port}'],capture_output=True,text=True,timeout=5)
    check(p.returncode == 0, 'ss fallo')
    return p.stdout

def free_port(use_requested=True):
    if requested and use_requested:
        try:
            p = int(requested)
            if not 1024 <= p <= 65535:
                raise ValueError()
        except ValueError:
            raise EnvironmentErrorTC('HERMES_TEST_PORT debe estar entre 1024 y 65535')
    else:
        with socket.socket() as s:
            s.bind(('127.0.0.1',0))
            p = s.getsockname()[1]
    if p == 45820 or listening(p):
        raise EnvironmentErrorTC(f'Puerto {p} reservado u ocupado')
    with socket.socket() as s:
        s.bind(('127.0.0.1',p))
    return p

def wait_for(fn, message, seconds=10):
    deadline = time.monotonic()+seconds
    while time.monotonic() < deadline:
        if fn():
            return
        time.sleep(.05)
    raise AssertionError(message)

def start(c):
    for attempt in range(3):
        pnum = json.loads(c['conf'].read_text())['puerto']
        if listening(pnum):
            raise EnvironmentErrorTC(f'Puerto {pnum} ocupado antes del arranque')
        log = c['folder']/f'server-{len(processes)}.log'
        with log.open('w') as output:
            p = subprocess.Popen([binary,'red','start'],env=c['env'],stdout=output,stderr=subprocess.STDOUT)
        processes.append((c,p,log,pnum))
        deadline = time.monotonic()+10
        while p.poll() is None and time.monotonic()<deadline:
            if 'Hermes Red escuchando en' in log.read_text() and listening(pnum):
                ports.add(pnum)
                rows = listening(pnum).splitlines()
                check(all(row.split()[3] == f'127.0.0.1:{pnum}' for row in rows), 'Escucha fuera de loopback')
                print(f'  Destino: 127.0.0.1:{pnum}; config={c["conf"].read_text()}')
                return p
            time.sleep(.05)
        if p.poll() is None:
            p.terminate()
            p.wait(timeout=8)
        if requested or attempt == 2:
            raise AssertionError('Fallo de arranque: '+log.read_text())
        config(c, puerto=free_port())
    raise AssertionError('Arranque agotado')

def stop(p, abrupt=False):
    record = next(item for item in processes if item[1] is p)
    c, _, log, port = record
    if p.poll() is None:
        p.kill() if abrupt else p.terminate()
        p.wait(timeout=8)
    check(p.returncode == (-signal.SIGKILL if abrupt else 0), 'Salida de servidor inesperada')
    if not abrupt:
        check('Hermes Red detenido' in log.read_text(), 'Falta mensaje de parada')
        check(any(e.get('message')=='Hermes Red detenido' for e in events(c)), 'Falta evento de parada')
    check(not listening(port), 'Puerto no liberado')

def scheduler_pids(c):
    found = set()
    target = str(c['data']/'scheduler.lock')
    for proc in Path('/proc').glob('[0-9]*'):
        try:
            for fd in (proc/'fd').iterdir():
                try:
                    if os.readlink(fd) == target:
                        found.add(int(proc.name))
                except OSError:
                    continue
        except OSError:
            continue
    return found

def cleanup():
    errors = []
    for c,p,log,port in processes:
        if p.poll() is None:
            try:
                p.terminate()
                p.wait(timeout=8)
            except subprocess.TimeoutExpired:
                p.kill()
                p.wait(timeout=5)
                errors.append('Servidor requirio SIGKILL')
    for c in cases:
        try:
            if scheduler_pids(c):
                run(c,'clean','scheduler')
            for pid in scheduler_pids(c):
                # Solo descriptores del scheduler.lock de este escenario.
                os.kill(pid,signal.SIGTERM)
                wait_for(lambda: pid not in scheduler_pids(c), 'Scheduler no termino', 5)
        except BaseException as exc:
            errors.append(str(exc))
            for pid in scheduler_pids(c):
                try:
                    os.kill(pid,signal.SIGKILL)
                except ProcessLookupError:
                    pass
    for port in ports:
        if listening(port):
            errors.append(f'Puerto {port} sigue ocupado')
    homes = {('HOME='+c['env']['HOME']).encode() for c in cases}
    for proc in Path('/proc').glob('[0-9]*'):
        try:
            env = (proc/'environ').read_bytes().split(b'\0')
        except OSError:
            continue
        if homes.intersection(env):
            errors.append('Proceso superviviente '+proc.name)
    check(not errors, '; '.join(errors))

def interrupt(signum, frame):
    raise KeyboardInterrupt(f'Senal {signum}')

signal.signal(signal.SIGTERM,interrupt)
code = 1
try:
    if os.environ.get('HERMES_TEST_HOST','127.0.0.1') not in ('127.0.0.1','localhost'):
        raise EnvironmentErrorTC('TC-013 requiere modo local en WSL/Linux de PC A')
    check(os.geteuid()!=0, 'Ejecutar como usuario sin privilegios')
    import re
    if re.fullmatch(r'[A-Za-z0-9._:-]{1,128}',client) is None:
        raise EnvironmentErrorTC('HERMES_TEST_CLIENT_ID invalido')

    # Auxiliar: enlaza las implementaciones reales, sin stubs ni cambios a src/.
    source = root/'config-probe.cpp'
    source.write_text(r'''#include "config.h"
#include <nlohmann/json.hpp>
#include <iostream>
int main(int argc, char** argv) {
 try {
  if(argc == 2) {
   hermes::CambiosConfiguracion c;
   c.puerto=true; c.valorPuerto=std::stoi(argv[1]);
   c.trabajosMaximos=true; c.valorTrabajosMaximos=2;
   hermes::actualizarConfiguracion(c);
  }
  auto c=hermes::cargarConfiguracion();
  std::cout << nlohmann::json({{"puerto",c.puerto},{"interfaz",c.interfaz},
    {"trabajos_maximos",c.trabajosMaximos},{"max_cola",c.maxCola},
    {"directorio_datos",c.directorioDatos}}).dump() << '\n';
  return 0;
 } catch(const std::exception& e) { std::cerr<<e.what()<<'\n'; return 1; }
}
''')
    helper = root/'config-probe'
    sources = ['src/config/config.cpp','src/config/config_update.cpp','src/events/event_log.cpp','src/network/access.cpp']
    build = subprocess.run(['g++','-Wall','-Wextra','-std=c++17','-I'+str(repo/'src/hermes/include'),str(source),
                            *[str(repo/'src/hermes'/s) for s in sources],'-pthread','-o',str(helper)],
                           capture_output=True,text=True,timeout=120)
    if build.returncode:
        raise EnvironmentErrorTC('No se pudo compilar auxiliar: '+build.stderr)
    print('Auxiliar de configuracion compilado con -Wall -Wextra:',build.stderr or 'sin advertencias')
    def probe(c, port=None, expected=0):
        p = subprocess.run([str(helper),*([] if port is None else [str(port)])],env=c['env'],
                           capture_output=True,text=True,timeout=10)
        check(p.returncode==expected,'API configuracion: '+p.stdout+p.stderr)
        return json.loads(p.stdout) if expected==0 else p.stderr

    c = scenario('inicializacion')
    baseline = health(c)
    original = c['conf'].read_bytes()
    defaults = json.loads(original)
    check(defaults == {'directorio_datos':str(c['data']),'trabajos_maximos':5,'max_cola':0,
                       'interfaz':'127.0.0.1','puerto':45820},'Valores iniciales incorrectos')
    check((c['conf'].parent/'config.lock').exists(),'Falta config.lock')
    health(c)
    check(c['conf'].read_bytes()==original,'Se sobrescribio configuracion existente')
    passed(1,'inicializacion idempotente, valores predeterminados y bloqueo')

    fallback = scenario('xdg-relativo',xdg='tc013-ruta-relativa')
    health(fallback)
    check(fallback['conf'].exists(),'No se uso HOME/.config')
    legacy = scenario('migracion')
    legacy['data'].mkdir(parents=True)
    old = legacy['data']/'config.json'
    old.write_text(json.dumps({'trabajos_maximos':3,'marca':'legado','puerto':49001}))
    before = old.read_bytes()
    health(legacy)
    check(json.loads(legacy['conf'].read_text())['marca']=='legado' and old.read_bytes()==before,'Migracion incorrecta')
    config(legacy,marca='nuevo',puerto=49002)
    health(legacy)
    check(json.loads(legacy['conf'].read_text())['marca']=='nuevo','Se mezclo legado con archivo nuevo')
    passed(2,'prioridad XDG absoluto, fallback relativo, migracion y prioridad del archivo nuevo')

    custom = scenario('datos-personalizados')
    first, second = custom['folder']/'datos-a', custom['folder']/'datos-b'
    config_path = custom['conf']
    config_path.write_text(json.dumps({'directorio_datos':str(first),'puerto':49003}))
    custom['data'] = first
    health(custom)
    (first/'marca.txt').write_text('conservar')
    check(custom['net'].exists() and (first/'jobs.json').exists(),'Rutas personalizadas incorrectas')
    check(not (first/'config.json').exists() and not (first/'network.json').exists(),'Configuracion movida a datos')
    snapshot = (first/'jobs.json').read_bytes()
    config(custom,directorio_datos=str(second))
    custom['data'] = second
    health(custom)
    check((second/'jobs.json').exists() and (first/'jobs.json').read_bytes()==snapshot and
          (first/'marca.txt').read_text()=='conservar','Cambio de ruta movio o borro datos')
    passed(3,'datos personalizados sin mover historial; configuracion y red en sus rutas propias')

    validation = scenario('validacion',{})
    for value in (-1,0,1,80,1023,1024,45820,65535,65536,2147483647,18446744073709551615,'1024',None,1.5):
        validation['conf'].write_text(json.dumps({'puerto':value,'marca':'conservar','trabajos_maximos':5}))
        if (validation['data']/'events.jsonl').exists():
            (validation['data']/'events.jsonl').write_text('')
        valid = type(value) is int and 1024<=value<=65535
        effective = probe(validation)['puerto']
        check(effective==(value if valid else 45820),f'Fallback puerto {value}')
        if not valid:
            check(any(e.get('level')=='WARN' and e.get('context',{}).get('clave')=='puerto' for e in events(validation)), 'Falta WARN puerto')
        if type(value) is int and -(2**31)<=value<2**31:
            previous = validation['conf'].read_bytes()
            answer = probe(validation,value,0 if valid else 1)
            if not valid:
                check(validation['conf'].read_bytes()==previous and '1024 y 65535' in answer,'API modifico archivo ante rechazo')
            else:
                check(json.loads(validation['conf'].read_text())['marca']=='conservar','API perdio claves')
        print(f'  puerto={value!r}; efectivo={effective}; API='+('validada' if type(value) is int and -(2**31)<=value<2**31 else 'tipo fuera de API int'))
    for values,expected in [({'trabajos_maximos':-1,'max_cola':-1},(1,0)),
                            ({'trabajos_maximos':1,'max_cola':0},(1,0)),
                            ({'trabajos_maximos':64,'max_cola':256},(64,256)),
                            ({'trabajos_maximos':65,'max_cola':257},(64,256)),
                            ({'trabajos_maximos':'x','max_cola':None},(5,0))]:
        validation['conf'].write_text(json.dumps(values))
        loaded=probe(validation)
        actual = (loaded['trabajos_maximos'],loaded['max_cola'])
        print(f'  capacidad={values}; esperado={expected}; observado={actual}')
        if actual != expected:
            finding = f'AC4: entrada {values}; esperado {expected}; observado {actual}'
            findings.append(finding)
            print('FAIL V4/AC4:',finding)
    for value in ('relativa','~/datos','$HOME/datos',''):
        validation['conf'].write_text(json.dumps({'directorio_datos':value,'interfaz':'0.0.0.0'}))
        loaded=probe(validation)
        check(loaded['directorio_datos']==str(validation['data']) and loaded['interfaz']=='127.0.0.1','Fallback ruta/interfaz incorrecto')
    validation['conf'].write_text('{"token":"sentinela_tc013",')
    loaded=probe(validation)
    check(loaded['puerto']==45820 and loaded['trabajos_maximos']==5,'Fallback JSON corrupto incorrecto')
    error = run(validation,'configmax','2',code=1)
    check('sentinela_tc013' not in error.stdout+error.stderr,'Filtracion de configuracion corrupta')
    validation['conf'].write_text(json.dumps({'puerto':49004,'marca':'conservar','interfaz':'127.0.0.1'}))
    run(validation,'configmax','2','--cola','3')
    saved=json.loads(validation['conf'].read_text())
    check(saved['puerto']==49004 and saved['marca']=='conservar' and saved['trabajos_maximos']==2 and saved['max_cola']==3,'configmax perdio claves')
    run(validation,'configmax','64','--cola','256')
    saved=json.loads(validation['conf'].read_text())
    check(saved['trabajos_maximos']==64 and saved['max_cola']==256,'CLI rechazo limites validos')
    before=validation['conf'].read_bytes()
    for args in [('configmax','65'),('configmax','--cola','257'),('configmax','2','--cola','257')]:
        run(validation,*args,code=1)
        check(validation['conf'].read_bytes()==before,'CLI escribio capacidad fuera de rango')
    if not findings:
        passed(4,'limites, tipos, enteros grandes, JSON corrupto, API estricta sin escritura parcial y configmax')

    inactive = scenario('salud-inactiva',{})
    state=health(inactive)
    (inactive['data']/'scheduler.lock').write_text('99999999')
    (inactive['data']/'network-service.lock').write_text('{"interfaz":"127.0.0.1","puerto":49000}')
    state=health(inactive)
    check(state['servicio']['activo'] is False and state['red']['activo'] is False and
          state['red']['puerto'] is None and state['red']['interfaz'] is None and
          state['trabajos']=={'en_ejecucion':0,'en_cola':0},'Registro obsoleto interpretado como activo')
    text=run(inactive,'health').stdout
    check('Servicio (scheduler): INACTIVO' in text and 'Servicio (Hermes Red): INACTIVO' in text,'Texto incoherente')
    check(not scheduler_pids(inactive),'health inicio scheduler')
    passed(5,'salud texto/JSON, registros obsoletos e inactividad sin iniciar scheduler')

    live = scenario('servicios-reales',{'interfaz':'127.0.0.1','puerto':free_port(),'trabajos_maximos':1,'max_cola':1,
                                      'redes_permitidas':['127.0.0.0/8']})
    live['net'].parent.mkdir(parents=True,exist_ok=True)
    live['net'].write_text(json.dumps({'habilitada':True,'clientes':[{'id':client,'direcciones':['127.0.0.1'],
        'ambito_trabajos':'tc013','operaciones':['submit','query','list','cancel'],'programas':['sleep','true']}]}))
    server=start(live)
    run(live,'job','sleep','120')
    wait_for(lambda: health(live)['trabajos']['en_ejecucion']==1,'No se observo trabajo local RUNNING')
    run(live,'red','job','127.0.0.1','sleep','120')
    wait_for(lambda: health(live)['trabajos']=={'en_ejecucion':1,'en_cola':1},'No se observo cola real')
    jobs=json.loads((live['data']/'jobs.json').read_text())
    check(sum(j['status']=='RUNNING' for j in jobs)==1 and sum(j['status']=='QUEUED' for j in jobs)==1,'Conteos no coinciden con persistencia')
    check(health(live)['servicio']['activo'] is True,'Scheduler real no detectado')
    passed(6,'scheduler activo y conteos reales 1 RUNNING + 1 QUEUED, trabajos local y remoto')

    port=json.loads(live['conf'].read_text())['puerto']
    state=health(live)
    check(state['red']['activo'] and state['red']['puerto']==port and state['red']['interfaz']=='127.0.0.1','Salud TCP incoherente')
    with socket.create_connection(('127.0.0.1',port),timeout=3) as sock:
        sock.sendall(b'{"version":1,"request_id":"tc013-ping","operation":"ping","params":{}}\n')
        with sock.makefile('rb') as stream:
            answer=json.loads(stream.readline(262145))
        check(answer.get('ok') and answer.get('result',{}).get('message')=='pong','Sin pong')
    occupied=scenario('puerto-ajeno',{'puerto':free_port(use_requested=False)})
    with socket.socket() as owner:
        owner.bind(('127.0.0.1',json.loads(occupied['conf'].read_text())['puerto']))
        owner.listen()
        check(health(occupied)['red']['activo'] is False,'Puerto ajeno interpretado como Hermes activo')
    passed(7,'health coincide con escucha ss y pong; puerto de otro programa no activa Hermes Red')

    # Registrar exclusividad con un puerto distinto para no confundirla con bind ocupado.
    with socket.socket() as reserve:
        reserve.bind(('127.0.0.1',0))
        next_port=reserve.getsockname()[1]
    check(not listening(next_port),'Puerto alternativo ocupado')
    config(live,puerto=next_port,interfaz='127.0.0.2')
    state=health(live)
    check(state['red']['puerto']==port and state['red']['interfaz']=='127.0.0.1' and
          state['red']['configurado']=={'interfaz':'127.0.0.2','puerto':next_port},'No distingue configuracion pendiente')
    run(live,'red','start',code=1)
    check(health(live)['red']['puerto']==port and not listening(next_port),'Segundo servidor altero al primero')
    stop(server)
    # Mantener interfaz loopback principal para comprobar ss y limpieza de forma uniforme.
    config(live,interfaz='127.0.0.1')
    server=start(live)
    state=health(live)
    check(state['red']['puerto']==next_port and state['red']['configurado']['puerto']==next_port,'Puerto no aplicado tras reinicio')
    stop(server)
    config(live,interfaz='127.0.0.2')
    with (live['folder']/'interface.log').open('w') as out:
        server2=subprocess.Popen([binary,'red','start'],env=live['env'],stdout=out,stderr=subprocess.STDOUT)
    processes.append((live,server2,live['folder']/'interface.log',next_port))
    wait_for(lambda: server2.poll() is not None or ('Hermes Red escuchando en' in (live['folder']/'interface.log').read_text() and listening(next_port)), 'Reinicio interfaz no listo')
    check(server2.poll() is None,'No inicio interfaz .2')
    check(health(live)['red']['interfaz']=='127.0.0.2' and f'127.0.0.2:{next_port}' in listening(next_port),'Interfaz no aplicada tras reinicio')
    passed(8,'escucha actual y proxima configuracion separadas; interfaz/puerto aplicados tras reinicio')

    stop(server2,abrupt=True)
    state=health(live)
    check(state['red']['activo'] is False and state['servicio']['activo'] is True,'SIGKILL dejo falso activo o perdio scheduler')
    run(live,'clean','scheduler')
    check(health(live)['servicio']['activo'] is False,'Scheduler no se detuvo')
    passed(9,'segundo servidor rechazado; SIGTERM libera puerto; SIGKILL no hereda actividad TCP al scheduler')

    history=scenario('errores-historicos',{})
    health(history)
    lines=[]
    for i in range(12):
        lines.append({'level':'ERROR','ts':f'2000-01-01 00:00:{i:02}','job_id':i,'message':f'error-{i} --token secreto_tc013\x1b[31m','context':{'privado':'oculto_tc013'}})
        lines.append({'level':'INFO','message':'informativo'})
    logfile=history['data']/'events.jsonl'
    logfile.write_text(''.join(json.dumps(e)+'\n' for e in lines))
    (history['data']/'jobs.json').write_text('[{"status":"FAILED"}]\n')
    state=health(history)
    errors=state['errores_recientes']
    check(len(errors)==10 and [e['job_id'] for e in errors]==[str(i) for i in range(11,1,-1)],'Limite u orden de errores incorrecto')
    check(all(set(e)=={'ts','job_id','message'} for e in errors),'Se expuso contexto de error')
    text=run(history,'health').stdout
    check('secreto_tc013' not in json.dumps(state)+text and 'oculto_tc013' not in text and '\x1b' not in text and '[REDACTED]' in text,'Redaccion de errores incorrecta')
    # Control fuera del secreto para comprobar el escape de forma independiente.
    with logfile.open('a') as output:
        output.write(json.dumps({'level':'ERROR','message':'control\x1b[31m','job_id':99})+'\n')
    check('\x1b' not in run(history,'health').stdout,'Control de terminal sin escapar')
    passed(10,'ultimos 10 ERROR sin ventana temporal, orden inverso, campos seguros y controles escapados; FAILED no es ERROR')

    broken=scenario('fuentes-incompletas',{})
    health(broken)
    jobs_path=broken['data']/'jobs.json'
    jobs_path.write_text('[{"status":"RUNNING"}]\n')
    before=jobs_path.read_bytes()
    state=health(broken)
    check(any('requieren recuperacion' in x for x in state['advertencias']) and jobs_path.read_bytes()==before,'health altero RUNNING obsoleto')
    jobs_path.write_text('[{"status":"DESCONOCIDO"}]\n')
    state=health(broken,1)
    check(state['trabajos'] is None and state['errores_recientes']==[],'Estado invalido publicado como conteo')
    jobs_path.write_text('{roto')
    (broken['data']/'jobs.json.bak').write_text('[{"status":"QUEUED"}]\n')
    check(health(broken)['trabajos']['en_cola']==1,'No recupero respaldo')
    jobs_path.write_text('{roto')
    (broken['data']/'jobs.json.bak').write_text('{roto')
    check(health(broken,1)['trabajos'] is None,'Corrupcion irrecuperable publicada como cero')
    jobs_path.write_text('[]\n')
    log=broken['data']/'events.jsonl'
    log.write_text('{invalido}\n'+json.dumps({'level':'ERROR','message':'entero'})+'\n'+json.dumps({'level':'ERROR','message':'parcial'}))
    state=health(broken,1)
    check(state['lineas_invalidas']==1 and len(state['errores_recientes'])==1,'JSONL invalido o parcial mal contado')
    log.write_text('')
    log.chmod(0)
    try:
        state=health(broken,1)
        check(state['errores_recientes'] is None and state['trabajos'] is not None,'Fallo bitacora anulo otras fuentes')
        check('NO DISPONIBLE' in run(broken,'health',code=1).stdout,'Texto sin NO DISPONIBLE')
    finally:
        log.chmod(0o600)
    for filename,key in [('scheduler.lock','servicio'),('network-service.lock','red')]:
        path=broken['data']/filename
        path.write_text('')
        path.chmod(0)
        try:
            state=health(broken,1)
            check((state[key]['activo'] if key=='servicio' else state[key]) is None,'Fuente inaccesible no es null')
            check(state['trabajos'] is not None,'Fallo de servicio anulo conteos')
        finally:
            path.chmod(0o600)
    passed(11,'RUNNING obsoleto sin mutacion; respaldo, corrupcion, JSONL parcial/invalido y fuentes inaccesibles')

    for args in [('health','--invalido'),('health','--json','extra')]:
        check('Uso: hermes health [--json]' in run(inactive,*args,code=1).stderr,'Argumentos invalidos sin uso')
    finished = True
    code=1 if findings else 0
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
        cleanup()
        cleanup_ok = True
    except BaseException as exc:
        print('FALLO DE LIMPIEZA:',exc,flush=True)
        code=1
    if finished and cleanup_ok:
        passed(12,'argumentos invalidos rechazados; servidores recogidos, schedulers detenidos, sin escuchas ni huerfanos')
    if code==0:
        print('PASS: RF-16 RF-24 TC-013 sin fallos.')
    for finding in findings:
        print('DEFECTO:',finding)
    print('Resultado:',code,flush=True)
sys.exit(code)
PY
