#!/usr/bin/env bash

# 串行执行 test/demo_flow 中的 Claude Code 流程计划。
# 默认只执行 P0、使用 deepseek-v4-flash：
# DEMO_FLOW_SCOPE=p1 DEMO_FLOW_MODEL=<model> bash scripts/run_demo_flows.sh

set -u
set -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

DEMO_FLOW_MODEL="${DEMO_FLOW_MODEL:-deepseek-v4-flash}"

if ! command -v claude >/dev/null 2>&1; then
  printf '错误：找不到 claude CLI\n' >&2
  exit 127
fi

P0_FLOWS=(
  account_flow
  friend_flow
  conversation_flow
  single_chat_flow
  channel_flow
  group_creation_flow
  group_chat_flow
  group_management_flow
  group_collaboration_flow
  e2ee_security_flow
)

P1_FLOWS=(
  channel_creator_flow
  paid_channel_flow
  group_content_flow
  group_organization_flow
  moments_flow
  wallet_flow
  red_packet_flow
  contact_management_flow
  qrcode_invite_flow
  call_flow
  live_room_flow
)

case "${DEMO_FLOW_SCOPE:-p0}" in
  p0) FLOWS=("${P0_FLOWS[@]}") ;;
  p1) FLOWS=("${P1_FLOWS[@]}") ;;
  all) FLOWS=("${P0_FLOWS[@]}" "${P1_FLOWS[@]}") ;;
  *)
    printf '错误：DEMO_FLOW_SCOPE 只能是 p0、p1 或 all\n' >&2
    exit 2
    ;;
esac

ALLOWED_TOOLS=(
  Read Write Edit Glob Grep
  "Bash(pwd)"
  "Bash(rg *)"
  "Bash(mkdir *)"
  "Bash(flutter test *)"
  "Bash(dart test *)"
  "Bash(git status *)"
  "Bash(git diff *)"
)

FAILED=0
BASELINE_STATUS_FILE="$(mktemp -t imboy-demo-flow-status.XXXXXX)"
BASELINE_HASH_FILE="$(mktemp -t imboy-demo-flow-hash.XXXXXX)"
trap 'rm -f "$BASELINE_STATUS_FILE" "$BASELINE_HASH_FILE"' EXIT

snapshot_status() {
  git status --porcelain=v1 | sort
}

snapshot_tracked_hashes() {
  local path
  while IFS= read -r -d '' path; do
    if [ -f "$path" ]; then
      shasum -a 256 "$path"
    else
      printf 'MISSING  %s\n' "$path"
    fi
  done < <(git ls-files -z)
}

check_flow_paths() {
  local current_hash_file current_status_file new_paths path status_line
  local changed_hash_line
  current_status_file="$(mktemp -t imboy-demo-flow-status.XXXXXX)"
  current_hash_file="$(mktemp -t imboy-demo-flow-hash.XXXXXX)"
  snapshot_status > "$current_status_file"
  snapshot_tracked_hashes > "$current_hash_file"
  new_paths=0
  while IFS= read -r status_line; do
    [ -n "$status_line" ] || continue
    path="${status_line:3}"
    case "$path" in
      test/demo_flow/*|integration_test/demo_flow/*)
        ;;
      *)
        printf 'flow 修改越界，禁止路径：%s\n' "$path" >&2
        new_paths=1
        ;;
    esac
  done < <(comm -13 "$BASELINE_STATUS_FILE" "$current_status_file")
  while IFS= read -r changed_hash_line; do
    path="${changed_hash_line:1}"
    path="${path#*  }"
    case "$path" in
      test/demo_flow/*|integration_test/demo_flow/*)
        ;;
      *)
        printf 'flow 修改越界，禁止路径：%s\n' "$path" >&2
        new_paths=1
        ;;
    esac
  done < <(diff -u "$BASELINE_HASH_FILE" "$current_hash_file" | grep -E '^[+-][0-9a-f]+  ' || true)
  rm -f "$current_status_file"
  rm -f "$current_hash_file"
  return "$new_paths"
}

for flow in "${FLOWS[@]}"; do
  printf '\n开始执行 test/demo_flow/%s.md\n' "$flow"
  snapshot_status > "$BASELINE_STATUS_FILE"
  snapshot_tracked_hashes > "$BASELINE_HASH_FILE"
  prompt=$(cat <<EOF
你现在只执行一个业务流程：test/demo_flow/${flow}.md。

先读取 test/demo_flow/README.md、test/demo_flow/P0_EXECUTION_PLAN.md 和目标 flow 文档，严格按其中的 TODO、前置条件、验收标准和停止条件执行。

本轮规则：
1. 只处理这个 flow；完成、失败或阻塞后就退出，不进入其他 flow。
2. 优先复用现有 integration_test；只有确有必要才新增 integration_test/demo_flow/ 下的测试。
3. 允许修改 test/demo_flow/ 和 integration_test/demo_flow/；禁止修改 lib/ 和 test/auto_test/，禁止 commit、push。
4. 缺少测试环境、账号、设备、授权或服务端证据时，把目标 flow 回写为阻塞并说明原因，不得猜测通过。
5. 禁止联系真实第三方、操作生产数据、充值、转账、红包、付费购买、删除群/动态、清空数据或导入/恢复真实 E2EE 密钥。
6. 每个写操作必须有服务端成功证据；单端 UI 变化不能作为闭环证据。
7. 结束前运行 git diff --check，报告通过、失败、跳过、阻塞和新增文件。
EOF
  )

  if ! claude \
    --model "$DEMO_FLOW_MODEL" \
    --permission-mode acceptEdits \
    --allowed-tools "${ALLOWED_TOOLS[@]}" \
    -p "$prompt"; then
    FAILED=1
    printf 'flow 退出异常，继续下一个：%s\n' "$flow" >&2
  fi
  if ! check_flow_paths; then
    FAILED=1
    printf 'flow 发生越界修改，请人工检查后再继续：%s\n' "$flow" >&2
  fi
done

exit "$FAILED"
