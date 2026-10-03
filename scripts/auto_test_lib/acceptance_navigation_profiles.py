"""Navigation profile collection plus mandatory full execution-input gate.

This never issues product PASS or replaces the original required acceptance set.
"""
import json
from pathlib import Path
from typing import Any

from auto_test_lib import acceptance, acceptance_contract, acceptance_execution

FUNCTION_ID = 'fn:bottom_navigation:bottom_navigation_page:006'
KEY_FIELDS = acceptance_contract._KEY_FIELDS
EXPECTED_KEYS = {
    ('bottom-navigation-channel', platform, profile, 'primary')
    for platform in ('android', 'macos') for profile in ('enabled', 'disabled')
}


def test_name(platform: str, profile: str) -> str:
    return f'bottom navigation: platform={platform} channel={profile} real tabs'


def _matrix_errors(frozen: Any) -> list[str]:
    if not isinstance(frozen, dict):
        return ['NAVIGATION_PROFILE_MATRIX_INVALID']
    cases = frozen.get('required_cases')
    if acceptance_contract._case_index(cases) is None:
        return ['NAVIGATION_PROFILE_MATRIX_INVALID']
    selected = [row for row in cases if FUNCTION_ID in row['seed_ids']]
    keys = {tuple(row[field] for field in KEY_FIELDS) for row in selected}
    if len(selected) != 4 or keys != EXPECTED_KEYS:
        return ['NAVIGATION_PROFILE_MATRIX_INVALID']
    for row in selected:
        parent = 'F14-A02' if row['platform'] == 'android' else 'F14-A03'
        if row['seed_ids'] != [FUNCTION_ID] or row['parent_acceptance_ids'] != [parent]:
            return ['NAVIGATION_PROFILE_MATRIX_INVALID']
    return []


def _binding_errors(frozen: dict) -> list[str]:
    runs = frozen.get('case_event_runs')
    if not isinstance(runs, list):
        return ['NAVIGATION_PROFILE_BINDINGS_INVALID']
    found = []
    for run in runs:
        if not isinstance(run, dict) or not isinstance(run.get('case_event_bindings'), list):
            return ['NAVIGATION_PROFILE_BINDINGS_INVALID']
        for binding in run['case_event_bindings']:
            if not isinstance(binding, dict):
                return ['NAVIGATION_PROFILE_BINDINGS_INVALID']
            key = tuple(binding.get(field) for field in KEY_FIELDS)
            if any(not isinstance(value, str) for value in key):
                return ['NAVIGATION_PROFILE_BINDINGS_INVALID']
            if key in EXPECTED_KEYS:
                found.append(key)
                if binding.get('test_name') != test_name(key[1], key[2]):
                    return ['NAVIGATION_PROFILE_BINDINGS_INVALID']
    if len(found) != 4 or set(found) != EXPECTED_KEYS:
        return ['NAVIGATION_PROFILE_BINDINGS_INVALID']
    return []


def audit_navigation_profile_inputs(root: Path, frozen_descriptor: Any,
                                    report_descriptor: Any, repositories: Any) -> dict:
    frozen, errors = acceptance.load_frozen_json(root, frozen_descriptor)
    if not errors:
        errors = _matrix_errors(frozen)
    if not errors:
        errors = _binding_errors(frozen)
    if not errors:
        result = acceptance_execution.audit_execution_inputs(
            root, frozen_descriptor, report_descriptor, repositories)
    else:
        result = {'errors': errors}
    result.update(scope='NAVIGATION_PROFILE_EXECUTION_INPUTS_ONLY',
                  product_pass=False, original_acceptance_ids_upgraded=[])
    return result


def register_cli(subparsers: Any) -> None:
    parser = subparsers.add_parser('acceptance-navigation-profiles',
                                  help='Read-only four-profile execution-input gate; no product PASS')
    for option in ('evidence-root', 'frozen-input', 'frozen-sha256',
                   'acceptance-report', 'report-sha256'):
        parser.add_argument('--' + option, required=True)


def run_cli(args: Any, workspace: Path) -> int:
    result = audit_navigation_profile_inputs(Path(args.evidence_root),
        {'path': args.frozen_input, 'sha256': args.frozen_sha256},
        {'path': args.acceptance_report, 'sha256': args.report_sha256},
        {name: workspace / name for name in ('imboy', 'imboyapp', 'imboyadmin')})
    print(json.dumps(result, sort_keys=True))
    return 2 if result['errors'] else 0
