#!/usr/bin/env bash
# buildapp_test.sh — automated acceptance tests for scripts/buildapp.sh.
#
# Three layers:
#   01-20  original end-to-end scenarios (PR #83 contract), adapted for the
#          V2 receipt layout (dry-runs/) and portable shell (BSD/GNU)
#   T*     tool-level tests against REAL repo files (copies): scheme
#          injection/verification, scheme contract, png fallback, aapt2 parse
#   S*     URL-scheme end-to-end dry-run scenarios (F09-F12 receipt evidence)
#   R*     receipt-isolation scenarios (F01-F07: same-minute, poisoning,
#          failure, SIGINT, dry-run separation)
#
# Real commands, real results; any failure exits non-zero and prints FAILED
# <case>. Fixtures are synthetic customers under ../customers/ created by
# scripts/buildapp_fixture.sh from neutral vendor assets only (never Yaoxin
# or any real-customer resources).
#
# Usage: bash scripts/buildapp_test.sh [--keep-fixtures]

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUTTER_ROOT="$(dirname "$SCRIPT_DIR")"
WORKSPACE_ROOT="$(dirname "$FLUTTER_ROOT")"
CUSTOMERS_ROOT="$WORKSPACE_ROOT/customers"
BUILDAPP="$SCRIPT_DIR/buildapp.sh"
FIXTURE="$SCRIPT_DIR/buildapp_fixture.sh"
SCHEME_TOOL="$SCRIPT_DIR/buildapp_scheme_tools.py"
PNG_TOOL="$SCRIPT_DIR/buildapp_png_tools.py"
LOCK_ROOT="$WORKSPACE_ROOT/.buildapp-locks"
WT_ROOT="$WORKSPACE_ROOT/.buildapp-worktrees"
KEEP=0
[ "${1:-}" = "--keep-fixtures" ] && KEEP=1

if sed --version >/dev/null 2>&1; then SED_I=(-i); else SED_I=(-i ''); fi
sedi() { sed "${SED_I[@]}" "$@"; }
if command -v shasum >/dev/null 2>&1; then
  SHA_BIN="shasum -a 256"
  sha_check() { ( cd "$1" && shasum -a 256 -c SHA256SUMS --status ); }
else
  SHA_BIN="sha256sum"
  sha_check() { ( cd "$1" && sha256sum -c SHA256SUMS --status ); }
fi
fixture() { bash "$FIXTURE" "$@"; }
count_dirs() { # $1=dir $2=maxdepth
  if [ -d "$1" ]; then find "$1" -mindepth 1 -maxdepth "$2" -type d 2>/dev/null | wc -l | tr -d ' '; else echo 0; fi
}
latest_failed_run() { ls -1t "$1" 2>/dev/null | head -1; }

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
expect_grep() { # $1=case-name $2=pattern $3..=command
  local name="$1" pat="$2"; shift 2
  local out rc
  out=$("$@" 2>&1); rc=$?
  if echo "$out" | grep -Eq "$pat"; then ok "$name";
  else bad "$name" "pattern '$pat' missing (exit=$rc); output: $(echo "$out" | tail -3 | tr '\n' ' ')"; fi
}
expect_file_grep() { # $1=case-name $2=file $3=pattern
  if [ -f "$2" ] && grep -q "$3" "$2"; then ok "$1"; else bad "$1" "pattern '$3' not in '$2'"; fi
}

ALL_FIXTURES="selftest-alpha selftest-beta missing-config selftest-prod customer-alpha customer-beta customer-prod customer-demo-imboy"
cleanup_fixtures() {
  [ "$KEEP" = "1" ] && { echo "(fixtures kept)"; return; }
  for id in $ALL_FIXTURES; do rm -rf "$CUSTOMERS_ROOT/$id"; done
}
trap cleanup_fixtures EXIT

echo "== buildapp_test.sh: preparing fixtures =="
# snapshot the checkout status BEFORE any run; case 17 asserts no NEW entries
# appear (injected pollution), while pre-existing branch edits stay expected.
BASELINE_STATUS=$(git -C "$FLUTTER_ROOT" status --porcelain 2>/dev/null || true)
fixture selftest-alpha inherit
fixture selftest-beta inherit
fixture selftest-prod inherit           # production identity UNCONFIGURED (case 07)
fixture customer-alpha alphaapp
fixture customer-beta betaapp
fixture customer-prod prodapp --production-identity
fixture customer-demo-imboy vendor-imboy
mkdir -p "$CUSTOMERS_ROOT/missing-config"   # no config/ inside (case 06)

A_ART=""
run_capture() { # $1=case; runs buildapp, captures receipt dir into RECV_DIR
  RECV_DIR=""
  local name="$1"; shift
  out=$(bash "$BUILDAPP" "$@" 2>&1); rc=$?
  RECV_DIR="$(echo "$out" | grep -o "$CUSTOMERS_ROOT/[^ ]*builds[^ ]*" | head -1)"
  if [ "$rc" -eq 0 ]; then ok "$name"; else bad "$name" "exit=$rc: $(echo "$out" | tail -3 | tr '\n' ' ')"; fi
}

