"""Read-only frozen required-case collection gate for F01.

The caller must load baseline cases and acceptance IDs from independently
hash-verified frozen inputs, never from the report being audited. This module
checks collection equality only, not execution or product qualification.
"""
import json
import os
import re
import subprocess
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from auto_test_lib import cache

_KEY_FIELDS = ('case_id', 'platform', 'profile', 'role_variant')
_REPOSITORIES = {'imboy', 'imboyapp', 'imboyadmin'}
_COMMIT = re.compile(r'^[0-9a-f]{40}$')


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


def _candidate_valid(value: Any) -> bool:
    if not isinstance(value, dict) or set(value) != {'head', 'required_ancestors'}:
        return False
    if not isinstance(value['head'], str) or not _COMMIT.fullmatch(value['head']):
        return False
    ancestors = value['required_ancestors']
    return (_unique_strings(ancestors)
            and all(_COMMIT.fullmatch(item) for item in ancestors))


def _git_output(root: Path, *args: str) -> str:
    completed = subprocess.run(
        ['git', '--no-replace-objects', '-C', str(root), *args],
        capture_output=True, text=True, check=True, timeout=10,
        env=dict(os.environ, GIT_GRAFT_FILE=os.devnull),
    )
    return completed.stdout.strip()


def _audit_repository(root: Any, candidate: dict) -> List[str]:
    try:
        root = Path(root).resolve()
        if Path(_git_output(root, 'rev-parse', '--show-toplevel')).resolve() != root:
            return ['CANDIDATE_REPOSITORY_ROOT_MISMATCH']
        head = candidate['head']
        if _git_output(root, 'rev-parse', 'HEAD') != head:
            return ['CANDIDATE_LIVE_HEAD_MISMATCH']
        if _git_output(root, 'cat-file', '-t', head) != 'commit':
            return ['CANDIDATE_NOT_COMMIT']
        for ancestor in candidate['required_ancestors']:
            if _git_output(root, 'cat-file', '-t', ancestor) != 'commit':
                return ['ANCESTOR_NOT_COMMIT']
            if not cache.git_is_ancestor(ancestor, head, root):
                return ['REQUIRED_ANCESTOR_MISSING']
    except (OSError, ValueError, TypeError, subprocess.SubprocessError):
        return ['CANDIDATE_GIT_INSPECTION_FAILED']
    return []


def audit_candidate_repositories(
    repository_paths: Any, frozen_candidates: Any, observed_candidates: Any,
) -> List[str]:
    """Bind three report candidates to frozen commits and actual Git ancestry.

    Paths and frozen candidates must come from the trusted coordinator inputs.
    This read-only check does not certify clean worktrees, builds or runtime
    configuration; those are separate gates. No report values appear in errors.
    """
    for value in (repository_paths, frozen_candidates, observed_candidates):
        if not isinstance(value, dict) or set(value) != _REPOSITORIES:
            return ['THREE_REPOSITORY_BINDINGS_REQUIRED']
    try:
        if len({Path(path).resolve() for path in repository_paths.values()}) != 3:
            return ['DISTINCT_REPOSITORY_ROOTS_REQUIRED']
    except (OSError, ValueError, TypeError, RuntimeError):
        return ['CANDIDATE_REPOSITORY_PATH_INVALID']
    for name in sorted(_REPOSITORIES):
        if not _candidate_valid(frozen_candidates[name]):
            return ['FROZEN_CANDIDATE_SCHEMA_INVALID:' + name]
        if not _candidate_valid(observed_candidates[name]):
            return ['OBSERVED_CANDIDATE_SCHEMA_INVALID:' + name]
        if frozen_candidates[name] != observed_candidates[name]:
            return ['CANDIDATE_REPORT_BINDING_MISMATCH:' + name]
    errors = []
    for name in sorted(_REPOSITORIES):
        errors.extend(error + ':' + name for error in _audit_repository(
            repository_paths[name], frozen_candidates[name]))
    return errors
