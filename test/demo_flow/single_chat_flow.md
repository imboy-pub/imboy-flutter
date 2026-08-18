# DF-03 单聊消息闭环

> 状态：`双账号双端消息闭环通过（2026-08-11 r14 历史证据；2026-08-17 无第二设备未重跑）/ 服务端历史归档为空 / E2EE 未覆盖`
> 优先级：P0
> 类型：好友关系后的核心消息流程

## 1. 目标

验证好友 A、B 能从联系人或会话列表进入单聊，发送文本消息，接收方看到消息，双方重新进入会话后消息仍可见。

## 2. 前置条件

- [x] 使用已有且已确认的测试好友关系（不在本次 flow 中重做好友申请）。
- [x] 使用两个明确授权的测试账号；本次生产写入仅限用户授权的 `117@imboy.pub` 与 `118@imboy.pub`。
- [x] 发送内容使用无敏感信息的唯一测试文本：`P0-DUAL-A-1786290028-r5`、`P0-DUAL-B-1786290028-r5`。
- [x] 未向真实第三方账号发送消息；仅使用用户授权的生产测试会话。

## 3. TODO 执行步骤

- [x] A 从已有 C2C 会话进入单聊页。
  - 预期：打开单聊页，标题和收件人正确。
  - 页面计划：[people_info_page.md](../auto_test/contact/people_info_page.md)、[chat_page.md](../auto_test/chat/chat_page.md)
- [x] A 发送一条唯一文本消息。
  - 预期：发送按钮、消息气泡、发送状态和服务端成功日志均正常。
- [x] B 通过 WebSocket 收到 A 的消息并进入同一单聊。
  - 预期：会话未读状态正确，消息内容和发送者正确。
  - 页面计划：[conversation_page.md](../auto_test/conversation/conversation_page.md)
- [x] B 回复一条唯一文本消息，A 收到 B 的消息。
  - 预期：双向消息顺序、时间和发送者一致。
- [x] 双方退出聊天页后重新进入，并在本地 SQLite 中核对两条标记消息。
  - 预期：消息仍从本地/服务端恢复，不因页面重建丢失。

## 4. 验收标准

- [ ] 联系人入口和会话入口都能进入同一单聊。
- [x] A→B、B→A 各至少一条消息收到 `C2C_SERVER_ACK`，本地发送状态为 `sent`。
- [x] 双端退出并重进后，两条唯一标记消息仍可在本地消息库核对。
- [ ] 断网、发送失败或重复点击时不会把失败消息误报为已送达。

## 5. 当前已有覆盖与阻塞

