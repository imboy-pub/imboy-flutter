#!/usr/bin/env python3
"""T04.c read-only state validator — imboy-enterprise-uiux-v1.

Verifies the live runtime state against the event log without mutating
anything: hash chain, strict revision sequence, snapshot/COMMIT agreement,
status/state vocabularies, and the STATE.example-must-not-replace-live rule.

Exit 0 = valid; 1 = INVALID (with reasons); 2 = usage error.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from plan_state import StateCorruption, StateStore, snapshot_hash  # noqa: E402

WORK_STATES = {"TODO", "READY", "RUNNING", "IMPLEMENTED", "COMMITTED",
               "INTEGRATED", "DONE", "BLOCKED", "SUPERSEDED_AGGREGATE", "REVERTED"}
VERIFICATION_STATES = {"NOT_RUN", "RUNNING", "PASS", "FAIL", "STALE",
                       "INCOMPLETE", "BLOCKED"}
MANUAL_STATES = {"NOT_APPLICABLE", "MANUAL_PENDING", "PASS", "FAIL"}


def default_runtime(cwd: str) -> str:
    p = subprocess.run(["git", "-C", cwd, "rev-parse", "--git-common-dir"],
                       capture_output=True, text=True)
    if p.returncode != 0:
        raise SystemExit(f"not a git worktree: {cwd}")
    common = p.stdout.strip()
    if not os.path.isabs(common):
        common = os.path.join(cwd, common)
    return os.path.join(common, "imboy-uiux", "imboy-enterprise-uiux-v1")


def validate(runtime: str, plan_id: str | None = None):
    problems = []
    store = StateStore(runtime, session_id="check-state-readonly")
    if not os.path.exists(store.state_path):
        return ["state.json missing (nothing to validate)"], None
    try:
        with open(store.state_path, encoding="utf-8") as f:
            state = json.load(f)
        events, quarantined = store.read_events()
    except StateCorruption as e:
        return [f"event log damage: {e}"], None
    except json.JSONDecodeError as e:
        return [f"state.json unreadable: {e}"], None

    commits = [e for e in events if e.get("event") == "COMMIT"]
    tail = events[-1] if events else None
    pending = tail if tail and tail.get("event") == "PREPARE" else None

    for idx, ev in enumerate(commits, start=1):
        if ev.get("revision") != idx:
            problems.append(f"revision conflict: COMMIT#{idx} has revision {ev.get('revision')}")
    if state.get("example_only") or state.get("status") == "NOT_INITIALIZED":
        if commits:
            problems.append("STATE.example content cannot replace a live state "
                            f"with {len(commits)} COMMITs")

    h = snapshot_hash(state)
    if commits:
        last = commits[-1]
        if h != last.get("snapshot_hash"):
            if pending and h == pending.get("next_snapshot_hash"):
                problems.append(f"state_commit_missing_not_pass: snapshot for "
                                f"{pending['txid']} has no COMMIT; not accepted")
            elif pending and h == pending.get("previous_snapshot_hash"):
                problems.append(f"state_prepare_without_snapshot_not_accepted: "
                                f"{pending['txid']} uncommitted (state stays at "
                                f"revision {last.get('revision')})")
            else:
                problems.append("state.json hash matches neither last COMMIT "
                                "nor any pending snapshot")
    elif h != snapshot_hash(state):
        problems.append("unreachable")

    if plan_id and state.get("plan_id") not in (None, plan_id):
        problems.append(f"plan_id mismatch: {state.get('plan_id')} != {plan_id}")

    for key, vocab in (("work_state", WORK_STATES),
                       ("verification_state", VERIFICATION_STATES),
                       ("manual_state", MANUAL_STATES)):
        for tid, task in (state.get("tasks") or {}).items():
            val = task.get(key)
            if val is not None and val not in vocab:
                problems.append(f"{tid}.{key}={val!r} not in vocabulary {sorted(vocab)}")

    report = {"runtime": runtime, "revision": state.get("revision"),
              "last_txid": state.get("last_txid"),
              "commits": len(commits), "quarantined": quarantined,
              "tasks": len(state.get("tasks") or {})}
    return problems, report


def main():
    ap = argparse.ArgumentParser(description="read-only runtime state validator")
    ap.add_argument("--plan-id", default=None)
    ap.add_argument("--runtime", default=None,
                    help="runtime dir override (tests); default resolves from cwd repo")
    args = ap.parse_args()
    runtime = args.runtime or default_runtime(os.getcwd())
    if not os.path.isdir(runtime):
        print(json.dumps({"valid": False, "problems": [f"runtime dir not found: {runtime}"]}))
        return 1
    problems, report = validate(runtime, args.plan_id)
    print(json.dumps({"valid": not problems, "problems": problems, "report": report},
                     ensure_ascii=False, indent=1))
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main())
