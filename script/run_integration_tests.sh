#!/usr/bin/env bash
# run_integration_tests.sh — 一键全链路集成测试编排
#
# 流程：检查依赖 → 启动后端 → 探活 → smoke → Flutter integration_test → 收集报告 → 清理
#
# 用法：
#   source script/test.env   # 先配置 TEST_PHONE 等变量
#   bash script/run_integration_tests.sh
#
# 退出码：
#   0 = 全部通过
#   1 = Flutter 测试失败
#   2 = 后端启动失败
#   3 = 后端 smoke 失败
#   4 = 环境检查失败

set -euo pipefail

# ── 项目根目录 ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
IMBOY_DIR="${PROJECT_ROOT}/imboy"
IMBOYAPP_DIR="${PROJECT_ROOT}/imboyapp"
OUTPUT_DIR="${PROJECT_ROOT}/test_output"

# ── 加载环境配置 ──
ENV_FILE="${SCRIPT_DIR}/test.env"
if [[ -f "${ENV_FILE}" ]]; then
    set -a; source "${ENV_FILE}"; set +a
fi

# ── 默认值 ──
PGHOST="${PGHOST:-127.0.0.1}"
PGPORT="${PGPORT:-4323}"
PGUSER="${PGUSER:-imboy_user}"
PGDATABASE="${PGDATABASE:-imboy_v1}"
HTTP_PORT="${HTTP_PORT:-9800}"
BACKEND_STARTUP_TIMEOUT="${BACKEND_STARTUP_TIMEOUT:-60}"
TEST_DEVICE="${TEST_DEVICE:-macos}"
APP_ENV="${APP_ENV:-local_office}"
SMOKE_FROM="${SMOKE_FROM:-1000000051}"
SMOKE_TO="${SMOKE_TO:-1000000056}"

# ── 后端启动方式标记（true = 本次启动的，需要清理）──
BACKEND_STARTED=false

# ── 颜色输出 ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }

# ── 清理函数 ──
cleanup() {
    if [[ "${BACKEND_STARTED}" == "true" ]]; then
        log "停止后端 (daemon stop)..."
        cd "${IMBOY_DIR}" && _rel/imboy/bin/imboy stop 2>/dev/null || true
        cd "${PROJECT_ROOT}"
        BACKEND_STARTED=false
    fi
}
trap cleanup EXIT

# ═══════════════════════════════════════════════════════════════
# Step 0: 准备输出目录
# ═══════════════════════════════════════════════════════════════
mkdir -p "${OUTPUT_DIR}/screenshots"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="${OUTPUT_DIR}/integration_report_${TIMESTAMP}.log"
exec > >(tee -a "${REPORT_FILE}") 2>&1

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     IMBoy 全链路集成测试 / Full-Stack Integration Test      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
log "报告输出: ${REPORT_FILE}"
log "截图目录: ${OUTPUT_DIR}/screenshots"
echo ""

# ═══════════════════════════════════════════════════════════════
# Step 1: 检查前置依赖
# ═══════════════════════════════════════════════════════════════
log "Step 1/8: 检查前置依赖"

check_cmd() {
    if command -v "$1" >/dev/null 2>&1; then
        ok "$1 已安装"
        return 0
    else
        fail "$1 未安装"
        return 1
    fi
}

DEPS_OK=true
check_cmd erl   || DEPS_OK=false
check_cmd flutter || DEPS_OK=false
check_cmd psql  || DEPS_OK=false

if [[ "${DEPS_OK}" != "true" ]]; then
    fail "缺少必要依赖，请安装后重试"
    exit 4
fi

# 检查 Flutter 设备
if ! flutter devices 2>/dev/null | grep -q "${TEST_DEVICE}"; then
    warn "未检测到 ${TEST_DEVICE} 设备，尝试继续..."
fi

# ═══════════════════════════════════════════════════════════════
# Step 2: 检查 PostgreSQL
# ═══════════════════════════════════════════════════════════════
log "Step 2/8: 检查 PostgreSQL 连接"

export PGPASSWORD="${PGPASSWORD:-abc54321}"
if psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" -c "SELECT 1" >/dev/null 2>&1; then
    ok "PostgreSQL 连接正常 (${PGHOST}:${PGPORT}/${PGDATABASE})"
