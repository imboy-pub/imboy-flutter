#!/usr/bin/env bash
# E2E 联调测试运行脚本
#
# 用法：
#   ./scripts/run_e2e_tests.sh                    # 使用默认配置
#   ./scripts/run_e2e_tests.sh --env local_home    # 指定环境
#   ./scripts/run_e2e_tests.sh --api-only          # 仅 API 测试
#   ./scripts/run_e2e_tests.sh --ws-only           # 仅 WebSocket 测试
#
# 环境变量（可在 .env.e2e 中配置）：
#   E2E_API_BASE_URL   后端 API 地址
#   E2E_WS_URL         WebSocket 地址
#   E2E_TEST_PHONE     测试账号手机号
#   E2E_TEST_PASSWORD  测试账号密码
#   E2E_APP_ENV        Flutter 环境 (local_office/local_home/dev)
#   E2E_DEVICE         目标设备 (-d 参数)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ─── 默认值 ──────────────────────────────────────────────
E2E_APP_ENV="${E2E_APP_ENV:-local_office}"
E2E_API_BASE_URL="${E2E_API_BASE_URL:-}"
E2E_WS_URL="${E2E_WS_URL:-}"
E2E_TEST_PHONE="${E2E_TEST_PHONE:-}"
E2E_TEST_PASSWORD="${E2E_TEST_PASSWORD:-}"
E2E_DEVICE="${E2E_DEVICE:-macos}"
TEST_TARGET="all"  # all, api, ws

# ─── 加载本地配置 ─────────────────────────────────────────
ENV_FILE="$PROJECT_DIR/.env.e2e"
if [ -f "$ENV_FILE" ]; then
  echo "📋 加载配置: $ENV_FILE"
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

# ─── 解析命令行参数 ───────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      E2E_APP_ENV="$2"
      shift 2
      ;;
    --api-url)
      E2E_API_BASE_URL="$2"
      shift 2
      ;;
    --ws-url)
      E2E_WS_URL="$2"
      shift 2
      ;;
    --phone)
      E2E_TEST_PHONE="$2"
      shift 2
      ;;
    --password)
      E2E_TEST_PASSWORD="$2"
      shift 2
      ;;
    --device|-d)
      E2E_DEVICE="$2"
      shift 2
      ;;
    --api-only)
      TEST_TARGET="api"
      shift
      ;;
    --ws-only)
      TEST_TARGET="ws"
      shift
      ;;
    --help|-h)
      cat <<'HELP'
E2E 联调测试运行脚本

用法：
  ./scripts/run_e2e_tests.sh [选项]

选项：
  --env ENV           Flutter 环境 (默认: local_office)
  --api-url URL       后端 API 地址
  --ws-url URL        WebSocket 地址
  --phone PHONE       测试账号手机号
  --password PWD      测试账号密码
  --device|-d DEVICE  目标设备 (默认: macos)
  --api-only          仅运行 API 测试
  --ws-only           仅运行 WebSocket 测试
  --help|-h           显示帮助

环境变量配置文件：
  .env.e2e            项目根目录下（不提交到 git）

示例：
  # 本地联调（办公室）
  ./scripts/run_e2e_tests.sh --env local_office --api-url http://192.168.1.100:9800

  # Android 真机联调
  ./scripts/run_e2e_tests.sh -d R5CR20XXXXX --api-url http://192.168.1.100:9800
HELP
      exit 0
      ;;
    *)
      echo "未知参数: $1"
      exit 1
      ;;
  esac
done

# ─── 参数验证 ─────────────────────────────────────────────
if [ -z "$E2E_API_BASE_URL" ]; then
  echo "❌ 错误: 必须配置 API 地址"
  echo "   --api-url http://192.168.x.x:9800"
  echo "   或在 .env.e2e 中设置 E2E_API_BASE_URL"
  exit 1
fi

if [ -z "$E2E_TEST_PHONE" ] || [ -z "$E2E_TEST_PASSWORD" ]; then
  echo "⚠️ 警告: 未配置测试账号，部分测试将跳过"
  echo "   --phone 13800138000 --password test123456"
fi

# ─── 构建 dart-define 参数 ────────────────────────────────
DART_DEFINES=(
  "--dart-define=APP_ENV=$E2E_APP_ENV"
  "--dart-define=API_BASE_URL=$E2E_API_BASE_URL"
)

if [ -n "$E2E_WS_URL" ]; then
  DART_DEFINES+=("--dart-define=WS_URL=$E2E_WS_URL")
fi

if [ -n "$E2E_TEST_PHONE" ]; then
  DART_DEFINES+=("--dart-define=TEST_PHONE=$E2E_TEST_PHONE")
fi

if [ -n "$E2E_TEST_PASSWORD" ]; then
  DART_DEFINES+=("--dart-define=TEST_PASSWORD=$E2E_TEST_PASSWORD")
fi

# ─── 确定测试文件 ─────────────────────────────────────────
case "$TEST_TARGET" in
  api)
    TEST_FILE="integration_test/e2e/api_e2e_test.dart"
    ;;
  ws)
    TEST_FILE="integration_test/e2e/ws_e2e_test.dart"
    ;;
  all)
    TEST_FILE="integration_test/e2e/all_e2e_test.dart"
    ;;
esac

# ─── 打印配置 ─────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║       E2E 联调测试                            ║"
echo "╠══════════════════════════════════════════════╣"
echo "║ 环境:     $E2E_APP_ENV"
echo "║ API:      $E2E_API_BASE_URL"
echo "║ WS:       ${E2E_WS_URL:-<自动检测>}"
echo "║ 设备:     $E2E_DEVICE"
echo "║ 测试:     $TEST_TARGET ($TEST_FILE)"
echo "║ 账号:     ${E2E_TEST_PHONE:-<未配置>}"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ─── 健康检查 ─────────────────────────────────────────────
echo "🔍 检查后端连通性..."
if curl -sf --max-time 5 "$E2E_API_BASE_URL/v1/init" > /dev/null 2>&1; then
  echo "✅ 后端可达: $E2E_API_BASE_URL"
else
  echo "❌ 后端不可达: $E2E_API_BASE_URL"
  echo "   请确认后端已启动并且网络可达"
  exit 1
fi

# ─── 运行测试 ─────────────────────────────────────────────
echo ""
echo "🚀 开始运行 E2E 测试..."
echo ""

cd "$PROJECT_DIR"

flutter test "$TEST_FILE" \
  "${DART_DEFINES[@]}" \
  -d "$E2E_DEVICE" \
  --reporter expanded \
  2>&1 | tee "/tmp/e2e_test_$(date +%Y%m%d_%H%M%S).log"

EXIT_CODE=${PIPESTATUS[0]}

echo ""
if [ $EXIT_CODE -eq 0 ]; then
  echo "✅ E2E 联调测试全部通过"
else
  echo "❌ E2E 联调测试失败 (exit code: $EXIT_CODE)"
  echo "   日志已保存到 /tmp/e2e_test_*.log"
fi

exit $EXIT_CODE
