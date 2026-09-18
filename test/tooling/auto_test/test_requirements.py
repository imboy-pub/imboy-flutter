"""Unit tests for scripts/auto_test_lib/requirements.py (Step 4).

Covers ATF-301 (requirement enum sync with the frozen wave1 contract,
legacy migration fail-closed behaviour, unknown requirement/risk rejection
via validate_requirements) and ATF-303 (all current specs migrate with an
empty unmapped set and no permission widening, writing the run-scoped
migration report under RUN_ROOT/steps/).
"""

import json
import sys
import unittest
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from auto_test_lib import requirements as req  # noqa: E402

RUN_ID = "hardening-20260918T151153Z"
CONTRACT_PATH = (
    Path(__file__).resolve().parent / "fixtures" / "interfaces" / "wave1_contracts.json"
)
SPECS_DIR = REPO_ROOT / "test" / "auto_test" / "specs"
REPORT_PATH = (
    REPO_ROOT / "test" / "auto_test" / "reports" / RUN_ID / "steps" / "step4_migration_report.json"
)


class EnumSyncWithFrozenContract(unittest.TestCase):
    """The module enums must stay identical to the Step 1 frozen sketch."""

    def test_enums_match_wave1_contract(self):
        contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
        policy = contract["requirements_policy"]
        self.assertEqual(sorted(req.REQUIREMENTS), sorted(policy["requirement_enum"]))
        self.assertEqual(sorted(req.RISKS), sorted(policy["risk_enum"]))
        self.assertEqual(sorted(req.ERRORS), sorted(policy["error_codes"]))
        mapped_legacy = [
            key for key in policy["legacy_mapping"] if key != "logged_out_state"
        ]
        self.assertEqual(
            sorted(req.LEGACY_REQUIREMENT_MAP), sorted(mapped_legacy)
        )
        self.assertIn("logged_out_state", policy["legacy_mapping"])


class MigrateLegacyRequires(unittest.TestCase):
    """ATF-301: legacy migration is deterministic, de-duplicated, never widens."""

    LEGACY_CASES = {
        "device": "device.android",
        "credentials": "credentials.primary",
        "authorized_test_accounts": "credentials.primary",
        "backend": "backend.local",
        "existing_group": "fixture.existing_group",
        "disposable_account_for_import": "fixture.disposable_account",
        "disposable_local_profile": "fixture.disposable_account",
        "local_fixture_for_write": "fixture.local_write",
        "local_or_authorized_remote": "backend.local",
    }

    def test_each_known_legacy_value_maps_to_its_canonical_requirement(self):
        for legacy, canonical in self.LEGACY_CASES.items():
            with self.subTest(legacy=legacy):
                migrated, unmapped, notes = req.migrate_legacy_requires([legacy])
                self.assertEqual(migrated, [canonical])
                self.assertEqual(unmapped, [])
                self.assertTrue(all(isinstance(n, str) for n in notes))

    def test_local_or_authorized_remote_maps_local_only_with_note(self):
        migrated, unmapped, notes = req.migrate_legacy_requires(
            ["local_or_authorized_remote"]
        )
        self.assertEqual(migrated, ["backend.local"])
        self.assertEqual(unmapped, [])
        self.assertTrue(
            any("never" in n and "wider" in n for n in notes),
            "expected a no-widening note, got %r" % (notes,),
        )

    def test_logged_out_state_is_precondition_not_unmapped(self):
        migrated, unmapped, notes = req.migrate_legacy_requires(["logged_out_state"])
        self.assertEqual(migrated, [])
        self.assertEqual(unmapped, [])
        self.assertTrue(any("state precondition" in n for n in notes))

    def test_unknown_values_fail_closed_into_unmapped(self):
        migrated, unmapped, notes = req.migrate_legacy_requires(
            ["banana", "device.android"]
        )
        self.assertEqual(migrated, ["device.android"])
        self.assertEqual(unmapped, ["banana"])
        self.assertTrue(any("banana" in n for n in notes))

    def test_non_string_entries_fail_closed_into_unmapped(self):
        migrated, unmapped, _ = req.migrate_legacy_requires([42])
        self.assertEqual(migrated, [])
        self.assertEqual(unmapped, [repr(42)])

    def test_canonical_values_pass_through_unchanged(self):
        canonical = sorted(req.REQUIREMENTS)
        migrated, unmapped, _ = req.migrate_legacy_requires(canonical)
        self.assertEqual(migrated, canonical)
        self.assertEqual(unmapped, [])

    def test_duplicates_collapse_to_one_requirement_in_first_seen_order(self):
        migrated, unmapped, _ = req.migrate_legacy_requires(
            ["credentials", "authorized_test_accounts", "credentials"]
        )
        self.assertEqual(migrated, ["credentials.primary"])
        self.assertEqual(unmapped, [])

    def test_full_legacy_domain_never_produces_value_outside_enum(self):
        migrated, unmapped, _ = req.migrate_legacy_requires(
            list(req.LEGACY_REQUIREMENT_MAP)
        )
        self.assertEqual(unmapped, [])
        for value in migrated:
            self.assertIn(value, req.REQUIREMENTS)
            self.assertNotIn("remote", value)
            self.assertNotIn("external", value)


