#!/usr/bin/env bash

set -euo pipefail

WORKFLOW_FILE="${1:-.github/workflows/ci.yml}"

if [[ ! -f "$WORKFLOW_FILE" ]]; then
  echo "[ci-test-path] workflow file not found: $WORKFLOW_FILE" >&2
  exit 1
fi

errors=0
checks=0

while IFS= read -r entry; do
  line_no="${entry%%:*}"
  content="${entry#*:}"
  content="${content#"${content%%[![:space:]]*}"}"

  cmd_part="${content#*flutter test }"
  test_path="${cmd_part%% *}"
  test_path="${test_path%%;*}"
  test_path="${test_path%%|*}"

  # strip optional wrapping quotes
  test_path="${test_path%\"}"
  test_path="${test_path#\"}"
  test_path="${test_path%\'}"
  test_path="${test_path#\'}"

  # skip dynamic or flag-based invocations
  if [[ -z "$test_path" || "$test_path" == -* || "$test_path" == '$'* ]]; then
    echo "[ci-test-path] skip dynamic path at line $line_no: $content"
    continue
  fi

  checks=$((checks + 1))
  if [[ -e "$test_path" ]]; then
    echo "[ci-test-path] ok: $test_path (line $line_no)"
  else
    echo "[ci-test-path] missing: $test_path (line $line_no)" >&2
    errors=$((errors + 1))
  fi
done < <(grep -nE "flutter test " "$WORKFLOW_FILE" || true)

if [[ "$checks" -eq 0 ]]; then
  echo "[ci-test-path] no 'flutter test' command found in $WORKFLOW_FILE."
  exit 0
fi

if [[ "$errors" -gt 0 ]]; then
  echo "[ci-test-path] found $errors invalid test path(s)." >&2
  exit 1
fi

echo "[ci-test-path] verified $checks path(s) in $WORKFLOW_FILE."
