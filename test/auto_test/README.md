# imboyapp 自动化测试计划 —— 索引

> **权威文档**。imboyapp 现有全部功能点（已完成 / 未完成 / 阻塞 全部纳入）。
> 生成 2026-08-06 | 覆盖 **137 个页面 / 1538 个功能点**
> 数据源：`lib/page/**` 真实源码抽取 ＋ 批次 1～25 真机实测记录

## 目录结构

本目录**镜像 `lib/page/` 结构**：改了 `lib/page/channel/channel_list_page.dart`，
就去 `test/auto_test/channel/channel_list_page.md` 更新对应功能点。

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

## 全局汇总

| 计划变化 | 条数 | 占比 |
|---|---|---|
| 无待办 | 218 | 14.2% |
| 回归复测 | 739 | 48.0% |
| 待首测 | 228 | 14.8% |
| 待修复 | 32 | 2.1% |
| 待复验 | 11 | 0.7% |
| 阻塞 | 310 | 20.2% |
| **合计** | **1538** | 100% |

bug 累计：**发现 138 / 解决 105 / 待处理 33**

### 关键结论

1. **真实验证覆盖率 14.2%**（218/1538），不是历史清单说的 87%。差距来源：历史记录是**页面粒度**，
   落到功能点后，739 个功能点属于「页面标过通过但这条从没被单独验证」。
2. **阻塞 310 条**集中在直播间、E2EE 危险操作、钱包资金流水、需第二台设备的扫码链路、Web Shell —— 做不了，不是欠账。
3. 待修 32 条、待验 11 条，是下一轮修复期的全部工作量。

## 模块索引

| 模块 | 页面 | 功能点 | 待处理bug | 待修复 | 待复验 | 阻塞 | 无待办 |
|---|---|---|---|---|---|---|---|
| [group](group/) | 26 | 286 | 1 | 1 | 0 | 41 | 50 |
| [mine](mine/) | 21 | 249 | 2 | 2 | 0 | 16 | 29 |
| [channel](channel/) | 13 | 145 | 3 | 3 | 1 | 16 | 18 |
| [contact](contact/) | 13 | 126 | 4 | 4 | 2 | 1 | 17 |
| [personal_info](personal_info/) | 8 | 87 | 5 | 5 | 0 | 10 | 19 |
| [passport](passport/) | 7 | 82 | 0 | 0 | 0 | 39 | 22 |
| [chat](chat/) | 6 | 76 | 10 | 9 | 0 | 34 | 13 |
| [moment](moment/) | 6 | 74 | 2 | 2 | 1 | 0 | 12 |
| [wallet](wallet/) | 5 | 60 | 2 | 2 | 4 | 25 | 5 |
| [user_tag](user_tag/) | 5 | 58 | 1 | 1 | 0 | 0 | 11 |
| [single](single/) | 5 | 48 | 0 | 0 | 2 | 29 | 3 |
| [qrcode](qrcode/) | 4 | 42 | 0 | 0 | 1 | 0 | 6 |
| [settings](settings/) | 3 | 36 | 0 | 0 | 0 | 10 | 2 |
| [search](search/) | 3 | 35 | 2 | 2 | 0 | 11 | 3 |
| [live_room](live_room/) | 3 | 33 | 0 | 0 | 0 | 23 | 0 |
| [scanner](scanner/) | 3 | 30 | 0 | 0 | 0 | 24 | 1 |
| [conversation](conversation/) | 1 | 12 | 1 | 1 | 0 | 0 | 4 |
| [mention](mention/) | 1 | 12 | 0 | 0 | 0 | 6 | 0 |
| [welcome](welcome/) | 1 | 12 | 0 | 0 | 0 | 12 | 0 |
| [splash](splash/) | 1 | 12 | 0 | 0 | 0 | 2 | 3 |
| [bottom_navigation](bottom_navigation/) | 1 | 12 | 0 | 0 | 0 | 0 | 0 |
| [web_shell](web_shell/) | 1 | 11 | 0 | 0 | 0 | 11 | 0 |

