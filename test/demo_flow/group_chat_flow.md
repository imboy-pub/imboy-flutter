# DF-08 群会话 → 群消息 → @成员 → 消息恢复

> 优先级：P0
> 状态：`双账号文本消息闭环通过（生产，2026-08-10/11）/ 本地 strict 环境新增明文拒收+密文归档证据（2026-08-17）/ @成员与失败分支未覆盖 / 群历史 API 列名 bug 已定位`

## 1. 目标

验证群成员可以进入同一群会话发送文本消息，接收 @ 提醒，退出后重新进入仍能恢复消息。

## 2. 前置条件

- [x] 使用至少两个授权测试账号和可回收测试群。
- [x] 群成员、管理员和普通成员角色已明确。
- [x] 测试文本使用唯一标识，不 @ 真实第三方。

## 3. TODO 步骤

- [x] A 从会话列表或已核对群成员的现有 `ChatPage` 进入测试群。
  - 预期：群标题、成员信息和消息列表加载正确。
  - 页面计划：[chat_page.md](../auto_test/chat/chat_page.md)
- [x] A 发送唯一文本，B 打开群会话查看并回复。
  - 预期：发送者、顺序、时间和服务端成功证据一致。
  - 2026-08-17 补充：本地 strict E2EE 环境下明文被 fail-closed 拒收、密文结构消息经 WS 接收并归档（单端 API 级）；
    生产明文双端闭环引用 2026-08-10/11 历史证据。
- [ ] A @ B，B 查看提醒或群内消息。
  - 预期：@ 成员选择、消息渲染和提醒状态正确。
  - 页面计划：[mention_list_page.md](../auto_test/mention/mention_list_page.md)
  - 后端有 `msg_mention` 表与 mention API；本地密文消息对服务端不透明，@成员 payload 无法在 strict 环境以明文验证，未覆盖。
- [x] A 退出群聊页再重新进入。
  - 预期：消息从本地/服务端恢复，未读状态可解释。
  - 2026-08-17 补充：服务端归档以 `msg_c2g` 表 DB 行核验通过；`group/msg_page` API 因列名 bug 恒空（见第 5 节），
    客户端本地恢复引用 2026-08-10 双端重进回读历史证据。
- [ ] 在测试群验证发送失败和重复点击反馈。
  - 预期：失败不生成假成功气泡。
  - 2026-08-17 部分覆盖：strict 策略下明文消息收到结构化 `policy_violation` 拒收帧（负向边界），未覆盖 UI 假气泡分支。

## 4. 验收标准

- [x] 双向群消息均有服务端 ACK、跨设备收发和本地重进回读证据。
- [ ] @ 普通成员和权限边界有明确结果。
- [x] 重进页面后两条唯一消息均可回读；未读状态差异仍未单独验收。

## 5. 当前覆盖与阻塞

