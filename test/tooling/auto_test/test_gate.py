"""Step 7 tooling tests: unified framework gate negative injections + CI parity.

ATF-602：五类负向注入（缺页 catalog / 未知 requirement / 全 SKIP 假绿 /
target 冲突 / 凭证字段）分别使 gate 非零退出（注入经
AUTO_TEST_FRAMEWORK_NEGATIVE 测试钩子选择注入源；未设置变量时 gate 零差异）。
ATF-603：quality.yml 与本地调用同一入口命令。
"""
from __future__ import annotations

import os
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
GATE = ROOT / 'scripts' / 'check_auto_test_framework.sh'
QUALITY_YML = ROOT / '.github' / 'workflows' / 'quality.yml'

NEGATIVE_CASES = (
    'missing_catalog_page',
    'unknown_requirement',
    'all_skip_fake_green',
    'target_conflict',
    'credential_field',
)


def run_gate(negative: str = '', timeout: int = 120):
    env = dict(os.environ)
    if negative:
        env['AUTO_TEST_FRAMEWORK_NEGATIVE'] = negative
    else:
        env.pop('AUTO_TEST_FRAMEWORK_NEGATIVE', None)
    return subprocess.run(
        ['bash', str(GATE)],
        capture_output=True, text=True, cwd=ROOT, env=env, timeout=timeout,
    )


class TestGateNegativeInjections(unittest.TestCase):
    """ATF-602：注入必须让统一 gate 非零退出。"""

    def test_gate_script_exists_and_executable(self):
        self.assertTrue(GATE.is_file())
        self.assertTrue(os.access(GATE, os.X_OK))

    def test_five_negative_cases_each_fail_the_gate(self):
        for case in NEGATIVE_CASES:
            with self.subTest(case=case):
                proc = run_gate(case)
                self.assertNotEqual(
                    proc.returncode, 0,
                    '注入 %s 必须使 gate 非零退出；stdout=%s stderr=%s'
                    % (case, proc.stdout[-400:], proc.stderr[-400:]),
                )
                self.assertLess(proc.returncode, 64, '已知用例不得落入用法错误 64')

    def test_unknown_injection_case_is_usage_error_64(self):
        proc = run_gate('definitely_not_a_case')
        self.assertEqual(proc.returncode, 64)
        self.assertIn('未知注入用例', proc.stderr)

    def test_negative_hook_names_documented_in_gate(self):
        text = GATE.read_text(encoding='utf-8')
        for case in NEGATIVE_CASES:
            self.assertIn(case, text)
        self.assertIn('AUTO_TEST_FRAMEWORK_NEGATIVE', text)


