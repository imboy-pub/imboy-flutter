#!/usr/bin/env bash
# setup_test_data.sh — 集成测试数据准备
#
# 确保 PostgreSQL 中存在测试所需的基础数据：
#   - 测试账号 Alice (1000000051) / Bob (1000000056)
#   - 基础好友关系
#
# 用法：
#   source script/test.env && bash script/setup_test_data.sh
#
# 前置：PostgreSQL 已启动并可连接

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载环境配置
ENV_FILE="${SCRIPT_DIR}/test.env"
if [[ -f "${ENV_FILE}" ]]; then
    set -a; source "${ENV_FILE}"; set +a
fi

PGHOST="${PGHOST:-127.0.0.1}"
PGPORT="${PGPORT:-4323}"
PGUSER="${PGUSER:-imboy_user}"
PGDATABASE="${PGDATABASE:-imboy_v1}"
export PGPASSWORD="${PGPASSWORD:-abc54321}"

ALICE_UID="${SMOKE_FROM:-1000000051}"
BOB_UID="${SMOKE_TO:-1000000056}"

echo "=== 集成测试数据准备 ==="
echo "PG: ${PGHOST}:${PGPORT}/${PGDATABASE}"
echo "Alice UID: ${ALICE_UID}"
echo "Bob UID: ${BOB_UID}"
echo ""

# 检查 PG 连接
if ! psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" -c "SELECT 1" >/dev/null 2>&1; then
    echo "FAIL: PostgreSQL 连接失败"
    exit 1
fi
echo "PASS: PostgreSQL 连接正常"

# 检查测试账号是否存在
check_user() {
    local uid="$1"
    local name="$2"
    local count
    count="$(psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" \
        -At -c "SELECT COUNT(*) FROM public.user WHERE id = ${uid};" 2>/dev/null)"
    if [[ "${count}" -ge 1 ]]; then
        echo "PASS: ${name} (uid=${uid}) 存在"
        return 0
    else
        echo "WARN: ${name} (uid=${uid}) 不存在 — 需要通过应用注册或 SQL 插入"
        return 1
    fi
}

check_user "${ALICE_UID}" "Alice"
check_user "${BOB_UID}" "Bob"

# 检查好友关系
check_friendship() {
    local uid1="$1"
    local uid2="$2"
    local count
    count="$(psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" \
        -At -c "SELECT COUNT(*) FROM public.friend WHERE (uid = ${uid1} AND friend_uid = ${uid2}) OR (uid = ${uid2} AND friend_uid = ${uid1});" 2>/dev/null)"
    if [[ "${count}" -ge 1 ]]; then
        echo "PASS: Alice ↔ Bob 好友关系存在"
    else
        echo "WARN: Alice ↔ Bob 好友关系不存在 — 测试可能需要通过应用添加"
    fi
}

check_friendship "${ALICE_UID}" "${BOB_UID}"

echo ""
echo "=== 数据准备检查完成 ==="
echo "如缺少测试账号，请先通过 Flutter app 注册或手动插入 SQL。"
