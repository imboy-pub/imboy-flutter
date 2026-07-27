#!/usr/bin/env bash
# pre_push_gate.sh — pre-push 测试门控
#
# 设计原则：
#   1. 不阻塞所有 push —— 后端不可达 / 未配置凭证时优雅跳过（exit 0）
#   2. 只跑无设备的 Tier 1 API 契约测试（dart test test/api/）
#   3. 后端可达 + 凭证就绪 → 跑测试，失败则阻塞 push（exit 1）
#   4. 紧急情况可用 IMBOY_SKIP_PRE_PUSH=1 强制跳过
#
# 用法（lefthook 自动调用，也可手动执行）：
#   bash scripts/pre_push_gate.sh
#
# 手动跳过：
#   IMBOY_SKIP_PRE_PUSH=1 git push ...

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_ROOT}"

# 紧急跳过
if [[ "${IMBOY_SKIP_PRE_PUSH:-0}" == "1" ]]; then
  echo "[pre-push] IMBOY_SKIP_PRE_PUSH=1，跳过门控"
  exit 0
fi

# 加载测试环境配置（scripts/test.env）
ENV_FILE="${SCRIPT_DIR}/test.env"
if [[ -f "${ENV_FILE}" ]]; then
  set +a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set -a
  source "${ENV_FILE}"
  set +a
fi

# 环境变量（test.env 或外环境注入）
API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:9800}"
TEST_PHONE="${TEST_PHONE:-}"
TEST_PASSWORD="${TEST_PASSWORD:-}"

# ─── 探活后端 ───
# /api/v1/init 无需认证，3s 超时
PROBE_URL="${API_BASE_URL%/}/api/v1/init"
if ! command -v curl >/dev/null 2>&1; then
  echo "[pre-push] curl 不可用，跳过 API 契约测试（不阻塞 push）"
  exit 0
fi

if ! curl -sf --max-time 3 "${PROBE_URL}" >/dev/null 2>&1; then
  echo "[pre-push] 后端不可达 (${API_BASE_URL})，跳过 API 契约测试（不阻塞 push）"
  echo "           如需本地启动后端，见 ../imboy/ 目录（Erlang/OTP）"
  exit 0
fi

echo "[pre-push] 后端可达: ${API_BASE_URL}"

# ─── 检查凭证 ───
if [[ -z "${TEST_PHONE}" || -z "${TEST_PASSWORD}" ]]; then
  echo "[pre-push] 未配置 TEST_PHONE/TEST_PASSWORD，跳过 API 契约测试"
  echo "           配置方式：编辑 scripts/test.env 或 export 环境变量"
  exit 0
fi

# ─── 检查 dart 可用 ───
if ! command -v dart >/dev/null 2>&1; then
  echo "[pre-push] dart 命令不可用，跳过 API 契约测试"
  echo "           请确保 Flutter SDK 在 PATH 中"
  exit 0
fi

# ─── 执行 Tier 1 API 契约测试 ───
echo "[pre-push] 执行 Tier 1 API 契约测试 (test/api/) ..."
echo "           API_BASE_URL=${API_BASE_URL}"
echo "           TEST_PHONE=${TEST_PHONE}"
echo ""

export API_BASE_URL TEST_PHONE TEST_PASSWORD

# concurrency=1：避免并发登录导致 token 互踢
# test-timeout：单测试最长 60s，防止后端 hang 住阻塞 push
if dart test test/api/ --concurrency=1 --timeout=60s; then
  echo ""
  echo "[pre-push] ✅ API 契约测试通过"
  exit 0
else
  echo ""
  echo "[pre-push] ❌ API 契约测试失败，已阻止 push"
  echo "           修复后重试，或紧急情况用: IMBOY_SKIP_PRE_PUSH=1 git push ..."
  exit 1
fi
