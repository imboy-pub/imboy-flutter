#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ $# -lt 1 ]]; then
  cat <<'USAGE'
Usage:
  ./scripts/build_ios.sh <build_number> [build_name]

Examples:
  ./scripts/build_ios.sh 70101
  ./scripts/build_ios.sh 70102 1.0.0-alpha.45
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
# 2026-08-22 起支付宝配置已进 env 体系（.env.pro 的 ALIPAY_APP_ID /
# ALIPAY_UNIVERSAL_LINK），不传 --dart-define 也能用；此处注入仅作显式覆盖。
# universal link：支付宝新版只认 UL 回跳。配套 AASA 已部署在
# https://pro.imboy.pub/apple-app-site-association（appID=JUYGWVJJ4C.pub.imboy.app，
# paths=["/app/*"]），entitlements 已配 applinks:pro.imboy.pub。
# 留空时 tobias 退化为 alipay URL scheme 回跳（新版支付宝不再支持）。
# 两个值均可环境变量覆盖。
ALIPAY_APP_ID="${ALIPAY_APP_ID:-2021004142626807}"
ALIPAY_UNIVERSAL_LINK="${ALIPAY_UNIVERSAL_LINK:-https://pro.imboy.pub/app/}"

echo "Building iOS with build_name=$BUILD_NAME, build_number=$BUILD_NUMBER, alipay_app_id=$ALIPAY_APP_ID, universal_link=$ALIPAY_UNIVERSAL_LINK"
# 走默认签名流程（本机 Xcode 开发者证书），产物可 archive 导出 .ipa 装真机验证
flutter build ios --release \
  --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER" \
  --dart-define=ALIPAY_APP_ID="$ALIPAY_APP_ID" \
  --dart-define=ALIPAY_UNIVERSAL_LINK="$ALIPAY_UNIVERSAL_LINK"

echo "iOS output:"
echo "  $ROOT_DIR/build/ios/iphoneos/Runner.app"
