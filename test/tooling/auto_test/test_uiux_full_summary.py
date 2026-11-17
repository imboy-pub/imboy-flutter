"""Offline CI acceptance must preserve and constrain the full BLOCKED report."""
import copy
from collections import Counter
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / '.github/scripts'))
import uiux_full_summary as scope  # noqa: E402
from auto_test_lib import execution_runner as runner  # noqa: E402


class OfflineSummaryTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        rows = [self.instance('offline-' + product, 'unit', 'linux', product)
                for product in ('phase1_delivery', 'full-selected')]
        rows += [self.instance(suite, suite, platform) for suite, platform in (
            ('backend-contract', 'linux'), ('golden', 'macos'), ('device-single', 'android'),
            ('device-pair', 'macos'), ('native-ui', 'android'))]
        self.full = dict(commit='a' * 40, source_fingerprint='b' * 64, profile='full', scope='full',
                         full_regression=True, gates=['ownership'], instances=rows)
        self.offline = dict(copy.deepcopy(self.full), scope='scoped', full_regression=False)
        for row in self.offline['instances'][2:]:
            row['selected'] = False
        receipts = [self.receipt(row) for row in rows[:2]]
        self.reports = {
            'sources': dict(scope='source-binding-only', status='PASS', exit_code=0, complete_regression=False,
                            partitions_verified=['gates', 'linux:unit:full-selected', 'linux:unit:phase1_delivery'],
                            issues=[]),
            'coverage': dict(scope='coverage', status='PASS', exit_code=0, reason_code='NONE',
                             complete_regression=False, commit=self.full['commit'], profile='full', platform='linux',
                             expected_instances=2, verified_instances=2, coverage_files=2, issues=[], missing_evidence=[],
                             coverage=dict(covered_lines=40, source_lines=100, percent=40, minimum=38, threshold_met=True)),
            'offline': runner.reconcile(self.offline, receipts, {'ownership': 'PASS'}),
            'full': runner.reconcile(self.full, receipts, {'ownership': 'PASS'}),
        }
        self.codes = dict(sources=0, coverage=0, offline=0, full=2)
        self.assertEqual(self.reports['offline']['status'], 'PASS', self.reports['offline'])
        self.assertEqual(self.reports['full']['reason_code'], 'INCOMPLETE_EXECUTION')

    @staticmethod
    def instance(name, suite, platform, product='phase1_delivery'):
        target = 'test/' + name + '_test.dart'
        return dict(id=json.dumps([target, platform, product, 'primary', 'default']), target=target,
                    suite=suite, platform=platform, product_profile=product, runner='flutter-machine',
                    role='primary', variant='default', selected=True, upstream=['ownership'],
                    product_contract={'manifest_profile': 'any'}, coverage_eligible=suite == 'unit')

    def receipt(self, row):
        target = self.root / row['target']
        target.parent.mkdir(exist_ok=True)
        target.write_text('// synthetic offline target\n')
        output = self.root / row['product_profile']
        output.mkdir()
        lines = [json.dumps(event) for event in (
            {'type': 'suite', 'suite': {'id': 1, 'path': row['target']}},
            {'type': 'testStart', 'test': {'id': 1, 'suiteID': 1, 'name': 'synthetic case'}},
            {'type': 'testDone', 'testID': 1, 'result': 'success', 'skipped': False},
            {'type': 'done', 'success': True})]
        machine = output / 'machine.jsonl'
        machine.write_text('\n'.join(lines) + '\n')
        receipt = {'exit_code': 0, 'log': str(machine), 'machine': str(machine),
                   'command': ['flutter', 'test', row['target'], '--machine'],
                   'execution_context': runner._capture_execution_context(output)}
        runner._persist_process_receipt(receipt, output)
        attempt = runner._record_attempt(self.root, self.full, row, receipt, lines)
        return runner._finish(self.full, row, [attempt])

    def verdict(self):
        return scope.verdict(self.full, self.offline, self.reports, self.codes)

    def assert_rejected(self, reason):
        result = self.verdict()
        self.assertEqual(result['status'], 'FAIL', result)
        self.assertEqual(result['exit_code'], 1)
        self.assertFalse(result['complete_regression'])
        self.assertTrue(any(reason in issue for issue in result['issues']), result)

    def test_offline_pass_keeps_full_report_blocked_and_byte_equivalent(self):
        original = copy.deepcopy((self.full, self.offline, self.reports))
        result = self.verdict()
        self.assertEqual(result['status'], 'PASS', result)
        self.assertEqual(result['scope'], 'uiux-offline-only')
        self.assertEqual(result['unverified_full_instances'], 5)
        self.assertEqual(result['full_regression_status'], 'BLOCKED')
        self.assertFalse(result['complete_regression'])
        self.assertEqual((self.full, self.offline, self.reports), original)
        self.assertFalse(self.reports['full']['complete_regression'])

    def test_each_mandatory_process_and_report_must_pass(self):
        original = copy.deepcopy(self.reports)
        for name in ('sources', 'coverage', 'offline'):
            for change in ('exit', 'status', 'report_exit'):
                with self.subTest(name=name, change=change):
                    self.reports = copy.deepcopy(original)
                    self.codes[name] = 2 if change == 'exit' else 0
                    if change == 'status':
                        self.reports[name]['status'] = 'BLOCKED'
                    if change == 'report_exit':
                        self.reports[name]['exit_code'] = 2
                    self.assert_rejected(name.upper() + '_NOT_PASS')
            self.codes[name] = 0

    def test_source_partitions_and_coverage_cannot_be_relaxed(self):
        original = copy.deepcopy(self.reports)
        changes = [('sources', 'partitions_verified', ['gates'], 'SOURCE_PARTITIONS'),
                   ('coverage', 'verified_instances', 1, 'COVERAGE_EVIDENCE'),
                   ('coverage', 'commit', 'c' * 40, 'COVERAGE_EVIDENCE'),
                   ('coverage', 'missing_evidence', [{'id': 'lost'}], 'COVERAGE_EVIDENCE')]
        for name, key, value, reason in changes:
            with self.subTest(key=key):
                self.reports = copy.deepcopy(original)
                self.reports[name][key] = value
                self.assert_rejected(reason)
        for change in ({'minimum': 0}, {'percent': 37}, {'threshold_met': False}):
            self.reports = copy.deepcopy(original)
            self.reports['coverage']['coverage'].update(change)
            self.assert_rejected('COVERAGE_THRESHOLD')

    def test_genuine_full_fail_and_unexpected_exit_codes_are_rejected(self):
        original = copy.deepcopy(self.reports['full'])
        for status, reason, code in (('FAIL', 'TEST_FAILED', 1), ('PASS', 'NONE', 0),
                                     ('BLOCKED', 'UPSTREAM_FAILED', 2), ('BLOCKED', 'INCOMPLETE_EXECUTION', 3)):
            with self.subTest(status=status, reason=reason, code=code):
                self.reports['full'] = dict(copy.deepcopy(original), status=status, reason_code=reason, exit_code=code)
                self.codes['full'] = code
                self.assert_rejected('FULL_UNEXPECTED_VERDICT')
        self.reports['full'] = original
        self.codes['full'] = 0  # A crashed/stale command cannot borrow an old BLOCKED file.
        self.assert_rejected('FULL_UNEXPECTED_VERDICT')

    def test_full_missing_specialists_cannot_hide_flaky_fail_or_unexpected_block(self):
        original = copy.deepcopy(self.reports['full'])
        for status, reason in (('FLAKY', 'INFRA_FAIL'), ('FAIL', 'BUSINESS_ASSERTION_FAIL'),
                               ('BLOCKED', 'STALE_PLAN_RESULT'), ('PASS', 'NONE'), ('SKIPPED', 'OUT_OF_SCOPE')):
            with self.subTest(status=status, reason=reason):
                self.reports['full'] = copy.deepcopy(original)
                self.reports['full']['results'][-1].update(status=status, reason_code=reason)
                self.reports['full']['status_counts'] = dict(Counter(row['status'] for row in self.reports['full']['results']))
                self.assert_rejected('FULL_UNEXPECTED_SPECIALIST_RESULT')

    def test_missing_or_duplicate_offline_result_fails(self):
        original = copy.deepcopy(self.reports)
        for name in ('offline', 'full'):
            with self.subTest(name=name):
                self.reports = copy.deepcopy(original)
                self.reports[name]['results'].pop(0)
                self.assert_rejected(name.upper() + '_INSTANCE_SET_MISMATCH')
        self.reports = copy.deepcopy(original)
        self.reports['full']['missing_instances'].append(self.reports['full']['missing_instances'][0])
        self.assert_rejected('FULL_MISSING_ACCOUNTING')

    def test_missing_set_must_be_exact_and_reports_must_agree(self):
        full = self.reports['full']
        original = copy.deepcopy(full)
        full['missing_instances'][0] = full['results'][0]['id']
        self.assert_rejected('FULL_UNEXPECTED_MISSING_INSTANCES')
        self.reports['full'] = copy.deepcopy(original)
        self.reports['full']['results'][0]['logs'] = ['different-attempt.log']
        self.assert_rejected('FULL_OFFLINE_RESULT_MISMATCH')

    def test_evidence_identity_and_full_completeness_are_not_optional(self):
        original = copy.deepcopy(self.reports)
        for name in ('offline', 'full'):
            for key, value, reason in (('issues', ['UNEXPECTED_RESULT'], '_EVIDENCE_OR_UPSTREAM'),
                                       ('upstream_failed', ['ownership'], '_EVIDENCE_OR_UPSTREAM'),
                                       ('commit', 'd' * 40, '_SUMMARY_IDENTITY'),
                                       ('complete_regression', True, '_FALSE_COMPLETENESS')):
                with self.subTest(name=name, key=key):
                    self.reports = copy.deepcopy(original)
                    self.reports[name][key] = value
                    self.assert_rejected(name.upper() + reason)
        self.reports = copy.deepcopy(original)
        self.reports['full']['results'][-1]['attempts'] = [{'status': 'PASS'}]
        self.assert_rejected('FULL_UNEXPECTED_SPECIALIST_RESULT')

    def test_unknown_exclusion_and_omitted_offline_obligation_are_rejected(self):
        self.full['instances'][-1]['suite'] = 'new-unreviewed-suite'
        self.assert_rejected('UNDECLARED_SPECIALIST_SCOPE')
        self.full['instances'][-1]['suite'] = 'native-ui'
        self.offline['instances'][0]['selected'] = False
        self.assert_rejected('OFFLINE_SELECTION_INCOMPLETE')

    def run_workflow_verdict(self):
        plan_dir, summary_dir = self.root / 'uiux-plan', self.root / 'uiux-summary'
        scope.write_json(plan_dir / 'full-plan.json', self.full)
        scope.write_json(plan_dir / 'offline-plan.json', self.offline)
        for name, file in scope.REPORT_FILES.items():
            scope.write_json(summary_dir / file, self.reports[name])
        full_bytes = (summary_dir / 'full-summary.json').read_bytes()
        workflow = (ROOT / '.github/workflows/uiux-full-offline.yml').read_text()
        start = workflow.index('          python3 .github/scripts/uiux_full_summary.py')
        end = workflow.index('\n      - uses: actions/upload-artifact', start)
        command = textwrap.dedent(workflow[start:end])
        environment = dict(os.environ, RUNNER_TEMP=str(self.root), out=str(summary_dir),
                           GITHUB_STEP_SUMMARY=str(self.root / 'step-summary.md'))
        environment.update({name + '_rc': str(code) for name, code in self.codes.items()})
        result = subprocess.run(['bash', '-c', command], cwd=ROOT, env=environment,
                                capture_output=True, text=True)
        self.assertEqual((summary_dir / 'full-summary.json').read_bytes(), full_bytes)
        return result, scope.read_json(summary_dir / 'offline-ci-summary.json')

    def test_actual_workflow_verdict_command_propagates_both_exit_branches(self):
        passed, report = self.run_workflow_verdict()
        self.assertEqual(passed.returncode, 0, passed.stdout + passed.stderr)
        self.assertEqual(report['status'], 'PASS')
        summary = (self.root / 'step-summary.md').read_text()
        self.assertIn('only the declared offline scope', summary)
        self.assertIn('| Full regression obligations | BLOCKED | 2 |', summary)
        self.assertIn('complete_regression=false', summary)
        self.codes['coverage'] = 1
        failed, report = self.run_workflow_verdict()
        self.assertEqual(failed.returncode, 1, failed.stdout + failed.stderr)
        self.assertEqual(report['status'], 'FAIL')

    def test_missing_malformed_and_non_object_summary_are_failures(self):
        passed, _ = self.run_workflow_verdict()
        self.assertEqual(passed.returncode, 0)
        directory = self.root / 'uiux-summary'
        for content in (None, '{"status":', '[]', '{"status":"PASS","status":"BLOCKED"}'):
            with self.subTest(content=content):
                path = directory / 'source-summary.json'
                if content is None:
                    path.unlink()
                else:
                    path.write_text(content)
                command = [sys.executable, str(ROOT / '.github/scripts/uiux_full_summary.py'),
                           '--full-plan', str(self.root / 'uiux-plan/full-plan.json'),
                           '--offline-plan', str(self.root / 'uiux-plan/offline-plan.json'),
                           '--summary-dir', str(directory), '--step-summary', str(self.root / 'step-summary.md')]
                for name, code in self.codes.items():
                    command += ['--' + name + '-rc', str(code)]
                result = subprocess.run(command, capture_output=True, text=True)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                report = scope.read_json(directory / 'offline-ci-summary.json')
                self.assertIn('SUMMARY_INPUT_INVALID:', report['issues'][0])


if __name__ == '__main__':
    unittest.main()
