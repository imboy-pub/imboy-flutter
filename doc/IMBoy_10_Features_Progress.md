# IMBoy 10项功能进度评估与完善计划（可中断重跑）

更新时间：2026-02-28  
评估范围：当前仓库前端 Flutter 代码（含本地存储、WebSocket、S2C 处理、页面层、API 契约层）  
说明：后端实现代码不在本仓库，后端“真实完成度”仅能通过 API 契约与客户端处理链路间接判断。  
执行约束：按你的要求执行“单项失败即记录并继续下一项，不循环卡死”。

---

## 1. 总结结论

- 当前 10 条功能线里，`会话管理 / WebSocket确认重试 / 频道 / 朋友圈 / 收藏` 主链路完整度较高。  
- `会话消息提醒` 主要停留在应用内未读角标，系统级通知（本地通知链路）已有服务但未形成稳定调用闭环。  
- `E2EE` 已具备发送加密、接收解密、失败兜底（fail-close）和密钥不匹配处理主流程。  
- `Tag` 系统分为用户标签与群标签，基础能力存在，但统一体验、批量运营能力、回归覆盖仍需补强。  

---

## 2. 10项功能完成度矩阵（代码证据 + 测试证据）

| # | 功能线 | 当前完成度 | 判定 | 关键代码证据（文件:行） | 自动化证据 | 主要缺口 |
|---|---|---:|---|---|---|---|
| 1 | 单聊 | 80% | 部分实现（主链路可用） | `lib/page/chat/chat/chat_page.dart:213`、`lib/page/chat/chat/chat_page.dart:403`、`lib/service/message.dart:393`、`lib/service/message.dart:799`、`lib/store/repository/message_repo_sqlite.dart:156` | `conversation_logic_test` 通过；`message_receive_conversation_consistency_test` 通过 | 缺少更完整的端到端双端 UI 回归（尤其弱网/离线切换） |
| 2 | 群聊 | 78% | 部分实现（主链路可用） | `lib/page/chat/chat/chat_page.dart:387`、`lib/page/chat/chat/chat_page.dart:1895`、`lib/utils/conversation_uk3_generator.dart:42`、`lib/store/repository/message_repo_sqlite.dart:163` | 相关消息一致性测试通过；群场景端到端自动化仍偏少 | 群管理侧边行为（成员变更、权限变更）需更强自动化覆盖 |
| 3 | 会话管理 | 85% | 已实现（含权威同步） | `lib/page/conversation/conversation_provider.dart:383`、`lib/page/conversation/conversation_provider.dart:674`、`lib/page/conversation/conversation_page.dart:248`、`lib/store/repository/conversation_repo_sqlite.dart:372`、`lib/store/repository/conversation_repo_sqlite.dart:465` | `conversation_update_logic_test` 通过；`conversation_state_mock_test` 通过 | `conversation_state_integration_test` 受测试环境插件影响失败（非业务断言失败） |
| 4 | 会话消息提醒 | 65% | 部分实现（应用内完整，系统通知缺口） | `lib/page/conversation/conversation_provider.dart:61`、`lib/page/conversation/widget/conversation_item.dart:84`、`lib/page/bottom_navigation/bottom_navigation_page.dart:137`、`lib/service/active_conversation_notifier.dart:53`、`lib/service/message_conversation_utils.dart:41` | `unread_count_integration_test` 失败（StorageService 未初始化） | 系统级通知服务未形成业务调用闭环；提醒策略与勿扰策略尚未闭环 |
| 5 | WebSocket消息重试与确认 | 84% | 已实现（可增强） | `lib/service/websocket.dart:621`、`lib/service/websocket.dart:351`、`lib/service/ack_manager.dart:248`、`lib/service/ack_manager.dart:378`、`lib/service/message_retry.dart:236`、`lib/service/message.dart:1027`、`lib/service/websocket_message_queue.dart:137` | `message_ack_flow_integration_test` 通过；`message_retry_flow_integration_test` 通过；`ack_manager_enhanced_test` 通过；`message_retry_queue_test` 通过 | 离线消息整链路测试仍有环境耦合问题（EasyLoading / HttpClient注入） |
| 6 | 端到端加密消息处理 | 82% | 已实现（主链路完整） | `lib/service/e2ee_service.dart:67`、`lib/service/e2ee_service.dart:132`、`lib/service/e2ee_service.dart:208`、`lib/page/chat/chat/chat_provider.dart:764`、`lib/page/chat/chat/chat_provider.dart:789`、`lib/service/message.dart:1219` | `e2ee_service_test` 通过；`e2ee_transfer_service_test` 通过；`e2ee_health_check_service_test` 通过；`e2ee_integration_test` 通过 | `e2ee_crypto_service_test` 受 `path_provider` 插件注入影响失败；需完善测试基座 |
| 7 | Tag系统 | 72% | 部分实现 | `lib/store/api/user_tag_api.dart:10`、`lib/page/user_tag/user_tag_relation/user_tag_relation_provider.dart:80`、`lib/store/api/group_tag_api.dart:22`、`lib/service/group_tag_service.dart:41`、`lib/page/group/tag/group_tag_page.dart:39` | `user_tag_api_test` 通过 | 用户标签与群标签能力割裂；群标签仅增删，缺少更强运营能力（如重命名/颜色管理） |
| 8 | 收藏系统 | 83% | 已实现（可增强） | `lib/store/api/user_collect_api.dart:10`、`lib/page/chat/chat/message_action_handler.dart:221`、`lib/page/mine/user_collect/user_collect_provider.dart:46`、`lib/page/mine/user_collect/user_collect_provider.dart:867`、`lib/page/mine/user_collect/user_collect_provider.dart:953` | `user_collect_api_test` 通过 | 大列表性能与多端一致性验证仍需加强；UI 交互复杂度较高 |
| 9 | 频道系统 | 86% | 已实现（主干完整） | `lib/store/api/channel_api.dart:123`、`lib/store/api/channel_api.dart:195`、`lib/service/channel_service.dart:243`、`lib/page/channel/channel_provider.dart:60`、`lib/service/message_s2c.dart:162`、`lib/service/message_s2c.dart:772`、`lib/page/channel/channel_detail_page.dart:129` | `channel_integration_test` 通过；`channel_service_unread_summary_sync_test` 通过 | 付费/邀请/管理组合路径仍需更完整联调回归 |
| 10 | 朋友圈 | 82% | 已实现（主链路完整） | `lib/store/api/moment_api.dart:20`、`lib/store/api/moment_api.dart:63`、`lib/page/moment/moment_feed_page.dart:63`、`lib/page/moment/moment_create_page.dart:161`、`lib/page/moment/moment_detail_page.dart:56`、`lib/service/message_s2c.dart:186` | `moment_event_test` 通过；`moment_routes_test` 通过 | 页面状态主要在页面内部维护，跨页面一致性和弱网体验需再强化 |

