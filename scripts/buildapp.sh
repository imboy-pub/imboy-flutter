#!/usr/bin/env bash
# buildapp.sh — multi-customer isolated APP build entry for imboy-flutter.
#
# Usage:
#   bash scripts/buildapp.sh <customer_id> [environment] [platforms...] [--dry-run]
#     environment: development | staging | production   (default: production)
#     platforms:   android | ios | web | all            (default: all)
#   bash scripts/buildapp.sh --help
#
# Design contract (PRD V1.1 §5 / Plan P02 / D21; receipt isolation V2):
#   * One shared entry for every customer; no customer id is hardcoded here.
#   * Customer config:   ../customers/<id>/config/   (app.yaml + features.yaml + env files)
#   * Customer assets:   ../customers/<id>/assets/   (full package, SHA256SUMS-verified)
#   * Build receipts:    ../customers/<id>/builds/<env>/<version>-<build_number>-<run_id>/
#                        Every run owns a unique run_id (F01); artifacts are produced
#                        inside a run-private EMPTY staging dir (F02), the manifest is
#                        generated LAST with an explicit artifact inventory (F03/F05),
#                        and the whole directory is published with a single atomic mv.
#                        A failed or interrupted run never publishes a receipt; its
#                        staging evidence moves to builds/failed-runs/ (F04).
#                        Dry-runs publish under builds/dry-runs/ only, never carry
#                        artifacts, and never read real-build outputs (F06).
#   * URL scheme contract (F09-F12): identity.url_scheme is validated fail-closed,
#                        injected into the native registrations (AndroidManifest
#                        intent-filters + iOS CFBundleURLTypes), cross-verified by
#                        structurally parsing the injected files, and recorded in the
#                        receipt. Vendor scheme inheritance is demo-only and must be
#                        explicitly configured + disclosed. Final real-build artifacts
#                        (APK merged manifest / built Runner.app plist) are checked
#                        again after the actual flutter build (F13).
#   * Injection happens in an ISOLATED git worktree; the shared checkout is never
#     modified (survives failure, Ctrl-C, SIGTERM; stale locks/worktrees are
#     reclaimed on the next run — a SIGKILL leaves state that the next run cleans).
#   * Production builds fail-closed while required identity/API config is missing.
#   * Server secrets and signing credentials never pass through this script.
#
# Platform notes: macOS keeps its verified native tools (sips); everything else
# (sed/plist/sha256/png) goes through portable helpers so the same core logic
# runs on Linux CI. See scripts/buildapp.md.

set -euo pipefail

SELF_VERSION="2.0.0"
VENDOR_APP_ID="pub.imboy.app"        # vendor baseline application id (gradle/pbxproj)
VENDOR_BUNDLE_ID="pub.imboy.app"
VENDOR_APP_NAME="IMBoy"
VENDOR_URL_SCHEME="imboy"            # vendor deeplink scheme (demo inheritance only)

FLUTTER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_ROOT="$(dirname "$FLUTTER_ROOT")"
CUSTOMERS_ROOT="$WORKSPACE_ROOT/customers"
LOCK_ROOT="$WORKSPACE_ROOT/.buildapp-locks"
WT_ROOT="$WORKSPACE_ROOT/.buildapp-worktrees"
SCRIPTS_DIR="$FLUTTER_ROOT/scripts"
SCHEME_TOOL="$SCRIPTS_DIR/buildapp_scheme_tools.py"
APP_GROUP_TOOL="$SCRIPTS_DIR/buildapp_ios_app_group_tools.py"
PNG_TOOL="$SCRIPTS_DIR/buildapp_png_tools.py"

CUSTOMER_ID=""
ENV_NAME="production"
PLATFORMS=()
DRY_RUN=0

WORKTREE=""
LOCK_DIR=""
LOCK_HELD=0
CLEAN_DONE=0
PUBLISHED=0
LAST_ERROR=""

RUN_ID=""
BUILD_TS=""
BUILD_NUMBER=""
STAGING_DIR=""      # run-private staging (F02); published atomically (F05)
STAGING_ROOT=""
BUILDS_DIR=""
INVENTORY_FILE=""
OUT_DIR=""          # final published receipt directory
LOG=""

APP_NAME="" ; APP_ID="" ; BUNDLE_ID="" ; URL_SCHEME_NOTE="" ; APP_ENV=""
API_SOURCE="unconfigured" ; API_VALUE="" ; WS_VALUE=""
ASSET_PKG="" ; ASSET_VERSION="" ; REPLACEMENT_MAP="" ; AUTH_STATUS=""
WEB_TITLE="" ; PUSH_DEMO="unset"
RESOLVED_SCHEME="" ; SCHEME_RESOLUTION="" ; SCHEME_INHERITED=0
ANDROID_REGISTERED_SCHEMES="not-injected" ; IOS_REGISTERED_SCHEMES="not-injected"
IOS_ALL_URL_SCHEMES="not-injected"
IOS_APP_GROUP_STATUS="not-applicable"
URL_SCHEME_VALIDATION="not-applicable"
ANDROID_APK_SCHEMES="not-built" ; ANDROID_APK_TOOL="none" ; IOS_APP_SCHEMES="not-built"

info()  { echo "[buildapp] $*"; }
warn()  { echo "[buildapp] WARNING: $*" >&2; }
die()   { LAST_ERROR="$*"; echo "[buildapp] ERROR: $*" >&2; exit 1; }

usage() {
  cat <<EOF
buildapp.sh ${SELF_VERSION} — multi-customer isolated APP build entry

Usage:
  bash scripts/buildapp.sh <customer_id> [environment] [platforms...] [--dry-run]

Arguments:
  customer_id   lowercase [a-z0-9-] identifier; must exist under ../customers/
  environment   development | staging | production        (default: production)
  platforms     android | ios | web, space separated      (default: all = android ios web)

Options:
  --dry-run     validate config/assets, apply brand + URL scheme injection in an
                isolated worktree, verify, write a dry-run receipt under
                builds/dry-runs/ (never real-build artifacts), clean up.
                No flutter/xcodebuild invocation.
  --help        show this help

Receipts (F01-F05):
  real builds   builds/<env>/<version>-<build_number>-<run_id>/
  dry runs      builds/dry-runs/<env>/<version>-<build_number>-<run_id>/
  failures      builds/failed-runs/<env>-<run_id>/   (evidence only; NO receipt)
  Each receipt contains exactly this run's artifacts + build-manifest.yaml +
  SHA256SUMS (generated last, published atomically).

Examples:
  bash scripts/buildapp.sh yaoxin                       # production all (fail-closed until configured)
  bash scripts/buildapp.sh yaoxin development android   # demo APK
  bash scripts/buildapp.sh yaoxin development web --dry-run
EOF
}

# ---------- portability helpers (macOS BSD vs Linux GNU) ----------
if sed --version >/dev/null 2>&1; then SED_INPLACE=(-i); else SED_INPLACE=(-i ''); fi
sedi() { sed "${SED_INPLACE[@]}" "$@"; }

if command -v shasum >/dev/null 2>&1; then
  sha_sum()   { shasum -a 256 "$@"; }
  sha_check() { shasum -a 256 -c "$1" --status; }
else
  sha_sum()   { sha256sum "$@"; }
  sha_check() { sha256sum -c "$1" --status; }
fi

png_size() { # $1=png -> "W H"
  python3 "$PNG_TOOL" size "$1"
}
png_resize() { # $1=src $2=dst $3=box (square)
  if command -v sips >/dev/null 2>&1; then
    sips -z "$3" "$3" "$1" --out "$2" >/dev/null
  else
    python3 "$PNG_TOOL" resize "$1" "$2" "$3" "$3"
  fi
}

plist_set_string() { # $1=plist $2=key $3=value (portable plutil -replace equivalent)
  python3 - "$1" "$2" "$3" <<'PYEOF'
import plistlib, sys
path, key, value = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, "rb") as fh:
    data = plistlib.load(fh)
data[key] = value
with open(path, "wb") as fh:
    plistlib.dump(data, fh, fmt=plistlib.FMT_XML, sort_keys=False)
PYEOF
}
plist_get_string() { # $1=plist $2=key -> value or empty
  python3 - "$1" "$2" <<'PYEOF'
import plistlib, sys
try:
    with open(sys.argv[1], "rb") as fh:
        v = plistlib.load(fh).get(sys.argv[2])
    if isinstance(v, str):
        print(v)
except Exception:
    pass
PYEOF
}

jf() { # $1=field; reads JSON on stdin; lists join with ", "
  python3 -c 'import json,sys
d = json.load(sys.stdin)
v = d.get(sys.argv[1], "")
if isinstance(v, list):
    v = ", ".join(str(x) for x in v)
print(v)' "$1"
}

