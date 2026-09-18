"""Unit tests for scripts/auto_test_lib/machine_events.py (Step 3, ATF-201/202).

Fixture-driven: all fixtures live in
test/tooling/auto_test/fixtures/machine_events/*.jsonl (anonymous, hand
written for negative edges) plus derived_real_flutter_test.jsonl derived
from real local `flutter test --machine` output.
"""

import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from auto_test_lib.machine_events import parse_machine_events  # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures" / "machine_events"


def load_lines(name):
    return (FIXTURES / name).read_text(encoding="utf-8").splitlines()


class ParseMachineEventsTest(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
