"""Preflight composes existing gates; it must never report product PASS."""
import copy
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'scripts'))
from auto_test_lib import acceptance_preflight, acceptance_execution


class PreflightTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        case = {'case_id': 'synthetic-1', 'platform': 'android', 'profile': 'enabled',
                'role_variant': 'sender', 'parent_acceptance_ids': ['F03-A01'],
                'seed_ids': ['synthetic-seed'], 'oracle': 'synthetic only',
                'applicability': 'REQUIRED', 'cross_device_journey_ids': []}
        bindings = []
        for kind in ['source', 'config', 'build', 'fixture', 'device']:
            bindings.append({'binding_id': kind, 'kind': kind,
                             'artifact': self.descriptor(kind, {'synthetic': kind})})
        self.frozen = {'schema_version': 2, 'acceptance_ids': ['F03-A01'],
                       'runtime_bindings': bindings,
                       'required_runtime_binding_ids': [r['binding_id'] for r in bindings],
                       'required_cases': [case], 'candidates': {}}
        self.report = {'required_cases': [case], 'candidates': {},
                       'runtime_bindings': copy.deepcopy(bindings)}
        attempts = [{'attempt_id': 'synthetic-red', 'exit': 1},
                    {'attempt_id': 'synthetic-green', 'exit': 0}]
        self.frozen['attempt_index'] = [
            {'attempt_id': row['attempt_id'], 'record_sha256': hashlib.sha256(
                json.dumps(row, sort_keys=True, ensure_ascii=False, allow_nan=False,
                           separators=(',', ':')).encode()).hexdigest()}
            for row in attempts]
        self.report['attempts'] = attempts

    def descriptor(self, path, value):
        data = json.dumps(value).encode()
        (self.root / path).write_bytes(data)
        return {'path': path, 'sha256': hashlib.sha256(data).hexdigest()}

    def audit(self):
        # Candidate gate has separate real-Git tests. This is composition only.
        with patch('auto_test_lib.acceptance_contract.audit_candidate_repositories',
                   return_value=[]) as candidate:
            result = acceptance_preflight.audit_preparation_inputs(
                self.root, self.descriptor('frozen.json', self.frozen),
                self.descriptor('report.json', self.report), {})
            return result, candidate

    def test_success_never_becomes_product_pass(self):
        result, candidate = self.audit()
        self.assertEqual(result['errors'], [])
        self.assertEqual(result['scope'], 'PREPARATION_INPUTS_ONLY')
        self.assertIs(result['product_pass'], False)
        self.assertTrue(result['remaining_gates'])
        candidate.assert_called_once()

    def test_missing_required_input_is_failure(self):
        del self.frozen['acceptance_ids']
        result, _ = self.audit()
        self.assertTrue(result['errors'])

    def test_dropped_case_is_failure(self):
        self.report['required_cases'] = []
        result, _ = self.audit()
        self.assertTrue(result['errors'])

    def test_legacy_schema_cannot_bypass_runtime_bindings(self):
        self.frozen['schema_version'] = 1
        self.assertIn('PREPARATION_INPUT_SCHEMA_INVALID', self.audit()[0]['errors'])

    def test_missing_or_changed_runtime_binding_fails_composition(self):
        self.report['runtime_bindings'].pop()
        self.assertIn('RUNTIME_BINDING_MISSING', self.audit()[0]['errors'])
        self.report['runtime_bindings'] = copy.deepcopy(self.frozen['runtime_bindings'])
        self.report['runtime_bindings'][2]['artifact']['sha256'] = '0' * 64
        self.assertIn('FROZEN_RUNTIME_BINDING_CHANGED', self.audit()[0]['errors'])

    def test_actual_runtime_file_drift_fails_composition(self):
        (self.root / 'config').write_text('modified synthetic config')
        self.assertTrue(any('HASH_MISMATCH' in error
                            for error in self.audit()[0]['errors']))

    def test_missing_attempt_index_or_report_cannot_bypass_gate(self):
        index = self.frozen.pop('attempt_index')
        self.assertIn('FROZEN_ATTEMPT_INDEX_INVALID', self.audit()[0]['errors'])
        self.frozen['attempt_index'] = index
        del self.report['attempts']
        self.assertIn('ATTEMPT_JOURNAL_SCHEMA_INVALID', self.audit()[0]['errors'])

    def test_discarding_failed_attempt_is_rejected(self):
        self.report['attempts'] = self.report['attempts'][1:]
        self.assertIn('ATTEMPT_HISTORY_MISSING_UNKNOWN_OR_REORDERED',
                      self.audit()[0]['errors'])

    def test_rewriting_failed_attempt_is_rejected(self):
        self.report['attempts'][0]['exit'] = 0
        self.assertIn('FROZEN_ATTEMPT_RECORD_CHANGED', self.audit()[0]['errors'])

    def test_non_object_schema_rejected(self):
        self.frozen = []
        self.assertTrue(self.audit()[0]['errors'])

    def test_wrong_hash_stops_before_candidate_checks(self):
        descriptor = self.descriptor('frozen.json', self.frozen)
        descriptor['sha256'] = 'a' * 64
        result = acceptance_preflight.audit_preparation_inputs(
            self.root, descriptor, self.descriptor('report.json', self.report), {})
        self.assertTrue(result['errors'])

    def test_existing_runner_cli_returns_nonzero_fixed_code_json(self):
        self.descriptor('frozen.json', self.frozen)
        report = self.descriptor('report.json', self.report)
        script = Path(__file__).resolve().parents[3] / 'scripts' / 'auto_test.py'
        completed = subprocess.run([
            sys.executable, str(script), 'acceptance-preflight',
            '--evidence-root', str(self.root), '--frozen-input', 'frozen.json',
            '--frozen-sha256', 'a' * 64, '--acceptance-report', 'report.json',
            '--report-sha256', report['sha256'],
        ], capture_output=True, text=True, timeout=10)
        self.assertEqual(completed.returncode, 2)
        result = json.loads(completed.stdout)
        self.assertIs(result['product_pass'], False)
        self.assertTrue(result['errors'])

    def execution_audit(self):
        with patch('auto_test_lib.acceptance_contract.audit_candidate_repositories',
                   return_value=[]):
            return acceptance_execution.audit_execution_inputs(
                self.root, self.descriptor('frozen.json', self.frozen),
                self.descriptor('report.json', self.report), {})

    def prepare_event_run(self):
        self.frozen['cross_device_journeys'] = []
        self.report['cross_device_records'] = {}
        case = self.frozen['required_cases'][0]
        binding = {key: case[key] for key in
                   ('case_id', 'platform', 'profile', 'role_variant')}
        binding['test_name'] = 'synthetic case'
        events = [{'type': 'start'}, {'type': 'testStart',
                  'test': {'id': 1, 'name': 'synthetic case'}},
                  {'type': 'testDone', 'testID': 1, 'result': 'success'},
                  {'type': 'done', 'success': True}]
        data = '\n'.join(json.dumps(e) for e in events).encode()
        (self.root / 'events.jsonl').write_bytes(data)
        self.frozen['case_event_runs'] = [{'required_cases': [copy.deepcopy(case)],
            'case_event_bindings': [binding], 'process_exit_code': 0,
            'event_artifact': {'path': 'events.jsonl', 'sha256':
                               hashlib.sha256(data).hexdigest()}}]
        run = self.frozen['case_event_runs'][0]
        run['attempt_id'] = 'synthetic-green'
        record = self.report['attempts'][1]
        record.update(events='events.jsonl', events_sha256=run['event_artifact']['sha256'],
                      exit_code=0, parsed={'test_status': 'PASS', 'executed': 1,
                                           'failed': 0, 'skipped': 0})
        self.frozen['attempt_index'] = [
            {'attempt_id': row['attempt_id'], 'record_sha256': hashlib.sha256(
                json.dumps(row, sort_keys=True, ensure_ascii=False, allow_nan=False,
                           separators=(',', ':')).encode()).hexdigest()}
            for row in self.report['attempts']]
        self.frozen['coverage_inputs'] = [
            {'input_kind': kind, 'input_id': 'synthetic-' + kind}
            for kind in ['seed', 'generated', 'page', 'api', 'ws', 'admin']]
        self.frozen['approved_dispositions'] = []
        key = [case[field] for field in ('case_id', 'platform', 'profile', 'role_variant')]
        self.report['coverage_mappings'] = [
            dict(row, owner='/root', source_refs=['synthetic.dart:1'],
                 disposition='CASE_MAPPED', case_keys=[key])
            for row in self.frozen['coverage_inputs']]

    def test_execution_composition_requires_raw_run_index(self):
        self.assertIn('FROZEN_CASE_EVENT_RUNS_INVALID', self.execution_audit()['errors'])
        self.prepare_event_run()
        result = self.execution_audit()
        self.assertEqual(result['errors'], [])
        self.assertIs(result['product_pass'], False)
        self.assertEqual(result['scope'], 'EXECUTION_RECORD_INPUTS_ONLY')

    def test_execution_requires_explicit_journey_obligations_and_records(self):
        self.prepare_event_run()
        del self.frozen['cross_device_journeys']
        self.assertIn('FROZEN_JOURNEY_SET_INVALID', self.execution_audit()['errors'])
        self.frozen['cross_device_journeys'] = []
        del self.report['cross_device_records']
        self.assertIn('JOURNEY_RECORDED_SET_MISMATCH', self.execution_audit()['errors'])

    def test_execution_cli_checks_journey_inputs_without_writing(self):
        self.prepare_event_run()
        del self.frozen['cross_device_journeys']
        frozen = self.descriptor('frozen.json', self.frozen)
        report = self.descriptor('report.json', self.report)
        before = {p.name: p.read_bytes() for p in self.root.iterdir()}
        script = Path(__file__).resolve().parents[3] / 'scripts' / 'auto_test.py'
        completed = subprocess.run([
            sys.executable, str(script), 'acceptance-execution-preflight',
            '--evidence-root', str(self.root), '--frozen-input', 'frozen.json',
            '--frozen-sha256', frozen['sha256'], '--acceptance-report', 'report.json',
            '--report-sha256', report['sha256'],
        ], capture_output=True, text=True, timeout=10)
        self.assertEqual(2, completed.returncode)
        result = json.loads(completed.stdout)
        self.assertIn('FROZEN_JOURNEY_SET_INVALID', result['errors'])
        self.assertIs(False, result['product_pass'])
        self.assertEqual(before, {p.name: p.read_bytes() for p in self.root.iterdir()})

    def test_execution_composition_rejects_duplicate_case_run_or_log(self):
        self.prepare_event_run()
        duplicate = copy.deepcopy(self.frozen['case_event_runs'][0])
        self.frozen['case_event_runs'].append(duplicate)
        self.assertTrue(self.execution_audit()['errors'])
        duplicate['event_artifact']['path'] = 'another.jsonl'
        self.assertIn('CASE_EVENT_CONTENT_REUSED_OR_INVALID', self.execution_audit()['errors'])
        duplicate['event_artifact']['sha256'] = '0' * 64
        self.assertIn('CASE_EVENT_KEY_ASSIGNED_MULTIPLE_RUNS',
                      self.execution_audit()['errors'])

    def test_execution_composition_rejects_changed_case_obligation(self):
        self.prepare_event_run()
        self.frozen['case_event_runs'][0]['required_cases'][0]['oracle'] = 'changed'
        self.assertIn('CASE_EVENT_RUN_COVERAGE_OR_OBLIGATION_MISMATCH',
                      self.execution_audit()['errors'])

    def test_execution_composition_rejects_bad_exit_and_dropped_failure(self):
        self.prepare_event_run()
        for value in [1, False, '0', None]:
            self.frozen['case_event_runs'][0]['process_exit_code'] = value
            self.assertIn('CASE_EVENT_PROCESS_EXIT_NOT_ZERO',
                          self.execution_audit()['errors'])
        self.frozen['case_event_runs'][0]['process_exit_code'] = 0
        self.report['attempts'] = self.report['attempts'][1:]
        self.assertIn('ATTEMPT_HISTORY_MISSING_UNKNOWN_OR_REORDERED',
                      self.execution_audit()['errors'])

    def test_raw_log_cannot_attach_to_unknown_or_unrelated_attempt(self):
        self.prepare_event_run()
        run = self.frozen['case_event_runs'][0]
        run['attempt_id'] = 'unknown'
        self.assertIn('CASE_EVENT_ATTEMPT_MISSING_UNKNOWN_OR_REUSED',
                      self.execution_audit()['errors'])
        run['attempt_id'] = 'synthetic-red'
        self.assertIn('CASE_EVENT_ATTEMPT_ARTIFACT_MISMATCH', self.execution_audit()['errors'])

    def test_attempt_link_rejects_metadata_mismatch_even_with_pinned_record(self):
        self.prepare_event_run()
        original = copy.deepcopy(self.report['attempts'])
        variants = [('events', 'other.jsonl', 'CASE_EVENT_ATTEMPT_ARTIFACT_MISMATCH'),
                    ('events_sha256', '0' * 64, 'CASE_EVENT_ATTEMPT_ARTIFACT_MISMATCH'),
                    ('exit_code', False, 'CASE_EVENT_ATTEMPT_EXIT_NOT_ZERO'),
                    ('parsed', {'test_status': 'FAIL'}, 'CASE_EVENT_ATTEMPT_NOT_PASS'),
                    ('parsed', {'test_status': 'PASS', 'executed': True,
                                'failed': 0, 'skipped': 0}, 'CASE_EVENT_ATTEMPT_COUNTS_MISMATCH')]
        for key, value, expected in variants:
            records = copy.deepcopy(original)
            records[1][key] = value
            self.assertIn(expected, acceptance_execution.audit_run_attempt_links(
                self.frozen['case_event_runs'], records))

    def test_one_attempt_cannot_supply_multiple_raw_runs(self):
        self.prepare_event_run()
        runs = self.frozen['case_event_runs'] * 2
        self.assertIn('CASE_EVENT_ATTEMPT_MISSING_UNKNOWN_OR_REUSED',
                      acceptance_execution.audit_run_attempt_links(runs, self.report['attempts']))

    def test_execution_coverage_cannot_omit_inputs_or_report_mappings(self):
        self.prepare_event_run()
        inputs = self.frozen.pop('coverage_inputs')
        self.assertTrue(self.execution_audit()['errors'])
        self.frozen['coverage_inputs'] = inputs
        self.report['coverage_mappings'].pop()
        self.assertIn('COVERAGE_INPUT_MISSING', self.execution_audit()['errors'])

    def test_execution_coverage_cannot_self_approve_disposal(self):
        self.prepare_event_run()
        self.report['coverage_mappings'][0].update(
            disposition='DELETED', case_keys=[], approval_ref='worker-self-signed')
        self.assertIn('COVERAGE_DISPOSITION_NOT_IN_FROZEN_APPROVALS',
                      self.execution_audit()['errors'])


if __name__ == '__main__':
    unittest.main()