class TestGateCiParity(unittest.TestCase):
    """ATF-603：CI 与本地同一入口命令。"""

    def test_quality_yml_calls_the_same_gate_entry(self):
        text = QUALITY_YML.read_text(encoding='utf-8')
        self.assertIn('auto-test-framework:', text)
        self.assertIn('bash scripts/check_auto_test_framework.sh', text)
        # 该 job 只调 gate，不隐式启动设备/远程后端/视觉模型
        start = text.index('auto-test-framework:')
        end = text.index('sqlite-migration-gate:')
        job = text[start:end]
        self.assertNotIn('flutter test', job)
        self.assertNotIn('patrol', job)
        self.assertNotIn('adb', job)
        self.assertNotIn('magick', job)

    def test_ci_checks_out_sibling_backend_sources_for_domain_tests(self):
        text = QUALITY_YML.read_text(encoding='utf-8')
        job = text[text.index('auto-test-framework:'):text.index('sqlite-migration-gate:')]
        self.assertIn('working-directory: imboyapp', job)
        self.assertIn('path: imboyapp\n', job)
        source_steps = job[job.index('- name: Resolve pinned cross-repository sources'):]
        source_steps = source_steps[:source_steps.index('- name: Run unified framework gate')]
        self.assertIn('id: sources\n', source_steps)
        self.assertIn('ci_source_lock.py outputs --app . --github-output "$GITHUB_OUTPUT"', source_steps)
        lock = json.loads((ROOT / '.github/ci-source-lock.json').read_text())
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'github-output'
            proc = subprocess.run([sys.executable, str(ROOT / '.github/scripts/ci_source_lock.py'),
                                   'outputs', '--app', str(ROOT), '--github-output', str(output)],
                                  capture_output=True, text=True, check=True)
            resolved = json.loads(proc.stdout)
            emitted = dict(line.split('=', 1) for line in output.read_text().splitlines())
        for name, path in (('backend', 'imboy'), ('admin', 'imboyadmin')):
            self.assertRegex(lock['repositories'][name]['sha'], r'^[0-9a-f]{40}$')
            for field in ('repository', 'sha'):
                self.assertEqual(resolved[name + '_' + field], lock['repositories'][name][field])
                self.assertEqual(emitted[name + '_' + field], resolved[name + '_' + field])
            checkout = source_steps[source_steps.index('- name: Checkout ' + name):]
            checkout = checkout[:checkout.index('\n      - name:')]
            self.assertIn('repository: ${{ steps.sources.outputs.' + name + '_repository }}', checkout)
            self.assertIn('ref: ${{ steps.sources.outputs.' + name + '_sha }}', checkout)
            self.assertIn('path: ' + path + '\n', checkout)
            # A manifest-only checkout cannot validate backend targets/Makefile.
            self.assertNotIn('sparse-checkout:', checkout)
        self.assertIn('ci_source_lock.py checkout --app . --backend ../imboy --admin ../imboyadmin', source_steps)
        self.assertIn('/auto-test-framework/source-checkout.json', source_steps)
        self.assertNotIn('continue-on-error:', source_steps)

    def test_ci_retains_per_run_gate_logs_even_on_failure(self):
        text = QUALITY_YML.read_text(encoding='utf-8')
        job = text[text.index('auto-test-framework:'):text.index('sqlite-migration-gate:')]
        self.assertIn('AUTO_TEST_REPORT_ROOT: ${{ runner.temp }}/auto-test-framework', job)
        upload = job[job.index('- name: Upload framework gate diagnostics'):]
        self.assertIn('if: always()', upload)
        self.assertIn('actions/upload-artifact@', upload)
        self.assertIn('/auto-test-framework/gate_*.log', upload)
        self.assertIn('/auto-test-framework/gate_summary.json', upload)
        gate = GATE.read_text(encoding='utf-8')
        self.assertNotIn('/tmp/atf_gate_', gate)
        for check in ('unittest', 'catalog', 'validate', 'report', 'diffcheck',
                      'pycompile', 'selfcheck', 'drift'):
            self.assertIn('$AUTO_TEST_REPORT_ROOT/gate_%s.log' % check, gate)

    def test_retired_runner_delegates_without_defaults(self):
        retired = (ROOT / 'scripts' / 'run_all_integration_tests.sh').read_text(
            encoding='utf-8'
        )
        # 已删除：固定设备 / 远程生产地址 / 账号默认值 / 日志关键词 PASS 判定
        self.assertNotIn('XWE6R19916004085', retired)
        self.assertNotIn('pro.imboy.pub', retired)
        self.assertNotIn('118@imboy.pub', retired)
        self.assertNotIn('admin888', retired)
        self.assertNotIn('All tests passed', retired)
        self.assertNotIn('108@imboy.pub', retired)
        self.assertIn('run_test_suite.sh', retired)

    def test_run_test_suite_reuses_gate_and_never_autoselects_ios(self):
        suite = (ROOT / 'scripts' / 'run_test_suite.sh').read_text(encoding='utf-8')
        self.assertIn('check_auto_test_framework.sh', suite)
        # 漂移检查不再在解析参数前阻断
        self.assertNotIn('generate_product_features.py', suite)
        # 兼容壳只委托共享计划；必须显式提供设备，不能自行挑一台发往全部目标。
        self.assertIn('execution-plan', suite)
        self.assertIn('execution-run', suite)
        self.assertNotIn('flutter devices', suite)
        self.assertNotIn('find integration_test', suite)


