"""Synthetic snapshot calibration; never a real zero-write proof."""
import copy
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))
from auto_test_lib.billing_cancel_snapshots import audit_billing_cancel_snapshots


def fixture():
    context = dict(run_id='synthetic-run', attempt_id='synthetic-attempt',
                   fixture_generation='synthetic-generation', device_id='synthetic-device',
                   platform='android', backend_sha='a' * 40,
                   owner_uid='9007199254740993', tenant_id='0')
    stamp = '2026-10-03T00:00:00+00:00'
    subscription = dict(id='9007199254740995', tenant_id='0', plan_id='1',
                        owner_uid=context['owner_uid'], status=1,
                        current_period_start=stamp, current_period_end=stamp,
                        auto_renew=True, created_at=stamp, updated_at=stamp)
    invoice = dict(id='9007199254740997', invoice_no='synthetic-invoice',
                   subscription_id=subscription['id'], amount=100, currency='CNY',
                   status=0, payment_no=None, period_start=stamp, period_end=stamp,
                   paid_at=None, created_at=stamp, updated_at=stamp)
    return context, dict(schema_version=1, context=context,
                         subscriptions=[subscription], invoices=[invoice])


class BillingCancelSnapshots(unittest.TestCase):
    def test_unchanged_does_not_prove_zero_write(self):
        context, snapshot = fixture()
        result = audit_billing_cancel_snapshots(context, snapshot, copy.deepcopy(snapshot))
        self.assertEqual(result['errors'], [])
        self.assertTrue(result['state_unchanged'])
        self.assertFalse(result['zero_write_proven'])
        self.assertFalse(result['product_pass'])

    def test_update_is_detected_even_with_same_row_counts(self):
        context, before = fixture()
        after = copy.deepcopy(before)
        after['invoices'][0]['amount'] = 101
        self.assertIn('BILLING_STATE_CHANGED',
                      audit_billing_cancel_snapshots(context, before, after)['errors'])

    def test_owner_transfer_is_rejected(self):
        context, before = fixture()
        after = copy.deepcopy(before)
        after['subscriptions'][0]['owner_uid'] = '2'
        self.assertIn('BILLING_SUBSCRIPTION_SCOPE_INVALID',
                      audit_billing_cancel_snapshots(context, before, after)['errors'])

    def test_invoice_reassociation_is_rejected(self):
        context, before = fixture()
        after = copy.deepcopy(before)
        after['invoices'][0]['subscription_id'] = '2'
        self.assertIn('BILLING_INVOICE_SCOPE_INVALID',
                      audit_billing_cancel_snapshots(context, before, after)['errors'])

    def test_duplicate_rows_cannot_hide_missing_rows(self):
        context, snapshot = fixture()
        snapshot['invoices'].append(copy.deepcopy(snapshot['invoices'][0]))
        self.assertIn('BILLING_ROW_DUPLICATE',
                      audit_billing_cancel_snapshots(context, snapshot, snapshot)['errors'])

    def test_missing_column_is_rejected(self):
        context, snapshot = fixture()
        del snapshot['subscriptions'][0]['updated_at']
        self.assertIn('BILLING_ROW_SCHEMA_INVALID',
                      audit_billing_cancel_snapshots(context, snapshot, snapshot)['errors'])

    def test_float_or_boolean_money_is_rejected(self):
        for amount in [100.0, True]:
            context, snapshot = fixture()
            snapshot['invoices'][0]['amount'] = amount
            self.assertIn('BILLING_ROW_VALUE_INVALID',
                          audit_billing_cancel_snapshots(context, snapshot, snapshot)['errors'])

    def test_context_from_other_attempt_is_rejected(self):
        context, snapshot = fixture()
        after = copy.deepcopy(snapshot)
        after['context']['attempt_id'] = 'other'
        self.assertIn('BILLING_SNAPSHOT_CONTEXT_MISMATCH',
                      audit_billing_cancel_snapshots(context, snapshot, after)['errors'])

    def test_nullable_database_columns_preserve_unchanged_state(self):
        context, snapshot = fixture()
        for row, names in [(snapshot['subscriptions'][0],
                            ['current_period_start', 'current_period_end', 'updated_at']),
                           (snapshot['invoices'][0],
                            ['period_start', 'period_end', 'updated_at'])]:
            for name in names:
                row[name] = None
        snapshot['invoices'][0]['currency'] = 'USDT'
        self.assertEqual(audit_billing_cancel_snapshots(
            context, snapshot, copy.deepcopy(snapshot))['errors'], [])

    def test_null_to_timestamp_is_a_state_change(self):
        context, before = fixture()
        before['subscriptions'][0]['current_period_end'] = None
        after = copy.deepcopy(before)
        after['subscriptions'][0]['current_period_end'] = '2026-10-03T00:00:00+00:00'
        self.assertIn('BILLING_STATE_CHANGED',
                      audit_billing_cancel_snapshots(context, before, after)['errors'])

    def test_row_order_does_not_create_false_changes(self):
        context, snapshot = fixture()
        extra = dict(snapshot['invoices'][0], id='9007199254740999',
                     invoice_no='synthetic-second')
        snapshot['invoices'].append(extra)
        after = copy.deepcopy(snapshot)
        after['invoices'].reverse()
        self.assertEqual(audit_billing_cancel_snapshots(context, snapshot, after)['errors'], [])
