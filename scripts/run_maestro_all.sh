#!/usr/bin/env bash
# run_maestro_all.sh — Maestro 逐个跑所有 flow（不重新安装 APK，只操作已安装的 app）
#
# 用法：
#   bash scripts/run_maestro_all.sh
#
# 配置（.env.pro.android）：
#   APP_ID=imboy.chat  PHONE=118@imboy.pub  PASSWORD=admin888

set -uo pipefail

cd "$(dirname "$0")/.."

APP_ID="imboy.chat"
PHONE="118@imboy.pub"
PASSWORD="admin888"
FRIEND="108@imboy.pub"

RESULTS_FILE="/tmp/imboy_maestro_results.log"
echo "=== ImBoy Maestro 全量测试 $(date '+%Y-%m-%d %H:%M:%S') ===" > "$RESULTS_FILE"
echo "设备: XWE6R19916004085  APP_ID: $APP_ID  账号: $PHONE" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# flow 顺序（08_logout 放最后，避免退出后影响后续）
FLOWS=(
  "00_startup.yaml|App 启动冒烟"
  "01_login.yaml|登录流程"
  "02_tab_navigation.yaml|Tab 切换"
  "03_conversation.yaml|会话列表+搜索"
  "04_send_message.yaml|发送消息"
  "05_contacts.yaml|联系人"
  "06_channel.yaml|频道"
  "07_profile.yaml|我的页面"
  "10_e2ee_c2c.yaml|C2C 端到端加密"
  "11_e2ee_group.yaml|群端到端加密"
  "12_moments_post.yaml|朋友圈发布"
  "13_channel_post.yaml|频道发布"
  "14_face_to_face.yaml|面对面加好友"
  "15_mine_navigation.yaml|我的页核心入口"
  "16_settings_navigation.yaml|设置与安全入口"
  "17_contact_discovery.yaml|联系人发现入口"
  "18_profile_privacy_qrcode.yaml|个人资料隐私与二维码"
  "19_message_search.yaml|全局消息搜索"
  "20_e2ee_local_backup.yaml|E2EE 本地备份入口"
  "21_channel_discovery.yaml|频道列表与发现"
  "22_chat_settings.yaml|单聊设置与记录搜索"
  "23_conversation_quick_actions.yaml|会话页快捷入口"
  "24_wallet_overview.yaml|钱包概览"
  "25_account_security_forms.yaml|账号绑定表单预览"
  "26_storage_device_details.yaml|存储与登录设备详情"
  "27_favorites_search_filter.yaml|收藏搜索与类型筛选"
  "28_group_list_search.yaml|群聊列表搜索与角色筛选"
  "29_moment_notifications.yaml|朋友圈消息通知"
  "30_contact_tag_search.yaml|联系人标签搜索"
  "31_logout_account_preview.yaml|注销账号安全预览"
  "32_personal_info_forms.yaml|个人资料编辑页预览"
  "33_appearance_options.yaml|语言深色模式与字体预览"
  "34_friend_search_forms.yaml|新好友与添加好友搜索表单"
  "35_feedback_history.yaml|反馈入口与历史状态"
  "36_assistant_plaza_search.yaml|AI 助手广场搜索"
  "37_group_launch_preview.yaml|发起群聊与群选择预览"
  "38_channel_auxiliary_lists.yaml|频道订单与邀请列表"
  "39_recently_registered_users.yaml|最近注册用户列表"
  "40_device_rename_form.yaml|当前设备名称表单"
  "41_feedback_editor_preview.yaml|反馈编辑器预览"
  "42_channel_create_form.yaml|频道创建表单"
  "43_message_search_filter_states.yaml|消息搜索筛选交互"
  "44_group_role_filter_states.yaml|群聊角色筛选交互"
  "45_favorites_type_filter_states.yaml|收藏类型筛选交互"
  "46_new_friend_request_states.yaml|新好友申请状态"
  "47_people_nearby_read_only.yaml|附近的人页面只读验收"
  "48_scanner_entry_read_only.yaml|扫描二维码页面只读验收"
  "08_logout.yaml|退出登录"
  "49_auth_entry_forms.yaml|未登录认证入口与表单预览"
  "50_login_method_validation.yaml|登录方式切换与空表单校验"
  "51_account_binding_validation.yaml|账号绑定表单本地校验"
)

TOTAL=${#FLOWS[@]}
PASS_COUNT=0
FAIL_COUNT=0
IDX=0

for entry in "${FLOWS[@]}"; do
  IDX=$((IDX + 1))
  FILE="${entry%%|*}"
  NAME="${entry##*|}"

  echo "========== [$IDX/$TOTAL] $NAME ($FILE) =========="
  echo ">>> 开始: $(date '+%H:%M:%S')"

  START=$(date +%s)

  OUTPUT=$(maestro test "maestro/$FILE" \
    -e APP_ID="$APP_ID" \
    -e PHONE="$PHONE" \
    -e PASSWORD="$PASSWORD" \
    -e FRIEND_ACCOUNT="$FRIEND" \
    2>&1)

  EXIT_CODE=$?
  END=$(date +%s)
  DURATION=$((END - START))

  # Maestro 成功时 exit 0，失败时非 0
  if [[ $EXIT_CODE -eq 0 ]]; then
    STATUS="PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    STATUS="FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi

  echo ">>> 结果: $STATUS  耗时: ${DURATION}s  exit: $EXIT_CODE"
  echo ""

  # 记录到结果文件
  echo "[$IDX/$TOTAL] $NAME ($FILE)" >> "$RESULTS_FILE"
  echo "  状态: $STATUS  耗时: ${DURATION}s  exit: $EXIT_CODE" >> "$RESULTS_FILE"
  if [[ "$STATUS" == "FAIL" ]]; then
    echo "  --- 错误摘要（最后 10 行）---" >> "$RESULTS_FILE"
    echo "$OUTPUT" | tail -10 | sed 's/^/  /' >> "$RESULTS_FILE"
  fi
  echo "" >> "$RESULTS_FILE"

done

echo "========== 汇总 =========="
echo "总计: $TOTAL  通过: $PASS_COUNT  失败: $FAIL_COUNT"
echo ""
echo "========== 汇总 ==========" >> "$RESULTS_FILE"
echo "总计: $TOTAL  通过: $PASS_COUNT  失败: $FAIL_COUNT" >> "$RESULTS_FILE"
echo "完成时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$RESULTS_FILE"
echo ""
echo "详细结果: $RESULTS_FILE"
