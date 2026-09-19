#!/usr/bin/env bash
# hardening2 P2 · Workspace/Group 多角色正负路径 + 跨租户 IDOR 拒绝矩阵（API 证据）。
# 前置：后端以 IMBOY_PRODUCT_EXPERIENCE=workspace 启动；h2_seed_p2.sh 已铺 org/workspace。
set -uo pipefail

API=http://127.0.0.1:9800
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
RUN_ROOT="$PROJ/test/auto_test/reports/hardening2-20260918T211458Z"
OUT="$RUN_ROOT/steps/p2_matrix"
mkdir -p "$OUT"
CRED="$PROJ/test/auto_test/credentials.local.json"

read_cred() { python3 -c "import json;print(json.load(open('$CRED'))['$1'])"; }
acc() { python3 -c "import json;print(json.load(open('$CRED'))['accounts']['$1']['$2'])"; }
PW="$(read_cred test_password)"
A1="$(acc orgA_owner acc)"; A2="$(acc orgA_admin acc)"; A3="$(acc orgA_member acc)"
A4="$(acc orgA_nonmember acc)"; B5="$(acc orgB_owner acc)"; B6="$(acc orgB_member acc)"
A4_UID="$(acc orgA_nonmember uid)"; A3_UID="$(acc orgA_member uid)"; B6_UID="$(acc orgB_member uid)"

FIX="$RUN_ROOT/steps/p2_fixture/fixture.json"
[ -f "$FIX" ] || { echo "fixture.json 不存在，先跑 h2_seed_p2.sh"; exit 2; }
ORG_A=$(python3 -c "import json;print(json.load(open('$FIX'))['org_a']['id'])")
ORG_B=$(python3 -c "import json;print(json.load(open('$FIX'))['org_b']['id'])")

login() {
  curl -s -X POST "$API/api/v1/passport/login" -H 'Content-Type: application/json' \
    -d "{\"account\":\"$1\",\"pwd\":\"$PW\",\"type\":\"mobile\",\"rsa_encrypt\":\"0\"}" \
    | python3 -c "import sys,json; p=json.load(sys.stdin)['payload']; print(p.get('token') or p.get('access_token',''))"
}

T_A1=$(login $A1); T_A2=$(login $A2); T_A3=$(login $A3)
T_A4=$(login $A4); T_B5=$(login $B5); T_B6=$(login $B6)
for t in T_A1 T_A2 T_A3 T_A4 T_B5 T_B6; do
  [ -n "${!t}" ] || { echo "$t 登录失败"; exit 2; }
done

# req <label> <expect:200|expect:4xx> <token> <method> <path> [json]
RESULTS="$OUT/matrix.tsv"
: > "$RESULTS"
PASS_N=0; FAIL_N=0
req() {
  local label="$1" expect="$2" tok="$3" method="$4" path="$5" body="${6:-}"
  local args=(-s -o /tmp/h2_resp.json -w '%{http_code}' -X "$method" "$API$path" -H "Authorization: Bearer $tok")
  [ -n "$body" ] && args+=(-H 'Content-Type: application/json' -d "$body")
  local code; code=$(curl "${args[@]}")
  local bcode; bcode=$(python3 -c "import json;print(json.load(open('/tmp/h2_resp.json')).get('code',''))" 2>/dev/null || echo '')
  # imboy 业务错误一律 HTTP 200 + envelope code（elib_response.erl:197-198）：
  # 判定必须双看 HTTP 码与 body.code；code=1 为限流，sleep 重试一次（A6b 甄别）。
  if [ "$expect" = "200" ] && [ "$code" = "200" ] && [ "$bcode" = "1" ]; then
    sleep 4
    code=$(curl "${args[@]}")
    bcode=$(python3 -c "import json;print(json.load(open('/tmp/h2_resp.json')).get('code',''))" 2>/dev/null || echo '')
  fi
  local ok denied
  if [ "$expect" = "200" ]; then
    ok=$([ "$code" = "200" ] && [ "$bcode" = "0" ] && echo 1 || echo 0)
  else
    denied=0
    if [ "$code" -ge 400 ] 2>/dev/null && [ "$code" -lt 500 ] 2>/dev/null; then denied=1; fi
    case "$bcode" in 400|401|403|404|405|409|422) denied=1;; esac
    ok=$denied
  fi
  if [ "$ok" = "1" ]; then PASS_N=$((PASS_N+1)); else FAIL_N=$((FAIL_N+1)); fi
  printf '%s\t%s\t%s\t%s\tcode=%s\n' "$code" "$expect" "$ok" "$label" "$bcode" >> "$RESULTS"
  printf '[%s] %s expect=%s got=%s code=%s\n' "$([ $ok = 1 ] && echo PASS || echo FAIL)" "$label" "$expect" "$code" "$bcode"
}

