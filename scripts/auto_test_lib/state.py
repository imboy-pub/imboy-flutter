"""Run/step/target state layer, legacy loader and lease primitives (Step 6).

Source of truth:
- docs/plans/2026-09-18-auto-test-framework-hardening-plan.md §4.1 (three
  strictly separated state layers) and §6 (lease contract), Step 6 / ATF-501
  and ATF-503;
- test/auto_test/state/schema.json -- tracked stable schema; the enums below
  must stay identical to it (tests enforce the sync).

Three state layers (§4.1):
- ``scheduler_state`` (run/step): WAITING | READY | RUNNING | DONE |
  INTERRUPTED;
- ``test_status`` (single target): PASS | PASS_WITH_SKIPS | BLOCKED | FAIL |
  FLAKY | PLANNED, plus the plan-time placeholder UNKNOWN used by a fresh
  clone before anything executed;
- ``scope_verdict`` (step/domain rollup): '' | PASS | PARTIAL | BLOCKED.

The legacy ``test/auto_test/task_state.json`` is a read-only historical
input: :func:`load_legacy_task_state` never rewrites it and new executions
never append batch top-level fields to it.

Leases (§6): acquired via atomic ``mkdir`` of ``<leases_dir>/<resource>``,
owner payload written to a temp file (fsync) then atomically renamed to
``owner.json``. Missing owner / truncated JSON / schema errors are
``CORRUPT_LEASE`` and fail closed; stale leases are only marked, never
preempted; double release is an error.

Python 3.9 stdlib only.
"""

from __future__ import annotations

import json
import os
import time
import typing as t
from pathlib import Path

# ---------------------------------------------------------------------------
# Enums (must match test/auto_test/state/schema.json; tests enforce sync)
# ---------------------------------------------------------------------------

SCHEDULER_STATES: t.Tuple[str, ...] = (
    "WAITING", "READY", "RUNNING", "DONE", "INTERRUPTED",
)

TEST_STATUSES: t.Tuple[str, ...] = (
    "PASS", "PASS_WITH_SKIPS", "BLOCKED", "FAIL", "FLAKY", "PLANNED",
)

#: Plan-time placeholder for a target with no recorded execution yet.
UNKNOWN = "UNKNOWN"

TEST_STATUSES_WITH_UNKNOWN: t.Tuple[str, ...] = TEST_STATUSES + (UNKNOWN,)

SCOPE_VERDICTS: t.Tuple[str, ...] = ("PASS", "PARTIAL", "BLOCKED")

STATE_SCHEMA_VERSION = 1

#: Required owner.json fields of a lease (§6).
LEASE_OWNER_REQUIRED_FIELDS: t.Tuple[str, ...] = (
    "run", "step", "agent", "process", "resource",
)

ERR_UNKNOWN_STATE = "UNKNOWN_STATE"
ERR_CREDENTIAL_FIELD = "CREDENTIAL_FIELD_REJECTED"
ERR_STATE_SCHEMA = "STATE_SCHEMA"
ERR_LEASE_HELD = "LEASE_ALREADY_HELD"
ERR_LEASE_NOT_HELD = "LEASE_NOT_HELD"
ERR_CORRUPT_LEASE = "CORRUPT_LEASE"
ERR_LEASE_OWNER_MISMATCH = "LEASE_OWNER_MISMATCH"


class StateError(Exception):
    """Fail-closed state/lease violation."""


# ---------------------------------------------------------------------------
# Legacy task_state.json (read-only compatibility)
# ---------------------------------------------------------------------------

