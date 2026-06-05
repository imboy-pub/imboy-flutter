#!/usr/bin/env bash
# E2E 联调测试运行脚本
#
# Tier 1 API/WS 契约测试（无设备，可直接在 CI 运行）：
#   ./scripts/run_e2e_tests.sh --tier1
#   API_BASE_URL=http://192.168.1.100:9800 TEST_PHONE=xxx TEST_PASSWORD=yyy \
#     dart test test/api/ --concurrency=1
#
# Tier 2 冒烟门控（需真机）：
#   ./scripts/run_e2e_tests.sh --smoke -d <device>
#
# Tier 3 全量 UI 流程（需真机）：
#   ./scripts/run_e2e_tests.sh --ui -d <device>
#
# 组合运行（默认）：
#   ./scripts/run_e2e_tests.sh
#
# 环境变量（可在 .env.e2e 中配置）：
#   API_BASE_URL       后端 API 地址（Tier 1 必须）
#   TEST_PHONE         测试账号手机号
#   TEST_PASSWORD      测试账号密码
#   E2E_APP_ENV        Flutter 环境 (local_office/local_home/dev)
#   E2E_DEVICE         目标设备 (-d 参数，Tier 2/3 必须)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ─── 默认值 ──────────────────────────────────────────────
E2E_APP_ENV="${E2E_APP_ENV:-local_office}"
API_BASE_URL="${API_BASE_URL:-}"
TEST_PHONE="${TEST_PHONE:-}"
TEST_PASSWORD="${TEST_PASSWORD:-}"
E2E_DEVICE="${E2E_DEVICE:-macos}"
RUN_TIER1=false
RUN_SMOKE=false
RUN_UI=false

# ─── 加载本地配置 ─────────────────────────────────────────
ENV_FILE="$PROJECT_DIR/.env.e2e"
if [ -f "$ENV_FILE" ]; then
  echo "加载配置: $ENV_FILE"
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

# ─── 解析命令行参数 ───────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tier1)
      RUN_TIER1=true
      shift
      ;;
    --smoke)
      RUN_SMOKE=true
      shift
      ;;
    --ui)
      RUN_UI=true
      shift
      ;;
    --api-url)
      API_BASE_URL="$2"
      shift 2
      ;;
    --phone)
      TEST_PHONE="$2"
      shift 2
      ;;
    --password)
      TEST_PASSWORD="$2"
      shift 2
      ;;
    --device|-d)
      E2E_DEVICE="$2"
      shift 2
      ;;
    --help|-h)
      cat <<'HELP'
E2E 联调测试运行脚本

分层：
  --tier1   Tier 1: API/WS 契约测试（dart test，无设备）
  --smoke   Tier 2: 冒烟门控（flutter test，需真机）
  --ui      Tier 3: 全量 UI 流程（flutter test，需真机）

  默认（无参数）= --tier1 + --smoke + --ui

选项：
  --api-url URL       后端 API 地址
  --phone PHONE       测试账号手机号
  --password PWD      测试账号密码
  --device|-d DEVICE  目标设备
  --help|-h           显示帮助

Tier 1 直接运行（推荐，无需此脚本）：
  API_BASE_URL=http://127.0.0.1:9800 TEST_PHONE=xxx TEST_PASSWORD=yyy \
    dart test test/api/ --concurrency=1
HELP
      exit 0
      ;;
    *)
      echo "未知参数: $1"
      exit 1
      ;;
  esac
done

# 无参数时默认全跑
if ! $RUN_TIER1 && ! $RUN_SMOKE && ! $RUN_UI; then
  RUN_TIER1=true
  RUN_SMOKE=true
  RUN_UI=true
fi

# ─── 参数验证 ─────────────────────────────────────────────
if ($RUN_TIER1 || $RUN_SMOKE) && [ -z "$API_BASE_URL" ]; then
  echo "错误: 运行 Tier 1 或 Smoke 测试必须配置 API 地址"
  echo "  --api-url http://192.168.x.x:9800"
  echo "  或在 .env.e2e 中设置 API_BASE_URL"
  exit 1
