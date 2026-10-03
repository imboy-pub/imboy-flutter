"""Read-only semantic comparison of independently collected billing snapshots.

No resource access or authorization. Equal states cannot detect transient writes;
independent complete request/database audit evidence remains mandatory.
"""
import re
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

from auto_test_lib import acceptance, acceptance_contract

_CONTEXT = {'run_id', 'attempt_id', 'fixture_generation', 'device_id', 'platform',
            'backend_sha', 'owner_uid', 'tenant_id'}
_SUB = {'id', 'tenant_id', 'plan_id', 'owner_uid', 'status', 'current_period_start',
        'current_period_end', 'auto_renew', 'created_at', 'updated_at'}
_INV = {'id', 'invoice_no', 'subscription_id', 'amount', 'currency', 'status',
        'payment_no', 'period_start', 'period_end', 'paid_at', 'created_at', 'updated_at'}


def _identifier(value: Any, zero: bool = False) -> bool:
    if not isinstance(value, str) or not re.fullmatch(r'0|[1-9][0-9]{0,18}', value):
        return False
    return (zero or value != '0') and int(value) <= 9223372036854775807


def _context_valid(context: Any) -> bool:
    if not isinstance(context, dict) or set(context) != _CONTEXT:
        return False
    if any(not isinstance(v, str) or not v.strip() for v in context.values()):
        return False
    return (context['platform'] in {'android', 'macos'}
            and re.fullmatch(r'[0-9a-f]{40}', context['backend_sha']) is not None
            and context['backend_sha'] != '0' * 40
            and _identifier(context['owner_uid'])
            and _identifier(context['tenant_id'], zero=True))


def _timestamp(value: Any) -> bool:
    if not isinstance(value, str):
        return False
    try:
        stamp = datetime.fromisoformat(value.replace('Z', '+00:00'))
        return stamp.tzinfo is not None and stamp.utcoffset() == timedelta(0)
    except (ValueError, OverflowError):
        return False


def _row_values(row: dict, subscription: bool) -> bool:
    ids = ('id', 'tenant_id', 'plan_id', 'owner_uid') if subscription else ('id', 'subscription_id')
    if any(not _identifier(row[k], zero=k == 'tenant_id') for k in ids):
        return False
    dates = ('current_period_start', 'current_period_end') if subscription else ('period_start', 'period_end')
    if not _timestamp(row['created_at']):
        return False
    if any(row[k] is not None and not _timestamp(row[k]) for k in dates + ('updated_at',)):
        return False
    if type(row['status']) is not int or row['status'] not in (range(4) if subscription else range(3)):
        return False
    if subscription:
        return type(row['auto_renew']) is bool
    return (type(row['amount']) is int and 0 <= row['amount'] <= 9223372036854775807
            and isinstance(row['invoice_no'], str) and len(row['invoice_no']) <= 64
            and isinstance(row['currency'], str) and len(row['currency']) <= 8
            and (row['payment_no'] is None or
                 (isinstance(row['payment_no'], str) and len(row['payment_no']) <= 128))
            and (row['paid_at'] is None or _timestamp(row['paid_at'])))


def _rows(rows: Any, subscription: bool) -> tuple:
    if not isinstance(rows, list):
        return {}, ['BILLING_ROW_SCHEMA_INVALID']
    indexed = {}
    for row in rows:
        if not isinstance(row, dict) or set(row) != (_SUB if subscription else _INV):
            return {}, ['BILLING_ROW_SCHEMA_INVALID']
        if not _row_values(row, subscription):
            return {}, ['BILLING_ROW_VALUE_INVALID']
        if row['id'] in indexed:
            return {}, ['BILLING_ROW_DUPLICATE']
        indexed[row['id']] = dict(row)
    return indexed, []


def _snapshot(expected: dict, snapshot: Any) -> tuple:
    keys = {'schema_version', 'context', 'subscriptions', 'invoices'}
    if (not isinstance(snapshot, dict) or set(snapshot) != keys
            or type(snapshot['schema_version']) is not int or snapshot['schema_version'] != 1):
        return {}, ['BILLING_SNAPSHOT_SCHEMA_INVALID']
    if snapshot['context'] != expected:
        return {}, ['BILLING_SNAPSHOT_CONTEXT_MISMATCH']
    subs, sub_errors = _rows(snapshot['subscriptions'], True)
    invoices, inv_errors = _rows(snapshot['invoices'], False)
    errors = sub_errors + inv_errors
    if errors:
        return {}, errors
    if any(s['owner_uid'] != expected['owner_uid'] or s['tenant_id'] != expected['tenant_id']
           for s in subs.values()):
        errors.append('BILLING_SUBSCRIPTION_SCOPE_INVALID')
    if any(i['subscription_id'] not in subs for i in invoices.values()):
        errors.append('BILLING_INVOICE_SCOPE_INVALID')
    if len({i['invoice_no'] for i in invoices.values()}) != len(invoices):
        errors.append('BILLING_ROW_DUPLICATE')
    return {'subscriptions': subs, 'invoices': invoices}, errors


