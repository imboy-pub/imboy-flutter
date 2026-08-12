#!/usr/bin/env bash
# Android ↔ macOS C2C E2EE 互操作验收。
# 不连接后端、不登录、不写业务数据；只在两个平台间传递临时合成会话状态。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ANDROID_DEVICE_ID="${ANDROID_DEVICE_ID:-XWE6R19916004085}"

cd "$PROJECT_DIR"

run_and_extract_vector() {
  local role="$1"
  shift
  local output
  if ! output="$(flutter test integration_test/e2ee_cross_platform_interop_test.dart "$@" \
    --dart-define=TEST_INTEROP_ROLE="$role" --no-pub --no-test-assets 2>&1)"; then
    printf '%s\n' "$output" >&2
    return 1
  fi
  printf '%s\n' "$output" | sed -n 's/.*E2EE_INTEROP_VECTOR_B64:\([A-Za-z0-9_=-]*\).*/\1/p' | tail -1
}

echo "[1/3] Android sender: 生成 Olm/PFv3 密文"
sender_vector="$(run_and_extract_vector sender -d "$ANDROID_DEVICE_ID")"
test -n "$sender_vector"

echo "[2/3] macOS receiver: 解密并生成回复"
reply_vector="$(run_and_extract_vector receiver -d macos \
  --dart-define=TEST_INTEROP_VECTOR_B64="$sender_vector")"
test -n "$reply_vector"

echo "[3/3] Android final: 解密 macOS 回复"
if ! final_output="$(flutter test integration_test/e2ee_cross_platform_interop_test.dart \
  -d "$ANDROID_DEVICE_ID" --no-pub --no-test-assets \
  --dart-define=TEST_INTEROP_ROLE=final \
  --dart-define=TEST_INTEROP_VECTOR_B64="$reply_vector" 2>&1)"; then
  printf '%s\n' "$final_output" >&2
  exit 1
fi
printf '%s\n' "$final_output" | rg 'E2EE_INTEROP_PASS|All tests passed'

echo "Android ↔ macOS C2C Olm/PFv3 双向互解通过"
