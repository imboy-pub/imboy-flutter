#!/usr/bin/env bash
# Compatibility wrapper for the catalog's owned SQLite interruption coordinator.
# Usage: IMBOY_TEST_ISOLATED=true bash scripts/run_kill_replay.sh DEVICE ATTEMPT [--dry-run|--artifact-dir DIR]
# No device or attempt defaults; missing prerequisites produce ENV_MISSING.
set -euo pipefail
APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "$#" -gt 0 && "$1" != --* ]]; then
  export IMBOY_EXECUTION_DEVICE_ANDROID="$1"
  shift
fi
if [[ "$#" -gt 0 && "$1" != --* ]]; then
  export IMBOY_KILL_REPLAY_ATTEMPT="$1"
  shift
fi
exec bash "$APP_ROOT/scripts/run_test_suite.sh" \
  --profile device-single --platform android \
  --target integration_test/sqlite_migration/sqlite_migration_kill_replay_test.dart "$@"
