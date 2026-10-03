"""Synthetic matrix/delegation checks, never device or product qualification."""
import copy
import hashlib
import json
import sys
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'scripts'))
from auto_test_lib import acceptance_navigation_profiles as gate


class NavigationProfileCompositionTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.cases = []
        self.runs = []
        for platform in ('android', 'macos'):
            for profile in ('enabled', 'disabled'):
                case = dict(case_id='bottom-navigation-channel', platform=platform,
                            profile=profile, role_variant='primary',
                            parent_acceptance_ids=['F14-A02' if platform == 'android' else 'F14-A03'],
                            seed_ids=[gate.FUNCTION_ID], oracle='Actual profile, tabs and pages',
                            applicability='REQUIRED')
                self.cases.append(case)
                binding = {key: case[key] for key in gate.KEY_FIELDS}
                binding['test_name'] = gate.test_name(platform, profile)
                self.runs.append(dict(required_cases=[copy.deepcopy(case)],
                                      case_event_bindings=[binding]))
        self.frozen = dict(required_cases=self.cases, case_event_runs=self.runs)

    def audit(self, frozen=None, execution_errors=None):
        data = json.dumps(self.frozen if frozen is None else frozen).encode()
        (self.root / 'frozen.json').write_bytes(data)
        descriptor = dict(path='frozen.json', sha256=hashlib.sha256(data).hexdigest())
        with patch.object(gate.acceptance_execution, 'audit_execution_inputs',
                          return_value=dict(errors=execution_errors or [])) as execution:
            result = gate.audit_navigation_profile_inputs(self.root, descriptor, {}, {})
        return result, execution

    def test_exact_matrix_delegates_full_execution_gate_without_product_pass(self):
        result, execution = self.audit()
        self.assertEqual(result['errors'], [])
        self.assertFalse(result['product_pass'])
        execution.assert_called_once()

    def test_each_missing_cell_is_rejected(self):
        for index in range(4):
            frozen = copy.deepcopy(self.frozen)
            frozen['required_cases'].pop(index)
            result, execution = self.audit(frozen)
            self.assertIn('NAVIGATION_PROFILE_MATRIX_INVALID', result['errors'])
            execution.assert_not_called()

    def test_duplicate_cell_is_rejected(self):
        frozen = copy.deepcopy(self.frozen)
        frozen['required_cases'].append(copy.deepcopy(frozen['required_cases'][0]))
        self.assertTrue(self.audit(frozen)[0]['errors'])

    def test_unknown_profile_is_rejected(self):
        frozen = copy.deepcopy(self.frozen)
        frozen['required_cases'][0]['profile'] = 'other'
        self.assertTrue(self.audit(frozen)[0]['errors'])

    def test_wrong_parent_and_role_are_rejected(self):
        for field, value in [('parent_acceptance_ids', ['F01-A03']), ('role_variant', 'other')]:
            frozen = copy.deepcopy(self.frozen)
            frozen['required_cases'][0][field] = value
            self.assertTrue(self.audit(frozen)[0]['errors'])

    def test_wrong_raw_profile_name_is_rejected(self):
        frozen = copy.deepcopy(self.frozen)
        frozen['case_event_runs'][0]['case_event_bindings'][0]['test_name'] = gate.test_name('android', 'disabled')
        self.assertIn('NAVIGATION_PROFILE_BINDINGS_INVALID', self.audit(frozen)[0]['errors'])

    def test_missing_and_duplicate_binding_are_rejected(self):
        for change in ('missing', 'duplicate'):
            frozen = copy.deepcopy(self.frozen)
            if change == 'missing':
                frozen['case_event_runs'].pop()
            else:
                frozen['case_event_runs'].append(copy.deepcopy(frozen['case_event_runs'][0]))
            self.assertTrue(self.audit(frozen)[0]['errors'])

    def test_full_gate_candidate_runtime_and_artifact_errors_are_preserved(self):
        for error in ('CANDIDATE_DRIFT', 'RUNTIME_BINDING_INVALID', 'ARTIFACT_HASH_INVALID', 'ATTEMPT_INVALID'):
            result, execution = self.audit(execution_errors=[error])
            self.assertIn(error, result['errors'])
            self.assertFalse(result['product_pass'])
            execution.assert_called_once()

    def test_other_domain_cases_are_not_removed(self):
        frozen = copy.deepcopy(self.frozen)
        other = copy.deepcopy(frozen['required_cases'][0])
        other.update(case_id='other', seed_ids=['other'])
        frozen['required_cases'].append(other)
        result, execution = self.audit(frozen)
        self.assertEqual(result['errors'], [])
        execution.assert_called_once()

    def test_invalid_hash_rejected_before_execution(self):
        result = gate.audit_navigation_profile_inputs(self.root,
                    dict(path='missing.json', sha256='0' * 64), {}, {})
        self.assertTrue(result['errors'])
        self.assertFalse(result['product_pass'])

    def test_registered_template_keeps_all_four_obligations(self):
        document = json.loads((Path(__file__).resolve().parents[3] /
            'test/auto_test/case_maps/bottom_navigation_channel_profiles.json').read_text())
        self.assertEqual(gate._matrix_errors(document), [])
        self.assertFalse(document['product_pass'])
        document['case_event_runs'] = [{'case_event_bindings': document['case_event_bindings']}]
        self.assertEqual(gate._binding_errors(document), [])

    def test_real_cli_refuses_matrix_without_execution_evidence(self):
        data = json.dumps(self.frozen).encode()
        report = b'{}'
        (self.root / 'frozen.json').write_bytes(data)
        (self.root / 'report.json').write_bytes(report)
        script = Path(__file__).resolve().parents[3] / 'scripts' / 'auto_test.py'
        completed = subprocess.run([
            sys.executable, str(script), 'acceptance-navigation-profiles',
            '--evidence-root', str(self.root), '--frozen-input', 'frozen.json',
            '--frozen-sha256', hashlib.sha256(data).hexdigest(),
            '--acceptance-report', 'report.json',
            '--report-sha256', hashlib.sha256(report).hexdigest(),
        ], capture_output=True, text=True, timeout=20)
        self.assertEqual(completed.returncode, 2, completed.stderr)
        result = json.loads(completed.stdout)
        self.assertTrue(result['errors'])
        self.assertFalse(result['product_pass'])


if __name__ == '__main__':
    unittest.main()