echo "== running original 20 scenarios =="
# 01 normal parameters
run_capture "01-normal-params" selftest-alpha development web --dry-run
A_ART="$RECV_DIR"

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

# 07 production fail-closed (synthetic fixture: UNCONFIGURED identity, no production.env)
expect_grep "07-production-fail-closed" "fail-closed|environment file missing" bash "$BUILDAPP" selftest-prod production web --dry-run

# 08 unknown environment
expect_grep "08-unknown-env" "unknown environment" bash "$BUILDAPP" selftest-alpha qa web --dry-run

# 09 unknown platform
expect_grep "09-unknown-platform" "unknown platform" bash "$BUILDAPP" selftest-alpha development windows --dry-run

# 10 asset package missing
sedi 's|package: fixture-assets-v1|package: nonexistent-pkg|' "$CUSTOMERS_ROOT/selftest-beta/config/app.yaml"
expect_grep "10-assets-package-missing" "asset package directory not found" bash "$BUILDAPP" selftest-beta development web --dry-run
sedi 's|package: nonexistent-pkg|package: fixture-assets-v1|' "$CUSTOMERS_ROOT/selftest-beta/config/app.yaml"

# 11 SHA256 mismatch
printf 'X' | dd of="$CUSTOMERS_ROOT/selftest-beta/assets/fixture-assets-v1/replace/web/icons/icon-192.png" bs=1 seek=64 conv=notrunc 2>/dev/null
expect_grep "11-sha256-mismatch" "integrity check FAILED" bash "$BUILDAPP" selftest-beta development web --dry-run
fixture selftest-beta inherit

# 12 replacement-map missing
mv "$CUSTOMERS_ROOT/selftest-beta/assets/fixture-assets-v1/manifest/replacement-map.yaml" /tmp/buildapp-test-map.bak
expect_grep "12-replacement-map-missing" "replacement map not found" bash "$BUILDAPP" selftest-beta development web --dry-run
mv /tmp/buildapp-test-map.bak "$CUSTOMERS_ROOT/selftest-beta/assets/fixture-assets-v1/manifest/replacement-map.yaml"

# 13 concurrent build refused
mkdir -p "$LOCK_ROOT/selftest-alpha"
echo "$$" > "$LOCK_ROOT/selftest-alpha/pid"
expect_grep "13-concurrent-refused" "concurrent builds are refused" bash "$BUILDAPP" selftest-alpha development web --dry-run
rm -rf "$LOCK_ROOT/selftest-alpha"

# 14 injection failure => detected + clean recovery + NO receipt (F04)
# (break a PWA icon's PNG header, then re-sign the package manifest so the
#  integrity gate passes and the pixel-verification gate is what catches it)
DD_TARGET="$CUSTOMERS_ROOT/selftest-beta/assets/fixture-assets-v1/replace/web/icons/icon-192.png"
BETA_DRY_BEFORE=$(count_dirs "$CUSTOMERS_ROOT/selftest-beta/builds/dry-runs" 4)
dd if=/dev/zero of="$DD_TARGET" bs=1 count=10 2>/dev/null
( cd "$CUSTOMERS_ROOT/selftest-beta/assets/fixture-assets-v1" && \
  find . -type f ! -path './manifest/SHA256SUMS' -exec $SHA_BIN {} \; 2>/dev/null | sed 's|\ \./| |' > manifest/SHA256SUMS )
out=$(bash "$BUILDAPP" selftest-beta development web --dry-run 2>&1); rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -q "web icon verification failed"; then ok "14-inject-fail-detected"; else bad "14-inject-fail-detected" "exit=$rc: $(echo "$out" | tail -2)"; fi
FR="$(latest_failed_run "$CUSTOMERS_ROOT/selftest-beta/builds/failed-runs")"
if [ -n "$FR" ] && [ -f "$CUSTOMERS_ROOT/selftest-beta/builds/failed-runs/$FR/build-status.txt" ] \
   && grep -q "build_status: FAIL" "$CUSTOMERS_ROOT/selftest-beta/builds/failed-runs/$FR/build-status.txt" \
   && [ ! -f "$CUSTOMERS_ROOT/selftest-beta/builds/failed-runs/$FR/build-manifest.yaml" ]; then
  ok "14a-failure-evidence-no-receipt"
else
  bad "14a-failure-evidence-no-receipt" "failed-run evidence missing or carries a manifest: $FR"
fi
NOW_BETA_DRY=$(count_dirs "$CUSTOMERS_ROOT/selftest-beta/builds/dry-runs" 4)
if [ "$NOW_BETA_DRY" = "$BETA_DRY_BEFORE" ]; then ok "14b-failure-publishes-no-receipt"; else bad "14b-failure-publishes-no-receipt" "dry-run receipts before=$BETA_DRY_BEFORE after=$NOW_BETA_DRY"; fi
fixture selftest-beta inherit
if [ -z "$(find "$WT_ROOT" -maxdepth 1 -name 'selftest-beta-*' 2>/dev/null)" ] && [ ! -d "$LOCK_ROOT/selftest-beta" ]; then ok "14c-recovery-clean"; else bad "14c-recovery-clean" "leftover worktree/lock after failure"; fi

