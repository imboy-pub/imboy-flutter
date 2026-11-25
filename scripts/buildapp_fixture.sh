#!/usr/bin/env bash
# buildapp_fixture.sh — synthetic customer fixture factory for buildapp tests.
#
# Creates customers/<id>/ (config + assets) using ONLY repo-tracked neutral
# vendor assets (web icons, launcher mipmaps, iOS marketing icon). Never real
# customer credentials or brand resources. Used by scripts/buildapp_test.sh
# and by CI real-build jobs (F07/F13/F14 fixtures: customer-alpha/beta).
#
# Usage:
#   bash scripts/buildapp_fixture.sh <customer_id> <scheme-spec> [options]
#     scheme-spec:
#       <scheme>      explicit customer scheme (e.g. alphaapp); validated here
#       inherit       identity.url_scheme UNCONFIGURED + demo inherit flag "true"
#       vendor-imboy  explicit imboy (negative tests: vendor scheme must fail)
#   options:
#     --production-identity  fill production identity + production.env
#                            (requires an explicit non-vendor scheme)
#     --gate-skip            build_policy.features_gate=skip_with_disclosure
#                            (CI real builds; production still enforces)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUTTER_ROOT="$(dirname "$SCRIPT_DIR")"
WORKSPACE_ROOT="$(dirname "$FLUTTER_ROOT")"

usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 64; }
[ $# -ge 2 ] || usage

ID="$1" ; SPEC="$2" ; shift 2
PROD=0 ; GATE_SKIP=0
for a in "$@"; do
  case "$a" in
    --production-identity) PROD=1 ;;
    --gate-skip) GATE_SKIP=1 ;;
    *) usage ;;
  esac
done
[[ "$ID" =~ ^[a-z][a-z0-9-]{0,62}$ ]] || { echo "invalid fixture id: $ID" >&2; exit 64; }
# Java package names cannot contain '-'; fixture ids like customer-alpha must
# map to aapt-valid application ids (real gradle builds link AndroidManifest).
SAFE_ID="$(printf '%s' "$ID" | tr '-' '_')"

SCHEME_VALUE="UNCONFIGURED" ; INHERIT="true"
case "$SPEC" in
  inherit)       : ;;
  vendor-imboy)  SCHEME_VALUE="imboy" ; INHERIT="false" ;;
  *)
    echo "$SPEC" | grep -Eq '^[a-z][a-z0-9+.-]{0,39}$' || { echo "invalid scheme spec: $SPEC" >&2; exit 64; }
    SCHEME_VALUE="$SPEC" ; INHERIT="false"
    ;;
esac
if [ "$PROD" = "1" ]; then
  [ "$SCHEME_VALUE" != "UNCONFIGURED" ] && [ "$SCHEME_VALUE" != "imboy" ] \
    || { echo "--production-identity requires an explicit non-vendor scheme" >&2; exit 64; }
fi

if command -v shasum >/dev/null 2>&1; then
  SHA_BIN="shasum -a 256"
else
  SHA_BIN="sha256sum"
fi

BASE="$WORKSPACE_ROOT/customers/$ID"
PKG="$BASE/assets/fixture-assets-v1"
echo "[fixture] creating $BASE (scheme=$SCHEME_VALUE inherit=$INHERIT prod=$PROD gate_skip=$GATE_SKIP)"
mkdir -p "$BASE/config/environments" "$BASE/config/client" "$BASE/builds" \
         "$PKG/manifest" \
         "$PKG/replace/web/icons" "$PKG/replace/web/branding" \
         "$PKG/replace/android/app/src/main/res/mipmap-anydpi-v26" \
         "$PKG/replace/android/app/src/main/res/values" \
         "$PKG/replace/ios/Runner/Assets.xcassets/AppIcon.appiconset"

PROD_ID_BLOCK="  android_application_id: UNCONFIGURED
  ios_bundle_id: UNCONFIGURED"
if [ "$PROD" = "1" ]; then
  PROD_ID_BLOCK="  android_application_id: app.$SAFE_ID.example
  ios_bundle_id: app.$SAFE_ID.example"
  printf 'API_BASE_URL=https://api.%s.example/\nWS_URL=wss://api.%s.example/ws\n' "$SAFE_ID" "$SAFE_ID" \
    > "$BASE/config/environments/production.env"
  printf 'API_BASE_URL=https://api.%s.example/\nWS_URL=wss://api.%s.example/ws\n' "$SAFE_ID" "$SAFE_ID" \
    > "$BASE/config/environments/production.env.example"
fi

