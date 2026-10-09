#!/usr/bin/env bash
# Route smoke runner: each selected route gets its own Flutter test process.
# Usage: bash test/unit_test/smoke/run_smoke_isolated.sh [--quiet] [--route NAME]...
# Exit: 0 all selected routes executed/passed; 1 failure; 2 incomplete (skips).
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1
TEST_FILE="test/unit_test/smoke/route_smoke_test.dart"
REGISTRY="test/unit_test/smoke/route_registry.dart"
QUIET=false
SELECTED=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --quiet) QUIET=true; shift ;;
    --route)
      [ "$#" -ge 2 ] || { echo "ERROR: --route requires a name" >&2; exit 1; }
      SELECTED+=("$2"); shift 2 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
  esac
done
command -v python3 >/dev/null || { echo "ERROR: python3 is required" >&2; exit 1; }
ROUTES=()
while IFS= read -r name; do
  [ -n "$name" ] && ROUTES+=("$name")
done < <(grep -oE "name: '[a-z_]+'" "$REGISTRY" | sed "s/name: '//;s/'//" | sort -u)
[ "${#ROUTES[@]}" -gt 0 ] || { echo "ERROR: registry contains no routes" >&2; exit 1; }
if [ "${#SELECTED[@]}" -gt 0 ]; then
  for name in "${SELECTED[@]}"; do
    found=false
    for registered in "${ROUTES[@]}"; do
      [ "$name" = "$registered" ] && found=true
    done
    $found || { echo "ERROR: unknown route: $name" >&2; exit 1; }
  done
  ROUTES=("${SELECTED[@]}")
fi
# Default temporary output is outside the repository; callers may retain their
# own external evidence directory with SMOKE_OUTPUT_DIR.
OUTPUT_DIR="${SMOKE_OUTPUT_DIR:-}"
REMOVE_OUTPUT=false
if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/imboy-route-smoke.XXXXXX")" || exit 1
  REMOVE_OUTPUT=true
fi
mkdir -p "$OUTPUT_DIR" || exit 1
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd -P)" || exit 1
case "$OUTPUT_DIR/" in
  "$(pwd -P)/"*) echo "ERROR: smoke output must be outside the repository" >&2; exit 1 ;;
esac
cleanup() { if $REMOVE_OUTPUT; then rm -rf "$OUTPUT_DIR"; fi; }
trap cleanup EXIT
PASS=0
FAIL=0
SKIP=0
FAILED_ROUTES=()
SKIPPED_ROUTES=()
echo "===== Isolated route smoke: ${#ROUTES[@]} selected ====="
for name in "${ROUTES[@]}"; do
  out="$OUTPUT_DIR/$name.jsonl"
  # Match both real rendering tests and explicit quarantine cases. Unmatched
  # tests are errors, never inferred to be quarantine from an English log line.
  flutter test "$TEST_FILE" --machine --name "(^| )$name \(|\[quarantine\] $name —" > "$out" 2>&1
  code=$?
  result="$(python3 - "$out" "$name" "$code" <<'PYREPORT'
import json, sys
path, name, exit_code = sys.argv[1:]
targets, finished = set(), {}
done = False
for line in open(path, encoding='utf-8', errors='replace'):
    try:
        event = json.loads(line)
    except (ValueError, TypeError):
        continue
    if not isinstance(event, dict):
        continue
    if event.get('type') == 'testStart':
        test = event.get('test', {})
        title = test.get('name', '')
        if name + ' (' in title or '[quarantine] ' + name + ' —' in title:
            targets.add(test.get('id'))
    elif event.get('type') == 'testDone':
        finished[event.get('testID')] = event
    elif event.get('type') == 'done':
        done = event.get('success') is True
if len(targets) != 1 or not targets.issubset(finished):
    print('FAIL')
else:
    result = finished[next(iter(targets))]
    if result.get('skipped') is True and int(exit_code) == 0 and done:
        print('SKIP')
    elif result.get('result') == 'success' and int(exit_code) == 0 and done:
        print('PASS')
    else:
        print('FAIL')
PYREPORT
)" || result=FAIL
  case "$result" in
    PASS) PASS=$((PASS + 1)); $QUIET || echo "  PASS  $name" ;;
    SKIP) SKIP=$((SKIP + 1)); SKIPPED_ROUTES+=("$name"); $QUIET || echo "  SKIP  $name" ;;
    *) FAIL=$((FAIL + 1)); FAILED_ROUTES+=("$name"); echo "  FAIL  $name ($out)" ;;
  esac
done
echo "===== PASS=$PASS SKIP=$SKIP FAIL=$FAIL TOTAL=${#ROUTES[@]} ====="
if [ "$SKIP" -gt 0 ]; then
  echo "Not executed / 未执行路由:"
  printf '  - %s\n' "${SKIPPED_ROUTES[@]}"
fi
if [ "$FAIL" -gt 0 ]; then
  echo "Failed routes:"
  printf '  - %s\n' "${FAILED_ROUTES[@]}"
  exit 1
fi
if [ "$SKIP" -gt 0 ]; then
  echo "Incomplete / 存在跳过项，不能认定全部通过。"
  exit 2
fi
echo "All selected routes executed and passed."
