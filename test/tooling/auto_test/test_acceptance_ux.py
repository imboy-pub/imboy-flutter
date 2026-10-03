import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'scripts'))
from auto_test_lib.acceptance_ux import audit_user_ux_records


class UserUxRecordsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.key = ['case', 'android', 'enabled', 'sender']
        case = dict(zip(('case_id', 'platform', 'profile', 'role_variant'), self.key))
        case.update(parent_acceptance_ids=['F16-A01'], seed_ids=['seed'],
                    oracle='synthetic only', applicability='REQUIRED')
        raw = b'synthetic visual artifact, not a screenshot of a device'
        (self.root / 'visual').write_bytes(raw)
        artifacts = [dict(path='visual', sha256=hashlib.sha256(raw).hexdigest())]
        self.frozen = dict(required_cases=[case], candidates={name: {'head': 'a' * 40}
            for name in ('imboy', 'imboyapp', 'imboyadmin')},
            version_inputs={'synthetic': {'path': 'version', 'sha256': 'b' * 64}},
            ux_review_requirements=[dict(review_id='UX1', case_keys=[self.key],
                                         reviewed_artifacts=artifacts)])
        self.record = dict(review_id='UX1', case_keys=[self.key], reviewer_kind='USER',
            status='APPROVED', approval_ref='synthetic approval, not a user signature',
            candidate_heads={name: 'a' * 40 for name in self.frozen['candidates']},
            version_inputs=copy.deepcopy(self.frozen['version_inputs']),
            reviewed_artifacts=artifacts)

    def observed(self):
        raw = json.dumps(self.record).encode()
        (self.root / 'review.json').write_bytes(raw)
        return {'UX1': dict(path='review.json', sha256=hashlib.sha256(raw).hexdigest())}

    def test_synthetic_approval_structure_only(self):
        self.assertEqual([], audit_user_ux_records(self.root, self.frozen, self.observed()))

    def test_missing_empty_unknown_and_duplicate_requirements(self):
        for value in (None, [], self.frozen['ux_review_requirements'] * 2):
            frozen = copy.deepcopy(self.frozen)
            frozen['ux_review_requirements'] = value
            self.assertIn('UX_REVIEW_REQUIREMENTS_INVALID', audit_user_ux_records(
                self.root, frozen, self.observed()))
        for value in (None, {}, {'unknown': self.observed()['UX1']}):
            self.assertIn('UX_REVIEW_SET_MISMATCH', audit_user_ux_records(
                self.root, self.frozen, value))

    def test_worker_pending_and_rejected_cannot_substitute_user(self):
        for field, value in [('reviewer_kind', 'WORKER'), ('status', 'PENDING'),
                             ('status', 'REJECTED'), ('approval_ref', '')]:
            record = copy.deepcopy(self.record)
            self.record[field] = value
            self.assertTrue(audit_user_ux_records(self.root, self.frozen, self.observed()))
            self.record = record

    def test_obligation_candidate_version_and_artifact_changes_rejected(self):
        for field in ('review_id', 'case_keys', 'candidate_heads', 'version_inputs',
                      'reviewed_artifacts'):
            record = copy.deepcopy(self.record)
            self.record[field] = 'changed'
            self.assertTrue(audit_user_ux_records(self.root, self.frozen, self.observed()))
            self.record = record

    def test_tampered_approval_and_visual_rejected(self):
        observed = self.observed()
        (self.root / 'review.json').write_text('{}')
        self.assertTrue(audit_user_ux_records(self.root, self.frozen, observed))
        observed = self.observed()
        (self.root / 'visual').write_bytes(b'changed')
        self.assertTrue(audit_user_ux_records(self.root, self.frozen, observed))

    def test_unknown_or_repeated_case_and_invalid_candidate_rejected(self):
        for keys in ([['unknown', 'android', 'enabled', 'sender']], [self.key] * 2):
            frozen = copy.deepcopy(self.frozen)
            frozen['ux_review_requirements'][0]['case_keys'] = keys
            self.assertTrue(audit_user_ux_records(self.root, frozen, self.observed()))
        for head in (None, '0' * 40, 'bad', 123):
            frozen = copy.deepcopy(self.frozen)
            frozen['candidates']['imboyapp']['head'] = head
            self.assertIn('UX_REVIEW_BINDINGS_INVALID', audit_user_ux_records(
                self.root, frozen, self.observed()))

    def test_reused_approval_record_rejected(self):
        request = copy.deepcopy(self.frozen['ux_review_requirements'][0])
        request['review_id'] = 'UX2'
        self.frozen['ux_review_requirements'].append(request)
        observed = self.observed()
        observed['UX2'] = observed['UX1']
        self.assertIn('UX_REVIEW_RECORD_REUSED_OR_INVALID', audit_user_ux_records(
            self.root, self.frozen, observed))

    def test_missing_visual_and_symlink_approval_rejected(self):
        observed = self.observed()
        (self.root / 'visual').unlink()
        self.assertTrue(audit_user_ux_records(self.root, self.frozen, observed))
        (self.root / 'review.json').rename(self.root / 'review-original.json')
        (self.root / 'review.json').symlink_to(self.root / 'review-original.json')
        self.assertTrue(audit_user_ux_records(self.root, self.frozen, observed))

    def test_malformed_input_and_no_reviewed_artifacts_rejected(self):
        for value in (None, [], {}, {'ux_review_requirements': [None]}):
            self.assertTrue(audit_user_ux_records(self.root, value, {}))
        self.frozen['ux_review_requirements'][0]['reviewed_artifacts'] = []
        self.record['reviewed_artifacts'] = []
        self.assertIn('EMPTY_ARTIFACT_SET', audit_user_ux_records(
            self.root, self.frozen, self.observed()))


if __name__ == '__main__':
    unittest.main()
