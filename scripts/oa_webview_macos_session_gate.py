"""Native macOS OA session gate, isolated bundle and pinned loopback TLS."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import uuid

from oa_webview_native_session_gate import Fixture, certificate, tls_server


def run_native(root, defines, env, log, result):
    with log.open('w') as output:
        process = subprocess.Popen(
            ['flutter', 'test', '--no-pub', '-d', 'macos',
             '--dart-define-from-file=' + str(defines), 'integration_test/enterprise/oa_webview_native_session_test.dart'],
            cwd=root, env=env, stdout=output, stderr=subprocess.STDOUT,
            start_new_session=True)
        try:
            result['exit'] = process.wait(timeout=1200)
        except subprocess.TimeoutExpired:
            import signal
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=20)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            result.update(exit=process.returncode, timed_out=True)


def save_result(root, run, log, sources, paths, result):
    entries = [r for r in Fixture.records if r['path'] in ['/b', '/c']]
    result['server_oracle'] = {r['path'] for r in entries} == {'/b', '/c'}
    result['server_oracle'] &= all(not (r['session_a'] or r['session_b']) for r in entries)
    result['server_oracle'] &= not any(r['path'] == '/forbidden' for r in Fixture.records)
    result['source_unchanged'] = sources == {
        p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in paths}
    result['log_sha256'] = hashlib.sha256(log.read_bytes()).hexdigest()
    if (result['exit'] == 0 and not result.get('timed_out') and
            result['server_oracle'] and result['source_unchanged'] and
            'All tests passed!' in log.read_text(errors='replace')):
        result['status'] = 'PASS_NATIVE_MACOS_WEBVIEW_SESSION'
    (run / 'terminal.json').write_text(json.dumps(result, indent=2))
    print(result['status'], 'Evidence:', run)
    raise SystemExit(0 if result['status'].startswith('PASS_') else 1)


def main():
    root = Path(__file__).resolve().parents[1]
    assert Path(subprocess.check_output(
        ['git', 'rev-parse', '--show-toplevel'], cwd=root, text=True).strip()) == root
    run = Path(tempfile.mkdtemp(prefix='gz-oa-macos-session-'))
    os.chmod(run, 0o700)
    bundle = 'pub.imboy.app.gzoatest.' + uuid.uuid4().hex
    paths = ['scripts/oa_webview_macos_session_gate.py',
             'scripts/oa_webview_native_session_gate.py',
             'integration_test/enterprise/oa_webview_native_session_test.dart',
             'lib/modules/enterprise_oa/presentation/oa_webview_container.dart',
             'lib/modules/enterprise_oa/domain/oa_webview_policy.dart',
             'lib/modules/enterprise_oa/domain/oa_tab_state.dart',
             'pubspec.lock']
    sources = {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in paths}
    Fixture.records = []
    Fixture.record_path = run / 'observations.json'
    cert, key = certificate(run)
    der = subprocess.check_output(['openssl', 'x509', '-in', str(cert), '-outform', 'DER'])
    cert_hash = hashlib.sha256(der).hexdigest()
    servers = [tls_server(cert, key), tls_server(cert, key)]
    try:
        config = run / 'isolation.xcconfig'
        config.write_text(f'PRODUCT_BUNDLE_IDENTIFIER = {bundle}\n'
                          'CODE_SIGN_IDENTITY = -\nCODE_SIGNING_ALLOWED = NO\n'
                          'CODE_SIGNING_REQUIRED = NO\nCODE_SIGN_STYLE = Manual\n'
                          'DEVELOPMENT_TEAM =\n')
        defines = run / 'defines.json'
        defines.write_text(json.dumps(dict(
            APP_ENV='local', IMBOY_JPUSH_ENABLED='false',
            OA_NATIVE_TEST_ORIGIN=f'https://127.0.0.1:{servers[0].server_port}',
            OA_NATIVE_FORBIDDEN_ORIGIN=f'https://127.0.0.1:{servers[1].server_port}',
            OA_NATIVE_TEST_BUNDLE=bundle, OA_NATIVE_TEST_CERT_SHA256=cert_hash)))
        os.chmod(defines, 0o600)
        env = dict(os.environ, XCODE_XCCONFIG_FILE=str(config))
        log = run / 'native.log'
        result = dict(status='FAIL_NATIVE_MACOS_WEBVIEW_SESSION', bundle=bundle,
                      source_sha256=sources, certificate_der_sha256=cert_hash,
                      system_trust_modified=False, production_trust_modified=False,
                      customer_oa_verified=False)
        run_native(root, defines, env, log, result)
        save_result(root, run, log, sources, paths, result)
    finally:
        for server in servers:
            server.shutdown()
            server.server_close()


if __name__ == '__main__':
    main()
