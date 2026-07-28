#!/usr/bin/env bash
# run_maestro_macos_tests.sh — 批量运行 Maestro macOS 桌面端自动化测试流
#
# 用法：
#   bash scripts/run_maestro_macos_tests.sh

set -uo pipefail

APP_ID="${APP_ID:-pub.imboy.macos}"
PHONE="${PHONE:-118@imboy.pub}"
PASSWORD="${PASSWORD:-admin888}"
FRIEND_ACCOUNT="${FRIEND_ACCOUNT:-}"

if [[ -z "$FRIEND_ACCOUNT" ]]; then
  echo "缺少 FRIEND_ACCOUNT：10、11、22 号 Flow 需要已确认的测试好友账号。"
  echo "示例：FRIEND_ACCOUNT=test_friend_account bash scripts/run_maestro_macos_tests.sh"
  exit 2
fi

echo "=== 开始运行 Maestro macOS 桌面端自动化测试 ==="
echo "APP_ID: $APP_ID  账号: $PHONE"
echo ""

FLOWS=(
  "maestro/00_startup.yaml"
  "maestro/01_login.yaml"
  "maestro/02_tab_navigation.yaml"
  "maestro/03_conversation.yaml"
  "maestro/04_send_message.yaml"
  "maestro/05_contacts.yaml"
  "maestro/06_channel.yaml"
  "maestro/07_profile.yaml"
  "maestro/10_e2ee_c2c.yaml"
  "maestro/11_e2ee_group.yaml"
  "maestro/12_moments_post.yaml"
  "maestro/13_channel_post.yaml"
  "maestro/14_face_to_face.yaml"
  "maestro/15_mine_navigation.yaml"
  "maestro/16_settings_navigation.yaml"
  "maestro/17_contact_discovery.yaml"
  "maestro/18_profile_privacy_qrcode.yaml"
  "maestro/19_message_search.yaml"
  "maestro/20_e2ee_local_backup.yaml"
  "maestro/21_channel_discovery.yaml"
  "maestro/22_chat_settings.yaml"
  "maestro/23_conversation_quick_actions.yaml"
  "maestro/24_wallet_overview.yaml"
  "maestro/25_account_security_forms.yaml"
  "maestro/26_storage_device_details.yaml"
  "maestro/27_favorites_search_filter.yaml"
  "maestro/28_group_list_search.yaml"
  "maestro/29_moment_notifications.yaml"
  "maestro/30_contact_tag_search.yaml"
  "maestro/31_logout_account_preview.yaml"
  "maestro/32_personal_info_forms.yaml"
  "maestro/33_appearance_options.yaml"
  "maestro/34_friend_search_forms.yaml"
  "maestro/35_feedback_history.yaml"
  "maestro/36_assistant_plaza_search.yaml"
  "maestro/37_group_launch_preview.yaml"
  "maestro/38_channel_auxiliary_lists.yaml"
  "maestro/39_recently_registered_users.yaml"
  "maestro/40_device_rename_form.yaml"
  "maestro/41_feedback_editor_preview.yaml"
  "maestro/42_channel_create_form.yaml"
  "maestro/43_message_search_filter_states.yaml"
  "maestro/44_group_role_filter_states.yaml"
  "maestro/45_favorites_type_filter_states.yaml"
  "maestro/46_new_friend_request_states.yaml"
  "maestro/47_people_nearby_read_only.yaml"
  "maestro/48_scanner_entry_read_only.yaml"
  "maestro/08_logout.yaml"
  "maestro/49_auth_entry_forms.yaml"
  "maestro/50_login_method_validation.yaml"
  "maestro/51_account_binding_validation.yaml"
)

PASS_COUNT=0
FAIL_COUNT=0

for flow in "${FLOWS[@]}"; do
  if [ -f "$flow" ]; then
    echo ">>> 正在执行 Flow: $flow ..."
    maestro test "$flow" \
      -e APP_ID="$APP_ID" \
      -e PHONE="$PHONE" \
      -e PASSWORD="$PASSWORD" \
      -e FRIEND_ACCOUNT="$FRIEND_ACCOUNT"

    if [ $? -eq 0 ]; then
      echo "✅ [PASS] $flow"
      PASS_COUNT=$((PASS_COUNT + 1))
    else
      echo "❌ [FAIL] $flow"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    echo ""
  fi
done

echo "=== Maestro macOS 测试结果汇总 ==="
echo "成功: $PASS_COUNT  失败: $FAIL_COUNT"
