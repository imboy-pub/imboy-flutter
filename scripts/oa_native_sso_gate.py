"""Real Android enterprise UI -> real backend SSO -> synthetic HTTPS OA."""
import argparse
import hashlib
import http.server
import json
import os
from pathlib import Path
import ssl
import subprocess
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

from oa_webview_native_session_gate import certificate, debug_overlay, remove_overlay


class Oa(http.server.BaseHTTPRequestHandler):
    fixture = None
    redirect = None
    outcomes = []

    def log_message(self, *_args):
        pass

    def do_GET(self):
        parsed = urllib.parse.urlsplit(self.path)
        if parsed.path != '/sso/cb':
            self.send_error(404)
            return
        query = urllib.parse.parse_qs(parsed.query)
        try:
            assert set(query) == {'code', 'state'}
            body = dict(code=query['code'][0], nonce=query['state'][0],
                        redirect_uri=self.redirect)
            good, identity = self.exchange(body)
            replay, _ = self.exchange(body)
            assert good == 200 and replay == 404 and identity['user_id'] == 995011
            assert identity['external_user_id'] == 'synthetic-mobile-oa-user'
            assert not self.headers.get('Authorization')
            self.outcomes.append(dict(exchange=good, replay=replay,
                                      user_id=identity['user_id'], jwt_injected=False))
            page = b'<html><body data-native-sso="995011">Synthetic OA ready</body></html>'
            self.send_response(200)
            self.send_header('Set-Cookie', 'native_oa_session=synthetic; Path=/; HttpOnly; Secure; SameSite=Lax')
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(page)))
            self.end_headers()
            self.wfile.write(page)
        except Exception as error:
            self.outcomes.append(dict(error_type=type(error).__name__))
            self.send_error(500)

    def exchange(self, body):
        request = urllib.request.Request(
            f'http://127.0.0.1:{self.fixture["port"]}/api/internal/v1/oa/sso/exchange',
            data=json.dumps(body).encode(), headers={
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ' + self.fixture['native_oa']['credential']})
        try:
            response = urllib.request.urlopen(request, timeout=10)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            return response.code, json.load(response)


def wait_fixture(process, run):
    pointer = Path('/tmp/gz-mobile-native-fixture-run-path')
    deadline = time.monotonic() + 180
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError('Backend fixture exited before readiness')
        if pointer.exists():
            backend = Path(pointer.read_text().strip())
            ready = backend / 'mobile-fixture.json'
            if ready.exists() and ready.stat().st_mtime >= run.stat().st_ctime:
                return backend, json.loads(ready.read_text())
        time.sleep(1)
    raise TimeoutError('Backend fixture readiness timed out')


def native(root, device, defines, run):
    log = run / 'device.log'
    with log.open('w') as output:
        process = subprocess.Popen(['flutter', 'test', '--no-pub', '--flavor',
            'gzCustomer', '-d', device, '--dart-define-from-file=' + str(defines),
            'integration_test/enterprise/enterprise_scope_native_test.dart'],
            cwd=root, stdout=output, stderr=subprocess.STDOUT)
        deadline = time.monotonic() + 1200
        forced = False
        while process.poll() is None:
            time.sleep(2)
            if '[E]' in log.read_text(errors='replace') or time.monotonic() > deadline:
                forced = True
                process.send_signal(2)
                try:
                    process.wait(timeout=20)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        return process.returncode == 0 and not forced and 'All tests passed!' in log.read_text(errors='replace')


def build_defines(args, fixture, run):
    defines = json.loads(args.base_defines.read_text())
    defines.update(API_BASE_URL_OVERRIDE=f'http://127.0.0.1:{fixture["port"]}',
        WS_URL_OVERRIDE=f'ws://127.0.0.1:{fixture["port"]}/api/v1/ws',
        SOLIDIFIED_KEY_OVERRIDE=fixture['sign_key'],
        TEST_SYNTHETIC_ACCOUNT=fixture['account'], TEST_SYNTHETIC_PASSWORD=fixture['password'],
        TEST_ROOT_DEPARTMENT=fixture['directory']['root_department'],
        TEST_CHILD_DEPARTMENT=fixture['directory']['child_department'],
        TEST_JOIN_CODE=fixture['join_code'], TEST_NATIVE_OA_SSO='true',
        TEST_NATIVE_ORG_GOVERNANCE=str(fixture.get('native_org_governance', False)).lower())
    config = run / 'defines.json'
    config.write_text(json.dumps(defines))
    os.chmod(config, 0o600)
    return config


def arguments():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device-file', required=True, type=Path)
    parser.add_argument('--backend-fixture-script', required=True, type=Path)
    parser.add_argument('--deps-root', required=True, type=Path)
    parser.add_argument('--base-defines', required=True, type=Path)
    return parser.parse_args()


def tls_oa(cert, key):
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Oa)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(cert, key)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def finish(passed, backend, process, run):
    if passed:
        (backend / 'mobile.success').touch()
        (backend / 'native-oa.success').touch()
    (backend / 'mobile.done').touch()
    process.wait(timeout=60)
    oracle = backend / 'native-oa-oracle.json'
    success = passed and process.returncode == 0 and oracle.exists() and len(Oa.outcomes) == 1
    success = success and Oa.outcomes[0].get('exchange') == 200
    result = dict(status='PASS_NATIVE_OA_SSO' if success else 'FAIL_NATIVE_OA_SSO',
        native_pass=passed, backend_exit=process.returncode, backend_run=str(backend),
        oa_outcomes=Oa.outcomes, device_log_sha256=hashlib.sha256((run / 'device.log').read_bytes()).hexdigest(),
        customer_oa_verified=False, production_ready=False, release_trust_modified=False)
    (run / 'terminal.json').write_text(json.dumps(result, indent=2))
    print(result['status'], 'Evidence:', run)
    raise SystemExit(0 if success else 1)

def physical_device(device_file):
    device = device_file.read_text().strip()
    assert device and '\n' not in device
    adb = str(Path.home() / 'Library/Android/sdk/platform-tools/adb')
    assert subprocess.check_output([adb, '-s', device, 'shell', 'getprop', 'ro.kernel.qemu'], text=True).strip() != '1'
    return device, adb


def main():
    args = arguments()
    root = Path(__file__).resolve().parents[1]
    assert Path(subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], cwd=root, text=True).strip()) == root
    device, adb = physical_device(args.device_file)
    import tempfile
    run = Path(tempfile.mkdtemp(prefix='gz-native-oa-sso-'))
    cert, key = certificate(run)
    overlay = debug_overlay(root, cert)
    server = None
    backend = None
    process = None
    ports = []
    try:
        server = tls_oa(cert, key)
        Oa.redirect = f'https://127.0.0.1:{server.server_port}/sso/cb'
        env = dict(os.environ, IMBOY_DEPS_ROOT=str(args.deps_root),
                   IMBOY_NATIVE_OA_REDIRECT=Oa.redirect)
        with (run / 'backend.log').open('w') as log:
            process = subprocess.Popen(['bash', str(args.backend_fixture_script)],
                env=env, stdout=log, stderr=subprocess.STDOUT)
        backend, fixture = wait_fixture(process, run)
        assert fixture['synthetic_only'] and fixture['package'] == 'pub.imboy.app.gzcustomer'
        assert fixture['native_oa']['redirect_uri'] == Oa.redirect
        Oa.fixture = fixture
        for port in [server.server_port, fixture['port']]:
            subprocess.run([adb, '-s', device, 'reverse', f'tcp:{port}', f'tcp:{port}'],
                check=True, stdout=subprocess.DEVNULL)
            ports.append(port)
        config = build_defines(args, fixture, run)
        passed = native(root, device, config, run)
        finish(passed, backend, process, run)
    finally:
        if backend is not None:
            (backend / 'mobile.done').touch()
        if process is not None and process.poll() is None:
            try:
                process.wait(timeout=20)
            except subprocess.TimeoutExpired:
                process.terminate()
                process.wait(timeout=10)
        for port in ports:
            subprocess.run([adb, '-s', device, 'reverse', '--remove', f'tcp:{port}'],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if server is not None:
            server.shutdown()
            server.server_close()
        remove_overlay(overlay)


if __name__ == '__main__':
    main()
