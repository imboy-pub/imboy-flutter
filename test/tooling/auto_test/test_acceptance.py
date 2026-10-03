"""F01 artifact integrity and raw-event checks; never product acceptance."""
from __future__ import annotations

import copy
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))

from auto_test_lib import acceptance, evidence  # noqa: E402


class ArtifactIntegrityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.content = b'one immutable artifact\n'
        (self.root / 'events.jsonl').write_bytes(self.content)
        self.artifact = {
            'path': 'events.jsonl',
            'sha256': hashlib.sha256(self.content).hexdigest(),
        }

    def errors(self, artifacts=None):
        return acceptance.validate_artifact_files(
            self.root, [self.artifact] if artifacts is None else artifacts,
        )

    def test_valid_file_has_no_integrity_errors(self):
        self.assertEqual(self.errors(), [])

    def test_empty_manifest_never_passes(self):
        self.assertIn('EMPTY_ARTIFACT_SET', self.errors([]))

    def test_hash_is_recomputed_not_trusted(self):
        (self.root / 'events.jsonl').write_bytes(b'changed')
        self.assertTrue(any('ARTIFACT_HASH_MISMATCH' in e for e in self.errors()))

    def test_missing_file_is_not_a_pass(self):
        (self.root / 'events.jsonl').unlink()
        self.assertTrue(any('ARTIFACT_UNREADABLE' in e for e in self.errors()))

    def test_invalid_paths_are_rejected(self):
        for path in ('../outside', '/etc/passwd', './events.jsonl',
                     'dir/../events.jsonl', 'dir//events.jsonl', ''):
            with self.subTest(path=path):
                item = dict(self.artifact, path=path)
                self.assertTrue(any('ARTIFACT_PATH_REJECTED' in e
                                    for e in self.errors([item])))

    def test_duplicate_path_cannot_count_twice(self):
        self.assertTrue(any('DUPLICATE_ARTIFACT_PATH' in e
                            for e in self.errors([self.artifact] * 2)))

    def test_symlink_file_even_within_root_is_rejected(self):
        (self.root / 'alias').symlink_to('events.jsonl')
        item = dict(self.artifact, path='alias')
        self.assertTrue(any('ARTIFACT_UNREADABLE' in e
                            for e in self.errors([item])))

    def test_symlink_parent_is_rejected(self):
        (self.root / 'real').mkdir()
        (self.root / 'real/events.jsonl').write_bytes(self.content)
        (self.root / 'alias').symlink_to('real', target_is_directory=True)
        item = dict(self.artifact, path='alias/events.jsonl')
        self.assertTrue(any('ARTIFACT_UNREADABLE' in e
                            for e in self.errors([item])))

    def test_fifo_does_not_block_reader_or_count_as_file(self):
        import os
        os.mkfifo(self.root / 'fifo')
        item = dict(self.artifact, path='fifo')
        self.assertTrue(any('ARTIFACT_UNREADABLE' in e
                            for e in self.errors([item])))

    def test_invalid_hash_and_malformed_item_fail_closed(self):
        for item in (dict(self.artifact, sha256='-'), None, 'events.jsonl'):
            with self.subTest(item=item):
                self.assertTrue(self.errors([item]))


class RawEventAuditTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        events = [
            {'type': 'testStart', 'test': {'id': 1, 'name': 'one case'}},
            {'type': 'testDone', 'testID': 1, 'result': 'success',
             'skipped': False, 'hidden': False},
            {'type': 'done', 'success': True},
        ]
        self.write_events(events)
        digest = 'c' * 64
        self.manifest = evidence.build_evidence(
            run_id='verifier-fixture', head='a' * 40, backend_head='b' * 40,
            target='test/unit_test/case_test.dart',
            result_dict={'status': 'PASS', 'executed': 1, 'skipped': 0,
                         'failed': 0, 'process_exit_code': 0},
            environment={'app_env': 'local'}, device={'platform': 'host'},
            fixture={'namespace': 'isolated'}, artifacts=[self.artifact],
            dependency_closure={'algorithm': 'catalog-v1',
                                'manifest_path': 'closure.json',
                                'manifest_sha256': digest,
                                'content_sha256': digest},
            tested_tree_sha256=digest, catalog_sha256=digest,
            target_sha256=digest, runner_sha256=digest,
            config_sha256=digest, command_fingerprint=digest,
            required_evidence_level='C',
        )

    def write_events(self, events):
        data = '\n'.join(json.dumps(e) for e in events).encode() + b'\n'
        (self.root / 'events.jsonl').write_bytes(data)
        self.artifact = {'path': 'events.jsonl', 'kind': 'machine_events',
                         'sha256': hashlib.sha256(data).hexdigest()}

    def audit(self, manifest=None):
        return acceptance.audit_evidence_artifacts(
            self.root, self.manifest if manifest is None else manifest,
            requirements=[],
        )

    def test_real_events_are_reparsed(self):
        self.assertEqual(self.audit(), [])

    def test_claimed_count_must_match_raw_events(self):
        self.manifest['result']['executed'] = 100
        self.assertTrue(any('RAW_EVENT_RESULT_MISMATCH' in e for e in self.audit()))

    def test_zero_events_cannot_pass_with_exit_zero(self):
        self.write_events([{'type': 'done', 'success': True}])
        self.manifest['artifacts'] = [self.artifact]
        self.assertTrue(any('RAW_EVENT_NOT_PASS' in e for e in self.audit()))

    def test_required_skips_cannot_be_green(self):
        self.write_events([
            {'type': 'testDone', 'testID': 1, 'result': 'success',
             'skipped': True, 'hidden': False},
            {'type': 'done', 'success': True},
        ])
        self.manifest['artifacts'] = [self.artifact]
        self.assertTrue(any('RAW_EVENT_NOT_PASS' in e for e in self.audit()))

    def test_screenshot_only_or_missing_exit_code_never_passes(self):
        for manifest in (copy.deepcopy(self.manifest), copy.deepcopy(self.manifest)):
            if 'process_exit_code' in manifest['result']:
                manifest['result'].pop('process_exit_code')
            self.assertTrue(self.audit(manifest))
        self.manifest['artifacts'][0]['kind'] = 'screenshot'
        self.assertTrue(any('MACHINE_EVENT_ARTIFACT_REQUIRED' in e
                            for e in self.audit()))

    def test_nonzero_or_boolean_exit_code_is_rejected(self):
        for value in (1, True, False, '0'):
            with self.subTest(value=value):
                self.manifest['result']['process_exit_code'] = value
                self.assertTrue(any('PROCESS_EXIT_NOT_ZERO' in e
                                    for e in self.audit()))

    def test_secrets_never_echo_their_value(self):
        self.manifest['password'] = 'synthetic-sensitive-value'
        errors = self.audit()
        self.assertTrue(errors)
        self.assertNotIn('synthetic-sensitive-value', '\n'.join(errors))


if __name__ == '__main__':
    unittest.main()
