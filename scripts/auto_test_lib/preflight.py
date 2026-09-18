"""Fail-closed preflight decision for auto-test targets (Step 4).

Evaluates a target policy against devices/env/backend identity BEFORE any
Flutter/ADB/Patrol/network subprocess may be spawned. Python 3.9 stdlib only.

Design invariants (plan Step 4 / §10):

* ``external-impact`` risk is always blocked in the generic runner; no
  environment variable can relax this.
* No relaxation path exists for remote targets at all: an ``allow`` env var
  (e.g. IMBOY_ALLOW_REMOTE_TEST) is intentionally never read.
* ``local-write`` requires every resolved api/ws target to be provably local:
  IPv4 127.0.0.0/8, IPv6 ::1, or a path-style Unix socket. The literal
  hostname ``localhost`` is NOT accepted as loopback proof.
* Any blocked decision implies ``spawn_forbidden=True`` / ``allowed=False``.
"""

from __future__ import annotations

import ipaddress
import os
import sys
import typing as t
from urllib.parse import urlsplit

_SCRIPTS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir))
if _SCRIPTS_DIR not in sys.path:  # allow standalone import outside test runner
    sys.path.insert(0, _SCRIPTS_DIR)

from auto_test_lib import requirements  # noqa: E402  (path set above)

_LOOPBACK_V4 = ipaddress.ip_network("127.0.0.0/8")
_LOOPBACK_V6 = ipaddress.ip_address("::1")

# Host classification kinds.
KIND_ABSENT = "absent"
KIND_LOOPBACK = "loopback"
KIND_UNIX_SOCKET = "unix_socket"
KIND_REMOTE = "remote"
KIND_UNRESOLVABLE = "unresolvable"

_LOCAL_KINDS = frozenset({KIND_LOOPBACK, KIND_UNIX_SOCKET})


class PreflightDecision(t.NamedTuple):
    """Outcome of :func:`evaluate`.

    ``resolved_hosts`` maps ``{"api": ..., "ws": ...}`` to the urlsplit
    hostname (loopback or remote), ``"unix:<path>"`` for Unix sockets, or
    ``None`` when the URL is absent/unresolvable.
    """

    allowed: bool
    spawn_forbidden: bool
    blocked_reasons: t.List[str]
    error_codes: t.List[str]
    resolved_hosts: t.Dict[str, t.Optional[str]]


def _classify_url(url: t.Optional[str]) -> t.Tuple[str, t.Optional[str]]:
    """Classify a URL as absent/loopback/unix_socket/remote/unresolvable."""
    if not url:
        return KIND_ABSENT, None
    parts = urlsplit(url)
    host = parts.hostname
    if host:
        host = host.lower()
        try:
            ip = ipaddress.ip_address(host)
        except ValueError:
            # DNS names (including "localhost") prove nothing about locality.
            return KIND_REMOTE, host
        if ip.version == 4 and ip in _LOOPBACK_V4:
            return KIND_LOOPBACK, host
        if ip.version == 6 and ip == _LOOPBACK_V6:
            return KIND_LOOPBACK, host
        return KIND_REMOTE, host
    if parts.path.startswith("/"):
        return KIND_UNIX_SOCKET, "unix:" + parts.path
    return KIND_UNRESOLVABLE, None


def evaluate(
    policy: t.Mapping[str, t.Any],
    env: t.Mapping[str, str],
    devices: t.Sequence[str],
) -> PreflightDecision:
    """Evaluate whether a target may spawn processes; always fail-closed.

    ``policy`` keys: ``requirements`` (list), ``risk`` (str), ``api_url``,
    ``ws_url``, ``backend_head``, ``backend_profile_fingerprint``.
    ``env`` is the effective environment mapping (never os.environ here, so
    tests stay hermetic). No value inside ``env`` can relax a rule.
    """
    policy = policy or {}
    env = env or {}
    devices = list(devices or [])
    reqs = list(policy.get("requirements") or [])
    risk = policy.get("risk")

    blocked: t.List[str] = []
    codes: t.List[str] = []

    def block(code: str, reason: str) -> None:
        if code not in codes:
            codes.append(code)
        blocked.append("%s: %s" % (code, reason))

    def requirement_prefix(prefix: str) -> bool:
        return any(
            isinstance(r, str) and r.startswith(prefix + ".") for r in reqs
        )

    # Unknown requirement/risk values fail closed here as well; the same
    # values are reported by requirements.validate_requirements (exit 64).
    for value in reqs:
        if value not in requirements.REQUIREMENTS:
            block(
                requirements.UNKNOWN_REQUIREMENT,
                "unknown requirement %r is not in the finite enum" % (value,),
            )
    if risk is not None and risk not in requirements.RISKS:
        block(
            requirements.UNKNOWN_RISK,
            "unknown risk %r is not in the risk enum" % (risk,),
        )

    if requirement_prefix("device") and not devices:
        block(
            requirements.DEVICE_MISSING,
            "device.* required but no devices are available",
        )

    if requirement_prefix("credentials") and (
        not env.get("IMBOY_TEST_PHONE") or not env.get("IMBOY_TEST_PASSWORD")
    ):
        block(
            requirements.CREDENTIALS_MISSING,
            "IMBOY_TEST_PHONE/IMBOY_TEST_PASSWORD are not both present",
        )

    if requirement_prefix("backend") and (
        not policy.get("backend_head")
        or not policy.get("backend_profile_fingerprint")
    ):
        block(
            requirements.BACKEND_IDENTITY_UNVERIFIED,
            "backend.* requires backend_head and a secret-free "
            "backend_profile_fingerprint",
        )

    if risk == "external-impact":
        block(
            requirements.EXTERNAL_IMPACT_ALWAYS_BLOCKED,
            "external-impact targets are always blocked in the generic "
            "runner; no environment variable can relax this",
        )

    classified = {
        "api": _classify_url(policy.get("api_url")),
        "ws": _classify_url(policy.get("ws_url")),
    }
    resolved_hosts = {name: host for name, (_, host) in classified.items()}

    if risk == "local-write":
        for name, (kind, host) in classified.items():
            if kind not in _LOCAL_KINDS and kind != KIND_ABSENT:
                block(
                    requirements.LOCAL_WRITE_NON_LOOPBACK,
                    "%s_url target %r is not provably loopback "
                    "(127.0.0.0/8, ::1) or a Unix socket; 'localhost' is not "
                    "loopback proof" % (name, host),
                )

    for name, (kind, host) in classified.items():
        if kind in (KIND_REMOTE, KIND_UNRESOLVABLE):
            block(
                requirements.REMOTE_TARGET_FORBIDDEN,
                "%s_url target %r is not loopback/unix; remote targets are "
                "forbidden and no allow-env relaxation path exists"
                % (name, host),
            )

    allowed = not blocked
    return PreflightDecision(
        allowed=allowed,
        spawn_forbidden=not allowed,
        blocked_reasons=blocked,
        error_codes=codes,
        resolved_hosts=resolved_hosts,
    )
