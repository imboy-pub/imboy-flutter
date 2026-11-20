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
MAVEN_RATE_LIMIT = (
    "Could not GET 'https://repo.maven.apache.org/maven2/org/jetbrains/kotlin/"
    "kotlin-gradle-plugins-bom/2.2.20/kotlin-gradle-plugins-bom-2.2.20.pom'. "
    'Received status code 429 from server: Too Many Requests'
)
GRADLE_MAVEN_ERROR = '\n'.join([
    'FAILURE: Build failed with an exception.',
    '',
    '* What went wrong:',
    "Error resolving plugin [id: 'dev.flutter.flutter-plugin-loader', version: '1.0.0']",
    "> A problem occurred configuring project ':gradle'.",
    "   > Could not resolve all artifacts for configuration 'classpath'.",
    '      > Could not resolve org.jetbrains.kotlin:kotlin-stdlib:2.3.20.',
    '         > Repository Gradle Central Plugin Repository is disabled due to earlier error below:',
    '            > Could not resolve org.jetbrains.kotlin:kotlin-gradle-plugins-bom:2.2.20.',
    "               > Could not get resource 'https://plugins.gradle.org/m2/org/jetbrains/kotlin/"
    "kotlin-gradle-plugins-bom/2.2.20/kotlin-gradle-plugins-bom-2.2.20.pom'.",
    '                  > ' + MAVEN_RATE_LIMIT,
    '> There are 5 more failures with identical causes.',
    '',
    '* Try:',
    '> Run with --stacktrace option to get the stack trace.',
    '',
    'BUILD FAILED in 26s',
])
FLUTTER_RETRY = 'Retrying Gradle Build: #1, wait time: 100ms'
# The observed Flutter invocation reports two failed Gradle attempts before exit 1.
FLUTTER_MAVEN_ERROR = '\n'.join([
    GRADLE_MAVEN_ERROR, FLUTTER_RETRY, GRADLE_MAVEN_ERROR,
    'Gradle task assembleStandardRelease failed with exit code 1',
])
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
POD_SOURCE = 'https://mirrors.tuna.tsinghua.edu.cn/git/CocoaPods/Specs.git'
# Keep the complete observed CocoaPods stderr, including its project message.
# Retry eligibility comes from the separate source/clone/transport error chain.
POD_CLONE_ERROR = f"""Running pod install...                                            228.3s
CocoaPods' output:
↳
    Cloning spec repo `tsinghua-git-cocoapods` from `{POD_SOURCE}`
      $ /usr/local/bin/git clone {POD_SOURCE} -- tsinghua-git-cocoapods
    [!] Unable to add a source with url `{POD_SOURCE}` named `tsinghua-git-cocoapods`.
    (/usr/local/bin/git clone {POD_SOURCE} -- tsinghua-git-cocoapods

    Cloning into 'tsinghua-git-cocoapods'...
    error: RPC failed; curl 56 Recv failure: Connection reset by peer
    error: 2422 bytes of body are still expected
    fetch-pack: unexpected disconnect while reading sideband packet
    fatal: early EOF
    fatal: fetch-pack: invalid index-pack output
    )
    You can try adding it manually in `/Users/runner/.cocoapods/repos` or via `pod repo add`.
    /usr/local/lib/ruby/gems/3.4.0/gems/cocoapods-1.17.0/lib/cocoapods/sources_manager.rb:55:in 'Pod::Source::Manager#create_source_with_url'

Error output from CocoaPods:
↳
    Must provide a project directory and project name.
      Cloning into 'tsinghua-git-cocoapods'...
      error: RPC failed; curl 56 Recv failure: Connection reset by peer
      error: 2422 bytes of body are still expected
      fetch-pack: unexpected disconnect while reading sideband packet
      fatal: early EOF
      fatal: fetch-pack: invalid index-pack output

Error running pod install
"""

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

    def test_android_maven_rate_limit_recovers_with_unchanged_arguments(self):
        self.command = self.command.rename(self.bin_dir / 'flutter')
        for kind in ('apk', 'appbundle'):
            with self.subTest(kind=kind):
                result, calls, delays = self.run_build([
                    {'stderr': FLUTTER_MAVEN_ERROR, 'exit_code': 1},
                    {'stdout': 'build complete'},
                ], args=('build', kind, '--release', '--flavor', 'standard',
                         '--dart-define=SENTRY_DSN=private fixture'))
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(len(calls), 2)
                self.assertEqual(delays, ['10'])
                self.assertIn('build complete', result.stdout)

    def test_android_maven_rate_limit_preserves_exhausted_failure(self):
        self.command = self.command.rename(self.bin_dir / 'flutter')
        result, calls, delays = self.run_build([
            {'stderr': FLUTTER_MAVEN_ERROR, 'exit_code': 1},
        ], args=('build', 'apk'))
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(calls), 3)
        self.assertEqual(delays, ['10', '20'])
        self.assertIn('failed after 3 attempts (exit 1)', result.stderr)

    def test_maven_rate_limit_requires_android_flutter_build_exit_one(self):
        result, calls, delays = self.run_build([
            {'stderr': FLUTTER_MAVEN_ERROR, 'exit_code': 1}, {},
        ], args=('build', 'apk'))
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(calls), 1)
        self.assertEqual(delays, [])
        self.command = self.command.rename(self.bin_dir / 'flutter')
        for args, status in (
                (('build', 'ios'), 1), (('build', 'web'), 1),
                (('pub', 'get'), 1), (('test',), 1),
                (('build', 'apk'), 65), (('build', 'apk'), 69),
                (('build', 'apk'), 130), (('build', 'apk'), 137)):
            with self.subTest(args=args, status=status):
                result, calls, delays = self.run_build([
                    {'stderr': FLUTTER_MAVEN_ERROR, 'exit_code': status}, {},
                ], args=args)
                self.assertEqual(result.returncode, status)
                self.assertEqual(len(calls), 1)
                self.assertEqual(delays, [])

    def test_android_maven_rate_limit_requires_exact_official_get_diagnostic(self):
        self.command = self.command.rename(self.bin_dir / 'flutter')
        errors = [
            FLUTTER_MAVEN_ERROR.replace('repo.maven.apache.org', 'example.invalid'),
            FLUTTER_MAVEN_ERROR.replace('repo.maven.apache.org', 'repo.maven.apache.org.example.invalid'),
            FLUTTER_MAVEN_ERROR.replace('https://repo.maven.apache.org', 'http://repo.maven.apache.org'),
            FLUTTER_MAVEN_ERROR.replace('/maven2/', '/unrelated/'),
            FLUTTER_MAVEN_ERROR.replace('Could not GET', 'Could not HEAD'),
            MAVEN_RATE_LIMIT,
        ]
        errors.extend(FLUTTER_MAVEN_ERROR.replace('429', str(code))
                      for code in (401, 403, 404, 408, 500, 502, 503))
        for permanent in ('error: compilation failed', 'Code signing failed',
                          'checksum mismatch', MAVEN_RATE_LIMIT.replace('429', '401'),
                          'Could not find com.example:missing:1.0.',
                          'Could not resolve dependencies: incompatible package versions'):
            errors.append(FLUTTER_MAVEN_ERROR.replace(
                '\n* Try:', '\n> ' + permanent + '\n* Try:'))
            errors.append(FLUTTER_MAVEN_ERROR.replace(
                '\n* What went wrong:', '\n* What went wrong:\n> ' + permanent))
        for error in errors:
            with self.subTest(error=error):
                result, calls, delays = self.run_build([
                    {'stderr': error, 'exit_code': 1}, {},
                ], args=('build', 'apk'))
                self.assertEqual(result.returncode, 1)
                self.assertEqual(len(calls), 1)
                self.assertEqual(delays, [])

    def test_flutter_recovered_maven_error_does_not_retry_terminal_failure(self):
        self.command = self.command.rename(self.bin_dir / 'flutter')
        for error in (
                "Execution failed for task ':app:compileFlutterBuildStandardRelease'.\n"
                '> error: compilation failed',
                'Code signing failed', 'checksum mismatch',
                'Could not resolve dependencies: incompatible package versions',
                MAVEN_RATE_LIMIT.replace('429', '401'),
                MAVEN_RATE_LIMIT.replace('429', '404')):
            for complete_gradle_failure in (True, False):
                with self.subTest(error=error, complete=complete_gradle_failure):
                    terminal = ('FAILURE: Build failed with an exception.\n\n'
                                '* What went wrong:\n' + error + '\n\n* Try:\n'
                                if complete_gradle_failure else error)
                    output = '\n'.join([GRADLE_MAVEN_ERROR, FLUTTER_RETRY, terminal])
                    result, calls, delays = self.run_build([
                        {'stderr': output, 'exit_code': 1}, {},
                    ], args=('build', 'apk'))
                    self.assertEqual(result.returncode, 1)
                    self.assertEqual(len(calls), 1)
                    self.assertEqual(delays, [])

    def test_android_maven_rate_limit_rejects_ambiguous_gradle_failure_reports(self):
        self.command = self.command.rename(self.bin_dir / 'flutter')
        for permanent in ('error: compilation failed', 'Code signing failed', 'checksum mismatch'):
            for causes in ((permanent, MAVEN_RATE_LIMIT), (MAVEN_RATE_LIMIT, permanent)):
                for heading in ('FAILURE: Build completed with 2 failures.',
                                'FAILURE: Build failed with an exception.'):
                    with self.subTest(causes=causes, heading=heading):
                        # A new report must invalidate an earlier rate limit even
                        # if no Flutter retry banner separates the reports.
                        output = '\n'.join([
                            GRADLE_MAVEN_ERROR, heading,
                            '* What went wrong:', '> ' + causes[0], '* Try:',
                            '* What went wrong:', '> ' + causes[1], '* Try:',
                        ])
                        result, calls, delays = self.run_build([
                            {'stderr': output, 'exit_code': 1}, {},
                        ], args=('build', 'apk'))
                        self.assertEqual(result.returncode, 1)
                        self.assertEqual(len(calls), 1)
                        self.assertEqual(delays, [])
            with self.subTest(trailing_failure=permanent):
                result, calls, delays = self.run_build([
                    {'stderr': FLUTTER_MAVEN_ERROR + '\n' + permanent, 'exit_code': 1}, {},
                ], args=('build', 'apk'))
                self.assertEqual(result.returncode, 1)
                self.assertEqual(len(calls), 1)
                self.assertEqual(delays, [])

    def test_previous_maven_rate_limit_does_not_retry_later_permanent_failure(self):
        self.command = self.command.rename(self.bin_dir / 'flutter')
        for error in ('error: compilation failed', 'Code signing failed',
                      'checksum mismatch', 'Unable to satisfy pubspec.yaml using pubspec.lock.'):
            with self.subTest(error=error):
                result, calls, delays = self.run_build([
                    {'stderr': FLUTTER_MAVEN_ERROR, 'exit_code': 1},
                    {'stderr': error, 'exit_code': 65}, {},
                ], args=('build', 'apk'))
                self.assertEqual(result.returncode, 65)
                self.assertEqual(len(calls), 2)
                self.assertEqual(delays, ['10'])

    def test_ios_config_only_specs_clone_transport_recovers(self):
        self.command = self.command.rename(self.bin_dir / 'flutter')
        for args in (('build', 'ios', '--config-only', '--release', '--no-codesign',
                      '--dart-define=SENTRY_DSN=private fixture'),
                     ('build', 'ios', '--release', '--no-codesign', '--config-only')):
            with self.subTest(args=args):
                result, calls, delays = self.run_build([
                    {'stderr': POD_CLONE_ERROR, 'exit_code': 1}, {'stdout': 'configuration ready'},
                ], args=args)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(len(calls), 2)
                self.assertEqual(delays, ['10'])

    def test_ios_specs_clone_budget_and_permanent_followup(self):
        self.command = self.command.rename(self.bin_dir / 'flutter')
        first = {'stderr': POD_CLONE_ERROR, 'exit_code': 1}
        for steps, expected, attempts, waits in (
                ([first], 1, 3, ['10', '20']),
                ([first, {'stderr': 'error: compilation failed', 'exit_code': 1}, {}], 1, 2, ['10']),
                ([first, {'stderr': 'Code signing failed', 'exit_code': 65}, {}], 65, 2, ['10']),
                ([first, {'stderr': 'Error running pod install', 'exit_code': 1}, {}], 1, 2, ['10'])):
            with self.subTest(expected=expected, steps=steps):
                result, calls, delays = self.run_build(steps, args=('build', 'ios', '--config-only'))
                self.assertEqual(result.returncode, expected)
                self.assertEqual(len(calls), attempts)
                self.assertEqual(delays, waits)

    def test_ios_specs_clone_requires_exact_config_only_command(self):
        result, calls, delays = self.run_build([
            {'stderr': POD_CLONE_ERROR, 'exit_code': 1}, {},
        ], args=('build', 'ios', '--config-only'))
        self.assertEqual((result.returncode, len(calls), delays), (1, 1, []))
        self.command = self.command.rename(self.bin_dir / 'flutter')
        commands = [
            ('build', 'ios'), ('build', 'apk', '--config-only'), ('pub', 'get', '--config-only'),
            ('build', 'ios', '--config-only=true'), ('build', 'ios', '--config-only=false'),
            ('build', 'ios', '--dart-define=MODE=--config-only'),
            ('build', 'ios', '--dart-define=MODE=x\n--config-only'),
            ('build', 'ios', '--', '--config-only'),
        ]
        for flag in ('--no-config-only', '--config-only=false', '--config-only=true'):
            commands.extend((('build', 'ios', '--config-only', flag),
                             ('build', 'ios', flag, '--config-only')))
        for args, status in ([(args, 1) for args in commands] +
                             [(('build', 'ios', '--config-only'), code) for code in (65, 69, 130, 137)]):
            with self.subTest(args=args, status=status):
                result, calls, delays = self.run_build([
                    {'stderr': POD_CLONE_ERROR, 'exit_code': status}, {},
                ], args=args)
                self.assertEqual((result.returncode, len(calls), delays), (status, 1, []))

    def test_ios_specs_clone_requires_complete_terminal_transport(self):
        self.command = self.command.rename(self.bin_dir / 'flutter')
        required = (
            f'[!] Unable to add a source with url `{POD_SOURCE}` named `tsinghua-git-cocoapods`.',
            f'(/usr/local/bin/git clone {POD_SOURCE} -- tsinghua-git-cocoapods',
            'Error output from CocoaPods:', "Cloning into 'tsinghua-git-cocoapods'...",
            'error: RPC failed; curl 56 Recv failure: Connection reset by peer',
            'error: 2422 bytes of body are still expected',
            'fetch-pack: unexpected disconnect while reading sideband packet',
            'fatal: early EOF', 'fatal: fetch-pack: invalid index-pack output',
            'Error running pod install',
        )
        errors = [''.join(POD_CLONE_ERROR.rsplit(marker, 1)) for marker in required]
        errors.extend(POD_CLONE_ERROR.replace(POD_SOURCE, url) for url in (
            'https://example.invalid/CocoaPods/Specs.git', POD_SOURCE.replace('https:', 'http:'),
            POD_SOURCE.replace('.edu.cn/', '.edu.cn.example.invalid/'), POD_SOURCE + '.extra'))
        errors.append(POD_CLONE_ERROR.replace('curl 56 Recv failure: Connection reset by peer',
                                             'curl 60 SSL certificate problem: certificate has expired'))
        for permanent in ('error: compilation failed', 'Code signing failed', 'checksum mismatch',
                          'fatal: Authentication failed', 'fatal: HTTP 404 Not Found',
                          '[!] CocoaPods could not find compatible versions for pod Foo'):
            errors.extend((permanent + '\n' + POD_CLONE_ERROR,
                           POD_CLONE_ERROR.replace('Error output from CocoaPods:',
                                                  permanent + '\nError output from CocoaPods:'),
                           POD_CLONE_ERROR.replace('Error running pod install',
                                                  permanent + '\nError running pod install'),
                           POD_CLONE_ERROR + permanent))
        for boundary in ('Pod installation complete!', 'Running pod install...', "CocoaPods' output:"):
            errors.append(POD_CLONE_ERROR.replace('Error output from CocoaPods:',
                                                 boundary + '\nError output from CocoaPods:'))
            errors.append(POD_CLONE_ERROR + boundary + '\nError running pod install')
        for error in errors:
            with self.subTest(error=error):
                result, calls, delays = self.run_build([
                    {'stderr': error, 'exit_code': 1}, {},
                ], args=('build', 'ios', '--config-only'))
                self.assertEqual((result.returncode, len(calls), delays), (1, 1, []))

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
