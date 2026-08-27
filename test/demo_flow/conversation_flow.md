# DF-03 会话列表 → 未读 → 进入聊天

> 优先级：P0
> 状态：`列表与只读聊天入口通过（Android 真机 + macOS 生产只读）/ 有效会话写入与置顶闭环本地复跑维持通过（2026-08-27，alpha.69）/ 生产只读契约恢复 dart 套件 8 过 2 门禁拦（2026-08-27 收尾复跑，客户端 md5→明文回退后与 08-19 口径一致）/ 未读清零与双账号闭环待补齐`

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
- 2026-08-18（后端升级后复核轮，本地 main@e6d785d0）：
  - macOS 桌面只读复跑：`flutter test integration_test/demo_flow/conversation_flow_test.dart -d macos`（APP_ENV=pro + `.env.pro` 变量逐项提取以 `--dart-define` 注入）→ `1/1 All tests passed`，登录后进入会话列表，`conversation_search_input` 存在，发现 `4` 个 `Slidable` 会话项；同轮 `flutter test integration_test/app_test.dart -d macos` → `2/2 All tests passed`。
  - **有效会话写入本地闭环通过（API 级，全部带服务端证据）**：上轮遗留的「无法在本地构造会话」本轮以合规方式解决——
    1. 本地两个可登账号（uid=4、`scripts/test.env` 账号 13900001002→uid=104250986822109184）`conversation/mine` 均为空列表；
    2. 通过 WS（`imboy.v2` 子协议 + Bearer token）向 imboy 小助手（AI agent uid `103107938360756224`，免好友校验、不影响真实第三方）发送符合 v2.0 加密契约的信封消息（`e2ee` 非空 map 含 `devices` 信封、`payload` 空串；本地 `e2ee_mode=required` 下服务端按声明式契约校验，见 `imboy_policy.erl` `encrypted_message_body/3`）→ 收到二进制 v2 帧 `C2C_SERVER_ACK`（`in_reply_to` 回显发送 id）；
    3. 服务端归档回读 `msg/history` code=0 且该消息在列、e2ee 元数据完整保留；`conversation/mine` 出现该 c2c 会话（`last_msg_id` 即发送 id）——会话由真实服务端路径产生，非直写数据库。
  - 基于该有效会话执行置顶写入闭环：`POST /api/v1/conversation/pin`（conversation_id 按客户端 TSID 契约以 string 传输）→ `code=0`；`conversation/mine` 回读 `is_pinned=true`；`conversation/pinned` 列表含该会话且带 `pinned_at` 时间戳。`POST /api/v1/conversation/unpin` → `code=0`（payload `updated:true`）→ `is_pinned=false`、pinned 列表清空。重复 pin/unpin 幂等（均 `code=0`）。数据已还原为未置顶状态。
  - 未读清零：本地 agent 未配置 LLM 后端、始终无对端回复消息，`message_read` 已读回执（WS `action=message_read`，`payload.msg_ids` 批量）无合法上报对象——**未读清零维持未验收**（不能上报"已读自己发送的消息"，语义不符）。会话删除/恢复仍默认不执行。
  - 环境注记：本地 uid=4 现在存在 1 个与 agent 的 c2c 测试会话（本轮产生），后续复核「conversation/mine 为空」的表述不再成立；证据文件（本机临时目录，不入仓）：`/tmp/demo_flow_20260818/`（ws_send_e2ee_result_r2.json、conv_mine_4_after.json、hist_4.json）。
