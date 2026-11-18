"""W09 runner isolation and lifecycle tests; no browser or shared service."""
import base64
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import test_execution_runner as support
from auto_test_lib import execution_runner as runner
from auto_test_lib import execution_catalog as catalog

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))
from auto_test_lib.w09_fixture import W09Fixture, FixtureFailure
from auto_test_lib.execution_runner import execute_process, _default_preflight


class OwnedFixtureTest(unittest.TestCase):
    def test_real_fixture_handshake_and_cleanup(self):
        fixture = W09Fixture(ROOT, dict(os.environ)).start()
        self.assertIsNone(fixture.observer(None))
        self.assertTrue(fixture.stop())
        self.assertIsNotNone(fixture.observer(None))
        self.assertTrue(fixture.stop())

    def test_wrong_handshake_reaps_child(self):
        fixture = W09Fixture(ROOT, dict(os.environ))
        with patch('http.client.HTTPConnection.request', side_effect=OSError('private')):
            with self.assertRaises(FixtureFailure):
                fixture.start()
        self.assertIsNotNone(fixture.process.poll())

    def test_start_error_does_not_leak_detail(self):
        fixture = W09Fixture(ROOT, dict(os.environ))
        with patch('subprocess.Popen', side_effect=OSError('private details')):
            with self.assertRaises(FixtureFailure) as error:
                fixture.start()
        self.assertNotIn('private details', str(error.exception))

    def test_process_artifacts_remove_nonce_and_encoded_define(self):
        nonce = 'a' * 64
        encoded = base64.b64encode(('W09_CANCEL_NONCE=' + nonce).encode()).decode()
        source = f'print({nonce!r}); print({encoded!r})'
        with tempfile.TemporaryDirectory() as directory:
            receipt = execute_process([sys.executable, '-c', source], dict(os.environ), directory,
                                      redactions=[nonce])
            self.assertEqual(receipt['exit_code'], 0)
            for path in Path(directory).rglob('*'):
                if path.is_file():
                    self.assertNotIn(nonce, path.read_text())
                    self.assertNotIn(encoded, path.read_text())

    def test_isolated_batch_and_cleanup_failure_cannot_pass(self):
        for selected_target in sorted(runner.W09_TARGETS):
            helper = support.RunnerTest('runTest')
            helper.setUp()
            self.addCleanup(helper.doCleanups)
            target = selected_target
            (helper.root / target).parent.mkdir(parents=True, exist_ok=True)
            (helper.root / target).write_text('// fixture')
            a = support.instance(target, platform='web')
            b = support.instance('test/b_test.dart', platform='web')
            calls = []
            class Fixture:
                origin = 'http://127.0.0.1:10000'
                nonce = 'b' * 64
                def __init__(self, *_): pass
                def start(self): return self
                def stop(self): return False
                def observer(self, _): return None
            def process(command, env, output, **kwargs):
                calls.append(list(command))
                return helper.process(runner._display_command(command), env, output, **kwargs)
            with helper.mock_execution(process), patch.object(runner, 'W09Fixture', Fixture):
                result = runner.run_plan(helper.root, support.plan(a, b), helper.output)
            self.assertEqual(len(calls), 2)
            special = next(c for c in calls if target in c)
            other = next(c for c in calls if 'test/b_test.dart' in c)
            self.assertTrue(any('W09_CANCEL_NONCE=' in v for v in special))
            self.assertFalse(any('W09_CANCEL_NONCE=' in v for v in other))
            row = next(r for r in result['results'] if r['target'] == target)
            self.assertNotEqual(row['status'], 'PASS')
            self.assertEqual(row['reason_code'], 'W09_FIXTURE_CLEANUP_OR_EXIT_FAILED')

    def test_interruption_reaps_real_child(self):
        with tempfile.TemporaryDirectory() as directory:
            pid_file = Path(directory) / 'pid'
            source = (f'import os,time,pathlib; pathlib.Path({str(pid_file)!r}).write_text(str(os.getpid())); '
                      'time.sleep(30)')
            def observer(_):
                if pid_file.exists():
                    raise KeyboardInterrupt()
                return None
            with self.assertRaises(KeyboardInterrupt):
                execute_process([sys.executable, '-c', source], dict(os.environ),
                                Path(directory) / 'output', timeout=5, observer=observer)
            pid = int(pid_file.read_text())
            with self.assertRaises(ProcessLookupError):
                os.kill(pid, 0)

    def test_untracked_fixture_change_invalidates_only_selected_w09_plan(self):
        for selected_target in sorted(runner.W09_TARGETS):
            cfg = {'profiles': {'pr': {'platforms': ['web'], 'products': ['p'], 'suites': ['unit']}},
                   'platforms': ['web'], 'products': {'p': {}}, 'suites': {'unit': {}}}
            target = {'target': selected_target, 'suite': 'unit', 'runner': 'flutter-machine', 'platforms': ['web'], 'products': ['p'], 'dependencies': []}
            other = {'target': 'test/other.dart', 'suite': 'unit', 'runner': 'flutter-machine', 'platforms': ['web'], 'products': ['p'], 'dependencies': []}
            fake_catalog = {'targets': [target, other], 'entries': [], 'commit': 'x', 'counts': {}}
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                for name in ('scripts/auto_test_lib/execution_runner.py', 'scripts/auto_test_lib/w09_fixture.py',
                             'test/fixtures/w09_cancel/slow-put.cjs'):
                    path = root / name; path.parent.mkdir(parents=True, exist_ok=True); path.write_text('v1')
                with patch.object(catalog, 'validate_catalog', return_value=fake_catalog), \
                     patch.object(catalog.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, stdout=b'')):
                    one = catalog.build_plan(root, contract=cfg, targets=[selected_target])
                    other_before = catalog.build_plan(root, contract=cfg, targets=['test/other.dart'])
                    (root / 'test/fixtures/w09_cancel/slow-put.cjs').write_text('v2')
                    two = catalog.build_plan(root, contract=cfg, targets=[selected_target])
                    other_after = catalog.build_plan(root, contract=cfg, targets=['test/other.dart'])
                for planned in (one, two, other_before, other_after):
                    selected = [row for row in planned['instances'] if row['selected']]
                    self.assertEqual(len(selected), 1)
                    self.assertEqual(selected[0]['dependencies'], ['chrome'])
                self.assertNotEqual(one['source_fingerprint'], two['source_fingerprint'])
                self.assertEqual(other_before['source_fingerprint'], other_after['source_fingerprint'])

    def test_preflight_only_w09_requires_node(self):
        with tempfile.TemporaryDirectory() as directory, patch('shutil.which', return_value=None):
            for selected_target in sorted(runner.W09_TARGETS):
                target = {'target': selected_target, 'platform': 'web', 'runner': 'flutter-machine'}
                self.assertTrue(any('w09-fixture' in e for e in _default_preflight(Path(directory), target, {})))
            target['target'] = 'test/another.dart'
            self.assertFalse(any('w09-fixture' in e for e in _default_preflight(Path(directory), target, {})))


if __name__ == '__main__':
    unittest.main()