---

## 3. 已执行测试清单（按“失败即继续下一项”执行）

### 3.1 通过（PASS）

- `flutter test test/service/e2ee_service_test.dart`
- `flutter test test/service/e2ee_transfer_service_test.dart`
- `flutter test test/service/e2ee_health_check_service_test.dart`
- `flutter test test/service/shamir_secret_sharing_test.dart`
- `flutter test test/store/api/user_tag_api_test.dart`
- `flutter test test/store/api/user_collect_api_test.dart`
- `flutter test test/service/channel_service_unread_summary_sync_test.dart`
- `flutter test test/service/moment_event_test.dart`
- `flutter test test/page/moment/moment_routes_test.dart`
- `flutter test test/service/message_retry_queue_test.dart`
- `flutter test test/service/ack_manager_enhanced_test.dart`
- `flutter test test/service/message_conversation_utils_test.dart`
- `flutter test test/integration/conversation_logic_test.dart`
- `flutter test test/integration/message_ack_flow_integration_test.dart`
- `flutter test test/integration/message_retry_flow_integration_test.dart`
- `flutter test test/integration/e2ee_integration_test.dart`
- `flutter test test/integration/channel_integration_test.dart`
- `flutter test test/integration/message_receive_conversation_consistency_test.dart`
- `flutter test test/integration/websocket_api_v2_integration_test.dart`（含2个插件依赖 skip）
- `flutter test test/integration/conversation_update_logic_test.dart`
- `flutter test test/integration/message_action_conversation_update_mock_test.dart`
- `flutter test test/integration/conversation_state_mock_test.dart`

### 3.2 失败（FAIL）与归因

- `flutter test test/service/e2ee_crypto_service_test.dart`  
  失败归因：`MissingPluginException(path_provider)`，测试环境插件注入问题。

- `flutter test test/integration/conversation_state_integration_test.dart`  
  失败归因：`MissingPluginException(shared_preferences)`，测试环境插件注入问题。

- `flutter test test/integration/offline_message_flow_integration_test.dart`  
  失败归因：  
  1) `EasyLoading.init()` 未在测试上下文初始化；  
  2) `HttpClient` 服务未注册（DI 依赖未满足）。  
  该失败更偏测试基座与服务耦合问题。

- `flutter test test/integration/unread_count_integration_test.dart`  
  失败归因：`StorageService not initialized`，测试前置初始化缺失。

---

## 4. UI/UX 逐步验证清单（10条功能线）

以下为可直接执行的手工验证步骤。每条功能线失败后，按规则记录后继续下一条，不阻塞。

### 4.1 单聊