else
    fail "PostgreSQL 连接失败 (${PGHOST}:${PGPORT}/${PGDATABASE})"
    exit 4
fi

# ═══════════════════════════════════════════════════════════════
# Step 3: 启动后端
# ═══════════════════════════════════════════════════════════════
log "Step 3/8: 启动 Erlang 后端"

PROBE_URL="http://127.0.0.1:${HTTP_PORT}/app_version/check"
if curl -sf --max-time 3 "${PROBE_URL}" >/dev/null 2>&1; then
    ok "后端已在运行 (port=${HTTP_PORT})"
else
    log "启动后端: IMBOYENV=${IMBOYENV} _rel/imboy/bin/imboy daemon (port=${HTTP_PORT})..."
    cd "${IMBOY_DIR}"
    IMBOYENV="${IMBOYENV}" _rel/imboy/bin/imboy daemon
    BACKEND_STARTED=true
    cd "${PROJECT_ROOT}"

    log "等待后端就绪 (最多 ${BACKEND_STARTUP_TIMEOUT}s)..."
    ELAPSED=0
    while [[ ${ELAPSED} -lt ${BACKEND_STARTUP_TIMEOUT} ]]; do
        if curl -sf --max-time 2 "${PROBE_URL}" >/dev/null 2>&1; then
            ok "后端就绪 (${ELAPSED}s)"
            break
        fi
        sleep 2
        ELAPSED=$((ELAPSED + 2))
    done

    if [[ ${ELAPSED} -ge ${BACKEND_STARTUP_TIMEOUT} ]]; then
        fail "后端启动超时 (${BACKEND_STARTUP_TIMEOUT}s)"
        exit 2
    fi
fi

# ═══════════════════════════════════════════════════════════════
# Step 4: 确保测试用户存在
# ═══════════════════════════════════════════════════════════════
log "Step 4/8: 确保测试用户存在"

ENSURE_SCRIPT="${IMBOY_DIR}/scripts/smoke/ensure_test_user.escript"
TEST_UID="${SMOKE_FROM:-1000000051}"

if [[ -x "${ENSURE_SCRIPT}" ]]; then
    ENSURE_OUT=$("${ENSURE_SCRIPT}" "${TEST_UID}" "${TEST_PHONE}" "TestAlice" "${TEST_PASSWORD}" 2>&1) || {
        warn "ensure_test_user 返回非零，尝试继续 (输出: ${ENSURE_OUT})"
    }
    ok "测试用户就绪 (uid=${TEST_UID})"
else
    warn "ensure_test_user.escript 不存在或不可执行，跳过用户创建"
fi

# ═══════════════════════════════════════════════════════════════
# Step 5: 后端 Smoke Test
# ═══════════════════════════════════════════════════════════════
log "Step 5/8: 运行后端 Smoke Test"

cd "${IMBOY_DIR}"
SMOKE_RC=0
make smoke SMOKE_FROM="${SMOKE_FROM}" SMOKE_TO="${SMOKE_TO}" 2>&1 | tee -a "${REPORT_FILE}" || SMOKE_RC=$?
if [[ ${SMOKE_RC} -eq 0 ]]; then
    ok "后端 Smoke Test 通过"
else
    warn "后端 Smoke Test 失败 (rc=${SMOKE_RC})，继续执行 Flutter 测试..."
fi
cd "${PROJECT_ROOT}"

# ═══════════════════════════════════════════════════════════════
# Step 6: Flutter Integration Test
# ═══════════════════════════════════════════════════════════════
log "Step 6/8: 运行 Flutter Integration Test"

FLUTTER_ARGS=(
    test
    integration_test/all_tests.dart
    --dart-define=APP_ENV="${APP_ENV}"
    --dart-define=API_BASE_URL_OVERRIDE="http://127.0.0.1:${HTTP_PORT}"
    --dart-define=WS_URL_OVERRIDE="ws://127.0.0.1:${HTTP_PORT}/ws"
    -d "${TEST_DEVICE}"
)

if [[ -n "${TEST_PHONE:-}" ]]; then
    FLUTTER_ARGS+=(--dart-define=TEST_PHONE="${TEST_PHONE}")
fi
if [[ -n "${TEST_PASSWORD:-}" ]]; then
    FLUTTER_ARGS+=(--dart-define=TEST_PASSWORD="${TEST_PASSWORD}")
