"""Entrypoint and evidence regressions; no SDK, credentials or network."""
from __future__ import annotations

import importlib.util
import copy
import json
import os
import subprocess
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))
from auto_test_lib import execution_cli, execution_gates


class EntrypointTest(unittest.TestCase):
    def test_quick_and_full_delegation_preserve_the_selection_arguments(self):
        with tempfile.TemporaryDirectory() as directory:
            binary = Path(directory) / 'python3'
            binary.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
            binary.chmod(0o755)
            env = {**os.environ, 'PATH': directory + os.pathsep + os.environ['PATH']}
            for mode, profile in [('quick', 'pr'), ('full', 'full')]:
                result = subprocess.run(
                    ['bash', str(ROOT / 'scripts/run_test_suite.sh'), '--mode', mode,
                     '--dry-run', '--platform', 'macos', '--product-profile', 'phase1_delivery'],
                    cwd=ROOT, env=env, text=True, capture_output=True, check=False)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.splitlines(), [
                    'scripts/auto_test.py', 'execution-plan', '--profile', profile,
                    '--platform', 'macos', '--product-profile', 'phase1_delivery'])

    def test_legacy_integration_entry_retains_full_scope(self):
        with tempfile.TemporaryDirectory() as directory:
            binary = Path(directory) / 'python3'
            binary.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
            binary.chmod(0o755)
            result = subprocess.run(
                ['bash', str(ROOT / 'scripts/run_all_integration_tests.sh'), '--dry-run'],
                cwd=ROOT, env={**os.environ, 'PATH': directory + os.pathsep + os.environ['PATH']},
                text=True, capture_output=True, check=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('execution-plan\n--profile\nfull', result.stdout)

    def test_legacy_page_run_delegates_to_shared_plan_without_device_io(self):
        spec = importlib.util.spec_from_file_location('execution_legacy_cli', ROOT / 'scripts/auto_test.py')
        cli = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cli)
        selected = [(Path('spec.json'), {'runner': {'target': 'integration_test/app_test.dart'},
                                         'safe_to_execute': True})]
        for execute, device, devices, expected in (
            (False, '', [], 0),
            (True, 'ios-fixture', [{'id': 'ios-fixture', 'targetPlatform': 'ios', 'emulator': False}], 0),
            (True, 'missing', [], 2),
        ):
            with self.subTest(execute=execute, device=device):
                argv = ['auto_test.py', 'run', '--execute' if execute else '--dry-run', '--device', device]
                with mock.patch.object(sys, 'argv', argv), \
                        mock.patch.object(cli, 'load_specs', return_value=selected), \
                        mock.patch.object(cli, 'validate', return_value=[]), \
                        mock.patch.object(cli, 'select', return_value=selected), \
                        mock.patch.object(cli, 'discover_devices', return_value=(devices, None)) as discover, \
                        mock.patch.object(execution_cli, 'run_cli', return_value=0) as run, \
                        mock.patch.dict(os.environ, {'IMBOY_TEST_DEVICE': 'previous'}):
                    self.assertEqual(cli.main(), expected)
                    self.assertEqual(os.environ['IMBOY_TEST_DEVICE'], 'previous')
                    if expected == 0:
                        options = run.call_args.args[0]
                        self.assertEqual(options.target, ['integration_test/app_test.dart'])
                        self.assertEqual(options.command, 'execution-run' if execute else 'execution-plan')
                        self.assertEqual(options.platform, ['ios'] if execute else [])
                    else:
                        run.assert_not_called()
                    if not execute:
                        discover.assert_not_called()

    def test_results_do_not_reimport_summaries_or_duplicate_input_paths(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            execution_cli.write_json(root / 'results.json', {'results': [{'id': 'one'}]})
            execution_cli.write_json(root / 'summary.json', {'results': [{'id': 'one'}]})
            self.assertEqual(execution_cli.load_results([root, root]), [{'id': 'one'}])
            self.assertEqual(execution_cli.load_results([root / 'missing.json']), [])

    def test_collected_artifacts_are_relocated_and_missing_or_corrupt_evidence_blocks(self):
        from auto_test_lib import execution_runner
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = 'fixture_test.py'
            (root / target).write_text('# Synthetic protocol fixture, no service or SDK\n')
            original = root / 'worker'
            events = [
                {'type': 'testStart', 'test': {'id': 1, 'name': 'fixture'}},
                {'type': 'testDone', 'testID': 1, 'result': 'success'},
                {'type': 'done', 'success': True},
            ]
            code = 'print(' + repr('\n'.join(json.dumps(event) for event in events)) + ')'
            receipt = execution_runner.execute_process([sys.executable, '-c', code], dict(os.environ), original)
            plan = {'commit': 'a' * 40, 'profile': 'tooling', 'source_fingerprint': 'synthetic'}
            instance = {'id': 'fixture', 'target': target, 'suite': 'tooling', 'platform': 'linux',
                        'product_profile': 'any', 'selected': True}
            attempt = execution_runner._record_attempt(root, plan, instance, receipt, receipt['lines'])
            row = execution_runner._finish(plan, instance, [attempt])
            self.assertEqual(row['status'], 'PASS', row)
            execution_cli.write_json(original / 'results.json', {'artifact_root': str(original), 'results': [row]})
            downloaded = root / 'downloaded'
            shutil.copytree(original, downloaded)
            original.rename(root / 'unavailable-worker')
            self.assertEqual(execution_cli.load_results([downloaded])[0]['status'], 'PASS')
            evidence = downloaded / Path(attempt['evidence']).relative_to(original)
            saved = evidence.read_bytes()
            evidence.write_text('corrupt evidence')
            self.assertEqual(execution_cli.load_results([downloaded])[0]['reason_code'], 'ARTIFACT_EVIDENCE_MISSING_OR_INVALID')
            evidence.write_bytes(saved)
            other_gate = {**row, 'companion_evidence': {'kind': 'coordinator-gate', 'instance_id': 'other'}}
            execution_cli.write_json(downloaded / 'results.json', {'artifact_root': str(original), 'results': [other_gate]})
            self.assertEqual(execution_cli.load_results([downloaded])[0]['status'], 'BLOCKED')
            companion = copy.deepcopy(row)
            companion['attempts'][0]['log_sha256'] = '0' * 64
            with_companion = {**row, 'companion_evidence': companion}
            execution_cli.write_json(downloaded / 'results.json', {'artifact_root': str(original), 'results': [with_companion]})
            self.assertEqual(execution_cli.load_results([downloaded])[0]['status'], 'BLOCKED')
            execution_cli.write_json(downloaded / 'results.json', {'artifact_root': str(original), 'results': [row]})
            evidence.unlink()
            self.assertEqual(execution_cli.load_results([downloaded])[0]['status'], 'BLOCKED')

    def test_failed_upstream_status_is_not_normalized_to_success(self):
        statuses = execution_cli.upstream_statuses(['prepare=cancelled', 'framework=failure'])
        self.assertEqual(statuses, {'prepare': 'cancelled', 'framework': 'failure'})
        with self.assertRaises(ValueError):
            execution_cli.upstream_statuses(['prepare'])

    def test_failed_gate_receipt_cannot_be_overwritten_by_later_pass(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            plan = {'commit': 'abc', 'profile': 'pr', 'source_fingerprint': 'source', 'gates': ['framework']}
            receipt = {key: plan[key] for key in ('commit', 'profile', 'source_fingerprint')}
            receipt.update(log='framework.log', exit_code=0)
            execution_cli.write_json(root / 'a/gates.json', {'framework': {**receipt, 'status': 'FAIL'}})
            execution_cli.write_json(root / 'b/gates.json', {'framework': {**receipt, 'status': 'PASS'}})
            self.assertEqual(execution_cli.load_gates([root], plan)['framework']['status'], 'FAIL')

    def test_gate_receipts_are_bound_to_source_commit_and_profile(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            plan = {'commit': 'abc', 'profile': 'pr', 'source_fingerprint': 'source', 'gates': ['framework']}
            receipt = {key: plan[key] for key in ('commit', 'profile', 'source_fingerprint')}
            receipt.update(log='framework.log', status='PASS', exit_code=0)
            for key in ('commit', 'profile', 'source_fingerprint'):
                with self.subTest(key=key):
                    execution_cli.write_json(root / 'gates.json', {'framework': {**receipt, key: 'stale'}})
                    row = execution_cli.load_gates([root], plan)['framework']
                    self.assertEqual(row['status'], 'BLOCKED')
                    self.assertEqual(row['reason_code'], 'STALE_GATE_EVIDENCE')
            for update in ({'exit_code': 137}, {'log': None}):
                execution_cli.write_json(root / 'gates.json', {'framework': {**receipt, **update}})
                self.assertEqual(execution_cli.load_gates([root], plan)['framework']['reason_code'], 'INVALID_GATE_EVIDENCE')

    def test_gate_log_must_arrive_with_its_relocated_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            original = root / 'gate-worker'
            plan = {'commit': 'abc', 'profile': 'pr', 'source_fingerprint': 'source', 'gates': ['ownership']}
            gates = execution_gates.run_gates(root, plan, original / 'gates', dict(os.environ))
            execution_cli.write_json(original / 'gates.json', gates)
            downloaded = root / 'gate-download'
            original.rename(downloaded)
            self.assertEqual(execution_cli.load_gates([downloaded], plan)['ownership']['status'], 'PASS')
            (downloaded / 'gates/ownership.log').unlink()
            self.assertEqual(execution_cli.load_gates([downloaded], plan)['ownership']['reason_code'], 'INVALID_GATE_EVIDENCE')

    def test_successful_job_cannot_erase_a_failed_gate_receipt(self):
        gates = execution_gates.merge_gate_statuses({'framework': {'status': 'FAIL'}}, {'quality-gates': 'success'})
        self.assertEqual(gates['framework'], 'FAIL')
        gates = execution_gates.merge_gate_statuses({'framework': {'status': 'PASS'}}, {'framework': 'cancelled'})
        self.assertEqual(gates['framework'], 'cancelled')

    def test_ci_jobs_attest_only_their_declared_prerequisite_gates(self):
        gates = execution_gates.merge_gate_statuses({}, {
            'execution-plan': 'success', 'quality-gates': 'cancelled', 'contract-gates': 'failure'})
        self.assertEqual(gates['ownership'], 'success')
        self.assertEqual(gates['framework'], 'cancelled')
        self.assertEqual(gates['static-analysis'], 'cancelled')
        self.assertEqual(gates['sqlite-generator'], 'cancelled')
        self.assertEqual(gates['contracts'], 'failure')

    def test_coverage_counts_unique_lines_and_empty_evidence_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'lcov.info'
            path.write_text('SF:lib/a.dart\nDA:1,1\nDA:2,0\nend_of_record\n'
                            'SF:lib/a.dart\nDA:1,5\nDA:2,0\nend_of_record\n')
            self.assertEqual(execution_cli.coverage_check(path, 50), 0)
            self.assertEqual(execution_cli.coverage_check(path, 51), 1)
            path.write_text('')
            with self.assertRaises(ValueError):
                execution_cli.coverage_check(path, 0)


if __name__ == '__main__':
    unittest.main()
