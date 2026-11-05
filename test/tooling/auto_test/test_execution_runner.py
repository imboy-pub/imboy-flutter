"""Governance tests use synthetic streams, temporary repos, and fake adapters."""
from __future__ import annotations

import contextlib
import copy
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / 'scripts'))
from auto_test_lib import execution_adapters as adapters
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
        self.root = Path(self.temporary.name)
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
                   'command': ['flutter', 'test', spec['target'], '--machine']}
        runner._persist_process_receipt(receipt, output)
        attempt = runner._record_attempt(self.root, planned, spec, receipt, lines)
        return runner._finish(planned, spec, [attempt])

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
             'command': list(command)}, output)

    def test_success_requires_matching_receipt_for_every_instance(self):
        a, b = instance(), instance('test/b_test.dart')
        declared = plan(a, b)
        good = [self.result(i, planned=declared) for i in (a, b)]
        self.assertEqual(runner.reconcile(declared, good)['status'], 'PASS')
        missing = runner.reconcile(declared, good[:1])
        self.assertEqual(missing['status'], 'BLOCKED')
        self.assertEqual(missing['results'][1]['reason_code'], 'MISSING_RESULT')

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
        spec = instance(runner='python-cases', dependencies=['process-identity'])
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
        receipt = {'exit_code': 0, 'log': str(log), 'machine': str(log), 'command': ['patrol', 'test']}
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
            fingerprint = runner._fingerprint(self.root, plan(instance()), instance(dependencies=[dependency]))
            self.assertEqual(fingerprint['backend_head'], 'UNVERIFIED_SERVICE_VERSION')
        fingerprint = runner._fingerprint(self.root, plan(instance()), instance(dependencies=['backend-source']))
        self.assertEqual(fingerprint['backend_head'], 'UNVERIFIED_SOURCE_VERSION')

    def test_host_adapter_command_preserves_no_pub(self):
        with self.mock_execution(self.process), contextlib.ExitStack() as stack:
            command, _, _ = runner._host_command(self.root, [instance()], {}, self.output, stack, adapters)
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


if __name__ == '__main__':
    unittest.main()
