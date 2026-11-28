#!/usr/bin/env bash
# RNF-01, RNF-02, RNF-03 - Construccion desde clon limpio sin root.
# TC-014: dos clones del mismo commit, build documentado, humo e instalacion de usuario.
# Modo: local (Linux/WSL); TCP propio en loopback, sin PC B.
set -euo pipefail
umask 077
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
EVIDENCIA="$REPO/verif/results/results_TC-014.md"
for herramienta in git g++ make python3 ss mktemp tee; do
    command -v "$herramienta" >/dev/null || { echo "ENTORNO: falta $herramienta"; exit 2; }
done
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/hermes-TC-014.XXXXXX")"
export HOME="$TEST_ROOT/driver-home" XDG_CONFIG_HOME="$TEST_ROOT/driver-xdg"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$REPO/verif/results"
cleanup() {
    local estado=$?
    trap - EXIT
    printf '\nCodigo de salida TC-014: %s\n```\n' "$estado"
    rm -rf -- "$TEST_ROOT"
    exit "$estado"
}
trap cleanup EXIT
{
    printf '\n## Ejecucion: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf -- '- Modo: local\n- Commit del origen: %s\n' "$(git -C "$REPO" rev-parse HEAD)"
    printf -- '- Kernel: %s\n' "$(uname -r)"
    if [[ -n "$(git -C "$REPO" status --porcelain)" ]]; then
        printf -- '- Arbol origen: con cambios locales (no se copian al clon)\n'
    else
        printf -- '- Arbol origen: limpio\n'
    fi
    printf '\n```text\n'
} >>"$EVIDENCIA"
exec > >(tee -a "$EVIDENCIA") 2>&1
python3 -u - "$REPO" "$TEST_ROOT" <<'PY'
from concurrent.futures import ThreadPoolExecutor, as_completed
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import socket
import stat
import subprocess
import sys
import time

repo,root=map(Path,sys.argv[1:])
copies=[]
server=None
port=None
owned=False
expected_uid=os.geteuid()
source_before=None

class EnvironmentErrorTC(Exception):
    pass

def check(condition,message):
    if not condition:
        raise AssertionError(message)

def passed(n,message):
    print(f'PASS V{n}/AC{n}: {message}',flush=True)

def command(args,env=None,cwd=None,timeout=20):
    p=subprocess.run(list(map(str,args)),env=env,cwd=cwd,capture_output=True,text=True,timeout=timeout)
    check(p.returncode==0,f'{args[0:3]}: codigo {p.returncode}: {p.stdout[-3000:]} {p.stderr[-3000:]}')
    return p.stdout

def hermes(c,*args,installed=False):
    binary=c['installed'] if installed else c['binary']
    out=command([binary,*args],env=c['env'])
    print(f'  {"instalado" if installed else c["name"]} hermes {" ".join(map(str,args))}: {out.strip()}')
    return out

def git(path,*args):
    return command(['git','-C',path,*args])

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def source_fingerprint():
    paths=git(repo,'ls-files','-z','src/hermes').split('\0')
    result={}
    for name in filter(None,paths):
        path=repo/name
        if path.is_symlink():
            result[name]=('symlink',os.readlink(path))
        elif path.exists():
            result[name]=(stat.S_IMODE(path.stat().st_mode),digest(path))
        else:
            result[name]=None
    return result

def wait_for(fn,message,seconds=10):
    end=time.monotonic()+seconds
    while time.monotonic()<end:
        if fn():
            return
        time.sleep(.05)
    raise AssertionError(message)

def jobs(c):
    with (c['data']/'jobs.lock').open() as lock:
        fcntl.flock(lock,fcntl.LOCK_SH)
        result=json.loads((c['data']/'jobs.json').read_text())
    check(isinstance(result,list),'jobs.json no es arreglo')
    return result

def job(c,ident):
    result=[j for j in jobs(c) if j['job_id']==ident]
    check(len(result)==1,'Job ausente o duplicado')
    return result[0]

def submit(c,*args,installed=False):
    out=hermes(c,*args,installed=installed)
    ids=re.findall(r'^job ID:\s*(\d+)\s*$',out,re.M)
    check(len(ids)==1,'Admision sin ID valido')
    return int(ids[0])