1. A/B 双账号互发文本、图片、文件。  
2. A 在聊天页内，B 连发 3 条，观察 A 会话未读不增加；A 回到会话列表后观察角标变化。  
3. 弱网下发送消息，恢复网络后检查状态是否从发送中/失败恢复到已发送。  
通过标准：消息顺序正确、状态变化正确、无重复渲染、会话摘要与最后消息一致。

### 4.2 群聊

1. 进入群聊发送文本并 @ 成员。  
2. 观察群会话标题与成员数展示是否正确。  
3. 收到群消息时，未读角标与会话排序是否正确。  
通过标准：群消息路由到 C2G 会话，群详情跳转与会话摘要一致。

### 4.3 会话管理

1. 在会话列表执行“标记已读/未读”。  
2. 执行“隐藏会话”“删除会话”并重启应用确认持久化。  
3. 清空聊天记录后会话项应保留但最后消息字段被清空且排序下沉。  
通过标准：会话列表、数据库、角标状态一致，且操作具备原子性表现。

### 4.4 会话消息提醒

1. 后台停留在会话列表，触发新消息，观察底部消息 tab 红点。  
2. 进入对应聊天页，观察角标自动清零。  
3. 锁屏状态验证是否有系统通知弹出。  
通过标准：应用内角标正确；系统通知目前预期为“可能缺失”（作为已知缺口）。

### 4.5 WebSocket 重试与确认

1. 人为断网发送消息，检查消息进入重试队列。  
2. 恢复网络后，检查自动重试触发与消息状态恢复。  
3. 人为注入 ACK_CONFIRM/ACK_ERROR，观察 ACK 重试停止。  
通过标准：无无限重试、无重复发送、确认后能及时移出队列。

### 4.6 E2EE

1. 打开 E2EE 后发送 C2C 与 C2G 消息。  
2. 检查发送包顶层 `e2ee` 元数据 + `payload` 密文格式。  
3. 模拟密钥不匹配，检查 UI 是否给出不可解密提示与重登录引导。  
通过标准：加密失败不降级明文（fail-close），解密失败可识别可恢复。

### 4.7 Tag 系统

1. 用户标签：新增/重命名/删除并绑定联系人。  
2. 群标签：新增/删除，刷新后应与服务端一致。  
3. 标签筛选收藏或联系人列表，验证关联对象正确。  
通过标准：标签变更可落地并回显，关系数据不丢失。

### 4.8 收藏系统

1. 在聊天消息执行“收藏”，检查收藏列表出现新项。  
2. 收藏详情预览文本/图片/语音/视频/文件并删除收藏。  
3. 网络异常时收藏失败提示应清晰，不应出现“本地成功、远端失败”静默不一致。  
通过标准：收藏增删改查闭环，媒体预览可用，异常提示明确。

### 4.9 频道系统

1. 订阅频道，进入详情查看消息流；管理员账号测试发布消息。  
2. 验证未读汇总与 `channel_unread_count` 推送变化。  
3. 验证邀请/订单（付费频道）入口流程可达。  
通过标准：频道消息流、订阅状态、未读对账一致。

### 4.10 朋友圈

1. 发布纯文本动态；发布图文/视频动态。  
2. 点赞、评论、删除动态并验证时间线刷新。  
3. 进入详情页验证评论增删与举报流程。  
通过标准：时间线与详情状态一致，操作有可感知反馈。

---

## 5. 功能线完善任务看板（可中断重跑）

重跑规则：每个任务最多执行 1 次尝试；失败写入 `失败记录` 后立即推进下一任务。  
恢复规则：终端中断后，打开本文件，从“未勾选任务”继续。

| ID | 功能线 | 当前缺口 | 下一动作（失败也继续） | 完成标准（DoD） | 失败记录 |
|---|---|---|---|---|---|
| F01 | 单聊 | 弱网与重连场景回归不够 | 增补单聊弱网集成测试 + 手工双端验证 | 断网/重连后状态与会话一致 | `TODO` |
| F02 | 群聊 | 群管理侧联动回归偏弱 | 增补成员变更/权限变更后消息流回归 | 群消息可达、会话摘要正确 | `TODO` |
| F03 | 会话管理 | 真实仓储集成测试受插件依赖影响 | 修复测试基座插件注入后重跑 `conversation_state_integration` | 测试稳定通过 | `TODO` |
| F04 | 会话提醒 | 系统通知未闭环 | 在消息接收链路接入 `NotificationService`，加入开关与免打扰策略 | 前台/后台提醒策略可控且可测 | `TODO` |
| F05 | WS重试确认 | 离线链路测试耦合 UI 组件 | 去除服务层对 `EasyLoading` 硬依赖，改事件通知；补 DI Mock | 离线集成测试稳定通过 | `TODO` |
| F06 | E2EE | 测试环境插件依赖缺口 | 补 `path_provider`/`secure_storage` 测试替身与初始化 | E2EE 套件无环境性失败 | `TODO` |
| F07 | Tag | 用户标签与群标签体验割裂 | 统一标签管理入口与字段规范（name/color/usage） | 统一增删改查体验 | `TODO` |
| F08 | 收藏 | 大列表性能与一致性压测不足 | 补收藏列表分页/搜索/删除并发回归 | 无重复、无错删、滚动稳定 | `TODO` |
| F09 | 频道 | 付费/邀请组合流程回归不足 | 建立“订阅-邀请-支付-发帖-未读”链路验收单 | 全链路可跑通 | `TODO` |
| F10 | 朋友圈 | 页面状态分散在页面层 | 引入统一状态管理（Provider）并补弱网回滚策略 | 刷新与交互一致性提升 | `TODO` |

