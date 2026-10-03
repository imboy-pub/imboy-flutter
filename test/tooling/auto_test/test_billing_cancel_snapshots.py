"""Synthetic snapshot calibration; never a real zero-write proof."""
import copy
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))
from auto_test_lib.billing_cancel_snapshots import audit_billing_cancel_snapshots
from auto_test_lib import billing_cancel_snapshots


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


def write_artifact(root, name, value):
    data = json.dumps(value).encode()
    (root / name).write_bytes(data)
    return dict(path=name, sha256=hashlib.sha256(data).hexdigest())


def composed_fixture(root):
    context, snapshot = fixture()
    case = dict(case_id='cancel', platform='android', profile='local', role_variant='owner',
                parent_acceptance_ids=['F14-A01'], seed_ids=['fn:billing:plan_list_page:004'],
                oracle='cancel sheet with independent audit', applicability='REQUIRED')
    key = [case[k] for k in ('case_id', 'platform', 'profile', 'role_variant')]
    device = {k: context[k] for k in ('run_id', 'fixture_generation', 'device_id', 'platform')}
    frozen = dict(run_id=context['run_id'], fixture_generation=context['fixture_generation'],
                  candidates={'imboy': {'head': context['backend_sha']}}, required_cases=[case],
                  billing_cancel_snapshots=[dict(id='cancel', context=context, case_key=key)],
                  case_event_runs=[dict(attempt_id=context['attempt_id'], device_binding_id='device',
                                       required_cases=[copy.deepcopy(case)])],
                  runtime_bindings=[dict(binding_id='device', kind='device',
                                        artifact=write_artifact(root, 'device.json', device))])
    records = {'cancel': {stage: write_artifact(root, stage + '.json', snapshot)
                          for stage in ('before', 'after')}}
    return frozen, records, snapshot


