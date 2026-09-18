"""Unit tests for scripts/auto_test_lib/preflight.py (Step 4).

Covers ATF-301 (per-requirement satisfied/missing matrix over the full enum,
unknown requirement/risk fail-closed in evaluate) and ATF-302 (a generic
allow env such as IMBOY_ALLOW_REMOTE_TEST=1 can never relax remote,
local-write non-loopback or external-impact blocking). All env values are
placeholders; no credentials are embedded.
"""

import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from auto_test_lib import preflight  # noqa: E402
from auto_test_lib import requirements as req  # noqa: E402

# Placeholder values only - presence, never real credentials.
BASE_ENV = {
    "IMBOY_TEST_PHONE": "placeholder-phone-present",
    "IMBOY_TEST_PASSWORD": "placeholder-password-present",
}
BASE_DEVICES = ["placeholder-device-id"]
BASE_BACKEND = {
    "backend_head": "a" * 40,
    "backend_profile_fingerprint": "sha256:placeholder-profile-fingerprint",
}


def local_policy(requirements=None, **overrides):
    """A fully local, fully satisfied local-write policy by default."""
    policy = {
        "requirements": requirements if requirements is not None else [],
        "risk": "local-write",
        "api_url": "http://127.0.0.1:9800",
        "ws_url": "ws://127.0.0.1:9801",
    }
    policy.update(BASE_BACKEND)
    policy.update(overrides)
    return policy


def neutral_policy(requirement):
    """Minimal pure-local policy carrying one requirement, no URL targets."""
    policy = {"requirements": [requirement], "risk": "pure-local"}
    policy.update(BASE_BACKEND)
    return policy


class EvaluateAllowedPaths(unittest.TestCase):
    def test_fully_satisfied_local_write_target_is_allowed(self):
        decision = preflight.evaluate(
            local_policy(["device.android", "credentials.primary", "backend.local"]),
            BASE_ENV,
            BASE_DEVICES,
        )
        self.assertTrue(decision.allowed)
        self.assertFalse(decision.spawn_forbidden)
        self.assertEqual(decision.error_codes, [])
        self.assertEqual(decision.blocked_reasons, [])
        self.assertEqual(
            decision.resolved_hosts, {"api": "127.0.0.1", "ws": "127.0.0.1"}
        )

    def test_provably_local_targets_are_allowed_under_local_write(self):
        cases = [
            ("http://127.0.0.1:80", "127.0.0.1"),
            ("http://127.199.0.9:9800", "127.199.0.9"),  # whole 127.0.0.0/8
            ("http://[::1]:8080", "::1"),
            ("ws+unix:///tmp/imboy-test.sock", "unix:/tmp/imboy-test.sock"),
        ]
        for url, resolved in cases:
            with self.subTest(url=url):
                decision = preflight.evaluate(
                    local_policy([], api_url=url, ws_url=None), BASE_ENV, BASE_DEVICES
                )
                self.assertTrue(decision.allowed, decision.blocked_reasons)
                self.assertEqual(decision.resolved_hosts["api"], resolved)

    def test_absent_urls_impose_no_host_constraint(self):
        decision = preflight.evaluate(
            {"requirements": [], "risk": "local-write"}, BASE_ENV, BASE_DEVICES
        )
        self.assertTrue(decision.allowed)
        self.assertEqual(decision.resolved_hosts, {"api": None, "ws": None})


class Atf301PerRequirementMatrix(unittest.TestCase):
    """Every enum requirement gets a satisfied and a missing direction."""

    def test_every_requirement_has_satisfied_and_missing_direction(self):
        for requirement in sorted(req.REQUIREMENTS):
            with self.subTest(requirement=requirement):
                satisfied = preflight.evaluate(
                    neutral_policy(requirement), BASE_ENV, BASE_DEVICES
                )
                self.assertTrue(
                    satisfied.allowed,
                    "%s should be satisfiable: %r" % (requirement, satisfied.blocked_reasons),
                )

                if requirement.startswith("device."):
                    missing = preflight.evaluate(
                        neutral_policy(requirement), BASE_ENV, []
                    )
                    self.assertFalse(missing.allowed)
                    self.assertIn(req.DEVICE_MISSING, missing.error_codes)

                elif requirement.startswith("credentials."):
                    for env in (
                        {},
                        {"IMBOY_TEST_PHONE": "placeholder", "IMBOY_TEST_PASSWORD": ""},
                        {"IMBOY_TEST_PHONE": "", "IMBOY_TEST_PASSWORD": "placeholder"},
                    ):
                        with self.subTest(env=sorted(env.keys())):
                            missing = preflight.evaluate(
                                neutral_policy(requirement), env, BASE_DEVICES
                            )
                            self.assertFalse(missing.allowed)
                            self.assertIn(
                                req.CREDENTIALS_MISSING, missing.error_codes
                            )

                elif requirement.startswith("backend."):
                    for absent_key in ("backend_head", "backend_profile_fingerprint"):
                        with self.subTest(absent=absent_key):
                            policy = neutral_policy(requirement)
                            policy.pop(absent_key)
                            missing = preflight.evaluate(policy, BASE_ENV, BASE_DEVICES)
                            self.assertFalse(missing.allowed)
                            self.assertIn(
                                req.BACKEND_IDENTITY_UNVERIFIED, missing.error_codes
                            )

                else:
                    # fixture.* / authorization.* carry no wave1 runtime gate:
                    # their absence cannot block; presence is validated against
                    # the enum and enforced by the migration/schema layer.
                    without = preflight.evaluate(
                        neutral_policy("device.android"), BASE_ENV, BASE_DEVICES
                    )
                    self.assertTrue(without.allowed)

    def test_unknown_requirement_value_blocks_evaluate(self):
        decision = preflight.evaluate(
            {"requirements": ["totally-made-up-requirement"], "risk": "pure-local"},
            BASE_ENV,
            BASE_DEVICES,
        )
        self.assertFalse(decision.allowed)
        self.assertTrue(decision.spawn_forbidden)
        self.assertIn(req.UNKNOWN_REQUIREMENT, decision.error_codes)

    def test_unknown_risk_value_blocks_evaluate(self):
        decision = preflight.evaluate(
            {"requirements": [], "risk": "P0"}, BASE_ENV, BASE_DEVICES
        )
        self.assertFalse(decision.allowed)
        self.assertIn(req.UNKNOWN_RISK, decision.error_codes)


