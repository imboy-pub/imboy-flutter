#!/usr/bin/env bash
# run_all_integration_tests.sh — 逐个跑所有 integration_test，收集结果
#
# 用法：
#   bash scripts/run_all_integration_tests.sh
#
# 输出：
#   - 实时进度到 stdout
#   - 汇总结果到 /tmp/imboy_test_results.log
#
# 配置（.env.pro）：
#   API_BASE_URL=https://pro.imboy.pub
#   TEST_PHONE=118@imboy.pub
#   TEST_PASSWORD=admin888
#   TEST_SEARCH_KEYWORD=108@imboy.pub（好友账号）

set -uo pipefail

DEVICE="${DEVICE:-XWE6R19916004085}"
API_URL="${API_URL:-https://pro.imboy.pub}"
PHONE="${PHONE:-118@imboy.pub}"
PASSWORD="${PASSWORD:-admin888}"
FRIEND="${FRIEND:-108@imboy.pub}"

RESULTS_FILE="/tmp/imboy_test_results.log"
echo "=== ImBoy 全量集成测试 $(date '+%Y-%m-%d %H:%M:%S') ===" > "$RESULTS_FILE"
echo "设备: $DEVICE  环境: $API_URL  账号: $PHONE" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# 测试清单（按功能模块排序）
TESTS=(
  "app_test.dart|App 基础流程"
  "e2e_chat_test.dart|C2C 端到端聊天"
  "chat/conversation_test.dart|会话列表+搜索"
  "chat/group_chat_test.dart|群聊"
  "contact/friend_management_test.dart|好友管理"
  "contact/add_friend_request_test.dart|添加好友"
  "channel/channel_e2e_test.dart|频道端到端"
  "channel/channel_publish_test.dart|频道发布"
  "channel/channel_edit_persistence_test.dart|频道编辑持久化"
  "channel/channel_subscribed_detail_consistency_test.dart|已订阅频道详情"
  "mine/mine_subpages_smoke_test.dart|我的子页面"
  "auth/register_flow_test.dart|注册流程"
  "auth/password_change_test.dart|密码修改"
  "sqlcipher_migration_test.dart|SQLCipher 迁移"
)

TOTAL=${#TESTS[@]}
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
IDX=0

for entry in "${TESTS[@]}"; do
  IDX=$((IDX + 1))
  FILE="${entry%%|*}"
  NAME="${entry##*|}"

  echo "========== [$IDX/$TOTAL] $NAME =========="
  echo ">>> 文件: integration_test/$FILE"
  echo ">>> 开始: $(date '+%H:%M:%S')"

  START=$(date +%s)

  # password_change 测试默认禁止改密码（生产环境保护）
  EXTRA_DART_DEFINE=""
  if [[ "$FILE" == "auth/password_change_test.dart" ]]; then
    EXTRA_DART_DEFINE="--dart-define=TEST_ALLOW_PASSWORD_CHANGE=false"
  fi

  OUTPUT=$(flutter test "integration_test/$FILE" \
    -d "$DEVICE" \
    --dart-define=API_BASE_URL="$API_URL" \
    --dart-define=TEST_PHONE="$PHONE" \
    --dart-define=TEST_PASSWORD="$PASSWORD" \
    --dart-define=TEST_SEARCH_KEYWORD="$FRIEND" \
    $EXTRA_DART_DEFINE \
    2>&1)

  EXIT_CODE=$?
  END=$(date +%s)
  DURATION=$((END - START))

  # 解析结果
  if echo "$OUTPUT" | grep -q "All tests passed"; then
    if echo "$OUTPUT" | grep -qE "\+0 .*All tests passed"; then
      STATUS="SKIP"
      SKIP_COUNT=$((SKIP_COUNT + 1))
    else
      STATUS="PASS"
      PASS_COUNT=$((PASS_COUNT + 1))
    fi
  elif echo "$OUTPUT" | grep -q "All tests skipped"; then
    STATUS="SKIP"
    SKIP_COUNT=$((SKIP_COUNT + 1))
  else
    STATUS="FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi

  # 提取测试计数（+N -M 格式）
  COUNTS=$(echo "$OUTPUT" | grep -oE '\+[0-9]+( -[0-9]+)?' | tail -1)

  echo ">>> 结果: $STATUS  耗时: ${DURATION}s  $COUNTS"
  echo ""

  # 记录到结果文件
  echo "[$IDX/$TOTAL] $NAME ($FILE)" >> "$RESULTS_FILE"
  echo "  状态: $STATUS  耗时: ${DURATION}s  $COUNTS  exit: $EXIT_CODE" >> "$RESULTS_FILE"
  if [[ "$STATUS" == "FAIL" ]]; then
    echo "  --- 错误摘要（最后 15 行）---" >> "$RESULTS_FILE"
    echo "$OUTPUT" | tail -15 | sed 's/^/  /' >> "$RESULTS_FILE"
  fi
  echo "" >> "$RESULTS_FILE"

done

echo "========== 汇总 =========="
echo "总计: $TOTAL  通过: $PASS_COUNT  失败: $FAIL_COUNT  跳过: $SKIP_COUNT"
echo ""
echo "========== 汇总 ==========" >> "$RESULTS_FILE"
echo "总计: $TOTAL  通过: $PASS_COUNT  失败: $FAIL_COUNT  跳过: $SKIP_COUNT" >> "$RESULTS_FILE"
echo "完成时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$RESULTS_FILE"

echo ""
echo "详细结果: $RESULTS_FILE"
