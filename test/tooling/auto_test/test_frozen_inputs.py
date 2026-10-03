"""Frozen inputs must be hash-bound and unambiguous before collection audit."""
import hashlib
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'scripts'))
from auto_test_lib import acceptance


class FrozenInputTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def load(self, data, claimed=None):
        (self.root / 'input.json').write_bytes(data)
        artifact = {'path': 'input.json', 'sha256': claimed or hashlib.sha256(data).hexdigest()}
        return acceptance.load_frozen_json(self.root, artifact)

    def test_valid_structure(self):
        self.assertEqual(self.load(b'{"cases":[1]}'), ({'cases': [1]}, []))

    def test_tamper_cannot_load(self):
        value, errors = self.load(b'{}', 'a' * 64)
        self.assertIsNone(value)
        self.assertTrue(errors)

    def test_duplicate_keys_and_nonfinite_numbers_rejected(self):
        for data in (b'{"cases":1,"cases":2}', b'{"nested":{"x":1,"x":2}}',
                     b'{"x":NaN}', b'{"x":Infinity}', b'{"x":-Infinity}',
                     b'{"x":1e400}'):
            with self.subTest(data=data):
                value, errors = self.load(data)
                self.assertIsNone(value)
                self.assertTrue(errors)

    def test_malformed_utf8_or_json_returns_codes(self):
        for data in (b'\xff', b'{secret-value', b'{}{}', b'null', b'{"x":\x0b1}'):
            value, errors = self.load(data)
            self.assertIsNone(value)
            self.assertTrue(errors)
            self.assertNotIn('secret-value', str(errors))

    def test_path_escape_and_symlink_rejected(self):
        self.load(b'{}')
        (self.root / 'link.json').symlink_to(self.root / 'input.json')
        for path in ('../input.json', 'link.json', '/input.json'):
            value, errors = acceptance.load_frozen_json(
                self.root, {'path': path, 'sha256': hashlib.sha256(b'{}').hexdigest()})
            self.assertIsNone(value)
            self.assertTrue(errors)

    def test_invalid_artifact_schema_rejected(self):
        for artifact in (None, [], {}, {'path': [], 'sha256': True}):
            self.assertTrue(acceptance.load_frozen_json(self.root, artifact)[1])


if __name__ == '__main__':
    unittest.main()
