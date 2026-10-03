"""Pinned user UX review records; never authenticate user identity or issue PASS."""
from pathlib import Path
import re
from typing import Any, List

from auto_test_lib import acceptance, acceptance_contract


def _requirements(rows: Any, cases: Any):
    known = acceptance_contract._case_index(cases)
    if known is None or not isinstance(rows, list) or not rows:
        return None
    indexed = {}
    for row in rows:
        if not isinstance(row, dict):
            return None
        identifier, keys = row.get('review_id'), row.get('case_keys')
        if (not isinstance(identifier, str) or not identifier.strip()
                or identifier in indexed or not isinstance(keys, list) or not keys):
            return None
        seen = set()
        for key in keys:
            if (not isinstance(key, list) or len(key) != 4
                    or any(not isinstance(part, str) or not part.strip() for part in key)):
                return None
            if tuple(key) not in known or tuple(key) in seen:
                return None
            seen.add(tuple(key))
        indexed[identifier] = row
    return indexed


def _candidate_heads(frozen: dict):
    candidates = frozen.get('candidates')
    if not isinstance(candidates, dict) or set(candidates) != {'imboy', 'imboyapp', 'imboyadmin'}:
        return None
    heads = {}
    for name, row in candidates.items():
        head = row.get('head') if isinstance(row, dict) else None
        if not isinstance(head, str) or not re.fullmatch(r'[0-9a-f]{40}', head) or head == '0' * 40:
            return None
        heads[name] = head
    return heads


def _review_errors(root: Path, identifier: str, request: dict,
                   descriptor: Any, heads: dict, versions: Any) -> List[str]:
    record, errors = acceptance.load_frozen_json(root, descriptor)
    if errors:
        return errors
    if not isinstance(record, dict):
        return ['UX_REVIEW_RECORD_INVALID']
    if record.get('review_id') != identifier or record.get('case_keys') != request['case_keys']:
        return ['UX_REVIEW_OBLIGATION_MISMATCH']
    if record.get('candidate_heads') != heads or record.get('version_inputs') != versions:
        return ['UX_REVIEW_CANDIDATE_OR_VERSION_MISMATCH']
    if record.get('reviewer_kind') != 'USER' or record.get('status') != 'APPROVED':
        return ['UX_USER_APPROVAL_MISSING']
    if not isinstance(record.get('approval_ref'), str) or not record['approval_ref'].strip():
        return ['UX_USER_APPROVAL_REFERENCE_MISSING']
    artifacts = request.get('reviewed_artifacts')
    if record.get('reviewed_artifacts') != artifacts:
        return ['UX_REVIEW_ARTIFACT_SET_MISMATCH']
    return acceptance.validate_artifact_files(root, artifacts)


def audit_user_ux_records(root: Path, frozen: Any, observed: Any) -> List[str]:
    """Require an explicit frozen review set and pinned approval for every item.

    The coordinator must independently verify approval provenance and UX scope.
    Synthetic records may pass this structural gate, never product qualification.
    """
    if not isinstance(frozen, dict):
        return ['UX_REVIEW_REQUIREMENTS_INVALID']
    expected = _requirements(frozen.get('ux_review_requirements'), frozen.get('required_cases'))
    if expected is None:
        return ['UX_REVIEW_REQUIREMENTS_INVALID']
    if not isinstance(observed, dict) or set(observed) != set(expected):
        return ['UX_REVIEW_SET_MISMATCH']
    heads = _candidate_heads(frozen)
    if heads is None or not isinstance(frozen.get('version_inputs'), dict) or not frozen['version_inputs']:
        return ['UX_REVIEW_BINDINGS_INVALID']
    errors, paths = [], set()
    for identifier, request in expected.items():
        descriptor = observed[identifier]
        path = descriptor.get('path') if isinstance(descriptor, dict) else None
        if not isinstance(path, str) or path in paths:
            errors.append('UX_REVIEW_RECORD_REUSED_OR_INVALID')
            continue
        paths.add(path)
        errors.extend(_review_errors(root, identifier, request, descriptor,
                                    heads, frozen['version_inputs']))
    return errors
