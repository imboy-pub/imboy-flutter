#!/usr/bin/env python3
"""auto_test run 执行前设备资格门的行为测试（纯离线，不调用真实 flutter）。

覆盖：Android 真机、macOS 桌面、未知设备、iOS、Chrome/web、Android 模拟器、
设备 ID/平台不一致、空设备 ID；并证明 --execute 的拒绝发生在任何测试子进程
启动之前（monkeypatch subprocess.run，被调用即测试失败）。

运行：python3 -m unittest scripts.auto_test_lib.auto_test_platform_gate_test -v
（cwd=仓库根，或直接 python3 scripts/auto_test_lib/auto_test_platform_gate_test.py）
"""
from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / 'scripts'))

import auto_test  # noqa: E402


ANDROID_REAL = {'id': 'REALANDROID01', 'name': 'Pixel', 'targetPlatform': 'android-arm64', 'emulator': False}
ANDROID_EMU = {'id': 'EMULATOR01', 'name': 'sdk_gphone', 'targetPlatform': 'android-x64', 'emulator': True}
MACOS_DESKTOP = {'id': 'macos', 'name': 'macOS', 'targetPlatform': 'darwin', 'emulator': False}
IOS_DEVICE = {'id': 'IPHONEUDID', 'name': 'iPhone', 'targetPlatform': 'ios', 'emulator': False}
CHROME = {'id': 'chrome', 'name': 'Chrome', 'targetPlatform': 'web-javascript', 'emulator': False}
UNKNOWN_TARGET = {'id': 'WEIRD01', 'name': 'weird', 'targetPlatform': 'linux', 'emulator': False}

ALL = [ANDROID_REAL, ANDROID_EMU, MACOS_DESKTOP, IOS_DEVICE, CHROME, UNKNOWN_TARGET]


class QualifyDeviceTest(unittest.TestCase):
    def test_android_real_device_passes(self):
        platform, errors = auto_test.qualify_device('REALANDROID01', ALL)
        self.assertEqual(platform, 'android')
        self.assertEqual(errors, [])

    def test_macos_desktop_passes(self):
        platform, errors = auto_test.qualify_device('macos', ALL)
        self.assertEqual(platform, 'macos')
        self.assertEqual(errors, [])

    def test_unknown_device_rejected_not_defaulted_to_android(self):
        platform, errors = auto_test.qualify_device('NOPE123', ALL)
        self.assertEqual(platform, '')
        self.assertIn('DEVICE_NOT_FOUND', errors)

    def test_ios_rejected(self):
        platform, errors = auto_test.qualify_device('IPHONEUDID', ALL)
        self.assertEqual(platform, '')
        self.assertIn('IOS_DEVICE_NOT_IN_PLATFORM_SET', errors)

    def test_chrome_rejected(self):
        platform, errors = auto_test.qualify_device('chrome', ALL)
        self.assertEqual(platform, '')
        self.assertIn('UNSUPPORTED_TARGET_PLATFORM:web-javascript', errors)

    def test_android_emulator_rejected(self):
        platform, errors = auto_test.qualify_device('EMULATOR01', ALL)
        self.assertEqual(platform, '')
        self.assertIn('ANDROID_EMULATOR_FORBIDDEN', errors)

    def test_unexpected_target_platform_rejected(self):
        platform, errors = auto_test.qualify_device('WEIRD01', ALL)
        self.assertEqual(platform, '')
        self.assertIn('UNSUPPORTED_TARGET_PLATFORM:linux', errors)

    def test_empty_device_id_rejected(self):
        platform, errors = auto_test.qualify_device('', ALL)
        self.assertEqual(platform, '')
        self.assertIn('DEVICE_ID_MISSING', errors)

    def test_android_with_missing_emulator_flag_rejected_fail_closed(self):
        dev = {'id': 'NOFLAG01', 'name': 'mystery', 'targetPlatform': 'android-arm64'}
        platform, errors = auto_test.qualify_device('NOFLAG01', [dev])
        self.assertEqual(platform, '')
        self.assertIn('ANDROID_EMULATOR_FLAG_UNKNOWN', errors)

    def test_missing_target_platform_rejected(self):
        dev = {'id': 'NOTARGET01', 'name': 'mystery'}
        platform, errors = auto_test.qualify_device('NOTARGET01', [dev])
        self.assertEqual(platform, '')
        self.assertIn('UNSUPPORTED_TARGET_PLATFORM:unknown', errors)

    def test_macos_execute_passes_gate_before_spawn(self):
        spec = {'id': 'GATE-MAC', 'runner': {'type': 'flutter', 'target': 'gate_test.dart'},
                'safe_to_execute': True}
        started = []

        def recorder(cmd, **kwargs):
            started.append(cmd)
            raise AssertionError('测试到此为止：已确认 macOS 资格放行')

        with mock.patch.object(auto_test, 'discover_devices', return_value=(ALL, None)), \
             mock.patch.object(auto_test.subprocess, 'run', side_effect=recorder):
            with self.assertRaises(AssertionError):
                auto_test.run([({'p': 'gate_test.dart'}, spec)],
                              device='macos', execute=True,
                              artifact_dir=Path(tempfile.mkdtemp()))
        self.assertEqual(len(started), 1)
        self.assertIn('macos', started[0])

    def test_device_platform_mismatch_rejected(self):
        # 设备 ID 存在，但其声明平台与请求路径期望不符（ios 冒充 android）：
        # 资格判定以 flutter devices 的 targetPlatform 为准，直接拒绝。
        platform, errors = auto_test.qualify_device('IPHONEUDID', ALL)
        self.assertNotEqual(platform, 'android')

    def test_discover_devices_malformed_output_rejected(self):
        fake = mock.Mock(returncode=0, stdout='not-json', stderr='')
        with mock.patch.object(auto_test.subprocess, 'run', return_value=fake):
            devices, error = auto_test.discover_devices()
        self.assertEqual(devices, [])
        self.assertEqual(error, 'DEVICE_DISCOVERY_MALFORMED')

    def test_discover_devices_nonzero_exit_rejected(self):
        fake = mock.Mock(returncode=1, stdout='', stderr='boom')
        with mock.patch.object(auto_test.subprocess, 'run', return_value=fake):
            devices, error = auto_test.discover_devices()
        self.assertEqual(error, 'DEVICE_DISCOVERY_FAILED')


