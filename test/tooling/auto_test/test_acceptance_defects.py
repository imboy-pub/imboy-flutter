import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'scripts'))
from auto_test_lib.acceptance_defects import audit_defect_records


class DefectRecordsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.key = ['retest', 'android', 'enabled', 'sender']
        case = dict(zip(('case_id', 'platform', 'profile', 'role_variant'), self.key))
        case.update(parent_acceptance_ids=['F03-A01'], seed_ids=['seed'],
                    oracle='synthetic', applicability='REQUIRED')
        run = dict(attempt_id='attempt', required_cases=[case],
                   event_artifact=dict(path='events', sha256='b' * 64))
        self.frozen = dict(defects=[dict(defect_id='D1', severity='P1',
                                        retest_case_keys=[self.key])],
                           candidates={'imboyapp': {'head': 'a' * 40}},
                           required_cases=[case], case_event_runs=[run])
        self.closure = dict(defect_id='D1', repository='imboyapp', candidate_sha='a' * 40,
                            case_key=self.key, attempt_id='attempt',
                            event_artifact=run['event_artifact'])

    def report(self):
        raw = json.dumps(self.closure).encode()
        (self.root / 'closure.json').write_bytes(raw)
        return [dict(defect_id='D1', severity='P1', status='CLOSED',
                     closure_artifacts=[dict(path='closure.json', sha256=hashlib.sha256(raw).hexdigest())])]

    def test_explicit_empty_inventory_and_linked_synthetic_closure(self):
        self.assertEqual([], audit_defect_records(self.root, self.frozen, self.report()))
        self.assertEqual([], audit_defect_records(self.root, {'defects': []}, []))

    def test_missing_duplicate_unknown_defects_rejected(self):
        for report in (None, [], self.report() * 2,
                       [dict(defect_id='unknown', severity='P1', status='OPEN')]):
            self.assertTrue(audit_defect_records(self.root, self.frozen, report))

    def test_open_high_severity_and_severity_downgrade_rejected(self):
        report = self.report()
        report[0]['status'] = 'OPEN'
        self.assertIn('REQUIRED_DEFECT_NOT_CLOSED', audit_defect_records(self.root, self.frozen, report))
        report[0]['severity'] = 'P3'
        self.assertIn('DEFECT_SEVERITY_CHANGED', audit_defect_records(self.root, self.frozen, report))

    def test_closure_binding_mutations_rejected(self):
        for field in ('defect_id', 'repository', 'candidate_sha', 'case_key',
                      'attempt_id', 'event_artifact'):
            with self.subTest(field=field):
                old = copy.deepcopy(self.closure[field])
                self.closure[field] = 'wrong'
                self.assertTrue(audit_defect_records(self.root, self.frozen, self.report()))
                self.closure[field] = old

    def test_unrelated_green_case_cannot_close_defect(self):
        self.frozen['defects'][0]['retest_case_keys'] = []
        self.assertIn('DEFECT_RETEST_SET_INVALID', audit_defect_records(
            self.root, self.frozen, self.report()))

    def test_every_frozen_retest_case_required_and_no_duplicate_closure(self):
        self.frozen['defects'][0]['retest_case_keys'].append(
            ['other', 'macos', 'enabled', 'receiver'])
        self.assertIn('DEFECT_RETEST_SET_MISMATCH', audit_defect_records(
            self.root, self.frozen, self.report()))
        self.frozen['defects'][0]['retest_case_keys'].pop()
        report = self.report()
        report[0]['closure_artifacts'] *= 2
        self.assertIn('DEFECT_RETEST_CASE_DUPLICATE', audit_defect_records(
            self.root, self.frozen, report))

    def test_tampered_closure_rejected(self):
        report = self.report()
        (self.root / 'closure.json').write_text('{}')
        errors = audit_defect_records(self.root, self.frozen, report)
        self.assertTrue(any('ARTIFACT_HASH_MISMATCH' in e for e in errors))


if __name__ == '__main__':
    unittest.main()
