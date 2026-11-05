#!/usr/bin/env bash
# E2EE 专项沿用统一归属、机器事件判定和对账；不再维护另一套文件列表。
set -uo pipefail
APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec bash "$APP_ROOT/scripts/run_test_suite.sh" --profile e2ee "$@"