def audit_billing_cancel_snapshots(expected: Any, before: Any, after: Any) -> dict:
    """Compare full rows under caller-pinned context without issuing PASS.

    The caller must independently authenticate collection completeness, hashes,
    actual fixture/device/runtime bindings, and request/database write audits.
    The comparison alone always leaves zero_write_proven false.
    """
    result = {'scope': 'BILLING_SNAPSHOT_STATE_ONLY', 'errors': [],
              'state_unchanged': False, 'zero_write_proven': False, 'product_pass': False}
    if not _context_valid(expected):
        result['errors'] = ['BILLING_EXPECTED_CONTEXT_INVALID']
        return result
    first, errors = _snapshot(expected, before)
    second, other = _snapshot(expected, after)
    result['errors'] = list(dict.fromkeys(errors + other))
    if not result['errors']:
        if first != second:
            result['errors'].append('BILLING_STATE_CHANGED')
        else:
            result['state_unchanged'] = True
    return result


def audit_billing_cancel_artifacts(root: Path, expected: Any, artifacts: Any) -> dict:
    """Load caller-pinned before/after bytes using existing bounded safe reader.

    Pin descriptors independently of the report. Hash integrity does not prove
    collection completeness, timing, authenticity or absence of transient writes.
    Distinct paths are required; identical content is expected for unchanged state.
    """
    result = {'scope': 'BILLING_SNAPSHOT_ARTIFACT_STATE_ONLY', 'errors': [],
              'state_unchanged': False, 'zero_write_proven': False, 'product_pass': False}
    if not _context_valid(expected):
        result['errors'] = ['BILLING_EXPECTED_CONTEXT_INVALID']
        return result
    if not isinstance(artifacts, dict) or set(artifacts) != {'before', 'after'}:
        result['errors'] = ['BILLING_SNAPSHOT_ARTIFACT_SET_INVALID']
        return result
    descriptors = list(artifacts.values())
    if all(isinstance(item, dict) for item in descriptors) and (
            descriptors[0].get('path') == descriptors[1].get('path')):
        result['errors'] = ['BILLING_SNAPSHOT_CAPTURE_PATH_REUSED']
        return result
    snapshots = {}
    for stage in ('before', 'after'):
        snapshots[stage], errors = acceptance.load_frozen_json(root, artifacts[stage])
        result['errors'].extend(stage + ':' + error for error in errors)
    if not result['errors']:
        result.update(audit_billing_cancel_snapshots(
            expected, snapshots['before'], snapshots['after']))
        result['scope'] = 'BILLING_SNAPSHOT_ARTIFACT_STATE_ONLY'
    return result


def _case_link_errors(frozen: dict, context: dict, key: Any) -> list:
    """Bind a specific frozen case to this attempt without changing its oracle."""
    if (not isinstance(key, list) or len(key) != 4 or any(
            not isinstance(part, str) or not part.strip() for part in key)
            or key[1] != context['platform']):
        return ['BILLING_SNAPSHOT_CASE_KEY_INVALID']
    baseline = acceptance_contract._case_index(frozen.get('required_cases'))
    if baseline is None or tuple(key) not in baseline:
        return ['BILLING_SNAPSHOT_CASE_UNKNOWN']
    runs = frozen.get('case_event_runs')
    if not isinstance(runs, list):
        return ['BILLING_SNAPSHOT_CASE_ATTEMPT_MISMATCH']
    matches = [run for run in runs if isinstance(run, dict)
               and run.get('attempt_id') == context['attempt_id']]
    if len(matches) != 1:
        return ['BILLING_SNAPSHOT_CASE_ATTEMPT_MISMATCH']
    cases = acceptance_contract._case_index(matches[0].get('required_cases'))
    if cases is None or cases.get(tuple(key)) != baseline[tuple(key)]:
        return ['BILLING_SNAPSHOT_CASE_ATTEMPT_MISMATCH']
    return []