# 15 interrupt (SIGTERM) recovery — also F04/F07: no receipt for interrupted run.
# SIGTERM instead of SIGINT: POSIX异步列表 (cmd &) 强制忽略 SIGINT/QUIT，后台
# bash 的 INT trap 无法触发（最小实验实证）；TERM trap 等价覆盖中断清理路径，
# buildapp.sh 的 INT trap 仍服务交互式 Ctrl-C。BUILDAPP_TEST_HOLD 保证信号
# 确定命中运行中（hold 由 wait builtin 承载、可被即时打断）。
BETA_DRY_BEFORE=$(count_dirs "$CUSTOMERS_ROOT/selftest-beta/builds/dry-runs" 4)
BUILDAPP_TEST_HOLD=30 bash "$BUILDAPP" selftest-beta development web --dry-run >/tmp/buildapp-test-int.log 2>&1 &
BG=$!
INT_SEEN=0
for i in $(seq 1 60); do
  if ls -d "$WT_ROOT"/selftest-beta-development-* >/dev/null 2>&1; then INT_SEEN=1; break; fi
  sleep 0.5
done
if [ "$INT_SEEN" = "1" ]; then
  kill -TERM "$BG" 2>/dev/null || true
  wait "$BG" 2>/dev/null
  sleep 1
  if [ -z "$(find "$WT_ROOT" -maxdepth 1 -name 'selftest-beta-*' 2>/dev/null)" ] && [ ! -d "$LOCK_ROOT/selftest-beta" ]; then ok "15-sigterm-recovery"; else bad "15-sigterm-recovery" "worktree/lock left after SIGTERM"; fi
  NOW_BETA_DRY=$(count_dirs "$CUSTOMERS_ROOT/selftest-beta/builds/dry-runs" 4)
  if [ "$NOW_BETA_DRY" = "$BETA_DRY_BEFORE" ]; then ok "15a-sigterm-no-receipt"; else bad "15a-sigterm-no-receipt" "receipt count changed across SIGTERM: $BETA_DRY_BEFORE -> $NOW_BETA_DRY"; fi
else
  bad "15-sigterm-recovery" "could not observe worktree creation to interrupt (log tail: $(tail -2 /tmp/buildapp-test-int.log | tr '\n' ' '))"
  bad "15a-sigterm-no-receipt" "skipped (15 failed)"
fi

# 16 temp cleanup
if [ -z "$(find "$WT_ROOT" -maxdepth 1 -name 'selftest-*' 2>/dev/null)" ] && [ -z "$(find "$LOCK_ROOT" -maxdepth 1 -name 'selftest-*' 2>/dev/null)" ]; then ok "16-temp-cleanup"; else bad "16-temp-cleanup" "leftovers in worktree/lock roots"; fi

# 17 IMBoy baseline unpolluted (compare against the pre-run snapshot; only
# task-status/new-script untracked entries may appear, never tracked changes)
st=$(git -C "$FLUTTER_ROOT" status --porcelain 2>/dev/null | grep -v -E '^\?\? (scripts/buildapp|BUILDAPP_RECEIPT_FIX_STATUS)' || true)
base=$(printf '%s\n' "$BASELINE_STATUS" | grep -v -E '^\?\? (scripts/buildapp|BUILDAPP_RECEIPT_FIX_STATUS)' || true)
label_now=$(grep 'android:label=' "$FLUTTER_ROOT/android/app/src/main/AndroidManifest.xml" | head -1)
if [ "$st" = "$base" ] && [ "$label_now" = '        android:label="IMBoy"' ]; then ok "17-baseline-unpolluted"; else bad "17-baseline-unpolluted" "status delta: $(diff <(printf '%s\n' "$base") <(printf '%s\n' "$st") | tr '\n' ' ') / label: $label_now"; fi

# 18 second synthetic customer works
check "18-second-customer" 0 bash "$BUILDAPP" selftest-beta development web --dry-run

# 19 manifest fields
if [ -n "$A_ART" ] && [ -f "$A_ART/build-manifest.yaml" ] && \
   grep -q 'customer_id: selftest-alpha' "$A_ART/build-manifest.yaml" && \
   grep -q 'mode: dry-run' "$A_ART/build-manifest.yaml" && \
   grep -q 'source_commit:' "$A_ART/build-manifest.yaml" && \
   grep -q 'identity_used:' "$A_ART/build-manifest.yaml" && \
   grep -q 'run_id: ' "$A_ART/build-manifest.yaml"; then ok "19-manifest-fields"; else bad "19-manifest-fields" "manifest missing/incomplete at '$A_ART'"; fi

