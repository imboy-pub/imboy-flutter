"""Frozen runtime artifact binding gate; integrity is not product qualification.

The coordinator supplies required IDs and frozen records independently of the
report. Snapshots are read only from the sanitized evidence root. Authenticity
of their runtime/device claims still requires separate semantic oracles.
"""
import json
from pathlib import Path
from typing import Any, Dict, List, Optional

from auto_test_lib import acceptance

_KINDS = {'source', 'config', 'build', 'fixture', 'device'}


def _index(rows: Any) -> Optional[Dict[str, str]]:
    if not isinstance(rows, list) or not rows:
        return None
    result = {}
    for row in rows:
        if not isinstance(row, dict):
            return None
        identifier = row.get('binding_id')
        kind = row.get('kind')
        artifact = row.get('artifact')
        if (not isinstance(identifier, str) or not identifier.strip()
                or identifier in result or not isinstance(kind, str)
                or kind not in _KINDS or not isinstance(artifact, dict)
                or set(artifact) != {'path', 'sha256'}):
            return None
        try:
            # Match the Python recursion guard on every supported interpreter.
            result[identifier] = ''.join(json.JSONEncoder(
                sort_keys=True, allow_nan=False,
            ).iterencode(row))
        except (TypeError, ValueError, RecursionError):
            return None
    return result


def audit_runtime_binding_files(
    root: Path, frozen_rows: Any, observed_rows: Any, required_ids: Any,
) -> List[str]:
    """Check exact frozen bindings and actual bytes; never issue product PASS.

    All five artifact kinds are mandatory. Required IDs must come from the
    frozen coordinator contract, not from the untrusted observed report.
    This does not prove complete source lists or genuine devices/builds.
    """
    if (not isinstance(required_ids, list) or not required_ids
            or any(not isinstance(i, str) or not i.strip() for i in required_ids)
            or len(set(required_ids)) != len(required_ids)):
        return ['REQUIRED_RUNTIME_BINDING_IDS_INVALID']
    frozen = _index(frozen_rows)
    if frozen is None or set(frozen) != set(required_ids):
        return ['FROZEN_RUNTIME_BINDING_SET_INVALID']
    if {r['kind'] for r in frozen_rows} != _KINDS:
        return ['FROZEN_RUNTIME_BINDING_KINDS_INCOMPLETE']
    observed = _index(observed_rows)
    if observed is None:
        return ['OBSERVED_RUNTIME_BINDING_SCHEMA_INVALID']
    errors = []
    if frozen.keys() - observed.keys():
        errors.append('RUNTIME_BINDING_MISSING')
    if observed.keys() - frozen.keys():
        errors.append('RUNTIME_BINDING_UNKNOWN')
    if any(frozen[key] != observed[key] for key in frozen.keys() & observed.keys()):
        errors.append('FROZEN_RUNTIME_BINDING_CHANGED')
    if errors:
        return errors
    errors.extend(acceptance.validate_artifact_files(
        root, [r['artifact'] for r in frozen_rows]))
    return errors