## 页面清单


### bottom_navigation

- [bottom_navigation_page](bottom_navigation/bottom_navigation_page.md) — 12 功能点

### channel

- [channel_admin_page](channel/channel_admin_page.md) — 11 功能点
- [channel_article_page](channel/channel_article_page.md) — 12 功能点
- [channel_comment_page](channel/channel_comment_page.md) — 12 功能点 ⚠️ 2 待修
- [channel_compose_page](channel/channel_compose_page.md) — 12 功能点
- [channel_create_page](channel/channel_create_page.md) — 11 功能点
- [channel_detail_page](channel/channel_detail_page.md) — 12 功能点
- [channel_discover_page](channel/channel_discover_page.md) — 10 功能点
- [channel_edit_page](channel/channel_edit_page.md) — 11 功能点
- [channel_invitation_page](channel/channel_invitation_page.md) — 11 功能点
- [channel_list_page](channel/channel_list_page.md) — 12 功能点 ⚠️ 1 待修
- [channel_order_detail_page](channel/channel_order_detail_page.md) — 10 功能点
- [channel_order_list_page](channel/channel_order_list_page.md) — 9 功能点
- [channel_subscriber_page](channel/channel_subscriber_page.md) — 12 功能点

### chat

- [chat_page](chat/chat_page.md) — 21 功能点 ⚠️ 4 待修
- [chat_setting_page](chat/chat_setting_page.md) — 10 功能点 ⚠️ 1 待修
- [p2p_call_screen_page](chat/p2p_call_screen_page.md) — 12 功能点 ⚠️ 3 待修
- [quick_reply_manage_page](chat/quick_reply_manage_page.md) — 11 功能点 ⚠️ 1 待修
- [rtc_room_page](chat/rtc_room_page.md) — 12 功能点
- [send_to_page](chat/send_to_page.md) — 10 功能点 ⚠️ 1 待修

### contact

- [add_friend_page](contact/add_friend_page.md) — 9 功能点
- [apply_friend_page](contact/apply_friend_page.md) — 9 功能点
- [assistant_plaza_page](contact/assistant_plaza_page.md) — 10 功能点 ⚠️ 1 待修
- [confirm_new_friend_page](contact/confirm_new_friend_page.md) — 9 功能点 ⚠️ 1 待修
- [contact_page](contact/contact_page.md) — 12 功能点
- [contact_setting_page](contact/contact_setting_page.md) — 10 功能点
- [contact_setting_tag_page](contact/contact_setting_tag_page.md) — 9 功能点
- [new_friend_page](contact/new_friend_page.md) — 11 功能点 ⚠️ 1 待修
- [people_info_more_page](contact/people_info_more_page.md) — 9 功能点 ⚠️ 1 待修
- [people_info_page](contact/people_info_page.md) — 11 功能点
- [people_info_same_group_page](contact/people_info_same_group_page.md) — 8 功能点
- [people_nearby_page](contact/people_nearby_page.md) — 11 功能点
- [recently_registered_user_page](contact/recently_registered_user_page.md) — 8 功能点

### conversation

- [conversation_page](conversation/conversation_page.md) — 12 功能点 ⚠️ 1 待修

### group