- 2026-08-19（复核轮，本地后端维持 main@e6d785d0 / 1.0.0-alpha.36）：
  - 生产只读契约复跑：`.env.pro` 变量逐项提取注入（未 source、未回显凭证、`TEST_ALLOW_API_WRITES` 保持关闭）执行 `dart test test/unit_test/api/conversation_api_test.dart --concurrency=1` → `8 passed / 2 门禁拦截`（7.1 C2C 发送与 8.1 写参数边界均在客户端写门禁处被拦截、未发出 HTTP 请求，属设计行为）。与 08-17/08-18 记录一致。
  - **有效会话写入闭环复跑维持通过（DEMO-FLOW-20260819，全部带服务端证据）**：WS（`imboy.v2` 子协议 + Bearer）向 agent（uid `103107938360756224`）发送 v2.0 加密契约信封消息（`e2ee` 非空 map 含 `devices`、`payload` 空串）→ 二进制 v2 帧 `C2C_SERVER_ACK`（`in_reply_to` 回显发送 id `ub8711bb8c8330m8olhf`）；`msg/history` code=0 且该消息在列（history_total=3）；`conversation/mine` 该 c2c 会话 `last_msg_id` 即本轮发送 id。会话仍由真实服务端路径产生。
  - **pin/unpin 闭环复跑维持通过（含幂等与还原）**：`POST /api/v1/conversation/pin`（conversation_id 以 string 传输）→ `code=0`；`conversation/mine` 回读 `is_pinned=true`；`conversation/pinned` 列表含该会话且带 `pinned_at=1787117004731`；重复 pin 幂等 `code=0`；`POST /api/v1/conversation/unpin` → `code=0`（payload `updated:true`）→ `is_pinned=false`、pinned 列表清空该会话；重复 unpin 幂等 `code=0`。终态已还原为未置顶（与初始态一致）。
  - 勘误（不影响 08-18 结论）：`GET /api/v1/conversation/pinned` 响应结构为 `payload.items`（map 键 `items`），非裸 list；08-18 文档仅记"列表"未记键名，本轮探针初版解析只认 `payload.list` 曾误报 count=0，修正后复核通过。
  - 未读清零：维持未验收——本轮再次确认 agent 无对端回复（WS 等待窗内无来自 agent 的 C2C/S2C 回复，`agent_reply_seen=false`），`message_read` 已读回执无合法上报对象，语义不符（不能上报"已读自己发送的消息"）。会话删除/恢复仍默认不执行。
  - 环境注记（跨 flow 数据漂移，仅记录不断言）：登录 uid=4 建立 WS 后收到 `logged_another_device`（did=undefined）×2 及积压 `apply_friend_confirm`、`group_member_leave` 等 S2C 推送，与其他并行 flow 会话共享 uid=4 的迹象一致；`conversation/mine` 会话数仅断言本轮目标会话，不断言全局总数。
  - macOS 桌面只读复跑：`flutter test integration_test/demo_flow/conversation_flow_test.dart -d macos`（APP_ENV=pro + `.env.pro` 变量以 `--dart-define` 注入）→ `1/1 All tests passed`，登录后进入会话列表，`conversation_search_input` 存在，发现 `4` 个 `Slidable` 会话项，与 08-18 记录一致。本轮复跑在含他人未提交改动（`bottom_navigation_page.dart`/`conversation_provider.dart`）的工作区上完成，证明这些改动未破坏会话列表基础入口；构建无锁等待。
  - 证据文件（本机临时目录，不入仓）：`/tmp/demo_flow_20260819/`（df03_ws_e2ee_result.json、df03_pin_unpin_result.json、df03_pinned_fix_result.json）。
