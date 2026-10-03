import copy
import hashlib
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'scripts'))
from auto_test_lib.acceptance_upstream_commands import audit_upstream_command_links
import test_acceptance_upstream as ledger_tests


class UpstreamCommandTests(unittest.TestCase):
    def setUp(self):
        self.ledger = ledger_tests.UpstreamLedgerTests()
        self.ledger.setUp()
        self.addCleanup(self.ledger.doCleanups)
        self.root = self.ledger.root
        self.ledger.artifact()
        self.frozen = self.ledger.frozen
        self.records = [{'command_id': self.ledger.rows[0]['command_id'],
            **{field: self.ledger.rows[0][field] for field in ('command', 'exit_code',
                'test_count', 'config_hash', 'evidence_path', 'evidence_sha256')}}]

    def descriptor(self):
        raw = json.dumps({'commands': self.records}).encode()
        (self.root / 'commands.json').write_bytes(raw)
        descriptor = {'path': 'commands.json', 'sha256': hashlib.sha256(raw).hexdigest()}
        self.frozen['upstream_commands_artifact'] = descriptor
        return descriptor

    def audit(self):
        return audit_upstream_command_links(self.root, self.frozen, self.descriptor())

    def test_shared_command_record_links_all_36_requirements(self):
        self.assertEqual([], self.audit())

    def test_each_execution_config_and_log_field_must_match(self):
        for field in ('command', 'exit_code', 'test_count', 'config_hash',
                      'evidence_path', 'evidence_sha256'):
            original = self.records[0][field]
            self.records[0][field] = 'different'
            self.assertIn('UPSTREAM_COMMAND_RECORD_MISMATCH:AC-00', self.audit())
            self.records[0][field] = original

    def test_missing_unknown_and_duplicate_commands_rejected(self):
        original = copy.deepcopy(self.records)
        self.records = []
        self.assertIn('UPSTREAM_COMMAND_REGISTRY_SCHEMA_INVALID', self.audit())
        self.records = original + [dict(original[0], command_id='unknown')]
        self.assertIn('UPSTREAM_COMMAND_SET_MISMATCH', self.audit())
        self.records = original + original
        self.assertIn('UPSTREAM_COMMAND_REGISTRY_SCHEMA_INVALID', self.audit())

    def test_registry_must_match_frozen_descriptor(self):
        self.descriptor()
        self.assertIn('UPSTREAM_COMMAND_REGISTRY_BINDING_CHANGED',
            audit_upstream_command_links(self.root, self.frozen, None))

    def test_boolean_exit_and_numeric_counts_are_not_tsv_values(self):
        self.records[0]['exit_code'] = False
        self.assertIn('UPSTREAM_COMMAND_REGISTRY_SCHEMA_INVALID', self.audit())
        self.records[0]['exit_code'] = '0'
        self.records[0]['test_count'] = 1
        self.assertIn('UPSTREAM_COMMAND_REGISTRY_SCHEMA_INVALID', self.audit())

    def test_registry_tamper_and_symlink_rejected(self):
        descriptor = self.descriptor()
        (self.root / 'commands.json').write_bytes(b'changed')
        self.assertTrue(audit_upstream_command_links(self.root, self.frozen, descriptor))
        descriptor = self.descriptor()
        (self.root / 'commands.json').rename(self.root / 'actual.json')
        (self.root / 'commands.json').symlink_to(self.root / 'actual.json')
        self.assertTrue(audit_upstream_command_links(self.root, self.frozen, descriptor))
