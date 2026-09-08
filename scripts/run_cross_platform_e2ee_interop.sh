#!/usr/bin/env bash
# Android ↔ macOS C2C E2EE 互操作验收。
# 不连接后端、不登录、不写业务数据；只在两个平台间传递临时合成会话状态。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$(cd "$PROJECT_DIR/../imboy" && pwd)"
python3 "$BACKEND_DIR/scripts/generate_product_features.py" \
  --check --require-profile full-selected || {
  echo "测试版本必须使用 full-selected 全 features 生成物" >&2
  exit 2
}
ANDROID_DEVICE_ID="${ANDROID_DEVICE_ID:-XWE6R19916004085}"
ANDROID_TEST_ABI="${ANDROID_TEST_ABI:-$(adb -s "$ANDROID_DEVICE_ID" shell getprop ro.product.cpu.abi | tr -d '\r')}"

case "$ANDROID_TEST_ABI" in
  arm64-v8a|armeabi-v7a|x86|x86_64) ;;
  *) echo "不支持的 Android 测试 ABI: $ANDROID_TEST_ABI" >&2; exit 1 ;;
esac

cd "$PROJECT_DIR"

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
    if ! output="$(env ORG_GRADLE_PROJECT_imboyE2eeTestAbi="$ANDROID_TEST_ABI" ORG_GRADLE_PROJECT_imboyE2eeNoOrchestrator=true patrol test --target "$test_file" --device "$ANDROID_DEVICE_ID" \
      --no-uninstall \
      --show-flutter-logs \
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
  printf '%s\n' "$output" | reassemble_vector
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