class Atf302AllowEnvCannotRelax(unittest.TestCase):
    """Generic allow envs must not unblock remote/local-write/external-impact."""

    ALLOW_ENV = dict(
        BASE_ENV,
        IMBOY_ALLOW_REMOTE_TEST="1",
        IMBOY_ALLOW_REMOTE="true",
        IMBOY_SKIP_PREFLIGHT="1",
    )

    def test_remote_api_target_still_blocked_with_allow_env(self):
        decision = preflight.evaluate(
            local_policy(api_url="http://203.0.113.10:9800"),  # TEST-NET-3
            self.ALLOW_ENV,
            BASE_DEVICES,
        )
        self.assertFalse(decision.allowed)
        self.assertTrue(decision.spawn_forbidden)
        self.assertIn(req.REMOTE_TARGET_FORBIDDEN, decision.error_codes)
        self.assertIn(req.LOCAL_WRITE_NON_LOOPBACK, decision.error_codes)

    def test_remote_ws_target_blocked_even_under_lower_risk(self):
        decision = preflight.evaluate(
            {
                "requirements": [],
                "risk": "device-readonly",
                "api_url": "http://127.0.0.1:9800",
                "ws_url": "ws://198.51.100.7:9801",  # TEST-NET-2
            },
            self.ALLOW_ENV,
            BASE_DEVICES,
        )
        self.assertFalse(decision.allowed)
        self.assertIn(req.REMOTE_TARGET_FORBIDDEN, decision.error_codes)
        self.assertNotIn(req.LOCAL_WRITE_NON_LOOPBACK, decision.error_codes)

    def test_localhost_hostname_is_not_loopback_proof(self):
        decision = preflight.evaluate(
            local_policy(api_url="http://localhost:9800"), self.ALLOW_ENV, BASE_DEVICES
        )
        self.assertFalse(decision.allowed)
        self.assertIn(req.LOCAL_WRITE_NON_LOOPBACK, decision.error_codes)
        self.assertIn(req.REMOTE_TARGET_FORBIDDEN, decision.error_codes)
        self.assertEqual(decision.resolved_hosts["api"], "localhost")

    def test_external_impact_always_blocked_with_everything_satisfied(self):
        decision = preflight.evaluate(
            local_policy(
                ["device.android", "credentials.primary", "backend.local"],
                risk="external-impact",
            ),
            self.ALLOW_ENV,
            BASE_DEVICES,
        )
        self.assertFalse(decision.allowed)
        self.assertTrue(decision.spawn_forbidden)
        self.assertIn(req.EXTERNAL_IMPACT_ALWAYS_BLOCKED, decision.error_codes)

    def test_private_lan_address_is_not_local_authorization(self):
        decision = preflight.evaluate(
            local_policy(ws_url="ws://192.168.1.10:9801"), self.ALLOW_ENV, BASE_DEVICES
        )
        self.assertFalse(decision.allowed)
        self.assertIn(req.REMOTE_TARGET_FORBIDDEN, decision.error_codes)
        self.assertIn(req.LOCAL_WRITE_NON_LOOPBACK, decision.error_codes)


class BlockedAlwaysForbidsSpawn(unittest.TestCase):
    """Any blocked decision implies allowed=False and spawn_forbidden=True."""

    def test_all_blocking_scenarios_forbid_spawn(self):
        scenarios = {
            "device-missing": (
                neutral_policy("device.android"), BASE_ENV, [],
            ),
            "credentials-missing": (
                neutral_policy("credentials.primary"), {}, BASE_DEVICES,
            ),
            "backend-identity": (
                {"requirements": ["backend.local"], "risk": "pure-local"},
                BASE_ENV,
                BASE_DEVICES,
            ),
            "external-impact": (
                {"requirements": [], "risk": "external-impact"}, BASE_ENV, BASE_DEVICES,
            ),
            "remote-api": (
                local_policy(api_url="http://203.0.113.10:80"), BASE_ENV, BASE_DEVICES,
            ),
            "unresolvable-url": (
                local_policy(api_url="not-a-url"), BASE_ENV, BASE_DEVICES,
            ),
            "unknown-requirement": (
                {"requirements": ["???"], "risk": "pure-local"}, BASE_ENV, BASE_DEVICES,
            ),
        }
        for name, (policy, env, devices) in scenarios.items():
            with self.subTest(scenario=name):
                decision = preflight.evaluate(policy, env, devices)
                self.assertFalse(decision.allowed)
                self.assertTrue(decision.spawn_forbidden)
                self.assertTrue(decision.blocked_reasons)
                self.assertTrue(decision.error_codes)
                for code in decision.error_codes:
                    self.assertIn(code, req.ERRORS)


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