fi

cd "${IMBOYAPP_DIR}"
log "执行: flutter ${FLUTTER_ARGS[*]}"

FLUTTER_RC=0
flutter "${FLUTTER_ARGS[@]}" 2>&1 | tee -a "${REPORT_FILE}" || FLUTTER_RC=$?
cd "${PROJECT_ROOT}"

if [[ ${FLUTTER_RC} -eq 0 ]]; then
    ok "Flutter Integration Test 通过"
else
    fail "Flutter Integration Test 失败 (rc=${FLUTTER_RC})"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════
# Step 7: 报告汇总
# ═══════════════════════════════════════════════════════════════
log "Step 7/8: 生成报告"

# ── 解析测试结果 ──
PASS_COUNT=$(grep -c '✅' "${REPORT_FILE}" 2>/dev/null || echo 0)
SKIP_COUNT=$(grep -c '\[AUTO-SKIP\]' "${REPORT_FILE}" 2>/dev/null || echo 0)
FAIL_COUNT=$(grep -c '⚠️' "${REPORT_FILE}" 2>/dev/null || echo 0)
INFO_COUNT=$(grep -c 'ℹ️' "${REPORT_FILE}" 2>/dev/null || echo 0)

# ── 控制台摘要 ──
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
if [[ ${FLUTTER_RC} -eq 0 ]]; then
    echo "║              全链路集成测试通过 / ALL TESTS PASS            ║"
else
    echo "║              集成测试失败 / TESTS FAILED                    ║"
fi
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "┌──────────────────────────────────────────────────────────┐"
echo "│  测试摘要 / Test Summary                                  │"
echo "├──────────────────────────────────────────────────────────┤"
printf "│  ✅ 通过 / Passed:    %-5d                              │\n" "${PASS_COUNT}"
printf "│  ⏭️ 跳过 / Skipped:   %-5d                              │\n" "${SKIP_COUNT}"
printf "│  ⚠️ 警告 / Warnings:  %-5d                              │\n" "${FAIL_COUNT}"
printf "│  ℹ️ 信息 / Info:      %-5d                              │\n" "${INFO_COUNT}"
echo "├──────────────────────────────────────────────────────────┤"
printf "│  后端 Smoke:  %-10s                                    │\n" "$([[ ${SMOKE_RC} -eq 0 ]] && echo 'PASS' || echo 'FAIL')"
printf "│  Flutter 测试: %-10s                                   │\n" "$([[ ${FLUTTER_RC} -eq 0 ]] && echo 'PASS' || echo 'FAIL')"
echo "└──────────────────────────────────────────────────────────┘"
echo ""
ok "报告: ${REPORT_FILE}"
ok "截图: ${OUTPUT_DIR}/screenshots/"
echo ""

# ── JSON 结构化报告 ──
JSON_REPORT="${OUTPUT_DIR}/integration_report_${TIMESTAMP}.json"

# 收集 AUTO-SKIP 原因
SKIP_REASONS=$(grep '\[AUTO-SKIP\] reason=' "${REPORT_FILE}" 2>/dev/null \
    | sed 's/.*reason=//' \
    | sort -u \
    | tr '\n' '|' \
    | sed 's/|$//' \
    || echo "none")

cat > "${JSON_REPORT}" <<JSONEOF
{
  "timestamp": "${TIMESTAMP}",
  "device": "${TEST_DEVICE}",
  "app_env": "${APP_ENV}",
  "backend_smoke": "$([[ ${SMOKE_RC} -eq 0 ]] && echo 'pass' || echo 'fail')",
  "flutter_result": "$([[ ${FLUTTER_RC} -eq 0 ]] && echo 'pass' || echo 'fail')",
  "flutter_rc": ${FLUTTER_RC},
  "passed": ${PASS_COUNT},
  "skipped": ${SKIP_COUNT},
  "warnings": ${FAIL_COUNT},
  "info": ${INFO_COUNT},
  "skip_reasons": "${SKIP_REASONS}",
  "report_log": "${REPORT_FILE}",
  "screenshots_dir": "${OUTPUT_DIR}/screenshots/"
}
JSONEOF

ok "JSON 报告: ${JSON_REPORT}"

exit 0
