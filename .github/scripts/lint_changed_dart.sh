#!/usr/bin/env bash

set -euo pipefail

BASE_REF="${GITHUB_BASE_REF:-main}"

if git rev-parse --verify "origin/${BASE_REF}" >/dev/null 2>&1; then
  DIFF_RANGE="origin/${BASE_REF}...HEAD"
elif git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
  DIFF_RANGE="HEAD~1...HEAD"
else
  echo "[new-code-guard] no valid baseline found, skip."
  exit 0
fi

CHANGED_DART_FILES=()
while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  CHANGED_DART_FILES+=("$file")
done < <(
  git diff --name-only --diff-filter=ACMR "$DIFF_RANGE" -- '*.dart' \
    ':!**/*.g.dart' \
    ':!**/*.freezed.dart' \
    ':!**/generated/**'
)

if [[ ${#CHANGED_DART_FILES[@]} -eq 0 ]]; then
  echo "[new-code-guard] no changed dart files."
  exit 0
fi

EXISTING_DART_FILES=()
for file in "${CHANGED_DART_FILES[@]}"; do
  if [[ -f "$file" ]]; then
    EXISTING_DART_FILES+=("$file")
  fi
done

if [[ ${#EXISTING_DART_FILES[@]} -eq 0 ]]; then
  echo "[new-code-guard] changed dart files are deleted/renamed away, skip."
  exit 0
fi

echo "[new-code-guard] changed dart files:"
printf '%s\n' "${EXISTING_DART_FILES[@]}" | sed 's/^/  - /'

echo "[new-code-guard] running flutter analyze on changed files..."
flutter analyze "${EXISTING_DART_FILES[@]}"

if grep -nHE '(^|[^a-zA-Z0-9_])print[[:space:]]*\(' "${EXISTING_DART_FILES[@]}"; then
  echo "[new-code-guard] disallowed print(...) found in changed files." >&2
  exit 1
fi

if grep -nHE 'ignore:[[:space:]]*use_build_context_synchronously' "${EXISTING_DART_FILES[@]}"; then
  echo "[new-code-guard] disallowed lint suppression found in changed files." >&2
  exit 1
fi

echo "[new-code-guard] passed."