# ---------- config reading (flat 2-space YAML / KEY=VALUE) ----------
yaml_get() { # $1=file $2=dotted.key ; prints value; empty string when absent
  python3 - "$1" "$2" <<'PYEOF'
import sys, re
path, key = sys.argv[1], sys.argv[2]
want = key.split('.')
stack = []
try:
    f = open(path, encoding='utf-8')
except OSError:
    sys.exit(0)
for line in f:
    raw = line.rstrip('\n')
    s = raw.strip()
    if not s or s.startswith('#'):
        continue
    m = re.match(r'([A-Za-z0-9_.-]+)\s*:\s*(.*)$', s)
    if not m:
        continue
    indent = (len(raw) - len(raw.lstrip(' '))) // 2
    k, v = m.group(1), m.group(2).strip()
    del stack[indent:]
    stack.append(k)
    if stack == want:
        v = v.split(' #', 1)[0].strip().strip('"').strip("'")
        print(v)
        break
PYEOF
}

env_get() { # $1=envfile $2=KEY
  awk -F= -v k="$2" '$1 == k { sub("^" k "=", ""); print; exit }' "$1" | tr -d '\r'
}

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"; }

cleanup() {
  [ "$CLEAN_DONE" = "1" ] && return
  CLEAN_DONE=1
  if [ -n "$STAGING_DIR" ] && [ -d "$STAGING_DIR" ] && [ "$PUBLISHED" != "1" ]; then
    # F04: a failed/interrupted run must never leave anything that looks like a
    # PASS receipt. Strip receipt files from OUR OWN staging copies (historical
    # customer builds elsewhere are never touched), stamp FAIL, keep evidence.
    rm -f "$STAGING_DIR/build-manifest.yaml" "$STAGING_DIR/SHA256SUMS" "$STAGING_DIR/.inventory" "$STAGING_DIR/.artifact-checks"
    printf 'build_status: FAIL\ncustomer_id: %s\nenvironment: %s\nrun_id: %s\nmode: %s\nerror: %s\nfinished_utc: %s\n' \
      "$CUSTOMER_ID" "$ENV_NAME" "${RUN_ID:-unknown}" \
      "$([ "$DRY_RUN" = "1" ] && echo dry-run || echo real-build)" \
      "${LAST_ERROR:-interrupted}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$STAGING_DIR/build-status.txt"
    mkdir -p "$BUILDS_DIR/failed-runs"
    local dest="$BUILDS_DIR/failed-runs/${ENV_NAME}-${RUN_ID}" n=0
    while [ -e "$dest" ]; do n=$((n+1)); dest="$BUILDS_DIR/failed-runs/${ENV_NAME}-${RUN_ID}-$n"; done
    mv "$STAGING_DIR" "$dest" 2>/dev/null \
      && info "failed-run evidence kept (no receipt published): $dest" || true
  fi
  if [ -n "$WORKTREE" ] && [ -d "$WORKTREE" ]; then
    git -C "$FLUTTER_ROOT" worktree remove --force "$WORKTREE" >/dev/null 2>&1 || rm -rf "$WORKTREE"
    info "worktree removed: $WORKTREE"
  fi
  if [ -n "$LOCK_DIR" ] && [ "$LOCK_HELD" = "1" ]; then
    rm -rf "$LOCK_DIR"
    info "lock released: $LOCK_DIR"
  fi
}
trap cleanup EXIT
trap 'LAST_ERROR="interrupted (SIGINT)"; echo "[buildapp] interrupted (SIGINT); cleaning isolated workspace..." >&2; exit 130' INT
trap 'LAST_ERROR="terminated (SIGTERM)"; echo "[buildapp] terminated (SIGTERM); cleaning isolated workspace..." >&2; exit 143' TERM

# ---------- argument parsing ----------
ARGS=()
for a in "$@"; do
  case "$a" in
    --help|-h) usage; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
    *) ARGS+=("$a") ;;
  esac
done
ARGC=${#ARGS[@]}
[ "$ARGC" -ge 1 ] || { usage; exit 1; }

CUSTOMER_ID="${ARGS[0]}"
[[ "$CUSTOMER_ID" =~ ^[a-z][a-z0-9-]{0,62}$ ]] || die "invalid customer_id '$CUSTOMER_ID' (expected lowercase [a-z0-9-], no path characters)"
case "${ARGS[1]:-}" in
  development|staging|production) ENV_NAME="${ARGS[1]}" ;;
  "") : ;;
  *) die "unknown environment '${ARGS[1]}' (allowed: development|staging|production)" ;;
esac
for p in "${ARGS[@]:2}"; do
  case "$p" in
    android|ios|web) PLATFORMS+=("$p") ;;
    all) PLATFORMS+=(android ios web) ;;
    *) die "unknown platform '$p' (allowed: android|ios|web|all)" ;;
  esac
done
if [ ${#PLATFORMS[@]} -eq 0 ]; then PLATFORMS=(android ios web); fi
has_platform() { local p; for p in "${PLATFORMS[@]}"; do [ "$p" = "$1" ] && return 0; done; return 1; }

# F01: per-run unique id. BUILDAPP_FAKE_UTC lets tests force the timestamp part
# (deterministic same-minute scenarios); uniqueness never relies on it alone.
BUILD_TS="${BUILDAPP_FAKE_UTC:-}"
[ -n "$BUILD_TS" ] || BUILD_TS="$(date -u +%Y%m%d%H%M%S)"
[[ "$BUILD_TS" =~ ^[0-9]{14}$ ]] || die "BUILDAPP_FAKE_UTC must be YYYYmmddHHMMSS (14 digits)"
# 8-digit build number: fits Android versionCode (max 2100000000) while staying
# unique per minute. run_id adds second-resolution + pid + random suffix, so two
# builds in the same minute can never share a receipt directory (F07).
BUILD_NUMBER="${BUILD_TS:4:8}"

case "$ENV_NAME" in
  development|staging) APP_ENV="dev" ;;
  production)          APP_ENV="pro" ;;
esac

# ---------- workspace & customer layout ----------
[ -d "$FLUTTER_ROOT/.git" ] || [ -f "$FLUTTER_ROOT/.git" ] || die "not a git checkout: $FLUTTER_ROOT"
CUSTOMER_DIR="$CUSTOMERS_ROOT/$CUSTOMER_ID"
CONFIG_DIR="$CUSTOMER_DIR/config"
ASSETS_DIR="$CUSTOMER_DIR/assets"
BUILDS_DIR="$CUSTOMER_DIR/builds"
[ -f "$CONFIG_DIR/app.yaml" ] || die "customer config not found: $CONFIG_DIR/app.yaml (create customers/$CUSTOMER_ID/config/ first)"

CFG_ID="$(yaml_get "$CONFIG_DIR/app.yaml" customer_id)"
[ "$CFG_ID" = "$CUSTOMER_ID" ] || die "app.yaml customer_id '$CFG_ID' != requested '$CUSTOMER_ID'"

APP_NAME="$(yaml_get "$CONFIG_DIR/app.yaml" brand.app_name)"
[ -n "$APP_NAME" ] && [ "$APP_NAME" != "UNCONFIGURED" ] || die "brand.app_name is missing in $CONFIG_DIR/app.yaml"
ASSET_PKG_NAME="$(yaml_get "$CONFIG_DIR/app.yaml" assets.package)"
ASSET_VERSION="$(yaml_get "$CONFIG_DIR/app.yaml" assets.version)"
REPLACEMENT_MAP="$(yaml_get "$CONFIG_DIR/app.yaml" assets.replacement_map)"
AUTH_STATUS="$(yaml_get "$CONFIG_DIR/app.yaml" assets.authorization_status)"
[ -n "$ASSET_PKG_NAME" ] || die "assets.package missing in app.yaml"
# package root: "." = the assets dir itself (flattened package layout);
# otherwise a single relative subdirectory name — reject traversal,
# absolute or nested paths.
case "$ASSET_PKG_NAME" in
  .) : ;;
  /*|*/*|*..*|.*)
    die "invalid assets.package '$ASSET_PKG_NAME' (single relative subdirectory name, or '.')"
    ;;
esac
ASSET_PKG="$ASSETS_DIR/$ASSET_PKG_NAME"
[ -d "$ASSET_PKG" ] || die "asset package directory not found: $ASSET_PKG (assets.package='$ASSET_PKG_NAME')"
[ -n "$REPLACEMENT_MAP" ] && [ -f "$ASSET_PKG/$REPLACEMENT_MAP" ] || die "replacement map not found: $ASSET_PKG/$REPLACEMENT_MAP"

# ---------- identity resolution + fail-closed gates ----------
IDENT_ANDROID="$(yaml_get "$CONFIG_DIR/app.yaml" identity.android_application_id)"
IDENT_IOS="$(yaml_get "$CONFIG_DIR/app.yaml" identity.ios_bundle_id)"
IDENT_SCHEME="$(yaml_get "$CONFIG_DIR/app.yaml" identity.url_scheme)"
DEMO_ANDROID="$(yaml_get "$CONFIG_DIR/app.yaml" identity.demo.android_application_id)"
DEMO_IOS="$(yaml_get "$CONFIG_DIR/app.yaml" identity.demo.ios_bundle_id)"
DEMO_SCHEME_OK="$(yaml_get "$CONFIG_DIR/app.yaml" identity.demo.inherit_vendor_url_scheme)"

ENVPATH="$CONFIG_DIR/environments/$ENV_NAME.env"
[ -f "$ENVPATH" ] || die "environment file missing: $ENVPATH (copy the .env.example and fill real values)"

