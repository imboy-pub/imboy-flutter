"""Unique-target planning, retry classification and exit-code mapping.

Source of truth: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md
Step 3 (trusted result & unique target) and section 4 (status/exit-code
contract). Python 3.9 stdlib only.

Public API:
- plan_unique_targets(specs)   -> (plan, conflicts)
- classify_attempts(attempts)  -> dict
- overall_exit_code(results)   -> int
"""

from __future__ import annotations

import json
from typing import Any, Dict, List, Sequence, Tuple

#: Fingerprint fields binding an attempt sequence together. Any change of
#: these between attempts means a NEW sequence must be started; merging such
#: attempts is invalid (MULTIPLE_ATTEMPT_MERGE_INVALID).
ATTEMPT_FINGERPRINT_KEYS: Tuple[str, ...] = (
    "app_head",
    "backend_head",
    "target_sha256",
    "config_sha256",
    "fixture_fingerprint",
    "device_fingerprint",
)

#: How many consecutive same-fingerprint infrastructure failures exhaust
#: the retry budget (Step 3 retry contract).
INFRA_RETRY_LIMIT = 3

#: Statuses counted as "the target finally succeeded".
_SUCCESS_STATUSES = ("PASS", "PASS_WITH_SKIPS")

#: Retryable infrastructure reason codes.
_INFRA_REASON_CODES = ("INFRA_FAIL", "RUNNER_CRASH")


def _spec_target(spec: Dict[str, Any]) -> str:
    runner = spec.get("runner")
    if isinstance(runner, dict):
        target = runner.get("target")
        if isinstance(target, str) and target:
            return target
    return ""


def _requires_key(spec: Dict[str, Any]) -> Tuple[str, ...]:
    requires = spec.get("requires")
    if not isinstance(requires, list):
        return ()
    parts = []
    for item in requires:
        if isinstance(item, str):
            parts.append(item)
        else:
            parts.append(json.dumps(item, sort_keys=True, ensure_ascii=False))
    return tuple(sorted(parts))


