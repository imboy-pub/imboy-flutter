#!/usr/bin/env bash
# Retry known temporary dependency-download failures, never all build errors.
set -euo pipefail

if [[ $# == 0 ]]; then
  echo 'Usage: ci_retry_build_downloads.sh command [args...]' >&2
  exit 64
fi

log="$(mktemp "${TMPDIR:-/tmp}/imboy-build-download.XXXXXX")"
trap 'rm -f "$log"' EXIT
# These 504 download formats remain separate from the scoped Gradle/Pods rules
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
  elif [[ "$status" == 1 && "${1##*/}" == flutter && "${2:-}" == build && "${3:-}" == ios ]]; then
    config_only=false
    conflicting_flag=false
    for argument in "${@:4}"; do
      case "$argument" in
        --) break ;;
        --config-only) config_only=true ;;
        --no-config-only|--config-only=*|--no-config-only=*) conflicting_flag=true ;;
      esac
    done
    if [[ "$config_only" == true && "$conflicting_flag" == false ]] && awk '
      function reset_pod() {
        # Permanent or ambiguous errors veto this entire command invocation.
        source_ok = clone_ok = in_error = error_sections = 0
        for (key in seen) delete seen[key]
      }
      function transport_marker(line) {
        if (line == cloning) return "clone"
        if (line == "error: RPC failed; curl 56 Recv failure: Connection reset by peer") return "rpc"
        if (line ~ /^error: [1-9][0-9]* bytes of body are still expected$/) return "bytes"
        if (line == "fetch-pack: unexpected disconnect while reading sideband packet") return "disconnect"
        if (line == "fatal: early EOF") return "eof"
        if (line == "fatal: fetch-pack: invalid index-pack output") return "pack"
        return ""
      }
      BEGIN {
        source = "https://mirrors.tuna.tsinghua.edu.cn/git/CocoaPods/Specs.git"
        name = "tsinghua-git-cocoapods"
        declaration = "[!] Unable to add a source with url `" source "` named `" name "`."
        clone_command = "(/usr/local/bin/git clone " source " -- " name
        cloning = "Cloning into " sprintf("%c", 39) name sprintf("%c", 39) "..."
        output_header = "CocoaPods" sprintf("%c", 39) " output:"
      }
      {
        line = $0
        sub(/^[[:space:]]+/, "", line); sub(/[[:space:]]+$/, "", line)
        if (line == "") next
        terminal = 0
        if (line ~ /^Running pod install/ || line ~ /^Pod installation complete!/ || line == output_header) {
          reset_pod(); next
        }
        if (line ~ /^\[!\]/) {
          source_ok = (line == declaration); clone_ok = 0
          if (!source_ok) bad = 1
          next
        }
        if (source_ok && line == clone_command) { clone_ok = 1; next }
        if (line == "Error output from CocoaPods:") { in_error = 1; error_sections++; next }
        if (line == "Error running pod install") {
          terminal = (source_ok && clone_ok && error_sections == 1 && !bad &&
                      seen["clone"] && seen["rpc"] && seen["bytes"] &&
                      seen["disconnect"] && seen["eof"] && seen["pack"])
          reset_pod(); next
        }
        marker = transport_marker(line)
        if (in_error) {
          if (marker != "") seen[marker] = 1
          else if (line != "↳" && line != "Must provide a project directory and project name.") bad = 1
        }
        if ((tolower(line) ~ /(^|[[:space:]])(error:|fatal:)/ && marker == "") ||
            tolower(line) ~ /compilation failed|code signing failed|checksum mismatch|verification failed|could not find |incompatible package versions|authentication failed|ssl certificate/) bad = 1
      }
      END { exit !terminal }
    ' "$log"; then
      # The observed project message alone is not evidence of a transport failure.
      # Keep the configured Specs source and the complete terminal clone error bound.
      retryable=true
    fi
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
