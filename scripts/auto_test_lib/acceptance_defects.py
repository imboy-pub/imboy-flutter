"""Frozen defect closure records only; never certify discovery completeness."""
from pathlib import Path
from typing import Any, List

from auto_test_lib import acceptance, acceptance_contract


def _defect_index(rows: Any):
    if not isinstance(rows, list):
        return None
    indexed = {}
    for row in rows:
        if not isinstance(row, dict):
            return None
        identifier = row.get('defect_id')
        if (not isinstance(identifier, str) or not identifier.strip()
                or identifier in indexed or row.get('severity') not in ('P0', 'P1', 'P2', 'P3')):
            return None
        indexed[identifier] = row
    return indexed


def _closure_errors(root: Path, defect: dict, observed: dict, frozen: dict) -> List[str]:
    closure, errors = acceptance.load_frozen_json(root, observed.get('closure_artifact'))
    if errors:
        return errors
    if not isinstance(closure, dict) or closure.get('defect_id') != defect['defect_id']:
        return ['DEFECT_CLOSURE_ID_MISMATCH']
    try:
        candidate = frozen['candidates'][closure['repository']]['head']
        if closure.get('candidate_sha') != candidate:
            return ['DEFECT_CLOSURE_CANDIDATE_MISMATCH']
        key = closure['case_key']
        if not isinstance(key, list) or len(key) != 4 or any(
                not isinstance(part, str) or not part.strip() for part in key):
            return ['DEFECT_CLOSURE_CASE_INVALID']
        required = acceptance_contract._case_index(frozen['required_cases'])
        if required is None or tuple(key) not in required:
            return ['DEFECT_CLOSURE_CASE_UNKNOWN']
        if key not in defect.get('retest_case_keys', []):
            return ['DEFECT_CLOSURE_UNRELATED_CASE']
        runs = [run for run in frozen['case_event_runs']
                if run.get('attempt_id') == closure.get('attempt_id')]
        if len(runs) != 1:
            return ['DEFECT_CLOSURE_ATTEMPT_INVALID']
        cases = acceptance_contract._case_index(runs[0].get('required_cases'))
        if (cases is None or tuple(key) not in cases
                or closure.get('event_artifact') != runs[0].get('event_artifact')):
            return ['DEFECT_CLOSURE_RETEST_MISMATCH']
        return []
    except (KeyError, TypeError, AttributeError):
        return ['DEFECT_CLOSURE_LINK_INVALID']


def _retest_set_errors(root: Path, defect: dict, observed: dict, frozen: dict) -> List[str]:
    keys, artifacts = defect.get('retest_case_keys'), observed.get('closure_artifacts')
    if (not isinstance(keys, list) or not keys or not isinstance(artifacts, list)
            or not artifacts or any(not isinstance(key, list) or len(key) != 4
                or any(not isinstance(part, str) or not part.strip() for part in key)
                for key in keys)):
        return ['DEFECT_RETEST_SET_INVALID']
    expected = {tuple(key) for key in keys}
    if len(expected) != len(keys):
        return ['DEFECT_RETEST_SET_INVALID']
    seen, errors = set(), []
    for artifact in artifacts:
        item_errors = _closure_errors(root, defect, {'closure_artifact': artifact}, frozen)
        errors.extend(item_errors)
        if item_errors:
            continue
        record, read_errors = acceptance.load_frozen_json(root, artifact)
        errors.extend(read_errors)
        if read_errors:
            continue
        key = tuple(record['case_key'])
        if key in seen:
            errors.append('DEFECT_RETEST_CASE_DUPLICATE')
        seen.add(key)
    if seen != expected:
        errors.append('DEFECT_RETEST_SET_MISMATCH')
    return errors


def audit_defect_records(root: Path, frozen: Any, observed: Any) -> List[str]:
    """Require explicit exact inventory and linked retest for every CLOSED row.

    Run success is checked by the mandatory execution composition. A synthetic
    closure record cannot prove a fix, a genuine reproduction or all defects.
    """
    if not isinstance(frozen, dict):
        return ['FROZEN_DEFECT_SET_INVALID']
    baseline, report = _defect_index(frozen.get('defects')), _defect_index(observed)
    if baseline is None or report is None:
        return ['DEFECT_SET_INVALID']
    if set(baseline) != set(report):
        return ['DEFECT_SET_MISMATCH']
    errors = []
    for identifier, defect in baseline.items():
        row = report[identifier]
        if row['severity'] != defect['severity']:
            errors.append('DEFECT_SEVERITY_CHANGED')
        status = row.get('status')
        if status not in ('OPEN', 'CLOSED'):
            errors.append('DEFECT_STATUS_INVALID')
        elif status == 'CLOSED':
            errors.extend(_retest_set_errors(root, defect, row, frozen))
        elif defect['severity'] in ('P0', 'P1'):
            errors.append('REQUIRED_DEFECT_NOT_CLOSED')
    return errors
