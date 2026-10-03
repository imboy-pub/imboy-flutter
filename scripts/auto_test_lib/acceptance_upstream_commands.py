"""Pinned upstream command-record links; declarations do not prove execution."""
from pathlib import Path
from typing import Any, List

from auto_test_lib import acceptance, acceptance_upstream

_FIELDS = ('command', 'exit_code', 'test_count', 'config_hash',
           'evidence_path', 'evidence_sha256')


def _command_index(document: Any):
    if not isinstance(document, dict):
        return None
    records = document.get('commands')
    if not isinstance(records, list) or not records:
        return None
    indexed = {}
    for record in records:
        if not isinstance(record, dict):
            return None
        identifier = record.get('command_id')
        if (not isinstance(identifier, str) or not identifier.strip()
                or identifier == '-' or identifier in indexed):
            return None
        if any(not isinstance(record.get(field), str) for field in _FIELDS):
            return None
        indexed[identifier] = record
    return indexed


def audit_upstream_command_links(root: Path, frozen: Any, observed: Any) -> List[str]:
    """Require exact frozen command set and all ledger execution/log bindings.

    The frozen registry is independently hash pinned. Shared commands may
    cover several requirements, but every ledger field must match. Raw process
    authenticity, command oracle adequacy and independent reviews remain gates.
    This function never executes commands or grants product qualification.
    """
    if not isinstance(frozen, dict):
        return ['UPSTREAM_COMMAND_INPUT_INVALID']
    descriptor = frozen.get('upstream_commands_artifact')
    if not isinstance(descriptor, dict) or descriptor != observed:
        return ['UPSTREAM_COMMAND_REGISTRY_BINDING_CHANGED']
    document, errors = acceptance.load_frozen_json(root, descriptor)
    if errors:
        return errors
    indexed = _command_index(document)
    if indexed is None:
        return ['UPSTREAM_COMMAND_REGISTRY_SCHEMA_INVALID']
    rows, errors = acceptance_upstream._load_rows(
        root, frozen.get('upstream_acceptance_artifact'))
    if errors:
        return errors
    if set(indexed) != {row['command_id'] for row in rows}:
        return ['UPSTREAM_COMMAND_SET_MISMATCH']
    for row in rows:
        record = indexed[row['command_id']]
        if any(row[field] != record[field] for field in _FIELDS):
            errors.append('UPSTREAM_COMMAND_RECORD_MISMATCH:' + row['id'])
    return errors