class ValidateRequirements(unittest.TestCase):
    """ATF-301: unknown requirement/risk values return errors (exit 64 input)."""

    @staticmethod
    def _spec(requires=None, risk=None):
        spec = {"runner": {"requires": requires if requires is not None else []}}
        if risk is not None:
            spec["risk"] = risk
        return spec

    def test_fully_valid_spec_has_no_errors(self):
        errors = req.validate_requirements(
            self._spec(
                requires=[
                    "device.android",
                    "credentials.primary",
                    "backend.local",
                    "fixture.local_write",
                ],
                risk="local-write",
            )
        )
        self.assertEqual(errors, [])

    def test_unknown_requirement_value_is_reported(self):
        errors = req.validate_requirements(self._spec(requires=["device"]))
        self.assertTrue(errors)
        self.assertTrue(any(req.UNKNOWN_REQUIREMENT in e for e in errors))

    def test_unknown_risk_value_is_reported(self):
        errors = req.validate_requirements(self._spec(risk="P0"))
        self.assertTrue(errors)
        self.assertTrue(any(req.UNKNOWN_RISK in e for e in errors))

    def test_legacy_risk_levels_are_unknown_until_migrated(self):
        for legacy_risk in ("P0", "P1", "P2"):
            with self.subTest(risk=legacy_risk):
                errors = req.validate_requirements(self._spec(risk=legacy_risk))
                self.assertTrue(any(req.UNKNOWN_RISK in e for e in errors))

    def test_missing_keys_are_not_unknown_values(self):
        self.assertEqual(req.validate_requirements({}), [])
        self.assertEqual(
            req.validate_requirements(self._spec(risk="pure-local")), []
        )


class Atf303SpecMigration(unittest.TestCase):
    """ATF-303: migrate every current spec read-only; empty unmapped, no widening.

    Also writes the run-scoped summary to
    ``test/auto_test/reports/<run-id>/steps/step4_migration_report.json``.
    """

    def test_all_specs_migrate_without_unmapped_or_widening(self):
        spec_paths = sorted(SPECS_DIR.glob("*.json"))
        self.assertEqual(
            len(spec_paths),
            25,
            "Step 1 sampled 25 specs; drift must be re-baselined before Step 4 "
            "acceptance (found %d)" % len(spec_paths),
        )

        entries = []
        unmapped_by_spec = {}
        legacy_histogram = Counter()
        migrated_histogram = Counter()

        for path in spec_paths:
            spec = json.loads(path.read_text(encoding="utf-8"))
            spec_id = spec.get("id") or path.stem
            legacy = list((spec.get("runner") or {}).get("requires") or [])
            migrated, unmapped, notes = req.migrate_legacy_requires(legacy)

            legacy_histogram.update(legacy)
            migrated_histogram.update(migrated)
            if unmapped:
                unmapped_by_spec[spec_id] = unmapped
            entries.append(
                {
                    "spec_id": spec_id,
                    "legacy": legacy,
                    "migrated": migrated,
                    "notes": notes,
                }
            )

            # Every produced value must be a legal enum member.
            for value in migrated:
                self.assertIn(value, req.REQUIREMENTS, "%s produced %r" % (spec_id, value))

            # No widening: the remote half of local_or_authorized_remote may
            # only ever surface as backend.local, never anything wider.
            if "local_or_authorized_remote" in legacy:
                self.assertIn(
                    "backend.local",
                    migrated,
                    "%s: local_or_authorized_remote must map to backend.local" % spec_id,
                )
                for value in migrated:
                    self.assertNotIn("remote", value)
                    self.assertNotIn("external", value)

        self.assertEqual(
            unmapped_by_spec,
            {},
            "specs with unmapped legacy requirements (fail-closed): %r"
            % (unmapped_by_spec,),
        )

        report = {
            "schema_version": 1,
            "run_id": RUN_ID,
            "step": 4,
            "acceptance": "ATF-303",
            "spec_count": len(entries),
            "unmapped_total": sum(len(v) for v in unmapped_by_spec.values()),
            "entries": entries,
            "histogram": {
                "legacy": dict(sorted(legacy_histogram.items())),
                "migrated": dict(sorted(migrated_histogram.items())),
            },
        }
        REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
        REPORT_PATH.write_text(
            json.dumps(report, indent=2, sort_keys=True, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        self.assertTrue(REPORT_PATH.is_file())
        reloaded = json.loads(REPORT_PATH.read_text(encoding="utf-8"))
        self.assertEqual(reloaded["spec_count"], 25)
        self.assertEqual(reloaded["unmapped_total"], 0)


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
