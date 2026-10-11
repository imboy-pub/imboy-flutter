"""Screenshot capture must prove completed tests and fresh image evidence."""
import json
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
from unittest import mock

from scripts import capture_integration_screenshots as capture
from scripts.capture_integration_screenshots import capture_exit_code


def events(*, skipped=False, success=True):
    return [json.dumps(event) for event in [
        {'type': 'start'},
        {'type': 'testStart', 'test': {'id': 1, 'name': 'real journey'}},
        {'type': 'testDone', 'testID': 1, 'result': 'success',
         'skipped': skipped, 'hidden': False},
        {'type': 'done', 'success': success},
    ]]


class CaptureIntegrityTest(unittest.TestCase):
    def test_interrupt_returning_zero_without_done_is_blocked(self):
        self.assertEqual(capture_exit_code(events()[:-1], 0, 1), 2)

    def test_failed_done_returning_zero_is_rejected(self):
        self.assertEqual(capture_exit_code(events(success=False), 0, 1), 1)

    def test_all_skipped_with_images_is_blocked(self):
        self.assertEqual(capture_exit_code(events(skipped=True), 0, 1), 2)

    def test_completed_tests_without_images_are_blocked(self):
        self.assertEqual(capture_exit_code(events(), 0, 0), 2)

    def test_nonzero_process_cannot_pass(self):
        self.assertNotEqual(capture_exit_code(events(), 1, 1), 0)

    def test_completed_non_skipped_test_with_image_passes(self):
        self.assertEqual(capture_exit_code(events(), 0, 1), 0)

    def test_done_success_must_be_explicit_boolean_true(self):
        for done in [{'type': 'done'}, {'type': 'done', 'success': 'true'}]:
            with self.subTest(done=done):
                self.assertNotEqual(capture_exit_code(
                    events()[:-1] + [json.dumps(done)], 0, 1), 0)

    def test_unfinished_test_cannot_pass(self):
        lines = events()[:-1] + [json.dumps(
            {'type': 'testStart', 'test': {'id': 2, 'name': 'unfinished'}})] + events()[-1:]
        self.assertNotEqual(capture_exit_code(lines, 0, 1), 0)

    def test_hidden_failure_cannot_pass(self):
        lines = events()
        lines[-2] = json.dumps({'type': 'testDone', 'testID': 1,
                               'result': 'failure', 'hidden': True, 'skipped': False})
        self.assertNotEqual(capture_exit_code(lines, 0, 1), 0)

    def test_unclassified_error_cannot_pass(self):
        lines = events()[:-1] + [json.dumps(
            {'type': 'error', 'isFailure': False, 'error': 'unexpected error'})] + events()[-1:]
        self.assertNotEqual(capture_exit_code(lines, 0, 1), 0)

    def test_print_event_marker_does_not_include_json_syntax(self):
        line = json.dumps({'type': 'print', 'message': '[AI_SCREENSHOT] profile_ready'})
        self.assertEqual(capture.screenshot_marker(line).group(1), 'profile_ready')
        self.assertIsNone(capture.screenshot_marker('[AI_SCREENSHOT] forged'))

    def test_existing_screenshots_cannot_be_reused(self):
        with TemporaryDirectory() as td:
            (Path(td) / '01_ready.png').write_bytes(b'old screenshot')
            argv = ['capture', '--target', 'integration_test/smoke/smoke_test.dart',
                    '--device', 'REALANDROID', '--output', td]
            cfg = SimpleNamespace(blocked_codes=[], consistent=True)
            with mock.patch.object(capture.sys, 'argv', argv), \
                 mock.patch.object(capture, 'effective_target_config', return_value=cfg), \
                 mock.patch.object(capture, 'capture_device_errors', return_value=[]), \
                 mock.patch.object(capture.subprocess, 'Popen') as spawn:
                self.assertEqual(capture.main(), 2)
                spawn.assert_not_called()

    def test_direct_capture_rejects_ios(self):
        with mock.patch.object(capture, 'discover_devices', return_value=(
                [{'id': 'IOS', 'targetPlatform': 'ios', 'isSupported': True}], None)):
            self.assertIn('IOS_DEVICE_NOT_IN_PLATFORM_SET',
                          capture.capture_device_errors('IOS', 'ios'))

    def test_direct_capture_rejects_declared_platform_mismatch(self):
        with mock.patch.object(capture, 'discover_devices', return_value=(
                [{'id': 'ANDROID', 'targetPlatform': 'android-arm',
                  'isSupported': True, 'emulator': False}], None)):
            self.assertEqual(capture.capture_device_errors('ANDROID', 'ios'),
                             ['CAPTURE_PLATFORM_MISMATCH'])


if __name__ == '__main__':
    unittest.main()
