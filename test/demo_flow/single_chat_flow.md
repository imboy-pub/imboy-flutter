# DF-03 单聊消息闭环

> 状态：`双账号闭环待补齐`
> 优先级：P0
> 类型：好友关系后的核心消息流程

## 1. 目标

验证好友 A、B 能从联系人或会话列表进入单聊，发送文本消息，接收方看到消息，双方重新进入会话后消息仍可见。

## 2. 前置条件

- [ ] 已完成 [friend_flow.md](./friend_flow.md)，或使用已确认的隔离测试好友关系。
- [ ] 使用两个明确授权的测试账号和非生产环境。
- [ ] 发送内容使用无敏感信息的唯一测试文本，例如 `demo-single-chat-<时间>`。
- [ ] 不向真实第三方账号发送消息，不把生产会话当作测试数据。

## 3. TODO 执行步骤

- [ ] A 从联系人进入 B 的用户详情，再点击发消息。
  - 预期：打开单聊页，标题和收件人正确。
  - 页面计划：[people_info_page.md](../auto_test/contact/people_info_page.md)、[chat_page.md](../auto_test/chat/chat_page.md)
- [ ] A 发送一条唯一文本消息。
  - 预期：发送按钮、消息气泡、发送状态和服务端成功日志均正常。
- [ ] B 打开会话列表并进入 A 的单聊。
  - 预期：会话未读状态正确，消息内容和发送者正确。
  - 页面计划：[conversation_page.md](../auto_test/conversation/conversation_page.md)
- [ ] B 回复一条唯一文本消息，A 返回会话查看。
  - 预期：双向消息顺序、时间和发送者一致。
- [ ] 双方退出聊天页后重新进入。
  - 预期：消息仍从本地/服务端恢复，不因页面重建丢失。

## 4. 验收标准

- [ ] 联系人入口和会话入口都能进入同一单聊。
- [ ] A→B、B→A 各至少一条消息有服务端成功证据。
- [ ] 未读数、会话预览和消息内容一致。
- [ ] 断网、发送失败或重复点击时不会把失败消息误报为已送达。

## 5. 当前已有覆盖与阻塞

- 已有局部可执行测试：`integration_test/chat/conversation_test.dart`、`e2e_chat_test.dart`。
- 2026-08-09：Android 华为真机生产 `integration_test/chat/single_chat_readonly_test.dart` 复跑通过；从已有 `C2C` 会话进入 `ChatPage`，未输入、未发送消息。首次运行发现 `ChatPageState._initChat` 在卸载后访问 `context`，已改为使用 `State.mounted` 并复验通过。
- `integration_test/chat/group_chat_test.dart` 可作为消息发送和等待策略参考，但不替代单聊流程。
- 双账号消息会产生通知和真实数据写入，只能对授权测试账号执行。
- 2026-08-09：生产 `conversation_api_test.dart` 仅验证无效收件人边界，未向第二账号发送真实消息；Android 真机主 Shell 和已有 C2C 只读入口已形成稳定通过证据，双账号消息与重进恢复仍阻塞。

## 6. 未来自动化目标

已新增 `integration_test/demo_flow/single_chat_flow_test.dart`，生产 Android 真机复核 `1/1` 通过；从已有 C2C 会话进入 `ChatPage`，未输入或发送消息。

后续文本消息和会话恢复只在双账号、非生产隔离数据和显式写入授权满足时执行；语音、视频、E2EE 异常恢复等高条件功能另立流程。
