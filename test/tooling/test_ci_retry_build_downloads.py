"""Build download retries preserve failures, arguments, and the retry budget."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[2] / '.github/scripts/ci_retry_build_downloads.sh'
GRADLE_ERROR = (
    'Exception in thread "main" java.io.IOException: Server returned HTTP response '
    'code: 504 for URL: https://github.com/gradle/gradle-distributions/releases/'
    'download/v8.14.0/gradle-8.14-all.zip'
)
SWIFTPM_ERROR = (
    "failed downloading 'https://github.com/webrtc-sdk/Specs/releases/download/"
    "150.7871.04/WebRTC.xcframework.zip' which is required by binary target "
    "'WebRTC': badResponseStatusCode(504)"
)
GIT_DNS_ERROR = (
    "fatal: unable to access 'https://gitee.com/imboy-tripartite-deps/azlistview.git/': "
    'Could not resolve host: gitee.com'
)
GIT_TLS_ERROR = '\n'.join([
    'Git error. Command: `git clone --mirror -- '
    'https://gitee.com/imboy-tripartite-deps/r_upgrade.git /tmp/pub-cache/_temp/fixture`',
    'stdout: ',
    "stderr: Cloning into bare repository '/tmp/pub-cache/_temp/fixture'...",
    'error: RPC failed; curl 56 GnuTLS recv error (-110): '
    'The TLS connection was non-properly terminated.',
    'error: 3680 bytes of body are still expected',
    'fetch-pack: unexpected disconnect while reading sideband packet',
    'fatal: early EOF',
    'fatal: fetch-pack: invalid index-pack output',
    'exit code: 128',
    'Failed to update packages.',
])

COMMAND = r'''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

calls = Path(os.environ['FIXTURE_CALLS'])
previous = calls.read_text().splitlines() if calls.exists() else []
with calls.open('a') as output:
    output.write(json.dumps(sys.argv[1:]) + '\n')
steps = json.loads(os.environ['FIXTURE_STEPS'])
step = steps[min(len(previous), len(steps) - 1)]
print(step.get('stdout', ''), flush=True)
print(step.get('stderr', ''), file=sys.stderr, flush=True)
sys.exit(step.get('exit_code', 0))
'''


class BuildDownloadRetryTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.bin_dir = self.root / 'bin'
        self.bin_dir.mkdir()
        self.command = self.bin_dir / 'build-fixture'
        self.command.write_text(COMMAND)
        sleeper = self.bin_dir / 'sleep'
        sleeper.write_text('#!/bin/sh\nprintf "%s\\n" "$1" >> "$FIXTURE_DELAYS"\n')
        for path in (self.command, sleeper):
            path.chmod(0o755)
        self.calls = self.root / 'calls.jsonl'
        self.delays = self.root / 'delays.txt'

    def run_build(self, steps, args=('--dart-define=SENTRY_DSN=private fixture',)):
        for path in (self.calls, self.delays):
            if path.exists():
                path.unlink()
        env = dict(os.environ, PATH=f'{self.bin_dir}:{os.environ["PATH"]}',
                   FIXTURE_CALLS=str(self.calls), FIXTURE_DELAYS=str(self.delays),
                   FIXTURE_STEPS=json.dumps(steps))
        result = subprocess.run(['bash', str(SCRIPT), str(self.command), *args],
                                cwd=self.root, env=env, capture_output=True,
                                text=True, timeout=10)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        delays = self.delays.read_text().splitlines() if self.delays.exists() else []
        self.assertEqual(calls, [list(args)] * len(calls))
        self.assertNotIn('private fixture', result.stdout + result.stderr)
        return result, calls, delays

    def test_success_runs_once_and_preserves_output(self):
        result, calls, delays = self.run_build([{'stdout': 'build complete'}])
        self.assertEqual(result.returncode, 0)
        self.assertEqual(len(calls), 1)
        self.assertEqual(delays, [])
        self.assertIn('build complete', result.stdout)

    def test_real_download_error_formats_recover(self):
        for error in (GRADLE_ERROR, SWIFTPM_ERROR):
            with self.subTest(error=error):
                result, calls, delays = self.run_build([
                    {'stderr': error, 'exit_code': 1}, {'stdout': 'build complete'},
                ])
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(len(calls), 2)
                self.assertEqual(delays, ['10'])
                self.assertIn(error, result.stdout)

    def test_other_http_codes_do_not_retry(self):
        for error in (GRADLE_ERROR, SWIFTPM_ERROR):
            for code in (408, 429, 500, 502, 503):
                with self.subTest(error=error, code=code):
                    result, calls, delays = self.run_build([
                        {'stderr': error.replace('504', str(code)), 'exit_code': 65}, {},
                    ])
                    self.assertEqual(result.returncode, 65)
                    self.assertEqual(len(calls), 1)
                    self.assertEqual(delays, [])

    def test_locked_pub_get_dns_failure_recovers_with_unchanged_arguments(self):
        self.command = self.command.rename(self.bin_dir / 'flutter')
        result, calls, delays = self.run_build([
            {'stderr': GIT_DNS_ERROR, 'exit_code': 69}, {},
        ], args=('pub', 'get', '--enforce-lockfile'))
        self.assertEqual(result.returncode, 0)
        self.assertEqual(len(calls), 2)
        self.assertEqual(delays, ['10'])

    def test_locked_pub_get_dns_failure_keeps_three_attempt_limit(self):
        self.command = self.command.rename(self.bin_dir / 'flutter')
        result, calls, delays = self.run_build([
            {'stderr': GIT_DNS_ERROR, 'exit_code': 69},
        ], args=('pub', 'get', '--enforce-lockfile'))
        self.assertEqual(result.returncode, 69)
        self.assertEqual(len(calls), 3)
        self.assertEqual(delays, ['10', '20'])

    def test_locked_pub_get_tls_disconnect_recovers_with_unchanged_arguments(self):
        self.command = self.command.rename(self.bin_dir / 'flutter')
        result, calls, delays = self.run_build([
            {'stderr': GIT_TLS_ERROR, 'exit_code': 69},
            {'stdout': 'Dependencies resolved'},
        ], args=('pub', 'get', '--enforce-lockfile'))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(len(calls), 2)
        self.assertEqual(delays, ['10'])
        self.assertIn(GIT_TLS_ERROR, result.stdout)
        self.assertIn('Dependencies resolved', result.stdout)

    def test_locked_pub_get_tls_disconnect_keeps_three_attempt_limit(self):
        self.command = self.command.rename(self.bin_dir / 'flutter')
        result, calls, delays = self.run_build([
            {'stderr': GIT_TLS_ERROR, 'exit_code': 69},
        ], args=('pub', 'get', '--enforce-lockfile'))
        self.assertEqual(result.returncode, 69)
        self.assertEqual(len(calls), 3)
        self.assertEqual(delays, ['10', '20'])
        self.assertIn('failed after 3 attempts (exit 69)', result.stderr)

    def test_tls_output_does_not_retry_other_commands_or_pub_errors(self):
        self.command = self.command.rename(self.bin_dir / 'flutter')
        for args, status in (
            (('build', 'apk'), 69), (('pub', 'get'), 65), (('pub', 'get'), 130),
        ):
            with self.subTest(args=args, status=status):
                result, calls, delays = self.run_build([
                    {'stderr': GIT_TLS_ERROR, 'exit_code': status}, {},
                ], args=args)
                self.assertEqual(result.returncode, status)
                self.assertEqual(len(calls), 1)
                self.assertEqual(delays, [])

    def test_pub_get_git_errors_without_transport_evidence_do_not_retry(self):
        self.command = self.command.rename(self.bin_dir / 'flutter')
        for error in (
            'fatal: early EOF\nfatal: fetch-pack: invalid index-pack output',
            'fatal: Remote branch missing-revision not found in upstream origin',
            "fatal: repository 'https://gitee.com/example/missing.git/' not found",
            'error: RPC failed; curl 60 SSL certificate problem: certificate has expired',
            "fatal: could not read Username for 'https://gitee.com': terminal prompts disabled",
            'Could not resolve dependencies: incompatible package versions',
        ):
            with self.subTest(error=error):
                result, calls, delays = self.run_build([
                    {'stderr': error, 'exit_code': 69}, {},
                ], args=('pub', 'get', '--enforce-lockfile'))
                self.assertEqual(result.returncode, 69)
                self.assertEqual(len(calls), 1)
                self.assertEqual(delays, [])

    def test_previous_tls_failure_does_not_retry_later_nontransport_failure(self):
        self.command = self.command.rename(self.bin_dir / 'flutter')
        for error in (
            'fatal: early EOF\nfatal: fetch-pack: invalid index-pack output',
            'fatal: Remote branch missing-revision not found in upstream origin',
        ):
            with self.subTest(error=error):
                result, calls, delays = self.run_build([
                    {'stderr': GIT_TLS_ERROR, 'exit_code': 69},
                    {'stderr': error, 'exit_code': 69}, {},
                ], args=('pub', 'get', '--enforce-lockfile'))
                self.assertEqual(result.returncode, 69)
                self.assertEqual(len(calls), 2)
                self.assertEqual(delays, ['10'])

    def test_dns_output_does_not_retry_other_commands_or_pub_errors(self):
        self.command = self.command.rename(self.bin_dir / 'flutter')
        for args, status in ((('build', 'apk'), 69), (('pub', 'get'), 65)):
            with self.subTest(args=args, status=status):
                result, calls, delays = self.run_build([
                    {'stderr': GIT_DNS_ERROR, 'exit_code': status}, {},
                ], args=args)
                self.assertEqual(result.returncode, status)
                self.assertEqual(len(calls), 1)
                self.assertEqual(delays, [])

    def test_previous_dns_failure_does_not_retry_lockfile_failure(self):
        self.command = self.command.rename(self.bin_dir / 'flutter')
        result, calls, delays = self.run_build([
            {'stderr': GIT_DNS_ERROR, 'exit_code': 69},
            {'stderr': 'Unable to satisfy pubspec.yaml using pubspec.lock.', 'exit_code': 65},
        ], args=('pub', 'get', '--enforce-lockfile'))
        self.assertEqual(result.returncode, 65)
        self.assertEqual(len(calls), 2)
        self.assertEqual(delays, ['10'])

    def test_flutter_internal_retry_does_not_mask_terminal_compile_failure(self):
        output = '\n'.join([
            GRADLE_ERROR.replace('504', '502'),
            'Retrying Gradle Build: #1, wait time: 100ms',
            'error: compilation failed',
        ])
        result, calls, delays = self.run_build([
            {'stderr': output, 'exit_code': 65}, {},
        ])
        self.assertEqual(result.returncode, 65)
        self.assertEqual(len(calls), 1)
        self.assertEqual(delays, [])

    def test_three_attempt_limit_preserves_last_failure(self):
        result, calls, delays = self.run_build([
            {'stderr': GRADLE_ERROR, 'exit_code': 1},
            {'stderr': GRADLE_ERROR, 'exit_code': 2},
            {'stderr': GRADLE_ERROR, 'exit_code': 65},
        ])
        self.assertEqual(result.returncode, 65)
        self.assertEqual(len(calls), 3)
        self.assertEqual(delays, ['10', '20'])
        self.assertIn('failed after 3 attempts', result.stderr)

    def test_deterministic_errors_do_not_retry(self):
        errors = [
            'error: compilation failed at source line 504',
            'Code signing failed',
            'checksum mismatch for WebRTC.xcframework.zip',
            'Could not resolve dependencies: incompatible package versions',
            'SSL certificate verification failed',
            GRADLE_ERROR.replace('504', '401'),
            GRADLE_ERROR.replace('504', '403'),
            GRADLE_ERROR.replace('504', '404'),
            SWIFTPM_ERROR.replace('504', '404'),
            SWIFTPM_ERROR.replace('504', '501'),
        ]
        for error in errors:
            with self.subTest(error=error):
                result, calls, delays = self.run_build([{'stderr': error, 'exit_code': 65}])
                self.assertEqual(result.returncode, 65)
                self.assertEqual(len(calls), 1)
                self.assertEqual(delays, [])

    def test_previous_download_error_does_not_retry_later_compile_failure(self):
        result, calls, delays = self.run_build([
            {'stderr': SWIFTPM_ERROR, 'exit_code': 1},
            {'stderr': 'error: compilation failed', 'exit_code': 65},
        ])
        self.assertEqual(result.returncode, 65)
        self.assertEqual(len(calls), 2)
        self.assertEqual(delays, ['10'])

    def test_cancelled_command_does_not_retry_download_output(self):
        result, calls, delays = self.run_build([{'stderr': GRADLE_ERROR, 'exit_code': 130}])
        self.assertEqual(result.returncode, 130)
        self.assertEqual(len(calls), 1)
        self.assertEqual(delays, [])

    def test_log_forwarding_failure_cannot_report_success(self):
        tee = self.bin_dir / 'tee'
        tee.write_text('#!/bin/sh\ncat >/dev/null\nexit 74\n')
        tee.chmod(0o755)
        result, calls, delays = self.run_build([{'stdout': 'build complete'}])
        self.assertEqual(result.returncode, 74)
        self.assertEqual(len(calls), 1)
        self.assertEqual(delays, [])

    def test_requires_a_command(self):
        result = subprocess.run(['bash', str(SCRIPT)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 64)
        self.assertIn('Usage:', result.stderr)


if __name__ == '__main__':
    unittest.main()
