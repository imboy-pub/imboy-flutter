"""Frozen input-to-case coverage gate; source and business truth are separate."""
from typing import Any, List

from auto_test_lib import acceptance_contract, acceptance_attempts

_KINDS = {'seed', 'generated', 'page', 'api', 'ws', 'admin'}
_SENTINELS = {'TODO', 'TBD', 'PENDING', 'PLACEHOLDER', 'UNKNOWN', '待补', '待确认'}


def _meaningful(value: Any) -> bool:
    return (isinstance(value, str) and bool(value.strip())
            and value.strip().upper() not in _SENTINELS
            and not value.strip().upper().startswith(('TODO:', 'PENDING:', 'TBD:')))


def _input_keys(rows: Any) -> set:
    if not isinstance(rows, list) or not rows:
        raise ValueError('empty inputs')
    keys = set()
    for row in rows:
        if not isinstance(row, dict) or set(row) != {'input_kind', 'input_id'}:
            raise ValueError('invalid input')
        key = (row['input_kind'], row['input_id'])
        if key[0] not in _KINDS or not _meaningful(key[1]) or key in keys:
            raise ValueError('invalid input key')
        keys.add(key)
    if {kind for kind, _ in keys} != _KINDS:
        raise ValueError('missing input domain')
    return keys


def _approval_hashes(rows: list) -> set:
    hashes = set()
    for row in rows:
        digest = acceptance_attempts._record_hash(row)
        if (not isinstance(row, dict) or row.get('disposition') not in ('DELETED', 'MERGED')
                or digest is None or digest in hashes):
            raise ValueError('invalid approved disposition')
        hashes.add(digest)
    return hashes


def _owner_source_valid(row: dict) -> bool:
    return (_meaningful(row.get('owner'))
            and acceptance_contract._unique_strings(row.get('source_refs'))
            and all(_meaningful(ref) for ref in row['source_refs']))


def audit_input_case_coverage(frozen_inputs: Any, frozen_cases: Any,
                             mappings: Any, approved_dispositions: Any) -> List[str]:
    """Require exact coverage against independently frozen inputs and approvals."""
    try:
        expected = _input_keys(frozen_inputs)
        cases = acceptance_contract._case_index(frozen_cases)
        if cases is None or any(not _meaningful(row['oracle']) for row in frozen_cases):
            return ['COVERAGE_REQUIRED_CASES_INVALID_OR_PLACEHOLDER']
        if not isinstance(mappings, list) or not isinstance(approved_dispositions, list):
            return ['COVERAGE_MAPPING_SCHEMA_INVALID']
        approved = _approval_hashes(approved_dispositions)
        seen, covered = set(), set()
        for row in mappings:
            if not isinstance(row, dict):
                return ['COVERAGE_MAPPING_SCHEMA_INVALID']
            key = (row.get('input_kind'), row.get('input_id'))
            if key in seen or key not in expected:
                return ['COVERAGE_INPUT_DUPLICATE_OR_UNKNOWN']
            seen.add(key)
            if not _owner_source_valid(row):
                return ['COVERAGE_OWNER_OR_SOURCE_MISSING']
            raw_keys = row.get('case_keys')
            if not isinstance(raw_keys, list):
                return ['COVERAGE_CASE_KEYS_INVALID']
            keys = [tuple(values) for values in raw_keys if isinstance(values, list)]
            if (len(keys) != len(raw_keys) or len(set(keys)) != len(keys)
                    or any(key not in cases for key in keys)):
                return ['COVERAGE_CASE_KEYS_INVALID']
            disposition = row.get('disposition')
            if disposition == 'CASE_MAPPED':
                if not keys:
                    return ['COVERAGE_INPUT_WITHOUT_CASE']
            elif disposition in ('DELETED', 'MERGED'):
                if bool(keys) != (disposition == 'MERGED'):
                    return ['COVERAGE_DISPOSITION_CASE_KEYS_INVALID']
                if (not _meaningful(row.get('approval_ref'))
                        or acceptance_attempts._record_hash(row) not in approved):
                    return ['COVERAGE_DISPOSITION_NOT_IN_FROZEN_APPROVALS']
            else:
                return ['COVERAGE_DISPOSITION_INVALID']
            covered.update(keys)
        errors = []
        if seen != expected:
            errors.append('COVERAGE_INPUT_MISSING')
        if covered != set(cases):
            errors.append('COVERAGE_REQUIRED_CASE_UNMAPPED')
        return errors
    except (ValueError, TypeError, KeyError, RecursionError, UnicodeError):
        return ['COVERAGE_FROZEN_INPUT_OR_MAPPING_INVALID']
