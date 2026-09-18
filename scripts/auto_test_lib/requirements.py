"""Finite requirement/risk enums and fail-closed legacy migration (Step 4).

Contracts are frozen in
``test/tooling/auto_test/fixtures/interfaces/wave1_contracts.json``
(``requirements_policy`` section, owner_step=step4). Python 3.9 stdlib only.
This module performs no I/O, reads no environment variables and never
widens permissions during migration.
"""

from __future__ import annotations

import typing as t

# ---------------------------------------------------------------------------
# Finite enums (must stay identical to wave1_contracts.json requirements_policy)
# ---------------------------------------------------------------------------

REQUIREMENTS: t.FrozenSet[str] = frozenset({
    "device.android",
    "device.ios",
    "device.macos",
    "credentials.primary",
    "credentials.peer",
    "backend.local",
    "backend.strict_e2ee",
    "fixture.existing_group",
    "fixture.disposable_account",
    "fixture.local_write",
    "authorization.business_write",
    "authorization.external_readonly",
})

RISKS: t.FrozenSet[str] = frozenset({
    "pure-local",
    "device-readonly",
    "local-write",
    "external-impact",
})

# Error codes, identical to wave1_contracts.json requirements_policy.error_codes.
UNKNOWN_REQUIREMENT = "UNKNOWN_REQUIREMENT"
UNKNOWN_RISK = "UNKNOWN_RISK"
REMOTE_TARGET_FORBIDDEN = "REMOTE_TARGET_FORBIDDEN"
EXTERNAL_IMPACT_ALWAYS_BLOCKED = "EXTERNAL_IMPACT_ALWAYS_BLOCKED"
BACKEND_IDENTITY_UNVERIFIED = "BACKEND_IDENTITY_UNVERIFIED"
CREDENTIALS_MISSING = "CREDENTIALS_MISSING"
DEVICE_MISSING = "DEVICE_MISSING"
LOCAL_WRITE_NON_LOOPBACK = "LOCAL_WRITE_NON_LOOPBACK"

ERRORS: t.FrozenSet[str] = frozenset({
    UNKNOWN_REQUIREMENT,
    UNKNOWN_RISK,
    REMOTE_TARGET_FORBIDDEN,
    EXTERNAL_IMPACT_ALWAYS_BLOCKED,
    BACKEND_IDENTITY_UNVERIFIED,
    CREDENTIALS_MISSING,
    DEVICE_MISSING,
    LOCAL_WRITE_NON_LOOPBACK,
})

# ---------------------------------------------------------------------------
# Legacy free-text runner.requires migration
# ---------------------------------------------------------------------------

LEGACY_REQUIREMENT_MAP: t.Dict[str, str] = {
    "device": "device.android",
    "credentials": "credentials.primary",
    "authorized_test_accounts": "credentials.primary",
    "backend": "backend.local",
    "existing_group": "fixture.existing_group",
    "disposable_account_for_import": "fixture.disposable_account",
    "disposable_local_profile": "fixture.disposable_account",
    "local_fixture_for_write": "fixture.local_write",
    # The "authorized remote" half is deliberately unrepresentable in the
    # finite enum; this entry may only ever migrate to the local value and
    # must never be widened to any remote/external-friendly value.
    "local_or_authorized_remote": "backend.local",
}

# Recognized legacy names that intentionally produce no requirement. They are
# NOT "unmapped": unmapped is reserved for unknown (fail-closed) values.
LEGACY_STATE_PRECONDITIONS: t.Dict[str, str] = {
    "logged_out_state": (
        "logged_out_state is a state precondition, not an environment "
        "requirement; no requirement emitted"
    ),
}

NO_WIDENING_NOTE = (
    "local_or_authorized_remote: remote part is not representable in the "
    "finite enum; migrated only to backend.local and never to any wider "
    "remote/external value"
)


def migrate_legacy_requires(
    values: t.Iterable[str],
) -> t.Tuple[t.List[str], t.List[str], t.List[str]]:
    """Migrate legacy free-text ``runner.requires`` entries to the enum.

    Returns ``(migrated, unmapped, notes)``:

    * ``migrated`` - order-preserving, de-duplicated canonical values; every
      entry is guaranteed to be a member of :data:`REQUIREMENTS`.
    * ``unmapped`` - unknown values that could not be represented. Non-empty
      means fail-closed: the caller must reject the spec (validate exit 64),
      never guess a replacement.
    * ``notes`` - human-readable migration annotations (no-widening remarks,
      state preconditions, unknown-value listings).

    Canonical enum values pass through unchanged, making the function
    idempotent over already-migrated specs.
    """
    migrated: t.List[str] = []
    unmapped: t.List[str] = []
    notes: t.List[str] = []
    emitted: t.Set[str] = set()

    for value in list(values or []):
        if not isinstance(value, str):
            unmapped.append(repr(value))
            notes.append("non-string requirement entry: %r" % (value,))
            continue
        if value in REQUIREMENTS:
            target: t.Optional[str] = value
        elif value in LEGACY_REQUIREMENT_MAP:
            target = LEGACY_REQUIREMENT_MAP[value]
            if value == "local_or_authorized_remote":
                notes.append(NO_WIDENING_NOTE)
        elif value in LEGACY_STATE_PRECONDITIONS:
            notes.append(LEGACY_STATE_PRECONDITIONS[value])
            continue
        else:
            unmapped.append(value)
            notes.append("unknown legacy requirement: %s" % value)
            continue
        if target not in emitted:
            emitted.add(target)
            migrated.append(target)

    return migrated, unmapped, notes


def validate_requirements(spec: t.Mapping[str, t.Any]) -> t.List[str]:
    """Return validate errors (caller exits 64) for unknown values.

    Checks ``spec["runner"]["requires"]`` against :data:`REQUIREMENTS` and
    ``spec["risk"]`` against :data:`RISKS`. Unknown values - including not
    yet migrated legacy names such as ``device`` or risk levels ``P0/P1/P2``
    - produce error messages prefixed with the matching error code. An empty
    list means the requirement/risk surface is known; missing keys are schema
    concerns judged elsewhere.
    """
    errors: t.List[str] = []
    runner = spec.get("runner") or {}
    requires = runner.get("requires") or []
    if not isinstance(requires, list):
        errors.append(
            "%s: runner.requires must be a list, got %s"
            % (UNKNOWN_REQUIREMENT, type(requires).__name__)
        )
        requires = []
    for value in requires:
        if value not in REQUIREMENTS:
            errors.append(
                "%s: runner.requires value %r is not in the finite requirement "
                "enum (legacy values must be migrated first)"
                % (UNKNOWN_REQUIREMENT, value)
            )
    risk = spec.get("risk")
    if risk is not None and risk not in RISKS:
        errors.append(
            "%s: risk value %r is not in the risk enum "
            "(legacy P0/P1/P2 must be migrated first)" % (UNKNOWN_RISK, risk)
        )
    return errors
