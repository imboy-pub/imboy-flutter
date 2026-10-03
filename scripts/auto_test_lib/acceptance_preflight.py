"""Composition entrypoint for F01 preparation; never a final verdict."""
from pathlib import Path
from typing import Any, Dict

from auto_test_lib import (
    acceptance, acceptance_attempts, acceptance_bindings, acceptance_contract,
)

_REMAINING = [
    'complete source set and authentic runtime/config/build/fixture/device observations',
    'plan/dispatch/seed/page/API coverage closure',
    'raw case events, real business oracles and independent execution journal completeness',
    'upstream qualification, independent final review and user UX approval',
]


def audit_preparation_inputs(
    root: Path, frozen_descriptor: Any, report_descriptor: Any,
    repository_paths: Any,
) -> Dict[str, Any]:
    """Check pinned JSON, required cases and live candidates without writes.

    Both descriptor hashes must be supplied by the coordinator independently
    of the report. Success is only readiness of these inputs, never F01-S06
    completion or product PASS. Required business gates remain explicit.
    """
    result = {'scope': 'PREPARATION_INPUTS_ONLY', 'product_pass': False,
              'remaining_gates': list(_REMAINING), 'errors': []}
    frozen, errors = acceptance.load_frozen_json(root, frozen_descriptor)
    result['errors'].extend(errors)
    report, errors = acceptance.load_frozen_json(root, report_descriptor)
    result['errors'].extend(errors)
    if result['errors']:
        return result
    if (not isinstance(frozen, dict) or not isinstance(report, dict)
            or type(frozen.get('schema_version')) is not int
            or frozen['schema_version'] != 2):
        result['errors'].append('PREPARATION_INPUT_SCHEMA_INVALID')
        return result
    result['errors'].extend(acceptance_contract.validate_required_case_set(
        frozen.get('required_cases'), report.get('required_cases'),
        frozen.get('acceptance_ids')))
    result['errors'].extend(acceptance_contract.audit_candidate_repositories(
        repository_paths, frozen.get('candidates'), report.get('candidates')))
    result['errors'].extend(acceptance_bindings.audit_runtime_binding_files(
        root, frozen.get('runtime_bindings'), report.get('runtime_bindings'),
        frozen.get('required_runtime_binding_ids')))
    result['errors'].extend(acceptance_attempts.validate_attempt_journal(
        frozen.get('attempt_index'), report.get('attempts')))
    return result


def run_cli(args: Any, workspace: Path) -> int:
    """Print fixed-code JSON only; execution/resources are never started."""
    import json
    result = audit_preparation_inputs(
        Path(args.evidence_root),
        {'path': args.frozen_input, 'sha256': args.frozen_sha256},
        {'path': args.acceptance_report, 'sha256': args.report_sha256},
        {name: workspace / name for name in ('imboy', 'imboyapp', 'imboyadmin')},
    )
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 2 if result['errors'] else 0
