"""Build download retries preserve failures, arguments, and the retry budget."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import textwrap
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / '.github/scripts/ci_retry_build_downloads.sh'
DEPENDENCY_STEPS = (
    ('ci.yml', 'host-tests', 'Prepare isolated host dependencies', True),
    ('ci.yml', 'build', 'Get dependencies', True),
    ('ci.yml', 'build-ios', 'Get dependencies', True),
    ('ci.yml', 'route-smoke-test', 'Prepare host', True),
    ('quality.yml', 'sqlite-migration-gate', 'Get dependencies', False),
    ('quality.yml', 'flutter-analyze', 'Get dependencies', False),
)
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
GIT_OPENSSL_TLS_ERROR = '\n'.join([
    'Git error. Command: `git clone --mirror -- '
    'https://gitee.com/imboy-tripartite-deps/jverify-flutter-plugin.git '
    '/tmp/pub-cache/_temp/fixture`',
    'stdout: ',
    "stderr: Cloning into bare repository '/tmp/pub-cache/_temp/fixture'...",
    'error: RPC failed; curl 56 OpenSSL SSL_read: OpenSSL/4.1.0: '
    'error:0A000126:SSL routines::unexpected eof while reading, errno 0',
    'error: 3875 bytes of body are still expected',
    'fetch-pack: unexpected disconnect while reading sideband packet',
    'fatal: early EOF',
    'fatal: fetch-pack: invalid index-pack output',
    'exit code: 128',
    'Failed to update packages.',
])
GIT_EOF_ERROR = '\n'.join([
    'Git error. Command: `git clone --mirror '
    'https://gitee.com/imboy-tripartite-deps/jverify-flutter-plugin.git /tmp/pub-git-fixture`',
    'error: RPC failed; curl 56 OpenSSL SSL_read: OpenSSL/4.1.0: '
    'error:0A000126:SSL routines::unexpected eof while reading, errno 0',
    'error: 3925 bytes of body are still expected',
    'fetch-pack: unexpected disconnect while reading sideband packet',
    'fatal: early EOF',
    'fatal: fetch-pack: invalid index-pack output',
])
GIT_CURL18_EOF_ERROR = '\n'.join([
    'Git error. Command: `git clone --mirror '
    'https://gitee.com/imboy-tripartite-deps/audio_waveforms.git /tmp/pub-git-fixture`',
    'error: RPC failed; curl 18 transfer closed with outstanding read data remaining',
    'error: 12554 bytes of body are still expected',
    'fetch-pack: unexpected disconnect while reading sideband packet',
    'fatal: early EOF',
    'fatal: fetch-pack: invalid index-pack output',
])
GIT_TRANSPORT_ERRORS = (GIT_DNS_ERROR, GIT_TLS_ERROR, GIT_OPENSSL_TLS_ERROR,
                        GIT_EOF_ERROR, GIT_CURL18_EOF_ERROR)

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

    def run_build(self, steps, args=('--dart-define=SENTRY_DSN=private fixture',),
                  *, command=None, environment=None):
        for path in (self.calls, self.delays):
            if path.exists():
                path.unlink()
        env = dict(os.environ, PATH=f'{self.bin_dir}:{os.environ["PATH"]}',
                   FIXTURE_CALLS=str(self.calls), FIXTURE_DELAYS=str(self.delays),
                   FIXTURE_STEPS=json.dumps(steps))
        env.update(environment or {})
        result = subprocess.run(command or ['bash', str(SCRIPT), str(self.command), *args],
                                cwd=self.root, env=env, capture_output=True,
                                text=True, timeout=10)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        delays = self.delays.read_text().splitlines() if self.delays.exists() else []
        self.assertEqual(calls, [list(args)] * len(calls))
        self.assertNotIn('private fixture', result.stdout + result.stderr)
        return result, calls, delays

    def run_workflow_dependencies(self, workflow, job_name, step_name, locked, steps):
        """Execute the committed run block; only the SDK and unrelated prep are synthetic."""
        source = (ROOT / '.github/workflows' / workflow).read_text(encoding='utf-8')
        job = re.search(r'^  ' + re.escape(job_name) + r':\n(.*?)(?=^  [\w-]+:\n|\Z)',
                        source, re.MULTILINE | re.DOTALL)
        self.assertIsNotNone(job)
        step = re.search(r'^      - name: ' + re.escape(step_name) + r'\n(.*?)(?=^      - |\Z)',
                         job[1], re.MULTILINE | re.DOTALL)
        self.assertIsNotNone(step)
        run = re.search(r'^        run: (.*)', step[1], re.MULTILINE)
        self.assertIsNotNone(run)
        command = (textwrap.dedent(step[1][run.end() + 1:])
                   if run[1] == '|' else run[1])

        scripts = self.root / '.github/scripts'
        scripts.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(SCRIPT, scripts / SCRIPT.name)
        for name in ('ci_patch_path_deps.sh', 'ci_gen_env.sh', 'ci_build_vod.sh'):
            (scripts / name).write_text('#!/bin/sh\nprintf "%s\\n" "' + name + '"\n')
        sdk_check = self.root / 'scripts/check_sdk_compatibility.py'
        sdk_check.parent.mkdir(exist_ok=True)
        sdk_check.write_text('raise SystemExit(0)\n')
        if self.command.name != 'flutter':
            self.command = self.command.rename(self.bin_dir / 'flutter')
        for name in ('bash', 'python3', 'mktemp', 'tee', 'grep', 'rm'):
            executable = shutil.which(name)
            self.assertIsNotNone(executable)
            if not (self.bin_dir / name).exists():
                (self.bin_dir / name).symlink_to(executable)
        args = ('pub', 'get', '--enforce-lockfile') if locked else ('pub', 'get')
        return self.run_build(
            steps, args=args,
            command=['bash', '--noprofile', '--norc', '-e', '-o', 'pipefail', '-c',
                     command + '\nprintf "dependency preparation finished\\n"\n'],
            environment={'PATH': str(self.bin_dir), 'WORKER_PLATFORM': 'linux',
                         'WORKER_SUITE': 'unit', 'WORKER_EVIDENCE_DIR': str(self.root / 'evidence')})

    def test_workflow_dependency_steps_recover_before_running_followup_preparation(self):
        for target in DEPENDENCY_STEPS:
            for error in GIT_TRANSPORT_ERRORS:
                with self.subTest(target=target, error=error):
                    result, calls, delays = self.run_workflow_dependencies(*target, steps=[
                        {'stderr': error.replace('r_upgrade.git', 'audio_waveforms.git'),
                         'exit_code': 69}, {},
                    ])
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertEqual(len(calls), 2)
                    self.assertEqual(delays, ['10'])
                    self.assertIn('dependency preparation finished', result.stdout)

    def test_workflow_dependency_steps_preserve_exhausted_download_failure(self):
        for target in DEPENDENCY_STEPS:
            with self.subTest(target=target):
                result, calls, delays = self.run_workflow_dependencies(*target, steps=[
                    {'stderr': GIT_TLS_ERROR, 'exit_code': 69},
                ])
                self.assertEqual(result.returncode, 69, result.stdout + result.stderr)
                self.assertEqual(len(calls), 3)
                self.assertEqual(delays, ['10', '20'])
                self.assertNotIn('dependency preparation finished', result.stdout)
                self.assertNotIn('ci_gen_env.sh', result.stdout)
                self.assertNotIn('ci_build_vod.sh', result.stdout)

    def test_workflow_dependency_steps_stop_on_permanent_package_failure(self):
        for target in DEPENDENCY_STEPS:
            with self.subTest(target=target):
                result, calls, delays = self.run_workflow_dependencies(*target, steps=[
                    {'stderr': 'Unable to satisfy pubspec.yaml using pubspec.lock.', 'exit_code': 65}, {},
                ])
                self.assertEqual(result.returncode, 65, result.stdout + result.stderr)
                self.assertEqual(len(calls), 1)
                self.assertEqual(delays, [])
                self.assertNotIn('dependency preparation finished', result.stdout)
                self.assertNotIn('ci_gen_env.sh', result.stdout)
                self.assertNotIn('ci_build_vod.sh', result.stdout)

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

    def test_locked_pub_get_git_transport_failure_recovers_with_unchanged_arguments(self):
        self.command = self.command.rename(self.bin_dir / 'flutter')
        for error in GIT_TRANSPORT_ERRORS:
            with self.subTest(error=error):
                result, calls, delays = self.run_build([
                    {'stderr': error, 'exit_code': 69}, {'stdout': 'Dependencies resolved'},
                ], args=('pub', 'get', '--enforce-lockfile'))
                self.assertEqual(result.returncode, 0)
                self.assertEqual(len(calls), 2)
                self.assertEqual(delays, ['10'])
                self.assertIn(error, result.stdout)
                self.assertIn('Dependencies resolved', result.stdout)

    def test_locked_pub_get_git_transport_failure_keeps_three_attempt_limit(self):
        self.command = self.command.rename(self.bin_dir / 'flutter')
        for error in GIT_TRANSPORT_ERRORS:
            with self.subTest(error=error):
                result, calls, delays = self.run_build([
                    {'stderr': error, 'exit_code': 69},
                ], args=('pub', 'get', '--enforce-lockfile'))
                self.assertEqual(result.returncode, 69)
                self.assertEqual(len(calls), 3)
                self.assertEqual(delays, ['10', '20'])
                self.assertIn('failed after 3 attempts (exit 69)', result.stderr)

    def test_git_transport_output_does_not_retry_other_commands_or_pub_errors(self):
        self.command = self.command.rename(self.bin_dir / 'flutter')
        for error in GIT_TRANSPORT_ERRORS:
            for args, status in ((('build', 'apk'), 69), (('pub', 'upgrade'), 69),
                                 (('pub', 'get'), 65), (('pub', 'get'), 130)):
                with self.subTest(error=error, args=args, status=status):
                    result, calls, delays = self.run_build([
                        {'stderr': error, 'exit_code': status}, {},
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
            GIT_OPENSSL_TLS_ERROR.replace('curl 56', 'curl 35'),
            GIT_OPENSSL_TLS_ERROR.replace(
                'error:0A000126:SSL routines::unexpected eof while reading',
                'error:0A000086:SSL routines::certificate verify failed'),
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
        for tls_error in GIT_TRANSPORT_ERRORS:
            for error in (
                'fatal: early EOF\nfatal: fetch-pack: invalid index-pack output',
                'fatal: Remote branch missing-revision not found in upstream origin',
            ):
                with self.subTest(tls_error=tls_error, error=error):
                    result, calls, delays = self.run_build([
                        {'stderr': tls_error, 'exit_code': 69},
                        {'stderr': error, 'exit_code': 69}, {},
                    ], args=('pub', 'get', '--enforce-lockfile'))
                    self.assertEqual(result.returncode, 69)
                    self.assertEqual(len(calls), 2)
                    self.assertEqual(delays, ['10'])

    def test_incomplete_or_deterministic_git_errors_do_not_retry_pub_69(self):
        self.command = self.command.rename(self.bin_dir / 'flutter')
        errors = [
            GIT_EOF_ERROR.splitlines()[1],
            'fatal: early EOF',
            'fatal: fetch-pack: invalid index-pack output',
            '\n'.join(GIT_EOF_ERROR.splitlines()[1:]),
            GIT_EOF_ERROR.replace('fatal: early EOF', ''),
            GIT_EOF_ERROR.replace('fatal: fetch-pack: invalid index-pack output', ''),
            GIT_EOF_ERROR.replace('curl 56', 'curl 60'),
            GIT_EOF_ERROR.replace('unexpected eof while reading', 'certificate verify failed'),
            'checksum mismatch',
            'fatal: Authentication failed for https://example.invalid/dependency.git',
        ]
        errors.extend(GIT_CURL18_EOF_ERROR.replace(line, '')
                      for line in GIT_CURL18_EOF_ERROR.splitlines())
        errors.extend([
            GIT_CURL18_EOF_ERROR.replace('https://', 'http://'),
            GIT_CURL18_EOF_ERROR.replace('curl 18', 'curl 60'),
            GIT_CURL18_EOF_ERROR.replace(
                'transfer closed with outstanding read data remaining',
                'SSL certificate verification failed'),
        ])
        for error in errors:
            with self.subTest(error=error):
                result, calls, delays = self.run_build([
                    {'stderr': error, 'exit_code': 69}, {},
                ], args=('pub', 'get', '--enforce-lockfile'))
                self.assertEqual(result.returncode, 69)
                self.assertEqual(len(calls), 1)
                self.assertEqual(delays, [])

    def test_previous_git_transport_failure_does_not_retry_lockfile_failure(self):
        self.command = self.command.rename(self.bin_dir / 'flutter')
        for error in GIT_TRANSPORT_ERRORS:
            with self.subTest(error=error):
                result, calls, delays = self.run_build([
                    {'stderr': error, 'exit_code': 69},
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
