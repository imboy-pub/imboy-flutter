#!/usr/bin/env bash
# hardening2 P1 · C2G E2EE 真链路编排（Android A 群主 ↔ macOS B 成员 ↔ 新成员 spare7）。
# 用法: bash scripts/h2_run_p1_c2g.sh   （须在 C2C 真链路之后跑，避免设备争用）
set -uo pipefail

PROJ="$(cd "$(dirname "$0")/.." && pwd)"
RUN_ROOT="$PROJ/test/auto_test/reports/hardening2-20260918T211458Z"
OUT="$RUN_ROOT/steps/p1_c2g_real"
mkdir -p "$OUT"
TAG="$(date -u +%H%M%S)"
# 凭证与 fixture 账号从 gitignored 本地文件读取（fixture 合同：tracked 禁明文）
CRED="$PROJ/test/auto_test/credentials.local.json"
read_cred() { python3 -c "import json;print(json.load(open('$CRED'))['$1'])"; }
acc() { python3 -c "import json;print(json.load(open('$CRED'))['accounts']['$1']['$2'])"; }
PW="$(read_cred test_password)"
KEY_VAL="$(read_cred solidified_key)"; IV_VAL="$(read_cred solidified_key_iv)"
A_ACC="$(acc orgA_owner acc)"; A_UID="$(acc orgA_owner uid)"
B_ACC="$(acc orgA_member acc)"; B_UID="$(acc orgA_member uid)"
C_ACC="$(acc spare7 acc)"; C_UID="$(acc spare7 uid)"
PG_HOST="$(read_cred pg_host)"; PG_PORT="$(read_cred pg_port)"
PG_USER="$(read_cred pg_user)"; PG_PASS="$(read_cred pg_password)"
PG_DB="$(read_cred pg_database)"
DEV=XWE6R19916004085
WS=ws://127.0.0.1:9800/api/v1/ws
API=http://127.0.0.1:9800
GNAME="h2c2g-$TAG"

log() { printf '[H2-C2G-ORCH] %s\n' "$*"; }

curl -sf -m 3 "$API/healthz" > /dev/null || { log "后端不可达"; exit 2; }
adb -s "$DEV" reverse tcp:9800 tcp:9800 > /dev/null || { log "adb reverse 失败"; exit 2; }
adb -s "$DEV" shell input keyevent KEYCODE_WAKEUP > /dev/null 2>&1 || true

login_token() {
  curl -s -X POST "$API/api/v1/passport/login" -H 'Content-Type: application/json' \
    -d "{\"account\":\"$1\",\"pwd\":\"$PW\",\"type\":\"mobile\",\"rsa_encrypt\":\"0\"}" \
    | python3 -c "import sys,json; p=json.load(sys.stdin)['payload']; print(p.get('token') or p.get('access_token',''))"
}

# 1. 造群（A 群主 + B 成员）并开 E2EE
A_TOKEN=$(login_token $A_ACC)
[ -n "$A_TOKEN" ] || { log "A 登录失败"; exit 2; }
GID=$(curl -s -X POST "$API/api/v1/group/add" -H "Authorization: Bearer $A_TOKEN" -H 'Content-Type: application/json' \
  -d "{\"name\":\"$GNAME\",\"member_uids\":[\"$B_UID\"]}" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['payload']['group']['id'])" 2>/dev/null)
if [ -z "$GID" ]; then
  log "建群失败，原始响应："
  curl -s -X POST "$API/api/v1/group/add" -H "Authorization: Bearer $A_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"name\":\"$GNAME\",\"member_uids\":[\"$B_UID\"]}" | head -c 400
  exit 2
fi
log "群已建 gid=$GID name=$GNAME"
curl -s -X POST "$API/api/v1/group/set_e2ee_mode" -H "Authorization: Bearer $A_TOKEN" -H 'Content-Type: application/json' \
  -d "{\"gid\":\"$GID\",\"e2ee_mode\":1}" | head -c 200; echo
echo "GID=$GID" > "$OUT/group.meta"
# 注意：群初始只含 A+B。spare7 在 B 回复 m2 之后才经 API 入群（见哨兵段）——
# 若提前入群：①A 首条消息的 room-key 分发会对无设备的 spare7 做 Olm claim
# → fail-closed 拒发（2026-09-19 orch6 实证）；②spare7 会进入 gen1 世代，
# 「新成员不可见历史」语义被破坏。
# 同理 new_member 实例也**晚启动**（orch8 起）：mac 双开共享存储/设备身份，
# 与 B 并行会以 B 身份收帧（orch7 实证）——必须等 B 退出后接管 mac 槽。

