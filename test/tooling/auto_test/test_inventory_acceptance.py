"""Static inventory readiness cannot accept generated business placeholders."""
import copy
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'scripts'))
from auto_test_lib import inventory


class InventoryAcceptanceTests(unittest.TestCase):
    def setUp(self):
        self.function = {'disposition': 'required', 'expected_oracle':
                         'sender and receiver show the same persisted message',
                         'details': '', 'test_target': 'test/synthetic_test.dart'}

    def audit(self, function=None):
        return inventory.acceptance_readiness_errors(
            {'functions': [self.function if function is None else function]})

    def test_concrete_structural_entry_has_no_readiness_error(self):
        self.assertEqual(self.audit(), [])

    def test_generated_placeholder_rejected_even_with_target(self):
        for field, value in (('expected_oracle', 'expect(<控件可观察状态>)'),
                             ('details', 'GENERATED_ORACLE_PLACEHOLDER; extraction')):
            row = copy.deepcopy(self.function)
            row[field] = value
            self.assertTrue(self.audit(row))

    def test_required_function_without_target_rejected(self):
        row = dict(self.function, test_target=None)
        self.assertTrue(self.audit(row))

    def test_empty_or_malformed_inventory_rejected(self):
        for value in (None, {}, {'functions': []}, {'functions': [False]}):
            self.assertTrue(inventory.acceptance_readiness_errors(value))

    def test_missing_or_unknown_disposition_cannot_hide_required_function(self):
        for value in (None, 'NOT_APPLICABLE', 'excluded', 'optional'):
            self.assertTrue(self.audit(dict(self.function, disposition=value)))

    def test_acceptance_check_refuses_write_before_generation(self):
        with patch.object(inventory, 'generate_inventory') as generator:
            self.assertNotEqual(inventory.main(
                ['--acceptance-check', '--write-ledgers']), 0)
            generator.assert_not_called()


if __name__ == '__main__':
    unittest.main()
