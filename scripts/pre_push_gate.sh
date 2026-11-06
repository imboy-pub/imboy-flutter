#!/usr/bin/env bash
# pre-push compatibility entrypoint for the shared execution contract.
# Default: static ownership only; optional backend tests require explicit opt-in.
# Usage: bash scripts/pre_push_gate.sh [--backend] [--artifact-dir DIR]
# Plan:  bash scripts/pre_push_gate.sh --dry-run [--output FILE]
# Hook opt-in: IMBOY_PRE_PUSH_BACKEND=1 git push ...
# Existing emergency opt-out: IMBOY_SKIP_PRE_PUSH=1 git push ...
set -euo pipefail

# Git hooks inject these variables; child SDK Git probes must see their own repo.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if [[ "${IMBOY_SKIP_PRE_PUSH:-0}" == "1" ]]; then
  echo '[pre-push] NOT_SELECTED reason_code=OUT_OF_SCOPE: explicit opt-out; ownership and backend checks were not run.' >&2
  exit 0
fi

BACKEND="${IMBOY_PRE_PUSH_BACKEND:-0}"
case "$BACKEND" in
  0|1) ;;
  *) echo 'IMBOY_PRE_PUSH_BACKEND must be 0 or 1' >&2; exit 64 ;;
esac
DRY_RUN=false
ARGS=()
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --backend) BACKEND=1; shift ;;
    --dry-run) BACKEND=1; DRY_RUN=true; shift ;;
    --artifact-dir|--output)
      [[ "$#" -ge 2 && -n "$2" ]] || { echo "$1 needs a value" >&2; exit 64; }
      ARGS+=("$1" "$2"); shift 2 ;;
    --help|-h)
      printf '%s\n' \
        'Usage: scripts/pre_push_gate.sh [--backend] [--artifact-dir DIR]' \
        'Plan: scripts/pre_push_gate.sh --dry-run [--output FILE]' \
        'Default runs execution-check only; backend is OUT_OF_SCOPE.' \
        'IMBOY_PRE_PUSH_BACKEND=1 opts the hook into the backend profile on this host.' \
        'No test.env is loaded; prepare an explicit isolated fixture environment.'
      exit 0 ;;
    *) echo "Unknown pre-push option: $1" >&2; exit 64 ;;
  esac
done

if [[ "$BACKEND" == "0" ]]; then
  echo '[pre-push] NOT_SELECTED reason_code=OUT_OF_SCOPE: backend profile not requested; validating static ownership only.' >&2
  exec python3 scripts/auto_test.py execution-check ${ARGS[@]+"${ARGS[@]}"}
fi

case "$(uname -s)" in
  Linux) TEST_PLATFORM=linux ;;
  Darwin) TEST_PLATFORM=macos ;;
  *) echo '[pre-push] BLOCKED reason_code=ENV_MISSING: backend runner requires a Linux or macOS host.' >&2; exit 2 ;;
esac
if $DRY_RUN; then
  exec python3 scripts/auto_test.py execution-plan --profile backend --platform "$TEST_PLATFORM" ${ARGS[@]+"${ARGS[@]}"}
fi
# The existing runner validates isolation before probing and owns machine-event
# verdicts, evidence and nonzero exits. Never infer business PASS in this wrapper.
exec python3 scripts/auto_test.py execution-run --profile backend --platform "$TEST_PLATFORM" ${ARGS[@]+"${ARGS[@]}"}
