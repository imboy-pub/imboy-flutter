"""Mandatory composition of recorded execution inputs; never product PASS."""
import json
from pathlib import Path
from typing import Any, Dict, List

from auto_test_lib import acceptance, acceptance_case_events, acceptance_contract
from auto_test_lib import acceptance_preflight


def audit_case_event_runs(root: Path, frozen_cases: Any, runs: Any) -> List[str]:
    """Require exact disjoint coverage and distinct logs for frozen run groups."""
    try:
        baseline = acceptance_contract._case_index(frozen_cases)
        if baseline is None or not isinstance(runs, list) or not runs:
            return ['FROZEN_CASE_EVENT_RUNS_INVALID']
        observed, paths, digests, errors = {}, set(), set(), []
        for run in runs:
            if not isinstance(run, dict):
                return ['FROZEN_CASE_EVENT_RUNS_INVALID']
            cases = acceptance_contract._case_index(run.get('required_cases'))
            artifact = run.get('event_artifact')
            if cases is None or not isinstance(artifact, dict):
                return ['FROZEN_CASE_EVENT_RUNS_INVALID']
            path = artifact.get('path')
            if not isinstance(path, str) or path in paths:
                return ['CASE_EVENT_LOG_REUSED_OR_INVALID']
            digest = artifact.get('sha256')
            if not isinstance(digest, str) or digest in digests:
                return ['CASE_EVENT_CONTENT_REUSED_OR_INVALID']
            paths.add(path)
            digests.add(digest)
            if observed.keys() & cases.keys():
                return ['CASE_EVENT_KEY_ASSIGNED_MULTIPLE_RUNS']
            observed.update(cases)
            if type(run.get('process_exit_code')) is not int or run['process_exit_code'] != 0:
                errors.append('CASE_EVENT_PROCESS_EXIT_NOT_ZERO')
            errors.extend(acceptance_case_events.audit_case_event_artifact(
                root, artifact, run['required_cases'], run.get('case_event_bindings')))
        if observed != baseline:
            errors.append('CASE_EVENT_RUN_COVERAGE_OR_OBLIGATION_MISMATCH')
        return errors
    except (ValueError, TypeError, RecursionError, UnicodeError):
        return ['FROZEN_CASE_EVENT_RUNS_INVALID']


def audit_execution_inputs(root: Path, frozen_descriptor: Any,
                           report_descriptor: Any, repositories: Any) -> Dict[str, Any]:
    """Compose live candidate/runtime/history and exact raw identities."""
    result = acceptance_preflight.audit_preparation_inputs(
        root, frozen_descriptor, report_descriptor, repositories)
    result['scope'] = 'EXECUTION_RECORD_INPUTS_ONLY'
    frozen, errors = acceptance.load_frozen_json(root, frozen_descriptor)
    result['errors'].extend(errors)
    if not errors and isinstance(frozen, dict):
        result['errors'].extend(audit_case_event_runs(
            root, frozen.get('required_cases'), frozen.get('case_event_runs')))
    return result


def register_cli(subparsers: Any) -> None:
    parser = subparsers.add_parser('acceptance-execution-preflight',
                                  help='只读组合运行记录门；不能签发产品 PASS')
    for option in ('evidence-root', 'frozen-input', 'frozen-sha256',
                   'acceptance-report', 'report-sha256'):
        parser.add_argument('--' + option, required=True)


def run_cli(args: Any, workspace: Path) -> int:
    result = audit_execution_inputs(Path(args.evidence_root),
        {'path': args.frozen_input, 'sha256': args.frozen_sha256},
        {'path': args.acceptance_report, 'sha256': args.report_sha256},
        {name: workspace / name for name in ('imboy', 'imboyapp', 'imboyadmin')})
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 2 if result['errors'] else 0
