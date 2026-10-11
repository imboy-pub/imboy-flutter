"""Runner contracts without Flutter compilation or application/network startup."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

RUNNER = Path(__file__).with_name("run_smoke_isolated.sh")
REPO = RUNNER.parents[3]


class IsolatedRunnerTests(unittest.TestCase):
    def run_case(self, mode, names=("welcome",), exit_code=0):
        with tempfile.TemporaryDirectory(prefix="imboy-runner-contract-") as tmp:
            root = Path(tmp)
            executable = root / "flutter"
            executable.write_text("""#!/usr/bin/env python3
import json, os, sys
assert os.getcwd() == os.environ['EXPECTED_REPO']
assert sys.argv[1:3] == ['test', 'test/unit_test/smoke/route_smoke_test.dart']
print(json.dumps([]))  # Flutter/dependency log lines can contain valid non-event JSON.
mode = os.environ['FAKE_MODE']
name = os.environ.get('FAKE_NAME', 'welcome')
if mode != 'missing':
    title = '[quarantine] ' + name + ' — fixture' if mode == 'skip' else name + ' (/fixture) rendering'
    print(json.dumps({'type': 'testStart', 'test': {'id': 9, 'name': title}}))
    print(json.dumps({'type': 'testDone', 'testID': 9, 'result': 'failure' if mode == 'fail' else 'success', 'skipped': mode == 'skip'}))
if mode != 'unfinished':
    print(json.dumps({'type': 'done', 'success': mode != 'fail'}))
sys.exit(int(os.environ['FAKE_EXIT']))
""")
            executable.chmod(0o755)
            env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ['PATH'],
                       EXPECTED_REPO=str(REPO), FAKE_MODE=mode, FAKE_NAME=names[0],
                       FAKE_EXIT=str(exit_code), SMOKE_OUTPUT_DIR=str(root / 'evidence'))
            args = ['bash', str(RUNNER), '--quiet']
            for name in names:
                args += ['--route', name]
            return subprocess.run(args, cwd=tmp, env=env, capture_output=True, text=True)

    def test_pass_and_repository_root(self):
        result = self.run_case('pass')
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn('PASS=1 SKIP=0 FAIL=0', result.stdout)

    def test_skip_is_incomplete_not_pass(self):
        result = self.run_case('skip')
        self.assertEqual(2, result.returncode)
        self.assertIn('PASS=0 SKIP=1', result.stdout)
        self.assertNotIn('All selected routes executed and passed.', result.stdout)

    def test_missing_target_fails(self):
        self.assertEqual(1, self.run_case('missing').returncode)

    def test_unfinished_report_fails(self):
        self.assertEqual(1, self.run_case('unfinished').returncode)

    def test_failure_fails(self):
        self.assertEqual(1, self.run_case('fail', exit_code=1).returncode)

    def test_nonzero_process_cannot_certify_success(self):
        self.assertEqual(1, self.run_case('pass', exit_code=1).returncode)

    def test_unknown_route_fails_before_flutter(self):
        result = self.run_case('pass', names=('not_a_registered_route',))
        self.assertEqual(1, result.returncode)
        self.assertIn('unknown route', result.stderr)


if __name__ == '__main__':
    unittest.main()
