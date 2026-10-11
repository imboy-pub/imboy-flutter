"""Step 2 tooling tests: effective target config + capture 脚本回归。

ATF-101 连续两个 checkpoint 保存 2 张截图且无 NameError。
ATF-102 父子进程 APP/API/WS 指纹一致；目标不一致 fail-closed。
ATF-103 远程目标、缺凭证、缺设备在启动子进程前 BLOCKED。
"""
from __future__ import annotations

import importlib.util
import io
import json
import sys
import tempfile
import unittest
import unittest.mock
from contextlib import redirect_stderr
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))

from auto_test_lib.target_config import (  # noqa: E402
    EffectiveTargetConfig,
    build_flutter_test_command,
    effective_target_config,
    is_loopback_host,
    resolve_host,
)


def load_capture_module():
    spec = importlib.util.spec_from_file_location(
        'capture_integration_screenshots', ROOT / 'scripts' / 'capture_integration_screenshots.py'
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class TestLoopbackHost(unittest.TestCase):
    def test_loopback_variants(self):
        self.assertTrue(is_loopback_host('127.0.0.1'))
        self.assertTrue(is_loopback_host('127.0.0.8'))
        self.assertTrue(is_loopback_host('127.1.2.3'))
        self.assertTrue(is_loopback_host('::1'))

    def test_non_loopback_fail_closed(self):
        for host in ('localhost', '0.0.0.0', '192.168.2.98', 'api.imboy.pub', None, '127.0.0.256', '1270.0.0.1'):
            self.assertFalse(is_loopback_host(host), host)


class TestEffectiveTargetConfig(unittest.TestCase):
    BASE_ENV = {
        'IMBOY_APP_ENV': 'local',
        'IMBOY_API_BASE_URL_OVERRIDE': 'http://127.0.0.1:9800',
        'IMBOY_WS_URL_OVERRIDE': 'ws://127.0.0.1:9800',
        'IMBOY_TEST_PHONE': '+10000000000',
        'IMBOY_TEST_PASSWORD': 'placeholder-not-real',
    }

    def test_atf102_parent_child_same_fingerprint(self):
        # 父进程（run 侧）与子进程（capture 侧）用同一 env 快照得到同一指纹
        parent = effective_target_config(dict(self.BASE_ENV), device_id='anon-device', platform='android')
        child = effective_target_config(dict(self.BASE_ENV), device_id='anon-device', platform='android')
        self.assertEqual(parent.fingerprint, child.fingerprint)
        self.assertTrue(parent.consistent)
        self.assertNotIn('REMOTE_TARGET_FORBIDDEN', parent.blocked_codes)

    def test_atf102_env_override_chain_resolved(self):
        env = dict(self.BASE_ENV)
        env['IMBOY_API_BASE_URL_OVERRIDE'] = 'http://127.0.0.1:9801'
        cfg = effective_target_config(env, device_id='anon-device')
        self.assertEqual(cfg.api_host_resolved, '127.0.0.1')
        self.assertIn('--dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801', cfg.dart_defines)

    def test_atf102_pro_env_with_local_url_inconsistent(self):
        env = dict(self.BASE_ENV)
        env['IMBOY_APP_ENV'] = 'pro'
        cfg = effective_target_config(env, device_id='anon-device')
        self.assertFalse(cfg.consistent)
        self.assertEqual(cfg.inconsistency_code, 'APP_ENV_PRO_WITH_LOCAL_URL')

    def test_atf102_api_ws_origin_mismatch(self):
        env = dict(self.BASE_ENV)
        env['IMBOY_WS_URL_OVERRIDE'] = 'ws://127.0.0.2:9800'
        cfg = effective_target_config(env, device_id='anon-device')
        self.assertFalse(cfg.consistent)
        self.assertEqual(cfg.inconsistency_code, 'API_WS_ORIGIN_MISMATCH')

    def test_atf103_remote_target_blocked_before_spawn(self):
        env = dict(self.BASE_ENV)
        env['IMBOY_API_BASE_URL_OVERRIDE'] = 'https://api.example.invalid'
        cfg = effective_target_config(env, device_id='anon-device')
        self.assertFalse(cfg.consistent)
        self.assertIn('REMOTE_TARGET_FORBIDDEN', cfg.blocked_codes)
        # WS 单独远程同样挡下
        env2 = dict(self.BASE_ENV)
        env2['IMBOY_WS_URL_OVERRIDE'] = 'wss://ws.example.invalid'
        cfg2 = effective_target_config(env2, device_id='anon-device')
        self.assertIn('REMOTE_TARGET_FORBIDDEN', cfg2.blocked_codes)

    def test_atf103_missing_credentials_and_device(self):
        env = {k: v for k, v in self.BASE_ENV.items() if k not in ('IMBOY_TEST_PHONE', 'IMBOY_TEST_PASSWORD')}
        cfg = effective_target_config(env, device_id='')
        self.assertIn('CREDENTIALS_MISSING', cfg.blocked_codes)
        self.assertIn('DEVICE_MISSING', cfg.blocked_codes)

    def test_half_credentials_inconsistent(self):
        env = dict(self.BASE_ENV)
        env.pop('IMBOY_TEST_PASSWORD')
        cfg = effective_target_config(env, device_id='anon-device')
        self.assertFalse(cfg.consistent)
        self.assertEqual(cfg.inconsistency_code, 'CREDENTIALS_HALF_PRESENT')

    def test_public_dict_has_no_secrets(self):
        cfg = effective_target_config(dict(self.BASE_ENV), device_id='anon-device')
        blob = repr(cfg.to_public_dict())
        self.assertNotIn('placeholder-not-real', blob)
        self.assertNotIn('+10000000000', blob)

    def test_command_contains_defines_and_target(self):
        cfg = effective_target_config(dict(self.BASE_ENV), device_id='anon-device', target='integration_test/anon/anon_test.dart')
        cmd = build_flutter_test_command(cfg)
        self.assertEqual(cmd[0], 'flutter')
        self.assertIn('integration_test/anon/anon_test.dart', cmd)
        self.assertIn('-d', cmd)
        joined = ' '.join(cmd)
        for define in ('APP_ENV=local', 'API_BASE_URL_OVERRIDE=http://127.0.0.1:9800', 'WS_URL_OVERRIDE=ws://127.0.0.1:9800'):
            self.assertIn(define, joined)


class TestCaptureScript(unittest.TestCase):
    """ATF-101/103：capture 脚本成功路径不再触碰未定义变量；BLOCKED 不启动子进程。"""

    def _run_main(self, argv, env_patch=None):
        module = load_capture_module()
        tmp_root_holder = {}
        events = iter([
            json.dumps({'type': 'start'}) + '\n',
            json.dumps({'type': 'testStart', 'test': {'id': 1, 'name': 'capture fixture'}}) + '\n',
            json.dumps({'type': 'print', 'message': '[AI_SCREENSHOT] first checkpoint'}) + '\n',
            json.dumps({'type': 'print', 'message': '[AI_SCREENSHOT] second checkpoint'}) + '\n',
            json.dumps({'type': 'testDone', 'testID': 1, 'result': 'success',
                        'hidden': False, 'skipped': False}) + '\n',
            json.dumps({'type': 'done', 'success': True}) + '\n',
        ])
        env = {
            'IMBOY_APP_ENV': 'local',
            'IMBOY_API_BASE_URL_OVERRIDE': 'http://127.0.0.1:9800',
            'IMBOY_WS_URL_OVERRIDE': 'ws://127.0.0.1:9800',
            'IMBOY_TEST_PHONE': '+10000000000',
            'IMBOY_TEST_PASSWORD': 'placeholder-not-real',
        }
        env.update(env_patch or {})
        saved: list[Path] = []

        def fake_capture_android(device, destination):
            destination.write_bytes(b'\x89PNG fake bytes')
            saved.append(destination)
            return True

        class FakeProcess:
            stdout = io.TextIOWrapper(io.BytesIO(), encoding='utf-8')  # placeholder; replaced below
            def __init__(self):
                self.stdout = events
            def terminate(self):
                pass
            def wait(self):
                return 0

        with tempfile.TemporaryDirectory() as tmp:
            tmp_root = Path(tmp) / 'root'
            target_dir = tmp_root / 'integration_test' / 'unit_test'
            target_dir.mkdir(parents=True, exist_ok=True)
            (target_dir / 'anon_test.dart').write_text('// anonymous fixture for tooling test\n')
            tmp_root_holder['path'] = tmp_root
            argv_out = [
                'capture_integration_screenshots.py',
                '--target', 'integration_test/unit_test/anon_test.dart',
                '--device', 'anon-device',
                '--output', str(Path(tmp) / 'shots'),
                '--hold-ms', '1500',
                '--app-env', 'local',
            ]
            with unittest.mock.patch.object(module.sys, 'argv', argv_out), \
                 unittest.mock.patch.object(module, 'ROOT', tmp_root_holder['path']), \
                 unittest.mock.patch.dict(module.os.environ, env, clear=True), \
                 unittest.mock.patch.object(module, 'discover_devices', return_value=(
                     [{'id': 'anon-device', 'targetPlatform': 'android-arm',
                       'isSupported': True, 'emulator': False}], None)), \
                 unittest.mock.patch.object(module.subprocess, 'Popen', return_value=FakeProcess()), \
                 unittest.mock.patch.object(module, 'capture_android', side_effect=fake_capture_android), \
                 unittest.mock.patch.object(module.subprocess, 'run') as fake_run:
                err = io.StringIO()
                with redirect_stderr(err):
                    code = module.main()
            blobs = [path.read_bytes() for path in saved]
        return code, saved, blobs, err.getvalue()

    def test_atf101_two_checkpoints_two_files_no_name_error(self):
        code, saved, blobs, err = self._run_main([])
        self.assertEqual(code, 0, err)
        self.assertEqual(len(saved), 2, f'expected 2 saved screenshots, got {len(saved)}')
        self.assertEqual(len(blobs), 2)
        for blob in blobs:
            self.assertEqual(blob[:4], b'\x89PNG')

    def test_atf103_remote_env_blocks_before_subprocess(self):
        # 远程 API：Popen/adb 都不得被调用
        module = load_capture_module()
        env = {
            'IMBOY_APP_ENV': 'local',
            'IMBOY_API_BASE_URL_OVERRIDE': 'https://api.example.invalid',
            'IMBOY_TEST_PHONE': '+10000000000',
            'IMBOY_TEST_PASSWORD': 'placeholder-not-real',
        }
        with tempfile.TemporaryDirectory() as tmp:
            tmp_root = Path(tmp) / 'root'
            target_dir = tmp_root / 'integration_test' / 'unit_test'
            target_dir.mkdir(parents=True, exist_ok=True)
            (target_dir / 'anon_test.dart').write_text('// anonymous fixture for tooling test\n')
            argv = [
                'capture_integration_screenshots.py',
                '--target', 'integration_test/unit_test/anon_test.dart',
                '--device', 'anon-device',
                '--output', tmp,
                '--hold-ms', '1500',
                '--app-env', 'local',
            ]
            with unittest.mock.patch.object(module.sys, 'argv', argv), \
                 unittest.mock.patch.object(module, 'ROOT', tmp_root), \
                 unittest.mock.patch.dict(module.os.environ, env, clear=True), \
                 unittest.mock.patch.object(module.subprocess, 'Popen') as popen, \
                 unittest.mock.patch.object(module.subprocess, 'run') as sub_run:
                err = io.StringIO()
                with redirect_stderr(err):
                    code = module.main()
        self.assertEqual(code, 2)
        self.assertIn('BLOCKED', err.getvalue())
        popen.assert_not_called()
        sub_run.assert_not_called()

    def test_atf103_missing_credentials_blocks_before_subprocess(self):
        module = load_capture_module()
        env = {
            'IMBOY_APP_ENV': 'local',
            'IMBOY_API_BASE_URL_OVERRIDE': 'http://127.0.0.1:9800',
        }
        with tempfile.TemporaryDirectory() as tmp:
            tmp_root = Path(tmp) / 'root'
            target_dir = tmp_root / 'integration_test' / 'unit_test'
            target_dir.mkdir(parents=True, exist_ok=True)
            (target_dir / 'anon_test.dart').write_text('// anonymous fixture for tooling test\n')
            argv = [
                'capture_integration_screenshots.py',
                '--target', 'integration_test/unit_test/anon_test.dart',
                '--device', 'anon-device',
                '--output', tmp,
                '--hold-ms', '1500',
                '--app-env', 'local',
            ]
            with unittest.mock.patch.object(module.sys, 'argv', argv), \
                 unittest.mock.patch.object(module, 'ROOT', tmp_root), \
                 unittest.mock.patch.dict(module.os.environ, env, clear=True), \
                 unittest.mock.patch.object(module.subprocess, 'Popen') as popen:
                err = io.StringIO()
                with redirect_stderr(err):
                    code = module.main()
        self.assertEqual(code, 2)
        self.assertIn('CREDENTIALS_MISSING', err.getvalue())
        popen.assert_not_called()


if __name__ == '__main__':
    unittest.main()
