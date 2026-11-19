#!/usr/bin/env bash
# Use the runner's installed browser; validation failures remain dependency failures.
set -euo pipefail

if [ "${1:-}" = --browser-sqlite-probe ] && [ "$#" -eq 2 ]; then
  # The runner calls this only for the two real multi-document SQLite probes.
  # Build current source; never reuse the former manually supplied SRI values.
  python3 - "$2" <<'PY'
import base64
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path.cwd()
output = Path(sys.argv[1]).resolve()
output.mkdir(parents=True, exist_ok=True)
for name in ('defines.json', 'receipt.json'):
    (output / name).unlink(missing_ok=True)

inputs = (
    '.github/scripts/ci_prepare_chrome.sh',
    'lib/service/browser_sqlite_storage_bridge_web.dart',
    'lib/service/sqflite_init_web.dart',
    'pubspec.lock',
    '.dart_tool/package_config.json',
    'test/fixtures/browser_sqlite_bridge_probe.dart',
    'test/fixtures/browser_sqlite_bridge_probe.html',
    'test/fixtures/browser_sqlite_bridge_probe.htm',
    'test/fixtures/browser_sqlite_bridge_host.html',
    'test/fixtures/browser_sqlite_bridge_host.htm',
    'test/fixtures/startup_busy_counter.js',
    'test/fixtures/sqlite3.wasm',
    'web/sqlite3.wasm',
)

def sha256(data):
    return hashlib.sha256(data).hexdigest()

def sri(data):
    return 'sha256-' + base64.b64encode(hashlib.sha256(data).digest()).decode()

def sources():
    result = {}
    for name in inputs:
        path = root / name
        result[name] = {'sha256': sha256(path.read_bytes())}
        if path.is_symlink():
            result[name]['link_target'] = os.readlink(path)
    link = root / 'test/fixtures/browser_sqlite_bridge_probe.js'
    expected = '../../.dart_tool/browser_sqlite_bridge_probe.js'
    if not link.is_symlink() or os.readlink(link) != expected:
        raise ValueError('The declared probe JS output symlink is missing or changed')
    result['test/fixtures/browser_sqlite_bridge_probe.js'] = {'link_target': expected}
    return result

try:
    before = sources()
    dart = shutil.which('dart')
    if not dart:
        raise ValueError('dart compiler is missing')
    compiler_env = dict(os.environ, CI='true', FLUTTER_SUPPRESS_ANALYTICS='true')
    version = subprocess.run([dart, '--version'], cwd=root, env=compiler_env, text=True,
                             capture_output=True, check=True, timeout=15)
    compiler = {'executable': dart, 'version': (version.stdout + version.stderr).strip(),
                'sha256': sha256(Path(dart).read_bytes())}
    if not compiler['version']:
        raise ValueError('dart --version returned no version')
    served = root / '.dart_tool/browser_sqlite_bridge_probe.js'
    if served.is_symlink():
        raise ValueError('Generated probe output must be a regular file')
    with tempfile.TemporaryDirectory(prefix='browser-sqlite-', dir=root / '.dart_tool') as temporary:
        compiled = Path(temporary) / 'browser_sqlite_bridge_probe.js'
        command = [dart, 'compile', 'js', '--no-source-maps', '-O1',
                   '-o', str(compiled), 'test/fixtures/browser_sqlite_bridge_probe.dart']
        with (output / 'compile.log').open('wb') as log:
            completed = subprocess.run(command, cwd=root, env=compiler_env, stdout=log,
                                       stderr=subprocess.STDOUT, timeout=180)
        if completed.returncode != 0:
            raise ValueError(f'probe compilation failed (exit {completed.returncode}); see compile.log')
        compiled_bytes = compiled.read_bytes()
        if not compiled_bytes:
            raise ValueError('probe compiler produced empty JavaScript')
        if sources() != before:
            raise ValueError('probe sources changed during compilation')
        counter_bytes = (root / 'test/fixtures/startup_busy_counter.js').read_bytes()
        (output / 'browser_sqlite_bridge_probe.js').write_bytes(compiled_bytes)
        # Publish the exact attested bytes through the existing fixture symlink.
        os.replace(compiled, served)
        receipt = {
            'schema_version': 1, 'status': 'READY', 'exit_code': completed.returncode,
            'command': command, 'compiler': compiler, 'sources': before,
            'artifacts': {
                'browser_sqlite_bridge_probe.js': sha256(compiled_bytes),
                'compile.log': sha256((output / 'compile.log').read_bytes()),
            },
            'served_path': '.dart_tool/browser_sqlite_bridge_probe.js',
            'probe_sri': sri(compiled_bytes), 'counter_sri': sri(counter_bytes),
        }
        receipt_bytes = (json.dumps(receipt, indent=2, sort_keys=True) + '\n').encode()
        (output / 'receipt.json').write_bytes(receipt_bytes)
        defines = {
            'BROWSER_SQLITE_PROBE_SRI': receipt['probe_sri'],
            'BROWSER_SQLITE_PREPARATION_SHA256': sha256(receipt_bytes),
            'STARTUP_BUSY_COUNTER_SRI': receipt['counter_sri'],
        }
        (output / 'defines.json').write_text(json.dumps(defines, indent=2, sort_keys=True) + '\n')
    print('[ci_prepare_chrome] browser SQLite probe prepared: ' + str(output / 'receipt.json'))
except (OSError, ValueError, subprocess.SubprocessError) as error:
    print('[ci_prepare_chrome] BROWSER_SQLITE_PREPARATION_FAILED: ' + str(error), file=sys.stderr)
    sys.exit(2)
PY
  exit $?
fi

if [ "$#" -ne 0 ]; then
  echo '[ci_prepare_chrome] usage: ci_prepare_chrome.sh [--browser-sqlite-probe OUTPUT_DIR]' >&2
  exit 2
fi

if [ -z "${GITHUB_ENV:-}" ]; then
  echo '[ci_prepare_chrome] ENV_MISSING: GITHUB_ENV is required to publish Chrome' >&2
  exit 2
fi

chrome_executable="${CHROME_EXECUTABLE:-}"
if [ -z "$chrome_executable" ]; then
  chrome_executable="$(command -v google-chrome || command -v google-chrome-stable || true)"
fi
if [ -z "$chrome_executable" ] || [ ! -f "$chrome_executable" ] || [ ! -x "$chrome_executable" ]; then
  printf '[ci_prepare_chrome] ENV_MISSING: executable Chrome not found: %s\n' "${chrome_executable:-google-chrome or google-chrome-stable}" >&2
  exit 2
fi
case "$chrome_executable" in
  *$'\n'*|*$'\r'*) echo '[ci_prepare_chrome] ENV_MISSING: invalid Chrome path' >&2; exit 2 ;;
esac

if chrome_version="$("$chrome_executable" --version 2>&1)"; then
  if [ -z "$chrome_version" ]; then
    echo '[ci_prepare_chrome] ENV_MISSING: Chrome --version returned no version' >&2
    exit 2
  fi
else
  chrome_status=$?
  printf '[ci_prepare_chrome] ENV_MISSING: Chrome --version failed (exit %s)\n%s\n' "$chrome_status" "$chrome_version" >&2
  exit 2
fi

printf 'CHROME_EXECUTABLE=%s\n' "$chrome_executable" >> "$GITHUB_ENV"
printf '[ci_prepare_chrome] executable=%s\n%s\n' "$chrome_executable" "$chrome_version"
