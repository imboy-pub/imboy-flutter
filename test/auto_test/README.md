# imboyapp 自动化测试计划 —— 索引

> **权威文档**。imboyapp 现有全部功能点（已完成 / 未完成 / 阻塞 全部纳入）。
> 覆盖 **137 个页面 / 1541 个功能点**
> 数据源：`lib/page/**` 真实源码抽取 ＋ 真机实测记录

> ⚠️ 本文件由 `regen_readme.py` 生成，**不要手改**。
> 每轮回写完各模块 md 后跑：`python3 test/auto_test/regen_readme.py`

## 目录结构

本目录**镜像 `lib/page/` 结构**：改了 `lib/page/channel/channel_list_page.dart`，
就去 `test/auto_test/channel/channel_list_page.md` 更新对应功能点。

执行规程见 [LOOP_PROMPT.md](./LOOP_PROMPT.md)。

## 表格规则（保证有限膨胀）

| 规则 | 说明 |
|---|---|
| **一行 = 一个功能点** | 行数只随功能增加，**不随测试轮次增加** |
| **按功能介绍覆盖写** | 同一功能点永远只有一行。新一轮改状态和计数，不加行 |
| **bug 用计数不用叙述** | `待处理 = 发现 − 解决`，恒等式可自动校验 |
| **备注只写当前未闭环的事** | 闭环即清空。修复细节去 git log 查 |

## 列定义

| 计划变化 | 含义 |
|---|---|
| `待首测` | 从没测过 |
| `回归复测` | 页面整体标过通过，但这个功能点当初没被单独验证 |
| `待修复` | 有未修 bug |
| `待复验` | 代码已改，缺真机证据 |
| `阻塞` | 缺外部条件（第二台设备 / 真实素材 / 授权 / 特定数据规模） |
| `无待办` | 当前无动作，只在回归轮被动扫到 |

## 「测试状态」列取值（第 6 列，白名单）

| 取值 | 含义 |
|---|---|
| `已通过` | 该功能点真机验证通过（logcat/截图有证据） |
| `未测` | 条件不具备，从未执行 |
| `待重验` | 已按判据测过或代码已改，缺真机证据待补 |
| `有BUG待修` | 发现 bug，等待修复 |
| 空 | 未记录（历史行允许，新写行不推荐） |

## 全局汇总

| 计划变化 | 条数 | 占比 |
|---|---|---|
| 无待办 | 760 | 49.3% |
| 回归复测 | 440 | 28.6% |
| 阻塞 | 341 | 22.1% |
| **合计** | **1541** | 100% |

bug 累计：**发现 184 / 解决 173 / 待处理 11**

> 恒等式 `发现 − 解决 = 待处理` 成立

## 模块索引

| 模块 | 页面 | 功能点 | 待处理bug | 无待办 | 回归复测 | 阻塞 |
|---|---|---|---|---|---|---|
| [group](group/) | 26 | 286 | 0 | 107 | 130 | 49 |
| [mine](mine/) | 21 | 249 | 0 | 162 | 50 | 37 |
| [channel](channel/) | 13 | 146 | 2 | 79 | 42 | 25 |
| [contact](contact/) | 13 | 126 | 3 | 54 | 55 | 17 |
| [personal_info](personal_info/) | 8 | 88 | 2 | 49 | 20 | 19 |
| [passport](passport/) | 7 | 82 | 0 | 22 | 21 | 39 |
| [chat](chat/) | 6 | 76 | 0 | 52 | 7 | 17 |
| [moment](moment/) | 6 | 74 | 0 | 36 | 37 | 1 |
| [wallet](wallet/) | 5 | 61 | 1 | 48 | 0 | 13 |
| [user_tag](user_tag/) | 5 | 58 | 1 | 46 | 2 | 10 |
| [single](single/) | 5 | 48 | 0 | 6 | 14 | 28 |
| [qrcode](qrcode/) | 4 | 42 | 0 | 17 | 25 | 0 |
| [settings](settings/) | 3 | 36 | 0 | 16 | 9 | 11 |
| [search](search/) | 3 | 35 | 1 | 5 | 9 | 21 |
| [live_room](live_room/) | 3 | 33 | 0 | 5 | 0 | 28 |
| [scanner](scanner/) | 3 | 30 | 0 | 14 | 8 | 8 |
| [bottom_navigation](bottom_navigation/) | 1 | 12 | 0 | 5 | 0 | 7 |
| [conversation](conversation/) | 1 | 12 | 1 | 5 | 7 | 0 |
| [mention](mention/) | 1 | 12 | 0 | 3 | 0 | 9 |
| [splash](splash/) | 1 | 12 | 0 | 6 | 4 | 2 |
| [welcome](welcome/) | 1 | 12 | 0 | 12 | 0 | 0 |
| [web_shell](web_shell/) | 1 | 11 | 0 | 11 | 0 | 0 |

