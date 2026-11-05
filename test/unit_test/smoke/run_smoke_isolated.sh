#!/usr/bin/env bash
# The shared catalog expands the route registry into one process per route.
# Usage: bash test/unit_test/smoke/run_smoke_isolated.sh [--quiet] [--include-quarantined] [--route NAME]... [--dry-run]
set -euo pipefail
cd "$(dirname "$0")/../../.."

COMMAND=execution-run
ARGS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --quiet) shift ;; # The unified runner already prints only the final summary.
    --include-quarantined)
      export IMBOY_SMOKE_INCLUDE_QUARANTINED=true
      shift ;;
    --route)
      [ "$#" -ge 2 ] || { echo 'ERROR: --route requires a name' >&2; exit 64; }
      ARGS+=(--variant "route:$2")
      shift 2 ;;
    --dry-run) COMMAND=execution-plan; shift ;;
    --help|-h)
      echo 'Usage: run_smoke_isolated.sh [--quiet] [--include-quarantined] [--route NAME]... [--dry-run]'
      echo 'SMOKE_OUTPUT_DIR retains unified plan, results and process evidence.'
      exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 64 ;;
  esac
done
case "$(uname -s)" in
  Darwin) PLATFORM=macos ;;
  Linux) PLATFORM=linux ;;
  *) echo 'ERROR: route-smoke requires a declared linux or macos host' >&2; exit 64 ;;
esac

if [ "$COMMAND" = execution-run ]; then
  OUTPUT_DIR="${SMOKE_OUTPUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/imboy-route-smoke.XXXXXX")}"
  mkdir -p "$OUTPUT_DIR"
  OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd -P)"
  case "$OUTPUT_DIR/" in
    "$(pwd -P)/"*) echo 'ERROR: smoke output must be outside the repository' >&2; exit 64 ;;
  esac
  ARGS+=(--artifact-dir "$OUTPUT_DIR")
fi
# --platform deliberately creates a scoped run. It never pretends that the other
# host platform's full-regression obligations have been executed.
exec python3 scripts/auto_test.py "$COMMAND" --profile routes --platform "$PLATFORM" "${ARGS[@]}"