missing=""
if [ "$ENV_NAME" = "production" ]; then
  case "$IDENT_ANDROID" in ""|UNCONFIGURED|REQUIRED) missing="$missing identity.android_application_id" ;; esac
  case "$IDENT_IOS" in ""|UNCONFIGURED|REQUIRED) missing="$missing identity.ios_bundle_id" ;; esac
  case "$IDENT_SCHEME" in ""|UNCONFIGURED|REQUIRED) missing="$missing identity.url_scheme" ;; esac
  API_VALUE="$(env_get "$ENVPATH" API_BASE_URL)"
  case "$API_VALUE" in ""|UNCONFIGURED|REQUIRED) missing="$missing environments/production.env:API_BASE_URL" ;; esac
  if [ -n "$missing" ]; then
    die "production build is fail-closed; missing required config:$missing
     (vendor production values are NEVER substituted — provide the customer's own)"
  fi
  WS_VALUE="$(env_get "$ENVPATH" WS_URL)"; [ "$WS_VALUE" = "REQUIRED" ] && WS_VALUE=""
  APP_ID="$IDENT_ANDROID"; BUNDLE_ID="$IDENT_IOS"
  API_SOURCE="customer-production"
else
  case "$DEMO_ANDROID" in ""|UNCONFIGURED) die "identity.demo.android_application_id required for $ENV_NAME demo builds" ;; esac
  case "$DEMO_IOS" in ""|UNCONFIGURED) die "identity.demo.ios_bundle_id required for $ENV_NAME demo builds" ;; esac
  API_VALUE="$(env_get "$ENVPATH" API_BASE_URL_OVERRIDE)"
  if [ -n "$API_VALUE" ] && [ "$API_VALUE" != "UNCONFIGURED" ]; then
    API_SOURCE="customer-override"
  else
    API_VALUE=""
    ALLOW_INHERIT="$(env_get "$ENVPATH" ALLOW_DEMO_INHERITED_API)"
    if [ "$ALLOW_INHERIT" = "yes" ]; then
      API_SOURCE="inherited-vendor-demo"
      warn "$ENV_NAME build will inherit the vendor demo backend (explicitly allowed by ALLOW_DEMO_INHERITED_API=yes); disclosed in build manifest"
    else
      die "$ENV_NAME build: API_BASE_URL_OVERRIDE is empty and ALLOW_DEMO_INHERITED_API!=yes — refusing to silently inherit vendor endpoints"
    fi
  fi
  WS_VALUE="$(env_get "$ENVPATH" WS_URL_OVERRIDE)"
  [ "$WS_VALUE" = "UNCONFIGURED" ] && WS_VALUE=""
  APP_ID="$DEMO_ANDROID"; BUNDLE_ID="$DEMO_IOS"
fi

# ---------- URL scheme contract (F09) ----------
scheme_value_is_absent() {
  case "$1" in ""|UNCONFIGURED|REQUIRED) return 0 ;; *) return 1 ;; esac
}
if scheme_value_is_absent "$IDENT_SCHEME"; then
  if [ "$ENV_NAME" = "production" ]; then
    die "production fail-closed: identity.url_scheme is missing — customer builds must never silently reuse the vendor ${VENDOR_URL_SCHEME}:// scheme"
  fi
  [ "$DEMO_SCHEME_OK" = "true" ] \
    || die "$ENV_NAME fail-closed: identity.url_scheme missing and identity.demo.inherit_vendor_url_scheme!=true — refusing to silently inherit the vendor ${VENDOR_URL_SCHEME}:// scheme"
  RESOLVED_SCHEME="$VENDOR_URL_SCHEME"
  SCHEME_RESOLUTION="vendor-demo-inherit"
  SCHEME_INHERITED=1
  URL_SCHEME_NOTE="inherits vendor ${VENDOR_URL_SCHEME}:// scheme (explicitly configured: identity.demo.inherit_vendor_url_scheme=true; disclosed in receipt)"
  warn "URL scheme: inheriting vendor '${VENDOR_URL_SCHEME}' for $ENV_NAME build — explicitly configured; disclosed in build manifest"
else
  python3 "$SCHEME_TOOL" validate-scheme "$IDENT_SCHEME" >/dev/null \
    || die "identity.url_scheme validation failed for '$IDENT_SCHEME' (expected bare lowercase URI scheme [a-z][a-z0-9+.-]{0,39}, no '://', host, path or query)"
  [ "$IDENT_SCHEME" != "$VENDOR_URL_SCHEME" ] \
    || die "identity.url_scheme equals the vendor scheme '${VENDOR_URL_SCHEME}' — customer builds must register a customer-owned scheme (demo inheritance requires identity.demo.inherit_vendor_url_scheme=true instead)"
  RESOLVED_SCHEME="$IDENT_SCHEME"
  SCHEME_RESOLUTION="identity.url_scheme"
  URL_SCHEME_NOTE="customer scheme: $RESOLVED_SCHEME"
fi

[ "$APP_ID" != "$VENDOR_APP_ID" ] || die "resolved application id equals the vendor baseline ('$VENDOR_APP_ID') — refusing to ship an unlabeled vendor build"

# ---------- assets integrity ----------
( cd "$ASSET_PKG" && sha_check manifest/SHA256SUMS ) \
  || die "asset package integrity check FAILED (manifest/SHA256SUMS mismatch): $ASSET_PKG"
info "asset package integrity OK: $ASSET_PKG_NAME v$ASSET_VERSION (authorization_status=$AUTH_STATUS)"
grep -q "authorization_status" "$ASSET_PKG/$REPLACEMENT_MAP" || warn "replacement map has no authorization_status line"

# ---------- lock (concurrency-safe; stale-lock reclaim) ----------
mkdir -p "$LOCK_ROOT" "$WT_ROOT"
LOCK_DIR="$LOCK_ROOT/$CUSTOMER_ID"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  OLD_PID="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
  if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
    die "another build for customer '$CUSTOMER_ID' is running (pid $OLD_PID); concurrent builds are refused"
  fi
  warn "stale lock recovered (previous pid: ${OLD_PID:-unknown})"
  OLD_WT="$(cat "$LOCK_DIR/last_worktree" 2>/dev/null || true)"
  if [ -n "$OLD_WT" ] && [ -d "$OLD_WT" ]; then
    git -C "$FLUTTER_ROOT" worktree remove --force "$OLD_WT" >/dev/null 2>&1 || rm -rf "$OLD_WT"
    warn "orphan worktree removed: $OLD_WT"
  fi
  rm -rf "$LOCK_DIR"
  mkdir "$LOCK_DIR"
fi
LOCK_HELD=1
echo $$ > "$LOCK_DIR/pid"

# ---------- run_id + run-private staging (F01/F02) ----------
STAGING_ROOT="$BUILDS_DIR/.staging"
mkdir -p "$STAGING_ROOT"
STAGING_DIR=""
RUN_ID=""
allocate_staging() {
  local cand="" i=0
  while :; do
    cand="${BUILD_TS}-$$-${RANDOM}${RANDOM}"
    [ $i -gt 0 ] && cand="$cand-$i"
    if mkdir "$STAGING_ROOT/$cand" 2>/dev/null; then
      STAGING_DIR="$STAGING_ROOT/$cand"
      RUN_ID="$cand"
      return 0
    fi
    i=$((i+1))
    [ $i -ge 50 ] && die "cannot allocate a unique staging directory under $STAGING_ROOT"
  done
}
allocate_staging
INVENTORY_FILE="$STAGING_DIR/.inventory"
: > "$INVENTORY_FILE"
artifact_add() { echo "$1" >> "$INVENTORY_FILE"; }   # subshell-safe (build fns run in pipelines)
CHECKS_FILE="$STAGING_DIR/.artifact-checks"
: > "$CHECKS_FILE"
record_check() { printf '%s|%s\n' "$1" "$2" >> "$CHECKS_FILE"; }  # subshell-safe F13 results
read_check() { awk -F'|' -v k="$1" '$1 == k { sub(/^[^|]*\|/, ""); print; exit }' "$CHECKS_FILE"; }
LOG="$STAGING_DIR/build.log"
{
  echo "[buildapp] run started $(date -u +%Y-%m-%dT%H:%M:%SZ) customer=$CUSTOMER_ID env=$ENV_NAME platforms=${PLATFORMS[*]} mode=$([ "$DRY_RUN" = "1" ] && echo dry-run || echo real-build) run_id=$RUN_ID"
  echo "[buildapp] url_scheme resolved=$RESOLVED_SCHEME resolution=$SCHEME_RESOLUTION inherited=$SCHEME_INHERITED"
} > "$LOG"
# final receipt directory: env-scoped, run-unique by construction (F01/F07).
# BUILD_NAME comes from the shared checkout's pubspec (the worktree is created
# from this HEAD, so the value is identical there).
BUILD_NAME="$(awk -F': ' '/^version:/{print $2; exit}' "$FLUTTER_ROOT/pubspec.yaml")"
[ -n "$BUILD_NAME" ] || die "cannot read version from pubspec.yaml"
if [ "$DRY_RUN" = "1" ]; then
  OUT_DIR="$BUILDS_DIR/dry-runs/$ENV_NAME/$BUILD_NAME-$BUILD_NUMBER-$RUN_ID"
