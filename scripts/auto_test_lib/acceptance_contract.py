"""Read-only frozen required-case collection gate for F01.

The caller must load baseline cases and acceptance IDs from independently
hash-verified frozen inputs, never from the report being audited. This module
checks collection equality only, not execution or product qualification.
"""
import json
from typing import Any, Dict, List, Optional, Tuple

_KEY_FIELDS = ('case_id', 'platform', 'profile', 'role_variant')


def _unique_strings(value: Any) -> bool:
    return (isinstance(value, list) and bool(value)
            and all(isinstance(item, str) and item.strip() for item in value)
            and len(value) == len(set(value)))


def _case_index(rows: Any) -> Optional[Dict[Tuple[str, ...], str]]:
    if not isinstance(rows, list) or not rows:
        return None
    indexed: Dict[Tuple[str, ...], str] = {}
    for row in rows:
        if not isinstance(row, dict):
            return None
        key = tuple(row.get(field) for field in _KEY_FIELDS)
        if any(not isinstance(item, str) or not item.strip() for item in key):
            return None
        if key in indexed:
            return None
        if not _unique_strings(row.get('parent_acceptance_ids')):
            return None
        if not _unique_strings(row.get('seed_ids')):
            return None
        if not isinstance(row.get('oracle'), str) or not row['oracle'].strip():
            return None
        if row.get('applicability') != 'REQUIRED':
            return None
        try:
            indexed[key] = json.dumps(row, sort_keys=True, allow_nan=False)
        except (TypeError, ValueError):
            return None
    return indexed


def validate_required_case_set(
    frozen_cases: Any, observed_cases: Any, frozen_acceptance_ids: Any,
) -> List[str]:
    """Reject dropped/unknown/duplicate cases and altered frozen obligations.

N/A dispositions require a separately approved applicability contract and
cannot replace a row in this REQUIRED collection. No untrusted values echo.
"""
    if not _unique_strings(frozen_acceptance_ids):
        return ['FROZEN_ACCEPTANCE_SET_INVALID']
    baseline = _case_index(frozen_cases)
    if baseline is None:
        return ['FROZEN_REQUIRED_CASE_SET_INVALID']
    expected = set(frozen_acceptance_ids)
    parents = {parent for row in frozen_cases
               for parent in row['parent_acceptance_ids']}
    if parents != expected:
        return ['FROZEN_PARENT_COVERAGE_INCOMPLETE']
    observed = _case_index(observed_cases)
    if observed is None:
        return ['REQUIRED_CASE_SCHEMA_OR_DUPLICATE']
    errors = []
    if baseline.keys() - observed.keys():
        errors.append('REQUIRED_CASE_MISSING')
    if observed.keys() - baseline.keys():
        errors.append('REQUIRED_CASE_UNKNOWN')
    if any(baseline[key] != observed[key]
           for key in baseline.keys() & observed.keys()):
        errors.append('FROZEN_CASE_OBLIGATION_CHANGED')
    return errors
