"""Read-only crash reconciliation; never replay work or issue product PASS."""
import json
import os
from pathlib import Path
from typing import Any, Dict, List

from auto_test_lib import acceptance

_MAX_BYTES = 32 * 1024 * 1024


def _read_journal(root: Path, path: str) -> List[dict]:
    with os.fdopen(acceptance._open_artifact(root, path), 'rb') as stream:
        raw = stream.read(_MAX_BYTES + 1)
    if len(raw) > _MAX_BYTES:
        raise ValueError('journal too large')
    rows = [json.loads(line, object_pairs_hook=acceptance._unique_json_object,
                       parse_constant=acceptance._reject_json_constant,
                       parse_float=acceptance._finite_json_float)
            for line in raw.decode('utf-8').splitlines() if line.strip()]
    if any(not isinstance(row, dict) for row in rows):
        raise ValueError('invalid journal row')
    return rows


def _ids(rows: List[dict]) -> List[str]:
    ids = [row.get('attempt_id') for row in rows]
    if (not ids or any(not isinstance(i, str) or not i.strip() for i in ids)
            or len(set(ids)) != len(ids)):
        raise ValueError('invalid attempt IDs')
    return ids


def inspect_target_journal(root: Path, target_directory: str) -> Dict[str, Any]:
    """Reconcile durable records and log bytes, without writes or execution.

    COMPLETED means the listed starts have durable completion records, not
    that tests passed or the journal is independently authenticated.
    """
    result = {'state': 'INVALID', 'scope': 'JOURNAL_COMPLETENESS_ONLY',
              'product_pass': False, 'errors': []}
    try:
        if len(acceptance._parts(target_directory)) != 1:
            raise ValueError('invalid directory')
        starts = _read_journal(root, target_directory + '/starts.jsonl')
        start_ids = _ids(starts)
        try:
            attempts = _read_journal(root, target_directory + '/attempts.jsonl')
        except FileNotFoundError:
            attempts = []
        attempt_ids = _ids(attempts) if attempts else []
        if attempt_ids != start_ids[:len(attempt_ids)]:
            raise ValueError('journal sequence mismatch')
        for start, attempt in zip(starts, attempts):
            if (not isinstance(start.get('fingerprint'), dict)
                    or json.dumps(start['fingerprint'], sort_keys=True, allow_nan=False)
                    != json.dumps(attempt.get('fingerprint'), sort_keys=True, allow_nan=False)):
                raise ValueError('start/completion fingerprint mismatch')
            path = attempt.get('events')
            if not isinstance(path, str) or not path.startswith(target_directory + '/'):
                raise ValueError('cross-target event path')
            errors = acceptance.validate_artifact_files(root, [{
                'path': path, 'sha256': attempt.get('events_sha256')}])
            if errors:
                result['errors'].extend(errors)
                return result
        result['state'] = 'COMPLETED' if attempt_ids == start_ids else 'INCOMPLETE'
        result['started'] = len(starts)
        result['completed'] = len(attempts)
        result['unfinished'] = len(starts) - len(attempts)
    except (OSError, ValueError, TypeError, RecursionError):
        result['errors'].append('SHARD_JOURNAL_INVALID_OR_UNREADABLE')
    return result


def main() -> int:
    """Read-only CLI; completion means records exist, never business PASS."""
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence-root', required=True)
    parser.add_argument('--target-directory', required=True)
    args = parser.parse_args()
    result = inspect_target_journal(Path(args.evidence_root), args.target_directory)
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0 if result['state'] == 'COMPLETED' else 2


if __name__ == '__main__':
    raise SystemExit(main())
