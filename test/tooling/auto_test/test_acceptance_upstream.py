import copy
import csv
import hashlib
import io
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'scripts'))
from auto_test_lib.acceptance_upstream import audit_upstream_ledger, _FIELDS, _CARDS


class UpstreamLedgerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        raw = b'synthetic oracle only, no safety qualification'
        (self.root / 'oracle').write_bytes(raw)
        row = dict(zip(_FIELDS, ['synthetic'] * len(_FIELDS)))
        row.update(status='PASS', plan_sha='b' * 64, backend_sha='a' * 40,
                   app_sha='a' * 40, other_repo_sha='-', config_hash='c' * 64, exit_code='0',
                   test_count='1', evidence_path='oracle',
                   evidence_sha256=hashlib.sha256(raw).hexdigest())
        self.rows = [dict(row, id=identifier, card=_CARDS[identifier])
                     for identifier in sorted(_CARDS)]
        self.frozen = dict(version_inputs={'e2ee_plan': {'sha256': 'b' * 64}},
                           candidates={name: {'head': 'a' * 40}
                               for name in ('imboy', 'imboyapp')})

    def artifact(self):
        stream = io.StringIO()
        writer = csv.DictWriter(stream, fieldnames=_FIELDS, delimiter='\t')
        writer.writeheader()
        writer.writerows(self.rows)
        raw = stream.getvalue().encode()
        (self.root / 'ledger.tsv').write_bytes(raw)
        descriptor = dict(path='ledger.tsv', sha256=hashlib.sha256(raw).hexdigest())
        self.frozen['upstream_acceptance_artifact'] = descriptor
        return descriptor

    def audit(self):
        return audit_upstream_ledger(self.root, self.frozen, self.artifact())

    def test_synthetic_full_ledger_structure_only(self):
        self.assertEqual([], self.audit())

    def test_declared_admin_sha_requires_current_frozen_candidate(self):
        self.rows[0]['other_repo_sha'] = 'd' * 40
        self.assertIn('UPSTREAM_OTHER_REPO_BINDING_MISMATCH:AC-00', self.audit())
        self.frozen['candidates']['imboyadmin'] = {'head': 'd' * 40}
        self.assertEqual([], self.audit())
        self.rows[0]['other_repo_sha'] = 'e' * 40
        self.assertIn('UPSTREAM_OTHER_REPO_BINDING_MISMATCH:AC-00', self.audit())

    def test_empty_invalid_or_zero_other_repo_sha_cannot_pass(self):
        self.frozen['candidates']['imboyadmin'] = {'head': 'd' * 40}
        for value in ('', 'synthetic', '0' * 40, 'd' * 39):
            self.rows[0]['other_repo_sha'] = value
            self.assertIn('UPSTREAM_OTHER_REPO_BINDING_MISMATCH:AC-00', self.audit())

    def test_wrong_card_rejected_even_with_complete_ids_and_valid_hashes(self):
        self.rows[0]['card'] = 'C17'
        self.assertIn('UPSTREAM_ACCEPTANCE_CARD_MISMATCH:AC-00', self.audit())
        self.rows[0]['status'] = 'PARTIAL'
        errors = self.audit()
        self.assertIn('UPSTREAM_ACCEPTANCE_CARD_MISMATCH:AC-00', errors)
        self.assertIn('UPSTREAM_REQUIRED_NOT_PASS:AC-00', errors)

    def test_missing_extra_duplicate_and_unknown_ids_rejected(self):
        original = copy.deepcopy(self.rows)
        for rows in (original[:-1], original + [original[0]],
                     original[:-1] + [original[0]],
                     original[:-1] + [dict(original[-1], id='AC-99')]):
            self.rows = rows
            self.assertIn('UPSTREAM_ACCEPTANCE_SET_MISMATCH', self.audit())

    def test_partial_blocked_and_prototype_cannot_upgrade(self):
        for status in ('PARTIAL', 'BLOCKED_USER_AUTH', 'BLOCKED_DECISION', 'PROTOTYPE_PASS'):
            self.rows[0]['status'] = status
            self.assertIn('UPSTREAM_REQUIRED_NOT_PASS:AC-00', self.audit())

    def test_stale_plan_and_candidate_rejected(self):
        for field in ('plan_sha', 'backend_sha', 'app_sha'):
            original = self.rows[0][field]
            self.rows[0][field] = 'd' * len(original)
            self.assertIn('UPSTREAM_PASS_BINDING_MISMATCH:AC-00', self.audit())
            self.rows[0][field] = original

    def test_zero_failed_skip_or_huge_counts_rejected(self):
        for field, value in [('exit_code', '1'), ('exit_code', '-'),
                             ('test_count', '0'), ('test_count', '-'),
                             ('test_count', '9' * 5000)]:
            old = self.rows[0][field]
            self.rows[0][field] = value
            self.assertIn('UPSTREAM_PASS_EXECUTION_INVALID:AC-00', self.audit())
            self.rows[0][field] = old

    def test_missing_provenance_config_and_artifact_hash_rejected(self):
        for field in ('command_id', 'command', 'oracle', 'reviewer', 'completed_at',
                      'config_hash', 'evidence_sha256'):
            old = self.rows[0][field]
            self.rows[0][field] = '-'
            self.assertTrue(self.audit())
            self.rows[0][field] = old

    def test_tamper_symlink_and_changed_descriptor_rejected(self):
        descriptor = self.artifact()
        self.assertTrue(audit_upstream_ledger(self.root, self.frozen, {}))
        (self.root / 'ledger.tsv').write_bytes(b'changed')
        self.assertTrue(audit_upstream_ledger(self.root, self.frozen, descriptor))
        descriptor = self.artifact()
        (self.root / 'oracle').rename(self.root / 'actual-oracle')
        (self.root / 'oracle').symlink_to(self.root / 'actual-oracle')
        self.assertTrue(audit_upstream_ledger(self.root, self.frozen, descriptor))


if __name__ == '__main__':
    unittest.main()
