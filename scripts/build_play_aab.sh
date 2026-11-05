#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: ./scripts/build_play_aab.sh <build_number> [build_name]" >&2
  exit 1
fi

BUILD_NUMBER="$1"
if [[ ! "$BUILD_NUMBER" =~ ^[1-9][0-9]{0,9}$ ]] || (( BUILD_NUMBER > 2100000000 )); then
  echo "build_number must be an integer between 1 and 2100000000" >&2
  exit 1
fi
BUILD_NAME="${2:-$(awk -F': ' '/^version:/{print $2}' pubspec.yaml | head -n1)}"
BUILD_NAME="${BUILD_NAME%%+*}"
if [[ -z "$BUILD_NAME" ]]; then
  echo "Unable to resolve build name from pubspec.yaml, please pass [build_name]." >&2
  exit 1
fi

python3 "$ROOT_DIR/scripts/check_sdk_compatibility.py"
BACKEND_ROOT="$(cd "$ROOT_DIR/../imboy" && pwd)"
python3 "$BACKEND_ROOT/scripts/generate_product_features.py" \
  --check --require-profile full-selected || {
  echo "测试/演示版本必须使用 full-selected 全 features 生成物" >&2
  exit 2
}

# 支付宝 App 支付的公开 appId（非密钥；商户密钥全部在服务端）。
# 不注入则 PaymentConfig.isAlipayConfigured=false，客户端充值降级为「即将开通」。
# universal link 本期不注入：留空时 tobias 在 iOS 退化为 alipay URL scheme 回跳
# （Info.plist 已配 LSApplicationQueriesSchemes），AASA + Associated Domains
# 属 ios/* 保留区改造，列为 follow-up。可用环境变量覆盖默认值。
ALIPAY_APP_ID="${ALIPAY_APP_ID:-2021004142626807}"

SYMBOL_DIR="${PLAY_SYMBOL_DIR:-$ROOT_DIR/debugInfo/play/$BUILD_NUMBER}"
AAB_PATH="$ROOT_DIR/build/app/outputs/bundle/standardRelease/app-standard-release.aab"
mkdir -p "$SYMBOL_DIR"
echo "Building AAB with build_name=$BUILD_NAME, build_number=$BUILD_NUMBER"
flutter build appbundle --release --flavor standard \
  --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER" \
  --obfuscate --split-debug-info="$SYMBOL_DIR" \
  --dart-define=ALIPAY_APP_ID="$ALIPAY_APP_ID"

if [[ ! -f "$AAB_PATH" ]]; then
  echo "Expected standard AAB not found: $AAB_PATH" >&2
  exit 1
fi
printf 'AAB: %s\nDart symbols: %s\n' "$AAB_PATH" "$SYMBOL_DIR"
echo "Verify AAB signature, certificate fingerprint, manifest, versionCode and symbols before release."