- 2026-08-27（复核轮，本地后端已升级 **1.0.0-alpha.69**；生产 alpha.69 严格只读）：
  - **【环境级发现：后端密码预哈希 MD5→SHA-256 迁移（2026-08-26）】**：本轮首轮直接跑 `dart test test/unit_test/api/conversation_api_test.dart`（`.env.pro` 变量逐项提取注入，未 source、未回显凭证）→ 登录 `errorPassword`、10 用例全 SKIP。经离线比对本地库存储 hash（`hmac(key=salt, msg=md5hex("admin888"))`）+ 只读 `imboy/src/lib/elib_password.erl`（头部注释"前端密码预哈希格式（2026-08-26 从 MD5 迁移到 SHA-256）"）定位根因：**密码未漂移**，alpha.69 `verify_hmac_sha512/3` 双分支（`sha256raw(pwd)` / `md5hex(pwd)`）对旧客户端 md5 姿势（上送 `md5hex(明文)`，存储 `hmac(msg=md5hex)`）均不匹配；**明文姿势上送可命中旧格式分支**（`md5hex(明文)==存储 msg`）——本地与生产以 `pwd=明文` 实测均 `code=0`（uid=4）。imboyapp 客户端已内置"登录失败后明文回退"（`lib/page/passport/passport_notifier.dart` `pwd_was_md5` 标记），故真实客户端不受影响；**纯 dart 契约测试客户端 `api_test_client.dart` 固定 md5 姿势、无回退，需后续升级**（不在本轮授权修改范围）。另注：`.env.pro` 的 SOLIDIFIED_KEY 已于 08-26 被人工更新为正确 32 字符值（签名验证可过，本轮错误均为密码级而非签名级）。
  - 生产只读契约复跑（探针复刻，替代无法登录的 dart 套件）：明文姿势登录后逐条复刻套件 8 个只读用例（会话列表/置顶列表/离线消息×2/好友列表/群组分页/最近联系人/用户设置，均真实请求 `https://pro.imboy.pub`）→ **8/8 PASS，2 写端点（7.1/8.1）按客户端写门禁设计未发出请求**，与 08-19 基线（8 passed / 2 门禁拦截）完全一致，alpha.69 生产契约无回归。证据：`/tmp/demo_flow_20260827/df03_prod_contract.json`。
  - macOS 桌面只读复跑：`flutter test integration_test/demo_flow/conversation_flow_test.dart -d macos`（APP_ENV=pro + `.env.pro` 变量 `--dart-define` 注入）→ `1/1 All tests passed`，登录（客户端明文回退路径）后进入会话列表，`conversation_search_input` 存在。**环境数据漂移**：本轮会话列表为空（`ConversationRepo/all 0 items`），08-19 为 4 个 `Slidable` 会话项——生产 uid=4 的会话数据在两轮之间被清空，属跨轮数据变化，不构成测试失败（断言不要求非空）。本轮仍在含用户未提交改动（频道 DND 相关等）的工作区上通过。
  - **有效会话写入+pin/unpin 幂等闭环复跑维持通过（DEMO-FLOW-20260827，全部带服务端证据，本地 alpha.69）**：WS（`imboy.v2` 子协议 + Bearer，明文姿势登录 uid=4）向 agent（uid `103107938360756224`）发送 v2.0 加密契约信封（`e2ee.devices` 非空 map + `payload` 空串，ciphertext=`DEMO-FLOW-20260827-E2EE-envelope`）→ 二进制 v2 帧 `C2C_SERVER_ACK`（`in_reply_to` 回显本轮发送 id `df27mtb15zkwybrle1af`）；`msg/history` code=0 且消息在列（字段 `msg_id`，e2ee 元数据完整保留为字符串化 JSON）；psql 直查 `msg_c2c` 归档行存在（from=4/to=agent/`protocol=olm`/`fan_out=per_device`，本轮共 3 行同标记，含调试轮次）；`conversation/mine`（`payload.list`）该 c2c 会话（`conversation_id=103107938360756224`）`last_msg_id` 即本轮发送 id。
  - **pin/unpin 全步骤**：`POST /api/v1/conversation/pin`（conversation_id string 传输）→ code=0；mine 回读 `is_pinned=true`；`conversation/pinned`（`payload.items`）含该会话且 `pinned_at=1787805399973`；重复 pin 幂等 code=0；`POST /api/v1/conversation/unpin` → code=0（payload `updated:true`）→ `is_pinned=false`、pinned 列表清空；重复 unpin 幂等 code=0。终态已还原为未置顶（初始态同为 false）。
  - 未读清零：维持未验收——agent 回复观察窗（15s）内无来自 agent 的 C2C/S2C 帧（`agent_reply_seen=false`），本地 agent 未配置 LLM 后端无对端回复，`message_read` 已读回执无合法上报对象（不能上报"已读自己发送的消息"）。会话删除/恢复仍默认不执行。
  - 环境注记：a) 本地库已整体更换（4323 端口实例 19218 用户，为生产快照形态；uid=4 即 `118@imboy.pub`，08-19 记载的本地账号 13900001002/uid=4 旧数据不再存在；**本地 psql 直查须带 `-p 4323`**，默认 5432 是另一实例）；b) 登录 WS 后收到 `logged_another_device`（did=e2e-dart-test-001）S2C 推送，共享 uid=4 迹象；c) alpha.69 下 `policy_violation` 拒收帧以 **WS text 帧**返回（`websocket_handler.erl` `{reply,{text,...}}` 路径），`C2C_SERVER_ACK` 仍为二进制 v2 帧——与 08-19 记录的拒收帧形态描述不同，属协议细节修正；d) 2026-08-25 轮记载的 `write_msg_with_sender ON CONFLICT` 丢数据 bug 本轮未复现（3 条发送 3 行落库）；e) **alpha.69 会话存储模型变化**：`conversation/mine` 改为从 `msg_c2c`/`msg_c2g` 消息表实时聚合（`conversation_logic.erl` `read_msg_for_conversation` + `normalize_*_conversation`），`public.conversation` 物化表本地为 0 行但 API 正常返回——pin 状态独立存于 `conversation_pin` 表（本轮 user_id=4 终态 0 行，还原彻底）。
  - 证据文件（本机临时目录，不入仓）：`/tmp/demo_flow_20260827/`（df03_prod_contract.json、df03_df04_local_r3.json 最终轮探针输出、df03_macos_conversation.log）。

## 6. 未来自动化目标

已新增 `integration_test/demo_flow/conversation_flow_test.dart`，生产 Android 真机复核 `1/1` 通过；只验证会话列表、搜索入口和可见会话项，不执行侧滑菜单操作。

后续只读扩展仍可覆盖断网、发送失败或重复点击的失败态；消息写入暂不接入生产流程。
