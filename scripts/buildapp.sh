#!/usr/bin/env bash
# buildapp.sh — multi-customer isolated APP build entry for imboy-flutter.
#
# Usage:
#   bash scripts/buildapp.sh <customer_id> [environment] [platforms...] [--dry-run]
#     environment: development | staging | production   (default: production)
#     platforms:   android | ios | web | all            (default: all)
#   bash scripts/buildapp.sh --help
#
# Design contract (PRD V1.1 §5 / Plan P02 / D21):
#   * One shared entry for every customer; no customer id is hardcoded here.
#   * Customer config:   ../customers/<id>/config/   (app.yaml + features.yaml + env files)
#   * Customer assets:   ../customers/<id>/assets/   (full package, SHA256SUMS-verified)
#   * Build artifacts:   ../customers/<id>/builds/<env>/<version>-<build_number>/
#   * Injection happens in an ISOLATED git worktree; the shared checkout is never
#     modified (survives failure, Ctrl-C, SIGTERM; stale locks/worktrees are
#     reclaimed on the next run — a SIGKILL leaves state that the next run cleans).
#   * Production builds fail-closed while required identity/API config is missing.
#   * Server secrets and signing credentials never pass through this script.
#
# Platform notes: written for macOS (BSD sed/plutil/sips). Build reuses the
# existing per-platform scripts where they are customer-agnostic (web/build_web.sh,
# scripts/check_sdk_compatibility.py, backend generate_product_features gate);
# build_android_apk.sh / build_ios.sh were evaluated and NOT reused because they
# hardcode vendor-release behavior (changelog version gate, vendor Alipay appId,
# APP_ENV=pro, vendor default signing) — see scripts/buildapp.md.

set -euo pipefail

SELF_VERSION="1.0.0"
VENDOR_APP_ID="pub.imboy.app"        # vendor baseline application id (gradle/pbxproj)
VENDOR_BUNDLE_ID="pub.imboy.app"
VENDOR_APP_NAME="IMBoy"

FLUTTER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_ROOT="$(dirname "$FLUTTER_ROOT")"
CUSTOMERS_ROOT="$WORKSPACE_ROOT/customers"
LOCK_ROOT="$WORKSPACE_ROOT/.buildapp-locks"
WT_ROOT="$WORKSPACE_ROOT/.buildapp-worktrees"

CUSTOMER_ID=""
ENV_NAME="production"
PLATFORMS=()
DRY_RUN=0

WORKTREE=""
LOCK_DIR=""
LOCK_HELD=0
CLEAN_DONE=0

APP_NAME="" ; APP_ID="" ; BUNDLE_ID="" ; URL_SCHEME_NOTE="" ; APP_ENV=""
API_SOURCE="unconfigured" ; API_VALUE="" ; WS_VALUE=""
ASSET_PKG="" ; ASSET_VERSION="" ; REPLACEMENT_MAP="" ; AUTH_STATUS="unknown"
WEB_TITLE="" ; PUSH_DEMO="unset"

info()  { echo "[buildapp] $*"; }
warn()  { echo "[buildapp] WARNING: $*" >&2; }
die()   { echo "[buildapp] ERROR: $*" >&2; exit 1; }

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
  --dry-run     validate config/assets, apply brand injection in an isolated
                worktree, verify, write a dry-run build-manifest, clean up.
                No flutter/xcodebuild invocation.
  --help        show this help

Examples:
  bash scripts/buildapp.sh yaoxin                       # production all (fail-closed until configured)
  bash scripts/buildapp.sh yaoxin development android   # demo APK
  bash scripts/buildapp.sh yaoxin development web --dry-run
EOF
}

