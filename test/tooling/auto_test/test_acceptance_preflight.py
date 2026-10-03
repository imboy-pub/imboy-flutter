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
from auto_test_lib import acceptance_preflight


class PreflightTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        case = {'case_id': 'synthetic-1', 'platform': 'android', 'profile': 'enabled',
                'role_variant': 'sender', 'parent_acceptance_ids': ['F03-A01'],
                'seed_ids': ['synthetic-seed'], 'oracle': 'synthetic only',
                'applicability': 'REQUIRED'}
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


if __name__ == '__main__':
    unittest.main()
