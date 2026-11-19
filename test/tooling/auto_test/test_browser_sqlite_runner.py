"""Prepare browser probes and replay their complete per-attempt evidence."""
import contextlib
import copy
import hashlib
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

import test_browser_sqlite_fixture as fixture_support
import test_execution_runner as support
from auto_test_lib import browser_sqlite_fixture as fixture
from auto_test_lib import execution_catalog as catalog
from auto_test_lib import execution_cli as cli
from auto_test_lib import execution_runner as runner


ROOT = Path(__file__).resolve().parents[3]
TARGETS = frozenset({
    'test/unit_test/service/browser_sqlite_storage_bridge_chrome_test.dart',
    'test/service/web_writer_startup_busy_chrome_test.dart',
})
DEFINES = frozenset({'BROWSER_SQLITE_PROBE_SRI', 'BROWSER_SQLITE_PREPARATION_SHA256',
                     'STARTUP_BUSY_COUNTER_SRI'})
FILES = frozenset({'defines.json', 'receipt.json', 'compile.log', 'browser_sqlite_bridge_probe.js',
                   'process.json', 'prepare.log', 'execution-context.json'})


class BrowserSqliteRunnerTest(unittest.TestCase):
    def setUp(self):
        project = fixture_support.BrowserSqliteFixtureTest('runTest').project()
        self.root, _, self.env = self.enterContext(project)
        # Match the runner's artifact root when temporary paths use symlink aliases.
        self.root = self.root.resolve()
        self.env.update(CI='true', FLUTTER_SUPPRESS_ANALYTICS='true')
        self.output = self.root / 'evidence'
        self.helper = support.RunnerTest('runTest')
        self.helper.root, self.helper.output = self.root, self.output
        self.commands = []
        self.execute_process = runner.execute_process
        for name in TARGETS | {'test/b_test.dart'}:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('// synthetic browser probe test\n')
        # Keep process/context evidence real; only Flutter's machine events are
        # synthetic, using the existing runner fixture without launching Chrome.
        streams = {name: support.events(name, done=False) for name in TARGETS | {'test/b_test.dart'}}
        flutter = self.root / 'bin/flutter'
        flutter.write_text('#!' + sys.executable + '\nimport json, sys\nstreams = ' + repr(streams) +
            '\nfor target in sys.argv[1:]:\n'
            '    if target in streams: print("\\n".join(streams[target]))\n'
            'print(json.dumps({"type": "done", "success": True}))\n')
        flutter.chmod(0o755)

    def process(self, command, env, output, **kwargs):
        self.commands.append(list(command))
        return self.execute_process(command, env, output, **kwargs)

    def run_targets(self, *targets):
        declared = support.plan(*(support.instance(target, platform='web') for target in targets))
        with self.helper.mock_execution(self.process):
            report = runner.run_plan(self.root, declared, self.output, env=self.env)
        return declared, report

    def prepared_result(self):
        declared, report = self.run_targets(sorted(TARGETS)[0])
        self.assertEqual(report['status'], 'PASS', report)
        row = report['results'][0]
        verified = self.verify(row)
        self.assertEqual(verified['status'], 'PASS', verified)
        return declared, row

    def verify(self, row, directory=None):
        return cli.verify_result_files(row, {'artifact_root': str(self.output)},
                                       (directory or self.output) / 'results.json')

    def main_files(self, row):
        attempt = row['attempts'][0]
        process = json.loads(Path(attempt['process_receipt']).read_bytes())
        paths = {attempt[key] for key in ('log', 'evidence', 'process_receipt')} | {process['machine']}
        return {path: Path(path).read_bytes() for path in paths}

    def assert_binding_blocked(self, declared, row):
        self.assertEqual(runner._verdict(row['attempts'])['test_status'], 'BLOCKED')
        self.assertEqual(runner.reconcile(declared, [row])['status'], 'BLOCKED')
        verified = self.verify(row)
        self.assertEqual(verified['status'], 'BLOCKED', verified)
        self.assertEqual(runner.reconcile(declared, [verified])['status'], 'BLOCKED')

    def test_symlinked_temporary_project_uses_recorded_artifact_root(self):
        project = fixture_support.BrowserSqliteFixtureTest.project

        @contextlib.contextmanager
        def aliased_project(helper):
            with project(helper) as (root, _, env), tempfile.TemporaryDirectory() as directory:
                alias = Path(directory) / 'project'
                alias.symlink_to(root, target_is_directory=True)
                yield alias, alias / 'attempt', env

        nested = BrowserSqliteRunnerTest('runTest')
        self.addCleanup(nested.doCleanups)
        with patch.object(fixture_support.BrowserSqliteFixtureTest, 'project', aliased_project):
            nested.setUp()
        nested.prepared_result()
        payload = json.loads((nested.output / 'results.json').read_bytes())
        self.assertEqual(payload['artifact_root'], str(nested.output))

    def test_each_probe_prepares_its_own_batch_and_binds_evidence(self):
        _, report = self.run_targets(*sorted(TARGETS | {'test/b_test.dart'}))
        self.assertEqual(report['status'], 'PASS', report)
        prepares = [command for command in self.commands if '--browser-sqlite-probe' in command]
        self.assertEqual(len(prepares), 2)
        self.assertEqual(len({command[-1] for command in prepares}), 2)
        self.assertEqual(len(self.commands), 5)
        for row in report['results']:
            attempt = row['attempts'][0]
            meta = attempt.get('browser_sqlite_preparation')
            if row['target'] not in TARGETS:
                self.assertIsNone(meta)
                self.assertFalse(any(arg.startswith('--dart-define=' + name + '=')
                    for arg in attempt['command'] for name in DEFINES))
                continue
            self.assertEqual(set(meta['files']), FILES)
            self.assertEqual(set(meta['defines']), DEFINES)
            self.assertIs(meta['served_unchanged'], True)
            for name, value in meta['defines'].items():
                self.assertEqual(attempt['command'].count('--dart-define=' + name + '=' + value), 1)
                self.assertNotIn('<redacted>', value)
            for evidence in meta['files'].values():
                self.assertEqual(attempt['related_evidence'].count(evidence), 1)
                self.assertEqual(evidence['sha256'], hashlib.sha256(Path(evidence['path']).read_bytes()).hexdigest())
            process = json.loads(Path(attempt['process_receipt']).read_bytes())
            self.assertEqual(process['browser_sqlite_preparation'], meta)
            verified = self.verify(row)
            self.assertEqual(verified['status'], 'PASS', verified)

    def test_preparation_failure_blocks_before_flutter(self):
        self.env['SQLITE_COMPILER_FIXTURE'] = 'failure'
        _, report = self.run_targets(sorted(TARGETS)[0])
        self.assertEqual(len(self.commands), 1)
        self.assertIn('--browser-sqlite-probe', self.commands[0])
        self.assertEqual(report['results'][0]['status'], 'BLOCKED')
        self.assertEqual(report['results'][0]['reason_code'], 'BROWSER_SQLITE_PREPARATION_FAILED')

    def test_changed_served_bytes_veto_successful_flutter_events(self):
        execute = self.execute_process

        def change_after_flutter(command, env, output, **kwargs):
            receipt = execute(command, env, output, **kwargs)
            if command[0] == 'flutter':
                (self.root / fixture.SERVED).write_bytes(b'changed while Flutter ran')
            return receipt

        self.execute_process = change_after_flutter
        declared, report = self.run_targets(sorted(TARGETS)[0])
        row = report['results'][0]
        self.assertEqual(row['attempts'][0]['parsed']['test_status'], 'PASS')
        self.assertNotEqual(row['status'], 'PASS')
        self.assertEqual(row['reason_code'], 'BROWSER_SQLITE_PREPARED_BYTES_CHANGED')
        row['attempts'][0]['execution_errors'] = []
        row.update(status='PASS', reason_code='NONE')
        summary = runner.reconcile(declared, [row])
        self.assertEqual(summary['status'], 'BLOCKED', summary)
        self.assertEqual(summary['results'][0]['reason_code'], 'BROWSER_SQLITE_PREPARED_BYTES_CHANGED')

    def test_removing_all_or_preparation_related_evidence_cannot_pass(self):
        declared, original = self.prepared_result()
        unchanged = self.main_files(original)
        for change in ('all', 'preparation', *sorted(FILES)):
            with self.subTest(change=change):
                row = copy.deepcopy(original)
                attempt = row['attempts'][0]
                files = attempt['browser_sqlite_preparation']['files']
                removed = list(files.values()) if change == 'preparation' else [files.get(change)]
                attempt['related_evidence'] = ([] if change == 'all' else
                    [item for item in attempt['related_evidence'] if item not in removed])
                self.assert_binding_blocked(declared, row)
                self.assertEqual(self.main_files(row), unchanged)

    def test_missing_preparation_metadata_or_any_required_file_cannot_pass(self):
        declared, original = self.prepared_result()
        unchanged = self.main_files(original)
        fields = tuple(original['attempts'][0]['browser_sqlite_preparation'])
        for missing in ('binding', *fields, *sorted(FILES)):
            with self.subTest(missing=missing):
                row = copy.deepcopy(original)
                attempt = row['attempts'][0]
                if missing == 'binding':
                    del attempt['browser_sqlite_preparation']
                elif missing in fields:
                    del attempt['browser_sqlite_preparation'][missing]
                else:
                    del attempt['browser_sqlite_preparation']['files'][missing]
                self.assert_binding_blocked(declared, row)
                self.assertEqual(self.main_files(row), unchanged)

    def test_hash_defines_must_be_present_unchanged_and_unique(self):
        declared, original = self.prepared_result()
        for name in sorted(DEFINES):
            for change in ('missing', 'redacted', 'duplicate'):
                with self.subTest(name=name, change=change):
                    row = copy.deepcopy(original)
                    command = row['attempts'][0]['command']
                    prefix = '--dart-define=' + name + '='
                    value = next(arg for arg in command if arg.startswith(prefix))
                    if change == 'duplicate':
                        command.append(value)
                    else:
                        command.remove(value)
                        if change == 'redacted':
                            command.append(prefix + '<redacted>')
                    self.assert_binding_blocked(declared, row)

    def test_each_preparation_file_is_replayed_from_actual_bytes(self):
        declared, row = self.prepared_result()
        unchanged = self.main_files(row)
        for name, evidence in row['attempts'][0]['browser_sqlite_preparation']['files'].items():
            for change in ('missing', 'tampered'):
                with self.subTest(name=name, change=change):
                    path = Path(evidence['path'])
                    data = path.read_bytes()
                    try:
                        if change == 'missing':
                            path.unlink()
                        else:
                            path.write_bytes(data + b'\nchanged preparation artifact\n')
                        verified = self.verify(row)
                        self.assertEqual(verified['status'], 'BLOCKED', verified)
                        self.assertEqual(runner.reconcile(declared, [verified])['status'], 'BLOCKED')
                        self.assertEqual(self.main_files(row), unchanged)
                    finally:
                        path.write_bytes(data)

    def test_process_and_attempt_preparation_metadata_must_match(self):
        declared, original = self.prepared_result()
        path = Path(original['attempts'][0]['process_receipt'])
        data = path.read_bytes()
        for change in ('missing', 'different'):
            with self.subTest(change=change):
                row = copy.deepcopy(original)
                process = json.loads(data)
                if change == 'missing':
                    del process['browser_sqlite_preparation']
                else:
                    process['browser_sqlite_preparation']['served_unchanged'] = False
                path.write_text(json.dumps(process))
                row['attempts'][0]['process_receipt_sha256'] = runner._file_sha256(path)
                verified = self.verify(row)
                self.assertEqual(verified['status'], 'BLOCKED', verified)
                self.assertEqual(runner.reconcile(declared, [verified])['status'], 'BLOCKED')

    def test_rebound_file_hashes_cannot_hide_invalid_preparation_content(self):
        declared, original = self.prepared_result()
        main_path = Path(original['attempts'][0]['process_receipt'])
        main_data = main_path.read_bytes()
        for name, expected in (
                ('defines.json', 'BROWSER_SQLITE_DEFINES_OR_SRI_MISMATCH'),
                ('process.json', 'BROWSER_SQLITE_PREPARATION_PROCESS_FAILED'),
                ('execution-context.json', 'BROWSER_SQLITE_EXECUTION_CONTEXT_MISMATCH')):
            with self.subTest(name=name):
                row = copy.deepcopy(original)
                attempt = row['attempts'][0]
                meta = attempt['browser_sqlite_preparation']
                path = Path(meta['files'][name]['path'])
                data = path.read_bytes()
                value = json.loads(data)
                if name == 'defines.json':
                    value['STARTUP_BUSY_COUNTER_SRI'] = 'sha256-' + 'A' * 43 + '='
                elif name == 'process.json':
                    value['exit_code'] = 19
                else:
                    value['euid'] += 1
                try:
                    path.write_text(json.dumps(value))
                    digest = runner._file_sha256(path)
                    meta['files'][name]['sha256'] = digest
                    for item in attempt['related_evidence']:
                        if item['path'] == str(path):
                            item['sha256'] = digest
                    process = json.loads(main_data)
                    process['browser_sqlite_preparation'] = meta
                    main_path.write_text(json.dumps(process))
                    attempt['process_receipt_sha256'] = runner._file_sha256(main_path)
                    self.assertEqual(runner._verdict(row['attempts'])['test_status'], 'PASS')
                    verified = self.verify(row)
                    self.assertEqual(verified['status'], 'BLOCKED', verified)
                    self.assertIn(expected, verified['evidence_error'])
                    self.assertEqual(runner.reconcile(declared, [verified])['status'], 'BLOCKED')
                finally:
                    path.write_bytes(data)
                    main_path.write_bytes(main_data)

    def test_downloaded_evidence_replays_after_original_project_is_deleted(self):
        declared, row = self.prepared_result()
        with tempfile.TemporaryDirectory() as directory:
            downloaded = Path(directory) / 'downloaded'
            shutil.copytree(self.output, downloaded)
            shutil.rmtree(self.root)
            with patch.object(runner, '_capture_execution_context',
                              side_effect=AssertionError('replay must not resample worker context')):
                verified = self.verify(row, downloaded)
                self.assertEqual(verified['status'], 'PASS', verified)
                summary = runner.reconcile(declared, [verified])
                self.assertEqual(summary['status'], 'PASS', summary)

    def test_only_declared_web_probes_can_compile(self):
        config = catalog.load_contract(ROOT)
        self.assertEqual(runner.BROWSER_SQLITE_TARGETS, TARGETS)
        for target in TARGETS:
            override = config['overrides'][target]
            self.assertEqual(override['platforms'], ['web'])
            self.assertTrue(override['offline'])
            self.assertFalse(DEFINES & set(override.get('dart_defines', {})))
            self.assertIn('.github/scripts/ci_prepare_chrome.sh', override['source_dependencies'])
            with self.subTest(target=target), self.helper.mock_execution(self.helper.process), \
                    patch.object(runner, 'prepare_browser_sqlite') as prepare, \
                    patch.object(runner, 'execute_process') as process:
                report = runner.run_plan(self.helper.root, support.plan(support.instance(target)),
                                         self.helper.output)
            prepare.assert_not_called()
            process.assert_not_called()
            self.assertEqual(report['results'][0]['reason_code'], 'BROWSER_SQLITE_PREPARATION_SCOPE_INVALID')


if __name__ == '__main__':
    unittest.main()