## 页面清单


### bottom_navigation

- [bottom_navigation_page](bottom_navigation/bottom_navigation_page.md) — 12 功能点

### channel

- [channel_admin_page](channel/channel_admin_page.md) — 11 功能点
- [channel_article_page](channel/channel_article_page.md) — 12 功能点
- [channel_comment_page](channel/channel_comment_page.md) — 12 功能点
- [channel_compose_page](channel/channel_compose_page.md) — 12 功能点
- [channel_create_page](channel/channel_create_page.md) — 11 功能点
- [channel_detail_page](channel/channel_detail_page.md) — 13 功能点 ⚠️ 2 待处理
- [channel_discover_page](channel/channel_discover_page.md) — 10 功能点
- [channel_edit_page](channel/channel_edit_page.md) — 11 功能点
- [channel_invitation_page](channel/channel_invitation_page.md) — 11 功能点
- [channel_list_page](channel/channel_list_page.md) — 12 功能点
- [channel_order_detail_page](channel/channel_order_detail_page.md) — 10 功能点
- [channel_order_list_page](channel/channel_order_list_page.md) — 9 功能点
- [channel_subscriber_page](channel/channel_subscriber_page.md) — 12 功能点

### chat

- [chat_page](chat/chat_page.md) — 21 功能点
- [chat_setting_page](chat/chat_setting_page.md) — 10 功能点
- [p2p_call_screen_page](chat/p2p_call_screen_page.md) — 12 功能点
- [quick_reply_manage_page](chat/quick_reply_manage_page.md) — 11 功能点
- [rtc_room_page](chat/rtc_room_page.md) — 12 功能点
- [send_to_page](chat/send_to_page.md) — 10 功能点

### contact

- [add_friend_page](contact/add_friend_page.md) — 9 功能点
- [apply_friend_page](contact/apply_friend_page.md) — 9 功能点
- [assistant_plaza_page](contact/assistant_plaza_page.md) — 10 功能点 ⚠️ 1 待处理
- [confirm_new_friend_page](contact/confirm_new_friend_page.md) — 9 功能点 ⚠️ 1 待处理
- [contact_page](contact/contact_page.md) — 12 功能点
- [contact_setting_page](contact/contact_setting_page.md) — 10 功能点
- [contact_setting_tag_page](contact/contact_setting_tag_page.md) — 9 功能点
- [new_friend_page](contact/new_friend_page.md) — 11 功能点 ⚠️ 1 待处理
- [people_info_more_page](contact/people_info_more_page.md) — 9 功能点
- [people_info_page](contact/people_info_page.md) — 11 功能点
- [people_info_same_group_page](contact/people_info_same_group_page.md) — 8 功能点
- [people_nearby_page](contact/people_nearby_page.md) — 11 功能点
- [recently_registered_user_page](contact/recently_registered_user_page.md) — 8 功能点

### conversation

- [conversation_page](conversation/conversation_page.md) — 12 功能点 ⚠️ 1 待处理

### group

