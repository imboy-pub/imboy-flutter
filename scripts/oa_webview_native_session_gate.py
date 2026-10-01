"""Physical Android WebView gate; loopback TLS, synthetic state, debug-only trust."""
import argparse
import hashlib
import http.server
import json
import os
from pathlib import Path
import shutil
import ssl
import subprocess
import tempfile
import threading
import time
from urllib.parse import urlsplit


class Fixture(http.server.BaseHTTPRequestHandler):
    records = []
    lock = threading.Lock()
    record_path = None

    def log_message(self, *_args):
        pass

    def do_GET(self):
        path = urlsplit(self.path).path
        cookie = self.headers.get('Cookie', '')
        probe = dict(session_a='oa_session=a' in cookie,
                     session_b='oa_session=b' in cookie, late_a='late_scope=a' in cookie)
        with self.lock:
            self.records.append(dict(path=path, **probe))
            self.record_path.write_text(json.dumps(self.records))
        self.send_response(200)
        if path in ['/a', '/b', '/c']:
            scope = path[1:]
            self.send_header('Set-Cookie', f'oa_session={scope}; Path=/; Secure; HttpOnly; SameSite=Lax')
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            body = f'''<html><body data-scope="{scope}"><script>
window.entryProbe={{old_storage:localStorage.getItem('oa_scope')!==null,
old_cookie:{str(probe['session_a'] or probe['session_b']).lower()}}};
localStorage.setItem('oa_scope','{scope}');
if ('{scope}'==='a') setTimeout(()=>{{document.cookie='late_scope=a; Path=/; Secure';}},8000);
</script></body></html>'''.encode()
        else:
            self.send_header('Content-Type', 'application/json')
            body = json.dumps(probe).encode()
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def certificate(run):
    cert, key = run / 'loopback.crt', run / 'loopback.key'
    with (run / 'openssl.log').open('w') as log:
        subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
                        '-keyout', str(key), '-out', str(cert), '-days', '1',
                        '-subj', '/CN=127.0.0.1', '-addext', 'subjectAltName=IP:127.0.0.1',
                        '-addext', 'basicConstraints=critical,CA:TRUE'],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    os.chmod(key, 0o600)
    subprocess.run(['openssl', 'verify', '-CAfile', str(cert), '-verify_ip',
                    '127.0.0.1', str(cert)], check=True, stdout=subprocess.DEVNULL)
    return cert, key


def tls_server(cert, key):
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Fixture)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(cert, key)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def debug_overlay(root, cert):
    overlay = root / 'android/app/src/gzCustomerDebug'
    if overlay.exists():
        raise RuntimeError('Debug overlay already exists; refusing to overwrite')
    files = {
        overlay / 'AndroidManifest.xml': '<manifest xmlns:android="http://schemas.android.com/apk/res/android" xmlns:tools="http://schemas.android.com/tools"><application android:networkSecurityConfig="@xml/oa_native_test_security" tools:replace="android:networkSecurityConfig" /></manifest>',
        overlay / 'res/xml/oa_native_test_security.xml': '<network-security-config><domain-config cleartextTrafficPermitted="false"><domain includeSubdomains="false">127.0.0.1</domain><trust-anchors><certificates src="@raw/oa_native_test_ca" /></trust-anchors></domain-config></network-security-config>',
        overlay / 'res/raw/oa_native_test_ca.crt': cert.read_text(),
    }
    for path, content in files.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
    return files


def remove_overlay(files):
    for path, content in files.items():
        if path.exists() and path.read_text() == content:
            path.unlink()
    directories = {parent for path in files for parent in path.parents
                   if 'gzCustomerDebug' in parent.parts}
    for path in sorted(directories, key=lambda p: len(p.parts), reverse=True):
        try:
            path.rmdir()
        except OSError:
            pass


def run_flutter(root, device, defines, run):
    log = run / 'device.log'
    with log.open('w') as output:
        process = subprocess.Popen(['flutter', 'test', '--no-pub', '--flavor',
                                    'gzCustomer', '-d', device,
                                    '--dart-define-from-file=' + str(defines),
                                    'integration_test/enterprise/oa_webview_native_session_test.dart'],
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
        content = log.read_text(errors='replace')
        passed = process.returncode == 0 and not forced and 'All tests passed!' in content
        return dict(passed=passed, exit=process.returncode, forced_stop=forced,
                    log_sha256=hashlib.sha256(log.read_bytes()).hexdigest())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device-file', required=True, type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    actual = subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], cwd=root, text=True)
    assert Path(actual.strip()) == root
    device = args.device_file.read_text().strip()
    assert device and '\n' not in device
    adb = Path.home() / 'Library/Android/sdk/platform-tools/adb'
    if not adb.exists():
        adb = shutil.which('adb')
    assert adb
    assert subprocess.check_output([str(adb), '-s', device, 'shell', 'getprop',
                                    'ro.kernel.qemu'], text=True).strip() != '1'
    run = Path(tempfile.mkdtemp(prefix='gz-oa-native-session-'))
    Fixture.record_path = run / 'observations.json'
    cert, key = certificate(run)
    overlay = debug_overlay(root, cert)
    servers, ports = [], []
    try:
        servers = [tls_server(cert, key), tls_server(cert, key)]
        for server in servers:
            port = server.server_port
            subprocess.run([str(adb), '-s', device, 'reverse', f'tcp:{port}', f'tcp:{port}'],
                           check=True, stdout=subprocess.DEVNULL)
            ports.append(port)
        defines = run / 'defines.json'
        defines.write_text(json.dumps(dict(APP_ENV='local', IMBOY_JPUSH_ENABLED='false',
                           OA_NATIVE_TEST_ORIGIN=f'https://127.0.0.1:{ports[0]}',
                           OA_NATIVE_FORBIDDEN_ORIGIN=f'https://127.0.0.1:{ports[1]}')))
        result = run_flutter(root, device, defines, run)
        entries = {r['path']: r for r in Fixture.records if r['path'] in ['/b', '/c']}
        server_ok = all(p in entries for p in ['/b', '/c']) and not any(
            entries[p]['session_a'] or entries[p]['session_b'] for p in ['/b', '/c'])
        server_ok = server_ok and not any(r['path'] == '/forbidden' for r in Fixture.records)
        result.update(server_oracle=server_ok, certificate_sha256=hashlib.sha256(cert.read_bytes()).hexdigest(),
                      device_trust_modified=False, system_trust_modified=False,
                      release_trust_modified=False, full_oa_sso_verified=False)
        result['status'] = 'PASS_NATIVE_WEBVIEW_SESSION' if result['passed'] and server_ok else 'FAIL_NATIVE_WEBVIEW_SESSION'
        (run / 'terminal.json').write_text(json.dumps(result, indent=2))
        print(result['status'], 'Evidence:', run)
        raise SystemExit(0 if result['status'] == 'PASS_NATIVE_WEBVIEW_SESSION' else 1)
    finally:
        for port in ports:
            subprocess.run([str(adb), '-s', device, 'reverse', '--remove', f'tcp:{port}'],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for server in servers:
            server.shutdown()
            server.server_close()
        remove_overlay(overlay)


if __name__ == '__main__':
    main()
