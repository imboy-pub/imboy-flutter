"""Exact Flutter case identity gate; never execution authenticity or PASS."""
import json
from pathlib import Path
from typing import Any, List

from auto_test_lib import acceptance, acceptance_contract

_FIELDS = acceptance_contract._KEY_FIELDS


def _binding_names(cases: Any, bindings: Any) -> List[str]:
    baseline = acceptance_contract._case_index(cases)
    if baseline is None or not isinstance(bindings, list):
        raise ValueError('invalid frozen collection')
    keys, names = [], []
    for binding in bindings:
        if not isinstance(binding, dict) or set(binding) != set(_FIELDS) | {'test_name'}:
            raise ValueError('invalid binding')
        key = tuple(binding.get(field) for field in _FIELDS)
        name = binding['test_name']
        if any(not isinstance(value, str) or not value.strip() for value in key):
            raise ValueError('invalid key')
        if not isinstance(name, str) or not name.strip():
            raise ValueError('invalid test name')
        keys.append(key)
        names.append(name)
    if len(set(keys)) != len(keys) or set(keys) != set(baseline):
        raise ValueError('binding coverage mismatch')
    if len(set(names)) != len(names):
        raise ValueError('ambiguous test names')
    return names


def audit_case_event_artifact(root: Path, artifact: Any,
                             frozen_cases: Any, frozen_bindings: Any) -> List[str]:
    """Match every non-hidden completed test to an independently frozen key.

    Bindings are supplied by the coordinator, not derived from the report or
    raw log. Exactly one unique Flutter name identifies each required
    case/platform/profile/role key within this artifact. Runtime authenticity,
    device provenance, business facts and final qualification are separate.
    """
    try:
        expected = _binding_names(frozen_cases, frozen_bindings)
    except (ValueError, TypeError, RecursionError, UnicodeError):
        return ['FROZEN_CASE_EVENT_BINDINGS_INVALID']
    errors = acceptance.validate_artifact_files(root, [artifact])
    if errors:
        return errors
    try:
        lines = acceptance._read_event_artifact(root, artifact)
        if not acceptance._valid_event_protocol(lines):
            return ['CASE_EVENT_PROTOCOL_NOT_PASS']
        events = [json.loads(line, object_pairs_hook=acceptance._unique_json_object,
                             parse_constant=acceptance._reject_json_constant,
                             parse_float=acceptance._finite_json_float)
                  for line in lines if line.strip()]
        starts = {event['test']['id']: event['test'] for event in events
                  if event.get('type') == 'testStart'}
        names = [starts[event['testID']].get('name') for event in events
                 if event.get('type') == 'testDone' and not event.get('hidden', False)]
        if any(not isinstance(name, str) or not name.strip() for name in names):
            return ['CASE_EVENT_NAME_INVALID']
        if len(names) != len(set(names)):
            return ['CASE_EVENT_NAME_DUPLICATE']
        return [] if set(names) == set(expected) else ['CASE_EVENT_COLLECTION_MISMATCH']
    except (OSError, ValueError, TypeError, UnicodeError, RecursionError):
        return ['CASE_EVENT_ARTIFACT_INVALID_OR_UNREADABLE']


def register_cli(subparsers: Any) -> None:
    parser = subparsers.add_parser('acceptance-case-events',
                                  help='只读原始用例身份核对；不能签发产品 PASS')
    for option in ('evidence-root', 'frozen-input', 'frozen-sha256'):
        parser.add_argument('--' + option, required=True)


def run_cli(args: Any) -> int:
    """Load coordinator-pinned bindings and logs without running any tests."""
    root = Path(args.evidence_root)
    frozen, errors = acceptance.load_frozen_json(root, {
        'path': args.frozen_input, 'sha256': args.frozen_sha256})
    if not errors:
        if (not isinstance(frozen, dict)
                or type(frozen.get('schema_version')) is not int
                or frozen['schema_version'] != 1):
            errors = ['CASE_EVENT_INPUT_SCHEMA_INVALID']
        else:
            errors = audit_case_event_artifact(
                root, frozen.get('event_artifact'), frozen.get('required_cases'),
                frozen.get('case_event_bindings'))
    result = {'scope': 'RAW_CASE_IDENTITY_ONLY', 'product_pass': False,
              'errors': errors, 'remaining_gates': [
                  'complete coverage and source/runtime/device provenance',
                  'authentic complete execution journal and business facts',
                  'independent review, UX and all final qualification gates']}
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 2 if errors else 0