- [add_member_page](group/add_member_page.md) — 11 功能点
- [change_info_page](group/change_info_page.md) — 10 功能点
- [face_to_face_confirm_page](group/face_to_face_confirm_page.md) — 10 功能点
- [face_to_face_page](group/face_to_face_page.md) — 11 功能点
- [group_album_page](group/group_album_page.md) — 10 功能点
- [group_album_photo_detail_page](group/group_album_photo_detail_page.md) — 11 功能点
- [group_album_photo_page](group/group_album_photo_page.md) — 12 功能点
- [group_announcement_page](group/group_announcement_page.md) — 12 功能点
- [group_category_detail_page](group/group_category_detail_page.md) — 10 功能点 ⚠️ 1 待修
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
- [language_page](mine/language_page.md) — 9 功能点 ⚠️ 1 待修
- [logout_account_page](mine/logout_account_page.md) — 12 功能点
- [mine_page](mine/mine_page.md) — 12 功能点
- [select_region_page](mine/select_region_page.md) — 10 功能点
- [set_password_page](mine/set_password_page.md) — 11 功能点
- [setting_page](mine/setting_page.md) — 16 功能点
- [storage_space_page](mine/storage_space_page.md) — 10 功能点
- [user_collect_detail_page](mine/user_collect_detail_page.md) — 12 功能点 ⚠️ 1 待修
- [user_collect_page](mine/user_collect_page.md) — 17 功能点
- [user_device_detail_page](mine/user_device_detail_page.md) — 14 功能点
- [user_device_page](mine/user_device_page.md) — 14 功能点

### moment

- [moment_at_picker_page](moment/moment_at_picker_page.md) — 10 功能点
- [moment_create_page](moment/moment_create_page.md) — 14 功能点
- [moment_detail_page](moment/moment_detail_page.md) — 13 功能点 ⚠️ 1 待修
- [moment_feed_page](moment/moment_feed_page.md) — 13 功能点
- [moment_friend_picker_page](moment/moment_friend_picker_page.md) — 12 功能点
- [moment_notify_page](moment/moment_notify_page.md) — 12 功能点 ⚠️ 1 待修

### passport

- [forgot_password_page](passport/forgot_password_page.md) — 12 功能点
- [forgot_password_pin_code_page](passport/forgot_password_pin_code_page.md) — 12 功能点
- [login_page](passport/login_page.md) — 12 功能点
- [manage_account_page](passport/manage_account_page.md) — 10 功能点
- [signup_continue_page](passport/signup_continue_page.md) — 12 功能点
- [signup_page](passport/signup_page.md) — 12 功能点
- [web_login_page](passport/web_login_page.md) — 12 功能点

### personal_info

- [more_page](personal_info/more_page.md) — 10 功能点 ⚠️ 1 待修
- [personal_info_page](personal_info/personal_info_page.md) — 11 功能点
- [privacy_settings_page](personal_info/privacy_settings_page.md) — 11 功能点
- [profile_page](personal_info/profile_page.md) — 12 功能点 ⚠️ 1 待修
- [set_gender_page](personal_info/set_gender_page.md) — 10 功能点 ⚠️ 1 待修
- [set_nickname_page](personal_info/set_nickname_page.md) — 11 功能点 ⚠️ 1 待修
- [set_region_page](personal_info/set_region_page.md) — 11 功能点 ⚠️ 1 待修
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

- [message_search_page](search/message_search_page.md) — 12 功能点 ⚠️ 1 待修
- [search_chat_page](search/search_chat_page.md) — 11 功能点 ⚠️ 1 待修
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

- [contact_tag_detail_page](user_tag/contact_tag_detail_page.md) — 11 功能点 ⚠️ 1 待修
- [contact_tag_list_page](user_tag/contact_tag_list_page.md) — 12 功能点
- [select_tag_friend_page](user_tag/select_tag_friend_page.md) — 12 功能点
- [tag_relation_page](user_tag/tag_relation_page.md) — 12 功能点
- [user_tag_save_page](user_tag/user_tag_save_page.md) — 11 功能点

### wallet

- [red_packet_detail_page](wallet/red_packet_detail_page.md) — 12 功能点 ⚠️ 1 待修
- [red_packet_send_page](wallet/red_packet_send_page.md) — 12 功能点
- [transfer_send_page](wallet/transfer_send_page.md) — 12 功能点
- [wallet_page](wallet/wallet_page.md) — 12 功能点
- [withdraw_page](wallet/withdraw_page.md) — 12 功能点 ⚠️ 1 待修

### web_shell

- [web_shell_page](web_shell/web_shell_page.md) — 11 功能点

### welcome

- [welcome_page](welcome/welcome_page.md) — 12 功能点
