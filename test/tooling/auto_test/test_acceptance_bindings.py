"""Runtime binding integrity calibration uses only synthetic local artifacts."""
import copy
import hashlib
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'scripts'))
from auto_test_lib import acceptance_bindings


class RuntimeBindingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.rows = []
        for kind in ['source', 'config', 'build', 'fixture', 'device']:
            content = ('synthetic ' + kind).encode()
            (self.root / kind).write_bytes(content)
            self.rows.append({'binding_id': kind, 'kind': kind, 'artifact': {
                'path': kind, 'sha256': hashlib.sha256(content).hexdigest()}})
        self.ids = [r['binding_id'] for r in self.rows]

    def audit(self, rows=None):
        return acceptance_bindings.audit_runtime_binding_files(
            self.root, self.rows, self.rows if rows is None else rows, self.ids)

    def test_complete_synthetic_bindings_have_matching_bytes(self):
        self.assertEqual(self.audit(), [])

    def test_missing_unknown_and_duplicate_rows_are_rejected(self):
        for rows in [self.rows[:-1], self.rows + [dict(self.rows[0], binding_id='extra')],
                     self.rows + [self.rows[0]], []]:
            with self.subTest(rows=rows):
                self.assertTrue(self.audit(rows))

    def test_metadata_and_hash_changes_are_rejected(self):
        for changed in [dict(self.rows[0], kind='device'),
                        dict(self.rows[0], candidate='unfrozen'),
                        dict(self.rows[0], artifact={'path': 'source', 'sha256': '0' * 64})]:
            rows = copy.deepcopy(self.rows)
            rows[0] = changed
            self.assertIn('FROZEN_RUNTIME_BINDING_CHANGED', self.audit(rows))

    def test_actual_config_drift_is_rejected(self):
        (self.root / 'config').write_text('modified synthetic config')
        self.assertTrue(any('HASH_MISMATCH' in e for e in self.audit()))

    def test_incomplete_frozen_kinds_and_ids_are_rejected(self):
        for rows, ids in [(self.rows[:-1], self.ids[:-1]),
                          (self.rows, self.ids + ['missing']),
                          (self.rows, self.ids + [self.ids[0]])]:
            self.assertTrue(acceptance_bindings.audit_runtime_binding_files(
                self.root, rows, rows, ids))

    def test_symlink_and_path_escape_rejected_without_echo(self):
        (self.root / 'source').unlink()
        (self.root / 'source').symlink_to(self.root / 'config')
        self.assertTrue(any('UNREADABLE' in e for e in self.audit()))
        self.rows[0]['artifact']['path'] = '../secret-marker'
        errors = self.audit()
        self.assertTrue(any('PATH_REJECTED' in e for e in errors))
        self.assertNotIn('secret-marker', str(errors))

    def test_malformed_rows_return_codes(self):
        for rows in [[False], [dict(self.rows[0], kind=[])],
                     [dict(self.rows[0], artifact=None)]]:
            self.assertTrue(self.audit(rows))

    def test_deep_metadata_returns_fixed_error_for_both_inputs(self):
        deep = 'synthetic'
        for _ in range(sys.getrecursionlimit() + 10):
            deep = [deep]
        observed = copy.deepcopy(self.rows)
        observed[0]['metadata'] = deep
        self.assertEqual(self.audit(observed),
                         ['OBSERVED_RUNTIME_BINDING_SCHEMA_INVALID'])
        self.rows[0]['metadata'] = deep
        self.assertEqual(self.audit(), ['FROZEN_RUNTIME_BINDING_SET_INVALID'])


if __name__ == '__main__':
    unittest.main()
