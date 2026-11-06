"""Unit tests for scripts/auto_test_lib/machine_events.py (Step 3, ATF-201/202).

Fixture-driven: all fixtures live in
test/tooling/auto_test/fixtures/machine_events/*.jsonl (anonymous, hand
written for negative edges) plus derived_real_flutter_test.jsonl derived
from real local `flutter test --machine` output.
"""

import json
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from auto_test_lib.machine_events import parse_machine_events  # noqa: E402
from auto_test_lib.result import ATTEMPT_FINGERPRINT_KEYS, classify_attempts  # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures" / "machine_events"


def load_lines(name):
    return (FIXTURES / name).read_text(encoding="utf-8").splitlines()


class ParseMachineEventsTest(unittest.TestCase):
    def test_visible_success_without_done_is_still_runner_crash(self):
        lines = ['{"type":"testDone","testID":1,"result":"success"}']
        parsed = parse_machine_events(lines, 0)
        self.assertEqual(parsed.test_status, 'BLOCKED')
        self.assertEqual(parsed.reason_code, 'RUNNER_CRASH')

    def test_skipped_flag_cannot_hide_a_failed_result(self):
        lines = [
            '{"type":"testDone","testID":1,"result":"failure",'
            '"skipped":true}',
            '{"type":"done","success":true}',
        ]
        self.assertEqual(parse_machine_events(lines, 0).test_status, 'FAIL')

    def test_current_reporter_skipped_success_is_not_pass(self):
        lines = [
            '{"type":"testDone","testID":1,"result":"success",'
            '"hidden":false,"skipped":true}',
            '{"type":"done","success":true}',
        ]
        result = parse_machine_events(lines, process_exit_code=0)
        self.assertEqual(result.skipped, 1)
        self.assertEqual(result.test_status, 'BLOCKED')
        self.assertEqual(result.reason_code, 'ALL_SKIPPED')

    def test_current_reporter_mixed_skip_cannot_be_full_pass(self):
        lines = [
            '{"type":"testDone","testID":1,"result":"success",'
            '"hidden":false,"skipped":true}',
            '{"type":"testDone","testID":2,"result":"success",'
            '"hidden":false,"skipped":false}',
            '{"type":"done","success":true}',
        ]
        result = parse_machine_events(lines, process_exit_code=0)
        self.assertEqual(result.test_status, 'PASS_WITH_SKIPS')
        self.assertEqual(result.skipped, 1)

    def test_done_reports_failure_even_when_visible_test_succeeded(self):
        lines = [
            '{"type":"testDone","testID":1,"result":"success"}',
            '{"type":"done","success":false}',
        ]
        self.assertEqual(parse_machine_events(lines, 0).test_status, 'FAIL')

    def test_done_null_is_an_interrupted_runner_not_a_pass(self):
        lines = [
            '{"type":"testDone","testID":1,"result":"success"}',
            '{"type":"done","success":null}',
        ]
        parsed = parse_machine_events(lines, 0)
        self.assertEqual(parsed.test_status, 'BLOCKED')
        self.assertEqual(parsed.reason_code, 'RUNNER_CRASH')

    def test_pass_fixture_maps_pass(self):
        result = parse_machine_events(load_lines("pass.jsonl"), process_exit_code=0)
        self.assertEqual(result.test_status, "PASS")
        self.assertEqual(result.reason_code, "NONE")
        self.assertEqual(result.executed, 2)
        self.assertEqual(result.skipped, 0)
        self.assertEqual(result.failed, 0)
        self.assertEqual(result.oracle_count, 2)
        self.assertTrue(result.done_event_seen)

    def test_pass_with_skips_maps_pass_with_skips(self):
        result = parse_machine_events(load_lines("pass_with_skips.jsonl"), process_exit_code=0)
        self.assertEqual(result.test_status, "PASS_WITH_SKIPS")
        self.assertEqual(result.executed, 2)
        self.assertEqual(result.skipped, 1)
        self.assertEqual(result.failed, 0)
        self.assertEqual(result.oracle_count, 1)

    def test_atf201_all_skip_with_exit_zero_is_blocked(self):
        # ATF-201: all SKIP + process exit 0 must never be PASS.
        result = parse_machine_events(load_lines("all_skip.jsonl"), process_exit_code=0)
        self.assertEqual(result.test_status, "BLOCKED")
        self.assertEqual(result.reason_code, "ALL_SKIPPED")
        self.assertGreater(result.executed, 0)
        self.assertEqual(result.skipped, result.executed)
        self.assertEqual(result.failed, 0)

    def test_business_assertion_fail(self):
        result = parse_machine_events(load_lines("fail.jsonl"), process_exit_code=1)
        self.assertEqual(result.test_status, "FAIL")
        self.assertEqual(result.reason_code, "BUSINESS_ASSERTION_FAIL")
        self.assertEqual(result.failure_class, "business")
        self.assertEqual(result.failed, 1)
        self.assertEqual(result.first_failure.test_id, 3)
        self.assertTrue(result.first_failure.is_failure)
        self.assertIn("Expected", result.first_failure.message)

    def test_native_flutter_error_retains_the_actual_assertion_text(self):
        # Shape and diagnostic from PR CI: Flutter emits "error", not "message".
        message = ("Expected: GoldenFontStatus:<GoldenFontStatus.ok>\n"
                   "  Actual: GoldenFontStatus:<GoldenFontStatus.visualBlocked>\n")
        events = [
            {"type": "testStart", "test": {"id": 805, "name": "font contract"}},
            {"type": "error", "testID": 805, "error": message,
             "isFailure": True, "stackTrace": "font_contract_test.dart 26:5"},
            {"type": "testDone", "testID": 805, "result": "failure", "skipped": False},
            {"type": "done", "success": False},
        ]
        result = parse_machine_events([json.dumps(event) for event in events], 1)
        self.assertEqual(result.first_failure.message, message)
        self.assertEqual(result.first_failure.name, "font contract")
        self.assertEqual(result.first_failure.test_id, 805)
        self.assertEqual(result.reason_code, "BUSINESS_ASSERTION_FAIL")
        self.assertEqual(result.failure_class, "business")
        self.assertEqual((result.failed, result.passed, result.skipped), (1, 0, 0))

    def test_native_error_text_takes_precedence_over_legacy_message(self):
        lines = [
            json.dumps({"type": "error", "testID": 1, "error": "native assertion",
                        "message": "legacy diagnostic", "isFailure": True}),
            '{"type":"testDone","testID":1,"result":"failure"}',
            '{"type":"done","success":false}',
        ]
        self.assertEqual(parse_machine_events(lines, 1).first_failure.message,
                         "native assertion")

    def test_unusable_native_error_falls_back_to_legacy_message(self):
        for native in (None, "", "  \n", False, 123, {}, []):
            with self.subTest(native=native):
                lines = [
                    json.dumps({"type": "error", "testID": 1, "error": native,
                                "message": "legacy assertion", "isFailure": True}),
                    '{"type":"testDone","testID":1,"result":"failure"}',
                    '{"type":"done","success":false}',
                ]
                self.assertEqual(parse_machine_events(lines, 1).first_failure.message,
                                 "legacy assertion")

    def test_error_field_alias_preserves_exit_skip_and_retry_contracts(self):
        def parse_with_native_key(name, exit_code):
            events = [json.loads(line) for line in load_lines(name)]
            for event in events:
                if event.get("type") == "error" and "message" in event:
                    event["error"] = event.pop("message")
            return parse_machine_events([json.dumps(event) for event in events], exit_code).to_dict()

        for fixture, exit_code in (("fail.jsonl", 1), ("retry_infra_fail_1.jsonl", 1),
                                   ("runner_crash.jsonl", 255), ("pass.jsonl", 139),
                                   ("all_skip.jsonl", 0), ("pass_with_skips.jsonl", 0)):
            with self.subTest(fixture=fixture):
                expected = parse_machine_events(load_lines(fixture), exit_code).to_dict()
                self.assertEqual(parse_with_native_key(fixture, exit_code), expected)

        fingerprint = dict.fromkeys(ATTEMPT_FINGERPRINT_KEYS, "synthetic-fingerprint")
        passed = {"parsed": parse_machine_events(load_lines("pass.jsonl"), 0).to_dict(),
                  "fingerprint": fingerprint}
        for fixture, status, reason, attempts in (
                ("fail.jsonl", "FAIL", "BUSINESS_ASSERTION_FAIL", 1),
                ("retry_infra_fail_1.jsonl", "FLAKY", "INFRA_FAIL", 2)):
            with self.subTest(retry=fixture):
                first = {"parsed": parse_with_native_key(fixture, 1), "fingerprint": fingerprint}
                verdict = classify_attempts([first, passed])
                self.assertEqual((verdict["test_status"], verdict["reason_code"],
                                  verdict["attempt_count"]), (status, reason, attempts))

    def test_infra_fail_is_blocked_retryable(self):
        result = parse_machine_events(load_lines("retry_infra_fail_1.jsonl"), process_exit_code=1)
        self.assertEqual(result.test_status, "BLOCKED")
        self.assertEqual(result.reason_code, "INFRA_FAIL")
        self.assertEqual(result.failure_class, "infra")

    def test_runner_crash(self):
        result = parse_machine_events(load_lines("runner_crash.jsonl"), process_exit_code=255)
        self.assertEqual(result.test_status, "BLOCKED")
        self.assertEqual(result.reason_code, "RUNNER_CRASH")
        self.assertEqual(result.failure_class, "infra")
        self.assertEqual(result.executed, 0)
        self.assertFalse(result.done_event_seen)

    def test_zero_executed_with_done_is_blocked(self):
        lines = [
            '{"time":1,"type":"start","protocolVersion":"0.12.0"}',
            '{"time":2,"type":"suite","suite":{"id":0,"platform":"vm","path":"x.dart"}}',
            '{"time":3,"type":"testStart","test":{"id":1,"name":"loading x.dart"}}',
            '{"time":4,"type":"testDone","testID":1,"result":"success","hidden":true}',
            '{"time":5,"type":"done","success":true}',
        ]
        result = parse_machine_events(lines, process_exit_code=0)
        self.assertEqual(result.test_status, "BLOCKED")
        self.assertEqual(result.reason_code, "ZERO_EXECUTED")
        self.assertEqual(result.executed, 0)

    def test_malformed_lines_counted_and_unknown_types_skipped(self):
        lines = [
            "not-json{",
            '{"type":"comment","note":"unknown type must be ignored"}',
            '{"time":1,"type":"testStart","test":{"id":2,"name":"t"}}',
            '{"time":2,"type":"testDone","testID":2,"result":"success","hidden":false}',
            '{"time":3,"type":"done","success":true}',
        ]
        result = parse_machine_events(lines, process_exit_code=0)
        self.assertEqual(result.malformed_lines, 1)
        self.assertEqual(result.test_status, "PASS")
        self.assertEqual(result.executed, 1)

    def test_all_malformed_without_done_is_runner_crash(self):
        result = parse_machine_events(["garbage1", "{broken"], process_exit_code=1)
        self.assertEqual(result.test_status, "BLOCKED")
        self.assertEqual(result.reason_code, "RUNNER_CRASH")
        self.assertEqual(result.malformed_lines, 2)

    def test_oracle_from_expect_in_error_stack(self):
        lines = [
            '{"time":1,"type":"testStart","test":{"id":2,"name":"t"}}',
            '{"time":2,"type":"error","testID":2,"result":"error",'
            '"message":"boom","isFailure":true,"stackTrace":"main expect(found, isTrue) frame"}',
            '{"time":3,"type":"testDone","testID":2,"result":"failure","hidden":false}',
            '{"time":4,"type":"done","success":false}',
        ]
        result = parse_machine_events(lines, process_exit_code=1)
        self.assertEqual(result.test_status, "FAIL")
        self.assertEqual(result.oracle_count, 1)

    def test_first_failure_name_resolved_from_test_start(self):
        result = parse_machine_events(load_lines("fail.jsonl"), process_exit_code=1)
        self.assertIn("failing assertion", result.first_failure.name)
        self.assertEqual(result.first_failure.to_dict()["test_id"], 3)

    def test_parsed_result_to_dict_is_json_serializable(self):
        import json

        result = parse_machine_events(load_lines("fail.jsonl"), process_exit_code=1)
        payload = json.dumps(result.to_dict())
        self.assertIn("BUSINESS_ASSERTION_FAIL", payload)