- 已有局部可执行测试：`integration_test/chat/conversation_test.dart`、`e2e_chat_test.dart`。
- 2026-08-09：Android 华为真机生产 `integration_test/chat/single_chat_readonly_test.dart` 复跑通过；从已有 `C2C` 会话进入 `ChatPage`，未输入、未发送消息。首次运行发现 `ChatPageState._initChat` 在卸载后访问 `context`，已改为使用 `State.mounted` 并复验通过。
- `integration_test/chat/group_chat_test.dart` 可作为消息发送和等待策略参考，但不替代单聊流程。
- 双账号消息会产生通知和真实数据写入，只能对授权测试账号执行。
- 2026-08-09：此前两次生产双端联调曾因接收端 WebSocket 尚未建立就继续发送、以及环境变量未正确设置而失败，不能作为通过证据。随后修正 runner：WebSocket 未连接时拒绝发送，并正确使用 `APP_ENV=pro`；使用 run id `1786290028` 复跑通过。macOS 与 Android 真机均建立 WebSocket；macOS 发送 `P0-DUAL-A-1786290028`、Android 回复 `P0-DUAL-B-1786290028`，双方各自获得对应 `C2C_SERVER_ACK`，接收端实时收到对方标记，双方退出并重进后在本地 SQLite 核对 A/B 两条消息。该结果计为“明文双账号消息闭环通过”。
- 2026-08-10：针对启动时序重跑 `1786290028-r5`；先让 Android 真机进入等待状态，再启动 macOS，并显式注入 `WS_URL_OVERRIDE`。macOS/117 与 Android/118 均 `1/1 All tests passed`：A/B 唯一标记完成跨设备实时收发，双方各自获得 `C2C_SERVER_ACK`，退出并重进后在本地 SQLite 核对两条消息。该结果计为“明文双账号消息闭环通过”。
- 2026-08-10：应现场复核要求重新启动 macOS/117 与 Android/118；首轮因测试入口缺少 `TEST_WS_URL` 参数提前失败，修正后第二轮 run id `20260810-072416-r2` 两端均 `1/1 All tests passed`。macOS/117 sender 与 Android/118 receiver 完成唯一标记双向收发、服务端 ACK、退出重进和本地消息回读；日志归档于 `/Users/leeyi/project/imboy-test-report/dual-live-20260810-072416-r2`。
- 2026-08-10：按 iPhone 8/117 ↔ Android/118 重新现场验证，run id `dual-live-20260810-092943-iphone8-r2`。iPhone 8 的 Xcode 构建和 App 安装均完成，但启动阶段被设备拒绝：底层日志返回 `invalid code signature, inadequate entitlements or its profile has not been explicitly trusted by the user`；后续核验确认 `codesign --verify --deep --strict` 有效、bundle ID 与 profile 的 application identifier 匹配、iPhone 8 UDID 在 profile 中且 profile 尚未过期，因此当前剩余原因是设备侧信任/启动状态。Flutter 集成测试随后因 Dart VM Service 未建立而 `Some tests failed`。Android/118 已启动并进入等待，但因 iPhone 8 未进入测试程序，未形成双端消息闭环；本次不计为通过。报告：`/Users/leeyi/project/imboy-test-report/dual-live-20260810-092943-iphone8-r2/`。
- 2026-08-10：按用户要求再次执行 `flutter install --debug` 安装 iPhone 8，命令退出码为 `0`，旧版本卸载和新版本安装均完成；随后再次执行普通 Debug 启动，仍在 `Installing and launching` 后返回 `Error launching application on iPhone 8`。因此当前结论细化为“可安装、不可启动”，消息闭环仍未执行。
- 2026-08-10：收到继续指令后再次执行 iPhone 8 安装，退出码仍为 `0`；随后重新构建并启动，仍在 `Installing and launching` 后返回 `Error launching application on iPhone 8`，没有 Dart VM Service 或测试入口证据。结论未改变：可安装、不可启动。
- 2026-08-10：改用 iPhone 16e/117 与 Android/118 复核。run `dual-live-20260810-104148-iphone16e-r1` 中 iPhone 16e 构建、安装完成，但集成测试加载阶段 Dart VM 连接被 reset；Android/118 已连接 WebSocket 并等待，未进入业务断言。run `dual-live-20260810-104641-iphone16e-r2` 增加 `--no-dds` 后仍在 VM 握手前断开。基础 `integration_test/app_test.dart` 在 iPhone 16e 上也以同样的 VM 连接关闭失败；用 `devicectl --console` 直接启动已安装 Debug 包时，设备明确返回 `Cannot create a FlutterEngine instance in debug mode without Flutter tooling` 并以 `signal 11` 退出，因此不能把非 Flutter 工具的直接启动结果当作 App 稳定运行证据。当前阻塞是 iPhone 16e Debug/VM 通道，未形成消息业务闭环。报告：`/Users/leeyi/project/imboy-test-report/dual-live-20260810-104148-iphone16e-r1/`、`/Users/leeyi/project/imboy-test-report/dual-live-20260810-104641-iphone16e-r2/`。
- 本次运行的服务端历史接口返回成功但归档列表为空，故服务端历史证据按 `historyUnavailable` 记录；重进恢复证据来自双端本地消息库，不把空历史接口误报为服务端归档通过。
- 本次消息使用 `e2ee:false` 明文路径；另有既有 `crypto_outbox` 表缺失告警和旧 ACK 噪声，但两条新业务消息仍获得服务端 ACK 并完成本地状态核对。该结果不证明 E2EE 双设备握手、密文收发或密钥恢复，E2EE 仍须单独完成 P0 验收。
- 2026-08-09：生产 `conversation_api_test.dart` 仅验证无效收件人边界；双账号写入仅限本次已授权测试账号和唯一文本标记，不作为普通 API 契约通过的替代。
- 2026-08-17（Demo Flow 复验轮，本轮无第二设备）：
  - **双端实时闭环未重跑**：仅 macOS 桌面可用（Android 真机未连接、iPhone 16e 离线），维持引用 2026-08-11 r14 历史 PASS 证据（run id `dual-20260811-mac117-118a-r14`，macOS/117 ↔ Android/118 明文消息闭环、双方 `C2C_SERVER_ACK`、重进本地回读）。本轮未新增双端证据。
  - macOS 桌面只读入口复核：`flutter test integration_test/demo_flow/single_chat_flow_test.dart -d macos`（APP_ENV=pro + `.env.pro` 注入，生产只读）→ `1/1 All tests passed`；从已有 C2C 会话进入 `ChatPage`，未输入或发送消息。
  - 本地单端发送补充（探查，未形成发送 PASS）：本地后端（127.0.0.1:9800，alpha.27）以 uid=4 登录成功并完成 WS 握手（`imboy.v2` 子协议 + Bearer token）；`GET /api/v1/app/policy` 返回 **`e2ee_mode=required`**，向 AI 小助手（agent uid `103107938360756224`，免好友校验）发送明文 C2C 被部署级明文门结构化拒收：`policy_violation / encrypted_message_required`（msg 帧含正确 `id` 回显）。错误边界链路验证：`type` 小写被拒 `unknown_message_type` → 改大写 `C2C` 后到达策略门。**本地明文发送阻塞于本地部署策略（需 E2EE 加密，超出本轮补充证据范围）**；本地亦无第二可登测试账号（117 本地不存在、注册被 License 配额 402 拦截）。
  - 本轮环境注记：生产只读 `conversation_api_test.dart` 复跑 8 过 2 拦截（客户端写门禁设计行为，详见 conversation_flow.md 2026-08-17 条目）；macOS 构建签名问题已通过重新生成 Mac 描述文件解决。

## 6. 未来自动化目标

已新增 `integration_test/demo_flow/single_chat_flow_test.dart`，生产 Android 真机复核 `1/1` 通过；从已有 C2C 会话进入 `ChatPage`，未输入或发送消息。

后续文本消息和会话恢复只在双账号、非生产隔离数据和显式写入授权满足时执行；语音、视频、E2EE 异常恢复等高条件功能另立流程。
