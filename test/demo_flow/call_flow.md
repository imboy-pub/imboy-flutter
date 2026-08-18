# DF-21 单聊 → 音视频通话 → RTC 房间

> 优先级：P1
> 状态：`本地状态机/信令协议通过（2026-08-18 复跑 51 项），生产 RTC 入口可达（902），本地 join 缺 LiveKit 配置阻塞（2026-08-18 复现维持），双端媒体阻塞`
> 条件：双端真机/媒体环境
> 最近验证：2026-08-18

## 1. 目标

验证好友可以从单聊发起音视频通话，双方进入 RTC 房间，接通后能看到媒体状态，并能安全结束通话。

## 2. 前置条件

- [ ] A、B 是明确授权的测试账号，且使用两台真机或受支持的双端环境。
- [ ] 摄像头、麦克风、网络和 RTC 服务均已准备。
- [ ] 不呼叫真实第三方，不在生产环境做媒体验证。

## 3. TODO 步骤

- [ ] A 从单聊发起音频通话。
  - 预期：B 收到来电，接通/拒绝/取消状态正确。
  - 页面计划：[p2p_call_screen_page.md](../auto_test/chat/p2p_call_screen_page.md)、[chat_page.md](../auto_test/chat/chat_page.md)
- [ ] A 从单聊发起视频通话。
  - 预期：权限申请、预览、接通和挂断状态正确。
- [ ] 双端进入 RTC 房间，验证连接、静音、摄像头切换和退出。
  - 预期：连接状态与媒体状态真实一致，异常断线有反馈。
  - 页面计划：[rtc_room_page.md](../auto_test/chat/rtc_room_page.md)
- [ ] 验证对方拒绝、超时、网络中断和重复点击。
  - 预期：双方最终回到可用聊天状态，不残留假通话状态。

## 4. 验收标准

- [ ] 呼叫、接听、拒绝、挂断和异常断线均有双端证据。
- [ ] 不能用单端按钮变化证明媒体双向可用。
- [ ] 摄像头/麦克风权限和错误提示清楚。

## 5. 当前覆盖与阻塞

- 当前只有页面级计划和部分通话页面入口，双端媒体闭环尚未纳入 demo-flow。
- 必须使用真机和可用 RTC 服务；无双端条件时标记 `阻塞`。
- 2026-08-09：本地呼叫状态机、信令协议和 RTC 控件检查通过；没有第二台授权真机及可验证媒体服务，呼叫接通、双向音视频和断线恢复保持 `BLOCKED`。
- 单端按钮、状态变化或 RTC 控件存在不能替代双端媒体证据。
- 2026-08-17（DEMO-FLOW-20260817）：本地无头复跑 `p2p_call_state_machine_test.dart + rtc_room_test.dart + webrtc_protocol_alignment_test.dart + component/webrtc/`（含信令模型）合计 `51` 项全部通过，覆盖呼叫状态机、RTC 房间控件、WebRTC 协议对齐与信令消息构造。
- 2026-08-17（DEMO-FLOW-20260817）：生产 `rtc_room_api_test.dart` 复跑——`rtc/room/join` 属 POST 入场券签发，生产写入红线（含 RTC 房间创建）下两个 join 用例被 `ApiTestClient` 写门禁在本地拦截（`Bad state: API 写入测试已阻止`），未向生产发出请求；该拦截是红线正确生效，不是回归。改用匿名负向探测：`POST https://pro.imboy.pub/api/v1/rtc/room/join`（无凭证）→ HTTP `200` + `{"code":902,"msg":"签名验证失败"}`，证明 alpha.36 上 RTC 入口路由可达且签名中间件正常（历史 502 修复维持），未进入业务逻辑、无写入。
- 2026-08-17（DEMO-FLOW-20260817）：本地 `rtc_room_api_test.dart`（`TEST_ALLOW_API_WRITES=true` + `.env.local` 签名）结果 `1` 通过 / `1` 失败：错误路径（非法 `target_id` → 业务错误）通过，证明路由与参数校验正常；群成员 `join` 失败根因已定位——本地后端 `config/sys.local.config` 无 `livekit` 配置段，`rtc_room_logic.erl` `build_grant/4` 的 `config_ds:env(livekit, #{})` 返回 `#{}` 后 `#{ws_url := WsUrl, ...}` 模式匹配崩溃 → HTTP 500。属本地媒体服务配置缺失（环境性阻塞），非客户端或路由回归；按约束不干预本地后端进程与配置。
- 双端媒体通话（真实呼叫、接听、双向音视频、断线恢复）保持 `BLOCKED`：无第二台授权设备、无 TURN/LiveKit 媒体环境。
- 2026-08-18（DEMO-FLOW-20260818）：本地无头复跑同上四个测试文件（`p2p_call_state_machine_test.dart` +
  `rtc_room_test.dart` + `webrtc_protocol_alignment_test.dart` + `component/webrtc/signaling_models_test.dart`，
  `flutter test --concurrency=1`）合计 `51` 项全部通过，与 08-17 结果一致（注意：这四个文件依赖
  flutter_test，必须用 `flutter test`，`dart test` 会因 flutter_test 加载失败全红）。
- 2026-08-18（DEMO-FLOW-20260818）：livekit 配置缺失复核维持——`config/sys.local.config` 与运行节点实际加载的
  `_rel/imboy/releases/1.0.0-alpha.36/sys.config` 中 grep `livekit` 均 0 处（`config/sys.config` 里的
  dev 段被 local 覆盖，不生效）。本地 `rtc_room_api_test.dart`（`TEST_ALLOW_API_WRITES=true` + `.env.local`
  签名）复跑结果 `1` 过 / `1` 失败，与 08-17 完全一致：非法 `target_id` 业务错误路径通过；群成员 `join`
  仍 `code=500 non_json_response`（`rtc_room_logic.erl` `build_grant/4` 因无 livekit 配置崩溃），环境性阻塞维持。

## 6. 未来自动化目标

建议新增 `integration_test/demo_flow/call_flow_test.dart`，优先覆盖呼叫状态机；媒体双向质量保留专用真机验收。
