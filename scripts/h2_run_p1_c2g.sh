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
)

# macOS 清场
pkill -f "flutter_tools.snapshot --no-color run --machine" 2>/dev/null || true
pkill -x IMBoy 2>/dev/null || true
sleep 2

# 2. B 侧（macOS）后台
log "启动 B 侧(macOS)"
( cd "$PROJ" && flutter test integration_test/two_client/h2_c2g_mac_b_side_test.dart \
    -d macos --no-pub "${COMMON_DEF[@]}" \
    --dart-define=TEST_PHONE=$B_ACC --dart-define=TEST_EXPECTED_UID=$B_UID \
    > "$OUT/b_side.log" 2>&1 ) &
B_PID=$!
READY=0
for i in $(seq 1 210); do
  grep -q "B 侧就绪" "$OUT/b_side.log" 2>/dev/null && { READY=1; break; }
  kill -0 $B_PID 2>/dev/null || break
  sleep 1
done
log "B 侧就绪=$READY"

# 3. A 侧（Android）：m1 → m2 → m3（m3 前编排已把 spare7 入群）
# spare7 先入群（SQL，A6 授权数据面；带 run marker 由群名承担）
PGPASSWORD=$PG_PASS psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DB -t -c \
  "INSERT INTO group_member (id, group_id, user_id, role, is_join, status, join_mode, created_at) VALUES ((SELECT COALESCE(MAX(id),113437940000010000)+1 FROM group_member), $GID, $C_UID, 3, true, 1, 'h2newmember-$TAG', now()) ON CONFLICT DO NOTHING;" 2>&1 | head -2
log "spare7 入群完成"

log "启动 A 侧(Android)"
( cd "$PROJ" && flutter test integration_test/two_client/h2_c2g_android_a_side_test.dart \
    -d "$DEV" --no-pub "${COMMON_DEF[@]}" \
    --dart-define=TEST_PHONE=$A_ACC --dart-define=TEST_EXPECTED_UID=$A_UID \
    > "$OUT/a_side.log" 2>&1 )
A_EXIT=$?
log "A 侧 exit=$A_EXIT"
wait $B_PID; B_EXIT=$?
log "B 侧 exit=$B_EXIT"

# 4. 新成员（macOS，spare7）
( cd "$PROJ" && flutter test integration_test/two_client/h2_c2g_new_member_test.dart \
    -d macos --no-pub "${COMMON_DEF[@]}" \
    --dart-define=TEST_PHONE=$C_ACC --dart-define=TEST_EXPECTED_UID=$C_UID \
    > "$OUT/new_member.log" 2>&1 )
NM_EXIT=$?
log "新成员 exit=$NM_EXIT"

# 5. 取证
adb -s "$DEV" exec-out screencap -p > "$OUT/evidence_android_final.png" 2>/dev/null || true
screencapture -x "$OUT/evidence_mac_desktop.png" 2>/dev/null || true
PGRESULT=$(PGPASSWORD=$PG_PASS psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DB -t -A -c \
  "SELECT count(*) FILTER (WHERE payload::text LIKE '%h2c2g-%'), count(*) FROM msg_c2g WHERE payload::text LIKE '%h2c2g-%' OR created_at > now() - interval '20 min';" 2>&1)
log "后端 msg_c2g 密文断言(明文命中, 近20min行数): $PGRESULT"

# 6. 汇总
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
doc = {
  "run_marker": f"h2c2g-{tag}", "gid": gid,
  "a_side_pass": a == 0 and grab("a_side.log", "A 侧 m3 已发送并回显"),
  "b_side_pass": b == 0 and grab("b_side.log", "B 侧 PASS"),
  "new_member_pass": nm == 0 and grab("new_member.log", "[H2-C2G-NEW] PASS"),
  "backend_cipher_check": pg.strip(),
  "exits": {"a": a, "b": b, "new_member": nm},
}
doc["overall"] = all(doc[k] for k in ("a_side_pass","b_side_pass","new_member_pass"))
print(json.dumps(doc, ensure_ascii=False, indent=2))
PY
cat "$OUT/evidence.json"
grep -q '"overall": true' "$OUT/evidence.json"
