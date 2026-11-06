"""Entrypoint and evidence regressions; no SDK, credentials or network."""
from __future__ import annotations

import importlib.util
import contextlib
import copy
import json
import os
import re
import subprocess
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))
from auto_test_lib import execution_cli, execution_gates


class EntrypointTest(unittest.TestCase):
    def run_pre_push(self, arguments=(), environment=None):
        """Exercise the hook in isolation; any config load or direct runner fails."""
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            scripts = project / 'scripts'
            scripts.mkdir()
            script = scripts / 'pre_push_gate.sh'
            shutil.copyfile(ROOT / 'scripts/pre_push_gate.sh', script)
            (scripts / 'test.env').write_text('echo UNEXPECTED_TEST_ENV_LOAD >&2\nexit 97\n')
            binaries = project / 'bin'
            binaries.mkdir()
            commands = {
                'python3': '#!/bin/sh\n'
                           '[ -z "${GIT_DIR+x}${GIT_WORK_TREE+x}${GIT_INDEX_FILE+x}" ] || exit 96\n'
                           'printf "%s\\0" "$@"\nexit "${PRE_PUSH_FIXTURE_EXIT:-0}"\n',
                'uname': '#!/bin/sh\nprintf "%s\\n" "${PRE_PUSH_FIXTURE_HOST:-Linux}"\n',
            }
            for name in ('curl', 'dart', 'flutter'):
                commands[name] = '#!/bin/sh\necho UNEXPECTED_DIRECT_RUNNER >&2\nexit 98\n'
            for name, content in commands.items():
                binary = binaries / name
                binary.write_text(content)
                binary.chmod(0o755)
            env = {**os.environ, 'PATH': str(binaries) + os.pathsep + os.environ['PATH'],
                   'IMBOY_SKIP_PRE_PUSH': '0', 'IMBOY_PRE_PUSH_BACKEND': '0',
                   'GIT_DIR': 'injected', 'GIT_WORK_TREE': 'injected', 'GIT_INDEX_FILE': 'injected',
                   'TEST_PHONE': 'synthetic-phone-must-not-print',
                   'TEST_PASSWORD': 'synthetic-password-must-not-print', **(environment or {})}
            result = subprocess.run(['bash', str(script), *arguments], cwd=project, env=env,
                                    text=True, capture_output=True, check=False)
            self.assertNotIn('UNEXPECTED_', result.stdout + result.stderr)
            self.assertNotIn('must-not-print', result.stdout + result.stderr)
            return result

    def test_pre_push_defaults_to_static_ownership_and_keeps_backend_out_of_scope(self):
        for code in (0, 1, 2):
            with self.subTest(code=code):
                result = self.run_pre_push(environment={'PRE_PUSH_FIXTURE_EXIT': str(code)})
                self.assertEqual(result.returncode, code, result.stderr)
                self.assertEqual(result.stdout.split('\0')[:-1], ['scripts/auto_test.py', 'execution-check'])
                self.assertIn('NOT_SELECTED reason_code=OUT_OF_SCOPE', result.stderr)
                self.assertNotIn('PASS', result.stderr)

    def test_pre_push_backend_opt_in_uses_shared_profile_and_local_platform(self):
        for host, platform in (('Linux', 'linux'), ('Darwin', 'macos')):
            for option, environment in ((['--backend'], {}), ([], {'IMBOY_PRE_PUSH_BACKEND': '1'})):
                with self.subTest(host=host, option=option):
                    arguments = [*option, '--artifact-dir', 'evidence directory']
                    result = self.run_pre_push(arguments, {**environment, 'PRE_PUSH_FIXTURE_HOST': host})
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout.split('\0')[:-1], [
                        'scripts/auto_test.py', 'execution-run', '--profile', 'backend',
                        '--platform', platform, '--artifact-dir', 'evidence directory'])

    def test_pre_push_backend_preserves_failed_blocked_and_crashed_runner_exits(self):
        for code in (1, 2, 137):
            with self.subTest(code=code):
                result = self.run_pre_push(['--backend'], {'PRE_PUSH_FIXTURE_EXIT': str(code)})
                self.assertEqual(result.returncode, code, result.stderr)
                self.assertIn('execution-run\0', result.stdout)
                self.assertNotIn('PASS', result.stderr)

    def test_pre_push_dry_run_uses_the_same_backend_plan_without_execution(self):
        result = self.run_pre_push(['--dry-run', '--output', 'plan output.json'])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.split('\0')[:-1], [
            'scripts/auto_test.py', 'execution-plan', '--profile', 'backend',
            '--platform', 'linux', '--output', 'plan output.json'])

    def test_pre_push_opt_out_reports_no_business_success_or_execution(self):
        result = self.run_pre_push(['--backend'], {'IMBOY_SKIP_PRE_PUSH': '1'})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, '')
        self.assertIn('OUT_OF_SCOPE', result.stderr)
        self.assertIn('checks were not run', result.stderr)
        self.assertNotIn('PASS', result.stderr)

    def test_pre_push_unsupported_host_and_invalid_options_cannot_turn_green(self):
        result = self.run_pre_push(['--backend'], {'PRE_PUSH_FIXTURE_HOST': 'FreeBSD'})
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertEqual(result.stdout, '')
        self.assertIn('ENV_MISSING', result.stderr)
        for arguments, environment in ((['--profile', 'pr'], {}), (['--output'], {}),
                                       ([], {'IMBOY_PRE_PUSH_BACKEND': 'maybe'})):
            with self.subTest(arguments=arguments, environment=environment):
                result = self.run_pre_push(arguments, environment)
                self.assertEqual(result.returncode, 64, result.stderr)
                self.assertEqual(result.stdout, '')

    def test_e2ee_legacy_wrappers_keep_paired_selection_arguments_and_exit_codes(self):
        wrappers = {
            'run_cross_platform_e2ee_interop.sh': 'integration_test/e2ee_cross_platform_interop_test.dart',
            'run_cross_platform_e2ee_group_interop.sh': 'integration_test/e2ee_cross_platform_group_interop_test.dart',
        }
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            scripts = project / 'scripts'
            scripts.mkdir()
            for name in (*wrappers, 'run_test_suite.sh'):
                shutil.copyfile(ROOT / 'scripts' / name, scripts / name)
            binaries = project / 'bin'
            binaries.mkdir()
            for name in ('python3', 'flutter', 'patrol', 'adb'):
                binary = binaries / name
                binary.write_text('#!/bin/sh\nprintf "%s\\0" "$@"\nexit "${PAIR_FIXTURE_EXIT:-0}"\n'
                                  if name == 'python3' else
                                  '#!/bin/sh\necho UNEXPECTED_DIRECT_RUNNER >&2\nexit 98\n')
                binary.chmod(0o755)
            for name, target in wrappers.items():
                for dry_run, command in ((False, 'execution-run'), (True, 'execution-plan')):
                    arguments = ['--dry-run', '--output', 'plan output.json'] if dry_run else [
                        '--artifact-dir', 'evidence output']
                    arguments += ['--product-profile', 'full-selected']
                    for code in (0, 1, 2, 137):
                        with self.subTest(name=name, dry_run=dry_run, code=code):
                            result = subprocess.run(
                                ['bash', str(scripts / name), *arguments], cwd=project,
                                env={**os.environ, 'PATH': str(binaries) + os.pathsep + os.environ['PATH'],
                                     'PAIR_FIXTURE_EXIT': str(code)},
                                text=True, capture_output=True, check=False)
                            self.assertEqual(result.returncode, code, result.stderr)
                            self.assertNotIn('UNEXPECTED_', result.stderr)
                            forwarded = [value for value in arguments if value != '--dry-run']
                            self.assertEqual(result.stdout.split('\0')[:-1], [
                                'scripts/auto_test.py', command, '--profile', 'device-pair',
                                '--target', target, *forwarded])

    def test_e2ee_legacy_wrappers_do_not_pin_devices_or_run_flutter_independently(self):
        for name in ('run_cross_platform_e2ee_interop.sh', 'run_cross_platform_e2ee_group_interop.sh'):
            with self.subTest(name=name):
                script = (ROOT / 'scripts' / name).read_text(encoding='utf-8')
                self.assertNotIn('XWE6R19916004085', script)
                self.assertNotRegex(script, r'\b(?:flutter|patrol)\s+test\b|\badb\s+-s\b')

    def run_web_shell(self, arguments=(), environment=None, *, assets=True, inside_artifacts=False):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            project = base / 'project'
            scripts = project / 'scripts'
            scripts.mkdir(parents=True)
            shutil.copyfile(ROOT / 'scripts/verify_web_shell.sh', scripts / 'verify_web_shell.sh')
            if assets:
                asset_dir = project / 'web/pkg'
                asset_dir.mkdir(parents=True)
                for name in ('vodozemac_bindings_dart.js', 'vodozemac_bindings_dart_bg.wasm'):
                    (asset_dir / name).write_text('synthetic asset')
            evidence = (project if inside_artifacts else base) / 'evidence output'
            calls_file = base / 'calls.jsonl'
            binaries = base / 'bin'
            binaries.mkdir()
            stub = '#!' + sys.executable + '\n' + '''import json, os, sys
from pathlib import Path
name, args = Path(sys.argv[0]).name, sys.argv[1:]
with open(os.environ['WEB_FIXTURE_CALLS'], 'a') as stream:
    stream.write(json.dumps([name, *args]) + '\\n')
if name == 'python3' and args[0] == '-c':
    os.execv(sys.executable, [sys.executable, *args])
if name == 'uname':
    print(os.environ.get('WEB_FIXTURE_HOST', 'Linux'))
    raise SystemExit(0)
if name == 'python3' and args[0].endswith('check_sdk_compatibility.py'):
    code = int(os.environ.get('WEB_FIXTURE_SDK_EXIT', '0'))
elif name == 'python3' and args[:2] == ['scripts/auto_test.py', 'execution-plan']:
    code = 0
elif name == 'python3' and args[:2] == ['scripts/auto_test.py', 'execution-run']:
    code = 2 if '--upstream' in args else int(os.environ.get('WEB_FIXTURE_TEST_EXIT', '0'))
elif name == 'flutter' and args[0] in ('analyze', 'build'):
    code = int(os.environ.get('WEB_FIXTURE_' + args[0].upper() + '_EXIT', '0'))
else:
    raise SystemExit('UNEXPECTED_DIRECT_RUNNER: ' + repr([name, *args]))
print('synthetic command fixture exit', code)
raise SystemExit(code)
'''
            for name in ('python3', 'flutter', 'uname'):
                binary = binaries / name
                binary.write_text(stub)
                binary.chmod(0o755)
            result = subprocess.run(
                ['bash', str(scripts / 'verify_web_shell.sh'), '--artifact-dir', str(evidence), *arguments],
                cwd=project, env={**os.environ, 'PATH': str(binaries) + os.pathsep + os.environ['PATH'],
                                  'WEB_FIXTURE_CALLS': str(calls_file), **(environment or {})},
                text=True, capture_output=True, check=False)
            self.assertNotIn('UNEXPECTED_', result.stdout + result.stderr)
            calls = [json.loads(line) for line in calls_file.read_text().splitlines()] if calls_file.exists() else []
            logs = sorted(path.name for path in evidence.glob('*.log'))
            return result, calls, logs

    def test_web_shell_dry_run_precedes_sdk_assets_analysis_and_build(self):
        for host, platform in (('Linux', 'linux'), ('Darwin', 'macos')):
            with self.subTest(host=host):
                result, calls, logs = self.run_web_shell(
                    ['--dry-run', '--quick', '--no-server', '--output', 'plan output.json'],
                    {'WEB_FIXTURE_HOST': host, 'WEB_FIXTURE_SDK_EXIT': '97'}, assets=False)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(calls, [['uname', '-s'], [
                    'python3', 'scripts/auto_test.py', 'execution-plan', '--profile', 'web-shell',
                    '--platform', platform, '--platform', 'web', '--output', 'plan output.json']])
                self.assertEqual(logs, [])

    def test_web_shell_quick_keeps_host_and_browser_obligations_and_shared_verdict(self):
        for host, platform in (('Linux', 'linux'), ('Darwin', 'macos')):
            for code in (0, 1, 2, 137):
                with self.subTest(host=host, code=code):
                    result, calls, logs = self.run_web_shell(
                        ['--quick', '--no-server'], {'WEB_FIXTURE_HOST': host, 'WEB_FIXTURE_TEST_EXIT': str(code)})
                    self.assertEqual(result.returncode, code, result.stderr)
                    run = next(call for call in calls if 'execution-run' in call)
                    self.assertEqual(run[:-1], ['python3', 'scripts/auto_test.py', 'execution-run',
                                               '--profile', 'web-shell', '--platform', platform,
                                               '--platform', 'web', '--artifact-dir'])
                    self.assertTrue(run[-1].endswith('/evidence output/tests'), run)
                    self.assertEqual([call[1] for call in calls if call[0] == 'flutter'], ['analyze'])
                    self.assertEqual(logs, ['analyze.log', 'execution.log', 'sdk.log'])
                    self.assertNotIn('all checks passed', result.stdout)

    def test_web_shell_prerequisite_failures_still_reconcile_selected_instances(self):
        for stage, environment, assets in (
            ('sdk', {'WEB_FIXTURE_SDK_EXIT': '1'}, True),
            ('assets', {}, False),
            ('analyze', {'WEB_FIXTURE_ANALYZE_EXIT': '1'}, True),
            ('build', {'WEB_FIXTURE_BUILD_EXIT': '1'}, True),
        ):
            with self.subTest(stage=stage):
                result, calls, logs = self.run_web_shell(['--no-server'], environment, assets=assets)
                self.assertEqual(result.returncode, 2, result.stderr)
                run = next(call for call in calls if 'execution-run' in call)
                self.assertIn('--upstream', run)
                self.assertIn('web-shell-' + stage + ('=blocked' if stage == 'assets' else '=failure'), run)
                self.assertIn(stage + '.log', logs)
                self.assertIn('execution.log', logs)
                self.assertEqual(calls[-1], run)

    def test_web_shell_full_keeps_build_and_no_server_without_a_second_test_runner(self):
        result, calls, logs = self.run_web_shell(['--no-server'])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([call[1] for call in calls if call[0] == 'flutter'], ['analyze', 'build'])
        self.assertEqual(sum('execution-run' in call for call in calls), 1)
        self.assertIn('execution-run', calls[-1])
        self.assertEqual(logs, ['analyze.log', 'build.log', 'execution.log', 'sdk.log'])

    def test_web_shell_rejects_artifacts_inside_repository_before_execution(self):
        result, calls, logs = self.run_web_shell(['--quick', '--no-server'], inside_artifacts=True)
        self.assertEqual(result.returncode, 64, result.stderr)
        self.assertIn('outside the repository', result.stderr)
        self.assertFalse(any('execution-run' in call for call in calls))
        self.assertEqual(logs, [])

    def ci_job(self, name):
        workflow = (ROOT / '.github/workflows/ci.yml').read_text(encoding='utf-8')
        jobs = workflow.split('\njobs:\n', 1)[1]
        match = re.search(r'^  ' + re.escape(name) + r':\n(.*?)(?=^  [\w-]+:\n|\Z)',
                          jobs, re.MULTILINE | re.DOTALL)
        self.assertIsNotNone(match, f'CI job is missing: {name}')
        return match.group(1)

    def test_empty_forwarded_arguments_keep_default_and_explicit_profiles(self):
        with tempfile.TemporaryDirectory() as directory:
            binary = Path(directory) / 'python3'
            binary.write_text('#!/bin/sh\nprintf "%s\\0" "$@"\n')
            binary.chmod(0o755)
            env = {**os.environ, 'PATH': directory + os.pathsep + os.environ['PATH']}
            for options, command, profile in (
                ([], 'execution-run', 'full'),
                (['--dry-run'], 'execution-plan', 'full'),
                (['--mode', 'quick'], 'execution-run', 'pr'),
                (['--profile', 'tooling', '--dry-run'], 'execution-plan', 'tooling'),
            ):
                with self.subTest(options=options):
                    result = subprocess.run(
                        ['bash', str(ROOT / 'scripts/run_test_suite.sh'), *options],
                        cwd=ROOT, env=env, text=True, capture_output=True, check=False)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout.split('\0')[:-1], [
                        'scripts/auto_test.py', command, '--profile', profile])

    def test_forwarded_arguments_preserve_spaces_globs_and_empty_values(self):
        with tempfile.TemporaryDirectory() as directory:
            binary = Path(directory) / 'python3'
            binary.write_text('#!/bin/sh\nprintf "%s\\0" "$@"\n')
            binary.chmod(0o755)
            env = {**os.environ, 'PATH': directory + os.pathsep + os.environ['PATH']}
            arguments = ['--target', 'test/widget tests/a_test.dart',
                         '--target', 'test/unit_test/*_test.dart',
                         '--artifact-dir', 'report output', '--variant', '']
            for options, command in (([], 'execution-run'), (['--dry-run'], 'execution-plan')):
                with self.subTest(command=command):
                    result = subprocess.run(
                        ['bash', str(ROOT / 'scripts/run_test_suite.sh'), *options, *arguments],
                        cwd=ROOT, env=env, text=True, capture_output=True, check=False)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout.split('\0')[:-1], [
                        'scripts/auto_test.py', command, '--profile', 'full', *arguments])

    def test_quick_and_full_delegation_preserve_the_selection_arguments(self):
        with tempfile.TemporaryDirectory() as directory:
            binary = Path(directory) / 'python3'
            binary.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
            binary.chmod(0o755)
            env = {**os.environ, 'PATH': directory + os.pathsep + os.environ['PATH']}
            for mode, profile in [('quick', 'pr'), ('full', 'full')]:
                result = subprocess.run(
                    ['bash', str(ROOT / 'scripts/run_test_suite.sh'), '--mode', mode,
                     '--dry-run', '--platform', 'macos', '--product-profile', 'phase1_delivery'],
                    cwd=ROOT, env=env, text=True, capture_output=True, check=False)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.splitlines(), [
                    'scripts/auto_test.py', 'execution-plan', '--profile', profile,
                    '--platform', 'macos', '--product-profile', 'phase1_delivery'])

    def test_legacy_integration_entry_retains_full_scope(self):
        with tempfile.TemporaryDirectory() as directory:
            binary = Path(directory) / 'python3'
            binary.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
            binary.chmod(0o755)
            result = subprocess.run(
                ['bash', str(ROOT / 'scripts/run_all_integration_tests.sh'), '--dry-run'],
                cwd=ROOT, env={**os.environ, 'PATH': directory + os.pathsep + os.environ['PATH']},
                text=True, capture_output=True, check=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('execution-plan\n--profile\nfull', result.stdout)

    def test_legacy_page_run_delegates_to_shared_plan_without_device_io(self):
        spec = importlib.util.spec_from_file_location('execution_legacy_cli', ROOT / 'scripts/auto_test.py')
        cli = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cli)
        selected = [(Path('spec.json'), {'runner': {'target': 'integration_test/app_test.dart'},
                                         'safe_to_execute': True})]
        for execute, device, devices, expected in (
            (False, '', [], 0),
            (True, 'ios-fixture', [{'id': 'ios-fixture', 'targetPlatform': 'ios', 'emulator': False}], 0),
            (True, 'missing', [], 2),
        ):
            with self.subTest(execute=execute, device=device):
                argv = ['auto_test.py', 'run', '--execute' if execute else '--dry-run', '--device', device]
                with mock.patch.object(sys, 'argv', argv), \
                        mock.patch.object(cli, 'load_specs', return_value=selected), \
                        mock.patch.object(cli, 'validate', return_value=[]), \
                        mock.patch.object(cli, 'select', return_value=selected), \
                        mock.patch.object(cli, 'discover_devices', return_value=(devices, None)) as discover, \
                        mock.patch.object(execution_cli, 'run_cli', return_value=0) as run, \
                        mock.patch.dict(os.environ, {'IMBOY_TEST_DEVICE': 'previous'}):
                    self.assertEqual(cli.main(), expected)
                    self.assertEqual(os.environ['IMBOY_TEST_DEVICE'], 'previous')
                    if expected == 0:
                        options = run.call_args.args[0]
                        self.assertEqual(options.target, ['integration_test/app_test.dart'])
                        self.assertEqual(options.command, 'execution-run' if execute else 'execution-plan')
                        self.assertEqual(options.platform, ['ios'] if execute else [])
                    else:
                        run.assert_not_called()
                    if not execute:
                        discover.assert_not_called()

    def test_results_do_not_reimport_summaries_or_duplicate_input_paths(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            execution_cli.write_json(root / 'results.json', {'results': [{'id': 'one'}]})
            execution_cli.write_json(root / 'summary.json', {'results': [{'id': 'one'}]})
            self.assertEqual(execution_cli.load_results([root, root]), [{'id': 'one'}])
            self.assertEqual(execution_cli.load_results([root / 'missing.json']), [])

    def test_collected_artifacts_are_relocated_and_missing_or_corrupt_evidence_blocks(self):
        from auto_test_lib import execution_runner
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = 'fixture_test.py'
            (root / target).write_text('# Synthetic protocol fixture, no service or SDK\n')
            original = root / 'worker'
            events = [
                {'type': 'testStart', 'test': {'id': 1, 'name': 'fixture'}},
                {'type': 'testDone', 'testID': 1, 'result': 'success'},
                {'type': 'done', 'success': True},
            ]
            code = 'print(' + repr('\n'.join(json.dumps(event) for event in events)) + ')'
            receipt = execution_runner.execute_process([sys.executable, '-c', code], dict(os.environ), original)
            plan = {'commit': 'a' * 40, 'profile': 'tooling', 'source_fingerprint': 'synthetic'}
            instance = {'id': 'fixture', 'target': target, 'suite': 'tooling', 'platform': 'linux',
                        'product_profile': 'any', 'selected': True}
            attempt = execution_runner._record_attempt(root, plan, instance, receipt, receipt['lines'])
            row = execution_runner._finish(plan, instance, [attempt])
            self.assertEqual(row['status'], 'PASS', row)
            execution_cli.write_json(original / 'results.json', {'artifact_root': str(original), 'results': [row]})
            downloaded = root / 'downloaded'
            shutil.copytree(original, downloaded)
            original.rename(root / 'unavailable-worker')
            self.assertEqual(execution_cli.load_results([downloaded])[0]['status'], 'PASS')
            evidence = downloaded / Path(attempt['evidence']).relative_to(original)
            saved = evidence.read_bytes()
            evidence.write_text('corrupt evidence')
            self.assertEqual(execution_cli.load_results([downloaded])[0]['reason_code'], 'ARTIFACT_EVIDENCE_MISSING_OR_INVALID')
            evidence.write_bytes(saved)
            other_gate = {**row, 'companion_evidence': {'kind': 'coordinator-gate', 'instance_id': 'other'}}
            execution_cli.write_json(downloaded / 'results.json', {'artifact_root': str(original), 'results': [other_gate]})
            self.assertEqual(execution_cli.load_results([downloaded])[0]['status'], 'BLOCKED')
            companion = copy.deepcopy(row)
            companion['attempts'][0]['log_sha256'] = '0' * 64
            with_companion = {**row, 'companion_evidence': companion}
            execution_cli.write_json(downloaded / 'results.json', {'artifact_root': str(original), 'results': [with_companion]})
            self.assertEqual(execution_cli.load_results([downloaded])[0]['status'], 'BLOCKED')
            execution_cli.write_json(downloaded / 'results.json', {'artifact_root': str(original), 'results': [row]})
            evidence.unlink()
            self.assertEqual(execution_cli.load_results([downloaded])[0]['status'], 'BLOCKED')

    def test_failed_upstream_status_is_not_normalized_to_success(self):
        statuses = execution_cli.upstream_statuses(['prepare=cancelled', 'framework=failure'])
        self.assertEqual(statuses, {'prepare': 'cancelled', 'framework': 'failure'})
        with self.assertRaises(ValueError):
            execution_cli.upstream_statuses(['prepare'])

    def test_failed_gate_receipt_cannot_be_overwritten_by_later_pass(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            plan = {'commit': 'abc', 'profile': 'pr', 'source_fingerprint': 'source', 'gates': ['framework']}
            receipt = {key: plan[key] for key in ('commit', 'profile', 'source_fingerprint')}
            receipt.update(log='framework.log', exit_code=0)
            execution_cli.write_json(root / 'a/gates.json', {'framework': {**receipt, 'status': 'FAIL'}})
            execution_cli.write_json(root / 'b/gates.json', {'framework': {**receipt, 'status': 'PASS'}})
            self.assertEqual(execution_cli.load_gates([root], plan)['framework']['status'], 'FAIL')

    def test_gate_receipts_are_bound_to_source_commit_and_profile(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            plan = {'commit': 'abc', 'profile': 'pr', 'source_fingerprint': 'source', 'gates': ['framework']}
            receipt = {key: plan[key] for key in ('commit', 'profile', 'source_fingerprint')}
            receipt.update(log='framework.log', status='PASS', exit_code=0)
            for key in ('commit', 'profile', 'source_fingerprint'):
                with self.subTest(key=key):
                    execution_cli.write_json(root / 'gates.json', {'framework': {**receipt, key: 'stale'}})
                    row = execution_cli.load_gates([root], plan)['framework']
                    self.assertEqual(row['status'], 'BLOCKED')
                    self.assertEqual(row['reason_code'], 'STALE_GATE_EVIDENCE')
            for update in ({'exit_code': 137}, {'log': None}):
                execution_cli.write_json(root / 'gates.json', {'framework': {**receipt, **update}})
                self.assertEqual(execution_cli.load_gates([root], plan)['framework']['reason_code'], 'INVALID_GATE_EVIDENCE')

    def test_gate_log_must_arrive_with_its_relocated_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            original = root / 'gate-worker'
            plan = {'commit': 'abc', 'profile': 'pr', 'source_fingerprint': 'source', 'gates': ['ownership']}
            gates = execution_gates.run_gates(root, plan, original / 'gates', dict(os.environ))
            execution_cli.write_json(original / 'gates.json', gates)
            downloaded = root / 'gate-download'
            original.rename(downloaded)
            self.assertEqual(execution_cli.load_gates([downloaded], plan)['ownership']['status'], 'PASS')
            (downloaded / 'gates/ownership.log').unlink()
            self.assertEqual(execution_cli.load_gates([downloaded], plan)['ownership']['reason_code'], 'INVALID_GATE_EVIDENCE')

    def test_successful_job_cannot_erase_a_failed_gate_receipt(self):
        gates = execution_gates.merge_gate_statuses({'framework': {'status': 'FAIL'}}, {'quality-gates': 'success'})
        self.assertEqual(gates['framework'], 'FAIL')
        gates = execution_gates.merge_gate_statuses({'framework': {'status': 'PASS'}}, {'framework': 'cancelled'})
        self.assertEqual(gates['framework'], 'cancelled')

    def test_ci_jobs_attest_only_their_declared_prerequisite_gates(self):
        gates = execution_gates.merge_gate_statuses({}, {
            'execution-plan': 'success', 'quality-gates': 'cancelled',
            'contract-gates': 'failure', 'coverage': 'failure'})
        self.assertEqual(gates['ownership'], 'success')
        self.assertEqual(gates['framework'], 'missing')
        self.assertEqual(gates['static-analysis'], 'missing')
        self.assertEqual(gates['sqlite-generator'], 'missing')
        self.assertEqual(gates['contracts'], 'missing')
        self.assertEqual(gates['quality-gates'], 'cancelled')
        self.assertEqual(gates['contract-gates'], 'failure')
        self.assertEqual(gates['coverage'], 'failure')

    def test_failed_aggregate_preserves_individual_gate_evidence(self):
        receipts = {'framework': {'status': 'PASS'}, 'sqlite-generator': {'status': 'FAIL'}}
        for outcome in ('failure', 'cancelled', 'skipped'):
            with self.subTest(outcome=outcome):
                gates = execution_gates.merge_gate_statuses(receipts, {'quality-gates': outcome})
                self.assertEqual(gates['quality-gates'], outcome)
                self.assertEqual(gates['framework'], 'PASS')
                self.assertEqual(gates['sqlite-generator'], 'FAIL')
                self.assertEqual(gates['static-analysis'], 'missing')

    def test_ci_worker_matrix_is_derived_from_the_same_frozen_plan(self):
        plan = self.ci_job('execution-plan')
        self.assertIn('matrix: ${{ steps.matrix.outputs.matrix }}', plan)
        self.assertIn('execution-plan --profile pr --output "${{ runner.temp }}/pr-plan.json"', plan)
        self.assertIn('execution-matrix', plan)
        self.assertIn('--plan "${{ runner.temp }}/pr-plan.json"', plan)
        self.assertIn('--output "${{ runner.temp }}/host-matrix.json"', plan)
        self.assertIn("os.environ['GITHUB_OUTPUT']", plan)
        host = self.ci_job('host-tests')
        self.assertIn('matrix: ${{ fromJSON(needs.execution-plan.outputs.matrix) }}', host)
        self.assertNotIn('include:', host)

    def test_ci_suite_workers_keep_isolated_artifacts_and_the_original_plan(self):
        host = self.ci_job('host-tests')
        self.assertIn('fail-fast: false', host)
        self.assertIn('timeout-minutes: 60', host)
        self.assertIn('--plan "${{ runner.temp }}/execution-plan/pr-plan.json"', host)
        self.assertIn('WORKER_SUITE: ${{ matrix.suite }}', host)
        self.assertIn('--worker-platform "$WORKER_PLATFORM" --worker-suite "$WORKER_SUITE"', host)
        artifact = 'execution-${{ matrix.platform }}-${{ matrix.suite }}'
        self.assertIn('--artifact-dir "${{ runner.temp }}/' + artifact + '"', host)
        self.assertIn('name: ' + artifact, host)
        upload = host[host.index('- name: Upload execution evidence even after failure'):]
        self.assertIn('if: always()', upload)
        self.assertNotIn('execution-coverage', host)

    def test_ci_coverage_joins_all_linux_evidence_after_upstream_failure(self):
        coverage = self.ci_job('coverage')
        self.assertIn('if: always()', coverage.split('steps:', 1)[0])
        self.assertIn('needs: [execution-plan, host-tests]', coverage)
        self.assertIn('name: execution-plan', coverage)
        self.assertIn('pattern: execution-linux-*', coverage)
        self.assertIn('merge-multiple: false', coverage)
        command = coverage[coverage.index('- name: Reconcile declared coverage evidence'):]
        self.assertIn('if: always()', command.split('run:', 1)[0])
        self.assertIn('execution-coverage', command)
        self.assertIn('--plan "${{ runner.temp }}/execution-plan/pr-plan.json"', command)
        self.assertIn('--results "${{ runner.temp }}/linux-results" --platform linux', command)
        self.assertIn('--minimum 38', command)
        self.assertNotIn('--input', command)

    def test_ci_summary_waits_for_coverage_and_remains_an_unfiltered_required_check(self):
        summary = self.ci_job('test-summary')
        self.assertIn('name: IMBoy Test Summary', summary)
        self.assertIn('if: always()', summary.split('steps:', 1)[0])
        needs = re.search(r'^    needs: \[([^]]+)\]', summary, re.MULTILINE)
        self.assertIsNotNone(needs)
        self.assertTrue({'execution-plan', 'host-tests', 'coverage', 'quality-gates', 'contract-gates'}
                        <= {name.strip() for name in needs.group(1).split(',')})
        self.assertIn('UPSTREAM_JOBS: ${{ toJSON(needs) }}', summary)
        self.assertIn('--upstream-env UPSTREAM_JOBS', summary)
        workflow = (ROOT / '.github/workflows/ci.yml').read_text(encoding='utf-8')
        self.assertNotRegex(workflow.split('\npermissions:', 1)[0], r'\bpaths(?:-ignore)?:')

    def test_manual_golden_uses_dart_check_before_its_own_flutter_environment_contract(self):
        workflow = (ROOT / '.github/workflows/integration_test.yml').read_text(encoding='utf-8')
        step = re.search(r'^      - name: Verify prepared SDK\n(.*?)(?=^      - |\Z)',
                         workflow, re.MULTILINE | re.DOTALL)
        self.assertIsNotNone(step)
        self.assertIn('PROFILE: ${{ inputs.profile }}', step.group(1))
        command = '\n'.join(line[10:] for line in step.group(1).split('        run: |\n', 1)[1].splitlines())
        with tempfile.TemporaryDirectory() as directory:
            binary = Path(directory) / 'python3'
            binary.write_text('#!/bin/sh\nprintf "%s\\0" "$@"\nexit "${SDK_FIXTURE_EXIT:-0}"\n')
            binary.chmod(0o755)
            for profile in ('golden', 'backend', 'web', 'web-shell'):
                for code in (0, 2):
                    with self.subTest(profile=profile, code=code):
                        result = subprocess.run(
                            ['bash', '-e', '-o', 'pipefail', '-c', command], cwd=ROOT,
                            env={**os.environ, 'PATH': directory + os.pathsep + os.environ['PATH'],
                                 'CI': 'true', 'PROFILE': profile, 'SDK_FIXTURE_EXIT': str(code)},
                            text=True, capture_output=True, check=False)
                        self.assertEqual(result.returncode, code, result.stderr)
                        self.assertEqual(result.stdout.split('\0')[:-1], [
                            'scripts/check_sdk_compatibility.py', *(['--dart-only'] if profile == 'golden' else [])])

    def test_manual_choices_and_suite_help_expose_web_specialists(self):
        workflow = (ROOT / '.github/workflows/integration_test.yml').read_text(encoding='utf-8')
        profile = workflow.split('      profile:\n', 1)[1].split('      platform:\n', 1)[0]
        choices = re.search(r'options: \[([^]]+)\]', profile)
        self.assertIsNotNone(choices)
        self.assertTrue({'web', 'web-shell'} <= {value.strip() for value in choices[1].split(',')})
        result = subprocess.run(['bash', str(ROOT / 'scripts/run_test_suite.sh'), '--help'],
                                cwd=ROOT, text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('|web|web-shell|', result.stdout)

    def test_fts_browser_invocation_forwards_its_fixed_same_origin_wasm(self):
        from auto_test_lib import execution_adapters as adapters, execution_runner as runner
        from auto_test_lib.execution_catalog import build_plan
        target = 'test/unit_test/service/migration_v38_fts_web_test.dart'
        plan = build_plan(ROOT, profile='web', targets=[target])
        selected = [row for row in plan['instances'] if row['selected']]
        with tempfile.TemporaryDirectory() as directory, contextlib.ExitStack() as stack, \
                mock.patch.object(adapters, 'preflight_instance', return_value=[]), \
                mock.patch.object(adapters, 'product_artifact_evidence', return_value={'errors': []}):
            command, _, _ = runner._host_command(
                ROOT, selected, {'SQLITE_WASM_URL': 'https://external-fixture.invalid/sqlite3.wasm'},
                Path(directory), stack, adapters=adapters)
        self.assertIn('--machine', command)
        self.assertIn('--no-pub', command)
        self.assertEqual('chrome', command[command.index('--platform') + 1])
        self.assertIn('--dart-define=SQLITE_WASM_URL=/fixtures/sqlite3.wasm', command)
        self.assertFalse(any('external-fixture.invalid' in argument for argument in command))

    def test_sqlcipher_fts_needs_a_native_device_but_no_backend_or_product_artifact(self):
        from auto_test_lib import execution_adapters as adapters
        from auto_test_lib.execution_catalog import build_plan
        target = 'integration_test/sqlcipher_fts_v38_draft_test.dart'
        plan = build_plan(ROOT, profile='device-single', targets=[target])
        selected = [row for row in plan['instances'] if row['selected']]
        native = {'android': 'android-arm64', 'ios': 'ios', 'macos': 'darwin'}
        self.assertEqual(set(native), {row['platform'] for row in selected})
        env = {'IMBOY_EXECUTION_DEVICE': 'synthetic-native'}
        with tempfile.TemporaryDirectory() as directory, \
                mock.patch.object(adapters.shutil, 'which', return_value='/synthetic/flutter'), \
                mock.patch.object(adapters.socket, 'create_connection') as connect:
            for item in selected:
                with self.subTest(platform=item['platform']):
                    device = {'id': 'synthetic-native', 'targetPlatform': native[item['platform']],
                              'emulator': False}
                    self.assertFalse(adapters.needs_backend(item))
                    self.assertEqual([], adapters.preflight_instance(ROOT, item, env, [device], probe=True))
                    self.assertIn('DEVICE_NOT_FOUND', adapters.preflight_instance(ROOT, item, env, []))
                    invocation = adapters.build_invocation(ROOT, item, env, Path(directory), [device])
                    self.assertEqual([], invocation['errors'])
                    command = invocation['command']
                    self.assertEqual('synthetic-native', command[command.index('-d') + 1])
                    self.assertIn('--machine', command)
                    self.assertIn('--no-test-assets', command)
                    self.assertFalse(any('API_BASE_URL' in argument or 'TEST_PHONE' in argument
                                         for argument in command))
                    if item['platform'] != 'macos':
                        errors = adapters.preflight_instance(ROOT, item, env, [{**device, 'emulator': True}])
                        self.assertIn('ANDROID_EMULATOR_FORBIDDEN' if item['platform'] == 'android'
                                      else 'IOS_SIMULATOR_FORBIDDEN', errors)
            connect.assert_not_called()

    def test_coverage_counts_unique_lines_and_empty_evidence_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'lcov.info'
            path.write_text('SF:lib/a.dart\nDA:1,1\nDA:2,0\nend_of_record\n'
                            'SF:lib/a.dart\nDA:1,5\nDA:2,0\nend_of_record\n')
            self.assertEqual(execution_cli.coverage_check(path, 50), 0)
            self.assertEqual(execution_cli.coverage_check(path, 51), 1)
            path.write_text('')
            with self.assertRaises(ValueError):
                execution_cli.coverage_check(path, 0)


if __name__ == '__main__':
    unittest.main()