else
  OUT_DIR="$BUILDS_DIR/$ENV_NAME/$BUILD_NAME-$BUILD_NUMBER-$RUN_ID"
fi
[ ! -e "$OUT_DIR" ] || die "internal error: receipt directory already exists: $OUT_DIR"

# ---------- isolated worktree ----------
WORKTREE="$WT_ROOT/$CUSTOMER_ID-$ENV_NAME-$RUN_ID"
echo "$WORKTREE" > "$LOCK_DIR/last_worktree"
SRC_COMMIT="$(git -C "$FLUTTER_ROOT" rev-parse HEAD)"
git -C "$FLUTTER_ROOT" worktree add --detach "$WORKTREE" "$SRC_COMMIT" >/dev/null
info "isolated worktree: $WORKTREE (from $SRC_COMMIT)"
# initialize submodules inside the isolated worktree (repo has plugin/flutter_chat_ui;
# without this, path dependencies fail pub get in a fresh worktree)
git -C "$WORKTREE" submodule update --init --recursive \
  || die "submodule init failed in worktree (network/remote issues?)"
info "submodules initialized"
# test-only determinism hook: hold the run inside the isolated phase so
# SIGINT/SIGTERM recovery can be exercised deterministically (see case 15).
# The sleep runs in a background subshell and we wait on it with the `wait`
# builtin — plain foreground `sleep` would make bash DISCARD a SIGINT that
# arrives while waiting for an external command (verified behavior), whereas
# `wait` is interruptible and runs the trap immediately.
if [ -n "${BUILDAPP_TEST_HOLD:-}" ]; then
  info "test hold: sleeping ${BUILDAPP_TEST_HOLD}s (BUILDAPP_TEST_HOLD)"
  ( sleep "$BUILDAPP_TEST_HOLD" ) &
  wait "$!" || true
fi

# copy untracked local build-support files (never committed; disposable copies).
# local.properties is DENY-BY-DEFAULT: only build-path keys are carried over —
# signing keys (storeFile/keyAlias/storePassword/keyPassword), vendor channel
# credentials (jpush.appKey/jpush.masterSecret/huawei.appId/wl.*) must NEVER
# leak into customer demo builds.
if [ -f "$FLUTTER_ROOT/android/local.properties" ]; then
  grep -E '^(sdk\.dir|flutter\.sdk|flutter\.compileSdkVersion|flutter\.buildMode|flutter\.versionName|flutter\.ndkVersion)=' \
    "$FLUTTER_ROOT/android/local.properties" > "$WORKTREE/android/local.properties" || true
  info "local.properties copied (build-path keys only; signing/channel credentials stripped)"
fi
# Firebase config is a client-side build input (not a secret); copy when the
# host checkout has one so fresh worktrees match the vendor CI build inputs.
if [ -f "$FLUTTER_ROOT/android/app/google-services.json" ]; then
  cp "$FLUTTER_ROOT/android/app/google-services.json" "$WORKTREE/android/app/google-services.json"
  info "google-services.json copied (client-side Firebase config)"
fi
if [ -f "$FLUTTER_ROOT/android/key.properties" ]; then
  warn "android/key.properties exists locally; intentionally NOT copied — customer builds never use the vendor release keystore"
fi
for f in .env .env.dev .env.pro .env.local .env.local_home .env.local_office; do
  [ -f "$FLUTTER_ROOT/$f" ] && cp "$FLUTTER_ROOT/$f" "$WORKTREE/$f"
done

# ---------- brand injection ----------
inject_android_identity() {
  local g="$WORKTREE/android/app/build.gradle.kts"
  sedi -e "s|val baseApplicationId = \"$VENDOR_APP_ID\"|val baseApplicationId = \"$APP_ID\"|" "$g"
  grep -q "val baseApplicationId = \"$APP_ID\"" "$g" || die "android applicationId injection failed"
  sedi -e "s|\"JPUSH_PKGNAME\" to \"$VENDOR_APP_ID\"|\"JPUSH_PKGNAME\" to \"$APP_ID\"|" "$g"
  grep -q "\"JPUSH_PKGNAME\" to \"$APP_ID\"" "$g" || die "JPUSH_PKGNAME injection failed"
  local m="$WORKTREE/android/app/src/main/AndroidManifest.xml"
  sedi -e "s|android:label=\"$VENDOR_APP_NAME\"|android:label=\"$APP_NAME\"|" "$m"
  grep -q "android:label=\"$APP_NAME\"" "$m" || die "android label injection failed"
  # F10: replace the vendor deeplink scheme with the customer scheme (scoped to
  # android:scheme="imboy" data attributes; host/pathPrefix/VIEW/DEFAULT/
  # BROWSABLE/https-app-links/SMS/TEL/wechat-pay callbacks untouched), then
  # structurally verify the injected file.
  local js
  js="$(python3 "$SCHEME_TOOL" inject-android "$m" "$RESOLVED_SCHEME")" \
    || die "android url scheme injection failed (see errors above)"
  echo "$js" | python3 -c 'import json,sys
d = json.load(sys.stdin)
print("[buildapp] android url scheme: replaced=%(replaced)s vendor_inherited=%(vendor_inherited)s activity_data_schemes=%(activity_data_schemes)s" % d)' >> "$LOG"
  info "android identity injected: applicationId=$APP_ID label=$APP_NAME url_scheme=$RESOLVED_SCHEME"
}

verify_android_scheme() { # F12: read registration back from the injected file
  local m="$WORKTREE/android/app/src/main/AndroidManifest.xml"
  local flag="" js
  [ "$SCHEME_INHERITED" = "1" ] && flag="--allow-vendor-imboy"
  js="$(python3 "$SCHEME_TOOL" verify-android "$m" "$RESOLVED_SCHEME" $flag)" \
    || die "android url scheme cross-verification FAILED — injected registration does not match the configuration (see errors above)"
  ANDROID_REGISTERED_SCHEMES="$(echo "$js" | jf activity_data_schemes)"
  case ", $ANDROID_REGISTERED_SCHEMES," in
    *", $RESOLVED_SCHEME,"*) : ;;
    *) die "android registered schemes '$ANDROID_REGISTERED_SCHEMES' do not include configured '$RESOLVED_SCHEME'" ;;
  esac
  info "android url scheme verified against injected manifest: [$ANDROID_REGISTERED_SCHEMES]"
}