def _attempt_device_errors(root: Path, frozen: dict, context: dict) -> list:
    """Link to pinned run/device records; does not authenticate their producer."""
    runs, bindings = frozen.get('case_event_runs'), frozen.get('runtime_bindings')
    if not isinstance(runs, list) or not isinstance(bindings, list):
        return ['BILLING_SNAPSHOT_ATTEMPT_LINK_INVALID']
    matches = [run for run in runs if isinstance(run, dict)
               and run.get('attempt_id') == context['attempt_id']]
    if len(matches) != 1:
        return ['BILLING_SNAPSHOT_ATTEMPT_LINK_INVALID']
    run = matches[0]
    cases = run.get('required_cases')
    if (not isinstance(cases, list) or not cases or any(
            not isinstance(case, dict) or case.get('platform') != context['platform']
            for case in cases)):
        return ['BILLING_SNAPSHOT_ATTEMPT_PLATFORM_MISMATCH']
    identifier = run.get('device_binding_id')
    if not isinstance(identifier, str) or not identifier.strip():
        return ['BILLING_SNAPSHOT_DEVICE_BINDING_INVALID']
    devices = [row for row in bindings if isinstance(row, dict)
               and row.get('binding_id') == identifier]
    if len(devices) != 1 or devices[0].get('kind') != 'device':
        return ['BILLING_SNAPSHOT_DEVICE_BINDING_INVALID']
    device, errors = acceptance.load_frozen_json(root, devices[0].get('artifact'))
    if errors:
        return errors
    if not isinstance(device, dict) or any(device.get(k) != context[k] for k in
            ('run_id', 'fixture_generation', 'device_id', 'platform')):
        return ['BILLING_SNAPSHOT_DEVICE_MISMATCH']
    return []


def _cancel_case_obligation_errors(frozen: dict, obligations: list) -> list:
    """Require snapshots for every explicitly declared generated cancel case."""
    cases = frozen.get('required_cases', [])
    if not isinstance(cases, list):
        return ['BILLING_CANCEL_CASE_OBLIGATION_SET_MISMATCH']
    required = set()
    for case in cases:
        if not isinstance(case, dict):
            return ['BILLING_CANCEL_CASE_OBLIGATION_SET_MISMATCH']
        seeds = case.get('seed_ids', [])
        if not isinstance(seeds, list) or any(not isinstance(seed, str) for seed in seeds):
            return ['BILLING_CANCEL_CASE_OBLIGATION_SET_MISMATCH']
        if 'fn:billing:plan_list_page:004' in seeds:
            key = tuple(case.get(k) for k in acceptance_contract._KEY_FIELDS)
            if any(not isinstance(k, str) or not k.strip() for k in key):
                return ['BILLING_CANCEL_CASE_OBLIGATION_SET_MISMATCH']
            required.add(key)
    keys = [obligation.get('case_key') for obligation in obligations]
    if any(not isinstance(key, list) or len(key) != 4 or any(
            not isinstance(part, str) for part in key) for key in keys):
        return ['BILLING_CANCEL_CASE_OBLIGATION_SET_MISMATCH']
    actual = [tuple(key) for key in keys]
    if len(actual) != len(set(actual)) or set(actual) != required:
        return ['BILLING_CANCEL_CASE_OBLIGATION_SET_MISMATCH']
    return []


def audit_billing_cancel_set(root: Path, frozen: Any, records: Any) -> list:
    """Bind declared cancel cases; independent coverage discovery/audits required."""
    if not isinstance(frozen, dict):
        return ['BILLING_FROZEN_OBLIGATIONS_INVALID']
    obligations = frozen.get('billing_cancel_snapshots')
    if not isinstance(obligations, list) or not isinstance(records, dict):
        return ['BILLING_FROZEN_OBLIGATIONS_INVALID']
    indexed = {}
    for obligation in obligations:
        if not isinstance(obligation, dict) or set(obligation) != {'id', 'context', 'case_key'}:
            return ['BILLING_FROZEN_OBLIGATIONS_INVALID']
        identifier, context = obligation['id'], obligation['context']
        if (not isinstance(identifier, str) or not identifier.strip()
                or identifier in indexed or not _context_valid(context)):
            return ['BILLING_FROZEN_OBLIGATIONS_INVALID']
        try:
            if (context['run_id'] != frozen['run_id']
                    or context['fixture_generation'] != frozen['fixture_generation']
                    or context['backend_sha'] != frozen['candidates']['imboy']['head']):
                return ['BILLING_FROZEN_RUNTIME_MISMATCH']
        except (KeyError, TypeError):
            return ['BILLING_FROZEN_RUNTIME_MISMATCH']
        indexed[identifier] = obligation
    if set(records) != set(indexed):
        return ['BILLING_SNAPSHOT_RECORDED_SET_MISMATCH']
    coverage_errors = _cancel_case_obligation_errors(frozen, obligations)
    if coverage_errors:
        return coverage_errors
    errors, paths = [], set()
    for identifier, obligation in indexed.items():
        context = obligation['context']
        link_errors = _case_link_errors(frozen, context, obligation['case_key'])
        link_errors.extend(_attempt_device_errors(root, frozen, context))
        errors.extend(link_errors)
        if link_errors:
            continue
        result = audit_billing_cancel_artifacts(root, context, records[identifier])
        errors.extend(result['errors'])
        if result['errors']:
            continue
        for descriptor in records[identifier].values():
            if descriptor['path'] in paths:
                errors.append('BILLING_SNAPSHOT_CAPTURE_REUSED_ACROSS_OBLIGATIONS')
            paths.add(descriptor['path'])
    return errors
