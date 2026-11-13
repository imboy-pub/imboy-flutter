"""Governance tests use synthetic streams, temporary repos, and fake adapters."""
from __future__ import annotations

import contextlib
import copy
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from unittest.mock import patch

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / 'scripts'))
from auto_test_lib import execution_adapters as adapters
from auto_test_lib import execution_cli as cli
from auto_test_lib import execution_runner as runner
from auto_test_lib.machine_events import parse_machine_events


def events(target='test/a_test.dart', *, skipped=0, passed=1, fail=False, done=True, suite=1):
    items = [{'type': 'suite', 'suite': {'id': suite, 'path': target}}]
    for number in range(passed + skipped + int(fail)):
        test_id = suite * 100 + number
        items += [{'type': 'testStart', 'test': {'id': test_id, 'suiteID': suite, 'name': f'case-{number}'}},
                  {'type': 'testDone', 'testID': test_id, 'result': 'failure' if fail and number == 0 else 'success',
                   'skipped': number >= passed + int(fail)}]
    if done:
        items += [{'type': 'done', 'success': not fail}]
    return [json.dumps(item) for item in items]


def instance(target='test/a_test.dart', platform='linux', product='current', role='primary', **values):
    row = dict(id=json.dumps([target, platform, product, role, values.get('variant', 'default')]),
               target=target, suite='unit', runner='flutter-machine', platform=platform,
               product_profile=product, role=role, variant='default', selected=True,
               status='PLANNED', reason_code=None, dependencies=[], upstream=[],
               product_contract={'manifest_profile': 'any'}, dart_defines={}, coverage_eligible=True)
    row.update(values)
    return row


def plan(*items, **values):
    value = dict(commit='a' * 40, profile='pr', instances=list(items), gates=[], full_regression=False)
    value.update(values)
    return value


class RunnerTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        (self.root / 'test').mkdir()
        (self.root / 'test/a_test.dart').write_text('// synthetic\n')
        (self.root / 'test/b_test.dart').write_text('// synthetic\n')
        self.output = self.root / 'evidence'

    def result(self, spec=None, data=None, code=0, planned=None):
        spec = spec or instance()
        planned = planned or plan(spec)
        output = self.output / hashlib.sha256(spec['id'].encode()).hexdigest()[:12]
        output.mkdir(parents=True, exist_ok=True)
        lines = data if data is not None else events(spec['target'])
        machine = output / 'machine.jsonl'
        machine.write_text('\n'.join(lines) + '\n')
        receipt = {'exit_code': code, 'log': str(machine), 'machine': str(machine),
                   'command': ['flutter', 'test', spec['target'], '--machine'],
                   'execution_context': runner._capture_execution_context(output)}
        runner._persist_process_receipt(receipt, output)
        attempt = runner._record_attempt(self.root, planned, spec, receipt, lines)
        return runner._finish(planned, spec, [attempt])

    def backend_result(self, data=None, code=0, generated_at=1, runtime='community'):
        spec = instance(suite='backend-contract', product='full-selected', required_features=['e2ee'],
                        product_contract={'manifest_profile': 'full-selected', 'backend_runtime_profile': 'community'})
        static = {'manifest_profile': 'full-selected', 'manifest_schema_version': 1,
                  'manifest_hash': 'sha256:' + 'a' * 64, 'compiled_features': ['core', 'e2ee'],
                  'artifacts': {name: 'b' * 64 for name in adapters.PRODUCT_ARTIFACTS},
                  'validation_inputs': {'synthetic': 'c' * 64}}
        static['fingerprint'] = hashlib.sha256(json.dumps(static, sort_keys=True).encode()).hexdigest()
        static['validation'] = 'existing-generator-read-only-render'
        raw = {'manifest_schema_version': 1, 'manifest_hash': static['manifest_hash'],
               'compiled_features': ['core', 'e2ee'], 'features': {'core': True, 'e2ee': True},
               'policy': {'profile': runtime}, 'generated_at': generated_at}
        output = self.output / str(generated_at)
        output.mkdir(parents=True, exist_ok=True)
        path = output / 'backend-manifest.json'
        path.write_text(json.dumps(raw))
        meta = {'kind': 'backend-manifest', 'path': str(path), 'sha256': runner._file_sha256(path)}
        canonical = {k: raw[k] for k in ('manifest_schema_version', 'manifest_hash', 'compiled_features', 'features')}
        canonical['runtime_profile'] = runtime
        product = dict(static, app_fingerprint=static['fingerprint'], backend_manifest=canonical)
        product['fingerprint'] = hashlib.sha256(json.dumps(
            {'app_fingerprint': product['app_fingerprint'], 'backend_manifest': canonical}, sort_keys=True).encode()).hexdigest()
        lines = events() if data is None else data
        machine = output / 'machine.jsonl'
        machine.write_text('\n'.join(lines) + '\n')
        receipt = {'command': ['synthetic'], 'exit_code': code, 'log': str(machine), 'machine': str(machine),
                   'execution_context': runner._capture_execution_context(output), 'product_artifact': product,
                   'backend_manifest_evidence': meta, 'related_evidence': [meta]}
        runner._persist_process_receipt(receipt, output)
        attempt = runner._record_attempt(self.root, plan(spec), spec, receipt, lines)
        return spec, runner._finish(plan(spec), spec, [attempt])

    def test_backend_manifest_offline_verification_and_negative_controls(self):
        for mutation in ('missing', 'tamper', 'process', 'canonical', 'required'):
            with self.subTest(mutation=mutation):
                spec, row = self.backend_result(generated_at=10)
                payload = {'artifact_root': str(self.output)}
                candidate = self.output / 'results.json'
                self.assertEqual('PASS', cli.verify_result_files(row, payload, candidate)['status'])
                attempt = row['attempts'][0]
                meta = attempt['backend_manifest_evidence']
                if mutation == 'missing':
                    Path(meta['path']).unlink()
                elif mutation == 'tamper':
                    Path(meta['path']).write_text('{}')
                elif mutation == 'process':
                    path = Path(attempt['process_receipt'])
                    raw = json.loads(path.read_text())
                    raw['backend_manifest_evidence'] = None
                    path.write_text(json.dumps(raw))
                    attempt['process_receipt_sha256'] = runner._file_sha256(path)
                elif mutation == 'canonical':
                    attempt['product_artifact']['backend_manifest']['runtime_profile'] = 'phase1_delivery'
                else:
                    attempt['instance']['required_features'] = ['wallet']
                    attempt['fingerprint']['config_sha256'] = runner.execution_config_sha256(
                        attempt['instance'], attempt['execution_context']['value'])
                if mutation == 'canonical':
                    path = Path(attempt['process_receipt'])
                    raw = json.loads(path.read_text())
                    raw['product_artifact'] = copy.deepcopy(attempt['product_artifact'])
                    path.write_text(json.dumps(raw))
                    attempt['process_receipt_sha256'] = runner._file_sha256(path)
                checked = cli.verify_result_files(row, payload, candidate)
                self.assertEqual('BLOCKED', checked['status'])
                if mutation == 'canonical':
                    self.assertIn('BACKEND_PRODUCT_FINGERPRINT_MISMATCH', checked['evidence_error'])
                self.assertTrue('BACKEND' in checked['evidence_error'] or 'backend-manifest' in checked['evidence_error'])

    def test_backend_manifest_move_and_generated_time_preserve_fingerprint_and_classifier(self):
        spec, first = self.backend_result(generated_at=1)
        _, second = self.backend_result(generated_at=2)
        self.assertEqual(first['attempts'][0]['fingerprint'], second['attempts'][0]['fingerprint'])
        relocated = self.root / 'download'
        shutil.copytree(self.output, relocated)
        self.assertEqual('PASS', cli.verify_result_files(first, {'artifact_root': str(self.output)},
                                                        relocated / 'results.json')['status'])
        _, failed = self.backend_result(data=events(fail=True), code=1, generated_at=3)
        self.assertEqual('FAIL', runner._finish(plan(spec), spec, failed['attempts'] + second['attempts'])['status'])
        _, other = self.backend_result(generated_at=4, runtime='enterprise')
        self.assertNotEqual(first['attempts'][0]['fingerprint'], other['attempts'][0]['fingerprint'])
        self.assertNotEqual('FLAKY', runner._finish(plan(spec), spec, first['attempts'] + other['attempts'])['status'])

    def test_backend_offline_schema_policy_and_feature_checks_have_valid_hash_controls(self):
        for key, value, reason in [
                ('manifest_schema_version', True, 'INVALID_SCHEMA'),
                ('manifest_hash', 'sha256:' + 'd' * 64, 'APP_MANIFEST_MISMATCH'),
                ('policy', {'profile': 'phase1_delivery'}, 'RUNTIME_PROFILE_MISMATCH'),
                ('features', {'core': True, 'e2ee': False}, 'RUNTIME_FEATURE_DISABLED')]:
            with self.subTest(key=key):
                _, row = self.backend_result(generated_at=60)
                payload = {'artifact_root': str(self.output)}
                candidate = self.output / 'results.json'
                self.assertEqual('PASS', cli.verify_result_files(row, payload, candidate)['status'])
                attempt = row['attempts'][0]
                meta = attempt['backend_manifest_evidence']
                path = Path(meta['path'])
                raw = json.loads(path.read_text())
                raw[key] = value
                path.write_text(json.dumps(raw))
                meta['sha256'] = runner._file_sha256(path)
                # Every other digest/link remains valid: isolate the semantic check.
                attempt['related_evidence'][0] = copy.deepcopy(meta)
                process = Path(attempt['process_receipt'])
                saved = json.loads(process.read_text())
                saved['backend_manifest_evidence'] = copy.deepcopy(meta)
                process.write_text(json.dumps(saved))
                attempt['process_receipt_sha256'] = runner._file_sha256(process)
                checked = cli.verify_result_files(row, payload, candidate)
                self.assertEqual('BLOCKED', checked['status'])
                self.assertIn(reason, checked['evidence_error'])
                # A blocked downloaded row must still reconcile without throwing.
                self.assertEqual('BLOCKED', runner.reconcile(plan(attempt['instance']), [checked])['status'])

    def test_backend_verdict_malformed_related_and_execution_errors_block_without_crashing(self):
        for key, value in [('related_evidence', {'forged': 'dict'}),
                           ('execution_errors', 1), ('execution_errors', 'forged')]:
            with self.subTest(key=key, value=value):
                spec, row = self.backend_result(generated_at=70)
                self.assertEqual('PASS', runner._verdict(row['attempts'])['test_status'])
                row['attempts'][0][key] = value
                self.assertEqual('BLOCKED', runner._verdict(row['attempts'])['test_status'])
                self.assertEqual('BLOCKED', runner.reconcile(plan(spec), [row])['status'])

    def test_backend_malformed_nested_json_blocks_without_crashing(self):
        for key, value in [('product_contract', ['forged']), ('required_features', 1),
                           ('required_features', [None])]:
            with self.subTest(key=key, value=value):
                _, row = self.backend_result(generated_at=50)
                candidate = self.output / 'results.json'
                payload = {'artifact_root': str(self.output)}
                self.assertEqual('PASS', cli.verify_result_files(row, payload, candidate)['status'])
                attempt = row['attempts'][0]
                attempt['instance'][key] = value
                attempt['fingerprint']['config_sha256'] = runner.execution_config_sha256(
                    attempt['instance'], attempt['execution_context']['value'])
                checked = cli.verify_result_files(row, payload, candidate)
                self.assertEqual('BLOCKED', checked['status'])
        for value in (None, [], 1, 'forged', {'kind': 'backend-manifest'}):
            with self.subTest(meta=value):
                _, row = self.backend_result(generated_at=51)
                self.assertEqual('PASS', cli.verify_result_files(row, payload, candidate)['status'])
                attempt = row['attempts'][0]
                attempt['backend_manifest_evidence'] = value
                process = Path(attempt['process_receipt'])
                saved = json.loads(process.read_text())
                saved['backend_manifest_evidence'] = value
                process.write_text(json.dumps(saved))
                attempt['process_receipt_sha256'] = runner._file_sha256(process)
                if isinstance(value, dict):
                    attempt['related_evidence'].append(value)
                checked = cli.verify_result_files(row, payload, candidate)
                self.assertEqual('BLOCKED', checked['status'])

    def test_backend_fixture_fingerprint_is_recomputed_by_offline_cli(self):
        spec, row = self.backend_result(generated_at=80)
        payload = {'artifact_root': str(self.output)}
        candidate = self.output / 'results.json'
        self.assertEqual('PASS', cli.verify_result_files(row, payload, candidate)['status'])
        self.assertEqual('PASS', runner.reconcile(plan(spec), [row])['status'])
        altered = copy.deepcopy(row)
        altered['attempts'][0]['fingerprint']['fixture_fingerprint'] = '0' * 64
        checked = cli.verify_result_files(altered, payload, candidate)
        self.assertEqual('BLOCKED', checked['status'])
        self.assertIn('BACKEND_FIXTURE_FINGERPRINT_MISMATCH', checked['evidence_error'])
        self.assertEqual('BLOCKED', runner.reconcile(plan(spec), [checked])['status'])

    def test_backend_pre_identity_survives_host_wrapper_and_post_sampling(self):
        spec = instance(suite='backend-contract', required_features=['e2ee'])
        prepared = {'command': ['flutter', 'test', spec['target']], 'env': {},
                    'product_artifact': {'fingerprint': 'startup'},
                    'backend_manifest_evidence': {'kind': 'backend-manifest'},
                    'evidence_artifacts': [{'path': 'startup'}]}
        evidence = {}
        with contextlib.ExitStack() as stack, patch.object(adapters, 'build_invocation', return_value=prepared):
            runner._host_command(self.root, [spec], {}, self.output, stack, adapters,
                                 prepared_evidence=evidence)
        self.assertEqual('startup', evidence['product_artifact']['fingerprint'])
        self.assertEqual(prepared['evidence_artifacts'], evidence['evidence_artifacts'])

    def test_backend_startup_rechecks_original_before_popen_and_finishes_blocked(self):
        spec, baseline = self.backend_result(generated_at=20)
        attempt = baseline['attempts'][0]
        original = {'instance': spec, 'product_artifact': attempt['product_artifact'],
                    'backend_manifest_evidence': attempt['backend_manifest_evidence']}
        command = [sys.executable, '-c', 'print(' + repr('\n'.join(events())) + ')']
        receipt = runner.execute_process(command, os.environ.copy(), self.output / 'startup-good',
                                         invocation_evidence=original)
        receipt['related_evidence'] = [original['backend_manifest_evidence']]
        good = runner._record_attempt(self.root, plan(spec), spec, receipt, receipt['lines'])
        self.assertEqual('PASS', runner._finish(plan(spec), spec, [good])['status'])
        for mutation in ('missing', 'tampered'):
            spec, baseline = self.backend_result(generated_at=21)
            attempt = baseline['attempts'][0]
            original = {'instance': spec, 'product_artifact': attempt['product_artifact'],
                        'backend_manifest_evidence': attempt['backend_manifest_evidence']}
            path = Path(original['backend_manifest_evidence']['path'])
            if mutation == 'missing':
                path.unlink()
            else:
                path.write_text('{}')
            with patch.object(runner.subprocess, 'Popen') as spawn:
                receipt = runner.execute_process(command, os.environ.copy(), self.output / mutation,
                                                 invocation_evidence=original)
            spawn.assert_not_called()
            receipt['related_evidence'] = [original['backend_manifest_evidence']]
            recorded = runner._record_attempt(self.root, plan(spec), spec, receipt, receipt['lines'])
            failed = runner._finish(plan(spec), spec, [recorded])
            self.assertEqual(('BLOCKED', 'BACKEND_MANIFEST_EVIDENCE_MISSING_OR_INVALID'),
                             (failed['status'], failed['reason_code']))

    def test_backend_same_identity_infra_recovery_is_flaky_and_other_identity_cannot_merge(self):
        infra = [json.dumps({'type': 'error', 'message': 'Could not resolve host: synthetic.invalid'})]
        spec, first = self.backend_result(data=infra, code=1, generated_at=31)
        _, second = self.backend_result(generated_at=32)
        self.assertEqual('FLAKY', runner._finish(plan(spec), spec, first['attempts'] + second['attempts'])['status'])
        other = copy.deepcopy(second)
        other['attempts'][0]['fingerprint']['fixture_fingerprint'] = 'd' * 64
        self.assertNotEqual('FLAKY', runner._finish(plan(spec), spec, first['attempts'] + other['attempts'])['status'])

    def test_backend_batch_uses_pre_invocation_product_and_never_post_replaces_it(self):
        spec, baseline = self.backend_result(generated_at=40)
        attempt = baseline['attempts'][0]
        prepared = {'command': ['flutter', 'test', spec['target']], 'env': {},
                    'product_artifact': attempt['product_artifact'],
                    'backend_manifest_evidence': attempt['backend_manifest_evidence'],
                    'evidence_artifacts': [attempt['backend_manifest_evidence']]}
        with patch.object(runner, '_default_preflight', return_value=[]), \
                patch.object(adapters, 'preflight_instance', return_value=[]), \
                patch.object(adapters, 'build_invocation', return_value=prepared), \
                patch.object(adapters, 'product_artifact_evidence', side_effect=AssertionError('post sample')), \
                patch.object(runner, 'execute_process', side_effect=self.process):
            result = runner.run_plan(self.root, plan(spec), self.output / 'batch')
        row = result['results'][0]
        self.assertEqual('PASS', row['status'], row)
        self.assertEqual(attempt['product_artifact'], row['product_artifact'])
        self.assertEqual('PASS', cli.verify_result_files(row, {'artifact_root': str(self.output)},
                                                        self.output / 'results.json')['status'])

    def mock_execution(self, process):
        stack = contextlib.ExitStack()
        stack.enter_context(patch.object(runner, '_default_preflight', return_value=[]))
        stack.enter_context(patch.object(adapters, 'preflight_instance', return_value=[]))
        stack.enter_context(patch.object(adapters, 'product_artifact_evidence', return_value={'errors': []}))
        stack.enter_context(patch.object(adapters, 'build_invocation', side_effect=lambda root, i, env, out:
            {'command': ['flutter', 'test', i['target'], '--machine'], 'env': env}))
        stack.enter_context(patch.object(runner, 'execute_process', side_effect=process))
        return stack

    def process(self, command, env, output, **kwargs):
        targets = [v for v in command if v.endswith('_test.dart')]
        lines = []
        for number, target in enumerate(targets):
            lines.extend(events(target, suite=number + 1, done=False))
        lines += [json.dumps({'type': 'done', 'success': True})]
        output.mkdir(parents=True, exist_ok=True)
        path = output / 'machine.jsonl'
        path.write_text('\n'.join(lines))
        if '--coverage-path' in command:
            coverage = Path(command[command.index('--coverage-path') + 1])
            coverage.write_text('SF:lib/sample.dart\nDA:1,1\nDA:2,0\nend_of_record\n')
        return runner._persist_process_receipt(
            {'exit_code': 0, 'lines': lines, 'log': str(path), 'machine': str(path),
             'command': list(command), 'execution_context': runner._capture_execution_context(output)}, output)

    def coverage_workers(self, *, process=None, widget_coverage=True):
        declared = plan(instance(), instance('test/b_test.dart', suite='widget'),
                        instance(platform='macos'), instance(platform='web'))
        with self.mock_execution(process or self.process):
            for suite in ('unit', 'widget'):
                report = runner.run_plan(self.root, declared, self.output / suite,
                    worker_platform='linux', worker_suites=[suite],
                    coverage=suite == 'unit' or widget_coverage)
                self.assertEqual(report['expected_instances'], 1)
        return declared

    def context_result(self, name='context', *, context=None, spec=None, data=None, code=0,
                       environment=None, before_spawn=None):
        context = context or dict(schema_version=1, host_platform='linux', euid=1000, egid=1000,
                                  linux_cap_eff='0000000000000000', linux_pid1_comm='docker-init')
        output = self.output / name
        spec = spec or instance()
        lines = data if data is not None else events(spec['target'])
        command = [sys.executable, '-c', 'import sys; print(' + repr('\n'.join(lines)) +
                   '); sys.exit(' + str(code) + ')']
        original_read, original_spawn = Path.read_text, subprocess.Popen
        def read(path, *args, **kwargs):
            if str(path) == '/proc/self/status':
                return 'Name:\tpython\nCapEff:\t' + context['linux_cap_eff'] + '\n'
            if str(path) == '/proc/1/comm':
                return context['linux_pid1_comm'] + '\n'
            return original_read(path, *args, **kwargs)
        def spawn(*args, **kwargs):
            if before_spawn:
                before_spawn(output)
            return original_spawn(*args, **kwargs)
        with patch.object(runner.sys, 'platform', context['host_platform']), \
                patch.object(runner.os, 'geteuid', return_value=context['euid']), \
                patch.object(runner.os, 'getegid', return_value=context['egid']), \
                patch.object(Path, 'read_text', read), patch.object(runner.subprocess, 'Popen', spawn):
            receipt = runner.execute_process(command, dict(os.environ, **(environment or {})), output)
        attempt = runner._record_attempt(self.root, plan(spec), spec, receipt, receipt['lines'])
        return receipt, attempt, runner._finish(plan(spec), spec, [attempt])

    def test_execution_context_measured_before_spawn_and_never_remeasured_for_attempt(self):
        def before(output):
            self.assertEqual(json.loads((output / 'execution-context.json').read_text())['euid'], 1000)
        receipt, attempt, row = self.context_result(before_spawn=before)
        self.assertEqual(row['status'], 'PASS', row)
        context = receipt['execution_context']
        self.assertEqual(context, attempt['execution_context'])
        self.assertEqual(context['value']['euid'], 1000)
        self.assertIn({'path': context['path'], 'sha256': context['sha256']}, attempt['related_evidence'])
        saved = json.loads(Path(receipt['process_receipt']).read_text())
        self.assertEqual(saved['execution_context'], context)
        expected = hashlib.sha256(json.dumps({'instance': instance(), 'context': context['value']},
                                             sort_keys=True).encode()).hexdigest()
        self.assertEqual(attempt['fingerprint']['config_sha256'], expected)

    def test_execution_context_stability_and_measured_uid_gid_capability_init_changes(self):
        base = dict(schema_version=1, host_platform='linux', euid=1000, egid=1000,
                    linux_cap_eff='0000000000000000', linux_pid1_comm='docker-init')
        cases = [base, base, *[{**base, key: value} for key, value in (
            ('euid', 0), ('egid', 0), ('linux_cap_eff', '0000000000000002'),
            ('linux_pid1_comm', 'sleep'))]]
        hashes = [self.context_result(str(i), context=value)[1]['fingerprint']['config_sha256']
                  for i, value in enumerate(cases)]
        self.assertEqual(hashes[0], hashes[1])
        self.assertEqual(len(set(hashes)), 5)

    def test_execution_context_environment_spoof_does_not_override_measurement(self):
        receipt, _, _ = self.context_result(environment={
            'IMBOY_EXECUTION_CONTEXT_EUID': '0', 'CapEff': 'ffffffffffffffff',
            'IMBOY_EXECUTION_CONTEXT': '{"euid":0,"linux_pid1_comm":"fake-init"}'})
        measured = receipt['execution_context']['value']
        self.assertEqual((measured['euid'], measured['linux_cap_eff'], measured['linux_pid1_comm']),
                         (1000, '0000000000000000', 'docker-init'))

    def test_execution_context_non_linux_explicitly_not_applicable(self):
        expected = dict(schema_version=1, host_platform='darwin', euid=501, egid=20,
                        linux_cap_eff=None, linux_pid1_comm=None)
        receipt, _, _ = self.context_result(context=expected)
        self.assertEqual(receipt['execution_context']['value'], expected)

    def test_execution_context_measurement_failure_blocks_before_process_spawn(self):
        original = Path.read_text
        def read(path, *args, **kwargs):
            if str(path).startswith('/proc/'):
                raise FileNotFoundError('synthetic missing proc context')
            return original(path, *args, **kwargs)
        with patch.object(runner.sys, 'platform', 'linux'), patch.object(Path, 'read_text', read), \
                patch.object(runner.subprocess, 'Popen', side_effect=AssertionError('spawned before context measurement')) as spawn:
            receipt = runner.execute_process(['must-not-spawn'], dict(os.environ), self.output)
        spawn.assert_not_called()
        self.assertNotEqual(receipt['exit_code'], 0)
        self.assertIn('EXECUTION_CONTEXT', receipt['error'])
        attempt = runner._record_attempt(self.root, plan(instance()), instance(), receipt, receipt['lines'])
        row = runner._finish(plan(instance()), instance(), [attempt])
        self.assertEqual((row['status'], row['reason_code']),
                         ('BLOCKED', 'EXECUTION_CONTEXT_MISSING_OR_INVALID'))

    def test_execution_context_missing_receipt_or_startup_file_blocks_attempt_without_remeasurement(self):
        for case in ('missing-receipt', 'changed-startup-file'):
            with self.subTest(case=case):
                receipt, _, _ = self.context_result(case)
                if case == 'missing-receipt':
                    receipt.pop('execution_context')
                else:
                    Path(receipt['execution_context']['path']).write_text('{}')
                with patch.object(runner, '_capture_execution_context', side_effect=AssertionError('remeasured')):
                    attempt = runner._record_attempt(self.root, plan(instance()), instance(), receipt, receipt['lines'])
                row = runner._finish(plan(instance()), instance(), [attempt])
                self.assertEqual((row['status'], row['reason_code']),
                                 ('BLOCKED', 'EXECUTION_CONTEXT_MISSING_OR_INVALID'))

    def test_execution_context_raw_missing_tampering_and_process_attempt_mismatch_block(self):
        for case in ('missing', 'tampered', 'mismatch', 'inline', 'config'):
            with self.subTest(case=case):
                receipt, attempt, row = self.context_result(case)
                candidate = self.output / 'results.json'
                payload = {'artifact_root': str(self.output)}
                self.assertEqual(cli.verify_result_files(row, payload, candidate)['status'], 'PASS')
                meta = attempt['execution_context']
                if case == 'missing':
                    Path(meta['path']).unlink()
                elif case == 'tampered':
                    Path(meta['path']).write_text('{}')
                elif case == 'mismatch':
                    process = json.loads(Path(attempt['process_receipt']).read_text())
                    process['execution_context']['value']['euid'] = 0
                    runner._write_json(Path(attempt['process_receipt']), process)
                    attempt['process_receipt_sha256'] = runner._file_sha256(attempt['process_receipt'])
                elif case == 'inline':
                    attempt['execution_context']['value']['euid'] = 0
                else:
                    attempt['fingerprint']['config_sha256'] = '0' * 64
                checked = cli.verify_result_files(row, {'artifact_root': str(self.output)}, candidate)
                self.assertEqual(checked['status'], 'BLOCKED', checked)
                self.assertEqual(checked['reason_code'], 'ARTIFACT_EVIDENCE_MISSING_OR_INVALID')
                if case == 'mismatch':
                    self.assertEqual(checked['evidence_error'], 'process and attempt execution context mismatch')

    def test_execution_context_malformed_saved_json_blocks_without_aborting_verifier(self):
        for key, value in (('fingerprint', None), ('fingerprint', []), ('fingerprint', 0), ('fingerprint', 'invalid'),
                           ('related_evidence', None), ('related_evidence', {}), ('instance', [])):
            with self.subTest(key=key, value=value):
                _, attempt, row = self.context_result('malformed-' + key + '-' + str(value))
                payload, candidate = {'artifact_root': str(self.output)}, self.output / 'results.json'
                self.assertEqual(cli.verify_result_files(row, payload, candidate)['status'], 'PASS')
                attempt[key] = value
                self.assertEqual(cli.verify_result_files(row, payload, candidate)['status'], 'BLOCKED')
                self.assertEqual(runner._verdict([attempt])['test_status'], 'BLOCKED')

    def test_execution_context_malformed_attempt_collection_stays_blocked_through_summary(self):
        for value in (None, 'invalid', [None], [[]], [0]):
            with self.subTest(attempts=value):
                _, _, row = self.context_result('invalid-attempts-' + str(value))
                payload, candidate = {'artifact_root': str(self.output)}, self.output / 'results.json'
                self.assertEqual(cli.verify_result_files(row, payload, candidate)['status'], 'PASS')
                row['attempts'] = value
                checked = cli.verify_result_files(row, payload, candidate)
                self.assertEqual(checked['status'], 'BLOCKED')
                self.assertEqual(runner.reconcile(plan(instance()), [checked])['status'], 'BLOCKED')

    def test_execution_context_schema_rejects_unknown_nonce_and_invalid_linux_values(self):
        for change in ({'nonce': 'must-not-be-accepted'}, {'euid': True},
                       {'linux_cap_eff': None}, {'linux_pid1_comm': ''}):
            with self.subTest(change=change):
                _, attempt, row = self.context_result('schema-' + str(len(change)) + '-' + str(next(iter(change))))
                self.assertEqual(cli.verify_result_files(row, {'artifact_root': str(self.output)},
                                                        self.output / 'results.json')['status'], 'PASS')
                meta = attempt['execution_context']
                previous_sha = meta['sha256']
                meta['value'].update(change)
                runner._write_json(Path(meta['path']), meta['value'])
                meta['sha256'] = runner._file_sha256(meta['path'])
                for reference in attempt['related_evidence']:
                    if reference == {'path': meta['path'], 'sha256': previous_sha}:
                        reference['sha256'] = meta['sha256']
                process = json.loads(Path(attempt['process_receipt']).read_text())
                process['execution_context'] = copy.deepcopy(meta)
                runner._write_json(Path(attempt['process_receipt']), process)
                attempt['process_receipt_sha256'] = runner._file_sha256(attempt['process_receipt'])
                attempt['fingerprint']['config_sha256'] = hashlib.sha256(json.dumps(
                    {'instance': attempt['instance'], 'context': meta['value']}, sort_keys=True).encode()).hexdigest()
                checked = cli.verify_result_files(row, {'artifact_root': str(self.output)},
                                                  self.output / 'results.json')
                self.assertEqual(checked['status'], 'BLOCKED', checked)

    def test_execution_context_download_relocation_and_saved_instance_plan_binding_with_coverage(self):
        spec = instance(coverage=True)
        _, attempt, row = self.context_result(spec=spec)
        original = self.output
        cli.write_json(original / 'results.json', {'artifact_root': str(original), 'results': [row]})
        downloaded = self.root / 'downloaded-context'
        shutil.copytree(original, downloaded)
        original.rename(self.root / 'old-context')
        checked = cli.load_results([downloaded])[0]
        self.assertEqual(checked['status'], 'PASS', checked)
        self.assertEqual(runner.reconcile(plan(instance()), [checked])['status'], 'PASS')
        changed = copy.deepcopy(checked)
        changed['attempts'][0]['instance']['dependencies'] = ['unexpected-new-dependency']
        context = changed['attempts'][0]['execution_context']['value']
        changed['attempts'][0]['fingerprint']['config_sha256'] = hashlib.sha256(json.dumps(
            {'instance': changed['attempts'][0]['instance'], 'context': context}, sort_keys=True).encode()).hexdigest()
        self.assertEqual(runner.reconcile(plan(instance()), [changed])['results'][0]['reason_code'],
                         'RESULT_INSTANCE_MISMATCH')

    def test_execution_context_retry_semantics_and_different_context_never_merge(self):
        infra = [json.dumps({'type': 'error', 'message': 'Could not resolve host: synthetic.invalid'})]
        _, first, _ = self.context_result('infra', data=infra, code=1)
        _, success, _ = self.context_result('success')
        self.assertEqual(runner._finish(plan(instance()), instance(), [first, success])['status'], 'FLAKY')
        _, failure, _ = self.context_result('failure', data=events(passed=0, fail=True), code=1)
        self.assertEqual(runner._finish(plan(instance()), instance(), [failure, success])['status'], 'FAIL')
        changed = dict(schema_version=1, host_platform='linux', euid=0, egid=1000,
                       linux_cap_eff='0000000000000000', linux_pid1_comm='docker-init')
        _, different, _ = self.context_result('different', context=changed)
        self.assertEqual(runner._finish(plan(instance()), instance(), [first, different])['reason_code'],
                         'MULTIPLE_ATTEMPT_MERGE_INVALID')

    def test_host_matrix_preserves_every_platform_product_and_role_instance(self):
        items = [instance(platform=platform, product=product, role=role)
                 for platform in ('linux', 'macos', 'web') for product in ('current', 'phase1')
                 for role in ('primary', 'secondary')]
        items += [instance('test/b_test.dart', suite='widget'),
                  instance('test/c_test.dart', selected=False, reason_code='OUT_OF_SCOPE')]
        declared = plan(*items)
        matrix = runner.host_worker_matrix(declared)['include']
        selected = [item['id'] for worker in matrix for item in runner._worker_instances(
            declared, worker['platform'], [worker['suite']])]
        self.assertCountEqual(selected, [item['id'] for item in items if item['selected']])
        self.assertEqual(len(selected), len(set(selected)))
        self.assertEqual(len(matrix), 4)
        browser = next(worker for worker in matrix if worker['platform'] == 'web')
        self.assertEqual(browser['os'], 'ubuntu-24.04')
        self.assertTrue(all(worker['os'] == 'ubuntu-24.04'
                            for worker in matrix if worker['platform'] == 'linux'))
        self.assertEqual(browser['coverage'], '')
        self.assertTrue(all(worker['coverage'] == ('--coverage' if worker['platform'] == 'linux' else '')
                            for worker in matrix))
        items[0].update(selected=False, reason_code='PLATFORM_NA')
        self.assertIn('macos', {worker['platform'] for worker in runner.host_worker_matrix(declared)['include']})

    def test_host_matrix_rejects_empty_duplicate_and_specialist_obligations(self):
        for declared in (plan(), plan(instance(), instance()),
                         plan(instance(runner='device-pair', suite='device-pair')),
                         plan(instance(runner='patrol', suite='native-ui')),
                         plan(instance(platform='android')),
                         plan(instance(platform='web', runner='python-unittest'))):
            with self.subTest(plan=declared), self.assertRaises(ValueError):
                runner.host_worker_matrix(declared)

    def test_coverage_reconciles_workers_before_merging_unique_source_lines(self):
        declared = self.coverage_workers()
        downloaded = self.root / 'downloaded'
        shutil.copytree(self.output, downloaded)
        self.output.rename(self.root / 'unavailable-workers')
        report = cli.coverage_from_results(declared, [downloaded], 'linux', self.root / 'merged.info', 38)
        self.assertEqual(report['status'], 'PASS', report)
        self.assertEqual((report['expected_instances'], report['verified_instances']), (2, 2))
        self.assertEqual(report['coverage']['source_lines'], 2)
        self.assertEqual(report['coverage']['percent'], 50)
        self.assertEqual(report['coverage_files'], 2)
        self.assertFalse(report['complete_regression'])
        low = cli.coverage_from_results(declared, [downloaded], 'linux', self.root / 'higher.info', 51)
        self.assertEqual((low['exit_code'], low['reason_code']), (1, 'COVERAGE_BELOW_THRESHOLD'))

    def test_missing_coverage_worker_cannot_pass_even_when_remaining_lcov_meets_threshold(self):
        declared = self.coverage_workers()
        report = cli.coverage_from_results(declared, [self.output / 'unit'], 'linux', self.root / 'merged.info', 38)
        self.assertEqual(report['status'], 'BLOCKED')
        self.assertTrue(report['coverage']['threshold_met'])
        self.assertEqual(report['verified_instances'], 1)
        self.assertEqual(report['missing_evidence'], [
            {'id': declared['instances'][1]['id'], 'reason_code': 'MISSING_RESULT'}])

    def test_worker_without_coverage_cannot_be_hidden_by_another_worker_lcov(self):
        declared = self.coverage_workers(widget_coverage=False)
        report = cli.coverage_from_results(declared, [self.output], 'linux', self.root / 'merged.info', 38)
        self.assertEqual(report['exit_code'], 2)
        self.assertEqual(report['missing_evidence'][0]['reason_code'], 'MISSING_COVERAGE_RESULT')
        self.assertTrue(report['coverage']['threshold_met'])

    def test_tampered_lcov_and_forged_collection_command_cannot_certify_coverage(self):
        declared = self.coverage_workers(widget_coverage=False)
        results = self.output / 'widget/results.json'
        payload = json.loads(results.read_text())
        attempt = payload['results'][0]['attempts'][0]
        coverage = self.output / 'widget/forged.info'
        coverage.write_text('SF:lib/sample.dart\nDA:1,1\nend_of_record\n')
        attempt.update(coverage=str(coverage), coverage_sha256=runner._file_sha256(coverage))
        cli.write_json(results, payload)
        report = cli.coverage_from_results(declared, [self.output], 'linux', self.root / 'merged.info', 38)
        self.assertEqual(report['missing_evidence'][0]['reason_code'], 'ARTIFACT_EVIDENCE_MISSING_OR_INVALID')
        unit = json.loads((self.output / 'unit/results.json').read_text())
        Path(unit['results'][0]['attempts'][0]['coverage']).write_text('SF:lib/forged.dart\nDA:1,100\nend_of_record\n')
        report = cli.coverage_from_results(declared, [self.output], 'linux', self.root / 'merged.info', 0)
        self.assertEqual(report['verified_instances'], 0)
        self.assertNotEqual(report['exit_code'], 0)

    def test_duplicate_or_stale_worker_receipts_cannot_certify_coverage(self):
        declared = self.coverage_workers()
        duplicate = self.root / 'duplicate'
        shutil.copytree(self.output / 'unit', duplicate)
        report = cli.coverage_from_results(declared, [self.output, duplicate], 'linux', self.root / 'merged.info', 38)
        self.assertEqual(report['missing_evidence'][0]['reason_code'], 'DUPLICATE_RESULT')
        declared['commit'] = 'b' * 40
        report = cli.coverage_from_results(declared, [self.output], 'linux', self.root / 'stale.info', 38)
        self.assertEqual({item['reason_code'] for item in report['missing_evidence']}, {'RESULT_IDENTITY_MISMATCH'})

    def test_zero_skip_and_nonzero_process_results_block_coverage(self):
        for counts, code in (({'passed': 0}, 0), ({'passed': 0, 'skipped': 1}, 0),
                             ({'passed': 1, 'skipped': 1}, 0), ({'passed': 1}, 137)):
            def incomplete(command, env, output, **kwargs):
                receipt = self.process(command, env, output, **kwargs)
                if 'test/b_test.dart' in command:
                    receipt.update(lines=events('test/b_test.dart', **counts), exit_code=code)
                    Path(receipt['machine']).write_text('\n'.join(receipt['lines']))
                    runner._persist_process_receipt(receipt, output)
                return receipt
            with self.subTest(counts=counts, code=code):
                declared = self.coverage_workers(process=incomplete)
                report = cli.coverage_from_results(declared, [self.output], 'linux', self.root / 'merged.info', 38)
                self.assertNotEqual(report['exit_code'], 0)
                self.assertEqual(report['verified_instances'], 1)
                self.assertTrue(report['coverage']['threshold_met'])

    def test_empty_coverage_plan_cannot_pass(self):
        report = cli.coverage_from_results(plan(full_regression=True), [], 'linux', self.root / 'empty.info', 0)
        self.assertEqual(report['exit_code'], 2)
        self.assertEqual(report['expected_instances'], 0)
        self.assertFalse(report['complete_regression'])

    def test_success_requires_matching_receipt_for_every_instance(self):
        a, b, browser = instance(), instance('test/b_test.dart'), instance(platform='web')
        declared = plan(a, b, browser)
        good = [self.result(i, planned=declared) for i in (a, b, browser)]
        self.assertEqual(runner.reconcile(declared, good)['status'], 'PASS')
        missing = runner.reconcile(declared, good[:2])
        self.assertEqual(missing['status'], 'BLOCKED')
        self.assertEqual(missing['results'][2]['reason_code'], 'MISSING_RESULT')
        self.assertEqual(missing['results'][2]['platform'], 'web')

    def test_empty_full_plan_cannot_pass(self):
        actual = runner.reconcile(plan(profile='full', full_regression=True), [])
        self.assertEqual(actual['reason_code'], 'EMPTY_PLAN')
        self.assertFalse(actual['complete_regression'])
        self.assertEqual(actual['exit_code'], 2)

    def test_zero_all_partial_skips_and_missing_done_never_pass(self):
        streams = [events(passed=0), events(passed=0, skipped=1), events(passed=1, skipped=1), events(done=False)]
        for data in streams:
            with self.subTest(data=data):
                result = self.result(data=data)
                self.assertNotEqual(result['status'], 'PASS')
                self.assertNotEqual(runner.reconcile(plan(instance()), [result])['exit_code'], 0)
        self.assertEqual(self.result(data=streams[2])['reason_code'], 'UNEXPECTED_SKIP')

    def test_nonzero_process_overrules_success_events(self):
        result = self.result(code=137)
        self.assertEqual(result['status'], 'BLOCKED')
        self.assertNotEqual(runner.reconcile(plan(instance()), [result])['exit_code'], 0)

    def test_no_attempts_or_forged_counts_cannot_claim_pass(self):
        for mutation in ('attempts', 'counts'):
            row = self.result()
            row[mutation] = [] if mutation == 'attempts' else {k: 50 for k in runner.COUNT_KEYS}
            self.assertNotEqual(runner.reconcile(plan(instance()), [row])['exit_code'], 0)

    def test_missing_exit_evidence_and_unknown_events_cannot_claim_pass(self):
        row = self.result()
        row['attempts'][0]['parsed']['process_exit_code'] = None
        self.assertEqual(runner.reconcile(plan(instance()), [row])['results'][0]['reason_code'], 'INCOMPLETE_EVIDENCE')

    def test_raw_process_receipt_cannot_disagree_with_successful_parsed_claim(self):
        row = self.result()
        row['attempts'][0]['process_exit_code'] = 137
        summary = runner.reconcile(plan(instance()), [row])
        self.assertEqual(summary['results'][0]['reason_code'], 'PROCESS_RECEIPT_MISMATCH')
        self.assertNotEqual(summary['exit_code'], 0)

    def test_execution_command_and_evidence_locations_are_required(self):
        for field, value in [('command', []), ('log', None), ('evidence', ''), ('process_exit_code', None)]:
            with self.subTest(field=field):
                row = self.result()
                row['attempts'][0][field] = value
                summary = runner.reconcile(plan(instance()), [row])
                self.assertEqual(summary['results'][0]['reason_code'], 'INCOMPLETE_EVIDENCE')
        for field in ('logs', 'evidence'):
            row = self.result()
            row[field] = []
            self.assertEqual(runner.reconcile(plan(instance()), [row])['results'][0]['reason_code'],
                             'INCOMPLETE_EVIDENCE')

    def test_process_identity_dependency_blocks_before_target_execution(self):
        host = {'darwin': 'macos', 'win32': 'windows'}.get(sys.platform, sys.platform)
        spec = instance(platform=host, runner='python-cases', dependencies=['process-identity'])
        reason = 'process-identity: ps cannot verify live parent/child start times'
        with patch.object(runner, '_process_identity_preflight', return_value=[reason]):
            self.assertEqual(runner._default_preflight(self.root, spec, dict(os.environ)), [reason])

    def test_missing_coverage_cannot_pass_a_coverage_run(self):
        def no_coverage(command, env, output, **kwargs):
            receipt = self.process(command, env, output, **kwargs)
            (output / 'lcov.info').unlink()
            return receipt
        with self.mock_execution(no_coverage):
            summary = runner.run_plan(self.root, plan(instance()), self.output, coverage=True)
        self.assertEqual(summary['results'][0]['reason_code'], 'MISSING_COVERAGE_RESULT')
        self.assertNotEqual(summary['exit_code'], 0)

    def test_route_quarantine_switch_is_an_execution_define_without_skip_waiver(self):
        spec = instance(suite='route-smoke')
        with contextlib.ExitStack() as stack:
            command, _, _ = runner._host_command(self.root, [spec],
                {'IMBOY_SMOKE_INCLUDE_QUARANTINED': 'true'}, self.output, stack)
        self.assertIn('--dart-define=SMOKE_INCLUDE_QUARANTINED=true', command)
        self.assertEqual(self.result(spec, events(skipped=1))['reason_code'], 'UNEXPECTED_SKIP')

    def test_native_skip_preserves_junit_evidence_and_skip_reason(self):
        self.output.mkdir()
        log = self.output / 'process.log'
        log.write_text('synthetic Patrol process output\n')
        receipt = {'exit_code': 0, 'log': str(log), 'machine': str(log), 'command': ['patrol', 'test'],
                   'execution_context': runner._capture_execution_context(self.output)}
        runner._persist_process_receipt(receipt, self.output)
        junit = self.root / 'original-junit.xml'
        junit.write_text('<testsuite><testcase name="synthetic" /></testsuite>')
        parsed = {'passed': 1, 'failed': 0, 'skipped': 1, 'errors': ['UNEXPECTED_SKIP']}
        with patch.object(adapters, 'fresh_junit_paths', return_value=[str(junit)]), \
                patch.object(adapters, 'parse_patrol_junit', return_value=parsed):
            lines = runner._patrol_events(adapters, self.root, {}, receipt, 'test/a_test.dart')
        self.assertTrue(Path(receipt['machine']).is_file())
        self.assertTrue(Path(receipt['native_evidence']).is_file())
        copied = receipt['related_evidence'][0]
        self.assertTrue(Path(copied['path']).is_relative_to(self.output))
        self.assertEqual(Path(copied['path']).read_bytes(), junit.read_bytes())
        self.assertEqual(copied['sha256'], runner._file_sha256(junit))
        attempt = runner._record_attempt(self.root, plan(instance()), instance(), receipt, lines)
        self.assertEqual(runner._verdict([attempt])['reason_code'], 'UNEXPECTED_SKIP')

    def test_persisted_target_streams_can_be_independently_reparsed(self):
        with self.mock_execution(self.process):
            summary = runner.run_plan(self.root, plan(instance(), instance('test/b_test.dart')), self.output)
        self.assertEqual(summary['status'], 'PASS')
        evidence_paths = []
        for row in summary['results']:
            attempt = row['attempts'][0]
            evidence = Path(attempt['evidence'])
            evidence_paths.append(evidence)
            actual = parse_machine_events(evidence.read_text().splitlines(), attempt['process_exit_code']).to_dict()
            self.assertEqual(actual, attempt['parsed'])
            self.assertEqual(actual['executed'], 1)
            for key in ('log', 'evidence', 'process_receipt'):
                self.assertEqual(runner._file_sha256(attempt[key]), attempt[key + '_sha256'])
                self.assertTrue(Path(attempt[key]).is_relative_to(self.output))
            process = json.loads(Path(attempt['process_receipt']).read_text())
            self.assertEqual(process['exit_code'], attempt['process_exit_code'])
            self.assertEqual(process['command'], attempt['command'])
        self.assertEqual(len(set(evidence_paths)), 2)
        payload = json.loads((self.output / 'results.json').read_text())
        self.assertEqual(payload['artifact_root'], str(self.output))
        self.assertEqual(len(payload['results']), 2)

    def test_success_requires_persisted_receipt_hash_metadata(self):
        for key in ('log_sha256', 'evidence_sha256', 'process_receipt', 'process_receipt_sha256'):
            row = self.result()
            row['attempts'][0].pop(key)
            self.assertEqual(runner.reconcile(plan(instance()), [row])['results'][0]['reason_code'],
                             'INCOMPLETE_EVIDENCE')

    def test_backend_dependency_fingerprint_does_not_claim_an_unused_service(self):
        for dependency in ('backend', 'isolated-backend'):
            fingerprint = runner._fingerprint(self.root, plan(instance()), instance(dependencies=[dependency]),
                                              runner._capture_execution_context(self.output)['value'])
            self.assertEqual(fingerprint['backend_head'], 'UNVERIFIED_SERVICE_VERSION')
        fingerprint = runner._fingerprint(self.root, plan(instance()), instance(dependencies=['backend-source']),
                                          runner._capture_execution_context(self.output)['value'])
        self.assertEqual(fingerprint['backend_head'], 'UNVERIFIED_SOURCE_VERSION')

    def test_host_adapter_command_preserves_no_pub(self):
        with self.mock_execution(self.process), contextlib.ExitStack() as stack:
            command, _, _ = runner._host_command(self.root, [instance()], {}, self.output, stack, adapters)
        self.assertIn('--no-pub', command)

    def test_host_parallelism_preserves_specialist_serial_execution(self):
        def invocation(root, spec, env, output):
            return {'command': ['flutter', 'test', spec['target'], '--machine',
                                '--no-pub', '--concurrency=1'], 'env': env}
        for suites in [('unit', 'widget', 'component'), ('sqlite-ffi',), ('crypto-ffi',),
                       ('backend-contract',), ('route-smoke',), ('unit', 'sqlite-ffi')]:
            with self.subTest(suites=suites), patch.object(adapters, 'build_invocation', side_effect=invocation), contextlib.ExitStack() as stack:
                items = [instance(suite=suite) for suite in suites]
                command, _, _ = runner._host_command(self.root, items, {}, self.output, stack, adapters)
                self.assertEqual('--concurrency=1' in command,
                                 any(suite not in {'unit', 'widget', 'component'} for suite in suites))
                self.assertIn('--no-pub', command)

    def test_explicit_upstream_failure_vetoes_even_without_named_dependency(self):
        result = runner.reconcile(plan(instance()), [self.result()], upstream={'coverage-job': 'failure'})
        self.assertEqual(result['reason_code'], 'UPSTREAM_FAILED')
        self.assertEqual(result['results'][0]['reason_code'], 'UPSTREAM_FAILED')

    def test_required_gate_missing_blocks_full_but_worker_can_defer_it(self):
        a = instance(upstream=['ownership'])
        declared = plan(a, gates=['ownership'])
        result = self.result(a, planned=declared)
        self.assertEqual(runner.reconcile(declared, [result])['status'], 'BLOCKED')
        self.assertEqual(runner.reconcile(declared, [result], worker_platform='linux', require_gates=False)['status'], 'PASS')
        self.assertEqual(runner.reconcile(declared, [result], {'sdk': 'cancelled'}, worker_platform='linux', require_gates=False)['status'], 'BLOCKED')

    def test_platform_product_role_matrix_is_reconciled_independently(self):
        items = [instance(platform=platform, product=product, role=role)
                 for platform in ('linux', 'macos') for product in ('phase1', 'full') for role in ('one', 'two')]
        declared = plan(*items, profile='full', full_regression=True)
        rows = [self.result(i, planned=declared) for i in items]
        summary = runner.reconcile(declared, rows)
        self.assertEqual(summary['expected_instances'], 8)
        self.assertTrue(summary['complete_regression'])
        self.assertFalse(runner.reconcile(declared, rows[:-1])['complete_regression'])
        worker = runner.reconcile(declared, rows, worker_platform='linux', worker_product_profile='phase1')
        self.assertEqual(worker['expected_instances'], 2)
        self.assertFalse(worker['complete_regression'])

    def test_na_and_out_of_scope_rows_leave_applicable_platform_obligation(self):
        linux = instance()
        other = instance(platform='macos', selected=False, status='NOT_SELECTED', reason_code='OUT_OF_SCOPE')
        na = instance(platform='ios', selected=False, status='NOT_APPLICABLE', reason_code='PLATFORM_NA')
        summary = runner.reconcile(plan(linux, other, na), [])
        self.assertEqual(summary['expected_instances'], 1)
        self.assertEqual(summary['status'], 'BLOCKED')
        self.assertEqual(other['reason_code'], 'OUT_OF_SCOPE')
        self.assertEqual(na['reason_code'], 'PLATFORM_NA')

    def test_duplicate_stale_and_wrong_identity_receipts_block(self):
        row = self.result()
        self.assertEqual(runner.reconcile(plan(instance()), [row, row])['results'][0]['reason_code'], 'DUPLICATE_RESULT')
        for key, value in [('commit', 'b' * 40), ('role', 'other'), ('source_fingerprint', 'stale')]:
            altered = copy.deepcopy(row)
            altered[key] = value
            self.assertNotEqual(runner.reconcile(plan(instance()), [altered])['status'], 'PASS')

    def test_per_target_batch_attribution_preserves_separate_counts(self):
        lines = events('test/a_test.dart', passed=2, done=False) + events('test/b_test.dart', skipped=1, passed=0, suite=2)
        streams = runner.split_machine_events(self.root, ['test/a_test.dart', 'test/b_test.dart'], lines)
        self.assertEqual(parse_machine_events(streams['test/a_test.dart'], 0).executed, 2)
        self.assertEqual(parse_machine_events(streams['test/b_test.dart'], 0).skipped, 1)

    def test_unbound_or_truncated_machine_event_blocks_batch(self):
        for extra in [json.dumps({'type': 'testDone', 'testID': 999, 'result': 'success'}), '{"type":"testDone"']:
            streams = runner.split_machine_events(self.root, ['test/a_test.dart'], events() + [extra])
            self.assertNotEqual(parse_machine_events(streams['test/a_test.dart'], 0).test_status, 'PASS')

    def test_host_batch_and_coverage_use_only_selected_declared_targets(self):
        a, b = instance(), instance('test/b_test.dart')
        excluded = instance('test/excluded_test.dart', selected=False)
        calls = []
        def process(*args, **kwargs):
            calls.append(args[0])
            return self.process(*args, **kwargs)
        with self.mock_execution(process):
            actual = runner.run_plan(self.root, plan(a, b, excluded), self.output, coverage=True)
        self.assertEqual(actual['status'], 'PASS')
        self.assertEqual(len(calls), 1)
        self.assertIn(a['target'], calls[0])
        self.assertIn(b['target'], calls[0])
        self.assertNotIn(excluded['target'], calls[0])
        self.assertIn('--coverage', calls[0])
        self.assertTrue((self.output / 'coverage/lcov.info').is_file())
        self.assertEqual({i['target'] for i in json.loads((self.output / 'results.json').read_text())['results']}, {a['target'], b['target']})

    def test_same_target_distinct_roles_are_separate_processes(self):
        calls = []
        def process(*args, **kwargs):
            calls.append(args[0])
            return self.process(*args, **kwargs)
        with self.mock_execution(process):
            summary = runner.run_plan(self.root, plan(instance(role='one'), instance(role='two')), self.output)
        self.assertEqual(summary['status'], 'PASS')
        self.assertEqual(len(calls), 2)

    def test_bounded_host_batches_keep_every_instance_and_merge_coverage_once(self):
        items = [instance(f'test/chunk_{index}_test.dart') for index in range(129)]
        for item in items:
            (self.root / item['target']).write_text('// synthetic host target\n')
        calls = []
        def process(*args, **kwargs):
            calls.append(args[0])
            return self.process(*args, **kwargs)
        with self.mock_execution(process), patch.object(
                runner, 'merge_coverage_files', wraps=runner.merge_coverage_files) as merge:
            summary = runner.run_plan(self.root, plan(*items), self.output, coverage=True)
        batches = [[arg for arg in command if arg.endswith('_test.dart')] for command in calls]
        self.assertEqual([len(batch) for batch in batches], [64, 64, 1])
        self.assertEqual([target for batch in batches for target in batch], [item['target'] for item in items])
        self.assertTrue(all('--coverage' in command for command in calls))
        self.assertEqual(summary['status'], 'PASS')
        self.assertEqual(summary['counts']['actually_run'], 129)
        self.assertEqual(len(summary['results']), 129)
        self.assertEqual({row['id'] for row in summary['results']}, {item['id'] for item in items})
        merge.assert_called_once()
        self.assertEqual(len(set(merge.call_args.args[0])), 3)
        merged = (self.output / 'coverage/lcov.info').read_text()
        self.assertEqual(merged.count('SF:lib/sample.dart'), 1)
        self.assertEqual(merged.count('DA:1,1'), 1)

    def test_route_variants_keep_separate_processes(self):
        items = [instance(suite='route-smoke', variant=f'route-{i}', test_name=f'route {i}') for i in (1, 2)]
        calls = []
        def process(*args, **kwargs):
            calls.append(args[0])
            return self.process(*args, **kwargs)
        with self.mock_execution(process):
            runner.run_plan(self.root, plan(*items), self.output)
        self.assertEqual(len(calls), 2)
        self.assertTrue(all('--name' in command for command in calls))

    def test_infra_retry_preserves_all_attempts_and_stays_flaky(self):
        count = 0
        def process(command, env, output, **kwargs):
            nonlocal count
            count += 1
            receipt = self.process(command, env, output, **kwargs)
            if count == 1:
                receipt['exit_code'] = 137
                receipt['lines'] = events(done=False)
                Path(receipt['machine']).write_text('\n'.join(receipt['lines']) + '\n')
                runner._persist_process_receipt(receipt, output)
            return receipt
        with self.mock_execution(process):
            summary = runner.run_plan(self.root, plan(instance()), self.output, max_infra_attempts=3)
        self.assertEqual(count, 2)
        self.assertEqual(summary['results'][0]['status'], 'FLAKY')
        self.assertEqual(len(summary['results'][0]['attempts']), 2)
        self.assertNotEqual(summary['exit_code'], 0)

    def test_assertion_failure_never_retried(self):
        count = 0
        def process(command, env, output, **kwargs):
            nonlocal count
            count += 1
            receipt = self.process(command, env, output, **kwargs)
            receipt.update(exit_code=1, lines=events(passed=0, fail=True, done=False))
            Path(receipt['machine']).write_text('\n'.join(receipt['lines']) + '\n')
            return runner._persist_process_receipt(receipt, output)
        with self.mock_execution(process):
            summary = runner.run_plan(self.root, plan(instance()), self.output, max_infra_attempts=3)
        self.assertEqual(count, 1)
        self.assertEqual(summary['status'], 'FAIL')

    def test_worker_dependency_failure_prevents_process(self):
        with self.mock_execution(self.process), patch.object(runner, 'execute_process') as execute:
            summary = runner.run_plan(self.root, plan(instance()), self.output,
                                      worker_platform='linux', upstream={'sdk': 'failure'})
        execute.assert_not_called()
        self.assertEqual(summary['results'][0]['reason_code'], 'UPSTREAM_FAILED')

    def test_failed_aggregate_blocks_summary_even_with_all_child_receipts_passed(self):
        from auto_test_lib.execution_gates import merge_gate_statuses
        gates = ['static-analysis', 'framework', 'sqlite-generator']
        declared = plan(instance(), gates=gates)
        row = self.result(planned=declared)
        upstream = merge_gate_statuses({name: {'status': 'PASS'} for name in gates},
                                       {'quality-gates': 'failure'})
        self.assertTrue(all(upstream[name] == 'PASS' for name in gates))
        report = runner.reconcile(declared, [row], upstream=upstream)
        self.assertEqual(report['reason_code'], 'UPSTREAM_FAILED')
        self.assertNotEqual(report['exit_code'], 0)
        self.assertEqual(report['upstream_failed'], [{'dependency': 'quality-gates', 'status': 'failure'}])

    def test_changed_source_blocks_stale_plan(self):
        a = instance(source_sha256=hashlib.sha256(b'old content').hexdigest())
        with self.mock_execution(self.process), patch.object(runner, 'execute_process') as execute:
            summary = runner.run_plan(self.root, plan(a), self.output)
        execute.assert_not_called()
        self.assertEqual(summary['results'][0]['reason_code'], 'STALE_PLAN')

    def test_source_mutation_during_execution_blocks_without_discarding_attempts(self):
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True, capture_output=True)
        subprocess.run(['git', '-C', str(self.root), 'add', 'test/a_test.dart'], check=True, capture_output=True)
        target = self.root / 'test/a_test.dart'
        spec = instance(source_sha256=runner._file_sha256(target))
        def changing_process(command, env, output, **kwargs):
            receipt = self.process(command, env, output, **kwargs)
            target.write_text('// changed while synthetic process was running\n')
            return receipt
        with self.mock_execution(changing_process):
            summary = runner.run_plan(self.root, plan(spec), self.output)
        row = summary['results'][0]
        self.assertEqual(row['reason_code'], 'SOURCE_CHANGED_DURING_RUN')
        self.assertEqual(row['source_changes']['targets'], ['test/a_test.dart'])
        self.assertEqual(len(row['attempts']), 1)
        self.assertEqual(row['attempts'][0]['parsed']['test_status'], 'PASS')
        self.assertTrue(Path(row['attempts'][0]['evidence']).is_file())
        self.assertEqual(summary['exit_code'], 2)

    def test_full_source_snapshot_is_rechecked_after_execution(self):
        with self.mock_execution(self.process), patch.object(runner, '_check_snapshot',
                side_effect=[None, 'STALE_PLAN']) as check:
            summary = runner.run_plan(self.root, plan(instance()), self.output)
        self.assertEqual(check.call_count, 2)
        self.assertEqual(summary['results'][0]['reason_code'], 'SOURCE_CHANGED_DURING_RUN')
        self.assertTrue(summary['results'][0]['source_changes']['snapshot_changed'])

    def test_coordinated_device_uses_shared_callback_and_requires_both_receipts(self):
        spec = instance(runner='flutter-device', suite='device-single', orchestration='mc-owned-coordinator')
        def coordinated(root, item, env, output, execute):
            row = execute(item, {'command': ['flutter', 'test', item['target'], '--machine', '--no-pub'],
                                 'env': env, 'log_path': str(output / 'process.log')})
            gate = {'kind': 'coordinator-gate', 'status': 'PASS', 'exit_code': 0, 'mode': 'live',
                    'command': ['python', 'synthetic-coordinator.py'], 'context_sha256': 'a' * 64, 'hashes': {}}
            for key in ('log', 'evidence', 'process_receipt'):
                path = output / (key + '.fixture')
                path.write_text('synthetic coordinator ' + key)
                gate[key], gate['hashes'][key] = str(path), runner._file_sha256(path)
            row['companion_evidence'] = gate
            return row
        with self.mock_execution(self.process), patch.object(adapters, 'run_coordinated',
                side_effect=coordinated, create=True) as adapter:
            summary = runner.run_plan(self.root, plan(spec), self.output)
        adapter.assert_called_once()
        self.assertEqual(summary['status'], 'PASS')
        self.assertTrue(summary['results'][0]['attempts'][0]['process_receipt'])
        row = summary['results'][0]
        for companion in (None, {'kind': 'coordinator-gate', 'status': 'FAIL', 'exit_code': 1},
                          {'kind': 'coordinator-gate', 'status': 'PASS', 'exit_code': 137}):
            altered = copy.deepcopy(row)
            altered['companion_evidence'] = companion
            self.assertNotEqual(runner.reconcile(plan(spec), [altered])['exit_code'], 0)
        for field, value in [('command', []), ('log', None), ('hashes', {}), ('context_sha256', '')]:
            altered = copy.deepcopy(row)
            altered['companion_evidence'][field] = value
            self.assertNotEqual(runner.reconcile(plan(spec), [altered])['exit_code'], 0)
        altered = copy.deepcopy(row)
        altered['attempts'][0]['process_exit_code'] = 1
        self.assertNotEqual(runner.reconcile(plan(spec), [altered])['exit_code'], 0)

    def test_coordinated_device_missing_result_cannot_fall_back_to_single_run(self):
        spec = instance(runner='flutter-device', suite='device-single', orchestration='mc-owned-coordinator')
        with self.mock_execution(self.process), patch.object(adapters, 'run_coordinated',
                return_value={'reason_code': 'MISSING_RESULT'}, create=True), \
                patch.object(runner, 'execute_process') as execute:
            summary = runner.run_plan(self.root, plan(spec), self.output)
        execute.assert_not_called()
        self.assertEqual(summary['results'][0]['reason_code'], 'MISSING_RESULT')

    def test_invocation_revalidation_errors_block_before_spawning(self):
        for name in ('flutter-machine', 'flutter-device'):
            with self.subTest(runner=name), self.mock_execution(self.process), \
                    patch.object(adapters, 'build_invocation', return_value={'errors': ['lease changed']}), \
                    patch.object(runner, 'execute_process') as execute:
                summary = runner.run_plan(self.root, plan(instance(runner=name)), self.output)
            execute.assert_not_called()
            self.assertEqual(summary['results'][0]['reason_code'], 'ENV_MISSING')
            self.assertEqual(summary['results'][0]['environment_missing'], ['lease changed'])

    def test_shared_device_callback_rejects_lease_drift(self):
        spec = instance(runner='flutter-device', suite='device-single', orchestration='mc-owned-coordinator')
        def coordinated(root, item, env, output, execute):
            return execute(item, {'errors': ['active lease drifted']})
        with self.mock_execution(self.process), patch.object(adapters, 'run_coordinated',
                side_effect=coordinated, create=True), patch.object(runner, 'execute_process') as execute:
            summary = runner.run_plan(self.root, plan(spec), self.output)
        execute.assert_not_called()
        self.assertEqual(summary['results'][0]['reason_code'], 'ENV_MISSING')
        self.assertEqual(summary['results'][0]['environment_missing'], ['active lease drifted'])

    def test_pair_dispatch_is_never_a_normal_single_device_loop(self):
        items = [instance(role=role, runner='device-pair', suite='device-pair', pair_group='pair') for role in ('sender', 'receiver')]
        def pair_run(root, instances, env, output, execute):
            return {i['id']: {'status': 'BLOCKED', 'reason_code': 'ENV_MISSING', 'errors': ['synthetic missing peer']} for i in instances}
        with self.mock_execution(self.process), patch.object(adapters, 'run_pair', side_effect=pair_run) as pairs, patch.object(runner, 'execute_process') as execute:
            summary = runner.run_plan(self.root, plan(*items), self.output, worker_suites=['device-pair'])
        pairs.assert_called_once()
        execute.assert_not_called()
        self.assertEqual(len(summary['results']), 2)

    def test_partial_platform_pair_cannot_execute(self):
        items = [instance(platform=p, role=r, runner='device-pair', suite='device-pair', pair_group='pair')
                 for p, r in [('linux', 'sender'), ('macos', 'receiver')]]
        with self.mock_execution(self.process), patch.object(adapters, 'run_pair') as pairs:
            summary = runner.run_plan(self.root, plan(*items), self.output, worker_platform='linux')
        pairs.assert_not_called()
        self.assertEqual(summary['results'][0]['reason_code'], 'UPSTREAM_FAILED')

    def test_saved_source_fingerprint_uses_catalog_build_plan_contract(self):
        declared = plan(instance(), source_fingerprint='catalog-hash', selectors={'platforms': ['linux']})
        with patch('auto_test_lib.execution_catalog.build_plan', return_value=declared) as builder:
            self.assertIsNone(runner._check_snapshot(self.root, declared))
        builder.assert_called_once_with(self.root, profile='pr', platforms=['linux'])

    def test_product_claim_requires_verified_artifact_fingerprint(self):
        i = instance(product='phase1', product_contract={'manifest_profile': 'phase1'})
        declared = plan(i)
        row = self.result(i, planned=declared)
        summary = runner.reconcile(declared, [row])
        self.assertEqual(summary['results'][0]['reason_code'], 'PRODUCT_EVIDENCE_MISSING')

    def test_coverage_merge_deduplicates_lines_with_maximum_hits(self):
        files = []
        for index, text in enumerate(('DA:1,2\nDA:2,0', 'DA:1,3\nDA:2,1')):
            path = self.root / f'{index}.info'
            path.write_text('SF:lib/a.dart\n' + text + '\nend_of_record\n')
            files.append(str(path))
        destination = self.root / 'merged.info'
        runner.merge_coverage_files(files, destination)
        self.assertEqual(destination.read_text().count('DA:1,'), 1)
        self.assertIn('DA:1,3', destination.read_text())
        self.assertIn('LF:2\nLH:2', destination.read_text())

    def test_tooling_protocol_isolated_from_nested_machine_looking_output(self):
        target = self.root / 'test_nested.py'
        nested_event = json.dumps({'type': 'testDone', 'testID': 99, 'result': 'failure'})
        child_source = 'print(' + repr(nested_event) + ')'
        target.write_text('import unittest, subprocess, sys\nclass Demo(unittest.TestCase):\n'
                          ' def test_one(self):\n'
                          '  print(\'{"type":"done","success":false}\')\n'
                          '  subprocess.run([sys.executable, "-c", ' + repr(child_source) + '], check=True)\n'
                          '  self.assertEqual(2 + 2, 4)\n')
        env = dict(os.environ, PYTHONPATH=str(REPO_ROOT / 'scripts'))
        receipt = runner.execute_process([sys.executable, '-m', 'auto_test_lib.execution_runner',
                                          '--tooling', 'python-unittest', str(target)], env,
                                         self.output, cwd=REPO_ROOT, separate_stderr=True)
        parsed = parse_machine_events(receipt['lines'], receipt['exit_code'])
        self.assertEqual(parsed.test_status, 'PASS', receipt)
        self.assertEqual(parsed.executed, 1)
        self.assertIn('"success":false', Path(receipt['log']).read_text())
        self.assertNotIn('"success":false', Path(receipt['machine']).read_text())
        self.assertIn(nested_event, Path(receipt['log']).read_text())
        self.assertNotIn(nested_event, Path(receipt['machine']).read_text())

    @unittest.skipUnless(os.name == 'posix', 'owned process-group execution requires POSIX')
    def test_timeout_stops_descendants_and_preserves_partial_evidence(self):
        for separate in (False, True):
            with self.subTest(separate_stderr=separate):
                output = self.output / str(separate)
                release = self.root / f'release-{separate}'
                late = self.root / f'late-{separate}'
                child = (
                    'import signal,sys,time\nfrom pathlib import Path\n'
                    'signal.signal(signal.SIGTERM, signal.SIG_IGN)\n'
                    'print("descendant ready", file=sys.stderr, flush=True)\n'
                    'deadline=time.monotonic()+8\n'
                    f'while not Path({str(release)!r}).exists() and time.monotonic()<deadline: time.sleep(0.01)\n'
                    f'if Path({str(release)!r}).exists():\n'
                    ' print("late stdout", flush=True)\n'
                    ' print("late stderr", file=sys.stderr, flush=True)\n'
                    f' Path({str(late)!r}).write_text("descendant survived")\n'
                )
                partial = '\n'.join(events(passed=2, skipped=1, done=False))
                parent = (
                    'import signal,subprocess,sys,time\n'
                    'signal.signal(signal.SIGTERM, signal.SIG_IGN)\n'
                    f'subprocess.Popen([sys.executable,"-c",{child!r}])\n'
                    f'print({partial!r},flush=True)\n'
                    'time.sleep(8)\n'
                )
                # This unrelated process must survive another invocation's timeout.
                with subprocess.Popen([sys.executable, '-c', 'import sys; sys.stdin.read()'],
                                      stdin=subprocess.PIPE, stdout=subprocess.DEVNULL,
                                      stderr=subprocess.DEVNULL) as sentinel:
                    try:
                        started = time.monotonic()
                        receipt = runner.execute_process([sys.executable, '-c', parent],
                            dict(os.environ), output, timeout=2, separate_stderr=separate)
                        self.assertLess(time.monotonic() - started, 6, 'TERM-ignoring children delayed cleanup')
                        self.assertIsNone(sentinel.poll())
                        self.assertEqual(receipt['exit_code'], 124)
                        self.assertEqual(receipt['error'], 'RUNNER_TIMEOUT')
                        self.assertIn('descendant ready', Path(receipt['log']).read_text())
                        parsed = parse_machine_events(receipt['lines'], receipt['exit_code'])
                        self.assertEqual((parsed.executed, parsed.skipped, parsed.actually_run), (3, 1, 2))
                        self.assertFalse(parsed.done_event_seen)
                        self.assertEqual(parsed.test_status, 'BLOCKED')
                        release.touch()
                        # A surviving child was instructed to write both streams
                        # only after the receipt; the original implementation did.
                        deadline = time.monotonic() + 0.5
                        while time.monotonic() < deadline and not late.exists():
                            time.sleep(0.01)
                        self.assertFalse(late.exists(), 'timed-out descendant still ran')
                        for key in ('log', 'machine'):
                            self.assertEqual(runner._file_sha256(receipt[key]), receipt[key + '_sha256'])
                            self.assertNotIn('late ', Path(receipt[key]).read_text())
                    finally:
                        release.touch()
                        sentinel.stdin.close()
                        sentinel.wait(timeout=5)

    @unittest.skipUnless(os.name == 'posix', 'owned process-group execution requires POSIX')
    def test_custom_process_log_remains_visible_while_command_runs(self):
        live = self.output / 'receiver' / 'process.log'
        release = self.root / 'release-live'
        source = (
            'import time\nfrom pathlib import Path\n'
            'print("receiver ready",flush=True)\n'
            'deadline=time.monotonic()+5\n'
            f'while not Path({str(release)!r}).exists() and time.monotonic()<deadline: time.sleep(0.01)\n'
            f'print({chr(10).join(events())!r},flush=True)\n'
        )
        with ThreadPoolExecutor(max_workers=1) as pool:
            future = pool.submit(runner.execute_process, [sys.executable, '-c', source],
                                 dict(os.environ), self.output, log_path=live, timeout=5)
            try:
                deadline = time.monotonic() + 3
                while time.monotonic() < deadline and not future.done():
                    if live.is_file() and 'receiver ready' in live.read_text():
                        break
                    time.sleep(0.01)
                self.assertIn('receiver ready', live.read_text())
                self.assertFalse(future.done())
            finally:
                release.touch()
            receipt = future.result(timeout=5)
        self.assertEqual(receipt['log'], str(live))
        self.assertEqual(receipt['exit_code'], 0)
        self.assertEqual(parse_machine_events(receipt['lines'], 0).test_status, 'PASS')

    def test_unavailable_process_supervision_blocks_before_spawning(self):
        with patch.object(runner, 'os', wraps=os) as unavailable, \
                patch.object(runner.subprocess, 'Popen') as process:
            unavailable.name = 'nt'
            receipt = runner.execute_process(['unused-command'], dict(os.environ), self.output)
        process.assert_not_called()
        self.assertEqual(receipt['exit_code'], 127)
        self.assertIn('PROCESS_SUPERVISION_UNAVAILABLE', receipt['error'])
        self.assertEqual(parse_machine_events(receipt['lines'], receipt['exit_code']).test_status, 'BLOCKED')


    def test_kill_replay_target_routes_only_to_its_coordinator(self):
        spec = instance(adapters.KILL_REPLAY_TARGET, platform='android', suite='device-single',
                        runner='flutter-device', orchestration='sqlite-kill-replay')
        with self.mock_execution(self.process), \
                patch.object(adapters, 'run_kill_replay', return_value={
                    'reason_code': 'ENV_MISSING', 'errors': ['synthetic missing device']}) as coordinator, \
                patch.object(runner, 'execute_process') as process:
            summary = runner.run_plan(self.root, plan(spec), self.output)
        coordinator.assert_called_once()
        process.assert_not_called()
        self.assertEqual('ENV_MISSING', summary['results'][0]['reason_code'])
        self.assertIs(coordinator.call_args.kwargs['execute_process'], process)

    def test_successful_kill_verify_requires_its_interruption_companion(self):
        spec = instance(adapters.KILL_REPLAY_TARGET, platform='android', suite='device-single',
                        runner='flutter-device', orchestration='sqlite-kill-replay')
        target = self.root / spec['target']
        target.parent.mkdir(parents=True)
        target.write_text('// isolated synthetic target\n')
        row = self.result(spec)
        result = runner.reconcile(plan(spec), [row])['results'][0]
        self.assertEqual('MISSING_COMPANION_EVIDENCE', result['reason_code'])
        row['companion_evidence'] = {'status': 'PASS', 'kind': 'coordinator-gate'}
        self.assertEqual('INCOMPLETE_COMPANION_EVIDENCE',
                         runner.reconcile(plan(spec), [row])['results'][0]['reason_code'])

    @unittest.skipUnless(os.name == 'posix', 'owned process-group execution requires POSIX')
    def test_observed_interruption_stops_owned_descendants_and_freezes_partial_evidence(self):
        release, late = self.root / 'release-observed', self.root / 'late-observed'
        child = ('import signal,time\nfrom pathlib import Path\n'
                 'signal.signal(signal.SIGTERM,signal.SIG_IGN)\n'
                 'print("child ready",flush=True)\n'
                 f'while not Path({str(release)!r}).exists(): time.sleep(0.01)\n'
                 f'Path({str(late)!r}).write_text("orphan survived")\n')
        source = ('import subprocess,sys,time\n'
                  f'subprocess.Popen([sys.executable,"-c",{child!r}])\n'
                  'print("prepare ready",flush=True)\n'
                  'time.sleep(8)\n')
        def observe(path):
            return 'KILL_REPLAY_INTERRUPTED' if 'child ready' in path.read_text() and 'prepare ready' in path.read_text() else None
        with subprocess.Popen([sys.executable, '-c', 'import sys;sys.stdin.read()'], stdin=subprocess.PIPE) as sentinel:
            try:
                receipt = runner.execute_process([sys.executable, '-c', source], dict(os.environ),
                    self.output, timeout=3, observer=observe)
                self.assertEqual((130, 'KILL_REPLAY_INTERRUPTED'), (receipt['exit_code'], receipt['error']))
                self.assertIsNone(sentinel.poll())
                self.assertNotEqual('PASS', parse_machine_events(receipt['lines'], 130).test_status)
                release.touch()
                time.sleep(0.15)
                self.assertFalse(late.exists())
                self.assertEqual(receipt['machine_sha256'], runner._file_sha256(receipt['machine']))
                self.assertIn('prepare ready', Path(receipt['machine']).read_text())
            finally:
                release.touch()
                sentinel.stdin.close()
                sentinel.wait(timeout=3)


if __name__ == '__main__':
    unittest.main()
