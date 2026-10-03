"""Exact-hit and compatibility-rebind result cache (Step 6).

Source of truth: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md
§4.3 (cache binding contract) and Step 6 acceptance ATF-502.

Two strictly separated mechanisms sharing one judgment core:

- **exact_hit** -- only when every CacheKey field (heads, target/runner/
  config/dependency hashes, environment + device fingerprints, level and the
  whole extra_binding dict) is equal. Level-A / local-write keys additionally
  bind the current run (run_id, fixture namespace, marker, account
  fingerprint, seed and session-state generations) and can never rebind
  across runs or commits.
- **compatibility_rebind** -- not a cache hit: only level B/C evidence whose
  evidence HEAD is an ancestor of the final HEAD, with closure/runner/
  config/env hashes fully equal, may generate a *new* rebind record pointing
  at the final HEAD. Level A / E2EE real-client / local-write evidence is
  always refused and must be re-executed on the final two-repo HEAD.

The store is a single JSON file (default under the ignored RUN_ROOT) written
atomically (tmp file + os.replace).

Python 3.9 stdlib only.
"""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import typing as t
from dataclasses import dataclass, field
from pathlib import Path

#: Extra bindings an A-level / local-write key must always carry.
RUN_SCOPED_BINDINGS: t.Tuple[str, ...] = (
    "run_id",
    "fixture_namespace",
    "marker",
    "account_fingerprint",
    "seed_generation",
    "session_state_generation",
)

_LEVEL_ORDER = {"D": 0, "C": 1, "B": 2, "A": 3}

ERR_RUN_BINDING_MISSING = "RUN_BINDING_MISSING"
ERR_REBIND_FORBIDDEN_LEVEL = "REBIND_FORBIDDEN_LEVEL"
ERR_REBIND_FORBIDDEN_LOCAL_WRITE = "REBIND_FORBIDDEN_LOCAL_WRITE"
ERR_REBIND_ANCESTRY = "REBIND_ANCESTOR_REQUIRED"
ERR_REBIND_HASH_MISMATCH = "REBIND_HASH_MISMATCH"
ERR_REBIND_HEAD = "REBIND_INVALID_HEAD"
ERR_REBIND_EVIDENCE = "REBIND_EVIDENCE_INVALID"


@dataclass
class CacheKey:
    """Full binding tuple of one executed result.

    Any change in any field (including nested extra_binding) must produce a
    cache miss for exact lookup.
    """

    app_head: str
    backend_head: str
    target_sha256: str
    runner_sha256: str
    config_sha256: str
    dependency_content_sha256: str
    environment_fingerprint: str
    device_fingerprint: str
    level: str = "C"
    local_write: bool = False
    extra_binding: t.Dict[str, t.Any] = field(default_factory=dict)

    # -- run scoping -----------------------------------------------------
    def run_scoped(self) -> bool:
        """A-level or local-write evidence is bound to the current run."""
        return self.level == "A" or bool(self.local_write)

    def is_rebindable(self) -> bool:
        """Run-scoped keys are never rebindable across commits/runs."""
        return not self.run_scoped()

    def required_run_bindings(self) -> t.Tuple[str, ...]:
        return RUN_SCOPED_BINDINGS if self.run_scoped() else ()

    def binding_errors(self) -> t.List[str]:
        """Fail-closed completeness check of the binding tuple."""
        errors: t.List[str] = []
        if self.level not in ("A", "B", "C"):
            errors.append(
                "%s: level must be A/B/C (D evidence is never cacheable), got %r"
                % (ERR_REBIND_FORBIDDEN_LEVEL, self.level)
            )
        for name in self.required_run_bindings():
            if not self.extra_binding.get(name):
                errors.append("%s: %s" % (ERR_RUN_BINDING_MISSING, name))
        return errors

    def fingerprint(self) -> str:
        """Stable sha256 over the canonical key dict."""
        payload = json.dumps(self.to_dict(), sort_keys=True, ensure_ascii=False)
        return hashlib.sha256(payload.encode("utf-8")).hexdigest()

    def to_dict(self) -> t.Dict[str, t.Any]:
        return {
            "app_head": self.app_head,
            "backend_head": self.backend_head,
            "target_sha256": self.target_sha256,
            "runner_sha256": self.runner_sha256,
            "config_sha256": self.config_sha256,
            "dependency_content_sha256": self.dependency_content_sha256,
            "environment_fingerprint": self.environment_fingerprint,
            "device_fingerprint": self.device_fingerprint,
            "level": self.level,
            "local_write": bool(self.local_write),
            "extra_binding": dict(self.extra_binding),
        }


def shared_reuse_gate(
    level: str, local_write: bool, mechanism: str
) -> t.Optional[str]:
    """Single judgment core used by BOTH mechanisms (plan Step 6).

    ``mechanism`` is ``"exact"`` or ``"rebind"``:

    - exact reuse needs no level gate here (it already demands full-field
      equality, which for run-scoped keys pins the very same run);
    - rebind is refused for level A / local-write / non-B,C levels --
      the same denial reasons apply wherever cross-HEAD reuse is attempted.
    """
    if mechanism == "exact":
        return None
    if level == "A":
        return "%s: level-A real-client evidence must re-run on the final HEAD" % (
            ERR_REBIND_FORBIDDEN_LEVEL,
        )
    if local_write:
        return "%s: local-write evidence must re-run on the final HEAD" % (
            ERR_REBIND_FORBIDDEN_LOCAL_WRITE,
        )
    if level not in ("B", "C"):
        return "%s: only B/C evidence may rebind (got %r)" % (
            ERR_REBIND_FORBIDDEN_LEVEL,
            level,
        )
    return None