def _attribute_diffs(a: Dict[str, Any], b: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Compare the safety attributes that must agree for one target."""
    diffs: List[Dict[str, Any]] = []
    if a.get("risk") != b.get("risk"):
        diffs.append({"field": "risk", "values": [a.get("risk"), b.get("risk")]})
    a_type = (a.get("runner") or {}).get("type")
    b_type = (b.get("runner") or {}).get("type")
    if a_type != b_type:
        diffs.append(
            {"field": "runner.type", "values": [a_type, b_type]}
        )
    a_requires = _requires_key(a)
    b_requires = _requires_key(b)
    if a_requires != b_requires:
        diffs.append(
            {"field": "requires", "values": [list(a_requires), list(b_requires)]}
        )
    return diffs


def plan_unique_targets(
    specs: Sequence[Dict[str, Any]],
) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    """Deduplicate specs by ``runner.target`` for one execution plan.

    Returns ``(plan, conflicts)``:
    - plan: at most one spec per target; for duplicated targets the first
      spec in (target, id) sorted order is kept.
    - conflicts: one entry per rejected duplicate whose safety attributes
      (risk / runner.type / requires set) disagree with the kept spec;
      each entry carries both ids and the differing fields.
    Exact duplicates (all safety attributes equal) are collapsed silently
    because they execute the same target with the same contract.
    """
    ordered = sorted(
        enumerate(specs),
        key=lambda pair: (_spec_target(pair[1]), str(pair[1].get("id", "")), pair[0]),
    )
    plan: List[Dict[str, Any]] = []
    conflicts: List[Dict[str, Any]] = []
    kept_by_target: Dict[str, Dict[str, Any]] = {}
    for _, spec in ordered:
        target = _spec_target(spec)
        kept = kept_by_target.get(target)
        if kept is None:
            kept_by_target[target] = spec
            plan.append(spec)
            continue
        diffs = _attribute_diffs(kept, spec)
        if diffs:
            conflicts.append(
                {
                    "target": target,
                    "ids": [kept.get("id"), spec.get("id")],
                    "differences": diffs,
                }
            )
    return plan, conflicts


def _attempt_fingerprint(attempt: Dict[str, Any]) -> Tuple[Any, ...]:
    fingerprint = attempt.get("fingerprint")
    if not isinstance(fingerprint, dict):
        fingerprint = {}
    return tuple(fingerprint.get(key) for key in ATTEMPT_FINGERPRINT_KEYS)


def _attempt_parsed(attempt: Dict[str, Any]) -> Dict[str, Any]:
    parsed = attempt.get("parsed")
    if not isinstance(parsed, dict):
        return {}
    return parsed


def _is_infra_attempt(parsed: Dict[str, Any]) -> bool:
    if parsed.get("reason_code") in _INFRA_REASON_CODES:
        return True
    return parsed.get("failure_class") == "infra"


def classify_attempts(attempts: Sequence[Dict[str, Any]]) -> Dict[str, Any]:
    """Fold one same-fingerprint retry sequence into a single verdict.

    Each attempt must carry:
    - ``parsed``: serializable ParsedResult fields (see machine_events);
    - ``fingerprint``: the six ATTEMPT_FINGERPRINT_KEYS values.

    Rules (Step 3 retry contract):
    - mixed fingerprints => BLOCKED / MULTIPLE_ATTEMPT_MERGE_INVALID
      (a fingerprint change must open a new sequence, never be merged);
    - any business FAIL => FAIL immediately, zero retry;
    - INFRA_FAIL followed by PASS/FAIL in the same sequence => FLAKY;
    - 3 consecutive same-fingerprint INFRA_FAIL => BLOCKED /
      INFRA_RETRY_EXHAUSTED.
    """
    attempt_list = list(attempts)
    attempt_count = len(attempt_list)
    if attempt_count == 0:
        return {
            "test_status": "BLOCKED",
            "reason_code": "ZERO_EXECUTED",
            "attempt_count": 0,
        }

    fingerprints = [_attempt_fingerprint(attempt) for attempt in attempt_list]
    if len(set(fingerprints)) != 1:
        return {
            "test_status": "BLOCKED",
            "reason_code": "MULTIPLE_ATTEMPT_MERGE_INVALID",
            "attempt_count": attempt_count,
        }

    parsed_list = [_attempt_parsed(attempt) for attempt in attempt_list]

    # Business assertion failure: zero retry, verdict settled at first FAIL.
    for index, parsed in enumerate(parsed_list):
        if parsed.get("test_status") == "FAIL":
            return {
                "test_status": "FAIL",
                "reason_code": parsed.get("reason_code") or "BUSINESS_ASSERTION_FAIL",
                "attempt_count": index + 1,
            }

    # Success after a retryable infra failure => FLAKY (all attempts kept).
    first_success = next(
        (
            index
            for index, parsed in enumerate(parsed_list)
            if parsed.get("test_status") in _SUCCESS_STATUSES
        ),
        None,
    )
    if first_success is not None:
        if any(_is_infra_attempt(parsed) for parsed in parsed_list[:first_success]):
            return {
                "test_status": "FLAKY",
                "reason_code": "INFRA_FAIL",
                "attempt_count": attempt_count,
            }
        parsed = parsed_list[first_success]
        return {
            "test_status": parsed.get("test_status", "BLOCKED"),
            "reason_code": parsed.get("reason_code", "NONE"),
            "attempt_count": first_success + 1,
        }

    # No success at all: count the leading run of retryable infra attempts.
    infra_run = 0
    for parsed in parsed_list:
        if _is_infra_attempt(parsed):
            infra_run += 1
        else:
            break
    if infra_run >= INFRA_RETRY_LIMIT:
        return {
            "test_status": "BLOCKED",
            "reason_code": "INFRA_RETRY_EXHAUSTED",
            "attempt_count": attempt_count,
        }
    if infra_run == attempt_count:
        # Retryable infra failure with budget left; caller may retry again.
        return {
            "test_status": "BLOCKED",
            "reason_code": "INFRA_FAIL",
            "attempt_count": attempt_count,
        }

    # Non-retryable non-success tail (ALL_SKIPPED / ZERO_EXECUTED / ...).
    parsed = parsed_list[-1]
    return {
        "test_status": parsed.get("test_status", "BLOCKED"),
        "reason_code": parsed.get("reason_code", "NONE"),
        "attempt_count": attempt_count,
    }


def overall_exit_code(results: Sequence[Dict[str, Any]]) -> int:
    """Map per-target statuses to the plan §4.2 process exit code.

    0 = every target PASS; 1 = at least one FAIL; 2 = no FAIL but any
    PASS_WITH_SKIPS / FLAKY / BLOCKED / PLANNED (or unknown status).
    """
    statuses = [str(result.get("test_status", "")) for result in results]
    if not statuses:
        return 0
    if any(status == "FAIL" for status in statuses):
        return 1
    if all(status == "PASS" for status in statuses):
        return 0
    return 2
