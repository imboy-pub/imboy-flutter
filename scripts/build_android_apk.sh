#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_ROOT="$(cd "$ROOT_DIR/../imboy" && pwd)"
cd "$ROOT_DIR"

if [[ $# -ne 1 ]]; then
  cat <<'USAGE'
Usage:
  ./scripts/build_android_apk.sh <version>

Example:
  ./scripts/build_android_apk.sh 1.0.0-alpha.17
USAGE
  exit 1
fi

BUILD_NAME="$1"
if [[ ! "$BUILD_NAME" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$ ]]; then
  echo "Invalid version: $BUILD_NAME" >&2
  exit 1
fi

if ! grep -Fqx "# $BUILD_NAME" docs/changelog.md; then
  echo "docs/changelog.md 缺少发布版本标题：# $BUILD_NAME" >&2
  exit 2
fi

python3 "$BACKEND_ROOT/scripts/generate_product_features.py" \
  --check --require-profile full-selected || {
  echo "测试/演示版本必须使用 full-selected 全 features 生成物" >&2
  exit 2
}

PUBSPEC_TMP="pubspec.yaml.tmp.$$"
trap 'rm -f -- "$PUBSPEC_TMP"' EXIT
awk -v version="$BUILD_NAME" '
  /^version:[[:space:]]*/ { print "version: " version; matches++; next }
  { print }
  END { if (matches != 1) exit 1 }
' pubspec.yaml >"$PUBSPEC_TMP" || {
  echo "pubspec.yaml 必须且只能包含一个顶层 version 字段" >&2
  exit 2
}
if cmp -s "$PUBSPEC_TMP" pubspec.yaml; then
  rm -f -- "$PUBSPEC_TMP"
else
  mv -- "$PUBSPEC_TMP" pubspec.yaml
  echo "Updated pubspec.yaml version to $BUILD_NAME"
fi
trap - EXIT

echo "Building split APKs with build_name=$BUILD_NAME"
flutter build apk --release \
  --build-name="$BUILD_NAME" \
  --obfuscate \
  --split-debug-info=debugInfo \
  --target-platform=android-arm,android-arm64 \
  --split-per-abi \
  -t lib/main.dart \
  --dart-define=APP_ENV=pro \
  --dart-define=ALIPAY_APP_ID=2021004142626807

echo "APK output:"
echo "  $ROOT_DIR/build/app/outputs/flutter-apk/"