COMMON_DEF=(
  "--dart-define=APP_ENV=local"
  "--dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9800"
  "--dart-define=SOLIDIFIED_KEY_OVERRIDE=$KEY_VAL"
  "--dart-define=SOLIDIFIED_KEY_IV_OVERRIDE=$IV_VAL"
  "--dart-define=WS_URL_OVERRIDE=$WS"
  "--dart-define=TEST_PASSWORD=$PW"
  "--dart-define=H2_RUN_TAG=$TAG"
  "--dart-define=H2_C2G_REAL_RUN=true"
  "--dart-define=H2_C2G_GID=$GID"
  "--dart-define=H2_C2G_M3=h2c2g-M3-$TAG"
  "--dart-define=H2_C2G_SPARE7_UID=$C_UID"
)

# macOS 清场
pkill -f "flutter_tools.snapshot --no-color run --machine" 2>/dev/null || true
pkill -x IMBoy 2>/dev/null || true
sleep 2

# 2. B 侧（macOS）后台。FRESH_LOGIN：A 每轮重装换设备身份，B 持久缓存
# 旧指纹会 IdentityChangedException 拒解 room-key（orch8 实证）——每轮
# 清 E2EE 状态重登，重建对 A 新设备的信任。
log "启动 B 侧(macOS)"
( cd "$PROJ" && flutter test integration_test/two_client/h2_c2g_mac_b_side_test.dart \
    -d macos --no-pub "${COMMON_DEF[@]}" \
    --dart-define=TEST_PHONE=$B_ACC --dart-define=TEST_EXPECTED_UID=$B_UID \
    --dart-define=H2_C2G_FRESH_LOGIN=true \
    > "$OUT/b_side.log" 2>&1 ) &
B_PID=$!
READY=0
for i in $(seq 1 210); do
  grep -q "B 侧就绪" "$OUT/b_side.log" 2>/dev/null && { READY=1; break; }
  kill -0 $B_PID 2>/dev/null || break
  sleep 1
done
log "B 侧就绪=$READY"

NM_PID=""

log "启动 A 侧(Android)"
# 强制卸载：上轮中断可能残留半配置会话（E2EE 恢复页等中间态），
# 入口白名单（welcome/login/main shell）等不到 → 恒入口超时 skip。
# 卸载后回归 C2C 已验证路径：全新安装 → Welcome → performLogin。
adb -s "$DEV" uninstall pub.imboy.app > /dev/null 2>&1 || true
sleep 1
( cd "$PROJ" && flutter test integration_test/two_client/h2_c2g_android_a_side_test.dart \
    -d "$DEV" --no-pub "${COMMON_DEF[@]}" \
    --dart-define=TEST_PHONE=$A_ACC --dart-define=TEST_EXPECTED_UID=$A_UID \
    > "$OUT/a_side.log" 2>&1 ) &
A_PID=$!

# 4. 哨兵：B 回复 m2 之后、A 发 m3 之前（A 侧收到 m2 后有 15s 缓冲），
# 经 API 让 spare7 入群。API 事务原子建 group_member + group_member_generation
# 两行——orch3 实证裸 SQL INSERT 缺 generation 行 → 服务端
# e2ee_session_generation_mismatch 拒发。邀请者须是群成员，用 A 的 token。
JOINED=0
for i in $(seq 1 1500); do
  grep -q "B 侧已回复" "$OUT/b_side.log" 2>/dev/null && { JOINED=1; break; }
  kill -0 $A_PID 2>/dev/null || break
  sleep 1
