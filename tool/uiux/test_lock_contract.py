#!/usr/bin/env python3
"""T04.b contract self-test for plan_lock.py (temp dirs + subprocesses only).

Required assertions:
  lock_live_owner_rejected
  lock_pid_reuse_rejected
  lock_timeout_is_not_takeover
  lock_release_old_epoch_rejected
  lock_child_alive_blocks_takeover
  lock_owner_unknown_fails_closed
plus lock_takeover_after_verified_death (epoch+1 inheritance).
The real repository is never touched: all state lives in tempfile dirs.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import plan_lock  # noqa: E402

CASES = []

def case(fn):
    CASES.append(fn)
    return fn

def tmp_lock():
    d = tempfile.mkdtemp(prefix="uiux-lock-case-")
    return d, os.path.join(d, "state.guard")

def owner_for(session, pid=None, lstart=None):
    return {
        "host": "fixture-host",
        "pid": pid if pid is not None else os.getpid(),
        "lstart": lstart or plan_lock.pid_lstart(pid if pid is not None else os.getpid()),
        "session_id": session,
    }

@case
def lock_live_owner_rejected():
    d, lock = tmp_lock()
    try:
        # cross-process: a child process holds the lock, this process must fail
        child = subprocess.Popen(
            [sys.executable, "-c",
             "import sys, time; sys.path.insert(0, %r); import plan_lock; "
             "plan_lock.acquire(%r, plan_lock.current_owner_identity(session_id='child-a')); "
             "print('held', flush=True); time.sleep(30)" % (HERE, lock)],
            stdout=subprocess.PIPE, text=True)
        assert child.stdout.readline().strip() == "held"
        me = owner_for("parent-b")
        try:
            plan_lock.acquire(lock, me, timeout=0.5)
            raise AssertionError("live owner must be rejected")
        except plan_lock.LockDenied as e:
            assert e.reason in ("ALREADY_LOCKED", "TIMEOUT"), e.reason
        child.kill(); child.wait()
        # record still points at dead child: a takeover now succeeds (epoch+1)
        rec = plan_lock.acquire(lock, me, takeover=True, timeout=2.0)
        assert rec["epoch"] >= 2, rec
        assert rec["takeover_of"]["session_id"] == "child-a"
        plan_lock.release(lock, me, rec["epoch"])
    finally:
        shutil.rmtree(d, ignore_errors=True)

@case
def lock_pid_reuse_rejected():
    d, lock = tmp_lock()
    try:
        # forge a record whose pid exists NOW but with a mismatched start time
        forger = owner_for("ghost", pid=os.getpid(), lstart="Wed Dec 25 00:00:00 2019")
        with open(lock, "w") as f:
            json.dump({**forger, "epoch": 1}, f)
        try:
            plan_lock.acquire(lock, owner_for("new-session"), timeout=1.0)
            raise AssertionError("pid reuse must fail closed")
        except plan_lock.LockDenied as e:
            assert e.reason == "PID_REUSE", e.reason
    finally:
        shutil.rmtree(d, ignore_errors=True)

@case
def lock_timeout_is_not_takeover():
    d, lock = tmp_lock()
    try:
        holder = owner_for("holder")
        plan_lock.acquire(lock, holder, timeout=1.0)
        before = json.load(open(lock))
        # hold the flock from another fd so the waiter really hits flock
        # contention (acquire releases the flock after the critical section;
        # long-lived ownership is the record itself)
        import fcntl as _fcntl
        block_fd = os.open(lock, os.O_RDWR)
        _fcntl.flock(block_fd, _fcntl.LOCK_EX)
        try:
            plan_lock.acquire(lock, owner_for("waiter"), timeout=0.3)
            raise AssertionError("waiter must time out")
        except plan_lock.LockDenied as e:
            assert e.reason == "TIMEOUT", e.reason
        finally:
            _fcntl.flock(block_fd, _fcntl.LOCK_UN)
            os.close(block_fd)
        after = json.load(open(lock))
        assert before == after, "timeout must not modify the owner record"
    finally:
        shutil.rmtree(d, ignore_errors=True)

@case
def lock_release_old_epoch_rejected():
    d, lock = tmp_lock()
    try:
        sess = "epoch-owner"
        rec = plan_lock.acquire(lock, owner_for(sess), timeout=1.0)
        assert rec["epoch"] >= 1
        try:
            plan_lock.release(lock, owner_for(sess), rec["epoch"] - 1)
            raise AssertionError("stale-epoch release must be rejected")
        except plan_lock.LockDenied as e:
            assert e.reason == "OLD_EPOCH_RELEASE", e.reason
        still = json.load(open(lock))
        assert still.get("session_id") == sess and not still.get("released"), \
            "rejected release must leave the record intact"
        plan_lock.release(lock, owner_for(sess), rec["epoch"])
        assert json.load(open(lock)).get("released") is True
    finally:
        shutil.rmtree(d, ignore_errors=True)

@case
def lock_child_alive_blocks_takeover():
    d, lock = tmp_lock()
    try:
        # owner pid must be verifiably DEAD; its child must be alive
        victim = subprocess.Popen(["sleep", "30"])
        victim_lstart = plan_lock.pid_lstart(victim.pid)
        victim.kill(); victim.wait()
        time.sleep(0.1)
        sleeper = subprocess.Popen(["sleep", "30"])
        record = {"host": "fixture-host", "pid": victim.pid, "lstart": victim_lstart,
                  "session_id": "dead-parent", "epoch": 3,
                  "child_pids": [sleeper.pid]}
        with open(lock, "w") as f:
            json.dump(record, f)
        try:
            plan_lock.acquire(lock, owner_for("newcomer"), takeover=True, timeout=1.0)
            raise AssertionError("alive child must block takeover")
        except plan_lock.LockDenied as e:
            assert e.reason == "CHILD_ALIVE", e.reason
        sleeper.kill(); sleeper.wait()
        time.sleep(0.1)
        rec = plan_lock.acquire(lock, owner_for("newcomer"), takeover=True, timeout=1.0)
        assert rec["epoch"] == 4, rec
        plan_lock.release(lock, owner_for("newcomer"), rec["epoch"])
    finally:
        shutil.rmtree(d, ignore_errors=True)

@case
def lock_owner_unknown_fails_closed():
    d, lock = tmp_lock()
    try:
        # missing lstart/session/epoch fields -> nobody may take over
        with open(lock, "w") as f:
            json.dump({"host": "fixture-host", "pid": 999999}, f)
        try:
            plan_lock.acquire(lock, owner_for("auditor"), takeover=True, timeout=1.0)
            raise AssertionError("unknown owner identity must fail closed")
        except plan_lock.LockDenied as e:
            assert e.reason == "OWNER_UNKNOWN", e.reason
        # corrupt JSON record -> also fail closed
        with open(lock, "w") as f:
            f.write('{"host": "x", "pid": 1')
        try:
            plan_lock.acquire(lock, owner_for("auditor"), takeover=True, timeout=1.0)
            raise AssertionError("corrupt record must fail closed")
        except plan_lock.LockDenied as e:
            assert e.reason == "OWNER_UNKNOWN", e.reason
    finally:
        shutil.rmtree(d, ignore_errors=True)

@case
def lock_takeover_after_verified_death():
    d, lock = tmp_lock()
    try:
        victim = subprocess.Popen(["sleep", "30"])
        rec = plan_lock.acquire(lock, owner_for("victim", pid=victim.pid,
                                                lstart=plan_lock.pid_lstart(victim.pid)),
                                timeout=1.0, child_pids=[])
        victim.kill(); victim.wait(); time.sleep(0.1)
        # flock is free again (OS released it when the holder process died);
        # force-release the flock side by simulating: acquire with takeover
        newcomer = owner_for("successor")
        rec2 = plan_lock.acquire(lock, newcomer, takeover=True, timeout=2.0)
        assert rec2["epoch"] == rec["epoch"] + 1, (rec, rec2)
        # old epoch cannot release anymore
        try:
            plan_lock.release(lock, owner_for("victim"), rec["epoch"])
            raise AssertionError("old epoch release after takeover must fail")
        except plan_lock.LockDenied as e:
            assert e.reason in ("OLD_EPOCH_RELEASE", "ALREADY_LOCKED"), e.reason
        plan_lock.release(lock, newcomer, rec2["epoch"])
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
