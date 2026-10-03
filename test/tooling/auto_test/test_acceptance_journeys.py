import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'scripts'))
from auto_test_lib.acceptance_journeys import audit_cross_device_records


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


if __name__ == '__main__':
    unittest.main()
