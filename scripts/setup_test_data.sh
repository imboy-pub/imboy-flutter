#!/usr/bin/env bash
# setup_test_data.sh — 集成测试数据准备（幂等，缺失即创建）
#
# 确保 PostgreSQL 中存在测试所需的基础数据：
#   - 测试账号 Alice (1000000051) / Bob (1000000056)
#   - 双向好友关系（C2C 消息发送的前置条件，否则 not_a_friend 拒发）
#
# 用法：
#   source scripts/test.env && bash scripts/setup_test_data.sh
#
# 前置：PostgreSQL 已启动并可连接
# 注意：库重置/恢复后这批数据会丢失，重跑本脚本即可恢复。
#       若后端节点已运行且曾有失败的发送尝试，好友关系缓存（300s TTL）
#       可能残留 false——脚本会尝试 RPC 冲洗，失败则等缓存自然过期。

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

PSQL=(psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}")

echo "=== 集成测试数据准备 ==="
echo "PG: ${PGHOST}:${PGPORT}/${PGDATABASE}"
echo "Alice UID: ${ALICE_UID} / Bob UID: ${BOB_UID}"
echo ""

# 检查 PG 连接
if ! "${PSQL[@]}" -c "SELECT 1" >/dev/null 2>&1; then
    echo "FAIL: PostgreSQL 连接失败"
    exit 1
fi
echo "PASS: PostgreSQL 连接正常"

# 创建测试账号（幂等；user 表无默认值的必填列：id/password/account/reg_ip/reg_cosv）
ensure_user() {
    local uid="$1"
    local account="$2"
    local nickname="$3"
    local count
    count="$("${PSQL[@]}" -At -c "SELECT COUNT(*) FROM public.\"user\" WHERE id = ${uid};")"
    if [[ "${count}" -ge 1 ]]; then
        echo "PASS: ${nickname} (uid=${uid}) 已存在"
    else
        "${PSQL[@]}" -q -c "INSERT INTO public.\"user\"
            (id, password, account, reg_ip, reg_cosv, nickname, status)
            VALUES (${uid}, '', '${account}', '127.0.0.1', 'test_data', '${nickname}', 1)
            ON CONFLICT (id) DO NOTHING;"
        echo "PASS: ${nickname} (uid=${uid}) 已创建"
    fi
}

ensure_user "${ALICE_UID}" "smoke_alice" "SmokeAlice"
ensure_user "${BOB_UID}" "smoke_bob" "SmokeBob"

# 建立双向好友关系（表 user_friend；id 无默认值用微秒时间戳；唯一键 (from,to) 保证幂等）
"${PSQL[@]}" -q <<SQL
INSERT INTO public.user_friend (id, from_user_id, to_user_id, status)
VALUES ((EXTRACT(EPOCH FROM clock_timestamp())*1000000)::bigint, ${ALICE_UID}, ${BOB_UID}, 1),
       ((EXTRACT(EPOCH FROM clock_timestamp())*1000000)::bigint + 1, ${BOB_UID}, ${ALICE_UID}, 1)
ON CONFLICT (from_user_id, to_user_id) DO NOTHING;
SQL
echo "PASS: Alice ↔ Bob 双向好友关系就绪"

# 冲洗后端好友关系缓存（可选：节点没跑或 erl 不可用时跳过，缓存 300s 自然过期）
NODE="${IMBOY_CTL_NODE:-imboy@127.0.0.1}"
COOKIE="${IMBOY_CTL_COOKIE:-imboy}"
if command -v erl >/dev/null 2>&1; then
    if erl -noshell -name "seed_$$@127.0.0.1" -setcookie "${COOKIE}" -eval \
        "case net_adm:ping('${NODE}') of pong -> rpc:call('${NODE}', friend_ds, invalidate_cache, [${ALICE_UID}, ${BOB_UID}]); _ -> ok end, halt()." \
        >/dev/null 2>&1; then
        echo "PASS: 好友关系缓存已冲洗（节点 ${NODE}）"
    else
        echo "WARN: 缓存冲洗失败（不致命：缓存最长 300s 后自然过期）"
    fi
else
    echo "WARN: 未安装 erl，跳过缓存冲洗"
fi

echo ""
echo "=== 测试数据准备完成 ==="
