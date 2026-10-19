#!/usr/bin/env python3
"""T04.c contract self-test for plan_state/check_state (temp runtime dirs only).

Required assertions:
  state_prepare_without_snapshot_not_accepted
  state_snapshot_without_commit_reconciled_once
  state_torn_last_event_quarantined
  state_revision_conflict_rejected
  state_example_cannot_replace_live
  state_status_enum_complete
  state_commit_missing_not_pass

The real imboyapp runtime is never touched.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import plan_state  # noqa: E402
from plan_state import StateCorruption, StateStore, snapshot_hash  # noqa: E402

CHECK_STATE = os.path.join(HERE, "check_state.py")
CASES = []

def case(fn):
    CASES.append(fn)
    return fn

def runtime():
    d = tempfile.mkdtemp(prefix="uiux-state-case-")
    os.makedirs(os.path.join(d, "locks"), exist_ok=True)
    os.makedirs(os.path.join(d, "recovery", "backups"), exist_ok=True)
    return d

def bump_note(state):
    state.setdefault("notes", []).append("bump")
    return state

def seed(store, n=1):
    for i in range(n):
        store.transact(bump_note, change=f"seed {i + 1}")

@case
def state_prepare_without_snapshot_not_accepted():
    d = runtime()
    try:
        store = StateStore(d, session_id="case1")
        seed(store)
        rev1 = json.load(open(store.state_path))
        # forge a PREPARE for rev2 without ever writing the new snapshot
        pending_next = {"revision": 2, "notes": ["sneaky"], "last_txid": "tx-0002"}
        with open(store.events_path, "a") as f:
            f.write(json.dumps({"event": "PREPARE", "txid": "tx-0002", "revision": 2,
                                "previous_snapshot_hash": snapshot_hash(rev1),
                                "next_snapshot_hash": snapshot_hash(pending_next),
                                "change": "never completed"}) + "\n")
        # read mode: old state stays authoritative, sneaky content never adopted
        state, report = store.load_state(write_mode=False)
        assert state == rev1, "uncommitted snapshot must not be adopted"
        assert report["uncommitted_tx"] == 1
        assert state["revision"] == 1
        # even in write mode nothing is adopted and no COMMIT appears
        state2, _ = store.load_state(write_mode=True)
        assert state2 == rev1
        events = [json.loads(l) for l in open(store.events_path) if l.strip()]
        assert sum(1 for e in events if e.get("txid") == "tx-0002"
                   and e.get("event") == "COMMIT") == 0
    finally:
        shutil.rmtree(d, ignore_errors=True)

@case
def state_snapshot_without_commit_reconciled_once():
    d = runtime()
    try:
        store = StateStore(d, session_id="case2")
        seed(store)
        rev1 = json.load(open(store.state_path))
        rev2 = dict(rev1, notes=rev1.get("notes", []) + ["pending"])
        rev2["revision"] = 2
        rev2["last_txid"] = "tx-0002"
        h = snapshot_hash(rev2)
        with open(store.events_path, "a") as f:
            f.write(json.dumps({"event": "PREPARE", "txid": "tx-0002", "revision": 2,
                                "previous_snapshot_hash": snapshot_hash(rev1),
                                "next_snapshot_hash": h,
                                "change": "crashed before commit"}) + "\n")
        plan_state.os.replace(store.state_path, store.state_path + ".old")
        with open(store.state_path + ".tmp", "w") as f:
            json.dump(rev2, f)
        os.replace(store.state_path + ".tmp", store.state_path)
        os.remove(store.state_path + ".old")
        # first load reconciles with exactly one COMMIT
        state, report = store.load_state(write_mode=True)
        assert report["reconciled_commit"] == "tx-0002", report
        assert state["revision"] == 2
        # second load adds nothing (idempotent)
        _state, report2 = store.load_state(write_mode=True)
        assert report2["reconciled_commit"] is None
        events = [json.loads(l) for l in open(store.events_path) if l.strip()]
        assert sum(1 for e in events if e.get("txid") == "tx-0002"
                   and e.get("event") == "COMMIT") == 1
    finally:
        shutil.rmtree(d, ignore_errors=True)

@case
def state_torn_last_event_quarantined():
    d = runtime()
    try:
        store = StateStore(d, session_id="case3")
        seed(store, n=2)
        rev2 = json.load(open(store.state_path))
        # tear the last COMMIT line mid-write
        with open(store.events_path, "rb") as f:
            raw = f.read()
        nl = raw.rstrip(b"\n").rfind(b"\n") + 1
        torn_line = raw[nl:].rstrip(b"\n")
        with open(store.events_path, "wb") as f:
            f.write(raw[:nl] + torn_line[: len(torn_line) // 2])  # no trailing \n
        state, report = store.load_state(write_mode=True)
        assert report["quarantined"] and report["quarantined"]["bytes"] > 0
        assert os.path.isfile(report["quarantined"]["path"])
        # the torn COMMIT line was quarantined, but the tx-0002 snapshot is
        # fully on disk with a matching next-hash: the protocol reconciles it
        # with exactly one COMMIT instead of redoing or rolling back
        assert state["revision"] == 2
        assert report["reconciled_commit"] == "tx-0002", report
        # the chain continues from the reconciled commit
        store.transact(bump_note, change="after recovery")
        state = json.load(open(store.state_path))
        assert state["revision"] == 3 and state["last_txid"] == "tx-0003"
    finally:
        shutil.rmtree(d, ignore_errors=True)

@case
def state_revision_conflict_rejected():
    d = runtime()
    try:
        store = StateStore(d, session_id="case4")
        seed(store)
        state = json.load(open(store.state_path))
        # forge a COMMIT that skips revisions (1 -> 3)
        with open(store.events_path, "a") as f:
            f.write(json.dumps({"event": "COMMIT", "txid": "tx-0003", "revision": 3,
                                "snapshot_hash": snapshot_hash(state)}) + "\n")
        try:
            store.load_state(write_mode=True)
            raise AssertionError("revision conflict must be rejected")
        except StateCorruption as e:
            assert "revision conflict" in str(e)
    finally:
        shutil.rmtree(d, ignore_errors=True)

@case
def state_example_cannot_replace_live():
    d = runtime()
    try:
        store = StateStore(d, session_id="case5")
        seed(store, n=2)
        # overwrite live state with STATE.example-like content
        example = json.load(open(os.path.join(HERE, "..", "..",
                                              "docs", "plans", "enterprise-uiux-v1",
                                              "STATE.example.json")))
        with open(store.state_path, "w") as f:
            json.dump(example, f)
        try:
            store.load_state(write_mode=True)
            raise AssertionError("example must not replace live state")
        except StateCorruption as e:
            assert "example" in str(e) or "hash" in str(e), str(e)
    finally:
        shutil.rmtree(d, ignore_errors=True)

def _write_case6_state(d):
    store = StateStore(d, session_id="case6")
    seed(store)
    state = json.load(open(store.state_path))
    state["tasks"] = {"T99": {"work_state": "FINISHED",  # invalid enum
                              "verification_state": "MAYBE",
                              "manual_state": "WHATEVER"}}
    h = snapshot_hash(state)
    with open(store.events_path, "a") as f:
        f.write(json.dumps({"event": "PREPARE", "txid": "tx-0002", "revision": 2,
                            "previous_snapshot_hash": snapshot_hash(
                                json.load(open(store.state_path))),
                            "next_snapshot_hash": h, "change": "enum case"}) + "\n")
    with open(store.state_path + ".tmp", "w") as f:
        json.dump(state, f)
    os.replace(store.state_path + ".tmp", store.state_path)

@case
def state_status_enum_complete():
    d = runtime()
    try:
        _write_case6_state(d)
        p = subprocess.run([sys.executable, CHECK_STATE, "--runtime", d],
                           capture_output=True, text=True)
        assert p.returncode != 0, "invalid state enums must fail check_state"
        out = json.loads(p.stdout)
        joined = " ".join(out["problems"])
        for bad in ("FINISHED", "MAYBE", "WHATEVER"):
            assert bad in joined, (bad, out["problems"])
    finally:
        shutil.rmtree(d, ignore_errors=True)

@case
def state_commit_missing_not_pass():
    d = runtime()
    try:
        store = StateStore(d, session_id="case7")
        seed(store)
        rev1 = json.load(open(store.state_path))
        rev2 = dict(rev1, notes=rev1.get("notes", []) + ["pending"])
        rev2["revision"] = 2
        with open(store.events_path, "a") as f:
            f.write(json.dumps({"event": "PREPARE", "txid": "tx-0002", "revision": 2,
                                "previous_snapshot_hash": snapshot_hash(rev1),
                                "next_snapshot_hash": snapshot_hash(rev2),
                                "change": "missing commit"}) + "\n")
        with open(store.state_path + ".tmp", "w") as f:
            json.dump(rev2, f)
        os.replace(store.state_path + ".tmp", store.state_path)
        # read-only checker must NOT pass and must NOT reconcile silently
        p = subprocess.run([sys.executable, CHECK_STATE, "--runtime", d],
                           capture_output=True, text=True)
        assert p.returncode != 0, "missing COMMIT must not pass check_state"
        out = json.loads(p.stdout)
        assert any("state_commit_missing_not_pass" in x for x in out["problems"]), out
        events = [json.loads(l) for l in open(store.events_path) if l.strip()]
        assert sum(1 for e in events if e.get("event") == "COMMIT"
                   and e.get("txid") == "tx-0002") == 0, \
            "read-only check must not append COMMIT"
    finally:
        shutil.rmtree(d, ignore_errors=True)

def main():
    results, failed = [], 0
    for fn in CASES:
        try:
            fn()
            results.append({"case": fn.__name__, "result": "PASS"})
            print(f"PASS {fn.__name__}")
        except AssertionError as e:
            failed += 1
            results.append({"case": fn.__name__, "result": "FAIL", "error": str(e)[:300]})
            print(f"FAIL {fn.__name__}: {e}")
    print(json.dumps({"total": len(CASES), "failed": failed, "results": results}))
    return 1 if failed else 0

if __name__ == "__main__":
    sys.exit(main())
