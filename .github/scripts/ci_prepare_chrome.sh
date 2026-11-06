#!/usr/bin/env bash
# Use the runner's installed browser; validation failures remain dependency failures.
set -euo pipefail

if [ -z "${GITHUB_ENV:-}" ]; then
  echo '[ci_prepare_chrome] ENV_MISSING: GITHUB_ENV is required to publish Chrome' >&2
  exit 2
fi

chrome_executable="${CHROME_EXECUTABLE:-}"
if [ -z "$chrome_executable" ]; then
  chrome_executable="$(command -v google-chrome || command -v google-chrome-stable || true)"
fi
if [ -z "$chrome_executable" ] || [ ! -f "$chrome_executable" ] || [ ! -x "$chrome_executable" ]; then
  printf '[ci_prepare_chrome] ENV_MISSING: executable Chrome not found: %s\n' "${chrome_executable:-google-chrome or google-chrome-stable}" >&2
  exit 2
fi
case "$chrome_executable" in
  *$'\n'*|*$'\r'*) echo '[ci_prepare_chrome] ENV_MISSING: invalid Chrome path' >&2; exit 2 ;;
esac

if chrome_version="$("$chrome_executable" --version 2>&1)"; then
  if [ -z "$chrome_version" ]; then
    echo '[ci_prepare_chrome] ENV_MISSING: Chrome --version returned no version' >&2
    exit 2
  fi
else
  chrome_status=$?
  printf '[ci_prepare_chrome] ENV_MISSING: Chrome --version failed (exit %s)\n%s\n' "$chrome_status" "$chrome_version" >&2
  exit 2
fi

printf 'CHROME_EXECUTABLE=%s\n' "$chrome_executable" >> "$GITHUB_ENV"
printf '[ci_prepare_chrome] executable=%s\n%s\n' "$chrome_executable" "$chrome_version"
