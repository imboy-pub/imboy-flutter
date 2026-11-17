"""Decide the UIUX offline CI gate without changing full-regression acceptance.

The ordinary execution summaries remain authoritative and are never rewritten.
Only the exact, declared specialist difference may be missing from the full report.
"""
from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path

from ci_source_lock import read_json, require, write_json
from uiux_full_matrix import matrix
from auto_test_lib.execution_runner import COUNT_KEYS, IDENTITY, _base

REPORT_FILES = {'sources': 'source-summary.json', 'coverage': 'lcov.summary.json',
                'offline': 'offline-summary.json', 'full': 'full-summary.json'}
SPECIALIST_SUITES = {'backend-contract', 'golden', 'device-single', 'device-pair', 'native-ui'}


def execution_rows(plan, report, label):
    """Check summary identity and accounting before interpreting its verdict."""
    selected = {row['id']: row for row in plan['instances'] if row.get('selected')}
    require(all(report.get(key) == plan.get(key) for key in ('commit', 'profile', 'scope')),
            label + '_SUMMARY_IDENTITY_MISMATCH')
    require(report.get('complete_regression') is False, label + '_FALSE_COMPLETENESS')
    require(report.get('issues') == [] and report.get('upstream_failed') == [],
            label + '_EVIDENCE_OR_UPSTREAM_FAILURE')
    rows = report['results']
    by_id = {row['id']: row for row in rows}
    require(len(rows) == len(by_id) == len(selected) and set(by_id) == set(selected)
            and report.get('expected_instances') == len(selected), label + '_INSTANCE_SET_MISMATCH')
    missing = report['missing_instances']
    require(len(missing) == len(set(missing)) and set(missing) <= set(selected)
            and report.get('reported_instances') == len(selected) - len(missing),
            label + '_MISSING_ACCOUNTING_MISMATCH')
    for key, row in by_id.items():
        expected = selected[key]
        require(all(row.get(field) == expected.get(field, plan.get(field)) for field in IDENTITY)
                and row.get('source_fingerprint') == plan.get('source_fingerprint')
                and row.get('product_contract') == expected.get('product_contract', {}),
                label + '_RESULT_IDENTITY_MISMATCH:' + key)
    require(report.get('status_counts') == dict(Counter(row.get('status') for row in rows))
            and report.get('counts') == {key: sum(row['counts'][key] for row in rows) for key in COUNT_KEYS},
            label + '_RESULT_COUNTS_MISMATCH')
    return by_id


def validate(full, offline, reports, codes):
    workers = matrix(full, offline)['include']
    require(full.get('profile') == offline.get('profile') == 'full'
            and full.get('scope') == 'full' and offline.get('full_regression') is False,
            'PLAN_SCOPE_INVALID')
    full_selected = {row['id']: row for row in full['instances'] if row.get('selected')}
    offline_ids = {row['id'] for row in offline['instances'] if row.get('selected')}
    excluded = set(full_selected) - offline_ids
    require(excluded and all(full_selected[key]['suite'] in SPECIALIST_SUITES for key in excluded),
            'UNDECLARED_SPECIALIST_SCOPE')
    for name in ('sources', 'coverage', 'offline'):
        require(type(codes[name]) is int and codes[name] == 0
                and type(reports[name].get('exit_code')) is int and reports[name]['exit_code'] == 0
                and reports[name].get('status') == 'PASS', name.upper() + '_NOT_PASS')

    sources, coverage = reports['sources'], reports['coverage']
    partitions = sorted(['gates'] + [':'.join(worker[key] for key in ('platform', 'suite', 'product'))
                                     for worker in workers])
    require(sources.get('scope') == 'source-binding-only' and sources.get('complete_regression') is False
            and sources.get('issues') == [] and sources.get('partitions_verified') == partitions,
            'SOURCE_PARTITIONS_INCOMPLETE')
    eligible = {key for key, row in full_selected.items()
                if row.get('platform') == 'linux' and row.get('coverage_eligible', row.get('coverage'))}
    require(eligible and eligible <= offline_ids, 'COVERAGE_SCOPE_MISMATCH')
    require(all(coverage.get(key) == full.get(key) for key in ('commit', 'profile'))
            and coverage.get('scope') == 'coverage' and coverage.get('platform') == 'linux'
            and coverage.get('complete_regression') is False and coverage.get('reason_code') == 'NONE'
            and coverage.get('issues') == [] and coverage.get('missing_evidence') == []
            and coverage.get('expected_instances') == coverage.get('verified_instances') == len(eligible)
            and coverage.get('coverage_files', 0) > 0, 'COVERAGE_EVIDENCE_INCOMPLETE')
    metrics = coverage['coverage']
    require(metrics.get('minimum') == 38 and metrics.get('threshold_met') is True
            and 38 <= metrics.get('percent', -1) <= 100, 'COVERAGE_THRESHOLD_NOT_MET')

    off = execution_rows(offline, reports['offline'], 'OFFLINE')
    require(reports['offline'].get('reason_code') == 'NONE' and reports['offline']['missing_instances'] == []
            and all(row.get('status') == 'PASS' and row.get('reason_code') == 'NONE' for row in off.values()),
            'OFFLINE_EXECUTION_INCOMPLETE')
    whole = execution_rows(full, reports['full'], 'FULL')
    require(type(codes['full']) is int and type(reports['full'].get('exit_code')) is int
            and codes['full'] == reports['full']['exit_code'] == 2
            and reports['full'].get('status') == 'BLOCKED'
            and reports['full'].get('reason_code') == 'INCOMPLETE_EXECUTION', 'FULL_UNEXPECTED_VERDICT')
    require(set(reports['full']['missing_instances']) == excluded, 'FULL_UNEXPECTED_MISSING_INSTANCES')
    require(all(whole[key] == row for key, row in off.items()), 'FULL_OFFLINE_RESULT_MISMATCH')
    # Reuse the runner's canonical missing receipt, including zero counts and no attempts.
    require(all(whole[key] == _base(full, full_selected[key], 'BLOCKED', 'MISSING_RESULT')
                for key in excluded), 'FULL_UNEXPECTED_SPECIALIST_RESULT')
    return {'offline_instances': len(off), 'unverified_full_instances': len(excluded),
            'unverified_suites': dict(sorted(Counter(full_selected[key]['suite'] for key in excluded).items()))}


