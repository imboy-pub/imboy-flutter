"""Thin CLI for the existing auto-test framework's execution contract.

Ownership/selection and verdicts live in execution_catalog/execution_runner.
This module only reads arguments, persists reviewable artifacts and prints them.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path


def register_cli(subparsers):
    check = subparsers.add_parser('execution-check', help='Validate tracked test ownership, not business results')
    check.add_argument('--output', help='Machine-readable ownership inventory')
    check.add_argument('--inventory', help='Human-readable ownership and migration inventory')
    for command in ('execution-plan', 'execution-run'):
        parser = subparsers.add_parser(command)
        parser.add_argument('--profile', default='pr')
        parser.add_argument('--platform', action='append', default=[])
        parser.add_argument('--product-profile', action='append', default=[])
        parser.add_argument('--suite', action='append', default=[])
        parser.add_argument('--target', action='append', default=[])
        parser.add_argument('--variant', action='append', default=[])
        if command == 'execution-plan':
            parser.add_argument('--output')
        else:
            parser.add_argument('--plan', help='Previously frozen plan; selection flags cannot replace it')
            parser.add_argument('--artifact-dir')
            parser.add_argument('--worker-platform', help='Run one worker partition; final summary still checks every obligation')
            parser.add_argument('--worker-suite', action='append', default=[], help='Run whole suite partitions without splitting paired roles')
            parser.add_argument('--worker-product-profile', help='Run one prepared product artifact partition')
            parser.add_argument('--coverage', action='store_true')
            parser.add_argument('--upstream', action='append', default=[], metavar='NAME=STATUS')
    gates = subparsers.add_parser('execution-gates', help='Run shared prerequisites once for a frozen multi-worker plan')
    gates.add_argument('--plan', required=True)
    gates.add_argument('--artifact-dir', required=True)
    summary = subparsers.add_parser('execution-summary')
    summary.add_argument('--plan', required=True)
    summary.add_argument('--results', action='append', default=[])
    summary.add_argument('--upstream', action='append', default=[], metavar='NAME=STATUS')
    summary.add_argument('--upstream-env', help='Environment variable containing GitHub needs JSON')
    summary.add_argument('--output', required=True)
    coverage = subparsers.add_parser('execution-coverage')
    coverage.add_argument('--input', required=True)
    coverage.add_argument('--minimum', type=float, default=38.0)


def write_json(path: Path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + f'.tmp.{os.getpid()}')
    temporary.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    temporary.replace(path)


def read_json(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def upstream_statuses(items, env_name=None):
    result = {}
    if env_name:
        data = json.loads(os.environ.get(env_name, '{}'))
        if not isinstance(data, dict):
            raise ValueError('upstream environment must contain an object')
        for name, value in data.items():
            result[name] = value.get('result', 'missing') if isinstance(value, dict) else value
    for item in items:
        name, separator, status = item.partition('=')
        if not separator or not name or not status:
            raise ValueError('--upstream must be NAME=STATUS')
        result[name] = status
    return result


def artifact_path(value, recorded_root, actual_root):
    """Relocate downloaded evidence inside its artifact, never follow arbitrary paths."""
    if not isinstance(value, str) or not value:
        raise ValueError('evidence path is missing')
    source = Path(value)
    relative = source.relative_to(Path(recorded_root)) if source.is_absolute() else source
    actual = (actual_root / relative).resolve()
    actual.relative_to(actual_root.resolve())
    if not actual.is_file():
        raise ValueError(f'evidence file missing: {relative}')
    return actual


def verify_result_files(row, payload, candidate):
    """Successful receipts need the actual downloaded files, not just path strings."""
    if row.get('status') not in ('PASS', 'FLAKY', 'PASS_WITH_SKIPS'):
        return row
    from .machine_events import parse_machine_events
    root = candidate.parent.resolve()
    recorded_root = payload.get('artifact_root', str(root)) if isinstance(payload, dict) else str(root)
    try:
        attempts = row.get('attempts')
        if not isinstance(attempts, list) or not attempts or any(not isinstance(a, dict) for a in attempts):
            raise ValueError('successful result has no valid attempts')
        for attempt in attempts:
            resolved = {}
            for key in ('log', 'evidence', 'process_receipt'):
                path = artifact_path(attempt.get(key), recorded_root, root)
                digest = hashlib.sha256(path.read_bytes()).hexdigest()
                if digest != attempt.get(key + '_sha256'):
                    raise ValueError(f'evidence digest mismatch: {key}')
                resolved[key] = path
            receipt = read_json(resolved['process_receipt'])
            if not isinstance(receipt, dict):
                raise ValueError('invalid process receipt')
            if (receipt.get('exit_code') != attempt.get('process_exit_code') or
                    receipt.get('command') != attempt.get('command') or
                    receipt.get('log_sha256') != attempt.get('log_sha256')):
                raise ValueError('process receipt contradicts saved attempt')
            machine = artifact_path(receipt.get('machine'), recorded_root, root)
            if hashlib.sha256(machine.read_bytes()).hexdigest() != receipt.get('machine_sha256'):
                raise ValueError('raw machine stream digest mismatch')
            parsed = parse_machine_events(resolved['evidence'].read_text(encoding='utf-8').splitlines(),
                                          attempt['process_exit_code']).to_dict()
            if parsed != attempt.get('parsed'):
                raise ValueError('parsed result differs from collected machine events')
            for evidence in attempt.get('related_evidence', []):
                path = artifact_path(evidence.get('path'), recorded_root, root)
                if hashlib.sha256(path.read_bytes()).hexdigest() != evidence.get('sha256'):
                    raise ValueError('related evidence digest mismatch')
            if attempt.get('native_evidence'):
                path = artifact_path(attempt['native_evidence'], recorded_root, root)
                if hashlib.sha256(path.read_bytes()).hexdigest() != attempt.get('native_evidence_sha256'):
                    raise ValueError('native evidence digest mismatch')
            if attempt.get('coverage'):
                artifact_path(attempt['coverage'], recorded_root, root)
        companion = row.get('companion_evidence')
        if companion:
            if not isinstance(companion, dict):
                raise ValueError('invalid companion receipt')
            if companion.get('kind') == 'coordinator-gate':
                if any(companion.get(a) != row.get(b) for a, b in (
                        ('instance_id', 'id'), ('target', 'target'), ('mode', 'variant'))):
                    raise ValueError('coordinator instance identity mismatch')
                from .execution_adapters import verify_coordinator_evidence
                errors = verify_coordinator_evidence(companion,
                    lambda value: artifact_path(value, recorded_root, root))
                if errors:
                    raise ValueError('coordinator evidence: ' + '; '.join(errors))
            else:
                verified = verify_result_files(companion, payload, candidate)
                if verified.get('status') != 'PASS':
                    raise ValueError('companion evidence failed verification')
        return row
    except (OSError, ValueError, KeyError, TypeError) as error:
        return {**row, 'status': 'BLOCKED', 'reason_code': 'ARTIFACT_EVIDENCE_MISSING_OR_INVALID',
                'evidence_error': str(error)}


def load_results(paths):
    records = []
    seen_files = set()
    for value in paths:
        path = Path(value)
        files = sorted(path.rglob('results.json')) if path.is_dir() else [path]
        for candidate in files:
            resolved = candidate.resolve()
            if resolved in seen_files or not candidate.is_file():
                continue  # Missing files remain missing obligations in reconciliation.
            seen_files.add(resolved)
            payload = read_json(candidate)
            rows = payload.get('results') if isinstance(payload, dict) else payload
            if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
                raise ValueError(f'invalid result collection: {candidate}')
            records.extend(verify_result_files(row, payload, candidate) for row in rows)
    return records


def load_gates(paths, plan):
    gates = {}
    for value in paths:
        path = Path(value)
        files = sorted(path.rglob('gates.json')) if path.is_dir() else []
        for candidate in files:
            payload = read_json(candidate)
            if not isinstance(payload, dict):
                raise ValueError(f'invalid gate collection: {candidate}')
            for name, row in payload.items():
                if name not in plan.get('gates', []):
                    raise ValueError(f'undeclared gate receipt: {name}')
                if not isinstance(row, dict):
                    raise ValueError(f'invalid gate receipt: {name}')
                mismatch = [key for key in ('commit', 'profile', 'source_fingerprint')
                            if not plan.get(key) or row.get(key) != plan[key]]
                if mismatch:
                    row = {**row, 'status': 'BLOCKED', 'reason_code': 'STALE_GATE_EVIDENCE',
                           'detail': f'{candidate}: mismatched ' + ', '.join(mismatch)}
                elif row.get('status') == 'PASS' and (row.get('exit_code') != 0 or not row.get('log')):
                    row = {**row, 'status': 'BLOCKED', 'reason_code': 'INVALID_GATE_EVIDENCE',
                           'detail': f'{candidate}: PASS needs a zero exit code and a log location'}
                if row.get('status') == 'PASS':
                    try:
                        log = artifact_path(row.get('log'), row.get('artifact_root', str(candidate.parent)), candidate.parent)
                        if hashlib.sha256(log.read_bytes()).hexdigest() != row.get('log_sha256'):
                            raise ValueError('gate log digest mismatch')
                    except (OSError, ValueError, TypeError) as error:
                        row = {**row, 'status': 'BLOCKED', 'reason_code': 'INVALID_GATE_EVIDENCE',
                               'detail': str(error)}
                previous = gates.get(name)
                # A later successful shard cannot hide an earlier failed gate.
                if previous and previous.get('status') != 'PASS':
                    continue
                gates[name] = row
    return gates


def print_summary(summary):
    status = summary.get('status', summary.get('test_status', 'BLOCKED'))
    rows = summary.get('results', [])
    counts = Counter(row.get('status', 'UNKNOWN') for row in rows)
    print(json.dumps({'status': status, 'reason_code': summary.get('reason_code'),
                      'counts': dict(counts), 'exit_code': summary.get('exit_code')}, ensure_ascii=False))
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as stream:
            stream.write(f'## Test reconciliation: {status}\n\n')
            stream.write('Planning and static inventory checks are separate from executed test evidence.\n\n')
            for name, count in sorted(counts.items()):
                stream.write(f'- {name}: {count}\n')
            stream.write('\n')


def coverage_check(path, minimum):
    """Use unique source/line keys; merged LCOV must not inflate denominators."""
    if not 0 <= minimum <= 100:
        raise ValueError('--minimum must be between 0 and 100')
    lines = {}
    source = None
    for line in Path(path).read_text(encoding='utf-8').splitlines():
        if line.startswith('SF:'):
            source = line[3:]
        elif line.startswith('DA:'):
            if not source:
                raise ValueError('LCOV line has no source')
            number, count, *_ = line[3:].split(',')
            key = source, int(number)
            lines[key] = max(lines.get(key, 0), int(count))
        elif line == 'end_of_record':
            source = None
    if not lines:
        raise ValueError('coverage contains zero source lines')
    covered = sum(count > 0 for count in lines.values())
    percent = covered / len(lines) * 100
    print(f'Coverage: {covered}/{len(lines)} lines = {percent:.2f}% (required {minimum:.2f}%)')
    return 0 if percent >= minimum else 1


def validate_saved_plan(root, plan, catalog):
    expected = catalog.build_plan(root, profile=plan['profile'], **plan.get('selectors', {}))
    for key in ('commit', 'source_fingerprint', 'instances', 'gates', 'scope', 'full_regression'):
        if expected.get(key) != plan.get(key):
            raise ValueError(f'PLAN_{key.upper()}_MISMATCH: regenerate a plan for this source and declared scope')
    return plan


def run_cli(args, root: Path, reports: Path):
    from . import execution_catalog as catalog
    try:
        if args.command == 'execution-coverage':
            return coverage_check(args.input, args.minimum)
        if args.command == 'execution-gates':
            from .execution_gates import run_gates
            plan = validate_saved_plan(root, read_json(args.plan), catalog)
            output = Path(args.artifact_dir).resolve()
            gates = run_gates(root, plan, output / 'gates', dict(os.environ))
            write_json(output / 'gates.json', gates)
            status = 'FAIL' if any(r['status'] == 'FAIL' for r in gates.values()) else (
                'BLOCKED' if any(r['status'] != 'PASS' for r in gates.values()) else 'PASS')
            code = {'PASS': 0, 'FAIL': 1, 'BLOCKED': 2}[status]
            write_json(output / 'gate-summary.json', {'status': status, 'exit_code': code,
                       'evidence_level': 'static-check', 'commit': plan['commit'],
                       'profile': plan['profile'], 'gates': gates})
            print(f'Static prerequisites: {status}; no business tests executed. Evidence: {output}')
            return code
        if args.command == 'execution-summary':
            from .execution_runner import reconcile
            plan = validate_saved_plan(root, read_json(args.plan), catalog)
            from .execution_gates import merge_gate_statuses
            upstream = merge_gate_statuses(load_gates(args.results, plan), upstream_statuses(args.upstream, args.upstream_env))
            for gate in plan.get('gates', []):
                upstream.setdefault(gate, 'missing')
            summary = reconcile(plan, load_results(args.results), upstream=upstream)
            write_json(Path(args.output), summary)
            print_summary(summary)
            return summary['exit_code']
        ownership = catalog.build_catalog(root)
        if ownership.get('errors'):
            for error in ownership['errors']:
                print(f'OWNERSHIP_ERROR: {error}', file=sys.stderr)
            if args.command == 'execution-check' and args.output:
                write_json(Path(args.output), ownership)
            return 1
        if args.command == 'execution-check':
            if args.output:
                write_json(Path(args.output), ownership)
            if args.inventory:
                path = Path(args.inventory)
                path.parent.mkdir(parents=True, exist_ok=True)
                plan = catalog.build_plan(root, profile='pr')
                path.write_text(catalog.render_catalog_markdown(ownership, plan, catalog.load_contract(root)), encoding='utf-8')
            print('Static ownership valid; no business tests executed. ' + json.dumps(ownership['counts'], ensure_ascii=False))
            return 0
        if getattr(args, 'plan', None):
            if args.platform or args.product_profile or args.suite or args.target or args.variant or args.profile != 'pr':
                raise ValueError('--plan cannot be combined with selection arguments')
            plan = validate_saved_plan(root, read_json(args.plan), catalog)
        else:
            plan = catalog.build_plan(root, profile=args.profile,
                                      platforms=args.platform or None, products=args.product_profile or None,
                                      suites=args.suite or None, targets=args.target or None, variants=args.variant or None)
        if args.command == 'execution-plan':
            if args.output:
                write_json(Path(args.output), plan)
                selected = sum(bool(row.get('selected')) for row in plan['instances'])
                print(f'PLANNED: {selected} selected instances; no tests executed. {args.output}')
            else:
                print(json.dumps(plan, indent=2, ensure_ascii=False))
            return 0
        from .execution_runner import run_plan
        output = (Path(args.artifact_dir) if args.artifact_dir else reports / ('execution-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ'))).resolve()
        from .execution_gates import run_gates, merge_gate_statuses
        output.mkdir(parents=True, exist_ok=True)
        write_json(output / 'plan.json', plan)
        is_worker = bool(args.worker_platform or args.worker_suite or args.worker_product_profile)
        gates = {} if is_worker else run_gates(root, plan, output / 'gates', dict(os.environ))
        if gates:
            write_json(output / 'gates.json', gates)
        upstream = merge_gate_statuses(gates, upstream_statuses(args.upstream))
        report = run_plan(root, plan, output, env=dict(os.environ),
                          worker_platform=args.worker_platform, worker_suites=args.worker_suite or None,
                          worker_product_profile=args.worker_product_profile, coverage=args.coverage, upstream=upstream)
        # results.json is the sole reconciliation input; summaries are not reimported.
        write_json(output / 'results.json', {'artifact_root': str(output), 'results': report.get('results', [])})
        summary = report.get('summary', report)
        write_json(output / 'summary.json', summary)
        print_summary(summary)
        print(f'Evidence: {output.resolve()}')
        return report.get('exit_code', summary.get('exit_code', 2))
    except (ValueError, OSError, KeyError, TypeError) as error:
        failure = {'status': 'BLOCKED', 'reason_code': 'INVALID_OR_MISSING_EVIDENCE',
                   'detail': str(error), 'results': [], 'exit_code': 2}
        if args.command == 'execution-summary':
            write_json(Path(args.output), failure)
        print(json.dumps(failure, ensure_ascii=False), file=sys.stderr)
        return 2
