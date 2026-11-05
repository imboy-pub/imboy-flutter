#!/usr/bin/env bash
# Compatibility entrypoint for the existing auto_test framework.
# check_auto_test_framework.sh retains static contracts; target selection and
# business verdicts come from the shared execution plan and machine events.
set -uo pipefail
APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE=full
DRY_RUN=false
ARGS=()
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --mode)
      [[ "$#" -ge 2 ]] || { echo '--mode needs a value' >&2; exit 64; }
      case "$2" in
        quick|pr) MODE=pr ;;
        full) MODE=full ;;
        *) echo 'use --mode quick|full or --profile NAME' >&2; exit 64 ;;
      esac
      shift 2 ;;
    --profile)
      [[ "$#" -ge 2 ]] || { echo '--profile needs a value' >&2; exit 64; }
      MODE="$2"; shift 2 ;;
    --dry-run|--plan) DRY_RUN=true; shift ;;
    --device)
      [[ "$#" -ge 2 ]] || { echo '--device needs an explicit ID' >&2; exit 64; }
      export IMBOY_TEST_DEVICE="$2"; shift 2 ;;
    --help|-h)
      printf '%s\n' \
        'Usage: scripts/run_test_suite.sh --profile pr|full|sqlite|e2ee|routes|backend|golden|device-single|device-pair|native-ui|tooling [--dry-run] [selection options]' \
        'Selection: --platform PLATFORM --product-profile PROFILE --suite SUITE --target PATH' \
        'Execution: --artifact-dir DIR --coverage; plan: --output FILE' \
        'full without filters retains all platforms/roles/products; missing prerequisites block it.'
      exit 0 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
cd "$APP_ROOT"
# Bash 3.2 treats an empty array as unset under nounset. Expand it only when
# populated, while preserving each argument (including spaces and empty values).
if $DRY_RUN; then
  exec python3 scripts/auto_test.py execution-plan --profile "$MODE" ${ARGS[@]+"${ARGS[@]}"}
fi
exec python3 scripts/auto_test.py execution-run --profile "$MODE" ${ARGS[@]+"${ARGS[@]}"}