class ExecuteGateBeforeSpawnTest(unittest.TestCase):
    """--execute 的拒绝必须发生在任何测试子进程启动之前。"""

    def _run_execute(self, device: str, devices, discovery_error=None):
        spawned = []
        real_subprocess_run = auto_test.subprocess.run

        def guard(*args, **kwargs):
            spawned.append(args)
            raise AssertionError('subprocess.run 在资格拒绝后仍被调用')

        with mock.patch.object(auto_test, 'discover_devices',
                               return_value=([], discovery_error) if discovery_error else (devices, None)), \
             mock.patch.object(auto_test.subprocess, 'run', side_effect=guard):
            code = auto_test.run([], device=device, execute=True,
                                 artifact_dir=Path(tempfile.mkdtemp()))
        return code, spawned

    def test_unknown_device_execute_rejects_before_spawn(self):
        code, spawned = self._run_execute('NOPE123', ALL)
        self.assertEqual(code, 2)
        self.assertEqual(spawned, [])

    def test_ios_execute_rejects_before_spawn(self):
        code, spawned = self._run_execute('IPHONEUDID', ALL)
        self.assertEqual(code, 2)
        self.assertEqual(spawned, [])

    def test_emulator_execute_rejects_before_spawn(self):
        code, spawned = self._run_execute('EMULATOR01', ALL)
        self.assertEqual(code, 2)
        self.assertEqual(spawned, [])

    def test_empty_device_execute_rejects_before_spawn(self):
        code, spawned = self._run_execute('', ALL)
        self.assertEqual(code, 2)
        self.assertEqual(spawned, [])

    def test_discovery_failure_execute_rejects_before_spawn(self):
        code, spawned = self._run_execute('REALANDROID01', [], discovery_error='DEVICE_DISCOVERY_FAILED')
        self.assertEqual(code, 2)
        self.assertEqual(spawned, [])

    def test_qualified_device_execute_spawns_flutter_test_as_first_subprocess(self):
        # 资格通过时执行链才允许前进：首个（也是唯一一个）子进程必须是
        # 携带 -d <设备> 的 flutter test，且 recorder 立即终止流程。
        spec = {'id': 'GATE-SPEC', 'runner': {'type': 'flutter', 'target': 'gate_test.dart'},
                'safe_to_execute': True}
        started = []

        def recorder(cmd, **kwargs):
            started.append(cmd)
            raise AssertionError('测试到此为止：已确认首个子进程')

        with mock.patch.object(auto_test, 'discover_devices', return_value=(ALL, None)), \
             mock.patch.object(auto_test.subprocess, 'run', side_effect=recorder):
            with self.assertRaises(AssertionError):
                auto_test.run([({'p': 'gate_test.dart'}, spec)],
                              device='REALANDROID01', execute=True,
                              artifact_dir=Path(tempfile.mkdtemp()))
        self.assertEqual(len(started), 1)
        self.assertEqual(started[0][:3], ['flutter', 'test', 'gate_test.dart'])
        self.assertIn('-d', started[0])
        self.assertIn('REALANDROID01', started[0])


class DryRunInferenceSeparationTest(unittest.TestCase):
    """离线 dry-run 的平台推断与执行资格严格分离。"""

    def test_platform_for_device_only_for_dry_run(self):
        self.assertEqual(auto_test.platform_for_device('macos'), 'macos')
        self.assertEqual(auto_test.platform_for_device('darwin'), 'macos')
        # 非法设备在 dry-run 也仅是推断显示，不代表执行资格：
        self.assertEqual(auto_test.platform_for_device('NOPE123'), 'android')
        self.assertEqual(auto_test.platform_for_device('chrome'), 'android')

    def test_dry_run_does_not_call_device_discovery(self):
        with mock.patch.object(auto_test, 'discover_devices') as disc:
            code = auto_test.run([], device='NOPE123', execute=False,
                                 artifact_dir=Path(tempfile.mkdtemp()))
            disc.assert_not_called()
        self.assertEqual(code, 0)


if __name__ == '__main__':
    unittest.main(verbosity=2)