class CacheStore:
    """JSON-file record store with atomic writes."""

    def __init__(self, path: t.Union[str, Path]):
        self.path = Path(path)

    def load(self) -> t.List[t.Dict[str, t.Any]]:
        if not self.path.is_file():
            return []
        try:
            data = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return []
        if isinstance(data, dict):
            records = data.get("records")
        else:
            records = data
        if not isinstance(records, list):
            return []
        return [r for r in records if isinstance(r, dict)]

    def _write(self, records: t.List[t.Dict[str, t.Any]]) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_name(self.path.name + ".tmp.%d" % os.getpid())
        payload = json.dumps(
            {"schema_version": 1, "records": records},
            ensure_ascii=False,
            indent=2,
            sort_keys=True,
        )
        with open(tmp, "w", encoding="utf-8") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp, self.path)

    def append(self, key: CacheKey, evidence: t.Dict[str, t.Any]) -> None:
        records = self.load()
        records.append(
            {"key": key.to_dict(), "key_fingerprint": key.fingerprint(),
             "evidence": evidence}
        )
        self._write(records)


def exact_hit(
    key: CacheKey, store: CacheStore
) -> t.Optional[t.Dict[str, t.Any]]:
    """Return the stored evidence only on full-field equality, else None.

    Raises ValueError when the key itself is incompletely bound (fail closed,
    e.g. an A-level key missing its run bindings).
    """
    errors = key.binding_errors()
    if errors:
        raise ValueError("; ".join(errors))
    denial = shared_reuse_gate(key.level, key.local_write, "exact")
    if denial is not None:  # pragma: no cover - exact never denies today
        raise ValueError(denial)
    wanted = key.to_dict()
    for record in store.load():
        if record.get("key") == wanted:
            return record.get("evidence")
    return None


def record_hit(key: CacheKey, evidence: t.Dict[str, t.Any], store: CacheStore) -> None:
    """Persist one executed result under its full binding key."""
    errors = key.binding_errors()
    if errors:
        raise ValueError("; ".join(errors))
    store.append(key, evidence)


def git_is_ancestor(
    ancestor: str, descendant: str, repo: t.Union[str, Path]
) -> bool:
    """``git merge-base --is-ancestor`` via subprocess (injectable in tests)."""
    completed = subprocess.run(
        ["git", "--no-replace-objects", "-C", str(repo), "merge-base",
         "--is-ancestor", ancestor, descendant],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
        env=dict(os.environ, GIT_GRAFT_FILE=os.devnull),
        timeout=10,
    )
    return completed.returncode == 0


_HeadPredicate = t.Callable[[str, str], bool]


def compatibility_rebind(
    old_evidence: t.Dict[str, t.Any],
    final_head: str,
    *,
    closure_hash_match: bool,
    level: str,
    local_write: bool = False,
    runner_hash_match: bool = True,
    config_hash_match: bool = True,
    env_fingerprint_match: bool = True,
    is_ancestor: t.Optional[_HeadPredicate] = None,
    repo: t.Union[str, Path] = ".",
) -> t.Tuple[t.Optional[t.Dict[str, t.Any]], t.Optional[str]]:
    """Try to rebind B/C evidence onto ``final_head``.

    Returns ``(record, None)`` on success or ``(None, reason)`` on refusal.
    Success requires: level in (B, C) via the shared gate, the evidence HEAD
    being an ancestor of ``final_head`` (git merge-base --is-ancestor, or the
    injected predicate), and closure/runner/config/env hashes all equal.
    """
    denial = shared_reuse_gate(level, local_write, "rebind")
    if denial is not None:
        return None, denial

    old_head = old_evidence.get("head") if isinstance(old_evidence, dict) else None
    if not isinstance(old_head, str) or len(old_head) != 40:
        return None, "%s: evidence head %r is not a 40-char sha" % (
            ERR_REBIND_EVIDENCE,
            old_head,
        )
    if not isinstance(final_head, str) or len(final_head) != 40:
        return None, "%s: final head %r is not a 40-char sha" % (
            ERR_REBIND_HEAD,
            final_head,
        )
    if old_head == final_head:
        # Same HEAD is an exact-hit concern, not a rebind.
        return None, "%s: evidence head already equals the final head" % (
            ERR_REBIND_EVIDENCE,
        )

    predicate = is_ancestor or (lambda a, d: git_is_ancestor(a, d, repo))
    try:
        ancestor_ok = bool(predicate(old_head, final_head))
    except Exception as exc:  # fail closed on any predicate/git failure
        return None, "%s: ancestry check failed: %s" % (ERR_REBIND_ANCESTRY, exc)
    if not ancestor_ok:
        return None, "%s: evidence head %s is not an ancestor of %s" % (
            ERR_REBIND_ANCESTRY,
            old_head,
            final_head,
        )

    hash_checks = {
        "closure_hash_match": closure_hash_match,
        "runner_hash_match": runner_hash_match,
        "config_hash_match": config_hash_match,
        "env_fingerprint_match": env_fingerprint_match,
    }
    if not all(hash_checks.values()):
        failed = sorted(name for name, ok in hash_checks.items() if not ok)
        return None, "%s: %s" % (ERR_REBIND_HASH_MISMATCH, ",".join(failed))

    record = {
        "schema_version": 1,
        "kind": "compatibility_rebind",
        "head": final_head,
        "level": level,
        "original": {
            "head": old_head,
            "run_id": old_evidence.get("run_id"),
            "target": old_evidence.get("target"),
            "dependency_closure": old_evidence.get("dependency_closure"),
        },
        "hash_checks": hash_checks,
        "result": old_evidence.get("result"),
    }
    return record, None
