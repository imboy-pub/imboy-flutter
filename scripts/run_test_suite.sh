#!/usr/bin/env bash
# IMBoy Flutter 客户端确定性测试编排器。
# mobile-mcp 由 Claude Code 在本脚本完成后单独执行。

set -uo pipefail

interrupted() {
  printf '\n测试被中断，未生成通过结论。\n' >&2
  exit 130
}

trap interrupted INT TERM

APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="full"
DEVICE="${IMBOY_TEST_DEVICE:-${TEST_DEVICE:-}}"
ARTIFACT_DIR="${IMBOY_TEST_ARTIFACT_DIR:-/Users/leeyi/project/imboy.pub/imboy-test-report/app/$(date '+%Y%m%d-%H%M%S')-$$}"
RUN_INTEGRATION="${IMBOY_RUN_INTEGRATION:-1}"
RUN_PATROL="${IMBOY_RUN_PATROL:-1}"
ALLOW_REMOTE="${IMBOY_ALLOW_REMOTE_TEST:-0}"

TOTAL=0
PASS_COUNT=0
FAIL_COUNT=0
BLOCKED_COUNT=0
SKIP_COUNT=0
declare -a RESULTS=()

usage() {
  cat <<'EOF'
用法：bash scripts/run_test_suite.sh [选项]

选项：
  --mode quick|full|release   quick=静态+单元/Widget，full=契约+真机+Patrol，release=full+构建
  --device <id>               指定真实 Android/iOS 设备
  --artifact-dir <path>       指定日志目录
  --no-integration            不运行 integration_test（仅诊断）
  --no-patrol                 不运行 Patrol（仅诊断）
  -h, --help                  显示帮助

退出码：0=全部执行且通过，1=有失败，2=有阻塞/未执行，64=参数错误。
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      [[ $# -ge 2 ]] || { echo "缺少 --mode 参数" >&2; exit 64; }
      MODE="$2"
      shift 2
      ;;
    --device)
      [[ $# -ge 2 ]] || { echo "缺少 --device 参数" >&2; exit 64; }
      DEVICE="$2"
      shift 2
      ;;
    --artifact-dir)
      [[ $# -ge 2 ]] || { echo "缺少 --artifact-dir 参数" >&2; exit 64; }
      ARTIFACT_DIR="$2"
      shift 2
      ;;
    --no-integration)
      RUN_INTEGRATION=0
      shift
      ;;
    --no-patrol)
      RUN_PATROL=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

case "$MODE" in
  quick|full|release) ;;
  *) echo "非法 mode: $MODE" >&2; exit 64 ;;
esac

mkdir -p "$ARTIFACT_DIR"
SUMMARY_TSV="$ARTIFACT_DIR/summary.tsv"
SUMMARY_MD="$ARTIFACT_DIR/summary.md"
: > "$SUMMARY_TSV"

# 仅读取显式指定的外部测试环境；仓内 test.env 只在明确开启时使用。
if [[ -n "${IMBOY_TEST_ENV_FILE:-}" && -f "${IMBOY_TEST_ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$IMBOY_TEST_ENV_FILE"
  set +a
elif [[ "${IMBOY_USE_REPO_TEST_ENV:-0}" == "1" && -f "$APP_ROOT/scripts/test.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$APP_ROOT/scripts/test.env"
  set +a
fi

API_BASE_URL="${IMBOY_API_BASE_URL:-${API_BASE_URL:-http://127.0.0.1:9800}}"
TEST_PHONE="${IMBOY_TEST_PHONE:-${TEST_PHONE:-}}"
TEST_PASSWORD="${IMBOY_TEST_PASSWORD:-${TEST_PASSWORD:-}}"
TEST_SEARCH_KEYWORD="${IMBOY_TEST_SEARCH_KEYWORD:-${TEST_SEARCH_KEYWORD:-}}"
APP_ENV="${IMBOY_APP_ENV:-${APP_ENV:-local_office}}"

timestamp() { date '+%Y-%m-%dT%H:%M:%S%z'; }

local_api() {
  case "$API_BASE_URL" in
    http://127.0.0.1:*|http://localhost:*|http://0.0.0.0:*) return 0 ;;
    *) return 1 ;;
  esac
}

record() {
  local name="$1" status="$2" code="$3" duration="$4" log="$5" reason="${6:-}"
  TOTAL=$((TOTAL + 1))
  case "$status" in
    PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
    FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
    BLOCKED) BLOCKED_COUNT=$((BLOCKED_COUNT + 1)) ;;
    SKIP) SKIP_COUNT=$((SKIP_COUNT + 1)) ;;
  esac
  RESULTS+=("$name|$status|$code|${duration}s|$log|$reason")
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$status" "$code" "${duration}s" "$log" "$reason" >> "$SUMMARY_TSV"
  printf '[%s] %-34s %ss\n' "$status" "$name" "$duration"
}

blocked() { record "$1" BLOCKED 2 0 "-" "$2"; }
skipped() { record "$1" SKIP 0 0 "-" "$2"; }

first_failure_hint() {
  local log="$1" hint=""
  if command -v rg >/dev/null 2>&1; then
    hint="$(rg -i -m 1 'FAILED|failure|Expected:|Actual:|Unhandled exception|NoSuchMethodError|AssertionError|Test failed' "$log" 2>/dev/null || true)"
  else
    hint="$(grep -i -m 1 -E 'FAILED|failure|Expected:|Actual:|Unhandled exception|NoSuchMethodError|AssertionError|Test failed' "$log" 2>/dev/null || true)"
  fi
  hint="$(printf '%s' "$hint" | tr '\t\r\n' '   ' | cut -c1-240)"
  [[ -n "$hint" ]] && printf '%s' "$hint" || printf '%s' '查看日志中的首个失败断言'
}

run_step() {
  local name="$1" required="$2" workdir="$3"
  shift 3
  local log="$ARTIFACT_DIR/${name//[^A-Za-z0-9_.-]/_}.log"
  local start end duration code
  start="$(date +%s)"
  {
    printf '=== %s ===\n' "$name"
    printf '开始: %s\n' "$(timestamp)"
    printf '目录: %s\n' "$workdir"
    printf '命令参数已脱敏；测试凭证不会写入日志。\n\n'
  } > "$log"

  if [[ ! -d "$workdir" ]]; then
    record "$name" BLOCKED 2 0 "$log" "目录不存在: $workdir"
    return
  fi
  if ! command -v "$1" >/dev/null 2>&1; then
    if [[ "$required" == "required" ]]; then
      record "$name" BLOCKED 2 0 "$log" "命令不可用: $1"
    else
      record "$name" SKIP 0 0 "$log" "命令不可用: $1"
    fi
    return
  fi

  (cd "$workdir" && "$@") >> "$log" 2>&1
  code=$?
  end="$(date +%s)"
  duration=$((end - start))
  if [[ "$code" -eq 0 ]]; then
    record "$name" PASS "$code" "$duration" "$log" ""
  else
    record "$name" FAIL "$code" "$duration" "$log" "$(first_failure_hint "$log")"
  fi
}

choose_real_device() {
  [[ -n "$DEVICE" ]] && return 0
  command -v flutter >/dev/null 2>&1 || return 1
  local json
  json="$(flutter devices --machine 2>/dev/null || true)"
  if [[ -n "$json" ]] && command -v python3 >/dev/null 2>&1; then
    DEVICE="$(printf '%s' "$json" | python3 -c '
import json, sys
try:
    devices = json.load(sys.stdin)
except Exception:
    devices = []
for device in devices:
    platform = str(device.get("targetPlatform", "")).lower()
    if platform.startswith(("android", "ios")) and not device.get("emulator", False):
        print(device.get("id", ""))
        break
')"
  fi
  [[ -n "$DEVICE" ]]
}

device_available() {
  [[ -n "$DEVICE" ]] || return 1
  # 不要用 `flutter devices | grep -q`：grep -q 命中即退出关闭管道，flutter 收到
  # SIGPIPE 返回 141，set -o pipefail 会把整条管道判为失败 —— 设备明明在线也会
  # 被判成"未找到真实设备"，真机层必然 BLOCKED。先收集输出再纯 bash 匹配。
  local device_list
  device_list="$(flutter devices 2>/dev/null || true)"
  [[ "$device_list" == *"$DEVICE"* ]]
}

backend_available() {
  command -v curl >/dev/null 2>&1 || return 1
  curl -fsS --max-time 3 "${API_BASE_URL%/}/api/v1/init" >/dev/null 2>&1
}

echo "=== IMBoy App Test Suite ==="
echo "模式: $MODE"
echo "API: $API_BASE_URL"
echo "设备: ${DEVICE:-自动选择}"
echo "产物: $ARTIFACT_DIR"

# L0/L1：静态、纯逻辑、Widget、SQLite ffi、协议和服务测试。
run_step "app_analyze" required "$APP_ROOT" flutter analyze
if [[ "$MODE" == "quick" ]]; then
  QUICK_TEST_FILES=()
  while IFS= read -r test_file; do
    [[ -n "$test_file" ]] || continue
    QUICK_TEST_FILES+=("$test_file")
  done < <(
    cd "$APP_ROOT" && find test -type f -name '*_test.dart' \
      ! -path 'test/api/*' \
      ! -path 'test/integration/*' \
      ! -path 'test/smoke/*' \
      | sort
  )
  if [[ "${#QUICK_TEST_FILES[@]}" -eq 0 ]]; then
    blocked "app_unit_widget" "没有找到 Quick 单元/Widget 测试文件"
  else
    run_step "app_unit_widget" required "$APP_ROOT" flutter test --reporter compact "${QUICK_TEST_FILES[@]}"
  fi
else
  run_step "app_unit_widget_coverage" required "$APP_ROOT" flutter test --coverage --reporter compact
fi

if [[ "$MODE" != "quick" ]]; then
  run_step "app_e2ee_protocol_suite" required "$APP_ROOT" bash scripts/run_e2ee_suite.sh
fi

# L2：真实后端 API/WS 契约。远程地址或凭证缺失时明确阻塞。
if [[ "$MODE" != "quick" ]]; then
  if ! local_api && [[ "$ALLOW_REMOTE" != "1" ]]; then
    blocked "app_api_contract" "API 不是本地地址，未显式授权远程测试"
  elif ! backend_available; then
    blocked "app_api_contract" "后端不可达: $API_BASE_URL"
  elif [[ -z "$TEST_PHONE" || -z "$TEST_PASSWORD" ]]; then
    blocked "app_api_contract" "缺少 IMBOY_TEST_PHONE 或 IMBOY_TEST_PASSWORD"
  else
    run_step "app_api_contract" required "$APP_ROOT" env API_BASE_URL="$API_BASE_URL" TEST_PHONE="$TEST_PHONE" TEST_PASSWORD="$TEST_PASSWORD" dart test test/api/ --concurrency=1 --timeout=60s
  fi
fi

# L3：真实 Android/iOS 设备 integration_test。每个文件单独运行，覆盖聚合入口遗漏的测试。
if [[ "$MODE" != "quick" && "$RUN_INTEGRATION" == "1" ]]; then
  if ! choose_real_device || ! device_available; then
    blocked "app_integration_device" "未找到真实 Android/iOS 设备"
  elif [[ -z "$TEST_PHONE" || -z "$TEST_PASSWORD" ]]; then
    blocked "app_integration_device" "缺少 IMBOY_TEST_PHONE 或 IMBOY_TEST_PASSWORD"
  else
    FLOW_DEFINES=(
      "--dart-define=APP_ENV=$APP_ENV"
      "--dart-define=API_BASE_URL=$API_BASE_URL"
      "--dart-define=TEST_PHONE=$TEST_PHONE"
      "--dart-define=TEST_PASSWORD=$TEST_PASSWORD"
      "--dart-define=TEST_SEARCH_KEYWORD=$TEST_SEARCH_KEYWORD"
    )
    run_step "app_integration_smoke" required "$APP_ROOT" flutter test integration_test/smoke/smoke_test.dart -d "$DEVICE" "${FLOW_DEFINES[@]}"
    while IFS= read -r test_file; do
      [[ -n "$test_file" ]] || continue
      name="app_$(printf '%s' "$test_file" | sed 's#^integration_test/##; s#[^A-Za-z0-9_.-]#_#g; s/_test\.dart$//')"
      if [[ "$test_file" == *"password_change_test.dart" ]]; then
        run_step "$name" required "$APP_ROOT" flutter test "$test_file" -d "$DEVICE" "${FLOW_DEFINES[@]}" --dart-define=TEST_ALLOW_PASSWORD_CHANGE=false
      else
        run_step "$name" required "$APP_ROOT" flutter test "$test_file" -d "$DEVICE" "${FLOW_DEFINES[@]}"
      fi
    done < <(cd "$APP_ROOT" && find integration_test -type f -name '*_test.dart' ! -path 'integration_test/patrol/*' ! -path 'integration_test/smoke/*' | sort)
  fi
elif [[ "$MODE" != "quick" ]]; then
  skipped "app_integration_device" "IMBOY_RUN_INTEGRATION=0"
fi

# L4：Patrol 原生 UI；只补 Flutter tester 无法观测的边界。
if [[ "$MODE" != "quick" && "$RUN_PATROL" == "1" ]]; then
  if ! choose_real_device || ! device_available; then
    blocked "app_patrol" "Patrol 需要真实 Android/iOS 设备"
  elif ! command -v patrol >/dev/null 2>&1; then
    blocked "app_patrol" "Patrol CLI 不可用"
  else
    PATROL_DEFINES=(
      "--dart-define=APP_ENV=$APP_ENV"
      "--dart-define=API_BASE_URL=$API_BASE_URL"
      "--dart-define=TEST_PHONE=$TEST_PHONE"
      "--dart-define=TEST_PASSWORD=$TEST_PASSWORD"
    )
    while IFS= read -r test_file; do
      [[ -n "$test_file" ]] || continue
      name="patrol_$(basename "$test_file" .dart)"
      run_step "$name" required "$APP_ROOT" patrol test --target "$test_file" --device "$DEVICE" "${PATROL_DEFINES[@]}"
    done < <(cd "$APP_ROOT" && find integration_test/patrol -type f -name '*_test.dart' | sort)
  fi
elif [[ "$MODE" != "quick" ]]; then
  skipped "app_patrol" "IMBOY_RUN_PATROL=0"
fi

# L5：release 只加构建，不自动读取签名材料。
if [[ "$MODE" == "release" ]]; then
  run_step "app_android_debug_build" required "$APP_ROOT" flutter build apk --debug
fi

cat > "$SUMMARY_MD" <<EOF
# IMBoy App Test Report

- 模式：$MODE
- API：${API_BASE_URL:-未配置}（凭证未写入）
- 设备：${DEVICE:-未使用}
- 通过：$PASS_COUNT
- 失败：$FAIL_COUNT
- 阻塞：$BLOCKED_COUNT
- 跳过：$SKIP_COUNT

| 阶段 | 状态 | 退出码 | 耗时 | 日志 | 说明 |
|---|---|---:|---:|---|---|
EOF
for result in "${RESULTS[@]}"; do
  IFS='|' read -r name status code duration log reason <<< "$result"
  printf '| `%s` | **%s** | %s | %s | `%s` | %s |\n' "$name" "$status" "$code" "$duration" "$log" "$reason" >> "$SUMMARY_MD"
done

echo
echo "=== 汇总 ==="
echo "总计: $TOTAL  通过: $PASS_COUNT  失败: $FAIL_COUNT  阻塞: $BLOCKED_COUNT  跳过: $SKIP_COUNT"
echo "报告: $SUMMARY_MD"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
if [[ "$BLOCKED_COUNT" -gt 0 ]]; then
  exit 2
fi
exit 0