---

## 6. 可中断重跑执行计划（分阶段）

### 阶段 P0：测试基座稳定化（优先级最高）

- [ ] P0-T1：统一测试初始化模板（`TestWidgetsFlutterBinding`、`shared_preferences`、`path_provider`、必要 DI 注册）。  
- [ ] P0-T2：将 `MessageOfflineService` 中 UI 依赖（`EasyLoading`）迁移到事件层，服务层只产出事件与错误码。  
- [ ] P0-T3：重跑当前失败用例：  
  - `test/service/e2ee_crypto_service_test.dart`  
  - `test/integration/conversation_state_integration_test.dart`  
  - `test/integration/offline_message_flow_integration_test.dart`  
  - `test/integration/unread_count_integration_test.dart`  

验收：上述 4 项至少 3 项转绿，剩余 1 项可明确归因为业务缺陷并形成 issue。  
中断恢复：从 P0 清单里未勾选项继续，不重复执行已完成项。

### 阶段 P1：功能缺口补齐（按功能线推进）

- [ ] P1-T1（F04）：会话提醒接入系统通知链路（含通知开关、免打扰、聚合策略）。  
- [ ] P1-T2（F05）：WS 重试确认链路增加观测字段（重试原因、队列深度、ACK RTT）。  
- [ ] P1-T3（F06）：E2EE 密钥更新与重试解密链路补充回归（密钥错配 -> 恢复）。  
- [ ] P1-T4（F07）：Tag 系统统一域模型（用户标签/群标签）并补 UI 入口一致性。  
- [ ] P1-T5（F09/F10）：频道与朋友圈的 S2C 增量事件一致性回归（新消息/点赞/删除）。  

验收：每项任务完成后必须新增至少 1 条自动化用例或可重复手工脚本步骤（写入本文件）。  
中断恢复：按任务 ID 递增继续执行，跳过已打勾任务。

### 阶段 P2：UI/UX 专项验收

- [ ] P2-T1：聊天页（单聊/群聊）视觉与交互一致性检查（状态图标、撤回文案、未读消失时机）。  
- [ ] P2-T2：会话列表交互检查（滑动操作、空态、错误态、加载态）。  
- [ ] P2-T3：频道页与朋友圈页移动端体验检查（滚动性能、图片/视频加载、操作反馈）。  
- [ ] P2-T4：无障碍与可读性检查（字体缩放、触达面积、色彩对比）。  

验收：关键页面无阻断交互缺陷（P0/P1）；高频路径首屏与操作反馈在可接受范围内。  
中断恢复：从未勾选任务继续，保留已记录的问题单。

### 阶段 P3：发布前回归闸门

- [ ] P3-T1：执行回归测试清单（自动化 + 手工 Top 20 路径）。  
- [ ] P3-T2：整理功能线结果：每条线输出 `PASS/FAIL + 证据`。  
- [ ] P3-T3：形成发布结论：可发布 / 有条件发布 / 不可发布。  

验收：10 条功能线都有明确结论与证据链接。  
中断恢复：按闸门项继续，禁止返工已关闭项（除非出现阻断缺陷）。

---

## 7. 风险与依赖

- 风险 R1：测试基座插件注入不完整，导致“环境性失败”掩盖真实业务质量。  
- 风险 R2：服务层存在 UI 组件依赖（如 EasyLoading），影响可测性和可复用性。  
- 风险 R3：后端实现不可见，客户端判定仅为“前端可见完成度”，需联调验证闭环。  

依赖建议：

- D1：提供稳定联调环境（频道、朋友圈、E2EE 相关接口）。  
- D2：统一测试初始化基建（shared_preferences/path_provider/http client mock）。  
- D3：给每条功能线配置最小可重复验收数据集（账号、群、频道、动态样例）。

---

## 8. 当前结论状态

- 本文档已覆盖：10 条功能线完成度、代码证据、测试证据、UI/UX 步骤、可中断重跑计划。  
- 后续执行时只需维护本文件，不需要额外脚本或额外文档。  