inject_ios_identity() {
  plist_set_string "$WORKTREE/ios/Runner/Info.plist" CFBundleDisplayName "$APP_NAME" \
    || die "iOS display name injection failed"
  plist_set_string "$WORKTREE/ios/ShareExtension/Info.plist" CFBundleDisplayName "$APP_NAME" \
    || die "ShareExtension display name injection failed"
  sedi "s|$VENDOR_BUNDLE_ID|$BUNDLE_ID|g" "$WORKTREE/ios/Runner.xcodeproj/project.pbxproj"
  # share_handler_ios reads AppGroupId from ShareExtension/Info.plist.
  # Inject one customer-owned group into the extension plist and both targets.
  python3 "$APP_GROUP_TOOL" inject \
    "$WORKTREE/ios/ShareExtension/Info.plist" "group.$BUNDLE_ID" \
    "$WORKTREE"/ios/Runner/*.entitlements \
    "$WORKTREE"/ios/ShareExtension/*.entitlements \
    || die "iOS App Group injection failed — stale or mismatched target groups"
  [ "$(plist_get_string "$WORKTREE/ios/Runner/Info.plist" CFBundleDisplayName)" = "$APP_NAME" ] || die "iOS display name injection failed"
  [ "$(plist_get_string "$WORKTREE/ios/ShareExtension/Info.plist" CFBundleDisplayName)" = "$APP_NAME" ] || die "ShareExtension display name injection failed"
  grep -q "$BUNDLE_ID" "$WORKTREE/ios/Runner.xcodeproj/project.pbxproj" || die "iOS bundle id injection failed"
  python3 "$APP_GROUP_TOOL" verify \
    "$WORKTREE/ios/ShareExtension/Info.plist" "group.$BUNDLE_ID" \
    "$WORKTREE"/ios/Runner/*.entitlements \
    "$WORKTREE"/ios/ShareExtension/*.entitlements \
    || die "iOS App Group cross-verification failed — vendor/cross-customer group remains"
  IOS_APP_GROUP_STATUS="verified"
  # F11: rewrite ONLY the IMBoy deeplink URL type's CFBundleURLSchemes
  # (CFBundleURLName == "imboy.pub"); weixin/alipay/ShareMedia URL types,
  # E2EE backup registrations and every other plist key stay untouched.
  # ShareExtension/Info.plist carries NO CFBundleURLTypes (verified by tests)
  # and is deliberately not scheme-injected.
  local js
  js="$(python3 "$SCHEME_TOOL" inject-ios "$WORKTREE/ios/Runner/Info.plist" "$RESOLVED_SCHEME")" \
    || die "iOS url scheme injection failed (see errors above)"
  echo "$js" | python3 -c 'import json,sys
d = json.load(sys.stdin)
print("[buildapp] ios url scheme: replaced=%(replaced)s vendor_inherited=%(vendor_inherited)s deeplink=%(deeplink_schemes)s preserved=%(other_url_types_preserved)s" % d)' >> "$LOG"
  info "ios identity injected: bundle=$BUNDLE_ID display=$APP_NAME url_scheme=$RESOLVED_SCHEME customer App Group shared by Runner + ShareExtension; no URL registration in extension)"
}

verify_ios_scheme() { # F12: read registration back from the injected file
  local flag="" js
  [ "$SCHEME_INHERITED" = "1" ] && flag="--allow-vendor-imboy"
  js="$(python3 "$SCHEME_TOOL" verify-ios "$WORKTREE/ios/Runner/Info.plist" "$RESOLVED_SCHEME" $flag)" \
    || die "iOS url scheme cross-verification FAILED — injected registration does not match the configuration (see errors above)"
  IOS_REGISTERED_SCHEMES="$(echo "$js" | jf deeplink_schemes)"
  IOS_ALL_URL_SCHEMES="$(echo "$js" | jf all_registered_url_schemes)"
  case ", $IOS_REGISTERED_SCHEMES," in
    *", $RESOLVED_SCHEME,"*) : ;;
    *) die "iOS deeplink URL type schemes '$IOS_REGISTERED_SCHEMES' do not match configured '$RESOLVED_SCHEME'" ;;
  esac
  info "ios url scheme verified against injected plist: deeplink=[$IOS_REGISTERED_SCHEMES] all_types=[$IOS_ALL_URL_SCHEMES]"
}

inject_ios_icons() {
  local real_set="$WORKTREE/ios/Runner/Assets.xcassets/AppIcon.appiconset"
  local pkg_set="$ASSET_PKG/replace/ios/Runner/Assets.xcassets/AppIcon.appiconset"
  [ -d "$pkg_set" ] || die "asset package missing replace/ios/Runner/Assets.xcassets/AppIcon.appiconset"
  python3 - "$real_set" "$pkg_set" "$PNG_TOOL" <<'PYEOF'
import json, subprocess, sys, glob, os
real_set, pkg_set, png_tool = sys.argv[1], sys.argv[2], sys.argv[3]
def px(path):
    out = subprocess.run(['python3', png_tool, 'size', path],
                         capture_output=True, text=True).stdout.split()
    return (int(out[0]), int(out[1])) if len(out) == 2 else (0, 0)
def resize(src, dst, box):
    # sips (macOS, verified Lanczos path) when available; pure-python fallback
    # otherwise so Linux CI runs the same core logic.
    import shutil
    if shutil.which('sips'):
        subprocess.run(['sips', '-z', str(box), str(box), src, '--out', dst],
                       check=True, capture_output=True)
    else:
        subprocess.run(['python3', png_tool, 'resize', src, dst, str(box), str(box)],
                       check=True, capture_output=True)
entries = json.load(open(os.path.join(real_set, 'Contents.json')))['images']
cands = sorted(glob.glob(os.path.join(pkg_set, 'AppIcon-*.png')),
               key=lambda p: px(p)[0], reverse=True)
if not cands:
    sys.exit('no AppIcon-*.png sources in package iconset')
count = 0
for e in entries:
    size, scale = e['size'], e.get('scale', '1x').rstrip('x')
    sw, sh = (float(x) for x in size.split('x'))
    target = int(round(sw * int(scale)))
    exact = [p for p in cands if px(p)[0] == target]
    src = exact[0] if exact else next((p for p in cands if px(p)[0] >= target), cands[0])
    dst = os.path.join(real_set, e['filename'])
    resize(src, dst, target)
    got = px(dst)
    if got != (target, target):
        sys.exit('size mismatch for %s: want %d, got %s' % (e['filename'], target, got))
    count += 1
print('%d icon slots generated from package masters' % count)
PYEOF
  [ -n "$(ls -1 "$real_set"/*.png 2>/dev/null)" ] || die "iOS icon generation produced no files"
  info "ios AppIcon replaced against the real Contents.json slot table"
}

inject_android_res() {
  local src="$ASSET_PKG/replace/android/app/src/main/res"
  [ -d "$src" ] || die "asset package missing replace/android/app/src/main/res"
  # Overlay scope: launcher/adaptive icon resources only. Splash concept
  # drawables (e.g. yaoxin_launch_background.xml — invalid for aapt: inline hex
  # in android:drawable) are excluded while splash.mode=inherit; they are the
  # splash generator's input concern, not the resource overlay's.
  local d
  for d in "$src"/mipmap-*; do
    [ -d "$d" ] && cp -R "$d" "$WORKTREE/android/app/src/main/res/"
  done
  if [ -d "$src/values" ]; then
    mkdir -p "$WORKTREE/android/app/src/main/res/values"
    cp "$src/values/"*.xml "$WORKTREE/android/app/src/main/res/values/" 2>/dev/null || true
  fi
  [ -f "$WORKTREE/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml" ] || die "adaptive icon xml missing after overlay"
  [ -f "$WORKTREE/android/app/src/main/res/values/colors.xml" ] || die "adaptive colors.xml missing after overlay"
  # API 26+ cycle guard: ic_launcher resolves to the anydpi-v26 adaptive XML,
  # so a foreground/background drawable referencing @mipmap/ic_launcher itself
  # is infinite recursion at inflation time — PackageManager logs "Failure
  # retrieving resources ... mipmap/ic_launcher" and the launcher falls back
  # to the system icon (observed on real-device smoke 2026-11-25, fixture
  # ic_launcher.xml v1). Fail the build instead of shipping a fallback icon.
  if grep -q 'android:drawable="@mipmap/ic_launcher"' \
      "$WORKTREE/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml"; then
    die "adaptive icon self-reference: foreground/background must not be @mipmap/ic_launcher (resource cycle on API 26+; use a dedicated ic_launcher_foreground resource)"
  fi
  grep -q "@mipmap/ic_launcher" "$WORKTREE/android/app/src/main/AndroidManifest.xml" || die "manifest icon reference lost"
  info "android res overlay applied (mipmap + anydpi-v26 adaptive + foreground + colors; splash concept drawables excluded under splash.mode=inherit)"
}

inject_web_brand() {
  local w="$WORKTREE/web"
  [ -f "$ASSET_PKG/replace/web/icons/favicon-32.png" ] || die "asset package missing replace/web/icons/favicon-32.png"
  cp "$ASSET_PKG/replace/web/icons/favicon-32.png" "$w/favicon.png"
  cp "$ASSET_PKG/replace/web/icons/icon-192.png" "$w/icons/Icon-192.png"
  cp "$ASSET_PKG/replace/web/icons/icon-512.png" "$w/icons/Icon-512.png"
  mkdir -p "$w/branding"
  cp "$ASSET_PKG/replace/web/branding/"*.png "$w/branding/" 2>/dev/null || true
  for extra in favicon-16.png favicon-48.png favicon-64.png apple-touch-icon.png; do
    [ -f "$ASSET_PKG/replace/web/icons/$extra" ] && cp "$ASSET_PKG/replace/web/icons/$extra" "$w/branding/$extra"
  done
  local primary; primary="$(yaml_get "$CONFIG_DIR/app.yaml" brand.primary_color)"
  WEB_TITLE=""
  [ -f "$CONFIG_DIR/client/public.env" ] && WEB_TITLE="$(env_get "$CONFIG_DIR/client/public.env" WEB_TITLE)"
  [ -n "$WEB_TITLE" ] || WEB_TITLE="$APP_NAME"
  python3 - "$w/manifest.json" "$WEB_TITLE" "$primary" <<'PYEOF'
import json, sys
path, name, color = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(path, encoding='utf-8'))
d['name'] = name
d['short_name'] = name
if color and color.startswith('#'):
    d['theme_color'] = color
json.dump(d, open(path, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
PYEOF
  sedi -e "s|<title>[^<]*</title>|<title>$WEB_TITLE</title>|" \
       -e "s|content=\"ImBoy\"|content=\"$WEB_TITLE\"|g" \
       -e "s|favicon.png?v=[A-Za-z0-9_.-]*|favicon.png?v=${CUSTOMER_ID}-${ASSET_VERSION}|" "$w/index.html"
  grep -q "<title>$WEB_TITLE</title>" "$w/index.html" || die "web title injection failed"
  cmp -s "$ASSET_PKG/replace/web/icons/favicon-32.png" "$w/favicon.png" || die "web favicon copy verification failed"
  # pixel-level verification: copied PWA icons must be real, correctly sized images
  local icon_expect icon_file got
  for icon_expect in "icons/Icon-192.png:192" "icons/Icon-512.png:512"; do
    icon_file="$w/${icon_expect%%:*}"
    got="$(png_size "$icon_file" || true)"
    [ "$got" = "${icon_expect##*:} ${icon_expect##*:}" ] || die "web icon verification failed: $icon_file (expected ${icon_expect##*:}x${icon_expect##*:}, got '${got:-unreadable}')"
  done
  info "web brand injected: title=$WEB_TITLE favicon/icons replaced (cache-bust ?v=${CUSTOMER_ID}-${ASSET_VERSION})"
}

apply_splash_policy() {
  local mode; mode="$(yaml_get "$CONFIG_DIR/app.yaml" splash.mode)"
  case "$mode" in
    inherit|"")
      info "splash policy: inherit vendor-generated native splash (no overwrite)"
      ;;
    regenerate)
      local src; src="$(yaml_get "$CONFIG_DIR/app.yaml" splash.source)"
      case "$src" in ""|UNCONFIGURED) die "splash.mode=regenerate requires splash.source" ;; esac
      [ -f "$ASSET_PKG/$src" ] || die "splash.source not found in package: $src"
      warn "splash.mode=regenerate rewrites flutter_native_splash sources; ensure brand visual QA sign-off before release use"
      cp "$ASSET_PKG/$src" "$WORKTREE/assets/images/customer_splash_logo.png"
      sedi -e 's|image: assets/images/splash_logo.png|image: assets/images/customer_splash_logo.png|g' \
           -e 's|image_dark: assets/images/splash_logo.png|image_dark: assets/images/customer_splash_logo.png|g' \
           "$WORKTREE/flutter_native_splash.yaml"
      ( cd "$WORKTREE" && dart run flutter_native_splash:create )
      info "splash regenerated from customer source"
      ;;
    *) die "unknown splash.mode: $mode (inherit|regenerate)" ;;
  esac
}

info "== brand injection (isolated worktree; scoped to: ${PLATFORMS[*]}) =="
if has_platform android; then inject_android_identity; verify_android_scheme; fi
if has_platform ios;    then inject_ios_identity; verify_ios_scheme; fi
if has_platform ios;    then inject_ios_icons; fi
if has_platform android; then inject_android_res; fi
if has_platform web;    then inject_web_brand; fi
if has_platform android || has_platform ios; then apply_splash_policy; fi

# F12: overall validation status from ACTUAL injected native files (not config)
if has_platform android || has_platform ios; then
  if [ "$SCHEME_INHERITED" = "1" ]; then
    URL_SCHEME_VALIDATION="verified-vendor-inherited"
  else
    URL_SCHEME_VALIDATION="verified"
  fi
else
  URL_SCHEME_VALIDATION="config-validated-web-only"
fi

# ---------- dart-define assembly ----------
DEFINES=(--dart-define=APP_ENV="$APP_ENV")
[ -n "$API_VALUE" ] && DEFINES+=(--dart-define=API_BASE_URL_OVERRIDE="$API_VALUE")
[ -n "$WS_VALUE" ] && DEFINES+=(--dart-define=WS_URL_OVERRIDE="$WS_VALUE")
PUSH_DEMO="$(yaml_get "$CONFIG_DIR/features.yaml" features.push.demo_enabled)"
[ "$PUSH_DEMO" = "false" ] && DEFINES+=(--dart-define=IMBOY_JPUSH_ENABLED=false)

# ---------- pre-build gates (mirror existing release scripts) ----------
# BUILD_NAME was already resolved from the shared checkout before the staging
# dir was laid out; re-assert it matches the worktree copy (same commit).
[ "$(awk -F': ' '/^version:/{print $2; exit}' "$WORKTREE/pubspec.yaml")" = "$BUILD_NAME" ] \
  || die "pubspec version differs between checkout and isolated worktree"

CODEGEN_DISCLOSURE=""
if [ "$DRY_RUN" = "0" ] && { has_platform android || has_platform ios; }; then
  # envied/riverpod generated *.g.dart files are untracked; a fresh worktree lacks
  # them, so native Dart compilation fails on undefined names (_Env). Regenerate
  # inside the disposable worktree from the copied .env files.
  info "regenerating build_runner artifacts (envied etc.) inside isolated worktree"
  # Use flutter-driven pub resolution: a fresh worktree has no
  # .dart_tool/package_config.json, and `dart run` would implicitly run
  # `dart pub get`, which cannot resolve `sdk: flutter` dependencies
  # (flutter_secure_storage_platform_interface) — "Flutter users should use
  # `flutter pub`". This is an SDK-dependency resolution error, NOT a network
  # error. flutter pub get --enforce-lockfile resolves the tracked
  # pubspec.lock without upgrading; matches .github/scripts/ci_gen_env.sh.
  ( cd "$WORKTREE" && flutter pub get --enforce-lockfile \
      && flutter pub run build_runner build --delete-conflicting-outputs ) \
    || die "build_runner codegen failed (stage: flutter pub get / build_runner; see log above for resolution-vs-network-vs-codegen)"
  CODEGEN_DISCLOSURE="envied/build_runner codegen regenerated in-worktree from vendor .env files; demo artifacts embed vendor demo client-side credentials (client-extractable by design, same disclosure posture as inherited demo API)"
fi

GATE_DISCLOSURE=""
FEATURES_GATE="$(yaml_get "$CONFIG_DIR/app.yaml" build_policy.features_gate)"
[ -n "$FEATURES_GATE" ] || FEATURES_GATE="enforce"
if [ "$DRY_RUN" = "0" ]; then
  ( cd "$WORKTREE" && python3 scripts/check_sdk_compatibility.py ) || die "SDK compatibility check failed"
  if [ "$ENV_NAME" != "production" ] && [ "$FEATURES_GATE" = "skip_with_disclosure" ]; then
    warn "backend product-features gate skipped by build_policy.features_gate=skip_with_disclosure (demo/staging only); disclosed in build manifest"
    GATE_DISCLOSURE="backend product-features gate skipped via build_policy.features_gate=skip_with_disclosure; backend workspace may not be full-selected (vendor release gate untouched for production)"
  else
    BACKEND_ROOT="$WORKSPACE_ROOT/imboy"
    [ -d "$BACKEND_ROOT" ] || die "backend repo not found at $BACKEND_ROOT (required by the full-selected features gate)"
    python3 "$BACKEND_ROOT/scripts/generate_product_features.py" --check --require-profile full-selected \
      || die "backend product-features gate failed (full-selected profile required, same as existing release scripts; or set build_policy.features_gate=skip_with_disclosure for demo builds)"
  fi
fi

# ---------- artifact manifest checks on REAL build outputs (F13) ----------
android_sdk_dir() {
  local d=""
  [ -n "${ANDROID_HOME:-}" ] && d="$ANDROID_HOME"
  [ -z "$d" ] && [ -n "${ANDROID_SDK_ROOT:-}" ] && d="$ANDROID_SDK_ROOT"
  if [ -z "$d" ] && [ -f "$WORKTREE/android/local.properties" ]; then
    d="$(awk -F= '$1=="sdk.dir"{sub(/^sdk.dir=/,""); print; exit}' "$WORKTREE/android/local.properties" | tr -d '\r')"
  fi
  [ -n "$d" ] && [ -d "$d" ] && { echo "$d"; return 0; }
  return 1
}

verify_android_apk_schemes() { # $1=apk  -> sets ANDROID_APK_SCHEMES / ANDROID_APK_TOOL
  local apk="$1" sdk dump js
  sdk="$(android_sdk_dir)" || die "cannot verify final APK manifest: Android SDK not found (ANDROID_HOME/ANDROID_SDK_ROOT/sdk.dir)"
  local apkanalyzer="" aapt2="" cand
  for cand in "$sdk"/cmdline-tools/latest/bin/apkanalyzer "$sdk"/cmdline-tools/*/bin/apkanalyzer; do
    [ -x "$cand" ] && apkanalyzer="$cand" && break
  done
  if [ -n "$apkanalyzer" ] && command -v java >/dev/null 2>&1; then
    dump="$(mktemp "${TMPDIR:-/tmp}/apk-manifest.XXXXXX")"
    if "$apkanalyzer" manifest print "$apk" > "$dump" 2>/dev/null && [ -s "$dump" ]; then
      local flag=""; [ "$SCHEME_INHERITED" = "1" ] && flag="--allow-vendor-imboy"
      js="$(python3 "$SCHEME_TOOL" verify-android "$dump" "$RESOLVED_SCHEME" $flag)" || { rm -f "$dump"; die "final APK merged-manifest scheme verification FAILED (apkanalyzer): $apk"; }
      ANDROID_APK_SCHEMES="$(echo "$js" | jf activity_data_schemes)"
      ANDROID_APK_TOOL="apkanalyzer manifest print"
      record_check ANDROID_APK_SCHEMES "$ANDROID_APK_SCHEMES"
      record_check ANDROID_APK_TOOL "$ANDROID_APK_TOOL"
      rm -f "$dump"
      return 0
    fi
    rm -f "$dump"
  fi
  for cand in "$sdk"/build-tools/*/aapt2; do
    [ -x "$cand" ] && aapt2="$cand" && break
  done
  [ -n "$aapt2" ] || die "cannot verify final APK manifest: no apkanalyzer (with java) or aapt2 under $sdk"
  dump="$(mktemp "${TMPDIR:-/tmp}/apk-xmltree.XXXXXX")"
  "$aapt2" dump xmltree --file AndroidManifest.xml "$apk" > "$dump" 2>/dev/null || { rm -f "$dump"; die "aapt2 xmltree dump failed: $apk"; }
  js="$(python3 "$SCHEME_TOOL" parse-aapt2 "$dump")" || { rm -f "$dump"; die "aapt2 xmltree parse failed"; }
  rm -f "$dump"
  local got=""; got="$(echo "$js" | jf activity_data_schemes)"
  case ", $got," in
    *", $RESOLVED_SCHEME,"*) : ;;
    *) die "final APK merged-manifest scheme verification FAILED: activity schemes [$got] do not include '$RESOLVED_SCHEME'" ;;
  esac
  if [ "$SCHEME_INHERITED" != "1" ]; then
    case ", $got," in
      *", $VENDOR_URL_SCHEME,"*) die "final APK merged-manifest still registers vendor scheme '$VENDOR_URL_SCHEME'" ;;
    esac
  fi
  ANDROID_APK_SCHEMES="$got"
  ANDROID_APK_TOOL="aapt2 dump xmltree"
  record_check ANDROID_APK_SCHEMES "$got"
  record_check ANDROID_APK_TOOL "$ANDROID_APK_TOOL"
}

verify_ios_app_schemes() { # $1=Runner.app dir -> sets IOS_APP_SCHEMES
  local plist="$1/Info.plist"
  [ -f "$plist" ] || die "cannot verify built iOS app: $plist missing"
  local flag="" js
  [ "$SCHEME_INHERITED" = "1" ] && flag="--allow-vendor-imboy"
  js="$(python3 "$SCHEME_TOOL" verify-ios "$plist" "$RESOLVED_SCHEME" $flag)" \
    || die "built Runner.app Info.plist scheme verification FAILED (plistlib): $plist"
  IOS_APP_SCHEMES="$(echo "$js" | jf deeplink_schemes)"
  record_check IOS_APP_SCHEMES "$IOS_APP_SCHEMES"
}

# ---------- gradle proxy hygiene (worktree copy only) ----------
prepare_gradle_proxy() {
  # The tracked android/gradle.properties carries the developer's local proxy
  # (systemProp.{http,https}.proxyHost=127.0.0.1 / proxyPort=7897). On hosts
  # where that proxy is not listening (e.g. CI), gradle dies within a second
  # with "java.net.ConnectException: Connection refused". The main CI strips
  # those lines unconditionally before building; here the strip is
  # environment-adaptive and confined to the ISOLATED worktree copy — the
  # shared checkout is never modified, and a live local proxy is preserved.
  local gp="$WORKTREE/android/gradle.properties"
  [ -f "$gp" ] || return 0
  local host port
  host="$(awk -F= '/^systemProp\.http\.proxyHost=/{print $2; exit}' "$gp" | tr -d '\r')"
  port="$(awk -F= '/^systemProp\.http\.proxyPort=/{print $2; exit}' "$gp" | tr -d '\r')"
  [ -n "$host" ] && [ -n "$port" ] || return 0
  if (exec 3<>"/dev/tcp/$host/$port") 2>/dev/null; then
    exec 3>&- 3<&- 2>/dev/null || true
    info "gradle proxy $host:$port reachable; kept in worktree gradle.properties"
  else
    sedi '/^systemProp\.http\.proxy/d;/^systemProp\.https\.proxy/d' "$gp"
    info "gradle proxy $host:$port unreachable; stripped proxy lines from worktree gradle.properties (shared checkout untouched)"
  fi
}

# ---------- gradle repository mode (mirror off by default; gapclose 20261125) ----------
prepare_gradle_repository_mode() {
  # 2026-11-25 CI incident: the aliyun mirror answered 502 and Gradle's 5xx
  # handling does NOT fall through to the later google()/mavenCentral() entries
  # (android/settings.gradle.kts lists mirrors FIRST when
  # imboyUseMavenMirror=true, which is that file's default for local dev).
  # This CI-facing build path therefore pins the mirror OFF (direct official
  # repos) unless the caller explicitly opts back in with
  # IMBOY_USE_MAVEN_MIRROR=true. ORG_GRADLE_PROJECT_* is Gradle's documented
  # environment -> project property bridge, honored by
  # providers.gradleProperty() in settings and build scripts alike; nothing in
  # the shared checkout is modified.
  local mode="${IMBOY_USE_MAVEN_MIRROR:-false}"
  export ORG_GRADLE_PROJECT_imboyUseMavenMirror="$mode"
  info "gradle repository mode: imboyUseMavenMirror=$mode (direct official repos by default; opt-in via IMBOY_USE_MAVEN_MIRROR=true)"
}

# ---------- builds (into the run-private staging dir; F02/F03) ----------
DEMO_SIGNING_DISCLOSURE=""
ensure_android_demo_signing() {
  # vendor key.properties is deliberately never copied (deny-by-default), so
  # demo builds need their own throwaway keystore: generated once per customer
  # under customers/<id>/signing/, fixed non-secret passphrase (documented).
  local kp="$WORKTREE/android/key.properties"
  [ -f "$kp" ] && return 0
  local ks_dir="$CUSTOMER_DIR/signing"
  mkdir -p "$ks_dir" || return 1
  local ks="$ks_dir/demo-release.keystore"
  if [ ! -f "$ks" ]; then
    keytool -genkeypair -keystore "$ks" -storepass imboydemo -keypass imboydemo \
      -alias demo -keyalg RSA -keysize 2048 -validity 10000 \
      -dname "CN=$CUSTOMER_ID pre-sales demo (throwaway)" >/dev/null 2>&1 || return 1
    info "demo keystore generated: $ks (throwaway; never for production/store)"
  fi
  { echo "storeFile=$ks"
    echo "storePassword=imboydemo"
    echo "keyAlias=demo"
    echo "keyPassword=imboydemo"
  } > "$kp" || return 1
  DEMO_SIGNING_DISCLOSURE="android demo build signed with a locally generated throwaway keystore (customers/$CUSTOMER_ID/signing/demo-release.keystore, documented passphrase); production requires customer-supplied signing credentials"
  info "demo signing prepared (throwaway keystore)"
}

build_android() {
  # key.properties is prepared in the main shell (demo: throwaway keystore /
  # production: customer-supplied file) before the build loop starts.
  [ -f "$WORKTREE/android/key.properties" ] || { echo "[buildapp] android signing not prepared" >&2; return 1; }
  info "== building android (flavor standard) =="
  ( cd "$WORKTREE" && flutter build apk --release \
      --flavor standard \
      --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER" \
      -t lib/main.dart "${DEFINES[@]}" ) || return 1
  # flavored builds emit app-<flavor>-release.apk; resolve instead of assuming
  local apk
  apk="$(ls "$WORKTREE"/build/app/outputs/flutter-apk/app-*-release*.apk 2>/dev/null | head -1)"
  [ -n "$apk" ] || { echo "[buildapp] no flavored release apk exists under build/app/outputs/flutter-apk/" >&2; return 1; }
  mkdir -p "$STAGING_DIR/android" || return 1
  cp "$apk" "$STAGING_DIR/android/app-release.apk" || return 1
  # F13: verify the FINAL APK's merged manifest, not the source tree
  verify_android_apk_schemes "$STAGING_DIR/android/app-release.apk" || return 1
  artifact_add "android/app-release.apk"
  echo "[buildapp] android artifact verified (apk url schemes: $ANDROID_APK_SCHEMES via $ANDROID_APK_TOOL)" >> "$LOG"
  info "android artifact: $STAGING_DIR/android/app-release.apk (from $(basename "$apk")); merged-manifest schemes=[$ANDROID_APK_SCHEMES]"
}

build_ios() {
  info "== building ios (unsigned; IPA export BLOCKED without customer signing credentials) =="
  ( cd "$WORKTREE" && flutter build ios --release --no-codesign \
      --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER" \
      -t lib/main.dart "${DEFINES[@]}" ) || return 1
  [ -d "$WORKTREE/build/ios/iphoneos/Runner.app" ] || { echo "[buildapp] Runner.app missing after build" >&2; return 1; }
  # F13: verify the BUILT app's Info.plist (plistlib), not the source plist
  verify_ios_app_schemes "$WORKTREE/build/ios/iphoneos/Runner.app" || return 1
  mkdir -p "$STAGING_DIR/ios" || return 1
  ( cd "$WORKTREE/build/ios/iphoneos" && zip -qry "$STAGING_DIR/ios/Runner-unsigned.app.zip" Runner.app ) || return 1
  artifact_add "ios/Runner-unsigned.app.zip"
  echo "[buildapp] ios artifact verified (Runner.app url schemes: $IOS_APP_SCHEMES)" >> "$LOG"
  info "ios artifact: $STAGING_DIR/ios/Runner-unsigned.app.zip (NOT an IPA; archive/export requires customer certs); app schemes=[$IOS_APP_SCHEMES]"
}

build_web() {
  info "== building web (reuses web/build_web.sh) =="
  ( cd "$WORKTREE" && bash web/build_web.sh ) || return 1
  mkdir -p "$STAGING_DIR/web" || return 1
  # /. form: copy CONTENTS into the existing target dir (plain cp -R would nest web/web/)
  cp -R "$WORKTREE/build/web/." "$STAGING_DIR/web/" || return 1
  cmp -s "$WORKTREE/web/favicon.png" "$STAGING_DIR/web/favicon.png" || { echo "[buildapp] web output favicon mismatch" >&2; return 1; }
  grep -q "$WEB_TITLE" "$STAGING_DIR/web/index.html" || { echo "[buildapp] web output title mismatch" >&2; return 1; }
  artifact_add "web/"
  info "web artifact: $STAGING_DIR/web/"
}

BUILD_STATUS="PASS"
[ "$DRY_RUN" = "1" ] && BUILD_STATUS="DRY_RUN"
# prepare signing in the MAIN shell (build functions run in pipeline subshells;
# their variable assignments would not propagate to the manifest block)
if [ "$DRY_RUN" = "0" ] && has_platform android; then
  prepare_gradle_repository_mode
  prepare_gradle_proxy
  if [ "$ENV_NAME" = "production" ]; then
    [ -f "$CUSTOMER_DIR/signing/key.properties" ] || die "production android requires customers/$CUSTOMER_ID/signing/key.properties (customer-supplied signing)"
    cp "$CUSTOMER_DIR/signing/key.properties" "$WORKTREE/android/key.properties"
  else
    ensure_android_demo_signing
  fi
fi
if [ "$DRY_RUN" = "1" ]; then
  info "dry-run: injection + url-scheme verification done; skipping flutter builds (no artifacts produced)"
  echo "[buildapp] dry-run: no flutter builds; receipt contains no artifacts (F06)" >> "$LOG"
else
  for p in "${PLATFORMS[@]}"; do
    if ! "build_$p" 2>&1 | tee -a "$LOG"; then
      die "platform build failed: $p (evidence kept under builds/failed-runs/; log: build.log)"
    fi
  done
fi

# ---------- build receipt (F03/F05: manifest LAST, atomic publish) ----------
# Expand the run inventory (F03): directories expand to their files (everything
# inside staging was produced by THIS run — the staging dir started empty).
INVENTORY=()
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  if [ -d "$STAGING_DIR/$rel" ]; then
    while IFS= read -r f; do INVENTORY+=("${f#"$STAGING_DIR"/}"); done < <(find "$STAGING_DIR/$rel" -type f | sort)
  else
    [ -f "$STAGING_DIR/$rel" ] || die "inventory entry missing in staging: $rel"
    INVENTORY+=("$rel")
  fi
done < "$INVENTORY_FILE"
rm -f "$INVENTORY_FILE"
# F13 results were recorded from pipeline subshells; read them back for the receipt
_r="$(read_check ANDROID_APK_SCHEMES)"; [ -n "$_r" ] && ANDROID_APK_SCHEMES="$_r"
_r="$(read_check ANDROID_APK_TOOL)";    [ -n "$_r" ] && ANDROID_APK_TOOL="$_r"
_r="$(read_check IOS_APP_SCHEMES)";     [ -n "$_r" ] && IOS_APP_SCHEMES="$_r"
rm -f "$CHECKS_FILE"

MANIFEST="$STAGING_DIR/build-manifest.yaml"
{
  echo "run_id: $RUN_ID"
  echo "receipt_version: 2"
  echo "customer_id: $CUSTOMER_ID"
  echo "customer_type: $(yaml_get "$CONFIG_DIR/app.yaml" customer_type)"
  echo "project_purpose: $(yaml_get "$CONFIG_DIR/app.yaml" project_purpose)"
  echo "authorization_status: $AUTH_STATUS"
  echo "store_submission_allowed: $(yaml_get "$CONFIG_DIR/app.yaml" store_submission.allowed)"
  echo "mode: $( [ "$DRY_RUN" = "1" ] && echo dry-run || echo real-build )"
  echo "environment: $ENV_NAME"
  echo "app_env: $APP_ENV"
  echo "platforms: ${PLATFORMS[*]}"
  echo "build_status: $BUILD_STATUS"
  echo "source_commit: $SRC_COMMIT"
  echo "build_name: \"$BUILD_NAME\""
  echo "build_number: $BUILD_NUMBER"
  echo "generated_at_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "assets:"
  echo "  package: $ASSET_PKG_NAME"
  echo "  version: $ASSET_VERSION"
  echo "  replacement_map: $REPLACEMENT_MAP"
  echo "identity_used:"
  echo "  android_application_id: $APP_ID"
  echo "  ios_bundle_id: $BUNDLE_ID"
  echo "  display_name: $APP_NAME"
  echo "  ios_app_group_id: group.$BUNDLE_ID"
  echo "ios_app_group_validation_status: $IOS_APP_GROUP_STATUS"
  echo "ios_app_group_evidence_source: ShareExtension-Info.plist + Runner/ShareExtension-entitlements"
  echo "  url_scheme: $URL_SCHEME_NOTE"
  echo "url_scheme:"
  echo "  configured_url_scheme: $RESOLVED_SCHEME"
  echo "  resolution: $SCHEME_RESOLUTION"
  echo "  vendor_scheme_inherited: $([ "$SCHEME_INHERITED" = "1" ] && echo true || echo false)"
  echo "  android_registered_url_schemes: \"$ANDROID_REGISTERED_SCHEMES\""
  echo "  ios_registered_url_schemes: \"$IOS_REGISTERED_SCHEMES\""
  echo "  ios_all_url_type_schemes: \"$IOS_ALL_URL_SCHEMES\""
  echo "  url_scheme_validation_status: $URL_SCHEME_VALIDATION"
  echo "  registration_evidence_source: injected-native-files (structural parse, F12)"
  echo "  device_coexistence_test_status: DEVICE_TEST_PENDING"
  echo "api:"
  echo "  source: $API_SOURCE"
  echo "artifact_checks:"
  echo "  android_apk_url_schemes: \"$ANDROID_APK_SCHEMES\""
  echo "  android_apk_check_tool: $ANDROID_APK_TOOL"
  echo "  ios_app_url_schemes: \"$IOS_APP_SCHEMES\""
  echo "artifacts:"
  if [ ${#INVENTORY[@]} -eq 0 ]; then
    echo "  []"
  else
    for rel in "${INVENTORY[@]}"; do echo "  - $rel"; done
  fi
  echo "features_injected:"
  echo "  push_demo_enabled: $PUSH_DEMO"
  echo "  features_gate: $FEATURES_GATE"
  echo "disclosures:"
  echo "  - brand resources carry authorization_status=$AUTH_STATUS; NOT for store submission or public release"
  echo "  - ios IPA export not performed unless customer signing credentials are configured (unsigned .app.zip only)"
  echo "  - vendor release keystore and vendor production endpoints are never substituted into customer builds"
  if [ "$API_SOURCE" = "inherited-vendor-demo" ]; then
    echo "  - demo build inherits vendor demo backend by explicit ALLOW_DEMO_INHERITED_API=yes"
  fi
  if [ "$SCHEME_INHERITED" = "1" ]; then
    echo "  - URL scheme: $ENV_NAME build INHERITS the vendor ${VENDOR_URL_SCHEME}:// scheme (explicitly configured identity.demo.inherit_vendor_url_scheme=true); never valid for production"
  fi
  [ -n "$GATE_DISCLOSURE" ] && echo "  - $GATE_DISCLOSURE"
  [ -n "$CODEGEN_DISCLOSURE" ] && echo "  - $CODEGEN_DISCLOSURE"
  [ -n "$DEMO_SIGNING_DISCLOSURE" ] && echo "  - $DEMO_SIGNING_DISCLOSURE"
  echo "  - dual-app coexistence (vendor IMBoy + this build on one device) NOT verified on a real device yet: DEVICE_TEST_PENDING"
  echo "log: build.log"
} > "$MANIFEST"

# SHA256SUMS covers exactly: this run's inventory + manifest + log (F03/F05).
(
  cd "$STAGING_DIR" || exit 1
  files=(build-manifest.yaml build.log)
  if [ ${#INVENTORY[@]} -gt 0 ]; then files+=("${INVENTORY[@]}"); fi
  sha_sum "${files[@]}" > SHA256SUMS || exit 1
  sha_check SHA256SUMS || exit 1
) || die "artifact SHA256SUMS generation/self-check failed"

# F05: atomic publish — single rename inside the same filesystem; the receipt
# directory appears fully-formed or not at all. A pre-existing target (unique
# run_id makes this a shouldn't-happen) is a hard error, never an overwrite.
mkdir -p "$(dirname "$OUT_DIR")"
if ! mv "$STAGING_DIR" "$OUT_DIR" 2>/dev/null || [ ! -f "$OUT_DIR/SHA256SUMS" ]; then
  die "atomic receipt publish failed: $OUT_DIR"
fi
PUBLISHED=1
info "receipt published atomically: $OUT_DIR"

info "== DONE ($BUILD_STATUS) mode=$([ "$DRY_RUN" = "1" ] && echo dry-run || echo real-build) artifacts: $OUT_DIR =="
[ "$AUTH_STATUS" = "pre_sales_demo_unverified_brand_rights" ] && warn "authorization_status=$AUTH_STATUS — demo/proposal use only, never store submission"
exit 0
