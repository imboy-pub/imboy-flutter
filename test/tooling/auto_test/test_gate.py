"""Step 7 tooling tests: unified framework gate negative injections + CI parity.

ATF-602：五类负向注入（缺页 catalog / 未知 requirement / 全 SKIP 假绿 /
target 冲突 / 凭证字段）分别使 gate 非零退出（注入经
AUTO_TEST_FRAMEWORK_NEGATIVE 测试钩子选择注入源；未设置变量时 gate 零差异）。
ATF-603：quality.yml 与本地调用同一入口命令。
"""
from __future__ import annotations

import os
import subprocess
import sys
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
        # 自动设备发现仅限 android（不自动选 iOS）
        self.assertIn('platform.startswith("android")', suite)
        self.assertNotIn('platform.startswith(("android", "ios"))', suite)


if __name__ == '__main__':
    unittest.main()