class BillingCancelSnapshots(unittest.TestCase):
    def test_complete_nonempty_composition_and_negative_samples(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            frozen, records, snapshot = composed_fixture(root)
            audit = billing_cancel_snapshots.audit_billing_cancel_set
            self.assertEqual(audit(root, frozen, records), [])
            for field, value in [('attempt_id', 'wrong'), ('device_id', 'wrong')]:
                changed = copy.deepcopy(frozen)
                changed['billing_cancel_snapshots'][0]['context'][field] = value
                self.assertTrue(audit(root, changed, records), field)
            changed = copy.deepcopy(frozen)
            changed['billing_cancel_snapshots'][0]['case_key'][0] = 'unrelated'
            self.assertTrue(audit(root, changed, records))
            after = copy.deepcopy(snapshot)
            after['invoices'][0]['amount'] += 1
            records['cancel']['after'] = write_artifact(root, 'after.json', after)
            self.assertIn('BILLING_STATE_CHANGED', audit(root, frozen, records))

    def test_unrelated_attempt_cannot_supply_case_oracle(self):
        context, _ = fixture()
        case = dict(case_id='cancel', platform='android', profile='local',
                    role_variant='owner', parent_acceptance_ids=['F14-A01'],
                    seed_ids=['fn:billing:plan_list_page:004'],
                    oracle='cancel sheet and independent audit', applicability='REQUIRED')
        key = [case[k] for k in ('case_id', 'platform', 'profile', 'role_variant')]
        frozen = dict(required_cases=[case], case_event_runs=[dict(
            attempt_id=context['attempt_id'], required_cases=[dict(case, case_id='unrelated')])])
        self.assertIn('BILLING_SNAPSHOT_CASE_ATTEMPT_MISMATCH',
                      billing_cancel_snapshots._case_link_errors(frozen, context, key))
        frozen['case_event_runs'][0]['required_cases'] = [copy.deepcopy(case)]
        self.assertEqual(billing_cancel_snapshots._case_link_errors(frozen, context, key), [])
        frozen['case_event_runs'][0]['required_cases'][0]['oracle'] = 'changed'
        self.assertIn('BILLING_SNAPSHOT_CASE_ATTEMPT_MISMATCH',
                      billing_cancel_snapshots._case_link_errors(frozen, context, key))

    def test_missing_attempt_cannot_supply_snapshots(self):
        context, _ = fixture()
        self.assertIn('BILLING_SNAPSHOT_ATTEMPT_LINK_INVALID',
                      billing_cancel_snapshots._attempt_device_errors(
                          Path('.'), {'case_event_runs': []}, context))

    def test_attempt_device_snapshot_must_match_context(self):
        context, _ = fixture()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            device = {k: context[k] for k in
                      ('run_id', 'fixture_generation', 'device_id', 'platform')}
            data = json.dumps(device).encode()
            (root / 'device.json').write_bytes(data)
            frozen = dict(case_event_runs=[dict(attempt_id=context['attempt_id'],
                device_binding_id='device', required_cases=[dict(platform='android')])],
                runtime_bindings=[dict(binding_id='device', kind='device',
                    artifact=dict(path='device.json', sha256=hashlib.sha256(data).hexdigest()))])
            audit = billing_cancel_snapshots._attempt_device_errors
            self.assertEqual(audit(root, frozen, context), [])
            other = dict(context, device_id='other-device')
            self.assertIn('BILLING_SNAPSHOT_DEVICE_MISMATCH', audit(root, frozen, other))
            frozen['case_event_runs'].append(copy.deepcopy(frozen['case_event_runs'][0]))
            self.assertIn('BILLING_SNAPSHOT_ATTEMPT_LINK_INVALID', audit(root, frozen, context))

    def test_frozen_obligations_are_explicit_and_exact(self):
        audit = billing_cancel_snapshots.audit_billing_cancel_set
        self.assertTrue(audit(Path('.'), {}, {}))
        self.assertEqual(audit(Path('.'), {'billing_cancel_snapshots': []}, {}), [])
        self.assertTrue(audit(Path('.'), {'billing_cancel_snapshots': []}, {'extra': {}}))

    def test_obligations_reject_runtime_drift(self):
        context, _ = fixture()
        frozen = dict(billing_cancel_snapshots=[dict(id='cancel', context=context,
                      case_key=['cancel', 'android', 'local', 'owner'])],
                      run_id='different', fixture_generation=context['fixture_generation'],
                      candidates={'imboy': {'head': context['backend_sha']}})
        self.assertIn('BILLING_FROZEN_RUNTIME_MISMATCH',
                      billing_cancel_snapshots.audit_billing_cancel_set(
                          Path('.'), frozen, {'cancel': {}}))

    def test_pinned_artifacts_compare_complete_rows(self):
        context, snapshot = fixture()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            data = json.dumps(snapshot).encode()
            descriptors = {}
            for stage in ('before', 'after'):
                name = stage + '.json'
                (root / name).write_bytes(data)
                descriptors[stage] = dict(path=name, sha256=hashlib.sha256(data).hexdigest())
            result = billing_cancel_snapshots.audit_billing_cancel_artifacts(
                root, context, descriptors)
            self.assertTrue(result['state_unchanged'])
            self.assertFalse(result['zero_write_proven'])
            self.assertFalse(result['product_pass'])
            (root / 'after.json').write_text('{}')
            result = billing_cancel_snapshots.audit_billing_cancel_artifacts(
                root, context, descriptors)
            self.assertFalse(result['state_unchanged'])
            self.assertTrue(result['errors'])

    def test_artifact_gate_rejects_missing_or_reused_capture(self):
        context, _ = fixture()
        descriptor = dict(path='same.json', sha256='a' * 64)
        for records in ({}, {'before': descriptor, 'after': descriptor}):
            result = billing_cancel_snapshots.audit_billing_cancel_artifacts(
                Path('.'), context, records)
            self.assertFalse(result['state_unchanged'])
            self.assertTrue(result['errors'])

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