# 20 SHA256SUMS verification
if [ -n "$A_ART" ] && sha_check "$A_ART"; then ok "20-sha256-artifacts"; else bad "20-sha256-artifacts" "SHA256SUMS check failed at '$A_ART'"; fi

echo "== T: tool-level tests (real repo files, copies) =="
TT="$(mktemp -d /tmp/buildapp-tools.XXXXXX)"
cp "$FLUTTER_ROOT/android/app/src/main/AndroidManifest.xml" "$TT/m-base.xml"
cp "$FLUTTER_ROOT/android/app/src/main/AndroidManifest.xml" "$TT/m-alpha.xml"
cp "$FLUTTER_ROOT/android/app/src/main/AndroidManifest.xml" "$TT/m-beta.xml"
cp "$FLUTTER_ROOT/ios/Runner/Info.plist" "$TT/p-base.plist"
cp "$FLUTTER_ROOT/ios/Runner/Info.plist" "$TT/p-alpha.plist"
cp "$FLUTTER_ROOT/ios/Runner/Info.plist" "$TT/p-beta.plist"
cp "$FLUTTER_ROOT/ios/ShareExtension/Info.plist" "$TT/se-before.plist"

# T1 android injection: 3 replacements, structural verification, nothing else moves
if python3 "$SCHEME_TOOL" inject-android "$TT/m-alpha.xml" alphaapp > "$TT/t1.json" 2>&1 \
   && grep -q '"replaced": 3' "$TT/t1.json" && grep -q '"ok": true' "$TT/t1.json" \
   && ! grep -q 'scheme="imboy"' "$TT/m-alpha.xml"; then ok "T1-android-inject"; else bad "T1-android-inject" "$(tail -2 "$TT/t1.json" | tr '\n' ' ')"; fi
if python3 "$SCHEME_TOOL" verify-android "$TT/m-alpha.xml" alphaapp > "$TT/t1v.json" 2>&1 \
   && grep -q '"https_app_link_intact": true' "$TT/t1v.json" \
   && grep -q '"queries_intact": true' "$TT/t1v.json" \
   && grep -q '"host_semantics_preserved": true' "$TT/t1v.json" \
   && grep -q '"main_launcher_present": true' "$TT/t1v.json"; then ok "T1a-android-invariants"; else bad "T1a-android-invariants" "$(tail -2 "$TT/t1v.json" | tr '\n' ' ')"; fi

# T2 ios injection: only the deeplink URL type's schemes change; everything
#    else (weixin/alipay/ShareMedia/E2EE backup) structurally identical
if python3 "$SCHEME_TOOL" inject-ios "$TT/p-alpha.plist" alphaapp > "$TT/t2.json" 2>&1 \
   && grep -q '"replaced": 1' "$TT/t2.json" \
   && grep -q '"url_type_count": 4' "$TT/t2.json"; then ok "T2-ios-inject"; else bad "T2-ios-inject" "$(tail -2 "$TT/t2.json" | tr '\n' ' ')"; fi
if python3 - "$TT/p-base.plist" "$TT/p-alpha.plist" <<'PY' > "$TT/t2s.txt" 2>&1
import plistlib, sys
a = plistlib.load(open(sys.argv[1], "rb"))
b = plistlib.load(open(sys.argv[2], "rb"))
assert set(a.keys()) == set(b.keys()), "top-level keys changed"
diffs = sorted(k for k in a if a[k] != b[k])
assert diffs == ["CFBundleURLTypes"], "unexpected diffs: %s" % diffs
ta, tb = a["CFBundleURLTypes"], b["CFBundleURLTypes"]
assert len(ta) == len(tb) == 4, "URL type count changed"
for x, y in zip(ta, tb):
    if x.get("CFBundleURLName") == "imboy.pub":
        assert x["CFBundleURLSchemes"] == ["imboy"] and y["CFBundleURLSchemes"] == ["alphaapp"]
        assert {k: v for k, v in x.items() if k != "CFBundleURLSchemes"} == {k: v for k, v in y.items() if k != "CFBundleURLSchemes"}
    else:
        assert x == y, "non-deeplink URL type changed: %s" % x.get("CFBundleURLName")
print("T2-STRUCTURAL-OK")
PY
   grep -q "T2-STRUCTURAL-OK" "$TT/t2s.txt"; then ok "T2a-ios-structural-diff"; else bad "T2a-ios-structural-diff" "$(tail -2 "$TT/t2s.txt" | tr '\n' ' ')"; fi
if python3 "$SCHEME_TOOL" verify-ios "$TT/p-alpha.plist" alphaapp 2>&1 | grep -q '"e2ee_backup_preserved": true'; then ok "T2b-e2ee-preserved"; else bad "T2b-e2ee-preserved" "E2EE backup registration lost"; fi