GATE_BLOCK=""
[ "$GATE_SKIP" = "1" ] && GATE_BLOCK="build_policy:
  features_gate: skip_with_disclosure"

cat > "$BASE/config/app.yaml" <<EOF
customer_id: $ID
customer_type: prospect
project_purpose: buildapp-selftest
brand:
  app_name: TestApp
  tagline: selftest
  primary_color: "#2474E5"
assets:
  package: fixture-assets-v1
  version: 1
  replacement_map: manifest/replacement-map.yaml
  authorization_status: selftest-fixture
identity:
$PROD_ID_BLOCK
  url_scheme: $SCHEME_VALUE
  demo:
    android_application_id: pub.imboy.app.demo.$SAFE_ID
    ios_bundle_id: pub.imboy.app.demo.$SAFE_ID
    inherit_vendor_url_scheme: "$INHERIT"
splash:
  mode: inherit
  source: UNCONFIGURED
  reason: fixture
store_submission:
  allowed: "false"
  reason: selftest fixture
$GATE_BLOCK
EOF

cat > "$BASE/config/features.yaml" <<EOF
features:
  push:
    provider: jpush
    app_key: UNCONFIGURED
    demo_enabled: "false"
EOF

printf 'API_BASE_URL_OVERRIDE=\nWS_URL_OVERRIDE=\nALLOW_DEMO_INHERITED_API=yes\n' > "$BASE/config/environments/development.env"
printf 'API_BASE_URL_OVERRIDE=\nWS_URL_OVERRIDE=\nALLOW_DEMO_INHERITED_API=yes\n' > "$BASE/config/environments/development.env.example"
printf 'API_BASE_URL_OVERRIDE=\nWS_URL_OVERRIDE=\nALLOW_DEMO_INHERITED_API=yes\n' > "$BASE/config/environments/staging.env"
printf 'WEB_TITLE=TestApp\n' > "$BASE/config/client/public.env"

# --- neutral fixture assets, all copied from repo-tracked vendor files ---
cp "$FLUTTER_ROOT/web/favicon.png"                  "$PKG/replace/web/icons/favicon-32.png"
cp "$FLUTTER_ROOT/web/icons/Icon-192.png"           "$PKG/replace/web/icons/icon-192.png"
cp "$FLUTTER_ROOT/web/icons/Icon-512.png"           "$PKG/replace/web/icons/icon-512.png"
for d in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  mkdir -p "$PKG/replace/android/app/src/main/res/mipmap-$d"
  cp "$FLUTTER_ROOT/android/app/src/main/res/mipmap-$d/ic_launcher.png" \
     "$PKG/replace/android/app/src/main/res/mipmap-$d/ic_launcher.png"
  # dedicated adaptive-icon foreground layer: MUST NOT reference
  # @mipmap/ic_launcher itself — ic_launcher resolves to the anydpi-v26
  # adaptive XML on API 26+, so a self-referencing foreground is a resource
  # cycle (W PackageManager "Failure retrieving resources ... mipmap/
  # ic_launcher" and a system fallback icon; observed on the 2026-11-25
  # device smoke). The foreground is the same vendor PNG under a distinct
  # resource name, which keeps the fixture self-contained AND acyclic.
  cp "$FLUTTER_ROOT/android/app/src/main/res/mipmap-$d/ic_launcher.png" \
     "$PKG/replace/android/app/src/main/res/mipmap-$d/ic_launcher_foreground.png"
done
# synthetic (valid, acyclic) adaptive icon + its color: self-contained
cat > "$PKG/replace/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
EOF
cat > "$PKG/replace/android/app/src/main/res/values/colors.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#2474E5</color>
</resources>
EOF
cp "$FLUTTER_ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset/ios-marketing-1024x1024.png" \
   "$PKG/replace/ios/Runner/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

cat > "$PKG/manifest/replacement-map.yaml" <<EOF
customer_id: $ID
package_version: 1
authorization_status: selftest-fixture
source_roots:
  web: replace/web/
  android: replace/android/
  ios: replace/ios/
proposed_destinations:
  web:
    destination: web/
    operation: selective_resource_overlay_in_isolated_build_workspace
  android:
    destination: android/app/src/main/res/
    operation: launcher_icon_resource_overlay
  ios:
    destination: ios/Runner/Assets.xcassets/AppIcon.appiconset/
    operation: per_slot_icon_resample
EOF

( cd "$PKG" && \
  find . -type f ! -path './manifest/SHA256SUMS' -exec $SHA_BIN {} \; | sed 's|\ \./| |' > manifest/SHA256SUMS )
echo "[fixture] done: $ID"
