"""The legacy route command delegates selection and verdicts to one runner."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

RUNNER = Path(__file__).with_name('run_smoke_isolated.sh')
REPO = RUNNER.parents[3]
sys.path.insert(0, str(REPO / 'scripts'))
from auto_test_lib.execution_runner import _persist_process_receipt, _record_attempt, _verdict


class IsolatedRunnerTests(unittest.TestCase):
    def invoke(self, options=(), exit_code=0):
        with tempfile.TemporaryDirectory(prefix='imboy-route-wrapper-') as tmp:
            temporary = Path(tmp)
            shim = temporary / 'python3'
            # Observe the real shell boundary. This shim supplies no test verdict;
            # it only proves the wrapper preserves the unified CLI's exit code.
            shim.write_text('#!' + sys.executable + '\n' + """import json, os, sys
from pathlib import Path
Path(os.environ['CAPTURE']).write_text(json.dumps({
    'cwd': os.getcwd(), 'argv': sys.argv[1:],
    'probe_quarantine': os.environ.get('IMBOY_SMOKE_INCLUDE_QUARANTINED'),
}))
print('unified runner receipt')
sys.exit(int(os.environ['CLI_EXIT']))
""")
            shim.chmod(0o755)
            env = {**os.environ, 'PATH': str(temporary) + os.pathsep + os.environ['PATH'],
                   'CAPTURE': str(temporary / 'capture.json'), 'CLI_EXIT': str(exit_code),
                   'SMOKE_OUTPUT_DIR': str(temporary / 'evidence')}
            env.pop('IMBOY_SMOKE_INCLUDE_QUARANTINED', None)
            result = subprocess.run(['bash', str(RUNNER), *options], cwd=temporary,
                                    env=env, capture_output=True, text=True)
            capture = temporary / 'capture.json'
            return result, json.loads(capture.read_text()) if capture.exists() else None

    def test_wrapper_selects_current_host_via_shared_cli(self):
        result, receipt = self.invoke(['--quiet', '--route', 'welcome', '--route', 'e2ee_key_recovery'])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(receipt['cwd'], str(REPO))
        self.assertEqual(receipt['argv'][:4], ['scripts/auto_test.py', 'execution-run', '--profile', 'routes'])
        platform = receipt['argv'][receipt['argv'].index('--platform') + 1]
        self.assertEqual(platform, 'macos' if sys.platform == 'darwin' else 'linux')
        self.assertEqual(receipt['argv'][6:10], ['--variant', 'route:welcome', '--variant', 'route:e2ee_key_recovery'])
        self.assertIn('--artifact-dir', receipt['argv'])
        self.assertNotIn('flutter', receipt['argv'])

    def test_wrapper_preserves_failure_and_incomplete_exit_codes(self):
        for exit_code in (0, 1, 2, 7):
            with self.subTest(exit_code=exit_code):
                result, _ = self.invoke(exit_code=exit_code)
                self.assertEqual(result.returncode, exit_code)
                self.assertNotIn('All selected routes executed and passed', result.stdout)

    def test_include_quarantined_is_real_probe_flag_not_a_skip_waiver(self):
        result, receipt = self.invoke(['--include-quarantined'], exit_code=2)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(receipt['probe_quarantine'], 'true')
        self.assertFalse(any('waiver' in value or 'allow-skip' in value for value in receipt['argv']))

    def test_dry_run_only_delegates_plan(self):
        for routes in ([], ['welcome'], ['page with spaces/*', '']):
            with self.subTest(routes=routes):
                options = ['--dry-run']
                variants = []
                for route in routes:
                    options.extend(['--route', route])
                    variants.extend(['--variant', 'route:' + route])
                result, receipt = self.invoke(options)
                self.assertEqual(result.returncode, 0, result.stderr)
                platform = 'macos' if sys.platform == 'darwin' else 'linux'
                self.assertEqual(receipt['argv'], [
                    'scripts/auto_test.py', 'execution-plan', '--profile', 'routes',
                    '--platform', platform, *variants])
                self.assertNotIn('--artifact-dir', receipt['argv'])

    def test_missing_value_or_unknown_flag_never_reaches_runner(self):
        for options in (['--route'], ['--unknown']):
            with self.subTest(options=options):
                result, receipt = self.invoke(options)
                self.assertNotEqual(result.returncode, 0)
                self.assertIsNone(receipt)

    def test_unknown_route_is_rejected_by_real_catalog_cli(self):
        result = subprocess.run(['bash', str(RUNNER), '--dry-run', '--route', 'not_a_registered_route'],
                                cwd=REPO, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('UNKNOWN_SELECTED_VARIANT', result.stderr)


class SharedRouteVerdictTests(unittest.TestCase):
    def verdict(self, results, exit_code=0, done=True):
        events = []
        for index, kind in enumerate(results):
            events.extend([
                {'type': 'testStart', 'test': {'id': index, 'name': 'route case ' + str(index)}},
                {'type': 'testDone', 'testID': index, 'result': 'failure' if kind == 'fail' else 'success',
                 'skipped': kind == 'skip'},
            ])
        if done:
            events.append({'type': 'done', 'success': 'fail' not in results})
        lines = [json.dumps(event) for event in events]
        evidence = tempfile.TemporaryDirectory(prefix='imboy-route-evidence-')
        self.addCleanup(evidence.cleanup)
        path = Path(evidence.name) / 'machine.jsonl'
        path.write_text('\n'.join(lines))
        target = 'test/unit_test/smoke/route_smoke_test.dart'
        receipt = _persist_process_receipt({'exit_code': exit_code,
            'log': str(path), 'machine': str(path),
            'command': ['flutter', 'test', target, '--machine']}, Path(evidence.name))
        attempt = _record_attempt(REPO, {'commit': 'synthetic-route-contract'},
            {'id': 'synthetic-route', 'target': target, 'dependencies': []}, receipt, lines)
        return _verdict([attempt])

    def test_zero_all_skip_partial_skip_and_incomplete_stream_never_pass(self):
        for results, done in [([], True), (['skip'], True), (['pass', 'skip'], True), (['pass'], False)]:
            with self.subTest(results=results, done=done):
                self.assertNotEqual(self.verdict(results, done=done)['test_status'], 'PASS')
        self.assertEqual(self.verdict(['pass', 'skip'])['reason_code'], 'UNEXPECTED_SKIP')

    def test_nonzero_process_vetoes_successful_events(self):
        self.assertEqual(self.verdict(['pass'])['test_status'], 'PASS')
        self.assertNotEqual(self.verdict(['pass'], exit_code=1)['test_status'], 'PASS')
        self.assertEqual(self.verdict(['fail'], exit_code=1)['test_status'], 'FAIL')


if __name__ == '__main__':
    unittest.main()
