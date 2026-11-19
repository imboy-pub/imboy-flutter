"""W09 runner isolation and lifecycle tests; no browser or shared service."""
import base64
import hashlib
import json
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
from auto_test_lib import execution_cli as cli

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
        helper = support.RunnerTest('runTest')
        helper.setUp()
        self.addCleanup(helper.doCleanups)
        spec = support.instance()
        declared = support.plan(spec)
        lines = support.events(spec['target'])
        lines.insert(1, json.dumps({'type': 'print', 'message': nonce + ' ' + encoded}))
        source = 'print(' + repr('\n'.join(lines)) + ')'
        captured = []
        original_capture = runner._capture_execution_context

        def capture(output):
            context = original_capture(output)
            captured.append((json.loads(json.dumps(context)), Path(context['path']).read_bytes()))
            return context

        with patch.object(runner, '_capture_execution_context', side_effect=capture):
            receipt = execute_process([sys.executable, '-c', source], dict(os.environ), helper.output,
                                      redactions=[nonce])
        self.assertEqual(receipt['exit_code'], 0)
        self.assertEqual(len(captured), 1, 'relocating context must not measure the post-run process again')
        original_meta, original_bytes = captured[0]
        self.assertFalse(Path(original_meta['path']).parent.exists(), 'private scratch directory must be gone')
        context = receipt['execution_context']
        context_path = Path(context['path'])
        self.assertEqual(context_path.parent, helper.output)
        self.assertNotEqual(context['path'], original_meta['path'])
        self.assertEqual(context['sha256'], original_meta['sha256'])
        self.assertEqual(context['value'], original_meta['value'])
        self.assertEqual(context_path.read_bytes(), original_bytes)
        self.assertEqual(hashlib.sha256(original_bytes).hexdigest(), context['sha256'])
        saved_process = json.loads(Path(receipt['process_receipt']).read_text())
        self.assertEqual(saved_process['execution_context'], context)

        attempt = runner._record_attempt(helper.root, declared, spec, receipt, receipt['lines'])
        self.assertEqual(attempt['execution_context'], context)
        self.assertEqual(attempt['execution_errors'], [])
        row = runner._finish(declared, spec, [attempt])
        self.assertEqual(row['status'], 'PASS', row)
        payload = {'artifact_root': str(helper.output)}
        candidate = helper.output / 'results.json'
        verified = cli.verify_result_files(row, payload, candidate)
        self.assertEqual(verified['status'], 'PASS', verified)
        self.assertEqual(runner.reconcile(declared, [verified])['status'], 'PASS')
        for path in helper.output.rglob('*'):
            if path.is_file():
                self.assertNotIn(nonce, path.read_text())
                self.assertNotIn(encoded, path.read_text())

        # Even a semantically equivalent edit must fail the original startup
        # digest; relocation does not relax evidence verification.
        context_path.write_bytes(original_bytes + b'\n')
        invalid = cli.verify_result_files(row, payload, candidate)
        self.assertEqual(invalid['status'], 'BLOCKED')
        self.assertEqual(invalid['reason_code'], 'ARTIFACT_EVIDENCE_MISSING_OR_INVALID')
        self.assertIn('startup execution context digest mismatch', invalid['evidence_error'])
        self.assertEqual(runner.reconcile(declared, [invalid])['status'], 'BLOCKED')

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
                inputs = ('scripts/auto_test_lib/execution_runner.py',
                          'scripts/auto_test_lib/owned_node_fixture.py',
                          'scripts/auto_test_lib/w09_fixture.py',
                          'test/fixtures/w09_cancel/slow-put.cjs')
                for name in inputs:
                    path = root / name; path.parent.mkdir(parents=True, exist_ok=True); path.write_text('v1')
                with patch.object(catalog, 'validate_catalog', return_value=fake_catalog), \
                     patch.object(catalog.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, stdout=b'')):
                    one = catalog.build_plan(root, contract=cfg, targets=[selected_target])
                    other_before = catalog.build_plan(root, contract=cfg, targets=['test/other.dart'])
                    for name in inputs:
                        with self.subTest(target=selected_target, input=name):
                            (root / name).write_text('v2')
                            two = catalog.build_plan(root, contract=cfg, targets=[selected_target])
                            other_after = catalog.build_plan(root, contract=cfg, targets=['test/other.dart'])
                            for planned in (one, two, other_before, other_after):
                                selected = [row for row in planned['instances'] if row['selected']]
                                self.assertEqual(len(selected), 1)
                                self.assertEqual(selected[0]['dependencies'], ['chrome'])
                            self.assertNotEqual(one['source_fingerprint'], two['source_fingerprint'])
                            self.assertEqual(other_before['source_fingerprint'], other_after['source_fingerprint'])
                            (root / name).write_text('v1')

    def test_preflight_only_w09_requires_node(self):
        with tempfile.TemporaryDirectory() as directory, patch('shutil.which', return_value=None):
            for selected_target in sorted(runner.W09_TARGETS):
                target = {'target': selected_target, 'platform': 'web', 'runner': 'flutter-machine'}
                self.assertTrue(any('w09-fixture' in e for e in _default_preflight(Path(directory), target, {})))
            target['target'] = 'test/another.dart'
            self.assertFalse(any('w09-fixture' in e for e in _default_preflight(Path(directory), target, {})))


if __name__ == '__main__':
    unittest.main()
