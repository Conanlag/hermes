#!/usr/bin/env python3
"""RNF-08: pruebas TCP aisladas de solicitudes y recuperación del servicio."""
import json
import os
from pathlib import Path
import select
import signal
import socket
import subprocess
import tempfile

binary = Path(__file__).resolve().parents[1] / 'hermes'
with tempfile.TemporaryDirectory(prefix='hermes-rnf08-') as tmp:
    directory = Path(tmp) / '.config/hermes'
    directory.mkdir(parents=True)
    env = dict(os.environ, HOME=tmp, XDG_CONFIG_HOME=str(directory.parent))
    with socket.socket() as probe:
        probe.bind(('127.0.0.1', 0))
        port = probe.getsockname()[1]
    (directory / 'config.json').write_text(json.dumps({'puerto': port}))
    server = subprocess.Popen([str(binary), 'red', 'start'], env=env, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    def connect():
        return socket.create_connection(('127.0.0.1', port), timeout=5)
    def receive(client):
        response = b''
        while not response.endswith(b'\n'):
            chunk = client.recv(4096)
            assert chunk, response
            response += chunk
        return json.loads(response)
    def request(payload, half_close=False):
        with connect() as client:
            client.sendall(payload)
            if half_close:
                client.shutdown(socket.SHUT_WR)
            return receive(client)
    ping = {'version': 1, 'request_id': 'test-1', 'operation': 'ping', 'params': {}}
    wire = json.dumps(ping).encode() + b'\n'
    def healthy():
        assert server.poll() is None
        result = request(wire)
        assert result['ok'] and result['request_id'] == 'test-1'
        assert result['result']['message'] == 'pong'
    try:
        assert select.select([server.stdout], [], [], 10)[0]
        assert 'escuchando' in server.stdout.readline()
        cases = [(b'bad\n', 'INVALID_JSON'), (b'\xff\n', 'INVALID_JSON'),
                 (b'[]\n', 'INVALID_REQUEST'), (b'{}\n', 'INVALID_REQUEST_ID'),
                 (b' ' * 16385 + b'\n', 'MESSAGE_TOO_LARGE'),
                 (b'[' * 100 + b'0' + b']' * 100 + b'\n', 'INVALID_JSON')]
        for patch, code in [({'version': 2}, 'UNSUPPORTED_VERSION'),
                            ({'version': True}, 'INVALID_VERSION'),
                            ({'version': 18446744073709551615}, 'UNSUPPORTED_VERSION'),
                            ({'request_id': 'bad id'}, 'INVALID_REQUEST_ID'),
                            ({'operation': 8}, 'INVALID_OPERATION'),
                            ({'operation': 'unknown'}, 'UNKNOWN_OPERATION'),
                            ({'params': []}, 'INVALID_PARAMS'),
                            ({'params': {'extra': 1}}, 'INVALID_PARAMS'),
                            ({'operation': 'submit'}, 'UNAUTHORIZED'),
                            ({'operation': 'cancel'}, 'UNAUTHORIZED')]:
            cases.append((json.dumps(dict(ping, **patch)).encode() + b'\n', code))
        missing = dict(ping)
        del missing['params']
        cases.append((json.dumps(missing).encode() + b'\n', 'INVALID_PARAMS'))
        for payload, expected in cases:
            assert request(payload)['error'] == expected, expected
            healthy()
        assert request(b'{', half_close=True)['error'] == 'INCOMPLETE_MESSAGE'
        healthy()
        # Un cliente lento no bloquea a otro y vence aunque envíe datos parciales.
        with connect() as slow:
            slow.sendall(b'{')
            healthy()
            assert receive(slow)['error'] == 'REQUEST_TIMEOUT'
        with connect() as fragmented:
            fragmented.sendall(wire[:10])
            healthy()
            fragmented.sendall(wire[10:])
            assert receive(fragmented)['ok']
        # Cada conexión procesa un único mensaje, aunque lleguen varios juntos.
        assert request(wire + wire)['ok']
        for _ in range(10):
            with connect() as disconnected:
                disconnected.sendall(b'bad\n')
        healthy()
        # Verifica que el filtro de RF-20 siga rechazando antes del protocolo.
        server.send_signal(signal.SIGTERM)
        assert server.wait(timeout=3) == 0
        config = {'puerto': port, 'redes_permitidas': []}
        (directory / 'config.json').write_text(json.dumps(config))
        server.stdout.close()
        server.stderr.close()
        server = subprocess.Popen([str(binary), 'red', 'start'], env=env, text=True,
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        assert select.select([server.stdout], [], [], 5)[0]
        assert 'escuchando' in server.stdout.readline()
        with connect() as denied:
            try:
                assert denied.recv(4096) == b''
            except ConnectionResetError:
                pass
        assert server.poll() is None
        server.send_signal(signal.SIGTERM)
        assert server.wait(timeout=3) == 0
    finally:
        if server.poll() is None:
            server.kill()
            server.wait()
        server.stdout.close()
        server.stderr.close()
print('RNF-08 OK: validación, límites, clientes lentos, desconexiones y recuperación')
