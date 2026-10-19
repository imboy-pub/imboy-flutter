#!/usr/bin/env python3
"""T04.c persistent transactional state — imboy-enterprise-uiux-v1.

Implements RESUME_PROTOCOL §6 inside a plan_lock short transaction:

  PREPARE event (fsync) -> snapshot temp+atomic-rename (fsync) -> COMMIT event (fsync)

Recovery follows the event log strictly by txid/revision/hash — never by mtime:

| situation                                   | handling                                    |
|---------------------------------------------|---------------------------------------------|
| no PREPARE                                  | no state change                              |
| PREPARE present, snapshot still previous    | uncommitted: old state stays authoritative;  |
|                                             | new content never adopted                    |
| snapshot == next hash, COMMIT missing       | write mode: reconcile with exactly one       |
|                                             | COMMIT; read mode: reported invalid          |
| COMMIT present, snapshot matches            | committed (idempotent)                       |
| torn LAST log line                          | quarantined under recovery/backups, prefix   |
|                                             | stays authoritative                          |
| mid-file corruption / revision / hash chain | StateCorruption: fail closed, never guess    |
| conflict                                    |                                              |

The lock file is fixed and never deleted; ownership rules come from plan_lock.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import os

from plan_lock import LockDenied, acquire, release, current_owner_identity


class StateCorruption(Exception):
    pass


def snapshot_hash(state: dict) -> str:
    return hashlib.sha256(
        json.dumps(state, ensure_ascii=False, sort_keys=True).encode()
    ).hexdigest()


def _now() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


class StateStore:
    def __init__(self, runtime_dir: str, session_id: str):
        self.dir = runtime_dir
        self.state_path = os.path.join(runtime_dir, "state.json")
        self.events_path = os.path.join(runtime_dir, "events.jsonl")
        self.lock_path = os.path.join(runtime_dir, "locks", "state.guard")
        self.backups = os.path.join(runtime_dir, "recovery", "backups")
        self.session_id = session_id
        os.makedirs(self.backups, exist_ok=True)
        os.makedirs(os.path.dirname(self.lock_path), exist_ok=True)

    # ------------------------------------------------------------------ io
    def _append_event(self, event: dict):
        with open(self.events_path, "a", encoding="utf-8") as f:
            f.write(json.dumps(event, ensure_ascii=False) + "\n")
            f.flush()
            os.fsync(f.fileno())

    def _write_snapshot(self, state: dict):
        tmp = self.state_path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(state, f, ensure_ascii=False, indent=1)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, self.state_path)
        fd = os.open(self.dir, os.O_RDONLY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)

    # -------------------------------------------------------------- events
    def read_events(self, trim_torn: bool = False):
        """Return (events, quarantined_info). Fails closed on mid-file damage.

        A torn (newline-less) LAST line is backed up under recovery/backups;
        with trim_torn=True the live log is truncated back to the valid prefix
        so appended events can never merge with the torn bytes.
        """
        if not os.path.exists(self.events_path):
            return [], None
        with open(self.events_path, "rb") as f:
            raw = f.read()
        quarantined = None
        if raw and not raw.endswith(b"\n"):
            nl = raw.rfind(b"\n")
            torn = raw[nl + 1:]
            valid = raw[: nl + 1] if nl >= 0 else b""
            qname = f"torn-{dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')}"
            qpath = os.path.join(self.backups, qname + ".jsonl")
            with open(qpath, "wb") as f:
                f.write(torn)
            quarantined = {"path": qpath, "bytes": len(torn)}
            if trim_torn:
                with open(self.events_path, "r+b") as f:
                    f.truncate(len(valid))
                    f.flush()
                    os.fsync(f.fileno())
            raw = valid
        events = []
        for i, line in enumerate(raw.decode("utf-8", "replace").split("\n")):
            if not line.strip():
                continue
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError as e:
                raise StateCorruption(f"events.jsonl mid-file damage at line {i + 1}: {e}")
        return events, quarantined

    # -------------------------------------------------------------- load
    def load_state(self, write_mode: bool = False):
        """Return (state, report). Recovery per the event log; see module doc."""
        report = {"quarantined": None, "reconciled_commit": None,
                  "uncommitted_tx": 0, "example_rejected": None}
        events, report["quarantined"] = self.read_events(trim_torn=write_mode)
        commits = [e for e in events if e.get("event") == "COMMIT"]
        tail = events[-1] if events else None
        pending = tail if tail and tail.get("event") == "PREPARE" else None

        # strict revision sequence over COMMITs
        for idx, ev in enumerate(commits, start=1):
            if ev.get("revision") != idx:
                raise StateCorruption(
                    f"revision conflict: COMMIT#{idx} has revision {ev.get('revision')}")

        disk = None
        if os.path.exists(self.state_path):
            try:
                with open(self.state_path, encoding="utf-8") as f:
                    disk = json.load(f)
            except json.JSONDecodeError as e:
                raise StateCorruption(f"state.json unreadable: {e}")

        if not commits:
            state = disk if disk is not None else self._fresh_state()
            return state, report

        last = commits[-1]
        if disk is None:
            raise StateCorruption("COMMIT history exists but state.json is missing")
        if disk.get("example_only") or disk.get("status") == "NOT_INITIALIZED":
            report["example_rejected"] = ("state.json looks like STATE.example while "
                                          f"{len(commits)} COMMITs exist")
            raise StateCorruption(report["example_rejected"])

        h = snapshot_hash(disk)
        if h == last.get("snapshot_hash"):
            state = disk
            if (pending and pending.get("previous_snapshot_hash") == h
                    and pending.get("next_snapshot_hash") != h):
                # a PREPARE whose new snapshot was never written: the new
                # content is not adopted; only the previous state counts
                report["uncommitted_tx"] = 1
        elif pending and h == pending.get("next_snapshot_hash"):
            if write_mode:
                self._append_event({"event": "COMMIT", "txid": pending["txid"],
                                    "revision": pending["revision"], "ts": _now(),
                                    "snapshot_hash": h,
                                    "reconciled": True})
                report["reconciled_commit"] = pending["txid"]
                state = disk
            else:
                raise StateCorruption(
                    f"snapshot for {pending['txid']} exists but COMMIT missing "
                    "(read-only check does not accept it)")
        elif pending and h == pending.get("previous_snapshot_hash"):
            # uncommitted transaction: old snapshot stays authoritative
            report["uncommitted_tx"] = 1
            state = disk
        else:
            raise StateCorruption(
                "state.json hash matches neither last COMMIT nor any pending snapshot")
        return state, report

    def _fresh_state(self):
        return {"schema_version": 2, "plan_id": None, "revision": 0,
                "last_txid": None, "tasks": {}, "status": "ACTIVE"}

    # ----------------------------------------------------------- transact
    def transact(self, mutator, change: str = ""):
        """One state transaction under the short-tx lock. Returns new state."""
        owner = current_owner_identity(session_id=self.session_id)
        owner["epoch"] = 1  # plan_lock assigns/validates epoch against the record
        rec = acquire(self.lock_path, owner, timeout=5.0)
        try:
            state, _report = self.load_state(write_mode=True)
            prev_hash = snapshot_hash(state)
            events, _ = self.read_events(trim_torn=True)
            rev = len([e for e in events if e.get("event") == "COMMIT"]) + 1
            txid = f"tx-{rev:04d}"
            new_state = mutator(json.loads(json.dumps(state, ensure_ascii=False)))
            new_state["revision"] = rev
            new_state["last_txid"] = txid
            next_hash = snapshot_hash(new_state)
            self._append_event({"event": "PREPARE", "txid": txid, "revision": rev,
                                "ts": _now(), "owner_epoch": rec["epoch"],
                                "previous_snapshot_hash": prev_hash,
                                "next_snapshot_hash": next_hash,
                                "change": change})
            self._write_snapshot(new_state)
            self._append_event({"event": "COMMIT", "txid": txid, "revision": rev,
                                "ts": _now(), "snapshot_hash": next_hash})
            return new_state
        finally:
            release(self.lock_path, owner, rec["epoch"])
