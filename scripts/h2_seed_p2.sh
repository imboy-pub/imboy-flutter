#!/usr/bin/env bash
# hardening2 P2 · 组织/workspace 铺底（A6 账号之上建 org_a/org_b + workspace + 角色）。
# 前置：后端已以 IMBOY_PRODUCT_EXPERIENCE=workspace 启动。
# 幂等：重复执行会新建同名 org（org 名不唯一约束）——故先查已有。
set -uo pipefail

API=http://127.0.0.1:9800
RUN_ROOT="$(cd "$(dirname "$0")/.." && pwd)/test/auto_test/reports/hardening2-20260918T211458Z"
OUT="$RUN_ROOT/steps/p2_fixture"
mkdir -p "$OUT"
TAG="$(date -u +%H%M%S)"
A1="$(acc orgA_owner acc)"; A1_UID="$(acc orgA_owner uid)"
A2="$(acc orgA_admin acc)"; A2_UID="$(acc orgA_admin uid)"
A3="$(acc orgA_member acc)"; A3_UID="$(acc orgA_member uid)"
B5="$(acc orgB_owner acc)"; B5_UID="$(acc orgB_owner uid)"
B6="$(acc orgB_member acc)"; B6_UID="$(acc orgB_member uid)"
# 凭证与 fixture 账号从 gitignored 本地文件读取（fixture 合同：tracked 禁明文）
CRED="$PROJ/test/auto_test/credentials.local.json"
read_cred() { python3 -c "import json;print(json.load(open('$CRED'))['$1'])"; }
acc() { python3 -c "import json;print(json.load(open('$CRED'))['accounts']['$1']['$2'])"; }
PW="$(read_cred test_password)"
KEY_VAL="$(read_cred solidified_key)"; IV_VAL="$(read_cred solidified_key_iv)"
A_ACC="$(acc orgA_owner acc)"; A_UID="$(acc orgA_owner uid)"
B_ACC="$(acc orgA_member acc)"; B_UID="$(acc orgA_member uid)"
PW="$TEST_PASSWORD"


log() { printf '[H2-P2-SEED] %s\n' "$*"; }

login() {
  curl -s -X POST "$API/api/v1/passport/login" -H 'Content-Type: application/json' \
    -d "{\"account\":\"$1\",\"pwd\":\"$PW\",\"type\":\"mobile\",\"rsa_encrypt\":\"0\"}" \
    | python3 -c "import sys,json; p=json.load(sys.stdin)['payload']; print(p.get('token') or p.get('access_token',''))"
}

# create_org <token> <name> -> org_id（若同名已存在则复用 mine 列表里的）
create_org() {
  local tok="$1" name="$2"
  local existing
  existing=$(curl -s "$API/api/v1/organizations/mine" -H "Authorization: Bearer $tok" \
    | python3 -c "
import sys,json
d=json.load(sys.stdin)
items=d.get('payload',{}).get('organizations') or d.get('payload',{}).get('items') or []
items=items if isinstance(items,list) else []
for o in items:
    if o.get('name')=='$name': print(o.get('id')); break
" 2>/dev/null)
  if [ -n "$existing" ]; then echo "$existing"; return; fi
  curl -s -X POST "$API/api/v1/organizations" -H "Authorization: Bearer $tok" -H 'Content-Type: application/json' \
    -d "{\"name\":\"$name\"}" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['payload'].get('id','') if d.get('code')==0 else '')"
}

# invite_and_accept <org> <inviter_tok> <invitee_uid> <invitee_acc>
invite_and_accept() {
  local org="$1" itok="$2" iuid="$3" iacc="$4"
  local inv tok
  inv=$(curl -s -X POST "$API/api/v1/organizations/$org/invitations" \
    -H "Authorization: Bearer $itok" -H 'Content-Type: application/json' \
    -d "{\"user_id\":$iuid}")
  tok=$(echo "$inv" | python3 -c "
import sys,json
d=json.load(sys.stdin)
p=d.get('payload',{})
print(p.get('token') or p.get('invitation',{}).get('token') or '')" 2>/dev/null)
  if [ -z "$tok" ]; then
    log "邀请 $iacc 失败: $(echo "$inv" | head -c 200)"
    return 1
  fi
  local etok; etok=$(login "$iacc")
  local acc
  acc=$(curl -s -X POST "$API/api/v1/organizations/$org/invitations/accept" \
    -H "Authorization: Bearer $etok" -H 'Content-Type: application/json' \
    -d "{\"token\":\"$tok\"}")
  echo "$acc" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('code')==0 else 1)" \
    && log "成员 $iacc 已入组 $org" || log "accept 失败: $(echo "$acc" | head -c 150)"
}

# promote <org> <owner_tok> <uid> <role>
promote() {
  curl -s -X POST "$API/api/v1/organizations/$1/members/$3/role" \
    -H "Authorization: Bearer $2" -H 'Content-Type: application/json' \
    -d "{\"role\":\"$4\"}" | head -c 120; echo
}

# create_ws <token> <org> <name> -> ws_id
create_ws() {
  curl -s -X POST "$API/api/v1/workspaces" -H "Authorization: Bearer $1" -H 'Content-Type: application/json' \
    -d "{\"name\":\"$3\",\"organization_id\":$2}" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); p=d.get('payload',{}); print(p.get('workspace_id') or p.get('id','') if d.get('code')==0 else '')"
}

T_A1=$(login $A1); [ -n "$T_A1" ] || { log "A1 登录失败"; exit 2; }
T_B5=$(login $B5); [ -n "$T_B5" ] || { log "B5 登录失败"; exit 2; }

ORG_A=$(create_org "$T_A1" "h2-org-a")
[ -n "$ORG_A" ] || { log "org_a 创建失败"; exit 2; }
log "org_a=$ORG_A"
invite_and_accept "$ORG_A" "$T_A1" "$A2_UID" "$A2" || true
invite_and_accept "$ORG_A" "$T_A1" "$A3_UID" "$A3" || true
log "提升 A2 为 admin:"; promote "$ORG_A" "$T_A1" "$A2_UID" "admin"
WS_A1=$(create_ws "$T_A1" "$ORG_A" "h2-ws-a1"); log "ws_a1=$WS_A1"
WS_A2=$(create_ws "$T_A1" "$ORG_A" "h2-ws-a2"); log "ws_a2=$WS_A2"

ORG_B=$(create_org "$T_B5" "h2-org-b")
[ -n "$ORG_B" ] || { log "org_b 创建失败"; exit 2; }
log "org_b=$ORG_B"
invite_and_accept "$ORG_B" "$T_B5" "$B6_UID" "$B6" || true
WS_B1=$(create_ws "$T_B5" "$ORG_B" "h2-ws-b1"); log "ws_b1=$WS_B1"

cat > "$OUT/fixture.json" <<EOF
{
  "seeded_at_utc": "$(date -u +%FT%TZ)",
  "org_a": {"id": "$ORG_A", "owner": "$A1_UID", "admin": "$A2_UID", "member": "$A3_UID"},
  "org_b": {"id": "$ORG_B", "owner": "$B5_UID", "member": "$B6_UID"},
  "workspaces": {"a1": "$WS_A1", "a2": "$WS_A2", "b1": "$WS_B1"}
}
EOF
log "fixture 写入 $OUT/fixture.json"
cat "$OUT/fixture.json"
