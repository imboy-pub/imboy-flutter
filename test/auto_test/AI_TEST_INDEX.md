# AI 真机回归规格索引

`specs/` 是 AI 真机回归的权威输入；本文件由 `python3 scripts/auto_test.py report` 生成。
真实通过必须以 `reports/<run-id>/summary.json` 为证据；本索引不记录假绿。
完整页面迁移队列见 [AI_COVERAGE_MATRIX.md](./AI_COVERAGE_MATRIX.md)：样板页不等于全页功能已覆盖。
建议的下一批规格见 [AI_SPEC_BACKLOG.md](./AI_SPEC_BACKLOG.md)：必须先完成风险与数据前置分级。

## 三期落地状态

| 期次 | 交付 | 状态 |
|---|---|---|
| 一期 | JSON 规格、静态校验、视觉准则与报告生成 | 已落地 |
| 二期 | 6 个 P0 页面样板、源码/测试映射、关键入口语义标识样例 | 已落地；视觉基线待真机采集 |
| 三期 | 改动影响分析、dry-run/显式执行编排、可归档报告 | 已落地 |

## 样板 case

| Case | 风险 | 页面 | 执行器 | 截图检查点 | 视觉基线 | 高风险门禁 |
|---|---|---|---|---|---|---|
| `AUTH-PASSWORD-CHANGE-001` | P0 | 修改密码全流程 | `integration_test/auth/password_change_test.dart` | `pwd_01_launch`<br>`pwd_02_after_login`<br>`pwd_03_settings`<br>`pwd_04_change_page`<br>`pwd_05_after_submit` | 待真机采集 | 是 |
| `C2C-E2EE-SEND-RENDER-001` | P0 | strict E2EE 加密 C2C 全链发送：白盒发送→对端拉密文→ChatPage 回显 | `integration_test/chat/c2c_e2ee_send_render_test.dart` | `e2eesend_01_whitelist_send_ok`<br>`e2eesend_02_peer_history_cipher`<br>`e2eesend_03_ui_truth_source`<br>`e2eesend_04_bubble_render`<br>`e2eesend_05_peer_history_second` | 待真机采集 | 否 |
| `C2C-PLAINTEXT-REJECT-001` | P0 | strict 模式拒收明文 C2C 消息（fail-closed 安全语义） | `integration_test/chat/c2c_plaintext_reject_test.dart` | `c2cplat_01_no_leak` | 待真机采集 | 否 |
| `CHANNEL-CREATE-001` | P0 | 创建频道全流程 | `integration_test/channel/channel_e2e_test.dart` | `channel_create_01_launch`<br>`channel_create_02_after_login`<br>`channel_create_03_create_form`<br>`channel_create_04_form_filled`<br>`channel_create_05_after_submit`<br>`channel_create_06_input`<br>`channel_create_07_after_publish` | 待真机采集 | 是 |
| `CHANNEL-DETAIL-PUBLISH-001` | P0 | 频道发现、详情与消息发布 | `integration_test/channel/channel_e2e_test.dart` | `channel_01_launch`<br>`channel_02_after_login`<br>`channel_03_channel_tab`<br>`channel_04_channel_detail`<br>`channel_05_input_message`<br>`channel_06_after_publish` | 待真机采集 | 是 |
| `CHANNEL-EDIT-001` | P1 | 频道资料编辑与持久化 | `integration_test/channel/channel_edit_persistence_test.dart` | `edit_01_detail`<br>`edit_02_edit_page`<br>`edit_03_after_save` | 待真机采集 | 是 |
| `CHANNEL-PUBLISH-SMOKE-001` | P1 | 频道列表到详情发布冒烟 | `integration_test/channel/channel_publish_test.dart` | `pub_01_channel_list`<br>`pub_02_detail` | 待真机采集 | 否 |
| `CHANNEL-SUBSCRIBED-CONSISTENCY-001` | P1 | 订阅频道列表与详情一致性 | `integration_test/channel/channel_subscribed_detail_consistency_test.dart` | `consist_01_list`<br>`consist_02_detail` | 待真机采集 | 否 |
| `CHAT-GROUP-001` | P0 | 群聊消息收发与渲染 | `integration_test/chat/group_chat_test.dart` | `group_readonly_01_conv_list`<br>`group_readonly_02_chat_page`<br>`group_01_conv_list`<br>`group_02_chat_page`<br>`group_03_after_send` | 待真机采集 | 是 |
| `CHAT-SINGLE-READONLY-001` | P1 | 单聊历史消息只读渲染 | `integration_test/chat/single_chat_readonly_test.dart` | `single_chat_readonly_01` | 待真机采集 | 否 |
| `CHAT-VOICE-RENDER-001` | P1 | 语音消息气泡渲染 | `integration_test/chat/voice_render_verify_test.dart` | `voice_conv_list_empty`<br>`voice_01_chat_page`<br>`voice_02_bubble_render` | 待真机采集 | 否 |
| `CONTACT-ADD-FRIEND-001` | P0 | 搜索账号并发起好友申请 | `integration_test/contact/add_friend_request_test.dart` | `add_friend_01_launch`<br>`add_friend_02_contact_tab`<br>`add_friend_03_add_page`<br>`add_friend_04_results`<br>`add_friend_05_profile` | 待真机采集 | 是 |
| `CONTACT-CONFIRM-FRIEND-001` | P0 | 新的朋友列表与接受好友申请 | `integration_test/contact/confirm_new_friend_test.dart` | `confirm_friend_01_launch`<br>`confirm_friend_02_login_ok`<br>`confirm_friend_03_contact_tab`<br>`confirm_friend_04_new_friend_list`<br>`confirm_friend_05_confirm_page`<br>`confirm_friend_06_after_accept` | 待真机采集 | 是 |
| `CONTACT-FRIEND-MANAGE-001` | P0 | 好友资料页查看与管理 | `integration_test/contact/friend_management_test.dart` | `friend_01_launch`<br>`friend_02_after_login`<br>`friend_03_contact_list`<br>`friend_detail` | 待真机采集 | 是 |
| `GROUP-MANAGEMENT-READONLY-001` | P1 | 群列表与群管理入口只读 | `integration_test/group/group_management_readonly_test.dart` | `group_management_01_list` | 待真机采集 | 否 |
| `TWO-CLIENT-MAC-C2C-PING-001` | P0 | 双端 C2C 消息互通 | `integration_test/two_client/mac_peer_c2c_ping_test.dart` | `mac_ping_01_conversations`<br>`mac_ping_02_chat_page`<br>`mac_ping_03_after_send` | 待真机采集 | 是 |
| `TWO-CLIENT-MAC-FRIEND-APPLY-001` | P1 | 双端好友申请互通 | `integration_test/two_client/mac_peer_friend_apply_test.dart` | `mac_peer_01_main_shell`<br>`mac_peer_02_after_apply` | 待真机采集 | 是 |
| `CHAT-PAGE-001` | P0 | 单聊消息展示、输入与发送状态 | `integration_test/chat/c2c_e2ee_send_render_test.dart` | `e2eesend_01_whitelist_send_ok`<br>`e2eesend_02_peer_history_cipher`<br>`e2eesend_03_ui_truth_source`<br>`e2eesend_04_bubble_render`<br>`e2eesend_05_peer_history_second` | 待真机采集 | 是 |
| `CHAT-QUICK-REPLY-MANAGE-001` | P1 | 快捷回复管理列表与编辑控件 | `integration_test/chat/quick_reply_manage_test.dart` | `quick_reply_01_defaults` | 待真机采集 | 是 |
| `CONVERSATION-LIST-001` | P0 | 会话列表、搜索与进入聊天 | `integration_test/chat/conversation_test.dart` | `conv_03_conversation_list`<br>`conv_search_typed` | 待真机采集 | 否 |
| `E2EE-BACKUP-IMPORT-001` | P0 | E2EE 备份导入前置与危险操作门禁 | `integration_test/mine/mine_subpages_smoke_test.dart` | `e2ee_01_backup_import` | 待真机采集 | 是 |
| `GROUP-SCHEDULE-001` | P0 | 群日程列表、创建入口与详情导航 | `integration_test/group/group_collaboration_readonly_test.dart` | `group_schedule_01_list` | 待真机采集 | 否 |
| `PASSPORT-LOGIN-001` | P0 | 登录与主界面可见 | `integration_test/smoke/smoke_test.dart` | `smoke_01_main_shell` | 待真机采集 | 否 |
| `PASSPORT-SIGNUP-001` | P0 | 注册页可达、表单布局与默认不提交门禁 | `integration_test/auth/register_flow_test.dart` | `reg_03_signup_page`<br>`reg_04_form_filled` | 待真机采集 | 否 |
| `WALLET-TRANSFER-001` | P0 | 钱包余额、转账校验与确认界面 | `integration_test/wallet/wallet_readonly_test.dart` | `wallet_01_readonly` | 待真机采集 | 是 |

## 使用

```bash
python3 scripts/auto_test.py validate
python3 scripts/auto_test.py plan --phase p0
python3 scripts/auto_test.py impact lib/page/wallet/transfer_send_page.dart
python3 scripts/auto_test.py run --phase p0 --device <真实设备ID> --dry-run
python3 scripts/auto_test.py capture --case CONVERSATION-LIST-001 --device <Android真实设备ID>
```
