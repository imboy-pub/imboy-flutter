"""Unit tests for scripts/auto_test_lib/result.py (Step 3, ATF-202/203).

Covers: retry classification (FLAKY / INFRA_RETRY_EXHAUSTED / zero-retry
business FAIL / fingerprint isolation), unique-target planning with
conflict rejection, and §4.2 exit-code mapping.
"""

import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from auto_test_lib.machine_events import parse_machine_events  # noqa: E402
from auto_test_lib.result import (  # noqa: E402
    ATTEMPT_FINGERPRINT_KEYS,
    classify_attempts,
    overall_exit_code,
    plan_unique_targets,
)

FIXTURES = Path(__file__).resolve().parent / "fixtures" / "machine_events"


def load_lines(name):
    return (FIXTURES / name).read_text(encoding="utf-8").splitlines()


def parsed(name, exit_code=1):
    return parse_machine_events(load_lines(name), process_exit_code=exit_code).to_dict()


def fingerprint(**overrides):
    base = {
        "app_head": "a" * 40,
        "backend_head": "b" * 40,
        "target_sha256": "c" * 64,
        "config_sha256": "d" * 64,
        "fixture_fingerprint": "e" * 16,
        "device_fingerprint": "f" * 16,
    }
    base.update(overrides)
    return base


def attempt(parsed_dict, fp=None):
    return {"parsed": parsed_dict, "fingerprint": fp or fingerprint()}


PASS_PARSED = parsed("pass.jsonl", exit_code=0)
SKIPS_PARSED = parsed("pass_with_skips.jsonl", exit_code=0)
ALL_SKIP_PARSED = parsed("all_skip.jsonl", exit_code=0)
FAIL_PARSED = parsed("fail.jsonl", exit_code=1)
INFRA_PARSED = parsed("retry_infra_fail_1.jsonl", exit_code=1)


class ClassifyAttemptsTest(unittest.TestCase):
    def test_single_pass(self):
        verdict = classify_attempts([attempt(PASS_PARSED)])
        self.assertEqual(verdict["test_status"], "PASS")
        self.assertEqual(verdict["reason_code"], "NONE")

    def test_atf202_infra_then_pass_is_flaky_exit_2(self):
        verdict = classify_attempts([attempt(INFRA_PARSED), attempt(PASS_PARSED)])
        self.assertEqual(verdict["test_status"], "FLAKY")
        self.assertEqual(verdict["reason_code"], "INFRA_FAIL")
        self.assertEqual(overall_exit_code([verdict]), 2)

    def test_atf202_three_same_fingerprint_infra_fails_exhausted(self):
        verdict = classify_attempts([attempt(INFRA_PARSED)] * 3)
        self.assertEqual(verdict["test_status"], "BLOCKED")
        self.assertEqual(verdict["reason_code"], "INFRA_RETRY_EXHAUSTED")
        self.assertEqual(overall_exit_code([verdict]), 2)

    def test_two_infra_fails_still_retryable(self):
        verdict = classify_attempts([attempt(INFRA_PARSED)] * 2)
        self.assertEqual(verdict["test_status"], "BLOCKED")
        self.assertEqual(verdict["reason_code"], "INFRA_FAIL")

    def test_atf202_business_fail_zero_retry_even_with_more_attempts(self):
        verdict = classify_attempts(
            [attempt(FAIL_PARSED), attempt(PASS_PARSED), attempt(PASS_PARSED)]
        )
        self.assertEqual(verdict["test_status"], "FAIL")
        self.assertEqual(verdict["reason_code"], "BUSINESS_ASSERTION_FAIL")
        self.assertEqual(verdict["attempt_count"], 1)
        self.assertEqual(overall_exit_code([verdict]), 1)

    def test_fingerprint_change_must_not_merge(self):
        verdict = classify_attempts(
            [
                attempt(INFRA_PARSED, fingerprint()),
                attempt(PASS_PARSED, fingerprint(target_sha256="9" * 64)),
            ]
        )
        self.assertEqual(verdict["test_status"], "BLOCKED")
        self.assertEqual(verdict["reason_code"], "MULTIPLE_ATTEMPT_MERGE_INVALID")

    def test_fingerprint_change_on_device_field_rejected(self):
        verdict = classify_attempts(
            [
                attempt(INFRA_PARSED, fingerprint()),
                attempt(PASS_PARSED, fingerprint(device_fingerprint="zzz")),
            ]
        )
        self.assertEqual(verdict["reason_code"], "MULTIPLE_ATTEMPT_MERGE_INVALID")

    def test_single_all_skip_blocked(self):
        verdict = classify_attempts([attempt(ALL_SKIP_PARSED)])
        self.assertEqual(verdict["test_status"], "BLOCKED")
        self.assertEqual(verdict["reason_code"], "ALL_SKIPPED")

    def test_empty_attempts_blocked(self):
        verdict = classify_attempts([])
        self.assertEqual(verdict["test_status"], "BLOCKED")
        self.assertEqual(verdict["reason_code"], "ZERO_EXECUTED")

    def test_unbound_or_malformed_attempts_cannot_be_pass(self):
        invalid = [{"parsed": PASS_PARSED}, False,
                   {"parsed": PASS_PARSED, "fingerprint": {}}]
        for key in ATTEMPT_FINGERPRINT_KEYS:
            for value in (None, '', '  ', [], 123):
                invalid.append({"parsed": PASS_PARSED,
                                "fingerprint": fingerprint(**{key: value})})
        for item in invalid:
            with self.subTest(item=item):
                verdict = classify_attempts([item])
                self.assertEqual(verdict['test_status'], 'BLOCKED')
                self.assertEqual(verdict['reason_code'], 'ATTEMPT_FINGERPRINT_INVALID')

    def test_retry_fixtures_are_identical_for_infra_1_2_3(self):
        # The three retry_infra_fail fixtures reuse the same fingerprint
        # contract; distinct files must still classify identically.
        verdicts = [
            classify_attempts([attempt(parsed("retry_infra_fail_%d.jsonl" % i))])
            for i in (1, 2, 3)
        ]
        self.assertEqual(
            {v["reason_code"] for v in verdicts}, {"INFRA_FAIL"}
        )
        recovered = classify_attempts(
            [attempt(parsed("retry_pass_after_infra_1.jsonl", exit_code=0))]
        )
        self.assertEqual(recovered["test_status"], "PASS")


