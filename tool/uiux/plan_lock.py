#!/usr/bin/env python3
"""T04.b process identity + short-transaction lock — imboy-enterprise-uiux-v1.

Same-machine POSIX flock thin layer over a FIXED lock file (the file is never
deleted or recreated, so two processes can never lock different inodes).

Owner identity = (host, pid, process-start lstart, session_id, epoch).
The flock protects only the read-owner -> validate -> write-record critical
section; long-running ownership is expressed by the owner record itself.

Fail-closed rules:
- live owner (pid exists with matching lstart) -> ALREADY_LOCKED, never taken
- pid exists but lstart differs -> PID_REUSE, fail closed
- owner dead but listed child pids alive -> CHILD_ALIVE, blocks takeover
- owner record missing identity fields -> OWNER_UNKNOWN, fail closed
- waiting past timeout -> TIMEOUT (a timeout is never a takeover)
- release with a stale epoch -> OLD_EPOCH_RELEASE, record stays intact

Takeover of a verifiably dead owner bumps epoch inside the flock; writes from
the old epoch are rejected afterwards.
"""
from __future__ import annotations

import fcntl
import json
import os
import socket
import subprocess
import time


class LockDenied(Exception):
    def __init__(self, reason: str, detail: str = ""):
        super().__init__(f"{reason}: {detail}" if detail else reason)
        self.reason = reason


def pid_lstart(pid: int):
    """Process start time string, or None when the pid does not exist."""
    p = subprocess.run(["ps", "-o", "lstart=", "-p", str(pid)],
                       capture_output=True, text=True)
    out = p.stdout.strip()
    return out or None


def read_owner(lock_path: str):
    try:
        with open(lock_path, encoding="utf-8") as f:
            data = f.read().strip()
        return json.loads(data) if data else None
    except FileNotFoundError:
        return None
    except json.JSONDecodeError:
        # a torn record is readable-but-invalid: fail closed upstream
        return {"__corrupt__": True}


def _write_owner(lock_path: str, record: dict):
    tmp = lock_path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(record, f, ensure_ascii=False, indent=1)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, lock_path)


REQUIRED_FIELDS = ("host", "pid", "lstart", "session_id", "epoch")


def _flock_exclusive(fd, timeout: float):
    deadline = time.monotonic() + timeout
    while True:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return
        except OSError:
            if time.monotonic() >= deadline:
                raise LockDenied("TIMEOUT",
                                 "could not acquire flock; timeout is not a takeover")
            time.sleep(0.05)


def _any_child_alive(children):
    for pid in children or ():
        if pid_lstart(pid) is not None:
            return pid
    return None


def acquire(lock_path: str, owner: dict, timeout: float = 2.0,
            takeover: bool = False, child_pids=()):
    """Acquire ownership of `lock_path`.

    owner must contain host/pid/lstart/session_id; epoch is assigned here.
    takeover=True allows inheriting from a verifiably dead owner (epoch+1).
    """
    for field in ("host", "pid", "lstart", "session_id"):
        if not owner.get(field):
            raise LockDenied("OWNER_UNKNOWN", f"proposed owner missing {field}")
    os.makedirs(os.path.dirname(lock_path) or ".", exist_ok=True)
    # O_CREAT without unlink: the lock file must never be deleted/recreated
    fd = os.open(lock_path, os.O_RDWR | os.O_CREAT, 0o600)
    try:
        _flock_exclusive(fd, timeout)
    except LockDenied:
        os.close(fd)
        raise

    try:
        rec = read_owner(lock_path)
        if rec and rec.get("__corrupt__"):
            raise LockDenied("OWNER_UNKNOWN", "corrupt owner record; fail closed")

        if rec and not rec.get("released"):
            for field in REQUIRED_FIELDS:
                if field not in rec:
                    raise LockDenied("OWNER_UNKNOWN",
                                     f"existing record missing {field}")
            if rec["session_id"] == owner["session_id"] and rec["epoch"] == owner.get("epoch"):
                return rec  # re-entrant by the same owner identity

            stored_lstart = pid_lstart(rec["pid"])
            if stored_lstart is not None:
                if stored_lstart != rec["lstart"]:
                    raise LockDenied("PID_REUSE",
                                     f"pid {rec['pid']} exists with different start time")
                raise LockDenied("ALREADY_LOCKED",
                                 f"live owner session={rec['session_id']} pid={rec['pid']}")
            alive_child = _any_child_alive(rec.get("child_pids"))
            if alive_child is not None:
                raise LockDenied("CHILD_ALIVE",
                                 f"owner dead but child pid {alive_child} still alive")
            if not takeover:
                raise LockDenied("ALREADY_LOCKED",
                                 "owner record dead but takeover not requested")

        next_epoch = (rec["epoch"] + 1) if rec and "epoch" in rec else 1
        record = {
            "host": owner["host"],
            "pid": owner["pid"],
            "lstart": owner["lstart"],
            "session_id": owner["session_id"],
            "epoch": next_epoch,
            "role": owner.get("role", "worker"),
            "child_pids": list(child_pids),
            "acquired_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        }
        if rec and not rec.get("released"):
            record["takeover_of"] = {"session_id": rec.get("session_id"),
                                     "epoch": rec.get("epoch")}
        _write_owner(lock_path, record)
        return record
    finally:
        fcntl.flock(fd, fcntl.LOCK_UN)
        os.close(fd)


def release(lock_path: str, owner: dict, epoch: int):
    """Release ownership. Only the current-epoch owner may clear the record."""
    fd = os.open(lock_path, os.O_RDWR | os.O_CREAT, 0o600)
    try:
        _flock_exclusive(fd, 2.0)
        rec = read_owner(lock_path)
        if not rec or rec.get("released") or rec.get("__corrupt__"):
            raise LockDenied("OWNER_UNKNOWN", "no live owner record to release")
        if rec.get("session_id") != owner.get("session_id"):
            raise LockDenied("ALREADY_LOCKED",
                             f"record owned by {rec.get('session_id')}")
        if rec.get("epoch") != epoch:
            raise LockDenied("OLD_EPOCH_RELEASE",
                             f"record epoch={rec.get('epoch')} != releasing epoch={epoch}")
        _write_owner(lock_path, {
            "released": True,
            "last_owner": {"session_id": rec["session_id"], "epoch": rec["epoch"]},
            "released_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        })
        return True
    finally:
        fcntl.flock(fd, fcntl.LOCK_UN)
        os.close(fd)


def current_owner_identity(role="coordinator", session_id=None, child_pids=()):
    return {
        "host": socket.gethostname(),
        "pid": os.getpid(),
        "lstart": pid_lstart(os.getpid()) or "unknown",
        "session_id": session_id or f"pid-{os.getpid()}-{time.time_ns()}",
        "role": role,
        "child_pids": list(child_pids),
    }
