#!/usr/bin/env bash
# buildapp_test.sh — automated acceptance tests for scripts/buildapp.sh (I04).
# Covers the 20 required scenarios. Real commands, real results; any failure
# exits non-zero and prints FAILED <case>. Fixtures are synthetic customers
# under ../customers/selftest-* created here and removed at the end; they use
# vendor web icons as neutral fixtures (never Yaoxin resources).
#
# Usage: bash scripts/buildapp_test.sh [--keep-fixtures]

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUTTER_ROOT="$(dirname "$SCRIPT_DIR")"
WORKSPACE_ROOT="$(dirname "$FLUTTER_ROOT")"
CUSTOMERS_ROOT="$WORKSPACE_ROOT/customers"
BUILDAPP="$SCRIPT_DIR/buildapp.sh"
LOCK_ROOT="$WORKSPACE_ROOT/.buildapp-locks"
WT_ROOT="$WORKSPACE_ROOT/.buildapp-worktrees"
KEEP=0
[ "${1:-}" = "--keep-fixtures" ] && KEEP=1

PASS=0 ; FAIL=0
ok()   { echo "PASS $1"; PASS=$((PASS+1)); }
bad()  { echo "FAILED $1: $2"; FAIL=$((FAIL+1)); }
check() { # $1=case-name $2=expected(0|nonzero) $3..=command
  local name="$1" expect="$2"; shift 2
  local out rc
  out=$("$@" 2>&1); rc=$?
  if [ "$expect" = "0" ] && [ "$rc" -eq 0 ]; then ok "$name";
  elif [ "$expect" = "nonzero" ] && [ "$rc" -ne 0 ]; then ok "$name";
  else bad "$name" "exit=$rc expect=$expect; output: $(echo "$out" | tail -3 | tr '\n' ' ')"; fi
}
expect_grep() { # $1=case-name $2=pattern $3..=command (must exit nonzero-or-0 per semantics AND match)
  local name="$1" pat="$2"; shift 2
  local out rc
  out=$("$@" 2>&1); rc=$?
  if echo "$out" | grep -Eq "$pat"; then ok "$name";
  else bad "$name" "pattern '$pat' missing (exit=$rc); output: $(echo "$out" | tail -3 | tr '\n' ' ')"; fi
}

# ---------- fixture factory ----------
make_fixture() { # $1=id  (creates config+assets from vendor web icons)
  local id="$1"
  local base="$CUSTOMERS_ROOT/$id"
  rm -rf "$base"
  mkdir -p "$base/config/environments" "$base/config/client" "$base/builds" \
           "$base/assets/fixture-assets-v1/manifest" \
           "$base/assets/fixture-assets-v1/replace/web/icons" \
           "$base/assets/fixture-assets-v1/replace/web/branding"
  cat > "$base/config/app.yaml" <<EOF
customer_id: $id
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
  android_application_id: UNCONFIGURED
  ios_bundle_id: UNCONFIGURED
  url_scheme: UNCONFIGURED
  demo:
    android_application_id: pub.imboy.app.demo.$id
    ios_bundle_id: pub.imboy.app.demo.$id
    inherit_vendor_url_scheme: "true"
splash:
  mode: inherit
  source: UNCONFIGURED
  reason: fixture
store_submission:
  allowed: "false"
  reason: selftest fixture
EOF
  cat > "$base/config/features.yaml" <<EOF
features:
  push:
    provider: jpush
    app_key: UNCONFIGURED
    demo_enabled: "false"
EOF
  printf 'API_BASE_URL_OVERRIDE=\nWS_URL_OVERRIDE=\nALLOW_DEMO_INHERITED_API=yes\n' > "$base/config/environments/development.env"
  printf 'API_BASE_URL_OVERRIDE=\nWS_URL_OVERRIDE=\nALLOW_DEMO_INHERITED_API=yes\n' > "$base/config/environments/development.env.example"
  printf 'WEB_TITLE=TestApp\n' > "$base/config/client/public.env"
  cp "$FLUTTER_ROOT/web/favicon.png" "$base/assets/fixture-assets-v1/replace/web/icons/favicon-32.png"
  cp "$FLUTTER_ROOT/web/icons/Icon-192.png" "$base/assets/fixture-assets-v1/replace/web/icons/icon-192.png"
  cp "$FLUTTER_ROOT/web/icons/Icon-512.png" "$base/assets/fixture-assets-v1/replace/web/icons/icon-512.png"
  cat > "$base/assets/fixture-assets-v1/manifest/replacement-map.yaml" <<EOF
customer_id: $id
package_version: 1
authorization_status: selftest-fixture
source_roots:
  web: replace/web/
proposed_destinations:
  web:
    destination: web/
    operation: selective_resource_overlay_in_isolated_build_workspace
EOF
  ( cd "$base/assets/fixture-assets-v1" && \
    find . -type f ! -path './manifest/SHA256SUMS' -exec shasum -a 256 {} \; | sed 's|\ \./| |' > manifest/SHA256SUMS )
}