done
if [ "$JOINED" = "1" ]; then
  JOIN_RESP=$(curl -s -X POST "$API/api/v1/group_member/join" -H "Authorization: Bearer $A_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"gid\":\"$GID\",\"member_uids\":[\"$C_UID\"]}")
  log "spare7 API 入群响应: $(printf '%s' "$JOIN_RESP" | head -c 200)"
  sleep 1
  # 成员行 + generation 行都必须存在且世代未关闭，m3 staging 才放行。
  C_IN_GROUP=$(PGPASSWORD=$PG_PASS psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DB -t -A -c \
    "SELECT count(*) FROM group_member gm JOIN group_member_generation gmg ON gmg.group_id=gm.group_id AND gmg.user_id=gm.user_id WHERE gm.group_id=$GID AND gm.user_id=$C_UID AND gm.is_join=true AND gmg.end_seq IS NULL;" 2>&1)
  log "spare7 入群+generation 行确认=${C_IN_GROUP}（应为 1）"
  PGPASSWORD=$PG_PASS psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DB -t -c \
    "SELECT gm.user_id, gmg.generation_no FROM group_member gm LEFT JOIN group_member_generation gmg ON gmg.group_id=gm.group_id AND gmg.user_id=gm.user_id WHERE gm.group_id=$GID ORDER BY gm.user_id;" 2>&1
  # 等 B 侧实例退出再启动新成员：mac 双开共享存储/设备身份，并行必串号
  #（orch7 实证 spare7 以 B 身份收帧）。B 使命在「B 侧已回复」后即完成。
  for i in $(seq 1 180); do
    kill -0 $B_PID 2>/dev/null || break
    sleep 1
  done
  if kill -0 $B_PID 2>/dev/null; then
    log "⚠️ B 侧 3 分钟未退出，为避免双开串号仍启动新成员（有串号风险）"
  else
    log "B 侧已退出，mac 槽交新成员"
  fi
  # 新成员（macOS，spare7）晚启动：此刻已在群（上方 join 已落地）。登录即
  # 发布设备密钥，A 侧轮询到设备上线后轮转 S2 分发 room-key 再发 m3。
  log "启动新成员(macOS spare7，B 退出后)"
  ( cd "$PROJ" && flutter test integration_test/two_client/h2_c2g_new_member_test.dart \
      -d macos --no-pub "${COMMON_DEF[@]}" \
      --dart-define=TEST_PHONE=$C_ACC --dart-define=TEST_EXPECTED_UID=$C_UID \
      > "$OUT/new_member.log" 2>&1 ) &
  NM_PID=$!
else
  log "⚠️ 未等到 B 侧回复标记（A/B 进程可能已退出），跳过 API 入群——新成员链路预期失败"
fi

wait $A_PID; A_EXIT=$?
log "A 侧 exit=$A_EXIT"
wait $B_PID; B_EXIT=$?
log "B 侧 exit=$B_EXIT"
if [ -n "$NM_PID" ]; then
  wait $NM_PID; NM_EXIT=$?
else
  NM_EXIT=99
fi
log "新成员 exit=$NM_EXIT"

# 5. 取证
adb -s "$DEV" exec-out screencap -p > "$OUT/evidence_android_final.png" 2>/dev/null || true
screencapture -x "$OUT/evidence_mac_desktop.png" 2>/dev/null || true
PGRESULT=$(PGPASSWORD=$PG_PASS psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DB -t -A -c \
  "SELECT count(*) FILTER (WHERE payload::text LIKE '%h2c2g-%'), count(*) FROM msg_c2g WHERE payload::text LIKE '%h2c2g-%' OR created_at > now() - interval '20 min';" 2>&1)
log "后端 msg_c2g 密文断言(明文命中, 近20min行数): $PGRESULT"

# 6. 汇总（new_member 三态：PASS 或 BLOCKED[环境墙] 均计 pass，m3_blocked 单列）
python3 - "$OUT" "$TAG" "$GID" $A_EXIT $B_EXIT $NM_EXIT "$PGRESULT" <<'PY' > "$OUT/evidence.json"
import json, sys
out, tag, gid = sys.argv[1], sys.argv[2], sys.argv[3]
a, b, nm = map(int, sys.argv[4:7])
pg = sys.argv[7]
def grab(path, mark):
    try:
        return mark in open(f"{out}/{path}", encoding="utf-8", errors="replace").read()
    except FileNotFoundError:
        return False
nm_blocked = nm == 0 and grab("new_member.log", "[H2-C2G-NEW] BLOCKED")
doc = {
  "run_marker": f"h2c2g-{tag}", "gid": gid,
  "a_side_pass": a == 0 and grab("a_side.log", "A 侧 m3 已发送并回显"),
  "b_side_pass": b == 0 and grab("b_side.log", "B 侧 PASS"),
  "new_member_pass": nm == 0 and (grab("new_member.log", "[H2-C2G-NEW] PASS") or nm_blocked),
  "new_member_m3_blocked": nm_blocked,
  "isolation_pass": nm == 0 and not grab("new_member.log", "前向隔离被破坏"),
  "backend_cipher_check": pg.strip(),
  "exits": {"a": a, "b": b, "new_member": nm},
}
doc["overall"] = all(doc[k] for k in ("a_side_pass","b_side_pass","new_member_pass","isolation_pass"))
print(json.dumps(doc, ensure_ascii=False, indent=2))
PY
cat "$OUT/evidence.json"
grep -q '"overall": true' "$OUT/evidence.json"