# T3 beta independence: alpha and beta injections on separate copies
python3 "$SCHEME_TOOL" inject-android "$TT/m-beta.xml" betaapp > "$TT/t3a.json" 2>&1 || true
python3 "$SCHEME_TOOL" inject-ios "$TT/p-beta.plist" betaapp > "$TT/t3b.json" 2>&1 || true
if grep -q '"replaced": 3' "$TT/t3a.json" && grep -q '"replaced": 1' "$TT/t3b.json" \
   && python3 "$SCHEME_TOOL" verify-android "$TT/m-beta.xml" betaapp >/dev/null 2>&1 \
   && python3 "$SCHEME_TOOL" verify-ios "$TT/p-beta.plist" betaapp >/dev/null 2>&1 \
   && ! grep -q 'alphaapp' "$TT/m-beta.xml" && ! grep -q 'alphaapp' "$TT/p-beta.plist" \
   && ! grep -q 'betaapp' "$TT/m-alpha.xml" && ! grep -q 'betaapp' "$TT/p-alpha.plist"; then
  ok "T3-beta-unaffected-by-alpha"
else
  bad "T3-beta-unaffected-by-alpha" "cross-contamination between customer injections"
fi

# T4 scheme contract fail-closed (validate-scheme)
for badv in "AlphaApp" "alpha app" "alphaapp://x" "alpha/app" "" "1alpha" "alpha?x"; do
  if python3 "$SCHEME_TOOL" validate-scheme "$badv" >/dev/null 2>&1; then
    bad "T4-invalid-scheme[$badv]" "accepted an invalid scheme"
  fi
done
ok "T4-invalid-schemes-rejected"
check "T4a-inject-android-refuses-bad" nonzero python3 "$SCHEME_TOOL" inject-android "$TT/m-base.xml" "AlphaApp"
check "T4b-inject-ios-refuses-bad" nonzero python3 "$SCHEME_TOOL" inject-ios "$TT/p-base.plist" "alphaapp://x"
# vendor scheme passed to inject-android is a documented verify-only no-op
# (replaced=0, vendor_inherited=true); refusing it is buildapp.sh's F09 job
if python3 "$SCHEME_TOOL" inject-android "$TT/m-base.xml" imboy 2>&1 | grep -q '"vendor_inherited": true'; then
  ok "T4c-inject-android-vendor-is-verify-only-noop"
else
  bad "T4c-inject-android-vendor-is-verify-only-noop" "vendor scheme injection was not a no-op"
fi
check "T4d-inject-refuses-double" nonzero python3 "$SCHEME_TOOL" inject-android "$TT/m-alpha.xml" betaapp

# T5 ShareExtension plist: no URL registration, never modified by the pipeline
if ! grep -q "CFBundleURLTypes" "$TT/se-before.plist"; then ok "T5-shareextension-no-url-registration"; else bad "T5-shareextension-no-url-registration" "unexpected CFBundleURLTypes"; fi

# T6 png fallback resizer round-trip (pure-python path)
if python3 "$PNG_TOOL" resize "$FLUTTER_ROOT/web/icons/Icon-192.png" "$TT/r64.png" 64 64 2>&1 \
   && [ "$(python3 "$PNG_TOOL" size "$TT/r64.png")" = "64 64" ]; then ok "T6-png-resize-roundtrip"; else bad "T6-png-resize-roundtrip" "fallback resizer failed"; fi

# T7 parse-aapt2 splits activity filters vs queries
cat > "$TT/xmltree.txt" <<'EOF'
E: manifest (line=1)
  E: application (line=2)
    E: activity (line=3)
      E: intent-filter (line=4)
        E: data (line=5)
          A: android:scheme(0x01040027)="alphaapp"
          A: android:host(0x01040028)="imboy.pub"
      E: intent-filter (line=8)
        E: data (line=9)
          A: android:scheme(0x01040027)="https"
  E: queries (line=12)
    E: intent (line=13)
      E: data (line=14)
        A: android:scheme(0x01040027)="sms"
    E: intent (line=16)
      E: data (line=17)
        A: android:scheme(0x01040027)="tel"
EOF
if python3 "$SCHEME_TOOL" parse-aapt2 "$TT/xmltree.txt" 2>&1 | grep -q '"activity_data_schemes": \["alphaapp", "https"\]' \
   && python3 "$SCHEME_TOOL" parse-aapt2 "$TT/xmltree.txt" 2>&1 | grep -q '"queries_schemes": \["sms", "tel"\]'; then
  ok "T7-parse-aapt2"
else
  bad "T7-parse-aapt2" "$(python3 "$SCHEME_TOOL" parse-aapt2 "$TT/xmltree.txt" 2>&1)"
fi

echo "== T8: XXE / hostile-XML fail-closed (defusedxml) =="
# T8a normal manifest still parses + verifies after the parser swap
if python3 "$SCHEME_TOOL" verify-android "$TT/m-base.xml" imboy --allow-vendor-imboy >/dev/null 2>&1; then
  ok "T8a-normal-manifest-parses"
else
  bad "T8a-normal-manifest-parses" "normal AndroidManifest failed to parse under defusedxml"