def verdict(full, offline, reports, codes):
    full_report = reports.get('full')
    result = {'schema_version': 1, 'scope': 'uiux-offline-only', 'status': 'FAIL', 'exit_code': 1,
              'complete_regression': False,
              'full_regression_status': full_report.get('status') if isinstance(full_report, dict) else 'UNAVAILABLE',
              'process_exit_codes': codes, 'issues': []}
    try:
        result.update(validate(full, offline, reports, codes))
        result.update(status='PASS', exit_code=0)
    except (ValueError, KeyError, TypeError, AttributeError) as error:
        result['issues'].append(type(error).__name__ + ':' + str(error))
    return result


def step_summary(result, reports, codes):
    lines = ['## UIUX offline gate: ' + result['status'], '',
             '**A green CI check certifies only the declared offline scope.**',
             'Full regression remains separate; `full-summary.json` is preserved without changes.', '',
             '| Evidence | Status | Process exit |', '| --- | --- | --- |']
    for key, title in (('sources', 'Cross-repository source binding'), ('coverage', 'Linux coverage (minimum 38%)'),
                       ('offline', 'Offline execution'), ('full', 'Full regression obligations')):
        lines.append(f'| {title} | {reports.get(key, {}).get("status", "UNAVAILABLE")} | {codes[key]} |')
    lines += ['', '`complete_regression=false`. API/backend, Golden, device, paired-device and native-UI',
              'obligations are unverified by this workflow; missing evidence is not PASS or a completed skip.']
    if result.get('unverified_suites'):
        lines += ['', 'Unverified full-plan instances: ' + ', '.join(
            f'{name}={count}' for name, count in result['unverified_suites'].items()) + '.']
    if result['issues']:
        lines += ['', 'Offline CI verdict rejected:', *['- `' + issue.replace('`', "'") + '`' for issue in result['issues']]]
    return '\n'.join(lines) + '\n'


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--full-plan', required=True)
    parser.add_argument('--offline-plan', required=True)
    parser.add_argument('--summary-dir', required=True)
    parser.add_argument('--step-summary')
    for name in REPORT_FILES:
        parser.add_argument('--' + name + '-rc', required=True, type=int)
    args = parser.parse_args(argv)
    codes = {name: getattr(args, name + '_rc') for name in REPORT_FILES}
    reports = {}
    try:
        for name, file in REPORT_FILES.items():
            value = read_json(Path(args.summary_dir) / file)
            require(isinstance(value, dict), 'REPORT_NOT_OBJECT:' + name)
            reports[name] = value
        result = verdict(read_json(args.full_plan), read_json(args.offline_plan), reports, codes)
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
        result = {'schema_version': 1, 'scope': 'uiux-offline-only', 'status': 'FAIL', 'exit_code': 1,
                  'complete_regression': False, 'process_exit_codes': codes,
                  'issues': ['SUMMARY_INPUT_INVALID:' + type(error).__name__ + ':' + str(error)]}
    write_json(Path(args.summary_dir) / 'offline-ci-summary.json', result)
    if args.step_summary:
        with Path(args.step_summary).open('a', encoding='utf-8') as stream:
            stream.write(step_summary(result, reports, codes))
    print(json.dumps(result, sort_keys=True))
    return result['exit_code']


if __name__ == '__main__':
    raise SystemExit(main())