def load_legacy_task_state(path: t.Union[str, Path]) -> t.Dict[str, t.Any]:
    """Read the legacy task_state.json without ever rewriting it.

    Returns ``{}`` when the file does not exist; raises StateError on invalid
    JSON so corrupt history is never silently treated as empty.
    """
    target = Path(path)
    if not target.is_file():
        return {}
    try:
        data = json.loads(target.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise StateError("legacy task_state.json is not valid JSON: %s" % exc) from exc
    if not isinstance(data, dict):
        raise StateError("legacy task_state.json must be a JSON object")
    return data


# ---------------------------------------------------------------------------
# Fresh-clone planning (ATF-501)
# ---------------------------------------------------------------------------

def fresh_clone_plan(catalog: t.Mapping[str, t.Any]) -> t.Dict[str, t.Any]:
    """Build a complete all-UNKNOWN plan from the tracked catalog alone.

    No ignored ``reports/`` history is read: a fresh clone gets one plan row
    per catalog entry (and per mapped page), every target ``UNKNOWN`` and the
    scheduler ``READY`` -- never a fabricated PASS.
    """
    entries = catalog.get("entries") or []
    pages = catalog.get("pages") or []
    plan_rows = []
    for entry in entries:
        if not isinstance(entry, dict) or not entry.get("target"):
            continue
        plan_rows.append(
            {
                "id": entry.get("id") or "test:%s" % entry["target"],
                "target": entry["target"],
                "test_status": UNKNOWN,
                "scheduler_state": "READY",
            }
        )
    return {
        "schema_version": STATE_SCHEMA_VERSION,
        "source": "catalog-v1",
        "scheduler_state": "READY",
        "scope_verdict": "",
        "targets": plan_rows,
        "pages": [
            {
                "page": page.get("page"),
                "mapped_targets": list(page.get("mapped_targets") or []),
            }
            for page in pages
            if isinstance(page, dict)
        ],
    }


# ---------------------------------------------------------------------------
# State document validation (ATF-503)
# ---------------------------------------------------------------------------

def _scan_credential_fields(node: t.Any, errors: t.List[str], path: str) -> None:
    from auto_test_lib.evidence import SECRET_FIELD_RE  # local: avoid cycle at import

    if isinstance(node, dict):
        for key, value in node.items():
            key_text = key if isinstance(key, str) else repr(key)
            if SECRET_FIELD_RE.search(key_text):
                errors.append(
                    "%s: field %s at %s matches the credential pattern"
                    % (ERR_CREDENTIAL_FIELD, key_text, path)
                )
            _scan_credential_fields(value, errors, path + "." + key_text)
    elif isinstance(node, (list, tuple)):
        for index, item in enumerate(node):
            _scan_credential_fields(item, errors, "%s[%d]" % (path, index))


def _check_scheduler_state(value: t.Any, where: str, errors: t.List[str]) -> None:
    if value not in SCHEDULER_STATES:
        errors.append(
            "%s: %s scheduler_state %r not in %s"
            % (ERR_UNKNOWN_STATE, where, value, list(SCHEDULER_STATES))
        )


def _check_scope_verdict(value: t.Any, where: str, errors: t.List[str]) -> None:
    if value not in ("", None) and value not in SCOPE_VERDICTS:
        errors.append(
            "%s: %s scope_verdict %r not in %s"
            % (ERR_UNKNOWN_STATE, where, value, list(SCOPE_VERDICTS))
        )


def validate_state_document(document: t.Any) -> t.List[str]:
    """Validate a run/step/target state document; empty list == valid.

    Layer contract:
    - run: ``run_id`` + ``scheduler_state`` + optional ``scope_verdict``;
    - steps: each with ``step`` id + scheduler_state + scope_verdict;
    - targets: each with ``target`` + ``test_status`` (six §4.1 statuses or
      the plan-time UNKNOWN placeholder).
    Credential-named fields are rejected anywhere in the document.
    """
    errors: t.List[str] = []
    if not isinstance(document, dict):
        return ["%s: state document must be a JSON object" % ERR_STATE_SCHEMA]

    _scan_credential_fields(document, errors, "$")

    if document.get("schema_version") != STATE_SCHEMA_VERSION:
        errors.append(
            "%s: schema_version must be %d" % (ERR_STATE_SCHEMA, STATE_SCHEMA_VERSION)
        )
    if not document.get("run_id"):
        errors.append("%s: run_id is required" % ERR_STATE_SCHEMA)
    _check_scheduler_state(document.get("scheduler_state"), "run", errors)
    _check_scope_verdict(document.get("scope_verdict"), "run", errors)

    steps = document.get("steps")
    if steps is not None:
        if not isinstance(steps, list):
            errors.append("%s: steps must be a list" % ERR_STATE_SCHEMA)
        else:
            for index, step in enumerate(steps):
                if not isinstance(step, dict):
                    errors.append(
                        "%s: steps[%d] must be an object" % (ERR_STATE_SCHEMA, index)
                    )
                    continue
                if not step.get("step"):
                    errors.append(
                        "%s: steps[%d].step id is required" % (ERR_STATE_SCHEMA, index)
                    )
                _check_scheduler_state(
                    step.get("scheduler_state"), "steps[%d]" % index, errors
                )
                _check_scope_verdict(
                    step.get("scope_verdict"), "steps[%d]" % index, errors
                )

    targets = document.get("targets")
    if targets is not None:
        if not isinstance(targets, list):
            errors.append("%s: targets must be a list" % ERR_STATE_SCHEMA)
        else:
            for index, row in enumerate(targets):
                if not isinstance(row, dict):
                    errors.append(
                        "%s: targets[%d] must be an object" % (ERR_STATE_SCHEMA, index)
                    )
                    continue
                if not row.get("target"):
                    errors.append(
                        "%s: targets[%d].target is required"
                        % (ERR_STATE_SCHEMA, index)
                    )
                status = row.get("test_status")
                if status not in TEST_STATUSES_WITH_UNKNOWN:
                    errors.append(
                        "%s: targets[%d].test_status %r not in %s"
                        % (
                            ERR_UNKNOWN_STATE,
                            index,
                            status,
                            list(TEST_STATUSES_WITH_UNKNOWN),
                        )
                    )
    return errors


# ---------------------------------------------------------------------------
# Leases (§6): atomic mkdir acquire, fsync + rename owner.json, fail closed
# ---------------------------------------------------------------------------

def _lease_dir(leases_dir: t.Union[str, Path], resource: str) -> Path:
    import re

    if not resource or resource in (".", "..") or resource.startswith("."):
        raise StateError("invalid lease resource name: %r" % (resource,))
    # Lease resources like FIXTURE_NAMESPACE:<run/shard> contain separators;
    # map them onto one safe directory component (no traversal, no nesting).
    safe = re.sub(r"[^A-Za-z0-9_.:-]+", "__", resource)
    if not safe or safe.startswith("-"):
        raise StateError("invalid lease resource name: %r" % (resource,))
    return Path(leases_dir) / safe


def _atomic_write_owner(path: Path, owner: t.Dict[str, t.Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp.%d" % os.getpid())
    payload = json.dumps(owner, ensure_ascii=False, indent=2, sort_keys=True)
    with open(tmp, "w", encoding="utf-8") as handle:
        handle.write(payload)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(tmp, path)


def acquire_lease(
    leases_dir: t.Union[str, Path],
    resource: str,
    owner: t.Mapping[str, t.Any],
) -> Path:
    """Acquire ``resource`` via atomic mkdir; write fsynced owner.json.

    Raises StateError(LEASE_ALREADY_HELD) when another holder exists and
    StateError(CORRUPT_LEASE...) when the owner payload is incomplete.
    """
    payload = dict(owner)
    payload["resource"] = resource
    missing = [f for f in LEASE_OWNER_REQUIRED_FIELDS if not payload.get(f)]
    if missing:
        raise StateError(
            "%s: owner payload missing required fields %s"
            % (ERR_CORRUPT_LEASE, missing)
        )
    directory = _lease_dir(leases_dir, resource)
    Path(leases_dir).mkdir(parents=True, exist_ok=True)
    try:
        os.mkdir(directory)
    except FileExistsError as exc:
        raise StateError(
            "%s: resource %s is already held (no preemption)" % (ERR_LEASE_HELD, resource)
        ) from exc
    payload.setdefault("acquired_at", time.time())
    payload.setdefault("heartbeat", payload["acquired_at"])
    _atomic_write_owner(directory / "owner.json", payload)
    return directory


def read_lease(
    leases_dir: t.Union[str, Path], resource: str
) -> t.Dict[str, t.Any]:
    """Read a lease owner payload; missing dir, missing/empty/truncated
    owner.json or schema errors are CORRUPT_LEASE (fail closed)."""
    directory = _lease_dir(leases_dir, resource)
    if not directory.is_dir():
        raise StateError("%s: resource %s is not held" % (ERR_LEASE_NOT_HELD, resource))
    owner_path = directory / "owner.json"
    if not owner_path.is_file():
        raise StateError(
            "%s: lease %s has no owner.json (empty owner)" % (ERR_CORRUPT_LEASE, resource)
        )
    try:
        text = owner_path.read_text(encoding="utf-8")
    except OSError as exc:
        raise StateError(
            "%s: lease %s owner.json unreadable: %s" % (ERR_CORRUPT_LEASE, resource, exc)
        ) from exc
    if not text.strip():
        raise StateError(
            "%s: lease %s owner.json is empty (empty owner)" % (ERR_CORRUPT_LEASE, resource)
        )
    try:
        owner = json.loads(text)
    except ValueError as exc:
        raise StateError(
            "%s: lease %s owner.json is truncated/invalid JSON: %s"
            % (ERR_CORRUPT_LEASE, resource, exc)
        ) from exc
    if not isinstance(owner, dict):
        raise StateError(
            "%s: lease %s owner.json is not a JSON object" % (ERR_CORRUPT_LEASE, resource)
        )
    missing = [f for f in LEASE_OWNER_REQUIRED_FIELDS if not owner.get(f)]
    if missing:
        raise StateError(
            "%s: lease %s owner payload missing fields %s"
            % (ERR_CORRUPT_LEASE, resource, missing)
        )
    return owner


def heartbeat_lease(
    leases_dir: t.Union[str, Path], resource: str, agent: str
) -> float:
    """Refresh the lease heartbeat; only the owning agent may do so."""
    directory = _lease_dir(leases_dir, resource)
    owner = read_lease(leases_dir, resource)
    if owner.get("agent") != agent:
        raise StateError(
            "%s: agent %r cannot heartbeat lease %s held by %r"
            % (ERR_LEASE_OWNER_MISMATCH, agent, resource, owner.get("agent"))
        )
    now = time.time()
    owner["heartbeat"] = now
    _atomic_write_owner(directory / "owner.json", owner)
    return now


def lease_stale(
    leases_dir: t.Union[str, Path], resource: str, max_gap: float = 120.0
) -> bool:
    """Stale detection is mark-only: never preempts (§6)."""
    owner = read_lease(leases_dir, resource)
    heartbeat = owner.get("heartbeat")
    if not isinstance(heartbeat, (int, float)):
        return True
    return (time.time() - float(heartbeat)) > max_gap


def release_lease(
    leases_dir: t.Union[str, Path], resource: str, agent: str
) -> None:
    """Release a lease owned by ``agent``; double release is an error."""
    directory = _lease_dir(leases_dir, resource)
    owner = read_lease(leases_dir, resource)
    if owner.get("agent") != agent:
        raise StateError(
            "%s: agent %r cannot release lease %s held by %r"
            % (ERR_LEASE_OWNER_MISMATCH, agent, resource, owner.get("agent"))
        )
    try:
        (directory / "owner.json").unlink()
        directory.rmdir()
    except FileNotFoundError as exc:
        raise StateError(
            "%s: lease %s vanished before release" % (ERR_LEASE_NOT_HELD, resource)
        ) from exc