fi
# XXE fixtures: DOCTYPE is banned outright (forbid_dtd), so every hostile
# variant fails closed BEFORE any entity/network/file access can happen.
NS='xmlns:android="http://schemas.android.com/apk/res/android"'
mk_xxe() { # $1=outfile $2=doctype-body $3=scheme-value
  cat > "$1" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE manifest [$2]>
<manifest $NS>
  <application>
    <activity android:name=".MainActivity" android:exported="true">
      <intent-filter>
        <action android:name="android.intent.action.VIEW"/>
        <category android:name="android.intent.category.DEFAULT"/>
        <category android:name="android.intent.category.BROWSABLE"/>
        <data android:scheme="$3"/>
      </intent-filter>
    </activity>
  </application>
</manifest>
EOF
}
mk_xxe "$TT/xxe-file.xml" '<!ENTITY xxe SYSTEM "file:///etc/passwd">' '&xxe;'
mk_xxe "$TT/xxe-net.xml" '<!ENTITY xxe SYSTEM "http://169.254.169.254/latest/meta-data/">' '&xxe;'
mk_xxe "$TT/xxe-bomb.xml" '<!ENTITY a "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"><!ENTITY b "&a;&a;&a;&a;&a;&a;&a;&a;&a;&a;"><!ENTITY c "&b;&b;&b;&b;&b;&b;&b;&b;&b;&b;"><!ENTITY d "&c;&c;&c;&c;&c;&c;&c;&c;&c;&c;"><!ENTITY e "&d;&d;&d;&d;&d;&d;&d;&d;&d;&d;"><!ENTITY f "&e;&e;&e;&e;&e;&e;&e;&e;&e;&e;"><!ENTITY g "&f;&f;&f;&f;&f;&f;&f;&f;&f;&f;"><!ENTITY h "&g;&g;&g;&g;&g;&g;&g;&g;&g;&g;"><!ENTITY i "&h;&h;&h;&h;&h;&h;&h;&h;&h;&h;">' '&i;'
printf '<?xml version="1.0"?><manifest %s><application><activity' "$NS" > "$TT/xxe-trunc.xml"
XXE_OK=1
for x in xxe-file xxe-net xxe-bomb xxe-trunc; do
  out=$(python3 "$SCHEME_TOOL" verify-android "$TT/$x.xml" alphaapp 2>&1); rc=$?
  if [ "$rc" -eq 0 ]; then bad "T8-xxe-$x" "hostile XML was ACCEPTED (rc=0)"; XXE_OK=0
  elif ! echo "$out" | grep -Eqi 'forbidden|not well-formed|ParseError|cap|DTD'; then bad "T8-xxe-$x" "failed but without a fail-closed reason: $out"; XXE_OK=0
  else ok "T8-xxe-$x-fail-closed"; fi
done
# T8f: the file-entity variant must NOT leak the referenced file's content
if ! python3 "$SCHEME_TOOL" verify-android "$TT/xxe-file.xml" alphaapp 2>&1 | grep -q 'root:'; then
  ok "T8f-file-entity-content-not-leaked"
else
  bad "T8f-file-entity-content-not-leaked" "/etc/passwd content leaked through the parse error path"
  XXE_OK=0
fi
[ "$XXE_OK" = "1" ] || true

echo "== S: URL-scheme end-to-end (dry-run receipts, F09-F12) =="
# S1 android: customer scheme registered, vendor scheme gone
run_capture "S1-android-alpha" customer-alpha development android --dry-run
S1_ART="$RECV_DIR"
expect_file_grep "S1a-android-schemes" "$S1_ART/build-manifest.yaml" 'android_registered_url_schemes: "alphaapp, https"'
if [ -f "$S1_ART/build-manifest.yaml" ] && ! grep -q 'imboy, https' "$S1_ART/build-manifest.yaml"; then ok "S1b-no-vendor-scheme"; else bad "S1b-no-vendor-scheme" "vendor scheme leaked into android registration"; fi
expect_file_grep "S1c-validation-verified" "$S1_ART/build-manifest.yaml" 'url_scheme_validation_status: verified'
expect_file_grep "S1d-device-pending" "$S1_ART/build-manifest.yaml" 'device_coexistence_test_status: DEVICE_TEST_PENDING'
if sha_check "$S1_ART"; then ok "S1e-receipt-sha"; else bad "S1e-receipt-sha" "SHA256SUMS mismatch"; fi

# S2 ios: only customer scheme as the deeplink URL type; others preserved
run_capture "S2-ios-alpha" customer-alpha development ios --dry-run
S2_ART="$RECV_DIR"
expect_file_grep "S2a-ios-schemes" "$S2_ART/build-manifest.yaml" 'ios_registered_url_schemes: "alphaapp"'
expect_file_grep "S2b-ios-all-types" "$S2_ART/build-manifest.yaml" 'ShareMedia-pub.imboy.app'
expect_file_grep "S2c-ios-alipay-kept" "$S2_ART/build-manifest.yaml" 'alipay'
if [ -f "$S2_ART/build-manifest.yaml" ] && grep -q 'build_status: DRY_RUN' "$S2_ART/build-manifest.yaml"; then ok "S2d-dryrun-status"; else bad "S2d-dryrun-status" "dry-run receipt must not claim PASS"; fi