class TestProductDriftAdminRoot(unittest.TestCase):
    """Exercise the actual gate with an isolated generator spy."""

    def _run(self, admin_root, generator_exit=0):
        with tempfile.TemporaryDirectory(prefix='imboy-gate-admin-') as tmp:
            root = Path(tmp)
            app = root / 'app'
            backend = root / 'backend'
            (app / 'scripts' / 'auto_test_lib').mkdir(parents=True)
            (backend / 'scripts').mkdir(parents=True)
            shutil.copyfile(GATE, app / 'scripts' / 'check_auto_test_framework.sh')
            (app / 'scripts' / 'auto_test.py').write_text('')
            (app / 'scripts' / 'capture_integration_screenshots.py').write_text('')
            (app / 'scripts' / 'auto_test_lib' / 'dummy.py').write_text('')
            (backend / 'scripts' / 'generate_product_features.py').write_text(
                'import json, os, sys\n'
                'from pathlib import Path\n'
                "Path(os.environ['GATE_ARGS_CAPTURE']).write_text(json.dumps(sys.argv[1:]))\n"
                "sys.exit(int(os.environ['GATE_GENERATOR_EXIT']))\n"
            )
            env = dict(os.environ)
            env.pop('AUTO_TEST_FRAMEWORK_NEGATIVE', None)
            env.pop('IMBOY_ADMIN_ROOT', None)
            if admin_root is not None:
                env['IMBOY_ADMIN_ROOT'] = admin_root
            env.update({
                'IMBOY_BACKEND_ROOT': str(backend),
                'AUTO_TEST_REPORT_ROOT': str(root / 'report'),
                'GATE_ARGS_CAPTURE': str(root / 'generator-args.json'),
                'GATE_GENERATOR_EXIT': str(generator_exit),
            })
            result = subprocess.run(
                ['bash', str(app / 'scripts' / 'check_auto_test_framework.sh'), '--checks-only'],
                cwd=app, env=env, text=True, capture_output=True, timeout=30,
            )
            args_path = root / 'generator-args.json'
            args = json.loads(args_path.read_text()) if args_path.exists() else None
            summary = json.loads((root / 'report' / 'gate_summary.json').read_text())
            return args, summary['environment'], str(app), result.returncode

    def test_unset_preserves_generator_default(self):
        args, env, app, _ = self._run(None)
        self.assertEqual(args, ['--check', '--app-dir', app])
        self.assertEqual(env['product_drift_status'], 'OK')

    def test_explicit_path_with_spaces_is_one_argument(self):
        args, env, app, _ = self._run('/tmp/admin tree')
        self.assertEqual(args, ['--check', '--app-dir', app, '--admin-dir', '/tmp/admin tree'])
        self.assertEqual(env['product_drift_status'], 'OK')

    def test_explicit_empty_blocks_without_calling_generator(self):
        args, env, _, code = self._run('')
        self.assertIsNone(args)
        self.assertEqual(env['product_drift_status'], 'BLOCKED_PRODUCT_DRIFT')
        self.assertTrue(env['product_drift_is_gate_fatal'])
        self.assertIn('empty path', env['product_drift_detail'])
        self.assertNotEqual(code, 0)

    def test_generator_failure_stays_blocked(self):
        args, env, app, code = self._run('/missing/admin', generator_exit=2)
        self.assertEqual(args, ['--check', '--app-dir', app, '--admin-dir', '/missing/admin'])
        self.assertEqual(env['product_drift_status'], 'BLOCKED_PRODUCT_DRIFT')
        self.assertNotEqual(code, 0)


if __name__ == '__main__':
    unittest.main()