cleanup_fixtures() {
  [ "$KEEP" = "1" ] && { echo "(fixtures kept)"; return; }
  rm -rf "$CUSTOMERS_ROOT/selftest-alpha" "$CUSTOMERS_ROOT/selftest-beta" "$CUSTOMERS_ROOT/missing-config"
}
trap cleanup_fixtures EXIT

echo "== buildapp_test.sh: preparing fixtures =="
make_fixture selftest-alpha
make_fixture selftest-beta
mkdir -p "$CUSTOMERS_ROOT/missing-config"   # no config/ inside (case 6)

echo "== running 20 scenarios =="
A_ART=""

# 01 normal parameters
out=$(bash "$BUILDAPP" selftest-alpha development web --dry-run 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then ok "01-normal-params"; A_ART=$(echo "$out" | grep -o "$CUSTOMERS_ROOT/selftest-alpha/builds[^ ]*" | head -1);
else bad "01-normal-params" "exit=$rc: $(echo "$out" | tail -3)"; fi

# 02 help
expect_grep "02-help" "Usage" bash "$BUILDAPP" --help

# 03 unknown customer
expect_grep "03-unknown-customer" "customer config not found" bash "$BUILDAPP" nosuch-customer development web --dry-run

# 04 invalid customer_id
check "04a-invalid-id-uppercase" nonzero bash "$BUILDAPP" Yaoxin_Demo development web --dry-run
check "04b-invalid-id-space" nonzero bash "$BUILDAPP" "demo app" development web --dry-run

# 05 path traversal
check "05-path-traversal" nonzero bash "$BUILDAPP" "../imboy" development web --dry-run
check "05b-slash-traversal" nonzero bash "$BUILDAPP" "yaoxin/../../imboy" development web --dry-run

# 06 config missing
expect_grep "06-config-missing" "customer config not found" bash "$BUILDAPP" missing-config development web --dry-run

# 07 production fail-closed (yaoxin: UNCONFIGURED identity + no production.env — both are fail-closed gates)
expect_grep "07-production-fail-closed" "fail-closed|environment file missing" bash "$BUILDAPP" yaoxin production web

# 08 unknown environment
expect_grep "08-unknown-env" "unknown environment" bash "$BUILDAPP" selftest-alpha qa web --dry-run

# 09 unknown platform
expect_grep "09-unknown-platform" "unknown platform" bash "$BUILDAPP" selftest-alpha development windows --dry-run

# 10 asset package missing
sed -i '' 's|package: fixture-assets-v1|package: nonexistent-pkg|' "$CUSTOMERS_ROOT/selftest-beta/config/app.yaml"
expect_grep "10-assets-package-missing" "asset package directory not found" bash "$BUILDAPP" selftest-beta development web --dry-run
sed -i '' 's|package: nonexistent-pkg|package: fixture-assets-v1|' "$CUSTOMERS_ROOT/selftest-beta/config/app.yaml"

# 11 SHA256 mismatch
printf 'X' | dd of="$CUSTOMERS_ROOT/selftest-beta/assets/fixture-assets-v1/replace/web/icons/icon-192.png" bs=1 seek=64 conv=notrunc 2>/dev/null
expect_grep "11-sha256-mismatch" "integrity check FAILED" bash "$BUILDAPP" selftest-beta development web --dry-run
make_fixture selftest-beta

# 12 replacement-map missing
mv "$CUSTOMERS_ROOT/selftest-beta/assets/fixture-assets-v1/manifest/replacement-map.yaml" /tmp/buildapp-test-map.bak
expect_grep "12-replacement-map-missing" "replacement map not found" bash "$BUILDAPP" selftest-beta development web --dry-run
mv /tmp/buildapp-test-map.bak "$CUSTOMERS_ROOT/selftest-beta/assets/fixture-assets-v1/manifest/replacement-map.yaml"

# 13 concurrent build refused
mkdir -p "$LOCK_ROOT/selftest-alpha"
echo "$$" > "$LOCK_ROOT/selftest-alpha/pid"
expect_grep "13-concurrent-refused" "concurrent builds are refused" bash "$BUILDAPP" selftest-alpha development web --dry-run
rm -rf "$LOCK_ROOT/selftest-alpha"

# 14 injection failure => detected + clean recovery
# (truncate a PWA icon to break its image header, then re-sign the manifest so the
#  integrity gate passes and the pixel-verification gate is what catches it)
truncate -s 10 "$CUSTOMERS_ROOT/selftest-beta/assets/fixture-assets-v1/replace/web/icons/icon-192.png"
( cd "$CUSTOMERS_ROOT/selftest-beta/assets/fixture-assets-v1" && \
  find . -type f ! -path './manifest/SHA256SUMS' -exec shasum -a 256 {} \; | sed 's|\ \./| |' > manifest/SHA256SUMS )
out=$(bash "$BUILDAPP" selftest-beta development web --dry-run 2>&1); rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -q "web icon verification failed"; then ok "14-inject-fail-detected"; else bad "14-inject-fail-detected" "exit=$rc: $(echo "$out" | tail -2)"; fi
make_fixture selftest-beta
if [ -z "$(find "$WT_ROOT" -maxdepth 1 -name 'selftest-beta-*' 2>/dev/null)" ] && [ ! -d "$LOCK_ROOT/selftest-beta" ]; then ok "14b-recovery-clean"; else bad "14b-recovery-clean" "leftover worktree/lock after failure"; fi

# 15 Ctrl+C (SIGINT) recovery
bash "$BUILDAPP" selftest-beta development web --dry-run >/tmp/buildapp-test-int.log 2>&1 &
BG=$!
INT_SEEN=0
for i in $(seq 1 60); do
  if ls -d "$WT_ROOT"/selftest-beta-development-* >/dev/null 2>&1; then INT_SEEN=1; break; fi
  sleep 0.5
done
if [ "$INT_SEEN" = "1" ]; then
  kill -INT "$BG" 2>/dev/null || true
  wait "$BG" 2>/dev/null
  sleep 1
  if [ -z "$(find "$WT_ROOT" -maxdepth 1 -name 'selftest-beta-*' 2>/dev/null)" ] && [ ! -d "$LOCK_ROOT/selftest-beta" ]; then ok "15-sigint-recovery"; else bad "15-sigint-recovery" "worktree/lock left after SIGINT"; fi
else
  bad "15-sigint-recovery" "could not observe worktree creation to interrupt (log tail: $(tail -2 /tmp/buildapp-test-int.log | tr '\n' ' '))"
fi

# 16 temp cleanup
if [ -z "$(find "$WT_ROOT" -maxdepth 1 -name 'selftest-*' 2>/dev/null)" ] && [ -z "$(find "$LOCK_ROOT" -maxdepth 1 -name 'selftest-*' 2>/dev/null)" ]; then ok "16-temp-cleanup"; else bad "16-temp-cleanup" "leftovers in worktree/lock roots"; fi

# 17 IMBoy baseline unpolluted
st=$(git -C "$FLUTTER_ROOT" status --porcelain | grep -v '^?? scripts/buildapp' || true)
label_now=$(grep 'android:label=' "$FLUTTER_ROOT/android/app/src/main/AndroidManifest.xml" | head -1)
if [ -z "$st" ] && [ "$label_now" = '        android:label="IMBoy"' ]; then ok "17-baseline-unpolluted"; else bad "17-baseline-unpolluted" "status: $st / label: $label_now"; fi

# 18 second synthetic customer works
check "18-second-customer" 0 bash "$BUILDAPP" selftest-beta development web --dry-run

# 19 manifest fields
if [ -n "$A_ART" ] && [ -f "$A_ART/build-manifest.yaml" ] && \
   grep -q 'customer_id: selftest-alpha' "$A_ART/build-manifest.yaml" && \
   grep -q 'mode: dry-run' "$A_ART/build-manifest.yaml" && \
   grep -q 'source_commit:' "$A_ART/build-manifest.yaml" && \
   grep -q 'identity_used:' "$A_ART/build-manifest.yaml"; then ok "19-manifest-fields"; else bad "19-manifest-fields" "manifest missing/incomplete at '$A_ART'"; fi

# 20 SHA256SUMS verification
if [ -n "$A_ART" ] && ( cd "$A_ART" && shasum -a 256 -c SHA256SUMS --status ); then ok "20-sha256-artifacts"; else bad "20-sha256-artifacts" "SHA256SUMS check failed at '$A_ART'"; fi

echo "== results: PASS=$PASS FAIL=$FAIL =="
[ "$FAIL" -eq 0 ] || exit 1