# S3 beta unaffected by alpha runs (separate receipts, own scheme)
run_capture "S3-android-beta" customer-beta development android --dry-run
S3_ART="$RECV_DIR"
expect_file_grep "S3a-beta-schemes" "$S3_ART/build-manifest.yaml" 'android_registered_url_schemes: "betaapp, https"'
if [ -f "$S3_ART/build-manifest.yaml" ] && ! grep -q 'alphaapp' "$S3_ART/build-manifest.yaml"; then ok "S3b-no-alpha-leak"; else bad "S3b-no-alpha-leak" "alpha leaked into beta receipt"; fi
if [ -n "$S1_ART" ] && sha_check "$S1_ART"; then ok "S3c-alpha-receipt-intact"; else bad "S3c-alpha-receipt-intact" "alpha receipt corrupted after beta run"; fi

# S4 demo inheritance is explicit + disclosed (vendor scheme allowed only here)
run_capture "S4-inherit-demo-android" selftest-alpha development android --dry-run
S4_ART="$RECV_DIR"
expect_file_grep "S4a-inherit-resolution" "$S4_ART/build-manifest.yaml" 'resolution: vendor-demo-inherit'
expect_file_grep "S4b-inherit-disclosure" "$S4_ART/build-manifest.yaml" 'INHERITS the vendor imboy:// scheme'
expect_file_grep "S4c-inherit-verified" "$S4_ART/build-manifest.yaml" 'url_scheme_validation_status: verified-vendor-inherited'
expect_file_grep "S4d-inherit-android-schemes" "$S4_ART/build-manifest.yaml" 'android_registered_url_schemes: "https, imboy"'

# S5 demo WITHOUT scheme and WITHOUT inherit flag => fail-closed
sedi 's|inherit_vendor_url_scheme: "true"|inherit_vendor_url_scheme: "false"|' "$CUSTOMERS_ROOT/selftest-beta/config/app.yaml"
expect_grep "S5-demo-missing-scheme-fail-closed" "refusing to silently inherit the vendor" bash "$BUILDAPP" selftest-beta development web --dry-run
fixture selftest-beta inherit

# S6 production missing scheme => fail-closed (with production.env present)
sedi 's|url_scheme: prodapp|url_scheme: UNCONFIGURED|' "$CUSTOMERS_ROOT/customer-prod/config/app.yaml"
expect_grep "S6-prod-missing-scheme-fail-closed" "identity.url_scheme" bash "$BUILDAPP" customer-prod production web --dry-run
fixture customer-prod prodapp --production-identity

# S7 production happy path (synthetic identity) => verified customer scheme
run_capture "S7-prod-ok" customer-prod production web --dry-run
S7_ART="$RECV_DIR"
expect_file_grep "S7a-prod-scheme" "$S7_ART/build-manifest.yaml" 'configured_url_scheme: prodapp'
expect_file_grep "S7b-prod-resolution" "$S7_ART/build-manifest.yaml" 'resolution: identity.url_scheme'
expect_file_grep "S7c-prod-webonly-status" "$S7_ART/build-manifest.yaml" 'url_scheme_validation_status: config-validated-web-only'

# S8 illegal scheme values => fail-closed
YAML="$CUSTOMERS_ROOT/customer-alpha/config/app.yaml"
for badv in "AlphaApp" "alphaapp://host" "alpha/app"; do
  sedi "s|url_scheme: alphaapp|url_scheme: $badv|" "$YAML"
  expect_grep "S8-invalid[$badv]" "identity.url_scheme validation failed" bash "$BUILDAPP" customer-alpha development android --dry-run
  sedi "s|url_scheme: $badv|url_scheme: alphaapp|" "$YAML"
done

# S9 explicit vendor scheme refused in BOTH environments
expect_grep "S9a-demo-vendor-scheme-refused" "customer builds must register a customer-owned scheme" bash "$BUILDAPP" customer-demo-imboy development web --dry-run
sedi 's|url_scheme: prodapp|url_scheme: imboy|' "$CUSTOMERS_ROOT/customer-prod/config/app.yaml"
expect_grep "S9b-prod-vendor-scheme-refused" "customer builds must register a customer-owned scheme" bash "$BUILDAPP" customer-prod production web --dry-run
fixture customer-prod prodapp --production-identity

echo "== R: receipt isolation (F01-F07) =="
CB="$CUSTOMERS_ROOT/customer-alpha/builds"

