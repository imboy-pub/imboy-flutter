"""Minimal evidence manifest construction and fail-closed validation (Step 6).

Source of truth:
- docs/plans/2026-09-18-auto-test-framework-hardening-plan.md §4.3 (minimal
  evidence manifest) and Step 6 acceptance ATF-503;
- test/auto_test/state/schema.json (tracked stable schema, evidence section).

Invariants:
- A PASS manifest always carries a 40-char App HEAD and the closure + hash
  set (target/runner/config/tree/catalog); anything missing is an error.
- ``backend_head = NOT_APPLICABLE`` is only legal when the target's
  requirements contain no backend.* / API / WS / persistence / cross-client
  oracle. In the finite requirement enum those oracles surface as the
  ``backend.*``, ``credentials.*`` and ``fixture.*`` prefixes, so any of them
  forces a real backend HEAD (fail closed when requirements are unknown).
- Field names matching the credential pattern are rejected recursively.
- ``required_evidence_level`` may only raise the capability minimum, never
  lower it; level D can never carry a PASS on its own.

Python 3.9 stdlib only.
"""

from __future__ import annotations

import re
import typing as t

#: Credential field-name pattern (case-insensitive), per ATF-503.
SECRET_FIELD_RE = re.compile(r"(?i)(password|token|secret|api[_-]?key|bearer)")

#: backend_head sentinel.
NOT_APPLICABLE = "NOT_APPLICABLE"

#: 40-char hex git sha.
_SHA1_RE = re.compile(r"^[0-9a-f]{40}$")

#: 64-char hex sha256.
_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")

SCHEMA_VERSION = 1

#: §4.1 terminal test statuses a manifest may carry.
TEST_STATUSES = frozenset({
    "PASS", "PASS_WITH_SKIPS", "BLOCKED", "FAIL", "FLAKY", "PLANNED",
})

#: Evidence levels; higher rank = stronger evidence. D can never PASS alone.
LEVEL_RANK = {"D": 0, "C": 1, "B": 2, "A": 3}

#: Requirement prefixes that imply an app/backend contract (min level B).
_CONTRACT_PREFIXES = ("backend.", "credentials.", "fixture.")

#: Error code prefixes returned inside validate_evidence error strings.
ERR_SCHEMA = "EVIDENCE_SCHEMA"
ERR_CREDENTIAL_FIELD = "CREDENTIAL_FIELD_REJECTED"
ERR_HEAD = "INVALID_HEAD"
ERR_BACKEND_HEAD = "INVALID_BACKEND_HEAD"
ERR_NOT_APPLICABLE = "BACKEND_HEAD_NOT_APPLICABLE_FORBIDDEN"
ERR_HASH = "MISSING_HASH"
ERR_CLOSURE = "MISSING_DEPENDENCY_CLOSURE"
ERR_STATUS = "INVALID_RESULT_STATUS"
ERR_ZERO_EXECUTED_PASS = "PASS_WITH_ZERO_EXECUTED"
ERR_LEVEL_DOWNGRADED = "EVIDENCE_LEVEL_DOWNGRADED"
ERR_LEVEL_D_PASS = "EVIDENCE_LEVEL_D_CANNOT_PASS"

#: Closure manifest fields (§4.3 dependency_closure).
_CLOSURE_FIELDS = ("algorithm", "manifest_path", "manifest_sha256", "content_sha256")


def _reject_credential_fields(node: t.Any, path: str = "$") -> t.List[str]:
    """Recursively reject dict keys matching SECRET_FIELD_RE."""
    errors: t.List[str] = []
    if isinstance(node, dict):
        for key, value in node.items():
            key_text = key if isinstance(key, str) else repr(key)
            if SECRET_FIELD_RE.search(key_text):
                errors.append(
                    "%s: field %s at %s matches the credential pattern"
                    % (ERR_CREDENTIAL_FIELD, key_text, path)
                )
            errors.extend(_reject_credential_fields(value, path + "." + key_text))
    elif isinstance(node, (list, tuple)):
        for index, item in enumerate(node):
            errors.extend(_reject_credential_fields(item, "%s[%d]" % (path, index)))
    return errors