class DerivedRealFixtureTest(unittest.TestCase):
    def test_derived_real_flutter_test_output_parses_with_executed(self):
        path = FIXTURES / "derived_real_flutter_test.jsonl"
        if not path.exists():
            self.skipTest("derived_real_flutter_test.jsonl not generated yet")
        result = parse_machine_events(path.read_text(encoding="utf-8").splitlines())
        self.assertGreaterEqual(
            result.executed,
            1,
            "real flutter --machine fixture must contain visible testDone events",
        )
        self.assertIn(result.test_status, ("PASS", "PASS_WITH_SKIPS"))


class MachineEvidenceIntegrityTest(unittest.TestCase):
    def test_nonzero_exit_is_not_success_even_with_complete_green_events(self):
        result = parse_machine_events(load_lines('pass.jsonl'), 139)
        self.assertEqual(result.test_status, 'BLOCKED')
        self.assertEqual(result.reason_code, 'PROCESS_EXIT_NONZERO')

    def test_duplicate_terminal_event_cannot_inflate_execution(self):
        lines = load_lines('pass.jsonl')
        lines.insert(-1, '{"type":"testDone","testID":3,"result":"success"}')
        result = parse_machine_events(lines, 0)
        self.assertEqual(result.executed, 2)
        self.assertEqual(result.reason_code, 'INVALID_MACHINE_EVENTS')

    def test_started_test_without_completion_is_incomplete_even_with_done_true(self):
        lines = load_lines('pass.jsonl')
        lines.insert(-1, '{"type":"testStart","test":{"id":99,"name":"unfinished"}}')
        self.assertEqual(parse_machine_events(lines, 0).reason_code, 'INVALID_MACHINE_EVENTS')

    def test_truncated_event_cannot_be_treated_as_an_ordinary_banner(self):
        lines = load_lines('pass.jsonl')
        lines.insert(-1, '{"type":"testDone"')
        self.assertEqual(parse_machine_events(lines, 0).reason_code, 'INVALID_MACHINE_EVENTS')

    def test_assertion_followed_by_runner_crash_is_terminal_business_failure(self):
        lines = [line for line in load_lines('fail.jsonl') if '"type": "done"' not in line]
        result = parse_machine_events(lines, 137)
        self.assertEqual(result.test_status, 'FAIL')
        self.assertEqual(result.failure_class, 'business')

    def test_unknown_error_cannot_hide_behind_successful_terminal_events(self):
        lines = load_lines('pass.jsonl')
        lines.insert(-1, '{"type":"error","message":"unexpected error","isFailure":false}')
        self.assertEqual(parse_machine_events(lines, 0).test_status, 'FAIL')

    def test_global_failure_does_not_invent_a_failed_case_in_this_suite(self):
        lines = load_lines('pass.jsonl')
        lines[-1] = '{"type":"done","success":false}'
        result = parse_machine_events(lines, 1)
        self.assertEqual(result.test_status, 'FAIL')
        self.assertEqual(result.failed, 0)
        self.assertEqual(result.passed, 2)
        self.assertEqual(result.reason_code, 'RUNNER_REPORTED_FAILURE')

    def test_duplicate_done_event_is_invalid(self):
        result = parse_machine_events(load_lines('pass.jsonl') + ['{"type":"done","success":true}'], 0)
        self.assertEqual(result.reason_code, 'INVALID_MACHINE_EVENTS')

    def test_executed_and_actually_run_have_distinct_skip_semantics(self):
        result = parse_machine_events(load_lines('pass_with_skips.jsonl'), 0)
        self.assertEqual(result.executed, 2)
        self.assertEqual(result.actually_run, 1)
        self.assertEqual(result.passed, 1)
        self.assertEqual(result.to_dict()['actually_run'], 1)


if __name__ == "__main__":
    unittest.main()
