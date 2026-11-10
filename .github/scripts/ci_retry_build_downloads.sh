#!/usr/bin/env bash
# Retry known temporary dependency-download failures, never all build errors.
set -euo pipefail

if [[ $# == 0 ]]; then
  echo 'Usage: ci_retry_build_downloads.sh command [args...]' >&2
  exit 64
fi

log="$(mktemp "${TMPDIR:-/tmp}/imboy-build-download.XXXXXX")"
trap 'rm -f "$log"' EXIT
# Only the observed 504 failures are handled here. Flutter already retries
# other errors such as 502; those can precede a terminal compiler failure.
retryable_http='504'

for attempt in 1 2 3; do
  # Do not echo argv: dart-define values can contain credentials.
  echo "[ci_build_downloads] Attempt $attempt/3"
  set +e
  "$@" 2>&1 | tee "$log"
  pipeline_status=("${PIPESTATUS[@]}")
  set -e
  status=${pipeline_status[0]}
  if [[ ${pipeline_status[1]} != 0 ]]; then
    exit "${pipeline_status[1]}"
  fi
  if [[ "$status" == 0 ]]; then
    exit 0
  fi

  # tee truncates the log for each attempt; an earlier HTTP failure must not
  # cause a later compiler, signing, checksum, or package-resolution error to retry.
  retryable=false
  if grep -Eq \
      -e "Server returned HTTP response code: $retryable_http for URL: https://" \
      -e "failed downloading 'https://[^']+'.*badResponseStatusCode\($retryable_http\)" \
      "$log"; then
    retryable=true
  elif [[ "$status" == 69 && "${1##*/}" == flutter && "${2:-}" == pub && "${3:-}" == get ]] &&
      grep -Eq "^fatal: unable to access 'https://[^']+': Could not resolve host: [^[:space:]]+$" "$log"; then
    # Pub reports unavailable (69) for Git DNS failures. Restrict this case to
    # package download so earlier transport output cannot retry a failed build.
    retryable=true
  fi
  if [[ "$status" -ge 128 || "$retryable" != true ]]; then
    exit "$status"
  fi
  if [[ "$attempt" == 3 ]]; then
    echo "::error::Dependency download failed after 3 attempts (exit $status)." >&2
    exit "$status"
  fi
  delay=$((attempt * 10))
  echo "::warning::Temporary dependency download error; retrying in ${delay}s."
  sleep "$delay"
done
