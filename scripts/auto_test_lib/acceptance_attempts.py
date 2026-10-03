"""Read-only attempt-history integrity gate, never a product verdict.

The index must be independently pinned by the coordinator at execution time.
A report-produced index cannot prove that failed attempts were retained.
"""
import hashlib
import json
import re
from typing import Any, List, Optional

_HASH = re.compile(r'^[0-9a-f]{64}$')


def _record_hash(record: Any) -> Optional[str]:
    try:
        data = json.dumps(record, sort_keys=True, allow_nan=False,
                          ensure_ascii=False, separators=(',', ':')).encode('utf-8')
    except (TypeError, ValueError, RecursionError, UnicodeError):
        return None
    return hashlib.sha256(data).hexdigest()


def validate_attempt_journal(frozen_index: Any, observed_records: Any) -> List[str]:
    """Require exact ordered IDs and canonical record hashes, including failures.

    A clean result proves retention relative to the pinned index only. It does
    not prove genuine execution, index completeness, retry policy, raw-case
    outcomes or business PASS. Untrusted values are never echoed in errors.
    """
    if not isinstance(frozen_index, list) or not frozen_index:
        return ['FROZEN_ATTEMPT_INDEX_INVALID']
    identifiers = []
    for entry in frozen_index:
        if (not isinstance(entry, dict)
                or set(entry) != {'attempt_id', 'record_sha256'}
                or not isinstance(entry['attempt_id'], str)
                or not entry['attempt_id'].strip()
                or not isinstance(entry['record_sha256'], str)
                or not _HASH.fullmatch(entry['record_sha256'])):
            return ['FROZEN_ATTEMPT_INDEX_INVALID']
        identifiers.append(entry['attempt_id'])
    if len(set(identifiers)) != len(identifiers):
        return ['FROZEN_ATTEMPT_INDEX_DUPLICATE']
    if not isinstance(observed_records, list):
        return ['ATTEMPT_JOURNAL_SCHEMA_INVALID']
    actual_ids = []
    for record in observed_records:
        if (not isinstance(record, dict)
                or not isinstance(record.get('attempt_id'), str)
                or not record['attempt_id'].strip()):
            return ['ATTEMPT_JOURNAL_SCHEMA_INVALID']
        actual_ids.append(record['attempt_id'])
    if len(set(actual_ids)) != len(actual_ids):
        return ['ATTEMPT_JOURNAL_DUPLICATE']
    if actual_ids != identifiers:
        return ['ATTEMPT_HISTORY_MISSING_UNKNOWN_OR_REORDERED']
    for entry, record in zip(frozen_index, observed_records):
        digest = _record_hash(record)
        if digest is None:
            return ['ATTEMPT_RECORD_UNSERIALIZABLE']
        if digest != entry['record_sha256']:
            return ['FROZEN_ATTEMPT_RECORD_CHANGED']
    return []