def owner(pid):
    text=Path(f'/proc/{pid}/status').read_text()
    match=re.search(r'^Uid:\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)',text,re.M)
    check(match is not None and all(int(v)==expected_uid for v in match.groups()),'Proceso con UID inesperado')

def schedulers(c):
    found=set()
    for proc in Path('/proc').glob('[0-9]*'):
        try:
            for fd in (proc/'fd').iterdir():
                try:
                    if os.readlink(fd)==str(c['data']/'scheduler.lock'):
                        found.add(int(proc.name))
                except OSError:
                    pass
        except OSError:
            pass
    return found

def listening(p):
    return command(['ss','-H','-ltn','sport','=',f':{p}'])

def free_port():
    raw=os.environ.get('HERMES_TEST_PORT')
    if raw is not None:
        try:
            p=int(raw)
            if not 1024<=p<=65535:
                raise ValueError()
        except ValueError as exc:
            raise EnvironmentErrorTC('HERMES_TEST_PORT debe estar entre 1024 y 65535') from exc
    else:
        with socket.socket() as s:
            s.bind(('127.0.0.1',0))
            p=s.getsockname()[1]
    if p==45820 or listening(p):
        raise EnvironmentErrorTC(f'Puerto {p} reservado/ocupado')
    with socket.socket() as s:
        s.bind(('127.0.0.1',p))
    return p

def own_processes():
    homes={('HOME='+c['env']['HOME']).encode() for c in copies}
    found=[]
    for proc in Path('/proc').glob('[0-9]*'):
        try:
            if homes.intersection((proc/'environ').read_bytes().split(b'\0')):
                found.append(int(proc.name))
        except OSError:
            pass
    return found

def cleanup_services():
    errors=[]
    if server is not None and server.poll() is None:
        server.terminate()
        try:
            server.wait(timeout=8)
        except subprocess.TimeoutExpired:
            server.kill()
            server.wait(timeout=5)
            errors.append('Servidor requirio SIGKILL')
    for c in copies:
        if schedulers(c):
            try:
                hermes(c,'clean','scheduler')
            except BaseException as exc:
                errors.append(str(exc))
                for pid in schedulers(c):
                    try:
                        os.kill(pid,signal.SIGTERM)
                    except ProcessLookupError:
                        pass
    end=time.monotonic()+5
    while own_processes() and time.monotonic()<end:
        time.sleep(.05)
    for pid in own_processes():
        try:
            os.kill(pid,signal.SIGKILL)
            errors.append(f'Proceso propio {pid} requirio SIGKILL')
        except ProcessLookupError:
            pass
    check(not own_processes(),'Quedan procesos propios')
    if owned:
        check(not listening(port),'Puerto propio no liberado')
    check(not errors,'; '.join(errors))

