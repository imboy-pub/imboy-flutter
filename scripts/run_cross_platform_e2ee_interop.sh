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
  local platform="$2"
  local vector="${3:-}"
  local output
  local test_file="integration_test/e2ee_cross_platform_interop_test.dart"
  local defines=(
    "--dart-define=TEST_INTEROP_ROLE=$role"
  )
  if [ -n "$vector" ]; then
    defines+=("--dart-define=TEST_INTEROP_VECTOR_B64=$vector")
  fi

  if [ "$platform" = "android" ]; then
    if ! output="$(patrol test --target "$test_file" --device "$ANDROID_DEVICE_ID" \
      --no-uninstall \
      --dart-define=PATROL_INTEROP=true \
      "${defines[@]}" 2>&1)"; then
      printf '%s\n' "$output" >&2
      return 1
    fi
  elif ! output="$(flutter test "$test_file" -d macos --no-pub --no-test-assets \
    "${defines[@]}" 2>&1)"; then
    printf '%s\n' "$output" >&2
    return 1
  fi
  printf '%s\n' "$output" | sed -n 's/.*E2EE_INTEROP_VECTOR_B64:\([A-Za-z0-9_=-]*\).*/\1/p' | tail -1
}

echo "[1/3] Android sender: 生成 Olm/PFv3 密文"
sender_vector="$(run_and_extract_vector sender android)"
test -n "$sender_vector"

echo "[2/3] macOS receiver: 解密并生成回复"
reply_vector="$(run_and_extract_vector receiver macos "$sender_vector")"
test -n "$reply_vector"

echo "[3/3] Android final: 解密 macOS 回复"
final_vector="$(run_and_extract_vector final android "$reply_vector")"
test -n "$final_vector"

echo "Android ↔ macOS C2C Olm/PFv3 双向互解通过"
