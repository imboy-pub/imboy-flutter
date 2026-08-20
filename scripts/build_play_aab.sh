#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ $# -lt 1 ]]; then
  cat <<'USAGE'
Usage:
  ./scripts/build_play_aab.sh <build_number> [build_name]

Examples:
  ./scripts/build_play_aab.sh 70101
  ./scripts/build_play_aab.sh 70102 0.7.2
USAGE
  exit 1
fi

BUILD_NUMBER="$1"
BUILD_NAME="${2:-$(awk -F': ' '/^version:/{print $2}' pubspec.yaml | head -n1)}"

if [[ -z "$BUILD_NAME" ]]; then
  echo "Unable to resolve build name from pubspec.yaml, please pass [build_name]."
  exit 1
fi

# 支付宝 App 支付的公开 appId（非密钥；商户密钥全部在服务端）。
# 不注入则 PaymentConfig.isAlipayConfigured=false，客户端充值降级为「即将开通」。
# universal link 本期不注入：留空时 tobias 在 iOS 退化为 alipay URL scheme 回跳
# （Info.plist 已配 LSApplicationQueriesSchemes），AASA + Associated Domains
# 属 ios/* 保留区改造，列为 follow-up。可用环境变量覆盖默认值。
ALIPAY_APP_ID="${ALIPAY_APP_ID:-2021004142626807}"

echo "Building AAB with build_name=$BUILD_NAME, build_number=$BUILD_NUMBER, alipay_app_id=$ALIPAY_APP_ID"
flutter build appbundle --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER" \
  --dart-define=ALIPAY_APP_ID="$ALIPAY_APP_ID"

echo "AAB output:"
echo "  $ROOT_DIR/build/app/outputs/bundle/release/app-release.aab"
