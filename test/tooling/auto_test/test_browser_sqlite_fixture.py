"""Preparation adapter evidence checks with the existing controlled compiler."""
import contextlib
import hashlib
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))
import test_execution_entrypoints as support
from auto_test_lib import browser_sqlite_fixture as fixture
from auto_test_lib import execution_runner as runner


class BrowserSqliteFixtureTest(unittest.TestCase):
    @contextlib.contextmanager
    def project(self):
        helper = support.EntrypointTest('runTest')
        with helper.browser_sqlite_preparation() as (root, _, _, env):
            for name in fixture.SOURCE_INPUTS:
                if name.startswith('scripts/auto_test_lib/'):
                    path = root / name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text('controlled runtime source: ' + name)
            yield root, root / 'attempt', env

    def test_success_binds_real_files_and_original_process_context(self):
        with self.project() as (root, output, env), patch.object(
                runner, '_capture_execution_context', wraps=runner._capture_execution_context) as capture:
            prepared = fixture.prepare(root, env, output, runner.execute_process)
            self.assertEqual(capture.call_count, 1)
            self.assertTrue(fixture.served_unchanged(root, prepared))
            self.assertEqual(len(prepared['evidence']), 7)
            evidence = {Path(row['path']).name: row for row in prepared['evidence']}
            self.assertEqual(set(evidence), {'defines.json', 'receipt.json', 'compile.log',
                'browser_sqlite_bridge_probe.js', 'process.json', 'prepare.log', 'execution-context.json'})
            for row in evidence.values():
                self.assertEqual(row['sha256'], hashlib.sha256(Path(row['path']).read_bytes()).hexdigest())
            self.assertEqual(prepared['defines']['BROWSER_SQLITE_PREPARATION_SHA256'],
                             evidence['receipt.json']['sha256'])
            self.assertEqual(prepared['served_sha256'], evidence['browser_sqlite_bridge_probe.js']['sha256'])

    def test_failed_compiler_cannot_reuse_preparation(self):
        with self.project() as (root, output, env):
            env['SQLITE_COMPILER_FIXTURE'] = 'failure'
            with self.assertRaisesRegex(fixture.PreparationFailure, 'PROCESS_FAILED:2'):
                fixture.prepare(root, env, output, runner.execute_process)

    def test_rebound_receipt_cannot_substitute_compiler_or_command(self):
        for change in ('compiler', 'command', 'sources'):
            with self.subTest(change=change), self.project() as (root, output, env):
                def execute(command, environment, directory, **kwargs):
                    process = runner.execute_process(command, environment, directory, **kwargs)
                    path = directory / 'receipt.json'
                    receipt = json.loads(path.read_bytes())
                    if change == 'compiler':
                        receipt['compiler']['sha256'] = '0' * 64
                    elif change == 'command':
                        receipt['command'][-1] = 'test/fixtures/another_probe.dart'
                    else:
                        receipt['sources']['.dart_tool/package_config.json']['sha256'] = '0' * 64
                    path.write_text(json.dumps(receipt))
                    defines_path = directory / 'defines.json'
                    defines = json.loads(defines_path.read_bytes())
                    defines['BROWSER_SQLITE_PREPARATION_SHA256'] = hashlib.sha256(path.read_bytes()).hexdigest()
                    defines_path.write_text(json.dumps(defines))
                    return process
                with self.assertRaises(fixture.PreparationFailure):
                    fixture.prepare(root, env, output, execute)

    def test_tampered_defines_and_served_bytes_are_rejected(self):
        for change in ('defines', 'served', 'context'):
            with self.subTest(change=change), self.project() as (root, output, env):
                def execute(command, environment, directory, **kwargs):
                    process = runner.execute_process(command, environment, directory, **kwargs)
                    if change == 'defines':
                        path = directory / 'defines.json'
                        defines = json.loads(path.read_bytes())
                        defines['STARTUP_BUSY_COUNTER_SRI'] = 'sha256-unattested'
                        path.write_text(json.dumps(defines))
                    elif change == 'served':
                        (root / fixture.SERVED).write_bytes(b'replaced served probe')
                    else:
                        (directory / 'execution-context.json').write_text('{}')
                    return process
                with self.assertRaises(fixture.PreparationFailure):
                    fixture.prepare(root, env, output, execute)

    def test_served_probe_change_after_preparation_fails(self):
        with self.project() as (root, output, env):
            prepared = fixture.prepare(root, env, output, runner.execute_process)
            (root / fixture.SERVED).write_bytes(b'changed after preparation')
            self.assertFalse(fixture.served_unchanged(root, prepared))

    def test_plan_fingerprints_hash_symlink_text_and_exclude_pubget_output(self):
        with self.project() as (root, _, _):
            (root / '.dart_tool/package_config.json').unlink()
            before = fixture.source_fingerprints(root)
            self.assertNotIn('.dart_tool/package_config.json', before)
            link = root / fixture.PROBE_LINK
            self.assertEqual(before[fixture.PROBE_LINK]['sha256'],
                             hashlib.sha256(b'../../.dart_tool/browser_sqlite_bridge_probe.js').hexdigest())
            (root / fixture.SERVED).write_bytes(b'generated first')
            self.assertEqual(before, fixture.source_fingerprints(root))
            (root / fixture.SERVED).write_bytes(b'generated again')
            (root / '.dart_tool/package_config.json').write_text('new pub get output')
            self.assertEqual(before, fixture.source_fingerprints(root))
            link.unlink()
            link.symlink_to('../../.dart_tool/other.js')
            self.assertNotEqual(before, fixture.source_fingerprints(root))


if __name__ == '__main__':
    unittest.main()