# R1 same-minute double build: unique run dirs, no shared artifacts
run_capture "R1a-same-minute-first" customer-alpha development web --dry-run
R1A="$RECV_DIR"
run_capture "R1b-same-minute-second" customer-alpha development web --dry-run
R1B="$RECV_DIR"
if [ -n "$R1A" ] && [ -n "$R1B" ] && [ "$R1A" != "$R1B" ] \
   && grep -q "run_id: $(basename "$R1A" | sed 's/^.*-\([0-9]\{14\}-[0-9]*-[0-9]*\)$/\1/')" "$R1A/build-manifest.yaml" \
   && grep -q "run_id: $(basename "$R1B" | sed 's/^.*-\([0-9]\{14\}-[0-9]*-[0-9]*\)$/\1/')" "$R1B/build-manifest.yaml" \
   && sha_check "$R1A" && sha_check "$R1B"; then
  ok "R1c-unique-run-ids"
else
  bad "R1c-unique-run-ids" "same-minute receipts collided or run_id mismatch: $R1A vs $R1B"
fi

# R2 old-file poisoning: junk in parent dirs never enters the new receipt
POISON="$CUSTOMERS_ROOT/customer-alpha/builds/development/9.9.9-11060000"
mkdir -p "$POISON"
echo "fake-old-apk" > "$POISON/app-release.apk"
echo "build_status: PASS" > "$POISON/build-manifest.yaml"
echo "deadbeef  app-release.apk" > "$POISON/SHA256SUMS"
echo "stray" > "$CUSTOMERS_ROOT/customer-alpha/builds/development/stray.apk"
run_capture "R2a-poison-run" customer-alpha development web --dry-run
R2_ART="$RECV_DIR"
LINES=$(wc -l < "$R2_ART/SHA256SUMS" | tr -d ' ')
if [ "$LINES" = "2" ] && ! grep -q "stray.apk" "$R2_ART/SHA256SUMS" && ! grep -q "9.9.9" "$R2_ART/SHA256SUMS" \
   && [ "$(cat "$POISON/app-release.apk")" = "fake-old-apk" ] && [ -f "$POISON/build-manifest.yaml" ]; then
  ok "R2b-poison-isolated"
else
  bad "R2b-poison-isolated" "receipt SHA256SUMS has $LINES lines or poisoned files disturbed"
fi

# R3 success then failing rerun: old PASS receipt survives, no new PASS receipt
ALPHA_DRY_BEFORE=$(count_dirs "$CUSTOMERS_ROOT/customer-alpha/builds/dry-runs" 4)
dd if=/dev/zero of="$CUSTOMERS_ROOT/customer-alpha/assets/fixture-assets-v1/replace/web/icons/icon-192.png" bs=1 count=10 2>/dev/null
( cd "$CUSTOMERS_ROOT/customer-alpha/assets/fixture-assets-v1" && \
  find . -type f ! -path './manifest/SHA256SUMS' -exec $SHA_BIN {} \; 2>/dev/null | sed 's|\ \./| |' > manifest/SHA256SUMS )
out=$(bash "$BUILDAPP" customer-alpha development web --dry-run 2>&1); rc=$?
ALPHA_DRY_AFTER=$(count_dirs "$CUSTOMERS_ROOT/customer-alpha/builds/dry-runs" 4)
if [ "$rc" -ne 0 ] && [ "$ALPHA_DRY_AFTER" = "$ALPHA_DRY_BEFORE" ] && sha_check "$R2_ART"; then
  ok "R3-failed-rerun-keeps-old-receipt-only"
else
  bad "R3-failed-rerun-keeps-old-receipt-only" "rc=$rc receipts before=$ALPHA_DRY_BEFORE after=$ALPHA_DRY_AFTER"
fi
fixture customer-alpha alphaapp

# R4 dry-run / real-build separation: dry receipts never list artifacts
if [ -f "$R2_ART/build-manifest.yaml" ] && grep -q 'artifacts:' "$R2_ART/build-manifest.yaml" \
   && grep -A1 '^artifacts:' "$R2_ART/build-manifest.yaml" | grep -q '\[\]'; then
  ok "R4-dryrun-no-artifacts"
else
  bad "R4-dryrun-no-artifacts" "dry-run receipt lists artifacts"
fi
REAL_COUNT=$(count_dirs "$CUSTOMERS_ROOT/customer-alpha/builds/development" 1)
DRY_COUNT=$(count_dirs "$CUSTOMERS_ROOT/customer-alpha/builds/dry-runs" 4)
if [ "$REAL_COUNT" -ge 1 ] && [ "$DRY_COUNT" -ge 1 ]; then ok "R4a-layout-separation"; else bad "R4a-layout-separation" "real=$REAL_COUNT dry=$DRY_COUNT (expect both >=1)"; fi

# R5 staging root is empty after every published/failed run (no residue mixing)
if [ -z "$(ls -A "$CB/.staging" 2>/dev/null)" ]; then ok "R5-staging-empty"; else bad "R5-staging-empty" "staging residue: $(ls -A "$CB/.staging" 2>/dev/null | tr '\n' ' ')"; fi

echo "== results: PASS=$PASS FAIL=$FAIL =="
[ "$FAIL" -eq 0 ] || exit 1