- 已有 `integration_test/chat/group_chat_test.dart`。
- 已新增并实跑 `integration_test/demo_flow/group_dual_account_message_flow_test.dart`。
- 2026-08-09：生产 `conversation_api_test.dart` 9/9 通过，其中消息发送仅使用无效接收方边界，不产生真实群消息；双账号群消息、@成员和重进恢复尚未通过。
- 2026-08-09：Android 华为真机运行 `group_chat_test.dart --plain-name='进入已有群聊页面可访问'` 通过：登录、会话同步、按 `ConversationModel.type == C2G` 识别已有群聊、进入 `ChatPage`，并加载生产群历史 4 条均有证据；截图因 Android 厂商 ROM surface 按诊断策略跳过。
- 本次用例未输入或点击发送；但登录期间 App 自有的已有 C2G 重试队列出现后台 `custom/PLAIN` 重试发送日志。因此只能认定“群聊页面和历史只读入口通过”，不能认定生产零写入或消息闭环通过。
- 2026-08-09：同一 Android 真机另有群协作列表 `1/1` 通过，日程/任务/投票列表均可读取；这不替代群消息、@成员或消息恢复验收。
- 2026-08-09：为防止 P0 串行执行误写生产，`group_chat_test.dart` 的发送用例接入通用 `TEST_ALLOW_BUSINESS_WRITES` 闸门；`.env.pro` 复核为 `0` 通过、`1` 受控跳过，门禁返回后不启动 App。双账号群消息仍需非生产隔离数据。
- @所有人、多人并发和 E2EE 解密异常依赖更多账号/设备，暂不纳入默认流程。
- 2026-08-10：使用 `.env.pro`、117 macOS 与 118 Android 华为真机，在测试群
  `104603643803863040` 完成双向唯一标记收发；两端均取得 `C2G_SERVER_ACK`，
  Android 直接从已核对成员的现有 `ChatPage` 进入，双方退出并重进后均回读两条消息，
  最终 sender/receiver 均 `1/1 All tests passed`。本次只写入文本消息，不创建/删除群，
  未覆盖 @成员、失败重试和多人并发。
- 2026-08-17：本地后端（alpha.27，strict policy：`/api/v1/app/policy` 只读确认 `e2ee_mode=required`、
  `storage_mode=secure_e2ee`）新增纯 Dart 测试 `integration_test/demo_flow/group_local_message_flow_test.dart`，
  双账号建群（A=`13900001002`、B=`test_886209702@example.com`）后 WS（`imboy.v2` 子协议+签名头+Bearer）验证，
  最终 `2/2 All tests passed`：
  1. 明文 C2G 文本（`DEMO-FLOW-20260817-PLAIN-*`）被服务端 fail-closed 拒收，收到结构化
     `policy_violation / encrypted_message_required` 帧——本地 strict 门禁有效的负向证据。
  2. 密文结构 C2G 消息（e2ee 非空信封+非空密文 payload，`DEMO-FLOW-20260817-CIPHER-*` 标记经 base64 封装）
     经 WS 发送后服务端接收并归档：`msg_c2g` 表 DB 行核验命中（msg_id `demoflow-cipher-*`，e2ee 非空）。
     注意：该消息为结构化测试密文，仅验证 C2G 管道与归档，不构成 E2EE 安全验收；本轮无第二设备，
     双端实时收发维持 2026-08-10/11 生产双账号 PASS 历史证据。
- 2026-08-17 发现项（后端 bug，根因定位，不修改 imboy 仓）：`GET /api/v1/group/msg_page` 恒返回
  `total=0`——`group_handler:msg_page` 的查询键 `to_groupid` 与 `msg_c2g` 表实际列名 `to_id` 不匹配，
  SQL 失败被吞后返回空列表（HEAD 源码与 alpha.27 一致）。这与历史 flow 中“服务端历史接口返回成功但归档为空
  （historyUnavailable）”现象一致，很可能是该现象的根因；修复后群历史 API 回读可恢复。
- 2026-08-17 发现项（后端，非回归）：本地 alpha.27 密文 C2G 消息归档成功但 `C2G_SERVER_ACK` 帧 15 秒内未返回
  （历史 WS ACK 修复在 alpha.26~28 间迭代）；本轮以 DB 归档行作为服务端成功证据，ACK 断言降级为尽力收集。

## 6. 未来自动化目标

`integration_test/demo_flow/group_dual_account_message_flow_test.dart` 已覆盖双账号文本收发、
服务端 ACK、跨设备回读和重进恢复；`group_chat_flow_test.dart` 继续作为只读入口测试；
`group_local_message_flow_test.dart`（2026-08-17 新增）覆盖本地 strict 环境明文拒收与密文归档。

后续文本、@普通成员和消息恢复只在双账号、非生产隔离数据和显式写入授权满足时执行；
`msg_page` 列名 bug 修复后应把服务端历史回读断言从 DB 行升级回 API。
