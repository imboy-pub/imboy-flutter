#!/usr/bin/env bash
# Retry known temporary dependency-download failures, never all build errors.
set -euo pipefail

if [[ $# == 0 ]]; then
  echo 'Usage: ci_retry_build_downloads.sh command [args...]' >&2
  exit 64
fi

log="$(mktemp "${TMPDIR:-/tmp}/imboy-build-download.XXXXXX")"
trap 'rm -f "$log"' EXIT
# These 504 download formats remain separate from the scoped Gradle 429 rule
# below. Flutter can recover one error before reporting a terminal build error.
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
  elif [[ "$status" == 1 && "${1##*/}" == flutter && "${2:-}" == build &&
          ( "${3:-}" == apk || "${3:-}" == appbundle ) ]] &&
      awk -v diagnostic="^[[:space:]]*> Could not GET 'https://repo[.]maven[.]apache[.]org/maven2/[^']+'[.] Received status code 429 from server: Too Many Requests$" '
        # Inspect the terminal Gradle report, not an earlier internal retry.
        /^FAILURE:/ || /^Retrying Gradle Build:/ {
          single = ($0 == "FAILURE: Build failed with an exception.")
          in_cause = causes = limited = other_failure = 0
          next
        }
        /^\* What went wrong:/ { in_cause = single; causes++; next }
        /^\* / { in_cause = 0 }
        in_cause {
          if ($0 ~ diagnostic) limited = 1
          else if ($0 ~ /Received status code [0-9]+ from server:/) other_failure = 1
        }
        # Keep mixed or trailing permanent failures terminal as well.
        single && (tolower($0) ~ /(^|[[:space:]>])error:|compilation failed|code signing failed|checksum mismatch|verification failed/ ||
                   tolower($0) ~ /could not find |incompatible package versions/) {
          other_failure = 1
        }
        END { exit !(single && causes == 1 && limited && !other_failure) }
      ' "$log"; then
    # Only the observed official Maven Central GET failure is admitted. Other
    # hosts, statuses, commands and ambiguous multi-failure reports stay fatal.
    retryable=true
  elif [[ "$status" == 69 && "${1##*/}" == flutter && "${2:-}" == pub && "${3:-}" == get ]]; then
    # Pub reports unavailable (69) for Git transport failures. Restrict these
    # signatures to package download, never a later failed build or test.
    if grep -Eq "^fatal: unable to access 'https://[^']+': Could not resolve host: [^[:space:]]+$" "$log"; then
      retryable=true
    elif grep -Eq '^Git error\. Command: `git clone --mirror (-- )?https://[^[:space:]]+ ' "$log" &&
        grep -Fxq 'fatal: early EOF' "$log" &&
        grep -Fxq 'fatal: fetch-pack: invalid index-pack output' "$log" &&
        { grep -Eq \
          -e '^error: RPC failed; curl 56 GnuTLS recv error \(-110\): The TLS connection was non-properly terminated\.$' \
          -e '^error: RPC failed; curl 56 OpenSSL SSL_read: OpenSSL/[0-9]+\.[0-9]+\.[0-9]+: error:0A000126:SSL routines::unexpected eof while reading, errno 0$' "$log" ||
          { grep -Fxq 'error: RPC failed; curl 18 transfer closed with outstanding read data remaining' "$log" &&
            grep -Eq '^error: [0-9]+ bytes of body are still expected$' "$log" &&
            grep -Fxq 'fetch-pack: unexpected disconnect while reading sideband packet' "$log"; }; }; then
      # Observed Git clone truncation (curl 56 or 18). A generic SSL, checksum,
      # or pack error alone is insufficient; keep the lockfile and command intact.
      retryable=true
    fi
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
