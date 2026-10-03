"""Cross-device raw-record correlation only; cannot certify product behavior.

Pinned records must still be produced by qualified capture adapters and reviewed
against real devices/storage. A structurally valid synthetic fixture is not PASS.
"""
from typing import Any, Dict, List
from pathlib import Path
import re

from auto_test_lib import acceptance, acceptance_contract

_STAGES = ('sender_ui', 'persistence', 'receiver_ui', 'reopened_ui')
_BINDINGS = ('run_id', 'journey_id', 'message_id', 'fixture_generation',
             'app_sha', 'backend_sha', 'admin_sha', 'payload_sha256')
_KINDS = ('ui_observation', 'database_query', 'ui_observation', 'ui_observation')


def _expected_errors(expected: Any) -> List[str]:
    if not isinstance(expected, dict):
        return ['JOURNEY_EXPECTATION_INVALID']
    keys = (*_BINDINGS, 'sender_device', 'receiver_device')
    if any(not isinstance(expected.get(k), str) or not expected[k].strip() for k in keys):
        return ['JOURNEY_EXPECTATION_INVALID']
    for key in ('app_sha', 'backend_sha', 'admin_sha'):
        if not re.fullmatch(r'[0-9a-f]{40}', expected[key]) or expected[key] == '0' * 40:
            return ['JOURNEY_CANDIDATE_INVALID']
    if not re.fullmatch(r'[0-9a-f]{64}', expected['payload_sha256']):
        return ['JOURNEY_PAYLOAD_DIGEST_INVALID']
    if expected['sender_device'] == expected['receiver_device']:
        return ['JOURNEY_REQUIRES_DISTINCT_DEVICES']
    return []


def _record_errors(record: Any, expected: dict, stage: str, kind: str) -> List[str]:
    if not isinstance(record, dict):
        return ['JOURNEY_RECORD_INVALID:' + stage]
    errors = []
    if any(record.get(k) != expected[k] for k in _BINDINGS):
        errors.append('JOURNEY_BINDING_MISMATCH:' + stage)
    if record.get('stage') != stage or record.get('capture_kind') != kind:
        errors.append('JOURNEY_CAPTURE_KIND_MISMATCH:' + stage)
    if record.get('observed') is not True:
        errors.append('JOURNEY_OBSERVATION_MISSING:' + stage)
    if stage != 'persistence':
        device = expected['sender_device' if stage == 'sender_ui' else 'receiver_device']
        if record.get('device_id') != device:
            errors.append('JOURNEY_DEVICE_MISMATCH:' + stage)
        if type(record.get('launch_generation')) is not int or record['launch_generation'] < 1:
            errors.append('JOURNEY_LAUNCH_GENERATION_INVALID:' + stage)
    return errors


def audit_cross_device_records(root: Path, expected: Any, artifacts: Any) -> Dict[str, Any]:
    """Read independently pinned records; do not trust a summary verdict."""
    result = {'scope': 'CROSS_DEVICE_RECORD_CORRELATION_ONLY',
              'product_pass': False, 'errors': _expected_errors(expected)}
    if not isinstance(artifacts, dict) or set(artifacts) != set(_STAGES):
        result['errors'].append('JOURNEY_REQUIRED_STAGE_SET_MISMATCH')
    if result['errors']:
        return result
    records, paths, digests = {}, set(), set()
    for stage, kind in zip(_STAGES, _KINDS):
        descriptor = artifacts[stage]
        record, errors = acceptance.load_frozen_json(root, descriptor)
        result['errors'].extend(stage + ':' + error for error in errors)
        if errors:
            continue
        path, digest = descriptor['path'], descriptor['sha256']
        if path in paths or digest in digests:
            result['errors'].append('JOURNEY_RECORD_REUSED:' + stage)
        paths.add(path)
        digests.add(digest)
        records[stage] = record
        result['errors'].extend(_record_errors(record, expected, stage, kind))
    if not result['errors']:
        if records['reopened_ui']['launch_generation'] <= records['receiver_ui']['launch_generation']:
            result['errors'].append('JOURNEY_REOPEN_NOT_NEW_LAUNCH')
    return result


def _journey_members(frozen: dict) -> tuple:
    cases = frozen.get('required_cases')
    if acceptance_contract._case_index(cases) is None:
        return {}, ['JOURNEY_REQUIRED_CASE_SET_INVALID']
    members = {}
    for row in cases:
        identifiers = row.get('cross_device_journey_ids')
        if (not isinstance(identifiers, list)
                or any(not isinstance(i, str) or not i.strip() for i in identifiers)
                or len(set(identifiers)) != len(identifiers)):
            return {}, ['JOURNEY_CASE_DECLARATION_INVALID']
        for identifier in identifiers:
            members.setdefault(identifier, set()).add(row['platform'])
    if any(platforms != {'android', 'macos'} for platforms in members.values()):
        return {}, ['JOURNEY_REQUIRES_BOTH_PLATFORMS']
    return members, []


def _journey_expectations(frozen: dict) -> tuple:
    members, errors = _journey_members(frozen)
    rows = frozen.get('cross_device_journeys')
    if errors or not isinstance(rows, list):
        return {}, errors or ['FROZEN_JOURNEY_SET_INVALID']
    indexed = {}
    for expected in rows:
        errors = _expected_errors(expected)
        if errors:
            return {}, errors
        identifier = expected['journey_id']
        if identifier in indexed:
            return {}, ['FROZEN_JOURNEY_DUPLICATE']
        indexed[identifier] = expected
        if any(expected[k] != frozen.get(k) for k in ('run_id', 'fixture_generation')):
            return {}, ['JOURNEY_FROZEN_RUNTIME_MISMATCH']
        for repo, key in [('imboyapp', 'app_sha'), ('imboy', 'backend_sha'), ('imboyadmin', 'admin_sha')]:
            candidates = frozen.get('candidates')
            candidate = candidates.get(repo) if isinstance(candidates, dict) else None
            if not isinstance(candidate, dict) or candidate.get('head') != expected[key]:
                return {}, ['JOURNEY_FROZEN_CANDIDATE_MISMATCH']
    if set(indexed) != set(members):
        return {}, ['JOURNEY_REQUIRED_MEMBERSHIP_MISMATCH']
    return indexed, []


def audit_cross_device_journey_set(root: Path, frozen: Any, records: Any) -> List[str]:
    """Mandatory explicit declarations; exact set, candidate links and no reuse."""
    if not isinstance(frozen, dict):
        return ['FROZEN_JOURNEY_SET_INVALID']
    expected, errors = _journey_expectations(frozen)
    if errors:
        return errors
    if not isinstance(records, dict) or set(records) != set(expected):
        return ['JOURNEY_RECORDED_SET_MISMATCH']
    paths, digests = set(), set()
    for identifier, obligation in expected.items():
        artifacts = records[identifier]
        result = audit_cross_device_records(root, obligation, artifacts)
        errors.extend(result['errors'])
        if result['errors']:
            continue
        for descriptor in artifacts.values():
            path, digest = descriptor['path'], descriptor['sha256']
            if path in paths or digest in digests:
                errors.append('JOURNEY_ARTIFACT_REUSED_ACROSS_JOURNEYS')
            paths.add(path)
            digests.add(digest)
    return errors
