"""Synthetic raw-event identity tests; no product or device execution."""
import copy
import hashlib
import json
import sys
import subprocess
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'scripts'))
from auto_test_lib.acceptance_case_events import audit_case_event_artifact


class CaseEventTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.cases = [{'case_id': 'synthetic', 'platform': 'android',
                       'profile': 'synthetic', 'role_variant': 'synthetic',
                       'parent_acceptance_ids': ['F01-A03'], 'seed_ids': ['synthetic'],
                       'oracle': 'synthetic-only', 'applicability': 'REQUIRED'}]
        self.bindings = [{key: self.cases[0][key] for key in
                          ('case_id', 'platform', 'profile', 'role_variant')}]
        self.bindings[0]['test_name'] = 'synthetic required test'

    def audit(self, names, hidden=False, skipped=False):
        events = [{'type': 'start'}]
        for number, name in enumerate(names):
            events.extend([{'type': 'testStart', 'test': {'id': number, 'name': name}},
                           {'type': 'testDone', 'testID': number, 'result': 'success',
                            'hidden': hidden, 'skipped': skipped}])
        events.append({'type': 'done', 'success': True})
        data = '\n'.join(json.dumps(e) for e in events).encode()
        (self.root / 'events.jsonl').write_bytes(data)
        return audit_case_event_artifact(self.root,
            {'path': 'events.jsonl', 'sha256': hashlib.sha256(data).hexdigest()},
            self.cases, self.bindings)

    def test_exact_identity_is_structurally_valid(self):
        self.assertEqual(self.audit(['synthetic required test']), [])

    def test_equal_count_wrong_identity_is_rejected(self):
        self.assertIn('CASE_EVENT_COLLECTION_MISMATCH', self.audit(['other test']))

    def test_duplicate_unknown_missing_or_invalid_names_are_rejected(self):
        for names in [[], [None], [''], ['synthetic required test', 'other'],
                      ['synthetic required test', 'synthetic required test']]:
            with self.subTest(names=names):
                self.assertTrue(self.audit(names))

    def test_hidden_or_skipped_required_case_cannot_pass(self):
        self.assertTrue(self.audit(['synthetic required test'], hidden=True))
        self.assertTrue(self.audit(['synthetic required test'], skipped=True))

    def test_frozen_binding_cannot_drop_or_change_key(self):
        for field in ['case_id', 'platform', 'profile', 'role_variant']:
            original = copy.deepcopy(self.bindings)
            self.bindings[0][field] = 'changed'
            self.assertIn('FROZEN_CASE_EVENT_BINDINGS_INVALID',
                          self.audit(['synthetic required test']))
            self.bindings = original
        self.bindings = []
        self.assertTrue(self.audit(['synthetic required test']))

    def test_ambiguous_frozen_binding_is_rejected(self):
        self.bindings.append(copy.deepcopy(self.bindings[0]))
        self.assertTrue(self.audit(['synthetic required test']))

    def test_artifact_hash_and_path_are_independently_checked(self):
        self.assertEqual(self.audit(['synthetic required test']), [])
        for artifact in [{'path': 'events.jsonl', 'sha256': '0' * 64},
                         {'path': '../events.jsonl', 'sha256': '0' * 64}]:
            self.assertTrue(audit_case_event_artifact(
                self.root, artifact, self.cases, self.bindings))

    def test_actual_cli_matches_frozen_identity_without_writing_evidence(self):
        script = Path(__file__).resolve().parents[3] / 'scripts' / 'auto_test.py'
        for name, expected_exit in [('synthetic required test', 0), ('other test', 2)]:
            self.audit([name])
            event_data = (self.root / 'events.jsonl').read_bytes()
            frozen = {'schema_version': 1, 'required_cases': self.cases,
                      'case_event_bindings': self.bindings,
                      'event_artifact': {'path': 'events.jsonl', 'sha256':
                                         hashlib.sha256(event_data).hexdigest()}}
            data = json.dumps(frozen).encode()
            (self.root / 'frozen.json').write_bytes(data)
            before = {p.name: p.read_bytes() for p in self.root.iterdir()}
            result = subprocess.run([sys.executable, str(script), 'acceptance-case-events',
                '--evidence-root', str(self.root), '--frozen-input', 'frozen.json',
                '--frozen-sha256', hashlib.sha256(data).hexdigest()],
                capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, expected_exit)
            payload = json.loads(result.stdout)
            self.assertIs(payload['product_pass'], False)
            self.assertEqual(payload['scope'], 'RAW_CASE_IDENTITY_ONLY')
            self.assertTrue(payload['remaining_gates'])
            self.assertEqual(before, {p.name: p.read_bytes() for p in self.root.iterdir()})