signal.signal(signal.SIGTERM,lambda signum,frame: sys.exit(1))
code=1
finished=False
try:
    if expected_uid==0:
        raise EnvironmentErrorTC('Ejecute TC-014 como usuario sin privilegios')
    if os.environ.get('HERMES_TEST_HOST','127.0.0.1') not in ('127.0.0.1','localhost'):
        raise EnvironmentErrorTC('TC-014 requiere clones y servidor propios, modo local')
    os_release=Path('/etc/os-release').read_text()
    print('Sistema:', '; '.join(line for line in os_release.splitlines() if line.startswith(('PRETTY_NAME=','ID=','VERSION_ID='))))
    print(f'UID real={os.getuid()}, efectivo={expected_uid}')
    check(os.getuid()==expected_uid,'UID real y efectivo distintos')
    print('g++:',command(['g++','--version']).splitlines()[0])
    print('make:',command(['make','--version']).splitlines()[0])
    print('git:',command(['git','--version']).strip())
    print('Python:',sys.version.split()[0], '(solo ejecutor de pruebas)')
    check(sys.platform.startswith('linux'),'Entorno distinto de Linux/WSL')
    passed(1,'Linux/WSL y herramientas documentadas, usuario real/efectivo sin root')

    commit=git(repo,'rev-parse','HEAD').strip()
    source_before=source_fingerprint()
    for name in ('A','B'):
        folder=root/name
        clone=folder/'clone'
        folder.mkdir()
        env=dict(os.environ,HOME=str(folder/'home'),XDG_CONFIG_HOME=str(folder/'xdg'))
        c=dict(name=name,clone=clone,project=clone/'src/hermes',binary=clone/'src/hermes/hermes',env=env,
               data=Path(env['HOME'])/'.local/share/hermes/data',conf=Path(env['XDG_CONFIG_HOME'])/'hermes/config.json',
               net=Path(env['HOME'])/'.local/share/hermes/network/network.json',
               installed=Path(env['HOME'])/'.local/bin/hermes',log=folder/'make.log')
        copies.append(c)
        command(['git','clone','--no-local','--no-checkout',repo,clone],env=env,timeout=60)
        git(clone,'checkout','--detach',commit)
        check(git(clone,'rev-parse','HEAD').strip()==commit and not git(clone,'status','--porcelain'),'Clon no limpio/no corresponde al commit')
        check(not c['binary'].exists(),'El clon ya contenia un binario')
        header=c['project']/'include/nlohmann/json.hpp'
        check(header.is_file() and 'version 3.12.0' in header.read_text()[:500],'Dependencia JSON versionada ausente/inesperada')
        check('src/hermes/include/nlohmann/json.hpp' in git(clone,'ls-files'),'JSON no forma parte del clon')
        print(f'Clon {name}: HEAD={commit}, limpio, sin binario; nlohmann/json 3.12.0 incluido')
    passed(2,'dos clones locales independientes del mismo commit; sin copiar cambios ni binarios del origen')

    def build(c):
        command(['make','-C',c['project'],'clean'],env=c['env'])
        # Objetivo documentado all: inicializa solo la copia y su HOME temporal.
        with c['log'].open('w') as out:
            p=subprocess.run(['make','-C',c['project']],env=c['env'],stdout=out,stderr=subprocess.STDOUT,timeout=300)
        text=c['log'].read_text()
        check(p.returncode==0 and os.access(c['binary'],os.X_OK),'Compilacion '+c['name']+' fallo:\n'+text[-6000:])
        check(all(flag in text for flag in ('-std=c++17','-Iinclude','-pthread','-Wall','-Wextra')),'Flags documentados no observados')
        check(not re.search(r'\bwarning:',text),'Advertencias de compilacion:\n'+text[-6000:])
        check(not (c['binary'].stat().st_mode & (stat.S_ISUID|stat.S_ISGID)),'Binario setuid/setgid')
        for link,target in [('data',c['data']),('config',c['conf'].parent),('network',c['net'].parent)]:
            path=c['project']/link
            check(path.is_symlink() and os.readlink(path)==str(target),'Enlace del clon no aislado: '+link)
        check(c['conf'].is_file() and c['net'].is_file(),'make no inicializo archivos propios')
        print(f'Compilacion {c["name"]}: limpia, sin advertencias; SHA256={digest(c["binary"])}',flush=True)
        return c
    with ThreadPoolExecutor(max_workers=2) as executor:
        for result in as_completed([executor.submit(build,c) for c in copies]):
            result.result()
    versions=[hermes(c,'--version') for c in copies]
    check(versions[0]==versions[1],'Versiones distintas entre builds')
    print('SHA256 iguales:',digest(copies[0]['binary'])==digest(copies[1]['binary']), '(dato adicional; no se exige identidad binaria entre toolchains)')
    passed(3,'ambos clones compilan con make y flags actuales, sin descargas ni root; version coincidente')

    for c in copies:
        ident=submit(c,'job','echo','hola-tc014')
        wait_for(lambda: job(c,ident)['status']=='SUCCEEDED','Humo no termino SUCCEEDED')
        check(job(c,ident)['codigo_salida']==0,'Humo codigo no cero')
        detail=hermes(c,'filter','id',str(ident))
        check('Estado: SUCCEEDED' in detail and 'Programa: echo' in detail,'Consulta no coincide')
        check('health' in hermes(c,'--help'),'Ayuda no corresponde al CLI actual')
        state=json.loads(hermes(c,'health','--json'))
        check(state['completo'] is True and state['servicio']['activo'] is True,'Salud del clon no disponible')
        for pid in schedulers(c):
            owner(pid)
    passed(4,'humo --version/--help/job/filter/health en ambos binarios y schedulers bajo UID del usuario')

    c=copies[0]
    command(['make','-C',c['project'],'install'],env=c['env'])
    check(c['installed'].is_file() and digest(c['installed'])==digest(c['binary']),'Instalacion no coincide con build')
    check(not (c['installed'].stat().st_mode & (stat.S_ISUID|stat.S_ISGID)),'Instalacion privilegiada')
    check(hermes(c,'--version',installed=True)==versions[0],'Version instalada distinta')
    ident=submit(c,'job','sleep','120',installed=True)
    wait_for(lambda: job(c,ident)['status']=='RUNNING' and job(c,ident)['pid']>0,'Job instalado no tiene PID real')
    owner(job(c,ident)['pid'])
    hermes(c,'cancel',str(ident),installed=True)
    wait_for(lambda: job(c,ident)['status']=='CANCELED','Job instalado no se cancelo')
    check(job(c,ident)['codigo_salida']==-15,'Job instalado no termino por SIGTERM')
    passed(5,'make install en HOME temporal; binario igual, sin setuid/setgid; Job real ejecutado y cancelado sin root')

    # Humo TCP del binario instalado: prueba operacion normal sin privilegios.
    client=os.environ.get('HERMES_TEST_CLIENT_ID','PC-B')
    if re.fullmatch(r'[A-Za-z0-9._:-]{1,128}',client) is None:
        raise EnvironmentErrorTC('HERMES_TEST_CLIENT_ID invalido')
    c['net'].write_text(json.dumps({'habilitada':True,'clientes':[{'id':client,'direcciones':['127.0.0.1'],
        'operaciones':['submit','query','list','cancel'],'programas':['true']}]}))
    log=root/'server.log'
    for attempt in range(3):
        port=free_port()
        settings=json.loads(c['conf'].read_text())
        settings.update(interfaz='127.0.0.1',puerto=port,redes_permitidas=['127.0.0.0/8'])
        c['conf'].write_text(json.dumps(settings))
        with log.open('w') as output:
            server=subprocess.Popen([c['installed'],'red','start'],env=c['env'],stdout=output,stderr=subprocess.STDOUT)
        end=time.monotonic()+10
        while server.poll() is None and time.monotonic()<end:
            if 'Hermes Red escuchando en' in log.read_text() and listening(port):
                owned=True
                break
            time.sleep(.05)
        if owned:
            break
        if server.poll() is None:
            server.terminate()
            server.wait(timeout=8)
        if os.environ.get('HERMES_TEST_PORT') or attempt==2:
            raise AssertionError('Arranque TCP fallo: '+log.read_text()[-4000:])
    check(all(row.split()[3]==f'127.0.0.1:{port}' for row in listening(port).splitlines()),'Escucha no es loopback')
    owner(server.pid)
    ident=submit(c,'red','job','127.0.0.1','true',installed=True)
    wait_for(lambda: job(c,ident)['status']=='SUCCEEDED','Job TCP del instalado no termino')
    check(job(c,ident)['codigo_salida']==0 and job(c,ident).get('tipo_ejecucion')=='remote','Job TCP no identificado')
    server.terminate()
    server.wait(timeout=8)
    check(server.returncode==0 and 'Hermes Red detenido' in log.read_text(),'Parada TCP no ordenada')
    check(not listening(port),'Puerto no liberado')
    passed(6,f'binario instalado atiende TCP 127.0.0.1:{port} y ejecuta Job remoto sin privilegios')

    installed_jobs=(c['data']/'jobs.json').read_bytes()
    installed_config=c['conf'].read_bytes()
    command(['make','-C',c['project'],'uninstall'],env=c['env'])
    check(not c['installed'].exists(),'uninstall no retiro binario')
    check((c['data']/'jobs.json').read_bytes()==installed_jobs and c['conf'].read_bytes()==installed_config,'uninstall altero datos/configuracion')
    check(source_fingerprint()==source_before,'Se altero src/ del repositorio de trabajo')
    passed(7,'uninstall retira solo instalacion temporal; datos y src/ del origen conservados')
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
        cleanup_services()
        if source_before is not None:
            check(source_fingerprint()==source_before,'El origen src/ cambio durante la prueba')
        if finished:
            passed(8,'servidor recogido, schedulers detenidos y puerto libre; sin procesos propios; clones/HOME eliminados al salir')
    except BaseException as exc:
        print('FALLO DE LIMPIEZA:',exc,flush=True)
        code=1
    if code==0:
        print('PASS: RNF-01 RNF-02 RNF-03 TC-014 sin fallos.')
    print('Resultado:',code,flush=True)
sys.exit(code)
PY
