"""Synthetic attempt-journal retention tests; no product execution claims."""
import copy
import hashlib
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'scripts'))
from auto_test_lib import acceptance_attempts


class AttemptJournalTests(unittest.TestCase):
    def setUp(self):
        self.records = [{'attempt_id': 'synthetic-red', 'exit': 1, 'status': 'FAIL'},
                        {'attempt_id': 'synthetic-green', 'exit': 0, 'status': 'PASS'}]
        self.index = [{'attempt_id': row['attempt_id'], 'record_sha256':
                       hashlib.sha256(json.dumps(row, sort_keys=True, ensure_ascii=False,
                           allow_nan=False, separators=(',', ':')).encode()).hexdigest()}
                      for row in self.records]

    def audit(self, records):
        return acceptance_attempts.validate_attempt_journal(self.index, records)

    def test_retained_failure_and_success_are_integrity_valid(self):
        self.assertEqual(self.audit(copy.deepcopy(self.records)), [])

    def test_only_last_green_dropped_or_reordered_records_fail(self):
        for rows in [self.records[1:], [], list(reversed(self.records)),
                     self.records + [{'attempt_id': 'unknown'}]]:
            self.assertIn('ATTEMPT_HISTORY_MISSING_UNKNOWN_OR_REORDERED', self.audit(rows))

    def test_duplicate_ids_and_malformed_records_fail(self):
        self.assertEqual(self.audit(self.records * 2), ['ATTEMPT_JOURNAL_DUPLICATE'])
        for rows in [None, [False], [{'attempt_id': []}]]:
            self.assertEqual(self.audit(rows), ['ATTEMPT_JOURNAL_SCHEMA_INVALID'])

    def test_rewritten_failure_or_type_changed_field_is_rejected(self):
        for value in [0, True, 1.0]:
            rows = copy.deepcopy(self.records)
            rows[0]['exit'] = value
            self.assertEqual(self.audit(rows), ['FROZEN_ATTEMPT_RECORD_CHANGED'])

    def test_invalid_frozen_indexes_cannot_pass(self):
        for index in [[], None, [False], self.index * 2,
                      [dict(self.index[0], record_sha256='invalid')]]:
            self.assertTrue(acceptance_attempts.validate_attempt_journal(index, self.records))

    def test_invalid_serialization_returns_fixed_error(self):
        for value in [float('nan'), float('inf'), {'not-json'}, '\ud800']:
            rows = copy.deepcopy(self.records)
            rows[0]['metadata'] = value
            errors = self.audit(rows)
            self.assertEqual(errors, ['ATTEMPT_RECORD_UNSERIALIZABLE'])
        deep = 'synthetic'
        for _ in range(sys.getrecursionlimit() + 10):
            deep = [deep]
        rows = copy.deepcopy(self.records)
        rows[0]['metadata'] = deep
        self.assertEqual(self.audit(rows), ['ATTEMPT_RECORD_UNSERIALIZABLE'])


if __name__ == '__main__':
    unittest.main()
