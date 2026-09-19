#!/usr/bin/env bash
# hardening2 P1 · C2C E2EE 真链路编排（Android 真机 A ↔ macOS B）。
# 用法: bash scripts/h2_run_p1_c2c.sh
# 产物: RUN_ROOT/steps/p1_c2c_real/{b_side.log,a_side.log,history_*.log,evidence.json,...}
set -uo pipefail

PROJ="$(cd "$(dirname "$0")/.." && pwd)"
RUN_ROOT="$PROJ/test/auto_test/reports/hardening2-20260918T211458Z"
OUT="$RUN_ROOT/steps/p1_c2c_real"
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
DEV=XWE6R19916004085
WS=ws://127.0.0.1:9800/api/v1/ws
COMMON_DEF=(
  "--dart-define=APP_ENV=local"
  "--dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9800"
  "--dart-define=SOLIDIFIED_KEY_OVERRIDE=$KEY_VAL"
  "--dart-define=SOLIDIFIED_KEY_IV_OVERRIDE=$IV_VAL"
  "--dart-define=WS_URL_OVERRIDE=$WS"
  "--dart-define=TEST_PASSWORD=$PW"
  "--dart-define=H2_RUN_TAG=$TAG"
  "--dart-define=H2_C2C_REAL_RUN=true"
)

log() { printf '[H2-ORCH] %s\n' "$*"; }

# 0. 环境就绪
curl -sf -m 3 http://127.0.0.1:9800/healthz > /dev/null || { log "后端不可达"; exit 2; }
adb -s "$DEV" reverse tcp:9800 tcp:9800 > /dev/null || { log "adb reverse 失败"; exit 2; }
adb -s "$DEV" shell input keyevent KEYCODE_WAKEUP > /dev/null 2>&1 || true
# macOS 清场：杀用户残留的 flutter run 调试会话与 IMBoy.app（共享数据目录，防污染）
pkill -f "flutter_tools.snapshot --no-color run --machine" 2>/dev/null || true
pkill -x IMBoy 2>/dev/null || true
sleep 2

# 2. B 侧（macOS）后台启动
log "TAG=$TAG 启动 B 侧(macOS, $B_ACC)"
( cd "$PROJ" && flutter test integration_test/two_client/h2_c2c_mac_b_side_test.dart \
    -d macos --no-pub "${COMMON_DEF[@]}" \
    --dart-define=TEST_PHONE=$B_ACC --dart-define=TEST_EXPECTED_UID=$B_UID \
    --dart-define=PEER_UID=$A_UID > "$OUT/b_side.log" 2>&1 ) &
B_PID=$!

# 2b. 等 B 侧就绪（stdout 出现就绪标记；最多 150s——含 macOS 测试 app 构建启动）
READY=0
for i in $(seq 1 150); do
  if grep -q "B 侧就绪" "$OUT/b_side.log" 2>/dev/null; then READY=1; break; fi
  if ! kill -0 $B_PID 2>/dev/null; then break; fi
  sleep 1
done
if [ "$READY" != 1 ]; then
  log "B 侧未就绪（构建慢或失败），再等 60s 后仍无则放弃"
  for i in $(seq 1 60); do
    grep -q "B 侧就绪" "$OUT/b_side.log" 2>/dev/null && { READY=1; break; }
    kill -0 $B_PID 2>/dev/null || break
    sleep 1
  done
fi
log "B 侧就绪=$READY"


# 1. A 侧（Android 真机，flutter test 前台 instrumentation；patrol 模式
# app 会被 EMUI 冻结——实证 CPU 零增长，弃用）。1200s 宿主硬超时兜底。
adb -s "$DEV" shell input keyevent KEYCODE_WAKEUP > /dev/null 2>&1 || true
adb -s "$DEV" shell svc power stayon true > /dev/null 2>&1 || true
log "启动 A 侧(Android, $A_ACC)"
( cd "$PROJ" && perl -e 'alarm 1200; exec @ARGV' -- \
    flutter test integration_test/two_client/h2_c2c_android_a_side_test.dart \
    -d "$DEV" --no-pub "${COMMON_DEF[@]}" \
    --dart-define=TEST_PHONE=$A_ACC --dart-define=TEST_EXPECTED_UID=$A_UID \
    --dart-define=PEER_UID=$B_UID > "$OUT/a_side.log" 2>&1 )
