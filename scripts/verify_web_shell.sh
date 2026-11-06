#!/usr/bin/env bash
# Web Shell analysis/build plus the shared host + Chrome test profile.
# Usage: scripts/verify_web_shell.sh [--quick] [--no-server] [--artifact-dir DIR]
# Plan:  scripts/verify_web_shell.sh --dry-run [--output FILE]
# --quick skips the build and preview, never tests. Missing prerequisites block.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"
QUICK=false
START_SERVER=true
DRY_RUN=false
ARTIFACT_DIR=''
PLAN_OUTPUT=''
PLAN_ARGS=()
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --quick) QUICK=true; shift ;;
    --no-server) START_SERVER=false; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --artifact-dir|--output)
      [[ "$#" -ge 2 && -n "$2" ]] || { echo "$1 needs a value" >&2; exit 64; }
      if [[ "$1" == '--artifact-dir' ]]; then ARTIFACT_DIR="$2"; else PLAN_OUTPUT="$2"; fi
      shift 2 ;;
    --help|-h)
      printf '%s\n' \
        'Usage: scripts/verify_web_shell.sh [--quick] [--no-server] [--artifact-dir DIR]' \
        'Plan: scripts/verify_web_shell.sh --dry-run [--output FILE]' \
        'Artifacts must be outside the repository; default is a temporary directory.' \
        'The web-shell profile selects this host plus Chrome; --quick skips only build/preview.'
      exit 0 ;;
    *) echo "Unknown Web Shell option: $1" >&2; exit 64 ;;
  esac
done
case "$(uname -s)" in
  Linux) TEST_PLATFORM=linux ;;
  Darwin) TEST_PLATFORM=macos ;;
  *) echo 'BLOCKED reason_code=ENV_MISSING: Web Shell requires a Linux or macOS host.' >&2; exit 2 ;;
esac
if $DRY_RUN; then
  [[ -z "$PLAN_OUTPUT" ]] || PLAN_ARGS=(--output "$PLAN_OUTPUT")
  exec python3 scripts/auto_test.py execution-plan --profile web-shell \
    --platform "$TEST_PLATFORM" --platform web ${PLAN_ARGS[@]+"${PLAN_ARGS[@]}"}
fi
[[ -z "$PLAN_OUTPUT" ]] || { echo '--output requires --dry-run' >&2; exit 64; }
if [[ -z "$ARTIFACT_DIR" ]]; then
  ARTIFACT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/imboy-web-shell.XXXXXX")"
fi
ARTIFACT_DIR="$(python3 -c '
from pathlib import Path
import sys
root, output = (Path(value).resolve() for value in sys.argv[1:])
if output == root or root in output.parents:
    raise SystemExit("--artifact-dir must be outside the repository")
print(output)
' "$PROJECT_DIR" "$ARTIFACT_DIR")" || exit 64
mkdir -p "$ARTIFACT_DIR"
echo "Web Shell evidence: $ARTIFACT_DIR"
UPSTREAM_ARGS=()
READY=true

# Preserve the existing static/build checks, recording failures as dependencies
# of the shared execution. No business verdict is inferred from their exit codes.
run_check() {
  local name="$1"; shift
  local code=0
  echo "==> $name"
  "$@" >"$ARTIFACT_DIR/$name.log" 2>&1 || code=$?
  cat "$ARTIFACT_DIR/$name.log" || code=$?
  if [[ "$code" -ne 0 ]]; then
    echo "Web Shell prerequisite $name failed (exit $code); see $ARTIFACT_DIR/$name.log" >&2
    UPSTREAM_ARGS+=(--upstream "web-shell-$name=failure")
    READY=false
  fi
}
run_check sdk python3 scripts/check_sdk_compatibility.py
if $READY; then
  for asset in web/pkg/vodozemac_bindings_dart.js web/pkg/vodozemac_bindings_dart_bg.wasm; do
    if [[ ! -s "$asset" ]]; then
      echo "ENV_MISSING: Web E2EE asset $asset" | tee -a "$ARTIFACT_DIR/assets.log" >&2
      UPSTREAM_ARGS+=(--upstream 'web-shell-assets=blocked')
      READY=false
    fi
  done
fi
if $READY; then
  run_check analyze flutter analyze lib/page/web_shell/ test/unit_test/page/web_shell/ --no-fatal-infos
fi
if $READY && ! $QUICK; then
  run_check build flutter build web --release --no-tree-shake-icons
fi

# One plan owns VM/Chrome selection and machine-event evidence. Prerequisite
# failures still produce per-instance UPSTREAM_FAILED results and a nonzero exit.
python3 scripts/auto_test.py execution-run --profile web-shell \
  --platform "$TEST_PLATFORM" --platform web --artifact-dir "$ARTIFACT_DIR/tests" \
  ${UPSTREAM_ARGS[@]+"${UPSTREAM_ARGS[@]}"} | tee "$ARTIFACT_DIR/execution.log"

if $QUICK; then
  echo 'Build and preview OUT_OF_SCOPE (--quick); test scope is unchanged.'
elif $START_SERVER; then
  echo 'Local preview: http://127.0.0.1:9820/ (Ctrl+C stops it; manual browser review is not an automated test verdict).'
  python3 -m http.server 9820 --bind 127.0.0.1 --directory build/web
fi
