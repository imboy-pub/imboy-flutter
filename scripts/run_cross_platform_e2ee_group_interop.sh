#!/usr/bin/env bash
set -euo pipefail

ANDROID_DEVICE_ID="${ANDROID_DEVICE_ID:-XWE6R19916004085}"
ANDROID_TEST_ABI="${ANDROID_TEST_ABI:-$(adb -s "$ANDROID_DEVICE_ID" shell getprop ro.product.cpu.abi | tr -d '\r')}"
TEST_FILE="integration_test/e2ee_cross_platform_group_interop_test.dart"
COMMON=(--no-pub --no-test-assets)

# 矢量分块重组：按索引排序+同索引去重+块数校验，避免 Patrol 日志回显重复导致夹拼错位。
# 若任何校验失败，返回空字符串交由调用方错误路径处理（fail-safe）。
# 注意：macOS 自带 BSD awk 不支持三参数 match()，故 sed 先把每行规整为 "<idx> <total> <chunk>" 三字段。
reassemble_vector() {
  local output="$1"
  printf '%s\n' "$output" |
    sed -n 's/^.*E2EE_INTEROP_VECTOR_B64_CHUNK:\([0-9][0-9]*\)\/\([0-9][0-9]*\):\([A-Za-z0-9_=-]*\).*$/\1 \2 \3/p' |
    awk '
      NF >= 3 {
        idx = $1 + 0; total = $2 + 0
        chunk = ""
        for (i = 3; i <= NF; i++) chunk = (i == 3 ? $i : chunk " " $i)
        # chunk 是 base64url，不可能含空格；合并仅防御异常行。
        gsub(/ /, "", chunk)
        if (idx <= 0 || total <= 0 || chunk == "") {
          invalid = 1
        } else if (idx in seen) {
          if (chunks[idx] != chunk || totals[idx] != total) invalid = 1
        } else {
          chunks[idx] = chunk
          totals[idx] = total
          seen[idx] = 1
          total_count++
        }
      }
      END {
        if (invalid || total_count == 0) exit 1
        first_total = ""
        for (i in totals) {
          if (first_total == "") {
            first_total = totals[i]
          } else if (totals[i] != first_total) {
            invalid = 1
          }
        }
        if (invalid || first_total <= 0) exit 1
        for (i = 1; i <= first_total; i++) {
          if (!(i in chunks) || chunks[i] == "") exit 1
        }
        for (i = 1; i <= first_total; i++) printf "%s", chunks[i]
        printf "\n"
      }
    '
}

case "$ANDROID_TEST_ABI" in
  arm64-v8a|armeabi-v7a|x86|x86_64) ;;
  *) echo "不支持的 Android 测试 ABI: $ANDROID_TEST_ABI" >&2; exit 1 ;;
esac

echo "[1/3] Android sender: 生成 Megolm 密文并用 Olm 分发 room key"
sender_output="$(env ORG_GRADLE_PROJECT_imboyE2eeTestAbi="$ANDROID_TEST_ABI" ORG_GRADLE_PROJECT_imboyE2eeNoOrchestrator=true patrol test --target "$TEST_FILE" --device "$ANDROID_DEVICE_ID" \
  --no-uninstall \
  --show-flutter-logs \
  --dart-define=PATROL_INTEROP=true \
  --dart-define=TEST_INTEROP_ROLE=sender 2>&1)"
sender_vector="$(reassemble_vector "$sender_output")"
test -n "$sender_vector"

echo "[2/3] macOS receiver: 用 Olm 解包 room key、解密群消息并回复"
if ! receiver_output="$(flutter test "$TEST_FILE" -d macos "${COMMON[@]}" \
  --dart-define=TEST_INTEROP_ROLE=receiver \
  --dart-define=TEST_INTEROP_VECTOR_B64="$sender_vector" 2>&1)"; then
  printf '%s\n' "$receiver_output" | tail -n 160
  exit 1
fi
receiver_vector="$(reassemble_vector "$receiver_output")"
if [ -z "$receiver_vector" ]; then
  printf '%s\n' "$receiver_output" | tail -n 160
  exit 1
fi

echo "[3/3] Android final: 解包 macOS room key 并解密回复"
final_output="$(env ORG_GRADLE_PROJECT_imboyE2eeTestAbi="$ANDROID_TEST_ABI" ORG_GRADLE_PROJECT_imboyE2eeNoOrchestrator=true patrol test --target "$TEST_FILE" --device "$ANDROID_DEVICE_ID" \
  --no-uninstall \
  --show-flutter-logs \
  --dart-define=PATROL_INTEROP=true \
  --dart-define=TEST_INTEROP_ROLE=final \
  --dart-define=TEST_INTEROP_VECTOR_B64="$receiver_vector" 2>&1)"
printf '%s\n' "$final_output" | tail -n 20
printf '%s\n' "$final_output" | rg -q 'E2EE_GROUP_INTEROP_PASS: Android/macOS C2G 双向互解'
printf '%s\n' "$final_output" | rg -q 'All tests passed!'
echo "Android ↔ macOS C2G Megolm/Olm 双向互解通过"
