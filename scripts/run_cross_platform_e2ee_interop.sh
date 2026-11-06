#!/usr/bin/env bash
# Existing offline E2EE entrypoint; the shared plan owns platforms, roles and verdicts.
# Device IDs must be supplied explicitly; --dry-run needs no device or SDK.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/run_test_suite.sh" --profile device-pair \
  --target integration_test/e2ee_cross_platform_interop_test.dart "$@"