def build_evidence(
    run_id: str,
    head: str,
    backend_head: str,
    target: str,
    result_dict: t.Mapping[str, t.Any],
    environment: t.Mapping[str, t.Any],
    device: t.Mapping[str, t.Any],
    fixture: t.Mapping[str, t.Any],
    artifacts: t.Sequence[t.Mapping[str, t.Any]],
    dependency_closure: t.Mapping[str, t.Any],
    *,
    tested_tree_sha256: str = "",
    catalog_sha256: str = "",
    target_sha256: str = "",
    runner_sha256: str = "",
    config_sha256: str = "",
    command_fingerprint: str = "",
    required_evidence_level: t.Optional[str] = None,
    schema_version: int = SCHEMA_VERSION,
) -> t.Dict[str, t.Any]:
    """Assemble the §4.3 minimal evidence manifest deterministically.

    The constructor performs no validation of its own; callers must pass the
    result through :func:`validate_evidence` (with the target's requirements)
    before the manifest may be stored or counted as evidence.
    """
    evidence: t.Dict[str, t.Any] = {
        "schema_version": schema_version,
        "run_id": run_id,
        "head": head,
        "backend_head": backend_head,
        "tested_tree_sha256": tested_tree_sha256,
        "catalog_sha256": catalog_sha256,
        "target": target,
        "target_sha256": target_sha256,
        "runner_sha256": runner_sha256,
        "config_sha256": config_sha256,
        "dependency_closure": dict(dependency_closure),
        "environment": dict(environment),
        "device": dict(device),
        "fixture": dict(fixture),
        "result": dict(result_dict),
        "command_fingerprint": command_fingerprint,
        "artifacts": [dict(artifact) for artifact in artifacts],
    }
    if required_evidence_level is not None:
        evidence["required_evidence_level"] = required_evidence_level
    return evidence


def minimum_required_level(
    requirements: t.Optional[t.Sequence[str]] = None,
    risk: t.Optional[str] = None,
) -> str:
    """Capability-type minimum evidence level (§4.3, spec may only raise it).

    - real client-device operations (any ``device.*`` requirement or
      ``local-write`` risk) require at least ``A``;
    - app/backend contract work (``backend.*`` / ``credentials.*`` /
      ``fixture.*`` requirements) requires at least ``B``;
    - pure functions / static tooling require at least ``C``.
    """
    reqs = list(requirements or [])
    if risk == "local-write" or any(
        isinstance(r, str) and r.startswith("device.") for r in reqs
    ):
        return "A"
    if any(
        isinstance(r, str) and r.startswith(_CONTRACT_PREFIXES) for r in reqs
    ):
        return "B"
    return "C"