- [add_member_page](group/add_member_page.md) — 11 功能点
- [change_info_page](group/change_info_page.md) — 10 功能点
- [face_to_face_confirm_page](group/face_to_face_confirm_page.md) — 10 功能点
- [face_to_face_page](group/face_to_face_page.md) — 11 功能点
- [group_album_page](group/group_album_page.md) — 10 功能点
- [group_album_photo_detail_page](group/group_album_photo_detail_page.md) — 11 功能点
- [group_album_photo_page](group/group_album_photo_page.md) — 12 功能点
- [group_announcement_page](group/group_announcement_page.md) — 12 功能点
- [group_category_detail_page](group/group_category_detail_page.md) — 10 功能点
- [group_category_page](group/group_category_page.md) — 10 功能点
- [group_detail_page](group/group_detail_page.md) — 12 功能点
- [group_file_audio_preview_page](group/group_file_audio_preview_page.md) — 9 功能点
- [group_file_page](group/group_file_page.md) — 12 功能点
- [group_list_page](group/group_list_page.md) — 12 功能点
- [group_member_detail_page](group/group_member_detail_page.md) — 11 功能点
- [group_member_page](group/group_member_page.md) — 12 功能点
- [group_schedule_detail_page](group/group_schedule_detail_page.md) — 12 功能点
- [group_schedule_page](group/group_schedule_page.md) — 11 功能点
- [group_select_page](group/group_select_page.md) — 9 功能点
- [group_tag_page](group/group_tag_page.md) — 10 功能点
- [group_task_detail_page](group/group_task_detail_page.md) — 12 功能点
- [group_task_page](group/group_task_page.md) — 12 功能点
- [group_vote_detail_page](group/group_vote_detail_page.md) — 12 功能点
- [group_vote_page](group/group_vote_page.md) — 11 功能点
- [launch_chat_page](group/launch_chat_page.md) — 12 功能点
- [remove_member_page](group/remove_member_page.md) — 10 功能点

### live_room

- [live_room_list_page](live_room/live_room_list_page.md) — 12 功能点
- [publisher_page](live_room/publisher_page.md) — 11 功能点
- [subscriber_page](live_room/subscriber_page.md) — 10 功能点

### mention

- [mention_list_page](mention/mention_list_page.md) — 12 功能点

### mine

- [account_security_page](mine/account_security_page.md) — 9 功能点
- [bind_email_page](mine/bind_email_page.md) — 12 功能点
- [bind_mobile_page](mine/bind_mobile_page.md) — 12 功能点
- [change_name_page](mine/change_name_page.md) — 11 功能点
- [change_password_page](mine/change_password_page.md) — 12 功能点
- [dark_model_page](mine/dark_model_page.md) — 9 功能点
- [denylist_page](mine/denylist_page.md) — 12 功能点
- [feedback_detail_page](mine/feedback_detail_page.md) — 12 功能点
- [feedback_page](mine/feedback_page.md) — 13 功能点
- [font_size_page](mine/font_size_page.md) — 10 功能点
- [language_page](mine/language_page.md) — 9 功能点
- [logout_account_page](mine/logout_account_page.md) — 12 功能点
- [mine_page](mine/mine_page.md) — 12 功能点
- [select_region_page](mine/select_region_page.md) — 10 功能点
- [set_password_page](mine/set_password_page.md) — 11 功能点
- [setting_page](mine/setting_page.md) — 16 功能点
- [storage_space_page](mine/storage_space_page.md) — 10 功能点
- [user_collect_detail_page](mine/user_collect_detail_page.md) — 12 功能点
- [user_collect_page](mine/user_collect_page.md) — 17 功能点
- [user_device_detail_page](mine/user_device_detail_page.md) — 14 功能点
- [user_device_page](mine/user_device_page.md) — 14 功能点

### moment

- [moment_at_picker_page](moment/moment_at_picker_page.md) — 10 功能点
- [moment_create_page](moment/moment_create_page.md) — 14 功能点
- [moment_detail_page](moment/moment_detail_page.md) — 13 功能点
- [moment_feed_page](moment/moment_feed_page.md) — 13 功能点
- [moment_friend_picker_page](moment/moment_friend_picker_page.md) — 12 功能点
- [moment_notify_page](moment/moment_notify_page.md) — 12 功能点

