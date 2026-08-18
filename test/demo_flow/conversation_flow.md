# DF-03 会话列表 → 未读 → 进入聊天

> 优先级：P0
> 状态：`列表与只读聊天入口通过（Android 真机 + macOS 生产只读）/ 未读写入与双账号闭环待补齐`

## 1. 目标

验证消息、好友和群聊产生的会话能在会话列表中正确展示，未读状态可以进入并清零，用户能从列表进入对应单聊或群聊。

## 2. 前置条件

- [ ] 已有一个隔离测试单聊和一个隔离测试群聊。
- [ ] 使用两个明确授权的测试账号，消息写入只发给测试账号。
- [ ] 测试前记录已有会话和未读数，避免把历史数据当作本轮结果。

## 3. TODO 步骤

- [ ] 打开会话列表并下拉刷新。
  - 预期：列表从服务端同步，头像、标题、最后消息和未读数正确。
  - 页面计划：[conversation_page.md](../auto_test/conversation/conversation_page.md)
- [ ] 使用本地搜索筛选一个单聊和一个群聊。
  - 预期：搜索结果正确，无结果有明确空态。
- [ ] 点击单聊会话进入单聊，再返回列表。
  - 预期：消息已读状态和会话预览更新。
- [ ] 点击群聊会话进入群聊，再返回列表。
  - 预期：群标题、未读状态和最后消息正确。
- [ ] 在隔离测试数据上验证标记已读/未读和置顶/取消置顶。
  - 预期：服务端成功后列表顺序和徽标正确；失败不得静默。

## 4. 验收标准

- [ ] 单聊、群聊均能从列表进入正确页面。
- [ ] 下拉刷新后服务端数据不被旧本地数据覆盖。
- [ ] 未读、置顶和搜索结果与服务端/本地状态一致。

## 5. 当前覆盖与阻塞

- 已有 `integration_test/chat/conversation_test.dart`。
- 2026-08-09：生产 `conversation_api_test.dart` 9/9 顺序通过，覆盖会话列表、离线消息、好友/群列表、搜索、设置和无效收件人边界。
- 2026-08-09：Android 华为真机 `conversation_test.dart --plain-name='会话列表显示与交互'` 生产只读通过 1/1；登录后主 Shell 成功挂载，列表发现 5 个会话项。该结果仅覆盖会话列表入口，不等于单聊/群聊消息双向闭环。
- 2026-08-09：Android 华为真机 `conversation_test.dart --plain-name='搜索入口可访问'` 生产只读通过 1/1；当前内嵌 `conversation_search_input` 可见、可输入并完成搜索入口断言。
- 2026-08-09：Android 华为真机 `single_chat_readonly_test.dart` 生产只读复跑通过；从已有 C2C 会话进入 `ChatPage`，只验证入口和页面挂载，未执行消息写入。
- 2026-08-09：Android 华为真机已分别形成会话列表、会话搜索、已有 C2C 单聊和已有 C2G 群聊只读入口证据；未读清零、置顶/已读写入及双账号消息闭环仍未验收。
- 2026-08-09：修正 `conversation_test.dart` 中过时的“长按弹菜单”假设，当前 UI 实际使用 `Slidable` 侧滑操作；Android 华为真机侧滑面板只读复核 `1/1` 通过，显示“置顶、删除”等菜单项，未点击任何写操作。此前失败仅因测试手势与当前 UI 不匹配，不构成业务失败证据。
- 2026-08-09：本地 widget 回归 `test/unit_test/widget/conversation_list_test.dart --plain-name='右滑会话项出现操作面板 / swipe reveals action pane'` 通过 `1/1`，确认侧滑面板渲染稳定；置顶、已读和删除的服务端写入仍未执行。
- 2026-08-09：生产 `conversation_api_test.dart` 扩展为 `10/10` 通过；置顶、取消置顶、删除、恢复四个写端点以无效 `conversation_id=0` 做参数边界检查，均返回结构化非成功结果。该结果证明错误边界可控，不证明有效会话写入或历史 TSID 契约问题已修复。
- Android 截图因厂商 ROM 的 surface 转换会阻塞运行器，已按测试工具策略跳过；这不影响列表和导航业务断言，但暂不产出截图诊断物。
- 当前页面计划记录过会话置顶/删除接口契约问题；删除会话和清空数据默认不执行。
- 2026-08-17（Demo Flow 复验轮）：
  - 生产只读契约复跑：`.env.pro` 注入执行 `dart test test/unit_test/api/conversation_api_test.dart --concurrency=1` → `8 passed / 2 failed`。会话列表、离线消息、好友/群列表、搜索、设置等只读用例全部通过；失败的 `7.1 C2C 发送接口可达` 与 `8.1 会话写入参数边界` 均在**客户端写门禁**处被拦截（未设 `TEST_ALLOW_API_WRITES`，且生产目标按设计不允许开启），未发出任何 HTTP 请求，属门禁设计行为而非服务端/业务回归；`test/unit_test/` 本轮禁改，仅归类报告。生产只读约束下历史 10/10 记录不可复现，以本轮 8 过 2 拦截为准。
  - macOS 桌面只读复核：`flutter test integration_test/demo_flow/conversation_flow_test.dart -d macos`（APP_ENV=pro + API_BASE_URL/TEST_PHONE/TEST_PASSWORD 自 `.env.pro` 注入）→ `1/1 All tests passed`，登录后进入会话列表，`conversation_search_input` 存在，发现 `4` 个 `Slidable` 会话项。同轮 `flutter test integration_test/app_test.dart -d macos` → `2/2 All tests passed`。
  - 本轮环境注记：macOS 构建一度因本机描述文件缺失失败（`No profiles for 'pub.imboy.macos'`）；通过 `xcodebuild -allowProvisioningUpdates` 重新生成 Mac Team Provisioning Profile 解决（未修改任何仓内文件）。历史"加密 SQLite out of memory"问题本轮未复现。
  - 未读清零、置顶/取消置顶、删除/恢复的**有效会话写入**仍未验收（需隔离测试会话数据与写入授权）；本地后端 uid=4 无会话数据（`conversation/mine` 空列表），无法在本地构造。

## 6. 未来自动化目标

已新增 `integration_test/demo_flow/conversation_flow_test.dart`，生产 Android 真机复核 `1/1` 通过；只验证会话列表、搜索入口和可见会话项，不执行侧滑菜单操作。

后续只读扩展仍可覆盖断网、发送失败或重复点击的失败态；消息写入暂不接入生产流程。