def validate_evidence(
    evidence: t.Mapping[str, t.Any],
    requirements: t.Optional[t.Sequence[str]] = None,
    risk: t.Optional[str] = None,
) -> t.List[str]:
    """Validate a manifest; return error strings (empty list == valid).

    ``requirements`` is the target's requirement list from the catalog; it is
    mandatory whenever ``backend_head == NOT_APPLICABLE`` (fail closed when
    the caller cannot prove the target is backend-free).
    """
    errors: t.List[str] = []
    if not isinstance(evidence, dict):
        return ["%s: evidence must be a JSON object" % ERR_SCHEMA]

    if evidence.get("schema_version") != SCHEMA_VERSION:
        errors.append(
            "%s: schema_version must be %d" % (ERR_SCHEMA, SCHEMA_VERSION)
        )

    # --- credential fields (recursive, keys only) --------------------------
    errors.extend(_reject_credential_fields(evidence))
    if errors and any(code in errors[0] for code in (ERR_CREDENTIAL_FIELD,)):
        # Credential hits are terminal: nothing else is inspected so a secret
        # name can never hide behind later validation branches.
        return errors

    # --- identifiers --------------------------------------------------------
    if not evidence.get("run_id"):
        errors.append("%s: run_id must be a non-empty string" % ERR_SCHEMA)
    if not evidence.get("target"):
        errors.append("%s: target must be a non-empty string" % ERR_SCHEMA)

    head = evidence.get("head")
    if not isinstance(head, str) or not _SHA1_RE.match(head):
        errors.append(
            "%s: head must be a 40-char hex sha, got %r" % (ERR_HEAD, head)
        )

    backend_head = evidence.get("backend_head")
    if isinstance(backend_head, str) and backend_head == NOT_APPLICABLE:
        if requirements is None:
            errors.append(
                "%s: NOT_APPLICABLE requires the target requirements to prove "
                "no backend/API/WS/persistence/cross-client oracle; caller "
                "passed none (fail closed)" % ERR_NOT_APPLICABLE
            )
        else:
            binding = [
                r for r in requirements
                if isinstance(r, str) and r.startswith(_CONTRACT_PREFIXES)
            ]
            if binding:
                errors.append(
                    "%s: backend_head=NOT_APPLICABLE but requirements %s "
                    "require a backend/API/WS/persistence/cross-client oracle"
                    % (ERR_NOT_APPLICABLE, binding)
                )
    elif not isinstance(backend_head, str) or not _SHA1_RE.match(backend_head):
        errors.append(
            "%s: backend_head must be a 40-char sha or %s, got %r"
            % (ERR_BACKEND_HEAD, NOT_APPLICABLE, backend_head)
        )

    # --- hash set -----------------------------------------------------------
    for field in (
        "tested_tree_sha256",
        "catalog_sha256",
        "target_sha256",
        "runner_sha256",
        "config_sha256",
    ):
        value = evidence.get(field)
        if not isinstance(value, str) or not _SHA256_RE.match(value):
            errors.append(
                "%s: %s must be a 64-char sha256, got %r" % (ERR_HASH, field, value)
            )
    command_fp = evidence.get("command_fingerprint")
    if not isinstance(command_fp, str) or not command_fp:
        errors.append("%s: command_fingerprint is missing" % ERR_HASH)

    # --- dependency closure -------------------------------------------------
    closure = evidence.get("dependency_closure")
    if not isinstance(closure, dict) or not closure:
        errors.append("%s: dependency_closure object is missing" % ERR_CLOSURE)
    else:
        for field in _CLOSURE_FIELDS:
            if not closure.get(field):
                errors.append(
                    "%s: dependency_closure.%s is missing" % (ERR_CLOSURE, field)
                )
        for field in ("manifest_sha256", "content_sha256"):
            value = closure.get(field)
            if value and (not isinstance(value, str) or not _SHA256_RE.match(value)):
                errors.append(
                    "%s: dependency_closure.%s must be a 64-char sha256"
                    % (ERR_CLOSURE, field)
                )

    # --- result -------------------------------------------------------------
    result = evidence.get("result")
    if not isinstance(result, dict):
        errors.append("%s: result object is missing" % ERR_STATUS)
    else:
        status = result.get("status")
        if status not in TEST_STATUSES:
            errors.append(
                "%s: result.status %r is not one of %s"
                % (ERR_STATUS, status, sorted(TEST_STATUSES))
            )
        executed = result.get("executed")
        if status == "PASS" and (not isinstance(executed, int) or executed < 1):
            errors.append(
                "%s: PASS requires executed >= 1" % ERR_ZERO_EXECUTED_PASS
            )

    # --- artifacts ----------------------------------------------------------
    artifacts = evidence.get("artifacts")
    if not isinstance(artifacts, list) or not artifacts:
        errors.append("%s: artifacts must be a non-empty list" % ERR_SCHEMA)
    else:
        for index, artifact in enumerate(artifacts):
            if not isinstance(artifact, dict) or not artifact.get("path"):
                errors.append(
                    "%s: artifacts[%d] must carry a path" % (ERR_SCHEMA, index)
                )

    # --- evidence level floor (spec may only raise, never lower) -----------
    declared = evidence.get("required_evidence_level")
    if declared is not None:
        if declared not in LEVEL_RANK:
            errors.append(
                "%s: required_evidence_level %r is not A/B/C/D"
                % (ERR_LEVEL_DOWNGRADED, declared)
            )
        else:
            floor = minimum_required_level(requirements, risk)
            if LEVEL_RANK[declared] < LEVEL_RANK[floor]:
                errors.append(
                    "%s: required_evidence_level %s is below the capability "
                    "minimum %s (requirements=%s risk=%r)"
                    % (ERR_LEVEL_DOWNGRADED, declared, floor, requirements, risk)
                )
            if declared == "D" and isinstance(result, dict) and result.get("status") == "PASS":
                errors.append(
                    "%s: level D evidence (docs/TODO/history/static inference) "
                    "can never carry PASS on its own" % ERR_LEVEL_D_PASS
                )

    return errors
