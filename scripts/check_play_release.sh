#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_DIR="$ROOT_DIR/android"
MERGED_MANIFEST="$ROOT_DIR/build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml"
AAB_PATH="$ROOT_DIR/build/app/outputs/bundle/release/app-release.aab"

PLAY_BASE_URL="${PLAY_BASE_URL:-https://pro.imboy.pub}"
PRIVACY_URL="$PLAY_BASE_URL/privacy-policy"
DELETION_URL="$PLAY_BASE_URL/account-deletion"
SKIP_URL_CHECK="${SKIP_URL_CHECK:-0}"

FORBIDDEN_PERMS=(
  "android.permission.ACCESS_BACKGROUND_LOCATION"
  "android.permission.QUERY_ALL_PACKAGES"
  "android.permission.MANAGE_EXTERNAL_STORAGE"
  "android.permission.REQUEST_INSTALL_PACKAGES"
  "android.permission.PACKAGE_USAGE_STATS"
)

fail_count=0

ok() { printf "PASS: %s\n" "$1"; }
warn() { printf "WARN: %s\n" "$1"; }
fail() { printf "FAIL: %s\n" "$1"; fail_count=$((fail_count + 1)); }

printf "== IMBoy Play release preflight ==\n"
printf "ROOT: %s\n" "$ROOT_DIR"
printf "PLAY_BASE_URL: %s\n" "$PLAY_BASE_URL"

if [[ ! -f "$MERGED_MANIFEST" ]]; then
  printf "Merged manifest not found, generating...\n"
  (cd "$ANDROID_DIR" && ./gradlew :app:processReleaseMainManifest >/dev/null)
fi

if [[ -f "$MERGED_MANIFEST" ]]; then
  ok "release merged manifest ready"
else
  fail "release merged manifest missing: $MERGED_MANIFEST"
fi

if [[ -f "$MERGED_MANIFEST" ]]; then
  for perm in "${FORBIDDEN_PERMS[@]}"; do
    if rg -q "$perm" "$MERGED_MANIFEST"; then
      fail "forbidden permission found in merged manifest: $perm"
    else
      ok "forbidden permission not present: $perm"
    fi
  done
fi

if [[ -f "$AAB_PATH" ]]; then
  ok "release AAB exists: $AAB_PATH"
else
  warn "release AAB not found, run: flutter build appbundle"
fi

if [[ -f "$ROOT_DIR/android/local.properties" ]]; then
  if rg -q '^flutter\.versionCode=' "$ROOT_DIR/android/local.properties"; then
    ok "flutter.versionCode is configured in android/local.properties"
  else
    warn "flutter.versionCode not configured; use ./scripts/build_play_aab.sh <build_number> to ensure monotonic Play build numbers"
  fi
fi

if [[ "$SKIP_URL_CHECK" == "1" ]]; then
  warn "URL checks skipped (SKIP_URL_CHECK=1)"
else
  for url in "$PRIVACY_URL" "$DELETION_URL"; do
    if curl -fsSI --max-time 10 "$url" >/dev/null; then
      ok "URL reachable: $url"
    else
      fail "URL unreachable: $url"
    fi
  done
fi

if [[ "$fail_count" -gt 0 ]]; then
  printf "\nPreflight finished with %d failure(s).\n" "$fail_count"
  exit 1
fi

printf "\nPreflight finished successfully.\n"
