# Route Smoke 路由覆盖清单

本清单对应 2026-10-16 的 81 条历史隔离路由核验，供后续维护与复跑使用。

## 基线与证据口径

- 远端 GitHub main / 原 CI SHA：`7b2ed5f0b3a4219f4b84bf7d419a6282b2a28e55`；[原运行及 Job](https://github.com/imboy-pub/imboy-flutter/actions/runs/38803126127/job/116657020125)。实际日志为 72 PASS、81 SKIP、0 FAIL、153 TOTAL，退出 2。
- 本地修复起点：`26a6871ba2a436348e67093359b5ca7ef4aac929` 加本次修复；较远端多一个企业 UI 提交。本次未推送或合并。路由注册表和烟雾执行源码在两个基线之间相同。
- 本地 Flutter 3.47.6 / Dart 3.13.5，CI 使用 Flutter 3.47.5；本地结果不能冒充 Linux CI 或真机验收。
- 历史隔离共 81 条：显式 `RouteStatus.quarantine` 13 条，历史异步名单 68 条，无重叠。原注册表实际有 156 条；旧 runner 的 `[a-z_]+` 路由名正则漏选了 3 个含数字的 E2EE 路由，此次修复后全部纳入。
- 补齐合成用户/套件级 MessageService 生命周期后，81 条独立实跑为 50 PASS、0 SKIP、31 FAIL；再补功能入口、主题容器与消息 extra 后，31 条复测为 28 PASS、0 SKIP、3 FAIL。移出隔离的 78 条均有实跑依据；最终全量回归见下。
- PASS 只证明使用真实路由挂载目标、固定帧推进和卸载无异常；网络及 SQLite 仍为合成夹具，可落在合法空态或错误态。关键业务入口另检查目标 Widget 类型；它不证明服务端请求成功或业务闭环。
- 下表“Widget源码/设备集成源码”表示已检查实际构造或 `find.byType` 断言；“导航桩/关联源码”或“构造/契约源码”不计为页面执行覆盖。未运行的设备文件不计为本次 PASS；含条件跳过的测试也不能凭源码签收。

## 优先恢复与修复边界

1. P0：聊天、主导航、账户安全、群详情/文件、个人二维码、工作区成员、企业首页/会话；复用真实页面和路由，修复共享会话/套件生命周期。
2. P1：转发消息、频道、群协作、项目协作与工作区页面；复用现有业务测试，补测试功能入口/主题容器和 extra。
3. P2：认证、资料、钱包等其余历史隔离；先确认真实挂载，再移出已不适用的隔离。
4. P3：直播发布/观看完成销毁链修复，地图通过平台夹具恢复无头测试；产品直播入口仍本地硬关闭。真机地图与音视频业务验收边界见下。

## 逐路由分类与已有覆盖

每条恢复后的路由均由 `test/unit_test/smoke/route_smoke_test.dart` 实际执行；已有测试列用于避免重复编写业务断言。这里不以一个模块的测试替代其全部路由。

| 路由 | 原隔离 | 优先级 / 当前分类 | 已有覆盖证据与本轮状态 |
|---|---|---|---|
| `sign_up` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | [test/unit_test/page/passport/signup_page_test.dart:38](../../test/unit_test/page/passport/signup_page_test.dart#L38)（Widget源码；未运行） |
| `sign_up_continue` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | [test/unit_test/page/passport/signup_continue_page_test.dart:56](../../test/unit_test/page/passport/signup_continue_page_test.dart#L56)（Widget源码；未运行） |
| `forgot_password` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | [test/unit_test/page/passport/forgot_password_page_test.dart:36](../../test/unit_test/page/passport/forgot_password_page_test.dart#L36)（Widget源码；未运行） |
| `forgot_password_pin` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | [test/unit_test/page/passport/forgot_password_pin_code_page_test.dart:51](../../test/unit_test/page/passport/forgot_password_pin_code_page_test.dart#L51)（Widget源码；未运行） |
| `manage_account` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | [test/unit_test/page/passport/manage_account_page_test.dart:25](../../test/unit_test/page/passport/manage_account_page_test.dart#L25)（Widget源码；未运行） |
| `bottom_navigation` | 历史异步名单 | P0：历史隔离已不适用；PASS（全量实跑） | [integration_test/enterprise/enterprise_nav_perm_nonoa_macos_test.dart:627](../../integration_test/enterprise/enterprise_nav_perm_nonoa_macos_test.dart#L627)（设备集成源码；未运行） |
| `web_shell` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | [integration_test/passport/web_login_acceptance_test.dart:253](../../integration_test/passport/web_login_acceptance_test.dart#L253)（设备集成源码；未运行；存在条件跳过） |
| `assistant_plaza` | 历史异步名单 | P2：主题容器已补；PASS（全量实跑） | [test/unit_test/page/contact/assistant_plaza/assistant_plaza_widget_flow_test.dart:79](../../test/unit_test/page/contact/assistant_plaza/assistant_plaza_widget_flow_test.dart#L79)（Widget源码；本轮实跑通过） |
| `chat` | 历史异步名单 | P0：完整会话/应用单例夹具已补；PASS（全量实跑） | [integration_test/chat/c2c_e2ee_send_render_test.dart:151](../../integration_test/chat/c2c_e2ee_send_render_test.dart#L151)（设备集成源码；未运行；存在条件跳过） |
| `send_to` | 显式 | P1：消息 extra 夹具已补；PASS（全量实跑） | 未找到直接业务断言；本次新增真实路由执行证据 |
| `launch_chat` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | [test/unit_test/page/group/launch_chat_widget_flow_test.dart:129](../../test/unit_test/page/group/launch_chat_widget_flow_test.dart#L129)（Widget源码；未运行） |
| `add_friend` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | 未找到直接业务断言；本次新增真实路由执行证据 |
| `group_discovery` | 历史异步名单 | P1：主题容器已补；PASS（全量实跑） | 未找到直接业务断言；本次新增真实路由执行证据 |
| `group_detail` | 历史异步名单 | P0：完整会话/应用单例夹具已补；PASS（全量实跑） | [test/unit_test/page/group/group_detail/group_detail_behavior_matrix_test.dart:253](../../test/unit_test/page/group/group_detail/group_detail_behavior_matrix_test.dart#L253)（Widget源码；本轮实跑通过） |
| `group_add_member` | 历史异步名单 | P1：历史隔离已不适用；PASS（全量实跑） | [test/unit_test/page/group/add_member_widget_flow_test.dart:164](../../test/unit_test/page/group/add_member_widget_flow_test.dart#L164)（Widget源码；未运行） |
| `group_remove_member` | 历史异步名单 | P1：历史隔离已不适用；PASS（全量实跑） | [test/unit_test/page/group/group_detail/member_picker_a11y_test.dart:78](../../test/unit_test/page/group/group_detail/member_picker_a11y_test.dart#L78)（Widget源码；未运行） |
| `group_launch_chat` | 历史异步名单 | P1：历史隔离已不适用；PASS（全量实跑） | [test/unit_test/page/group/launch_chat_widget_flow_test.dart:129](../../test/unit_test/page/group/launch_chat_widget_flow_test.dart#L129)（Widget源码；未运行） |
| `channel_list` | 历史异步名单 | P1：功能开关/入口夹具已补；PASS（全量实跑） | [test/unit_test/widget/channel_page_test.dart:107](../../test/unit_test/widget/channel_page_test.dart#L107)（Widget源码；未运行） |
| `channel_discover` | 历史异步名单 | P1：功能开关/入口夹具已补；PASS（全量实跑） | [test/unit_test/page/channel/channel_discover_page_test.dart:40](../../test/unit_test/page/channel/channel_discover_page_test.dart#L40)（Widget源码；未运行） |
| `channel_create` | 历史异步名单 | P1：功能开关/入口夹具已补；PASS（全量实跑） | [test/unit_test/page/channel/channel_create_page_test.dart:14](../../test/unit_test/page/channel/channel_create_page_test.dart#L14)（Widget源码；未运行） |
| `channel_invitations` | 历史异步名单 | P1：功能开关/入口夹具已补；PASS（全量实跑） | [test/unit_test/page/channel/channel_invitation_page_test.dart:33](../../test/unit_test/page/channel/channel_invitation_page_test.dart#L33)（Widget源码；未运行） |
| `channel_detail` | 历史异步名单 | P1：功能开关/入口夹具已补；PASS（全量实跑） | [test/unit_test/page/channel/channel_detail_event_test.dart:74](../../test/unit_test/page/channel/channel_detail_event_test.dart#L74)（Widget源码；未运行） |
| `channel_compose` | 历史异步名单 | P1：功能开关/入口夹具已补；PASS（全量实跑） | [test/unit_test/page/channel/channel_compose_draft_isolation_test.dart:41](../../test/unit_test/page/channel/channel_compose_draft_isolation_test.dart#L41)（Widget源码；未运行） |
| `channel_article` | 历史异步名单 | P1：功能开关/入口夹具已补；PASS（全量实跑） | [test/unit_test/page/channel/channel_article_page_test.dart:48](../../test/unit_test/page/channel/channel_article_page_test.dart#L48)（Widget源码；未运行） |
| `channel_comments` | 历史异步名单 | P1：功能开关/入口夹具已补；PASS（全量实跑） | 未找到直接业务断言；本次新增真实路由执行证据 |
| `channel_edit` | 历史异步名单 | P1：功能开关/入口夹具已补；PASS（全量实跑） | [test/unit_test/page/channel/channel_edit_page_test.dart:41](../../test/unit_test/page/channel/channel_edit_page_test.dart#L41)（Widget源码；未运行） |
| `channel_admins` | 历史异步名单 | P1：功能开关/入口夹具已补；PASS（全量实跑） | [test/unit_test/page/channel/channel_admin_page_test.dart:25](../../test/unit_test/page/channel/channel_admin_page_test.dart#L25)（Widget源码；未运行） |
| `channel_subscribers` | 历史异步名单 | P1：功能开关/入口夹具已补；PASS（全量实跑） | [test/unit_test/page/channel/channel_subscriber_page_test.dart:25](../../test/unit_test/page/channel/channel_subscriber_page_test.dart#L25)（Widget源码；未运行） |
| `channel_orders` | 历史异步名单 | P1：功能开关/入口夹具已补；PASS（全量实跑） | [test/unit_test/page/channel/channel_order_list_page_error_retry_test.dart:45](../../test/unit_test/page/channel/channel_order_list_page_error_retry_test.dart#L45)（Widget源码；未运行） |
| `channel_order_detail` | 历史异步名单 | P1：功能开关/入口夹具已补；PASS（全量实跑） | 未找到直接业务断言；本次新增真实路由执行证据 |
| `wallet` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | [integration_test/wallet/wallet_acceptance_batch156_test.dart:71](../../integration_test/wallet/wallet_acceptance_batch156_test.dart#L71)（设备集成源码；未运行） |
| `wallet_withdraw` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | [integration_test/wallet/withdraw_error_toast_acceptance_batch172_test.dart:146](../../integration_test/wallet/withdraw_error_toast_acceptance_batch172_test.dart#L146)（导航桩/关联源码；未运行；存在条件跳过） |
| `red_packet_send` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | [test/unit_test/page/wallet/wallet_send_page_back_button_test.dart:85](../../test/unit_test/page/wallet/wallet_send_page_back_button_test.dart#L85)（Widget源码；未运行） |
| `red_packet_detail` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | 未找到直接业务断言；本次新增真实路由执行证据 |
| `transfer_send` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | [test/unit_test/page/wallet/wallet_send_page_back_button_test.dart:78](../../test/unit_test/page/wallet/wallet_send_page_back_button_test.dart#L78)（Widget源码；未运行） |
| `favorites` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | [test/unit_test/integration/collect/collect_ui_flow_test.dart:22](../../test/unit_test/integration/collect/collect_ui_flow_test.dart#L22)（构造/契约源码；未运行） |
| `account_security` | 历史异步名单 | P0：完整会话/应用单例夹具已补；PASS（全量实跑） | [integration_test/auth/password_change_test.dart:176](../../integration_test/auth/password_change_test.dart#L176)（设备集成源码；未运行；存在条件跳过） |
| `select_region` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | 未找到直接业务断言；本次新增真实路由执行证据 |
| `video_viewer` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | 未找到直接业务断言；本次新增真实路由执行证据 |
| `map_location_picker` | 历史异步名单 | P2：WebView 平台夹具已补；PASS（本轮完整回归） | [原生路由回归](../../test/unit_test/config/router/native_route_lifecycle_test.dart)（本轮实跑通过；地图配置与桥事件/UI 状态断言） |
| `live_room` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | [integration_test/misc/acceptance_batch157_test.dart:193](../../integration_test/misc/acceptance_batch157_test.dart#L193)（设备集成源码；未运行） |
| `live_room_publisher` | 历史异步名单 | P3：销毁链已修复；PASS（本轮完整回归） | [原生路由回归](../../test/unit_test/config/router/native_route_lifecycle_test.dart)（本轮实跑通过；正常卸载及初始化中关闭，释放次数与顺序断言） |
| `live_room_subscriber` | 历史异步名单 | P3：销毁链已修复；PASS（本轮完整回归） | [原生路由回归](../../test/unit_test/config/router/native_route_lifecycle_test.dart)（本轮实跑通过；正常卸载及初始化中关闭，释放次数与顺序断言） |
| `qrcode` | 历史异步名单 | P0：完整会话/应用单例夹具已补；PASS（全量实跑） | [integration_test/personal_info/personal_info_acceptance_test.dart:559](../../integration_test/personal_info/personal_info_acceptance_test.dart#L559)（设备集成源码；未运行；存在条件跳过） |
| `qrcode_user` | 历史异步名单 | P0：历史隔离已不适用；PASS（全量实跑） | [integration_test/personal_info/personal_info_acceptance_test.dart:559](../../integration_test/personal_info/personal_info_acceptance_test.dart#L559)（设备集成源码；未运行；存在条件跳过） |
| `personal_info` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | [test/unit_test/page/personal_info/personal_info/personal_info_page_widget_test.dart:84](../../test/unit_test/page/personal_info/personal_info/personal_info_page_widget_test.dart#L84)（Widget源码；本轮实跑通过） |
| `set_nickname` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | [integration_test/personal_info/personal_info_acceptance_test.dart:339](../../integration_test/personal_info/personal_info_acceptance_test.dart#L339)（设备集成源码；未运行；存在条件跳过） |
| `set_gender` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | [integration_test/personal_info/personal_info_acceptance_test.dart:612](../../integration_test/personal_info/personal_info_acceptance_test.dart#L612)（设备集成源码；未运行；存在条件跳过） |
| `set_region` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | [integration_test/personal_info/personal_info_acceptance_test.dart:707](../../integration_test/personal_info/personal_info_acceptance_test.dart#L707)（设备集成源码；未运行；存在条件跳过） |
| `update` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | [integration_test/personal_info/personal_info_acceptance_test.dart:771](../../integration_test/personal_info/personal_info_acceptance_test.dart#L771)（设备集成源码；未运行；存在条件跳过） |
| `more` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | [integration_test/personal_info/personal_info_acceptance_test.dart:253](../../integration_test/personal_info/personal_info_acceptance_test.dart#L253)（设备集成源码；未运行；存在条件跳过） |
| `profile` | 历史异步名单 | P2：完整会话/应用单例夹具已补；PASS（全量实跑） | [test/unit_test/page/mine/mine/mine_page_test.dart:87](../../test/unit_test/page/mine/mine/mine_page_test.dart#L87)（导航桩/关联源码；未运行） |
| `privacy_settings` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | [test/unit_test/page/personal_info/profile/privacy_settings_page_test.dart:22](../../test/unit_test/page/personal_info/profile/privacy_settings_page_test.dart#L22)（Widget源码；未运行） |
| `search_chat` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | [integration_test/search/sc_acceptance_test.dart:76](../../integration_test/search/sc_acceptance_test.dart#L76)（导航桩/关联源码；未运行；存在条件跳过） |
| `message_search` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | [integration_test/search/ms_core_acceptance_test.dart:80](../../integration_test/search/ms_core_acceptance_test.dart#L80)（导航桩/关联源码；未运行；存在条件跳过） |
| `web_search` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | [integration_test/search/web_search_acceptance_test.dart:208](../../integration_test/search/web_search_acceptance_test.dart#L208)（导航桩/关联源码；未运行；存在条件跳过） |
| `group_category` | 历史异步名单 | P1：历史隔离已不适用；PASS（全量实跑） | 未找到直接业务断言；本次新增真实路由执行证据 |
| `group_tag` | 历史异步名单 | P1：历史隔离已不适用；PASS（全量实跑） | [test/unit_test/integration/tag/group_tag_manage_ui_test.dart:32](../../test/unit_test/integration/tag/group_tag_manage_ui_test.dart#L32)（Widget源码；未运行） |
| `group_file` | 历史异步名单 | P0：历史隔离已不适用；PASS（全量实跑） | [test/unit_test/page/group/file/group_file_page_test.dart:193](../../test/unit_test/page/group/file/group_file_page_test.dart#L193)（Widget源码；本轮实跑通过） |
| `group_album` | 历史异步名单 | P1：历史隔离已不适用；PASS（全量实跑） | [test/unit_test/page/group/album/group_album_page_test.dart:195](../../test/unit_test/page/group/album/group_album_page_test.dart#L195)（Widget源码；未运行） |
| `group_album_photos` | 历史异步名单 | P1：历史隔离已不适用；PASS（全量实跑） | [test/unit_test/page/group/album/group_album_photo_navigation_test.dart:156](../../test/unit_test/page/group/album/group_album_photo_navigation_test.dart#L156)（Widget源码；未运行） |
| `group_album_photo_detail` | 历史异步名单 | P1：历史隔离已不适用；PASS（全量实跑） | [test/unit_test/config/router/app_router_group_album_detail_route_test.dart:48](../../test/unit_test/config/router/app_router_group_album_detail_route_test.dart#L48)（Widget源码；未运行） |
| `group_vote` | 历史异步名单 | P1：功能开关/入口夹具已补；PASS（全量实跑） | [test/unit_test/page/group/vote/group_vote_widget_flow_test.dart:30](../../test/unit_test/page/group/vote/group_vote_widget_flow_test.dart#L30)（Widget源码；未运行） |
| `group_vote_detail` | 历史异步名单 | P1：功能开关/入口夹具已补；PASS（全量实跑） | [integration_test/demo_flow/group_collaboration_flow_test.dart:275](../../integration_test/demo_flow/group_collaboration_flow_test.dart#L275)（设备集成源码；未运行；存在条件跳过） |
| `group_schedule` | 历史异步名单 | P1：功能开关/入口夹具已补；PASS（全量实跑） | [integration_test/demo_flow/group_collaboration_flow_test.dart:158](../../integration_test/demo_flow/group_collaboration_flow_test.dart#L158)（设备集成源码；未运行；存在条件跳过） |
| `group_schedule_detail` | 历史异步名单 | P1：功能开关/入口夹具已补；PASS（全量实跑） | [integration_test/demo_flow/group_collaboration_flow_test.dart:263](../../integration_test/demo_flow/group_collaboration_flow_test.dart#L263)（设备集成源码；未运行；存在条件跳过） |
| `group_task` | 历史异步名单 | P1：功能开关/入口夹具已补；PASS（全量实跑） | [test/unit_test/widget/group_task_page_test.dart:172](../../test/unit_test/widget/group_task_page_test.dart#L172)（Widget源码；未运行） |
| `group_task_detail` | 历史异步名单 | P1：功能开关/入口夹具已补；PASS（全量实跑） | [test/unit_test/page/group/group_task_detail_assignment_test.dart:57](../../test/unit_test/page/group/group_task_detail_assignment_test.dart#L57)（Widget源码；未运行） |
| `mention_list` | 历史异步名单 | P2：历史隔离已不适用；PASS（全量实跑） | [test/unit_test/page/mention/mention_list_page_test.dart:52](../../test/unit_test/page/mention/mention_list_page_test.dart#L52)（Widget源码；未运行） |
| `workspace_picker` | 显式 | P1：历史隔离已不适用；PASS（全量实跑） | [test/unit_test/page/workspace/workspace_picker_page_test.dart:55](../../test/unit_test/page/workspace/workspace_picker_page_test.dart#L55)（Widget源码；未运行） |
| `workspace_members` | 显式 | P0：历史隔离已不适用；PASS（全量实跑） | [test/unit_test/page/workspace/workspace_members_page_test.dart:119](../../test/unit_test/page/workspace/workspace_members_page_test.dart#L119)（Widget源码；本轮实跑通过） |
| `workspace_channel_detail` | 显式 | P1：历史隔离已不适用；PASS（全量实跑） | [test/unit_test/page/workspace/workspace_channel_detail_page_test.dart:27](../../test/unit_test/page/workspace/workspace_channel_detail_page_test.dart#L27)（Widget源码；未运行） |
| `workspace_invite` | 显式 | P1：历史隔离已不适用；PASS（全量实跑） | [integration_test/workspace/workspace_acceptance_batch154_test.dart:185](../../integration_test/workspace/workspace_acceptance_batch154_test.dart#L185)（设备集成源码；未运行） |
| `workspace_project_detail` | 显式 | P1：功能开关/入口夹具已补；PASS（全量实跑） | [test/unit_test/page/workspace/project/project_page_test.dart:341](../../test/unit_test/page/workspace/project/project_page_test.dart#L341)（Widget源码；未运行） |
| `workspace_task_edit` | 显式 | P1：功能开关/入口夹具已补；PASS（全量实跑） | [test/unit_test/page/workspace/project/project_task_flow_test.dart:424](../../test/unit_test/page/workspace/project/project_task_flow_test.dart#L424)（Widget源码；未运行） |
| `workspace_project_members` | 显式 | P1：功能开关/入口夹具已补；PASS（全量实跑） | [test/unit_test/page/workspace/project/project_w2_members_page_test.dart:28](../../test/unit_test/page/workspace/project/project_w2_members_page_test.dart#L28)（Widget源码；本轮实跑通过） |
| `workspace_project_milestones` | 显式 | P1：功能开关/入口夹具已补；PASS（全量实跑） | [test/unit_test/page/workspace/project/project_w2_milestones_page_test.dart:34](../../test/unit_test/page/workspace/project/project_w2_milestones_page_test.dart#L34)（Widget源码；本轮实跑通过） |
| `workspace_project_channels` | 显式 | P1：功能开关/入口夹具已补；PASS（全量实跑） | [test/unit_test/page/workspace/project/project_w2_channels_page_test.dart:30](../../test/unit_test/page/workspace/project/project_w2_channels_page_test.dart#L30)（Widget源码；本轮实跑通过） |
| `workspace_project_insights` | 显式 | P1：功能开关/入口夹具已补；PASS（全量实跑） | [test/unit_test/page/workspace/project/project_w2_insights_page_test.dart:113](../../test/unit_test/page/workspace/project/project_w2_insights_page_test.dart#L113)（Widget源码；本轮实跑通过） |
| `enterprise_home` | 显式 | P0：历史隔离已不适用；PASS（全量实跑） | 未找到直接业务断言；本次新增真实路由执行证据 |
| `enterprise_conversation` | 显式 | P0：历史隔离已不适用；PASS（全量实跑） | 未找到直接业务断言；本次新增真实路由执行证据 |

## 最后三条的修复与验证边界

- `map_location_picker`：已复用并提取现有 WebView 平台夹具，保留真实 MapLocationPicker、WebViewController、HTML 地图配置与 FlutterBridge；高德 POI 请求返回符合实际接口结构的合成空列表。新增回归检查真实页面挂载、初始坐标、桥消息在挂载状态下可处理及页面卸载。没有加载真实高德服务或执行真机定位、选点/截图验收。
- `live_room_publisher` / `live_room_subscriber`：缓存页面使用的 Notifier，避免 dispose 时再次读取 WidgetRef；异步清理结束后仅在 Provider 存活时更新状态，关闭页面仍等待原生初始化和媒体清理完成后释放渲染器。发布端并行等待所有 track.stop，再关闭连接；失败仍传播，渲染器在 finally 路径释放。
- `test/unit_test/config/router/native_route_lifecycle_test.dart` 新增 6 项：两页正常卸载各自校验 renderer 创建/清理/释放；两页在原生初始化未完成时关闭，仍各释放一次；地图真实页面/初始坐标与消息桥配置，以及挂载时处理 moveend 消息后定位按钮从当前定位态变为地图拖动态。原生 WebRTC 仅 mock 插件通道，意外插件调用会直接失败。
- 这些是无头路由与生命周期回归证据，不代替真机定位权限、地图交互、WHIP/WHEP 传输或音视频轨道关闭的设备验收。直播入口本地硬关闭策略保持不变。

## 复跑与本次验证

```bash
# 默认门禁：存在跳过仍退出 2，执行失败退出 1。
bash test/unit_test/smoke/run_smoke_isolated.sh
# 诊断时实际执行隔离项，失败仍退出 1；不能用该开关把 skip 变成 PASS。
bash test/unit_test/smoke/run_smoke_isolated.sh --include-quarantined --route map_location_picker
```

- 上一阶段完整 156 路由扫描：152 PASS、3 SKIP、1 FAIL，退出 1。新断言发现 `group_announcement` 缺 groupId 时退回群列表；补 groupId 后复验通过。
- 同时补齐 `qrcode_group` / `qrcode_channel` / `feedback_detail` 的 extra 与实际页面类型断言，避免“数据不存在”兜底页继续算通过；这三条原先并不在 81 条隔离名单内。
- 后续只改上述四条路由的夹具/专属类型分支，以及文档路径/负向测试；四条均独立复验 PASS，三条保留隔离仍为 SKIP。该 7 路由 runner 实测 4 PASS、3 SKIP、0 FAIL、退出 2；其余路由沿用刚完成的全量证据，未重复跑完整 156 条。
- 上一阶段有效逐路由矩阵（全量 + 受影响项复验）：153 PASS、3 SKIP、0 FAIL、156 TOTAL；其中原 CI 81 条跳过项为 78 PASS、3 SKIP、0 FAIL。原 153 条选择口径为 150 PASS、3 SKIP、0 FAIL，另外 3 条 E2EE 路由此次首次被 runner 纳入并实跑 PASS。该阶段仍不满足“全部执行通过”。
- 上一阶段现有业务测试 10 文件、116 用例通过：群详情行为矩阵、群文件、工作区成员、二维码群/频道卡片、个人资料、项目成员/里程碑/频道/聚合、AI 助手交互。二维码卡片测试不等于个人二维码验证；个人二维码由本次路由烟雾测试执行。
- 路由负向/完整性守卫 6 用例通过：关闭朋友圈/频道入口不能签收首页，缺少三种 extra 时不能签收占位页，注册表覆盖真实 router。
- runner 契约 9 用例通过：含数字路由选取、隔离诊断开关、SKIP 退出 2、失败退出 1、缺目标/报告不完整不能通过。
- `dart analyze lib test/unit_test/smoke` 零问题；修改的 Dart 文件格式、runner shell 语法和 Diff 空白检查通过。
- 仓外证据根：`/tmp/imboy-route-audit-20261016/`；含原 CI 日志、逐路由 machine 日志、各轮汇总、候选源码哈希和实际 Diff。最终 `evidence-index.json` 绑定基线 SHA、Diff SHA-256 和日志哈希。
- 未运行整仓全量单测、Linux 远端 CI 或真机/桌面业务集成；未操作真实账号、发送消息、推送或合并。E2EE Suite Gate 单项失败仍是独立问题，本次不声称已修复。

## 三条收尾的当前候选

- 基线：`9fc43cf1c87b1f49c9bc26497f4da9956839de85`；本轮仅修改直播销毁链、测试夹具/断言和本清单，不开放直播业务入口。
- 定向回归：28 项通过（含上述 6 项原生/地图回归、现有 WebView 权限回归及直播状态/列表回归）；路由负向/完整性守卫 6 项通过；执行脚本契约 9 项通过。
- 静态检查：`dart analyze lib test/unit_test/smoke test/unit_test/helper/fake_webview_platform.dart test/unit_test/component/web_view_device_permissions_test.dart test/unit_test/config/router/native_route_lifecycle_test.dart` 零问题。
- 本轮固定候选完整扫描：156 PASS、0 SKIP、0 FAIL、156 TOTAL，runner 实测退出码 0；原 81 条历史跳过项全部执行并通过。没有再拼接上一阶段结果，保留原有“出现 SKIP 退出 2、出现 FAIL 退出 1”的判定规则。
- 本轮仓外证据：`/tmp/imboy-route-final3-20261016/`；源码哈希及仅测试文件移入常规 CI 扫描目录的记录见 `candidate-hashes.json`，最终完整 machine 日志与证据索引在该目录保留。

### 既有框架门禁限制

`inventory --check` 与 `auto_test.py validate --strict` 通过，但统一测试框架门禁仍失败：当前 461 项控制面测试有 1 FAIL、3 ERROR；三项 ERROR 均是截图工具导入了测试包 `auto_test`，无法找到 `discover_devices`，FAIL 则是 catalog 漏收已有的 `integration_test/enterprise/oa_login_real_backend_test.dart`（159/160 漂移）。

在未修改的 `9fc43cf1` 源码导出中，针对截图工具的 14 项测试同样有 3 ERROR，catalog 检查也复现同一缺失项；相关 scripts、test/tooling、catalog 与本次 Diff 无交集。未将缺 Git/并排后端的导出环境全量结果用作可比基线，也未绕过或调整门禁。本轮路由结果不代表整个项目所有 CI 已通过。
