# imboyapp auto-test control-plane library package.
#
# Part of the auto-test framework hardening plan
# (docs/plans/2026-09-18-auto-test-framework-hardening-plan.md, Step 3,
# run_id hardening-20260918T151153Z).
#
# Modules:
#   machine_events -- parse `flutter test --machine` JSONL into ParsedResult.
#   result         -- unique-target planning, retry classification, exit codes.
#   report         -- deterministic stdlib-only HTML report renderer.
#
# Constraints: Python 3.9 stdlib only; no third-party orchestration deps;
# the legacy CLI entry `scripts/auto_test.py` is NOT modified by Step 3.
