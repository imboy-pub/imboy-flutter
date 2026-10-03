"""Frozen collection checks are structural gates, never product PASS."""
import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'scripts'))
from auto_test_lib import acceptance_contract


class RequiredCaseSetTests(unittest.TestCase):
    def setUp(self):
        self.baseline = [{
            'case_id': 'synthetic-1', 'platform': 'android',
            'profile': 'enabled', 'role_variant': 'sender',
            'parent_acceptance_ids': ['F03-A01'],
            'seed_ids': ['synthetic-seed'], 'oracle': 'synthetic oracle',
            'applicability': 'REQUIRED',
        }]

    def audit(self, rows):
        return acceptance_contract.validate_required_case_set(
            self.baseline, rows, ['F03-A01'])

    def test_unchanged_synthetic_structure(self):
        self.assertEqual(self.audit(copy.deepcopy(self.baseline)), [])

    def test_empty_and_duplicate_rows_rejected(self):
        self.assertTrue(self.audit([]))
        self.assertTrue(self.audit(self.baseline * 2))

    def test_unknown_missing_or_modified_case_rejected(self):
        for field, value in (
            ('case_id', 'unknown'), ('platform', 'macos'),
            ('profile', 'disabled'), ('role_variant', 'receiver'),
            ('parent_acceptance_ids', []), ('seed_ids', []),
            ('oracle', 'screenshot only'), ('applicability', 'NOT_APPLICABLE'),
        ):
            with self.subTest(field=field):
                rows = copy.deepcopy(self.baseline)
                rows[0][field] = value
                self.assertTrue(self.audit(rows))

    def test_invalid_trusted_baseline_cannot_pass(self):
        for baseline, ids in (([], []), (self.baseline, ['F99-A01']),
                              (self.baseline, ['F03-A01', 'F03-A01'])):
            self.assertTrue(acceptance_contract.validate_required_case_set(
                baseline, baseline, ids))

    def test_malformed_keys_return_codes_without_echo(self):
        for rows in (None, [{}], [False], [{'case_id': ['secret-value']}],
                     [dict(self.baseline[0], platform=[]) ]):
            errors = self.audit(rows)
            self.assertTrue(errors)
            self.assertNotIn('secret-value', str(errors))

    def test_duplicate_parent_ids_rejected(self):
        rows = copy.deepcopy(self.baseline)
        rows[0]['parent_acceptance_ids'] *= 2
        self.assertTrue(self.audit(rows))

    def test_type_changes_in_frozen_extension_fields_are_rejected(self):
        self.baseline[0]['requires_pair'] = True
        rows = copy.deepcopy(self.baseline)
        rows[0]['requires_pair'] = 1
        self.assertTrue(self.audit(rows))


if __name__ == '__main__':
    unittest.main()
