"""Parse ``flutter test --machine`` JSONL output into a trusted result.

Source of truth for the rules implemented here:
- docs/plans/2026-09-18-auto-test-framework-hardening-plan.md, Step 3 and
  section 4 (status / exit-code / evidence contract);
- test/tooling/auto_test/fixtures/interfaces/wave1_contracts.json,
  node ``machine_event_parser``.

Key invariants (mirrored from the contract):
- ``executed`` counts only non-hidden ``testDone`` events (the hidden
  "loading" pseudo-test is excluded); a ``testDone`` with
  ``result == "skipped"`` counts into both ``executed`` and ``skipped``.
- ``executed == 0`` can never map to PASS, regardless of process exit code.
- A business assertion failure (``error`` with ``isFailure == true`` or a
  ``testDone`` with ``result == "failure"``) maps to FAIL /
  BUSINESS_ASSERTION_FAIL (failure_class=business, zero retry upstream).
- A retryable infrastructure failure (``error`` with ``isFailure == false``
  whose message matches the infra pattern) maps to BLOCKED / INFRA_FAIL
  (failure_class=infra).
- No visible ``testDone`` and no ``done`` event means the runner died
  before/at loading: BLOCKED / RUNNER_CRASH (failure_class=infra).
- Lines that fail JSON parsing are skipped and counted in
  ``malformed_lines``; unknown event types (e.g. ``type=comment``) are
  ignored silently.

Python 3.9 stdlib only.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Sequence

#: Oracle marker on ``print`` events ("oracle:" / "oracle " / "oracle\t").
ORACLE_PRINT_RE = re.compile(r"oracle[:\s]")

#: Assertion-oracle marker searched in error messages and stack traces.
ORACLE_ERROR_MARKER = "expect("

#: Messages that classify a non-failure error as retryable infrastructure.
INFRA_MESSAGE_RE = re.compile(
    r"Timeout|transport|connection|adb|dart vm service", re.IGNORECASE
)

#: testDone results counted as failures.
FAILED_RESULTS = ("failure", "error")


@dataclass
class FirstFailure:
    """First failing evidence found in the event stream (if any)."""

    test_id: Optional[int] = None
    name: Optional[str] = None
    message: Optional[str] = None
    is_failure: Optional[bool] = None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "test_id": self.test_id,
            "name": self.name,
            "message": self.message,
            "is_failure": self.is_failure,
        }


@dataclass
class ParsedResult:
    """Structured outcome of one ``flutter test --machine`` process run."""

    test_status: str = "BLOCKED"
    executed: int = 0
    skipped: int = 0
    failed: int = 0
    oracle_count: int = 0
    reason_code: str = "NONE"
    failure_class: str = "unknown"
    first_failure: FirstFailure = field(default_factory=FirstFailure)
    malformed_lines: int = 0
    done_event_seen: bool = False
    process_exit_code: Optional[int] = None

    def to_dict(self) -> Dict[str, Any]:
        """Serializable view used by result.classify_attempts and evidence."""
        return {
            "test_status": self.test_status,
            "executed": self.executed,
            "skipped": self.skipped,
            "failed": self.failed,
            "oracle_count": self.oracle_count,
            "reason_code": self.reason_code,
            "failure_class": self.failure_class,
            "first_failure": self.first_failure.to_dict(),
            "malformed_lines": self.malformed_lines,
            "done_event_seen": self.done_event_seen,
            "process_exit_code": self.process_exit_code,
        }


def _as_int(value: Any) -> Optional[int]:
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    return None


def parse_machine_events(
    lines: Sequence[str],
    process_exit_code: Optional[int] = None,
    process_stderr_tail: Optional[str] = None,
) -> ParsedResult:
    """Parse machine-event lines (one JSON object per line) into ParsedResult.

    ``process_exit_code`` and ``process_stderr_tail`` are recorded for
    evidence only; classification itself is driven by the event stream so
    PASS is never inferred from exit codes or log keywords.
    """
    executed = 0
    skipped = 0
    failed = 0
    oracle_count = 0
    malformed_lines = 0
    done_event_seen = False
    business_fail = False
    infra_fail = False
    first_failure = FirstFailure()
    test_names: Dict[int, str] = {}

    def record_first_failure(
        test_id: Optional[int],
        message: Optional[str],
        is_failure: Optional[bool],
    ) -> None:
        # Keeps the earliest failing evidence in stream order.
        if first_failure.test_id is not None or first_failure.message is not None:
            return
        first_failure.test_id = test_id
        first_failure.name = test_names.get(test_id) if test_id is not None else None
        first_failure.message = message
        first_failure.is_failure = is_failure

    for raw in lines:
        if not isinstance(raw, str):
            malformed_lines += 1
            continue
        text = raw.strip()
        if not text:
            continue
        try:
            event = json.loads(text)
        except (ValueError, TypeError):
            malformed_lines += 1
            continue
        if not isinstance(event, dict):
            malformed_lines += 1
            continue

        etype = event.get("type")
        if etype == "testStart":
            test = event.get("test")
            if isinstance(test, dict):
                test_id = _as_int(test.get("id"))
                if test_id is not None:
                    name = test.get("name")
                    test_names[test_id] = name if isinstance(name, str) else ""
        elif etype == "testDone":
            if bool(event.get("hidden", False)):
                continue  # hidden loading pseudo-tests never count
            executed += 1
            result = event.get("result")
            if result == "skipped":
                skipped += 1
            elif result in FAILED_RESULTS:
                failed += 1
                if result == "failure":
                    business_fail = True
                record_first_failure(_as_int(event.get("testID")), None, None)
        elif etype == "print":
            message = event.get("message")
            if isinstance(message, str) and ORACLE_PRINT_RE.search(message):
                oracle_count += 1
        elif etype == "error":
            message = event.get("message")
            stack = event.get("stackTrace")
            message_text = message if isinstance(message, str) else ""
            stack_text = stack if isinstance(stack, str) else ""
            if ORACLE_ERROR_MARKER in message_text or ORACLE_ERROR_MARKER in stack_text:
                oracle_count += 1
            is_failure = event.get("isFailure")
            if is_failure is True:
                business_fail = True
            elif is_failure is False and INFRA_MESSAGE_RE.search(message_text):
                infra_fail = True
            record_first_failure(
                _as_int(event.get("testID")),
                message_text or None,
                is_failure if isinstance(is_failure, bool) else None,
            )
        elif etype == "done":
            done_event_seen = True
        # start / suite and unknown types (e.g. type=comment) are ignored.

    # reason_code decision order (see Step 3 contract); statuses map from §4.1.
    if executed == 0 and not done_event_seen:
        reason_code = "RUNNER_CRASH"
        failure_class = "infra"
        test_status = "BLOCKED"
    elif executed > 0 and skipped == executed:
        reason_code = "ALL_SKIPPED"
        failure_class = "unknown"
        test_status = "BLOCKED"
    elif executed == 0:
        reason_code = "ZERO_EXECUTED"
        failure_class = "unknown"
        test_status = "BLOCKED"
    elif business_fail:
        reason_code = "BUSINESS_ASSERTION_FAIL"
        failure_class = "business"
        test_status = "FAIL"
    elif infra_fail:
        reason_code = "INFRA_FAIL"
        failure_class = "infra"
        test_status = "BLOCKED"
    elif failed > 0:
        # Failing testDone without a recognisable business/infra marker:
        # still a terminal failure, class unknown (never PASS, never silent).
        reason_code = "BUSINESS_ASSERTION_FAIL"
        failure_class = "unknown"
        test_status = "FAIL"
    elif skipped > 0:
        reason_code = "NONE"
        failure_class = "unknown"
        test_status = "PASS_WITH_SKIPS"
    else:
        reason_code = "NONE"
        failure_class = "unknown"
        test_status = "PASS"

    return ParsedResult(
        test_status=test_status,
        executed=executed,
        skipped=skipped,
        failed=failed,
        oracle_count=oracle_count,
        reason_code=reason_code,
        failure_class=failure_class,
        first_failure=first_failure,
        malformed_lines=malformed_lines,
        done_event_seen=done_event_seen,
        process_exit_code=process_exit_code,
    )