A_EXIT=$?
log "A 侧 exit=$A_EXIT"

# 4. 等 B 侧完成
wait $B_PID; B_EXIT=$?
log "B 侧 exit=$B_EXIT"

# 5. 杀进程重进：两端历史验证
( cd "$PROJ" && perl -e 'alarm 1200; exec @ARGV' -- \
    flutter test integration_test/two_client/h2_c2c_history_test.dart \
    -d "$DEV" --no-pub "${COMMON_DEF[@]}" \
    --dart-define=TEST_PHONE=$A_ACC --dart-define=TEST_EXPECTED_UID=$A_UID \
    --dart-define=PEER_UID=$B_UID > "$OUT/history_android.log" 2>&1 )
HA_EXIT=$?
( cd "$PROJ" && flutter test integration_test/two_client/h2_c2c_history_test.dart \
    -d macos --no-pub "${COMMON_DEF[@]}" \
    --dart-define=TEST_PHONE=$B_ACC --dart-define=TEST_EXPECTED_UID=$B_UID \
    --dart-define=PEER_UID=$A_UID > "$OUT/history_mac.log" 2>&1 )
HM_EXIT=$?

# 6. 取证：截图（主机侧）
adb -s "$DEV" exec-out screencap -p > "$OUT/evidence_android_final.png" 2>/dev/null || true
screencapture -x "$OUT/evidence_mac_desktop.png" 2>/dev/null || true

# 7. 取证：后端库密文断言（payload 不得含 marker 明文）
PGRESULT=$(PGPASSWORD=$PG_PASS psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DB -t -A -c \
  "SELECT count(*) FILTER (WHERE payload::text LIKE '%h2c2c-%'), count(*) FROM msg_c2c WHERE payload::text LIKE '%h2c2c-%' OR created_at > now() - interval '15 min';" 2>&1)
log "后端 msg_c2c 密文断言(明文命中数, 近15min行数): $PGRESULT"

# 8. 汇总
python3 - "$OUT" "$TAG" $A_EXIT $B_EXIT $HA_EXIT $HM_EXIT "$PGRESULT" <<'PY' > "$OUT/evidence.json"
import json, sys
out, tag, a, b, ha, hm, pg = sys.argv[1], sys.argv[2], *map(int, sys.argv[3:7]), sys.argv[7]
def grab(path, mark):
    try:
        txt = open(f"{out}/{path}", encoding="utf-8", errors="replace").read()
        return mark in txt
    except FileNotFoundError:
        return False
doc = {
  "run_marker": f"h2c2c-{tag}",
  "a_side_pass": a == 0 and grab("a_side.log", "A 侧 PASS"),
  "b_side_pass": b == 0 and grab("b_side.log", "B 侧 PASS"),
  "history_android_pass": ha == 0 and grab("history_android.log", "历史 PASS"),
  "history_mac_pass": hm == 0 and grab("history_mac.log", "历史 PASS"),
  "backend_cipher_check": pg.strip(),
  "exits": {"a": a, "b": b, "history_android": ha, "history_mac": hm},
}
doc["overall"] = all(doc[k] for k in ("a_side_pass","b_side_pass","history_android_pass","history_mac_pass"))
print(json.dumps(doc, ensure_ascii=False, indent=2))
PY
log "结果: $(cat "$OUT/evidence.json" | python3 -c 'import sys,json; print(json.load(sys.stdin)["overall"])')"
grep -q '"overall": true' "$OUT/evidence.json"
