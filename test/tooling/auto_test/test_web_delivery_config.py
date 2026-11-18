"""Delivery build input guards; real entrypoint with stubbed build/test tools."""

import base64
import contextlib
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))
import check_web_delivery_config as delivery
import test_execution_entrypoints as entrypoints


def encode(value):
    return base64.b64encode(value.encode()).decode()


class WebDeliveryConfigTest(unittest.TestCase):
    def production_build(self, environment=None, arguments=()):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ['scripts', 'web/pkg', 'bin']:
                (root / name).mkdir(parents=True)
            for name in ['scripts/check_web_delivery_config.py', 'web/build_web.sh']:
                shutil.copyfile(ROOT / name, root / name)
            for name in ['vodozemac_bindings_dart.js', 'vodozemac_bindings_dart_bg.wasm']:
                (root / 'web/pkg' / name).write_text('synthetic fixture')
            (root / 'bin/python3').symlink_to(sys.executable)
            flutter = root / 'bin/flutter'
            flutter.write_text('#!/bin/sh\nprintf "%s\\n" "$@" >> "$BUILD_CALLS"\n')
            flutter.chmod(0o755)
            calls = root / 'calls'
            result = subprocess.run(['bash', str(root / 'web/build_web.sh'), *arguments],
                env={'PATH': str(root / 'bin') + os.pathsep + os.defpath,
                     'BUILD_CALLS': str(calls), **(environment or {})},
                capture_output=True, text=True, check=False)
            return result, calls.read_text().splitlines() if calls.exists() else []

    def test_production_entrypoint_accepts_clean_build(self):
        result, calls = self.production_build()
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls, ['build', 'web', '--release', '--no-tree-shake-icons'])

    def test_production_entrypoint_rejects_bypass_before_flutter(self):
        for environment in [{'WEB_E2E_TOKEN': 'synthetic-private-marker'},
                            {'DART_DEFINES': encode('WEB_E2E_UID=synthetic-private-marker')},
                            {'DART_DEFINES': 'invalid!'}]:
            with self.subTest(keys=sorted(environment)):
                result, calls = self.production_build(environment)
                self.assertEqual(result.returncode, 1)
                self.assertEqual(calls, [])
                self.assertNotIn('synthetic-private-marker', result.stdout + result.stderr)

    def test_unsupported_build_arguments_are_rejected_without_echoing_values(self):
        argument = '--dart-define=WEB_E2E_TOKEN=synthetic-private-marker'
        result, calls = self.production_build(arguments=[argument])
        self.assertEqual(result.returncode, 64)
        self.assertEqual(calls, [])
        self.assertNotIn('synthetic-private-marker', result.stdout + result.stderr)
        with mock.patch.dict(os.environ, {'PATH': os.defpath}, clear=True):
            result, calls, _ = entrypoints.EntrypointTest().run_web_shell([argument])
        self.assertEqual(result.returncode, 64)
        self.assertEqual(calls, [])
        self.assertNotIn('synthetic-private-marker', result.stdout + result.stderr)

    def test_clean_and_unrelated_defines_are_accepted(self):
        self.assertEqual(delivery.violations({}), [])
        self.assertEqual(delivery.violations({'DART_DEFINES': encode('APP_ENV=local')}), [])

    def test_both_bypass_keys_are_rejected_even_when_empty(self):
        for key in sorted(delivery.FORBIDDEN):
            for value in ['', 'synthetic-private-marker']:
                with self.subTest(key=key, empty=not value):
                    self.assertEqual(delivery.violations({key: value}),
                                     ['forbidden_environment_key:' + key])
                    self.assertEqual(delivery.violations({'DART_DEFINES': encode(key + '=' + value)}),
                                     ['forbidden_dart_define:' + key])

    def test_malformed_encoded_configuration_fails_closed(self):
        for value in ['invalid!', encode('MISSING_SEPARATOR'), encode('=empty-key'),
                      encode('APP_ENV=local') + ',', '/w==', 'x' * 1048577]:
            with self.subTest(length=len(value)):
                self.assertIn('invalid_dart_defines', delivery.violations({'DART_DEFINES': value}))

    def test_result_and_usage_errors_do_not_print_values(self):
        marker = 'synthetic-private-marker'
        output, errors = io.StringIO(), io.StringIO()
        with mock.patch.dict(os.environ, {'WEB_E2E_TOKEN': marker}, clear=True), \
                mock.patch.object(sys, 'argv', ['checker']), contextlib.redirect_stdout(output):
            self.assertEqual(delivery.main(), 1)
        with mock.patch.object(sys, 'argv', ['checker', marker]), contextlib.redirect_stderr(errors):
            self.assertEqual(delivery.main(), 64)
        self.assertNotIn(marker, output.getvalue() + errors.getvalue())

    def test_real_entrypoint_blocks_build_and_preserves_shared_failure_verdict(self):
        for inputs in [{'WEB_E2E_UID': 'synthetic-private-marker'},
                       {'DART_DEFINES': encode('WEB_E2E_TOKEN=synthetic-private-marker')},
                       {'DART_DEFINES': 'invalid!'}]:
            with self.subTest(keys=sorted(inputs)), \
                    mock.patch.dict(os.environ, {'PATH': os.defpath}, clear=True):
                result, calls, logs = entrypoints.EntrypointTest().run_web_shell(['--no-server'], inputs)
                self.assertEqual(result.returncode, 2)
                self.assertFalse(any(call[:2] == ['flutter', 'build'] for call in calls))
                run = [call for call in calls if 'execution-run' in call]
                self.assertEqual(len(run), 1)
                self.assertIn('web-shell-delivery-config=failure', run[0])
                self.assertIn('delivery-config.log', logs)
                self.assertNotIn('synthetic-private-marker', result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
