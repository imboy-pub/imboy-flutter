"""System SQLite setup uses installed packages and preserves dependency failures."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[2] / '.github/scripts/ci_ensure_system_sqlite.sh'
PACKAGE_TOOL = r'''
import json
import os
from pathlib import Path
import sys

state = Path(os.environ['FIXTURE_STATE'])
args = sys.argv[1:]
if Path(sys.argv[0]).name == 'dpkg-query':
    if not state.exists():
        sys.exit(1)
    print('install ok installed' if '${Status}' in args[1] else 'libsqlite3-dev 3.45.1-fixture')
else:
    with open(os.environ['FIXTURE_APT_CALLS'], 'a') as output:
        output.write(json.dumps(args) + '\n')
    if args[:3] != ['env', 'DEBIAN_FRONTEND=noninteractive', 'apt-get']:
        sys.exit('unexpected privileged command')
    operation = 'install' if 'install' in args else 'update'
    if os.environ.get('FIXTURE_APT_FAIL') == operation:
        print('fixture apt failure: ' + operation, file=sys.stderr)
        sys.exit(100)
    if operation == 'install':
        state.write_text('installed')
'''
SQLITE_LOADER = r'''
import os
from pathlib import Path
from types import SimpleNamespace

c_char_p = object()

def CDLL(name):
    Path(os.environ['FIXTURE_LIBRARY_CALL']).write_text(name)
    if name != 'libsqlite3.so' or os.environ.get('FIXTURE_LIBRARY_MISSING') == '1':
        raise OSError('fixture system SQLite library is unavailable')
    def version():
        return b'3.45.1-fixture'
    return SimpleNamespace(sqlite3_libversion=version)
'''


class SystemSqliteSetupTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.bin_dir = self.root / 'bin'
        self.bin_dir.mkdir()
        for name in ('dpkg-query', 'sudo'):
            tool = self.bin_dir / name
            tool.write_text(f'#!{sys.executable}\n' + PACKAGE_TOOL)
            tool.chmod(0o755)
        self.modules = self.root / 'modules'
        self.modules.mkdir()
        (self.modules / 'ctypes.py').write_text(SQLITE_LOADER)
        self.state = self.root / 'installed'
        self.apt_calls = self.root / 'apt-calls.jsonl'
        self.library_call = self.root / 'library-call.txt'

    def run_setup(self, *, installed, apt_fail='', library_missing=False):
        for path in (self.state, self.apt_calls, self.library_call):
            if path.exists():
                path.unlink()
        if installed:
            self.state.write_text('installed')
        env = dict(os.environ, PATH=f'{self.bin_dir}:{os.environ["PATH"]}',
                   PYTHONPATH=str(self.modules), FIXTURE_STATE=str(self.state),
                   FIXTURE_APT_CALLS=str(self.apt_calls), FIXTURE_APT_FAIL=apt_fail,
                   FIXTURE_LIBRARY_CALL=str(self.library_call),
                   FIXTURE_LIBRARY_MISSING='1' if library_missing else '0')
        result = subprocess.run(['bash', str(SCRIPT)], cwd=self.root, env=env,
                                capture_output=True, text=True, timeout=10)
        calls = ([json.loads(line) for line in self.apt_calls.read_text().splitlines()]
                 if self.apt_calls.exists() else [])
        return result, calls

    def test_installed_package_loads_library_without_network_or_privilege(self):
        result, calls = self.run_setup(installed=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [])
        self.assertEqual(self.library_call.read_text(), 'libsqlite3.so')
        self.assertIn('libsqlite3-dev 3.45.1-fixture', result.stdout)
        self.assertIn('Loaded libsqlite3.so: SQLite 3.45.1-fixture', result.stdout)

    def test_missing_package_is_installed_with_bounded_apt_then_loaded(self):
        result, calls = self.run_setup(installed=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(calls), 2)
        self.assertIn('update', calls[0])
        self.assertIn('install', calls[1])
        self.assertEqual(calls[1][-1], 'libsqlite3-dev')
        for call in calls:
            for option in ('Acquire::Retries=2', 'Acquire::http::Timeout=30',
                           'Acquire::https::Timeout=30', 'DPkg::Lock::Timeout=60'):
                self.assertIn(option, call)
        self.assertEqual(self.library_call.read_text(), 'libsqlite3.so')

    def test_apt_update_or_install_failure_stays_failed(self):
        for operation, expected_calls in (('update', 1), ('install', 2)):
            with self.subTest(operation=operation):
                result, calls = self.run_setup(installed=False, apt_fail=operation)
                self.assertEqual(result.returncode, 100)
                self.assertEqual(len(calls), expected_calls)
                self.assertFalse(self.library_call.exists())

    def test_installed_package_with_missing_library_stays_failed(self):
        result, calls = self.run_setup(installed=True, library_missing=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, [])
        self.assertIn('system SQLite library is unavailable', result.stderr)


if __name__ == '__main__':
    unittest.main()
