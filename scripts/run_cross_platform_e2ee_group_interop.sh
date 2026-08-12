#!/usr/bin/env bash
set -euo pipefail

ANDROID_DEVICE_ID="${ANDROID_DEVICE_ID:-XWE6R19916004085}"
TEST_FILE="integration_test/e2ee_cross_platform_group_interop_test.dart"
COMMON=(--no-pub --no-test-assets)

echo "[1/3] Android sender: 生成 Megolm 密文并用 Olm 分发 room key"
sender_output="$(flutter test "$TEST_FILE" -d "$ANDROID_DEVICE_ID" "${COMMON[@]}" \
  --dart-define=TEST_INTEROP_ROLE=sender 2>&1)"
sender_vector="$(printf '%s\n' "$sender_output" | sed -n 's/^.*E2EE_INTEROP_VECTOR_B64:\(.*\)$/\1/p' | tail -n 1)"
test -n "$sender_vector"

echo "[2/3] macOS receiver: 用 Olm 解包 room key、解密群消息并回复"
if ! receiver_output="$(flutter test "$TEST_FILE" -d macos "${COMMON[@]}" \
  --dart-define=TEST_INTEROP_ROLE=receiver \
  --dart-define=TEST_INTEROP_VECTOR_B64="$sender_vector" 2>&1)"; then
  printf '%s\n' "$receiver_output" | tail -n 160
  exit 1
fi
receiver_vector="$(printf '%s\n' "$receiver_output" | sed -n 's/^.*E2EE_INTEROP_VECTOR_B64:\(.*\)$/\1/p' | tail -n 1)"
if [ -z "$receiver_vector" ]; then
  printf '%s\n' "$receiver_output" | tail -n 160
  exit 1
fi

echo "[3/3] Android final: 解包 macOS room key 并解密回复"
final_output="$(flutter test "$TEST_FILE" -d "$ANDROID_DEVICE_ID" "${COMMON[@]}" \
  --dart-define=TEST_INTEROP_ROLE=final \
  --dart-define=TEST_INTEROP_VECTOR_B64="$receiver_vector" 2>&1)"
printf '%s\n' "$final_output" | tail -n 20
printf '%s\n' "$final_output" | rg -q 'E2EE_GROUP_INTEROP_PASS: Android/macOS C2G 双向互解'
printf '%s\n' "$final_output" | rg -q 'All tests passed!'
echo "Android ↔ macOS C2G Megolm/Olm 双向互解通过"