### passport

- [forgot_password_page](passport/forgot_password_page.md) — 12 功能点
- [forgot_password_pin_code_page](passport/forgot_password_pin_code_page.md) — 12 功能点
- [login_page](passport/login_page.md) — 12 功能点
- [manage_account_page](passport/manage_account_page.md) — 10 功能点
- [signup_continue_page](passport/signup_continue_page.md) — 12 功能点
- [signup_page](passport/signup_page.md) — 12 功能点
- [web_login_page](passport/web_login_page.md) — 12 功能点

### personal_info

- [more_page](personal_info/more_page.md) — 10 功能点 ⚠️ 1 待处理
- [personal_info_page](personal_info/personal_info_page.md) — 12 功能点 ⚠️ 1 待处理
- [privacy_settings_page](personal_info/privacy_settings_page.md) — 10 功能点
- [profile_page](personal_info/profile_page.md) — 12 功能点
- [set_gender_page](personal_info/set_gender_page.md) — 10 功能点
- [set_nickname_page](personal_info/set_nickname_page.md) — 12 功能点
- [set_region_page](personal_info/set_region_page.md) — 11 功能点
- [update_page](personal_info/update_page.md) — 11 功能点

### qrcode

- [channel_qrcode_page](qrcode/channel_qrcode_page.md) — 10 功能点
- [group_qrcode_page](qrcode/group_qrcode_page.md) — 11 功能点
- [qrcode_page](qrcode/qrcode_page.md) — 11 功能点
- [user_qrcode_page](qrcode/user_qrcode_page.md) — 10 功能点

### scanner

- [qr_login_confirm_page](scanner/qr_login_confirm_page.md) — 9 功能点
- [scanner_page](scanner/scanner_page.md) — 12 功能点
- [scanner_result_page](scanner/scanner_result_page.md) — 9 功能点

### search

- [message_search_page](search/message_search_page.md) — 12 功能点 ⚠️ 1 待处理
- [search_chat_page](search/search_chat_page.md) — 11 功能点
- [web_search_page](search/web_search_page.md) — 12 功能点

### settings

- [e2ee_backup_export_page](settings/e2ee_backup_export_page.md) — 12 功能点
- [e2ee_backup_import_page](settings/e2ee_backup_import_page.md) — 12 功能点
- [e2ee_key_recovery_page](settings/e2ee_key_recovery_page.md) — 12 功能点

### single

- [markdown_page](single/markdown_page.md) — 9 功能点
- [network_failure_guidance_page](single/network_failure_guidance_page.md) — 8 功能点
- [terms_of_service_page](single/terms_of_service_page.md) — 8 功能点
- [upgrade_page](single/upgrade_page.md) — 12 功能点
- [video_viewer_page](single/video_viewer_page.md) — 11 功能点

### splash

- [splash_page](splash/splash_page.md) — 12 功能点

### user_tag

- [contact_tag_detail_page](user_tag/contact_tag_detail_page.md) — 11 功能点 ⚠️ 1 待处理
- [contact_tag_list_page](user_tag/contact_tag_list_page.md) — 12 功能点
- [select_tag_friend_page](user_tag/select_tag_friend_page.md) — 12 功能点
- [tag_relation_page](user_tag/tag_relation_page.md) — 12 功能点
- [user_tag_save_page](user_tag/user_tag_save_page.md) — 11 功能点

### wallet

- [red_packet_detail_page](wallet/red_packet_detail_page.md) — 12 功能点
- [red_packet_send_page](wallet/red_packet_send_page.md) — 12 功能点
- [transfer_send_page](wallet/transfer_send_page.md) — 12 功能点 ⚠️ 1 待处理
- [wallet_page](wallet/wallet_page.md) — 12 功能点
- [withdraw_page](wallet/withdraw_page.md) — 13 功能点

### web_shell

- [web_shell_page](web_shell/web_shell_page.md) — 11 功能点

### welcome

- [welcome_page](welcome/welcome_page.md) — 12 功能点