echo "=== 正路径 ==="
req "owner 读 org_a 详情" 200 "$T_A1" GET "/api/v1/organizations/$ORG_A"
req "member 读 org_a 详情" 200 "$T_A3" GET "/api/v1/organizations/$ORG_A"
req "owner 列 org_a 成员" 200 "$T_A1" GET "/api/v1/organizations/$ORG_A/members"
req "orgB owner 读 org_b 详情" 200 "$T_B5" GET "/api/v1/organizations/$ORG_B"

echo "=== 治理负路径（权限边界）==="
req "member 建 workspace 应拒" 4xx "$T_A3" POST "/api/v1/workspaces" "{\"name\":\"h2-deny-ws\",\"organization_id\":$ORG_A}"
req "member 提升角色应拒" 4xx "$T_A3" PUT "/api/v1/organizations/$ORG_A/members/$A3_UID/role" '{"role":"admin"}'
req "admin 转 owner 应拒" 4xx "$T_A2" POST "/api/v1/organizations/$ORG_A/members/transfer_owner" "{\"user_id\":$(acc orgA_admin uid)}"
req "member suspend 他人应拒" 4xx "$T_A3" POST "/api/v1/organizations/$ORG_A/members/$B6_UID/suspend" '{}'

echo "=== 跨租户 IDOR 拒绝 ==="
req "orgB owner 读 org_a 应拒(IDOR)" 4xx "$T_B5" GET "/api/v1/organizations/$ORG_A"
req "orgB member 读 org_a 成员应拒(IDOR)" 4xx "$T_B6" GET "/api/v1/organizations/$ORG_A/members"
req "orgB owner 邀 orgA member 入 org_b（跨组织邀请设计允许）" 200 "$T_B5" POST "/api/v1/organizations/$ORG_B/invitations" "{\"user_id\":$A3_UID}"
req "非成员(nonmember)读 org_a 应拒" 4xx "$T_A4" GET "/api/v1/organizations/$ORG_A"
req "非成员(nonmember)列 org_a 成员应拒" 4xx "$T_A4" GET "/api/v1/organizations/$ORG_A/members"

echo "=== owner 正向治理（写路径）==="
req "owner 提升 A3 为 admin" 200 "$T_A1" PUT "/api/v1/organizations/$ORG_A/members/$A3_UID/role" '{"role":"admin"}'
req "owner 建 workspace" 200 "$T_A1" POST "/api/v1/workspaces" "{\"name\":\"h2-ok-ws\",\"organization_id\":$ORG_A}"
req "owner suspend B6(org_b member 对 org_a 无关，负例改用 org 内)" 4xx "$T_A1" POST "/api/v1/organizations/$ORG_A/members/$B6_UID/suspend" '{}'

echo "SUMMARY: PASS=$PASS_N FAIL=$FAIL_N"
python3 - "$OUT" "$PASS_N" "$FAIL_N" <<'PY' > "$OUT/evidence.json"
import json, sys
out, p, f = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
rows = [l.split('\t') for l in open(f"{out}/matrix.tsv").read().splitlines() if l]
print(json.dumps({
  "pass": p, "fail": f,
  "checks": [{"code": r[0], "expect": r[1], "ok": r[2] == "1", "label": r[3]} for r in rows],
  "overall": f == 0 and p >= 15,
}, ensure_ascii=False, indent=1))
PY
cat "$OUT/evidence.json" | tail -8
[ "$FAIL_N" = 0 ]