fi

if ($RUN_TIER1 || $RUN_SMOKE) && { [ -z "$TEST_PHONE" ] || [ -z "$TEST_PASSWORD" ]; }; then
  echo "警告: 未配置测试账号，部分测试将跳过"
fi

# ─── 打印配置 ─────────────────────────────────────────────
echo ""
echo "=== E2E 联调测试 ==="
echo "API:    ${API_BASE_URL:-<未配置>}"
echo "设备:   $E2E_DEVICE"
echo "账号:   ${TEST_PHONE:-<未配置>}"
echo "Tier:   $([ $RUN_TIER1 = true ] && echo 'T1 ')$([ $RUN_SMOKE = true ] && echo 'T2 ')$([ $RUN_UI = true ] && echo 'T3')"
echo ""

cd "$PROJECT_DIR"

PASS=0
FAIL=0

# ─── Tier 1: API/WS 契约测试（dart test，无设备）────────
if $RUN_TIER1; then
  echo "--- Tier 1: API 契约测试 (dart test, 无设备) ---"

  # 后端可达性检查
  if ! curl -sf --max-time 5 "$API_BASE_URL/v1/app/init_config" > /dev/null 2>&1; then
    echo "错误: 后端不可达 $API_BASE_URL"
    exit 1
  fi
  echo "后端可达: $API_BASE_URL"

  if API_BASE_URL="$API_BASE_URL" TEST_PHONE="$TEST_PHONE" TEST_PASSWORD="$TEST_PASSWORD" \
      dart test test/api/ --concurrency=1 --reporter expanded; then
    PASS=$((PASS + 1))
    echo "Tier 1: PASS"
  else
    FAIL=$((FAIL + 1))
    echo "Tier 1: FAIL"
  fi
  echo ""
fi

# ─── Tier 2: 冒烟门控（flutter test，需真机）─────────────
if $RUN_SMOKE; then
  echo "--- Tier 2: 冒烟门控 (flutter test, 需真机) ---"

  DART_DEFINES=(
    "--dart-define=APP_ENV=$E2E_APP_ENV"
    "--dart-define=API_BASE_URL=$API_BASE_URL"
  )
  [ -n "$TEST_PHONE" ]    && DART_DEFINES+=("--dart-define=TEST_PHONE=$TEST_PHONE")
  [ -n "$TEST_PASSWORD" ] && DART_DEFINES+=("--dart-define=TEST_PASSWORD=$TEST_PASSWORD")

  if flutter test integration_test/smoke/smoke_test.dart \
      "${DART_DEFINES[@]}" -d "$E2E_DEVICE" --reporter expanded; then
    PASS=$((PASS + 1))
    echo "Tier 2: PASS"
  else
    FAIL=$((FAIL + 1))
    echo "Tier 2: FAIL"
  fi
  echo ""
fi

# ─── Tier 3: 全量 UI 流程（flutter test，需真机）────────
if $RUN_UI; then
  echo "--- Tier 3: UI 流程测试 (flutter test, 需真机) ---"

  DART_DEFINES=(
    "--dart-define=APP_ENV=$E2E_APP_ENV"
  )
  [ -n "$API_BASE_URL" ]  && DART_DEFINES+=("--dart-define=API_BASE_URL=$API_BASE_URL")
  [ -n "$TEST_PHONE" ]    && DART_DEFINES+=("--dart-define=TEST_PHONE=$TEST_PHONE")
  [ -n "$TEST_PASSWORD" ] && DART_DEFINES+=("--dart-define=TEST_PASSWORD=$TEST_PASSWORD")

  if flutter test integration_test/all_tests.dart \
      "${DART_DEFINES[@]}" -d "$E2E_DEVICE" --reporter expanded; then
    PASS=$((PASS + 1))
    echo "Tier 3: PASS"
  else
    FAIL=$((FAIL + 1))
    echo "Tier 3: FAIL"
  fi
  echo ""
fi

# ─── 汇总 ─────────────────────────────────────────────────
echo "=== 结果: $PASS 通过, $FAIL 失败 ==="
exit $FAIL