class PlanUniqueTargetsTest(unittest.TestCase):
    @staticmethod
    def spec(spec_id, target, risk="B", runner_type="flutter_test", requires=None):
        return {
            "id": spec_id,
            "risk": risk,
            "runner": {"type": runner_type, "target": target},
            "requires": list(requires or []),
        }

    def test_atf203_duplicate_target_same_attributes_planned_once(self):
        specs = [
            self.spec("s2", "integration_test/a_test.dart"),
            self.spec("s1", "integration_test/a_test.dart"),
            self.spec("s3", "integration_test/b_test.dart"),
        ]
        plan, conflicts = plan_unique_targets(specs)
        self.assertEqual(len(plan), 2)
        self.assertEqual([s["id"] for s in plan], ["s1", "s3"])
        self.assertEqual(conflicts, [])

    def test_requires_ordering_does_not_create_conflict(self):
        specs = [
            self.spec("s1", "t.dart", requires=["device.android", "backend.local"]),
            self.spec("s2", "t.dart", requires=["backend.local", "device.android"]),
        ]
        plan, conflicts = plan_unique_targets(specs)
        self.assertEqual(len(plan), 1)
        self.assertEqual(conflicts, [])

    def test_atf203_conflicting_risk_rejected_with_both_ids(self):
        specs = [
            self.spec("s1", "t.dart", risk="A"),
            self.spec("s2", "t.dart", risk="C"),
        ]
        plan, conflicts = plan_unique_targets(specs)
        self.assertEqual(len(plan), 1)
        self.assertEqual(plan[0]["id"], "s1")
        self.assertEqual(len(conflicts), 1)
        conflict = conflicts[0]
        self.assertEqual(conflict["target"], "t.dart")
        self.assertEqual(conflict["ids"], ["s1", "s2"])
        self.assertEqual(conflict["differences"][0]["field"], "risk")
        self.assertEqual(conflict["differences"][0]["values"], ["A", "C"])

    def test_conflicting_runner_type_rejected(self):
        specs = [
            self.spec("s1", "t.dart", runner_type="flutter_test"),
            self.spec("s2", "t.dart", runner_type="patrol"),
        ]
        _, conflicts = plan_unique_targets(specs)
        self.assertEqual(len(conflicts), 1)
        self.assertEqual(conflicts[0]["differences"][0]["field"], "runner.type")

    def test_conflicting_requires_rejected(self):
        specs = [
            self.spec("s1", "t.dart", requires=["device.android"]),
            self.spec("s2", "t.dart", requires=["device.android", "backend.local"]),
        ]
        _, conflicts = plan_unique_targets(specs)
        self.assertEqual(len(conflicts), 1)
        self.assertEqual(conflicts[0]["differences"][0]["field"], "requires")


class OverallExitCodeTest(unittest.TestCase):
    def test_all_pass_exit_0(self):
        self.assertEqual(
            overall_exit_code([{"test_status": "PASS"}, {"test_status": "PASS"}]), 0
        )

    def test_any_fail_exit_1(self):
        self.assertEqual(
            overall_exit_code([{"test_status": "PASS"}, {"test_status": "FAIL"}]), 1
        )

    def test_atf202_pass_with_skips_exit_2(self):
        self.assertEqual(overall_exit_code([{"test_status": SKIPS_PARSED["test_status"]}]), 2)
        self.assertEqual(overall_exit_code([SKIPS_PARSED]), 2)

    def test_atf201_all_skip_blocked_exit_2(self):
        self.assertEqual(overall_exit_code([ALL_SKIP_PARSED]), 2)

    def test_flaky_blocked_planned_exit_2(self):
        for status in ("FLAKY", "BLOCKED", "PLANNED", "PASS_WITH_SKIPS"):
            self.assertEqual(overall_exit_code([{"test_status": status}]), 2)
        self.assertEqual(
            overall_exit_code([{"test_status": "PASS"}, {"test_status": "FLAKY"}]), 2
        )

    def test_empty_results_exit_0(self):
        self.assertEqual(overall_exit_code([]), 0)

    def test_fixture_fixture_end_to_end_exit_codes(self):
        self.assertEqual(overall_exit_code([PASS_PARSED]), 0)
        self.assertEqual(overall_exit_code([FAIL_PARSED]), 1)
        self.assertEqual(overall_exit_code([INFRA_PARSED]), 2)


if __name__ == "__main__":
    unittest.main()