cleanup() {
  [ "$CLEAN_DONE" = "1" ] && return
  CLEAN_DONE=1
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
trap 'echo "[buildapp] interrupted (SIGINT); cleaning isolated workspace..." >&2; exit 130' INT
trap 'echo "[buildapp] terminated (SIGTERM); cleaning isolated workspace..." >&2; exit 143' TERM

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
BUILD_TS="$(date -u +%Y%m%d%H%M%S)"
# 8-digit build number: fits Android versionCode (max 2100000000) while staying unique per minute.
BUILD_NUMBER="$(date -u +%m%d%H%M)"

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
  API_VALUE="$(env_get "$ENVPATH" API_BASE_URL)"
  case "$API_VALUE" in ""|UNCONFIGURED|REQUIRED) missing="$missing environments/production.env:API_BASE_URL" ;; esac
  if [ -n "$missing" ]; then
    die "production build is fail-closed; missing required config:$missing
     (vendor production values are NEVER substituted — provide the customer's own)"
  fi
  WS_VALUE="$(env_get "$ENVPATH" WS_URL)"; [ "$WS_VALUE" = "REQUIRED" ] && WS_VALUE=""
  APP_ID="$IDENT_ANDROID"; BUNDLE_ID="$IDENT_IOS"
  API_SOURCE="customer-production"
  URL_SCHEME_NOTE="customer scheme: ${IDENT_SCHEME:-UNCONFIGURED}"
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
  URL_SCHEME_NOTE="inherits vendor imboy:// scheme (demo limitation: inherit_vendor_url_scheme=$DEMO_SCHEME_OK)"
fi
[ "$APP_ID" != "$VENDOR_APP_ID" ] || die "resolved application id equals the vendor baseline ('$VENDOR_APP_ID') — refusing to ship an unlabeled vendor build"

# ---------- assets integrity ----------
( cd "$ASSET_PKG" && shasum -a 256 -c manifest/SHA256SUMS --status ) \
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

# ---------- isolated worktree ----------
WORKTREE="$WT_ROOT/$CUSTOMER_ID-$ENV_NAME-$BUILD_TS"
echo "$WORKTREE" > "$LOCK_DIR/last_worktree"
SRC_COMMIT="$(git -C "$FLUTTER_ROOT" rev-parse HEAD)"
git -C "$FLUTTER_ROOT" worktree add --detach "$WORKTREE" "$SRC_COMMIT" >/dev/null
info "isolated worktree: $WORKTREE (from $SRC_COMMIT)"
# initialize submodules inside the isolated worktree (repo has plugin/flutter_chat_ui;
# without this, path dependencies fail pub get in a fresh worktree)
git -C "$WORKTREE" submodule update --init --recursive \
  || die "submodule init failed in worktree (network/remote issues?)"
info "submodules initialized"

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
if [ -f "$FLUTTER_ROOT/android/key.properties" ]; then
  warn "android/key.properties exists locally; intentionally NOT copied — customer builds never use the vendor release keystore"
fi
for f in .env .env.dev .env.pro .env.local .env.local_home .env.local_office; do
  [ -f "$FLUTTER_ROOT/$f" ] && cp "$FLUTTER_ROOT/$f" "$WORKTREE/$f"
done

# ---------- brand injection ----------
inject_android_identity() {
  local g="$WORKTREE/android/app/build.gradle.kts"
  sed -i '' -e "s|val baseApplicationId = \"$VENDOR_APP_ID\"|val baseApplicationId = \"$APP_ID\"|" "$g"
  grep -q "val baseApplicationId = \"$APP_ID\"" "$g" || die "android applicationId injection failed"
  sed -i '' -e "s|\"JPUSH_PKGNAME\" to \"$VENDOR_APP_ID\"|\"JPUSH_PKGNAME\" to \"$APP_ID\"|" "$g"
  grep -q "\"JPUSH_PKGNAME\" to \"$APP_ID\"" "$g" || die "JPUSH_PKGNAME injection failed"
  local m="$WORKTREE/android/app/src/main/AndroidManifest.xml"
  sed -i '' -e "s|android:label=\"$VENDOR_APP_NAME\"|android:label=\"$APP_NAME\"|" "$m"
  grep -q "android:label=\"$APP_NAME\"" "$m" || die "android label injection failed"
  info "android identity injected: applicationId=$APP_ID label=$APP_NAME"
}

inject_ios_identity() {
  plutil -replace CFBundleDisplayName -string "$APP_NAME" "$WORKTREE/ios/Runner/Info.plist"
  plutil -replace CFBundleDisplayName -string "$APP_NAME" "$WORKTREE/ios/ShareExtension/Info.plist"
  sed -i '' "s|$VENDOR_BUNDLE_ID|$BUNDLE_ID|g" "$WORKTREE/ios/Runner.xcodeproj/project.pbxproj"
  local ent
  for ent in "$WORKTREE"/ios/Runner/*.entitlements "$WORKTREE"/ios/ShareExtension/*.entitlements; do
    [ -f "$ent" ] || continue
    sed -i '' "s|group\.$VENDOR_BUNDLE_ID|group.$BUNDLE_ID|g" "$ent"
  done
  [ "$(plutil -extract CFBundleDisplayName raw "$WORKTREE/ios/Runner/Info.plist" 2>/dev/null)" = "$APP_NAME" ] || die "iOS display name injection failed"
  grep -q "$BUNDLE_ID" "$WORKTREE/ios/Runner.xcodeproj/project.pbxproj" || die "iOS bundle id injection failed"
  info "ios identity injected: bundle=$BUNDLE_ID display=$APP_NAME (ShareExtension included)"
}

inject_ios_icons() {
  local real_set="$WORKTREE/ios/Runner/Assets.xcassets/AppIcon.appiconset"
  local pkg_set="$ASSET_PKG/replace/ios/Runner/Assets.xcassets/AppIcon.appiconset"
  python3 - "$real_set" "$pkg_set" <<'PYEOF'
import json, subprocess, sys, glob, os, re
real_set, pkg_set = sys.argv[1], sys.argv[2]
def px(path):
    out = subprocess.run(['sips','-g','pixelWidth','-g','pixelHeight',path],
                         capture_output=True, text=True).stdout
    w = re.search(r'pixelWidth: (\d+)', out); h = re.search(r'pixelHeight: (\d+)', out)
    return (int(w.group(1)), int(h.group(1))) if w and h else (0, 0)
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
    subprocess.run(['sips','-z',str(target),str(target),src,'--out',dst],
                   check=True, capture_output=True)
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
  sed -i '' -e "s|<title>[^<]*</title>|<title>$WEB_TITLE</title>|" \
            -e "s|content=\"ImBoy\"|content=\"$WEB_TITLE\"|g" \
            -e "s|favicon.png?v=[A-Za-z0-9_.-]*|favicon.png?v=${CUSTOMER_ID}-${ASSET_VERSION}|" "$w/index.html"
  grep -q "<title>$WEB_TITLE</title>" "$w/index.html" || die "web title injection failed"
  cmp -s "$ASSET_PKG/replace/web/icons/favicon-32.png" "$w/favicon.png" || die "web favicon copy verification failed"
  # pixel-level verification: copied PWA icons must be real, correctly sized images
  local icon_expect icon_file got_w
  for icon_expect in "icons/Icon-192.png:192" "icons/Icon-512.png:512"; do
    icon_file="$w/${icon_expect%%:*}"
    got_w="$(sips -g pixelWidth "$icon_file" 2>/dev/null | awk '/pixelWidth/{print $2}')"
    [ "$got_w" = "${icon_expect##*:}" ] || die "web icon verification failed: $icon_file (expected width ${icon_expect##*:}, got '${got_w:-unreadable}')"
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
      sed -i '' -e 's|image: assets/images/splash_logo.png|image: assets/images/customer_splash_logo.png|g' \
                -e 's|image_dark: assets/images/splash_logo.png|image_dark: assets/images/customer_splash_logo.png|g' \
                "$WORKTREE/flutter_native_splash.yaml"
      ( cd "$WORKTREE" && dart run flutter_native_splash:create )
      info "splash regenerated from customer source"
      ;;
    *) die "unknown splash.mode: $mode (inherit|regenerate)" ;;
  esac
}

info "== brand injection (isolated worktree; scoped to: ${PLATFORMS[*]}) =="
if has_platform android; then inject_android_identity; fi
if has_platform ios;    then inject_ios_identity; fi
if has_platform ios;    then inject_ios_icons; fi
if has_platform android; then inject_android_res; fi
if has_platform web;    then inject_web_brand; fi
if has_platform android || has_platform ios; then apply_splash_policy; fi

# ---------- dart-define assembly ----------
DEFINES=(--dart-define=APP_ENV="$APP_ENV")
[ -n "$API_VALUE" ] && DEFINES+=(--dart-define=API_BASE_URL_OVERRIDE="$API_VALUE")
[ -n "$WS_VALUE" ] && DEFINES+=(--dart-define=WS_URL_OVERRIDE="$WS_VALUE")
PUSH_DEMO="$(yaml_get "$CONFIG_DIR/features.yaml" features.push.demo_enabled)"
[ "$PUSH_DEMO" = "false" ] && DEFINES+=(--dart-define=IMBOY_JPUSH_ENABLED=false)

# ---------- pre-build gates (mirror existing release scripts) ----------
BUILD_NAME="$(awk -F': ' '/^version:/{print $2; exit}' "$WORKTREE/pubspec.yaml")"
[ -n "$BUILD_NAME" ] || die "cannot read version from pubspec.yaml"

CODEGEN_DISCLOSURE=""
if [ "$DRY_RUN" = "0" ] && { has_platform android || has_platform ios; }; then
  # envied/riverpod generated *.g.dart files are untracked; a fresh worktree lacks
  # them, so native Dart compilation fails on undefined names (_Env). Regenerate
  # inside the disposable worktree from the copied .env files.
  info "regenerating build_runner artifacts (envied etc.) inside isolated worktree"
  ( cd "$WORKTREE" && dart run build_runner build ) || die "build_runner codegen failed"
  CODEGEN_DISCLOSURE="envied/build_runner codegen regenerated in-worktree from vendor .env files; demo artifacts embed vendor demo client-side credentials (client-extractable by design, same disclosure posture as inherited demo API)"
fi

GATE_DISCLOSURE=""
FEATURES_GATE="$(yaml_get "$CONFIG_DIR/app.yaml" build_policy.features_gate)"
[ -n "$FEATURES_GATE" ] || FEATURES_GATE="enforce"
if [ "$DRY_RUN" = "0" ]; then
  ( cd "$WORKTREE" && python3 scripts/check_sdk_compatibility.py ) || die "SDK compatibility check failed"
  BACKEND_ROOT="$WORKSPACE_ROOT/imboy"
  [ -d "$BACKEND_ROOT" ] || die "backend repo not found at $BACKEND_ROOT (required by the full-selected features gate)"
  if [ "$ENV_NAME" != "production" ] && [ "$FEATURES_GATE" = "skip_with_disclosure" ]; then
    warn "backend product-features gate skipped by build_policy.features_gate=skip_with_disclosure (demo/staging only); disclosed in build manifest"
    GATE_DISCLOSURE="backend product-features gate skipped via build_policy.features_gate=skip_with_disclosure; backend workspace may not be full-selected (vendor release gate untouched for production)"
  else
    python3 "$BACKEND_ROOT/scripts/generate_product_features.py" --check --require-profile full-selected \
      || die "backend product-features gate failed (full-selected profile required, same as existing release scripts; or set build_policy.features_gate=skip_with_disclosure for demo builds)"
  fi
fi

# ---------- builds ----------
OUT_DIR="$BUILDS_DIR/$ENV_NAME/$BUILD_NAME-$BUILD_NUMBER"
mkdir -p "$OUT_DIR"
LOG="$OUT_DIR/build.log"

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
  mkdir -p "$OUT_DIR/android" || return 1
  cp "$apk" "$OUT_DIR/android/app-release.apk" || return 1
  info "android artifact: $OUT_DIR/android/app-release.apk (from $(basename "$apk"))"
}

build_ios() {
  info "== building ios (unsigned; IPA export BLOCKED without customer signing credentials) =="
  ( cd "$WORKTREE" && flutter build ios --release --no-codesign \
      --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER" \
      -t lib/main.dart "${DEFINES[@]}" ) || return 1
  [ -d "$WORKTREE/build/ios/iphoneos/Runner.app" ] || { echo "[buildapp] Runner.app missing after build" >&2; return 1; }
  mkdir -p "$OUT_DIR/ios" || return 1
  ( cd "$WORKTREE/build/ios/iphoneos" && zip -qry "$OUT_DIR/ios/Runner-unsigned.app.zip" Runner.app ) || return 1
  info "ios artifact: $OUT_DIR/ios/Runner-unsigned.app.zip (NOT an IPA; archive/export requires customer certs)"
}

build_web() {
  info "== building web (reuses web/build_web.sh) =="
  ( cd "$WORKTREE" && bash web/build_web.sh ) || return 1
  mkdir -p "$OUT_DIR/web" || return 1
  # /. form: copy CONTENTS into the existing target dir (plain cp -R would nest web/web/)
  cp -R "$WORKTREE/build/web/." "$OUT_DIR/web/" || return 1
  cmp -s "$WORKTREE/web/favicon.png" "$OUT_DIR/web/favicon.png" || { echo "[buildapp] web output favicon mismatch" >&2; return 1; }
  grep -q "$WEB_TITLE" "$OUT_DIR/web/index.html" || { echo "[buildapp] web output title mismatch" >&2; return 1; }
  info "web artifact: $OUT_DIR/web/"
}

BUILD_STATUS="PASS"
# prepare signing in the MAIN shell (build functions run in pipeline subshells;
# their variable assignments would not propagate to the manifest block)
if has_platform android; then
  if [ "$ENV_NAME" = "production" ]; then
    [ -f "$CUSTOMER_DIR/signing/key.properties" ] || die "production android requires customers/$CUSTOMER_ID/signing/key.properties (customer-supplied signing)"
    cp "$CUSTOMER_DIR/signing/key.properties" "$WORKTREE/android/key.properties"
  else
    ensure_android_demo_signing
  fi
fi
{
  echo "[buildapp] run started $(date -u +%Y-%m-%dT%H:%M:%SZ) customer=$CUSTOMER_ID env=$ENV_NAME platforms=${PLATFORMS[*]} mode=$([ "$DRY_RUN" = 1 ] && echo dry-run || echo real-build)"
} > "$LOG"
if [ "$DRY_RUN" = "1" ]; then
  info "dry-run: injection verified; skipping flutter builds (no artifacts produced)"
else
  for p in "${PLATFORMS[@]}"; do
    if ! "build_$p" 2>&1 | tee -a "$LOG"; then
      die "platform build failed: $p (log: $LOG)"
    fi
  done
fi

# ---------- build manifest ----------
MANIFEST="$OUT_DIR/build-manifest.yaml"
{
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
  echo "  url_scheme: $URL_SCHEME_NOTE"
  echo "api:"
  echo "  source: $API_SOURCE"
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
  [ -n "$GATE_DISCLOSURE" ] && echo "  - $GATE_DISCLOSURE"
  [ -n "$CODEGEN_DISCLOSURE" ] && echo "  - $CODEGEN_DISCLOSURE"
  [ -n "$DEMO_SIGNING_DISCLOSURE" ] && echo "  - $DEMO_SIGNING_DISCLOSURE"
  echo "log: build.log"
} > "$MANIFEST"

# manifest + artifact digests: everything resolved INSIDE $OUT_DIR (no cwd-relative glob leakage)
(
  cd "$OUT_DIR" || exit 1
  files=(build-manifest.yaml build.log)
  if [ -d android ]; then files+=(android/*); fi
  if [ -d ios ]; then files+=(ios/*); fi
  if [ -d web ]; then while IFS= read -r f; do files+=("$f"); done < <(find web -type f); fi
  shasum -a 256 "${files[@]}" > SHA256SUMS || exit 1
  shasum -a 256 -c SHA256SUMS --status || exit 1
) || die "artifact SHA256SUMS generation/self-check failed"
info "build manifest + SHA256SUMS written: $OUT_DIR"

info "== DONE ($BUILD_STATUS) mode=$([ "$DRY_RUN" = 1 ] && echo dry-run || echo real-build) artifacts: $OUT_DIR =="
[ "$AUTH_STATUS" = "pre_sales_demo_unverified_brand_rights" ] && warn "authorization_status=$AUTH_STATUS — demo/proposal use only, never store submission"
exit 0
