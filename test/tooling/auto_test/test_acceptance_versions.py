import copy
import hashlib
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'scripts'))
from auto_test_lib.acceptance_versions import audit_version_inputs


class VersionInputsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.frozen = {}
        for role in ('product_plan', 'e2ee_plan', 'execution_contract', 'dispatch_cards',
                     'acceptance_set', 'coverage_seed', 'input_manifest'):
            raw = ('synthetic only: ' + role).encode()
            (self.root / role).write_bytes(raw)
            self.frozen[role] = dict(path=role, sha256=hashlib.sha256(raw).hexdigest())
        self.report = copy.deepcopy(self.frozen)

    def audit(self):
        return audit_version_inputs(self.root, self.frozen, self.report)

    def test_complete_synthetic_component_bytes(self):
        self.assertEqual([], self.audit())

    def test_missing_and_unknown_components_rejected(self):
        for role in tuple(self.frozen):
            descriptor = self.frozen.pop(role)
            self.assertIn('VERSION_INPUT_ROLE_SET_INVALID', self.audit())
            self.frozen[role] = descriptor
        self.report['unknown'] = {}
        self.assertIn('VERSION_INPUT_ROLE_SET_INVALID', self.audit())

    def test_report_cannot_replace_frozen_binding(self):
        self.report['product_plan']['sha256'] = '0' * 64
        self.assertIn('VERSION_INPUT_BINDING_CHANGED', self.audit())

    def test_tampered_bytes_rejected(self):
        (self.root / 'execution_contract').write_text('changed')
        self.assertTrue(any('ARTIFACT_HASH_MISMATCH' in e for e in self.audit()))

    def test_reusing_one_file_for_two_roles_rejected(self):
        self.frozen['e2ee_plan'] = self.frozen['product_plan']
        self.report = copy.deepcopy(self.frozen)
        self.assertIn('VERSION_INPUT_ARTIFACT_REUSED', self.audit())

    def test_escape_symlink_and_malformed_descriptor_rejected(self):
        for descriptor in (dict(path='../outside', sha256='a' * 64),
                           dict(path=[], sha256='a' * 64), None):
            self.frozen['product_plan'] = descriptor
            self.report = copy.deepcopy(self.frozen)
            self.assertTrue(self.audit())
        (self.root / 'alias').symlink_to('e2ee_plan')
        self.frozen['product_plan'] = dict(path='alias', sha256=self.frozen['e2ee_plan']['sha256'])
        self.report = copy.deepcopy(self.frozen)
        self.assertTrue(any('ARTIFACT_UNREADABLE' in e for e in self.audit()))


if __name__ == '__main__':
    unittest.main()
