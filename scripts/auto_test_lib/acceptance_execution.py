"""Mandatory composition of recorded execution inputs; never product PASS."""
import json
from pathlib import Path
from typing import Any, Dict, List

from auto_test_lib import acceptance, acceptance_case_events, acceptance_contract
from auto_test_lib import acceptance_preflight, acceptance_coverage, acceptance_journeys
from auto_test_lib import acceptance_defects, acceptance_versions, acceptance_ux
from auto_test_lib import acceptance_upstream
from auto_test_lib import acceptance_upstream_commands


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


def audit_run_attempt_links(runs: Any, attempts: Any) -> List[str]:
    """Bind each distinct raw run to one pinned completion, not to authenticity."""
    if not isinstance(runs, list) or not isinstance(attempts, list):
        return ['CASE_EVENT_ATTEMPT_LINK_INVALID']
    try:
        indexed = {row['attempt_id']: row for row in attempts}
        if len(indexed) != len(attempts):
            return ['CASE_EVENT_ATTEMPT_LINK_INVALID']
        used = set()
        for run in runs:
            identifier = run.get('attempt_id')
            if not isinstance(identifier, str) or identifier not in indexed or identifier in used:
                return ['CASE_EVENT_ATTEMPT_MISSING_UNKNOWN_OR_REUSED']
            used.add(identifier)
            record, artifact = indexed[identifier], run['event_artifact']
            if (record.get('events') != artifact['path']
                    or record.get('events_sha256') != artifact['sha256']):
                return ['CASE_EVENT_ATTEMPT_ARTIFACT_MISMATCH']
            if type(record.get('exit_code')) is not int or record['exit_code'] != 0:
                return ['CASE_EVENT_ATTEMPT_EXIT_NOT_ZERO']
            parsed = record.get('parsed')
            if not isinstance(parsed, dict) or parsed.get('test_status') != 'PASS':
                return ['CASE_EVENT_ATTEMPT_NOT_PASS']
            expected = {'executed': len(run['required_cases']), 'failed': 0, 'skipped': 0}
            if any(type(parsed.get(k)) is not int or parsed[k] != v for k, v in expected.items()):
                return ['CASE_EVENT_ATTEMPT_COUNTS_MISMATCH']
        return []
    except (KeyError, TypeError, AttributeError):
        return ['CASE_EVENT_ATTEMPT_LINK_INVALID']


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
        report, report_errors = acceptance.load_frozen_json(root, report_descriptor)
        result['errors'].extend(report_errors)
        if not report_errors and isinstance(report, dict):
            result['errors'].extend(acceptance_versions.audit_version_inputs(
                root, frozen.get('version_inputs'), report.get('version_inputs')))
            result['errors'].extend(acceptance_versions.audit_version_acceptance_set(root, frozen))
            result['errors'].extend(acceptance_versions.audit_version_document_links(root, frozen))
            result['errors'].extend(acceptance_versions.audit_dispatch_acceptance_set(root, frozen))
            result['errors'].extend(acceptance_versions.audit_case_dispatch_links(root, frozen))
            result['errors'].extend(acceptance_coverage.audit_input_case_coverage(
                frozen.get('coverage_inputs'), frozen.get('required_cases'),
                report.get('coverage_mappings'), frozen.get('approved_dispositions')))
            result['errors'].extend(audit_run_attempt_links(
                frozen.get('case_event_runs'), report.get('attempts')))
            result['errors'].extend(acceptance_journeys.audit_cross_device_journey_set(
                root, frozen, report.get('cross_device_records')))
            result['errors'].extend(acceptance_journeys.audit_journey_attempt_links(
                root, frozen, report.get('cross_device_records')))
            result['errors'].extend(acceptance_defects.audit_defect_records(
                root, frozen, report.get('defects')))
            result['errors'].extend(acceptance_ux.audit_user_ux_records(
                root, frozen, report.get('ux_reviews')))
            result['errors'].extend(acceptance_upstream.audit_upstream_ledger(
                root, frozen, report.get('upstream_acceptance_artifact')))
            result['errors'].extend(acceptance_upstream_commands.audit_upstream_command_links(
                root, frozen, report.get('upstream_commands_artifact')))
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
