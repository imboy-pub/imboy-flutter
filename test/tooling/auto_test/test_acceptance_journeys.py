import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'scripts'))
from auto_test_lib.acceptance_journeys import (
    audit_cross_device_records, audit_cross_device_journey_set,
)


class JourneyRecordsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.expected = dict(run_id='run', journey_id='journey', message_id='message',
                             fixture_generation='generation', app_sha='a' * 40,
                             backend_sha='b' * 40, admin_sha='c' * 40,
                             payload_sha256='d' * 64, sender_device='android',
                             receiver_device='macos')
        self.records = {}
        for stage in ('sender_ui', 'persistence', 'receiver_ui', 'reopened_ui'):
            row = {k: v for k, v in self.expected.items()
                   if k not in ('sender_device', 'receiver_device')}
            row.update(stage=stage, observed=True,
                       capture_kind='database_query' if stage == 'persistence' else 'ui_observation',
                       device_id='android' if stage == 'sender_ui' else 'macos',
                       launch_generation=2 if stage == 'reopened_ui' else 1)
            self.records[stage] = row

    def artifacts(self):
        artifacts = {}
        for stage, row in self.records.items():
            content = json.dumps(row).encode()
            (self.root / (stage + '.json')).write_bytes(content)
            artifacts[stage] = dict(path=stage + '.json', sha256=hashlib.sha256(content).hexdigest())
        return artifacts

    def audit(self):
        return audit_cross_device_records(self.root, self.expected, self.artifacts())

    def test_synthetic_structure_never_issues_product_pass(self):
        result = self.audit()
        self.assertEqual([], result['errors'])
        self.assertIs(False, result['product_pass'])

    def test_each_binding_mismatch_rejected(self):
        for field in ('run_id', 'journey_id', 'message_id', 'fixture_generation',
                      'app_sha', 'backend_sha', 'admin_sha', 'payload_sha256'):
            with self.subTest(field=field):
                old = self.records['receiver_ui'][field]
                self.records['receiver_ui'][field] = 'different'
                self.assertIn('JOURNEY_BINDING_MISMATCH:receiver_ui', self.audit()['errors'])
                self.records['receiver_ui'][field] = old

    def test_missing_persistence_rejected(self):
        del self.records['persistence']
        self.assertIn('JOURNEY_REQUIRED_STAGE_SET_MISMATCH', self.audit()['errors'])

    def test_mock_capture_rejected(self):
        self.records['persistence']['capture_kind'] = 'mock'
        self.assertIn('JOURNEY_CAPTURE_KIND_MISMATCH:persistence', self.audit()['errors'])

    def test_receiver_device_cannot_be_sender(self):
        self.records['receiver_ui']['device_id'] = 'android'
        self.assertIn('JOURNEY_DEVICE_MISMATCH:receiver_ui', self.audit()['errors'])

    def test_reopen_requires_new_launch(self):
        self.records['reopened_ui']['launch_generation'] = 1
        self.assertIn('JOURNEY_REOPEN_NOT_NEW_LAUNCH', self.audit()['errors'])

    def test_observation_cannot_be_summary_pass(self):
        self.records['receiver_ui']['observed'] = 'PASS'
        self.assertIn('JOURNEY_OBSERVATION_MISSING:receiver_ui', self.audit()['errors'])

    def test_boolean_is_not_launch_generation(self):
        self.records['reopened_ui']['launch_generation'] = True
        self.assertIn('JOURNEY_LAUNCH_GENERATION_INVALID:reopened_ui', self.audit()['errors'])

    def test_zero_candidate_rejected(self):
        self.expected['app_sha'] = '0' * 40
        self.assertIn('JOURNEY_CANDIDATE_INVALID', self.audit()['errors'])

    def test_artifact_tampering_rejected(self):
        artifacts = self.artifacts()
        (self.root / 'receiver_ui.json').write_text('{}')
        result = audit_cross_device_records(self.root, self.expected, artifacts)
        self.assertTrue(any('ARTIFACT_HASH_MISMATCH' in e for e in result['errors']))

    def test_path_escape_rejected(self):
        artifacts = self.artifacts()
        artifacts['persistence']['path'] = '../outside.json'
        result = audit_cross_device_records(self.root, self.expected, artifacts)
        self.assertTrue(any('ARTIFACT_PATH_REJECTED' in e for e in result['errors']))

    def test_symlink_rejected(self):
        artifacts = self.artifacts()
        (self.root / 'alias.json').symlink_to('receiver_ui.json')
        artifacts['receiver_ui']['path'] = 'alias.json'
        result = audit_cross_device_records(self.root, self.expected, artifacts)
        self.assertTrue(any('ARTIFACT_UNREADABLE' in e for e in result['errors']))

    def test_record_reuse_rejected(self):
        artifacts = self.artifacts()
        artifacts['persistence'] = artifacts['sender_ui']
        result = audit_cross_device_records(self.root, self.expected, artifacts)
        self.assertIn('JOURNEY_RECORD_REUSED:persistence', result['errors'])

    def frozen(self):
        cases = [dict(case_id='case', platform=platform, profile='enabled',
                      role_variant='participant', parent_acceptance_ids=['F03-A01'],
                      seed_ids=['seed'], oracle='synthetic', applicability='REQUIRED',
                      cross_device_journey_ids=['journey'])
                 for platform in ('android', 'macos')]
        return dict(required_cases=cases, cross_device_journeys=[self.expected],
                    run_id='run', fixture_generation='generation', candidates={
                        'imboyapp': {'head': 'a' * 40}, 'imboy': {'head': 'b' * 40},
                        'imboyadmin': {'head': 'c' * 40}})

    def test_exact_journey_set(self):
        self.assertEqual([], audit_cross_device_journey_set(
            self.root, self.frozen(), {'journey': self.artifacts()}))
        self.assertIn('JOURNEY_RECORDED_SET_MISMATCH', audit_cross_device_journey_set(
            self.root, self.frozen(), {}))
        self.assertIn('JOURNEY_RECORDED_SET_MISMATCH', audit_cross_device_journey_set(
            self.root, self.frozen(), {'journey': self.artifacts(), 'unknown': {}}))

    def test_missing_or_duplicate_frozen_journey_rejected(self):
        frozen = self.frozen()
        frozen['cross_device_journeys'] = []
        self.assertIn('JOURNEY_REQUIRED_MEMBERSHIP_MISMATCH',
                      audit_cross_device_journey_set(self.root, frozen, {}))
        frozen['cross_device_journeys'] = [self.expected, self.expected]
        self.assertIn('FROZEN_JOURNEY_DUPLICATE',
                      audit_cross_device_journey_set(self.root, frozen, {}))

    def test_both_case_platforms_mandatory(self):
        frozen = self.frozen()
        frozen['required_cases'].pop()
        self.assertIn('JOURNEY_REQUIRES_BOTH_PLATFORMS',
                      audit_cross_device_journey_set(self.root, frozen, {}))

    def test_case_declaration_cannot_be_silently_omitted(self):
        frozen = self.frozen()
        del frozen['required_cases'][0]['cross_device_journey_ids']
        self.assertIn('JOURNEY_CASE_DECLARATION_INVALID',
                      audit_cross_device_journey_set(self.root, frozen, {}))

    def test_frozen_runtime_and_candidates_bind_journey(self):
        for key in ('run_id', 'fixture_generation'):
            frozen = self.frozen()
            frozen[key] = 'different'
            self.assertIn('JOURNEY_FROZEN_RUNTIME_MISMATCH',
                          audit_cross_device_journey_set(self.root, frozen, {}))
        frozen = self.frozen()
        frozen['candidates']['imboyapp']['head'] = 'e' * 40
        self.assertIn('JOURNEY_FROZEN_CANDIDATE_MISMATCH',
                      audit_cross_device_journey_set(self.root, frozen, {}))

    def test_malformed_candidate_container_is_rejected(self):
        frozen = self.frozen()
        frozen['candidates'] = None
        self.assertIn('JOURNEY_FROZEN_CANDIDATE_MISMATCH',
                      audit_cross_device_journey_set(self.root, frozen, {}))


if __name__ == '__main__':
    unittest.main()
