"""Synthetic frozen coverage tests; no semantic or product verdict."""
import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'scripts'))
from auto_test_lib.acceptance_coverage import audit_input_case_coverage


class CoverageTests(unittest.TestCase):
    def setUp(self):
        self.case = {'case_id': 'synthetic', 'platform': 'android', 'profile': 'test',
                     'role_variant': 'test', 'parent_acceptance_ids': ['F00-A01'],
                     'seed_ids': ['synthetic'], 'oracle': 'visible synthetic fact',
                     'applicability': 'REQUIRED'}
        self.key = [self.case[k] for k in ('case_id', 'platform', 'profile', 'role_variant')]
        self.inputs = [{'input_kind': kind, 'input_id': 'synthetic-' + kind}
                       for kind in ['seed', 'generated', 'page', 'api', 'ws', 'admin']]
        self.mappings = [dict(row, owner='/root', source_refs=['synthetic.dart:1'],
                             case_keys=[self.key], disposition='CASE_MAPPED')
                         for row in self.inputs]
        self.approvals = []

    def audit(self):
        return audit_input_case_coverage(self.inputs, [self.case], self.mappings, self.approvals)

    def test_all_inputs_mapped_is_structurally_valid(self):
        self.assertEqual(self.audit(), [])

    def test_dropped_input_or_case_mapping_is_rejected(self):
        self.mappings.pop()
        self.assertIn('COVERAGE_INPUT_MISSING', self.audit())
        self.mappings = []
        self.assertIn('COVERAGE_REQUIRED_CASE_UNMAPPED', self.audit())

    def test_input_kind_missing_duplicate_unknown_are_rejected(self):
        self.inputs.pop()
        self.assertTrue(self.audit())
        self.setUp()
        self.mappings.append(copy.deepcopy(self.mappings[0]))
        self.assertTrue(self.audit())
        self.mappings[-1]['input_id'] = 'unknown'
        self.assertTrue(self.audit())

    def test_owner_oracle_placeholders_and_source_gaps_rejected(self):
        self.case['oracle'] = 'TODO'
        self.assertTrue(self.audit())
        self.case['oracle'] = 'visible synthetic fact'
        self.mappings[0]['owner'] = 'PENDING'
        self.assertTrue(self.audit())
        self.mappings[0]['owner'] = '/root'
        self.mappings[0]['source_refs'] = []
        self.assertTrue(self.audit())

    def test_unknown_duplicate_empty_or_malformed_case_keys_rejected(self):
        for keys in [[], [self.key, self.key], [['unknown'] * 4], [True], [[[]]]]:
            self.mappings[0]['case_keys'] = keys
            self.assertTrue(self.audit())

    def test_dispositions_require_exact_frozen_approval(self):
        row = self.mappings[0]
        row.update(disposition='DELETED', approval_ref='synthetic-approval', case_keys=[])
        self.assertIn('COVERAGE_DISPOSITION_NOT_IN_FROZEN_APPROVALS', self.audit())
        self.approvals = [copy.deepcopy(row)]
        self.assertEqual(self.audit(), [])
        row['source_refs'] = ['changed.dart:1']
        self.assertTrue(self.audit())

    def test_disposal_cannot_remove_required_case_coverage(self):
        for row in self.mappings:
            row.update(disposition='DELETED', approval_ref='synthetic-approved', case_keys=[])
        self.approvals = copy.deepcopy(self.mappings)
        self.assertIn('COVERAGE_REQUIRED_CASE_UNMAPPED', self.audit())

    def test_invalid_approval_rows_or_empty_merge_cannot_be_approved(self):
        for approvals in [[None], [{'disposition': 'DELETED', 'extra': float('nan')}]]:
            self.approvals = approvals
            self.assertTrue(self.audit())
        self.approvals = []
        row = self.mappings[0]
        row.update(disposition='MERGED', approval_ref='synthetic-approved', case_keys=[])
        self.approvals = [copy.deepcopy(row)]
        self.assertIn('COVERAGE_DISPOSITION_CASE_KEYS_INVALID', self.audit())

    def test_failed_hash_cannot_match_failed_approval_hash(self):
        self.mappings[0].update(disposition='DELETED', approval_ref='unapproved',
                                case_keys=[], metadata='\ud800')
        self.approvals = ['\ud800']
        self.assertTrue(self.audit())
