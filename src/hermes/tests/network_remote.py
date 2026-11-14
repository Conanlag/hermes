#!/usr/bin/env python3
"""RF-18: TCP sin certificados, scheduler y equivalencia con el CLI local."""
import json
import os
from pathlib import Path
import select
import signal
import socket
import subprocess
import sys
import tempfile
import re
import uuid
import time

binary = Path(__file__).resolve().parents[1] / 'hermes'

with tempfile.TemporaryDirectory(prefix='hermes-rf18-') as tmp:
    root = Path(tmp)
    alice, bob, unknown = '127.0.0.1', '127.0.0.2', '127.0.0.3'
    with socket.socket() as probe:
        probe.bind(('127.0.0.1', 0))
        port = probe.getsockname()[1]
    def home(name):
        directory = root / name
        config = directory / '.config/hermes'
        config.mkdir(parents=True)
        (config / 'config.json').write_text(json.dumps({'puerto': port, 'trabajos_maximos': 1, 'max_cola': 4}))
        network = directory / '.local/share/hermes/network'
        network.mkdir(parents=True)
        return directory, dict(os.environ, HOME=str(directory), XDG_CONFIG_HOME=str(config.parent))
    server_home, server_env = home('server-home')
    alice_home, alice_env = home('alice-home')
    _, bob_env = home('bob-home')
    policy_path = server_home / '.local/share/hermes/network/network.json'
    ignore_term = root / 'ignore-term'
    ignore_term.write_text('#!' + sys.executable + '\nimport signal,time,sys\nfrom pathlib import Path\nsignal.signal(signal.SIGTERM, signal.SIG_IGN)\nPath(sys.argv[1]).touch()\ntime.sleep(30)\n')
    ignore_term.chmod(0o700)
    policy = {'habilitada': True, 'clientes': [
        {'id': 'pc-a', 'direcciones': [alice], 'operaciones': ['submit', 'query', 'list', 'cancel'],
         'programas': ['/usr/bin/true', '/usr/bin/false', '/usr/bin/sleep', 'true', 'false', 'sleep', str(ignore_term)]},
        {'id': 'pc-b', 'direcciones': [bob], 'operaciones': ['query', 'list'], 'programas': []}]}
    policy_path.write_text(json.dumps(policy))
    def start():
        process = subprocess.Popen([str(binary), 'red', 'start'], env=server_env,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if not select.select([process.stdout], [], [], 10)[0] or 'escuchando' not in process.stdout.readline():
            process.kill()
            out, err = process.communicate()
            raise AssertionError((out, err))
        return process
    def stop(process):
        if process.poll() is None:
            process.send_signal(signal.SIGTERM)
            assert process.wait(timeout=5) == 0
        process.stdout.close()
        process.stderr.close()
    def rpc(*args, env=alice_env, success=True):
        operation, host, *values = map(str, args)
        ident = uuid.uuid4().hex
        params = {}
        if operation == 'job':
            ident, program, *arguments = values[1:]
            operation = 'submit'
            params = {'programa': program, 'argumentos': arguments}
        elif operation in ('query', 'cancel'):
            params = {'job_id': int(values[0])}
        elif values:
            params = {'after': int(values[0])}
        response = raw(bob if env is bob_env else alice, json.dumps({
            'version': 1, 'request_id': ident, 'operation': operation, 'params': params}).encode() + b'\n')
        assert response['ok'] == success, response
        return response
    def human(*args, env=alice_env, remote=True):
        command = [str(binary)] + (['red'] if remote else []) + list(map(str, args))
        return subprocess.run(command, env=env, capture_output=True, text=True, timeout=15)
    def query(job_id, **kwargs):
        return rpc('query', 'localhost', job_id, **kwargs)
    def terminal(job_id, expected, timeout=10):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            result = query(job_id)['result']
            if result['status'] == expected:
                return result
            time.sleep(0.1)
        raise AssertionError((expected, result))
    def raw(source, payload):
        with socket.socket() as tcp:
            tcp.settimeout(5)
            tcp.bind((source, 0))
            tcp.connect(('127.0.0.1', port))
            tcp.sendall(payload)
            data = b''
            while not data.endswith(b'\n'):
                chunk = tcp.recv(4096)
                if not chunk:
                    break
                data += chunk
            return json.loads(data) if data else None
    server = start()
    try:
        result = rpc('job', 'localhost', '--request-id', 'first', '/usr/bin/true')
        first = result['result']['job_id']
        assert terminal(first, 'SUCCEEDED')['codigo_salida'] == 0
        duplicate = rpc('job', 'localhost', '--request-id', 'first', '/usr/bin/true')
        assert duplicate['result']['duplicated'] and duplicate['result']['job_id'] == first
        assert rpc('job', 'localhost', '--request-id', 'first', '/usr/bin/false', success=False)['error'] == 'JOB_OPERATION_FAILED'
        failed = rpc('job', '127.0.0.1', '--request-id', 'failed', '/usr/bin/false')['result']['job_id']
        assert terminal(failed, 'FAILED')['codigo_salida'] == 1
        assert rpc('job', 'localhost', '--request-id', 'blocked', '/bin/sh', '-c', 'true', success=False)['error'] == 'PROGRAM_NOT_ALLOWED'
        assert rpc('job', 'localhost', '--request-id', 'blocked', '/usr/bin/true', env=bob_env, success=False)['error'] == 'UNAUTHORIZED'
        assert query(first, env=bob_env, success=False)['error'] == 'NOT_FOUND'
        assert rpc('list', 'localhost', env=bob_env)['result']['jobs'] == []
        listing = rpc('list', 'localhost')['result']
        assert {j['job_id'] for j in listing['jobs']} == {first, failed}
        assert rpc('list', 'localhost', listing['next_after'])['result']['jobs'] == []
        running = rpc('job', 'localhost', '--request-id', 'running', '/usr/bin/sleep', '30')['result']['job_id']
        terminal(running, 'RUNNING')
        queued = rpc('job', 'localhost', '--request-id', 'queued', '/usr/bin/sleep', '30')['result']['job_id']
        assert query(queued)['result']['status'] == 'QUEUED'
        assert rpc('cancel', 'localhost', running, env=bob_env, success=False)['error'] == 'UNAUTHORIZED'
        assert rpc('cancel', 'localhost', queued)['result']['cancel_requested']
        terminal(queued, 'CANCELED')
        assert rpc('cancel', 'localhost', running)['result']['cancel_requested']
        terminal(running, 'CANCELED')
        ready = root / 'ready'
        stubborn = rpc('job', 'localhost', '--request-id', 'ignore-term', ignore_term, ready)['result']['job_id']
        deadline = time.monotonic() + 5
        while not ready.exists():
            assert time.monotonic() < deadline
            time.sleep(0.05)
        rpc('cancel', 'localhost', stubborn)
        terminal(stubborn, 'CANCELED', timeout=10)
        assert rpc('cancel', 'localhost', first, success=False)['error'] == 'NOT_CANCELABLE'
        # Los jobs locales no se exponen ni se cancelan desde la red.
        local = subprocess.run([str(binary), 'job', '/usr/bin/true'], env=server_env,
                               capture_output=True, text=True, timeout=5)
        assert local.returncode == 0
        jobs = json.loads((server_home / '.local/share/hermes/data/jobs.json').read_text())
        local_id = next(j['job_id'] for j in jobs if not j.get('propietario_remoto'))
        assert query(local_id, success=False)['error'] == 'NOT_FOUND'
        assert rpc('cancel', 'localhost', local_id, success=False)['error'] == 'NOT_FOUND'
        # El origen sin registro no puede adoptar una identidad declarada en JSON.
        rejected = raw(unknown, json.dumps({'version': 1, 'request_id': 'spoof',
            'client_id': 'pc-a', 'operation': 'submit',
            'params': {'programa': 'true', 'argumentos': []}}).encode() + b'\n')
        assert rejected['error'] == 'UNAUTHORIZED'
        assert not (alice_home / '.local/share/hermes/network/client.json').exists()
        # La presentación y los filtros usan la misma semántica local.
        remote_detail = human('filter', 'localhost', 'id', first)
        local_detail = human('filter', 'id', first, env=server_env, remote=False)
        assert (remote_detail.returncode, remote_detail.stdout, remote_detail.stderr) == (
            local_detail.returncode, local_detail.stdout, local_detail.stderr)
        for kind, value in [('status', 'FAILED'), ('programa', '/usr/bin/false'),
                            ('programa', 'no-such-program'), ('id', 4294967295), ('id', '00004294967295')]:
            remote_result = human('filter', 'localhost', kind, value)
            local_result = human('filter', kind, value, env=server_env, remote=False)
            assert (remote_result.returncode, remote_result.stdout, remote_result.stderr) == (
                local_result.returncode, local_result.stdout, local_result.stderr), (kind, value)
        # request_id es opcional; nombres de programa usan PATH del ejecutor.
        one = human('job', 'localhost', 'sleep', '0.1')
        two = human('job', 'localhost', 'sleep', '0.1')
        assert one.returncode == two.returncode == 0, (one.stderr, two.stderr)
        one_id = int(re.search(r'job ID: (\d+)', one.stdout)[1])
        two_id = int(re.search(r'job ID: (\d+)', two.stdout)[1])
        assert one_id != two_id and 'PID:' in one.stdout and not one.stdout.startswith('{')
        terminal(one_id, 'SUCCEEDED')
        terminal(two_id, 'SUCCEEDED')
        for rid in ('semantics.1:test', 'semantics-2'):
            accepted = human('job', 'localhost', '--request-id', rid, 'sleep', '0.1')
            assert accepted.returncode == 0, accepted.stderr
            reused = human('job', 'localhost', '--request-id', rid, 'sleep', '0.1')
            assert reused.returncode == 0 and 'Solicitud duplicada' in reused.stdout
            assert re.search(r'job ID: (\d+)', reused.stdout)[1] == re.search(r'job ID: (\d+)', accepted.stdout)[1]
            terminal(int(re.search(r'job ID: (\d+)', accepted.stdout)[1]), 'SUCCEEDED')
        # La ausencia y la cancelación terminal conservan mensaje/código local.
        for value in (first, 4294967295):
            remote_cancel = human('cancel', 'localhost', value)
            local_cancel = human('cancel', value, env=server_env, remote=False)
            assert (remote_cancel.returncode, remote_cancel.stdout, remote_cancel.stderr) == (
                local_cancel.returncode, local_cancel.stdout, local_cancel.stderr)
        for args in [('filter', 'status', 'bad'), ('filter', 'invalid-type', '1'), ('cancel', '0'),
                     ('cancel', '4294967296'), ('job', '--request-id', 'bad id', 'sleep')]:
            remote_invalid = human(args[0], 'localhost', *args[1:])
            local_invalid = human(*args, env=server_env, remote=False)
            assert remote_invalid.returncode == local_invalid.returncode == 1
            assert remote_invalid.stderr == local_invalid.stderr
        assert raw(alice, b'bad\n')['error'] == 'INVALID_JSON'
        assert query(first)['ok']
        stop(server)
        # Una dirección adicional del mismo registro conserva propiedad e historial.
        policy['clientes'][0]['direcciones'].append('127.0.0.4')
        policy_path.write_text(json.dumps(policy))
        server = start()
        assert raw('127.0.0.4', json.dumps({'version': 1, 'request_id': 'new-ip',
            'operation': 'query', 'params': {'job_id': first}}).encode() + b'\n')['ok']
        assert query(first)['result']['status'] == 'SUCCEEDED'
        assert rpc('job', 'localhost', '--request-id', 'first', '/usr/bin/true')['result']['duplicated']
        assert len([j for j in json.loads((server_home / '.local/share/hermes/data/jobs.json').read_text())
                    if j.get('request_id', '').endswith('-first')]) == 1
    finally:
        stop(server)
        subprocess.run([str(binary), 'clean', 'scheduler'], env=server_env, capture_output=True, timeout=35)
print('RF-18 OK: TCP sin certificados, permisos por origen, envío, resultados, listado, cancelación, deduplicación y persistencia')
