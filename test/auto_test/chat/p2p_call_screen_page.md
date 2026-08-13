# `page/chat/p2p_call_screen/p2p_call_screen_page.dart`

> 功能点 12 个 | bug 发现 4 / 解决 2 / 待处理 2
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 回归复测 | 2026-08-08 | `page/chat/p2p_call_screen/p2p_call_screen_page.dart` | 发起音视频呼叫并邀请对端 | 部分通过 | 批次71 | 0 | 0 | 0 | 真机对 leeyi(50075) 发起语音呼叫：呼叫页打开「等待对方接受邀请...」文案正确；⚠️偶现 FlutterWebRTC NPE（SurfaceTextureSurfaceProducer.release null，语音 renderer 未渲染即 dispose，首次触发第二次未复现）已记 BUG#145；接听闭环仍需对端接听 |
| 阻塞 | 解阻塞条件：需第二台真机 + 对端账号在线 | `page/chat/p2p_call_screen/p2p_call_screen_page.dart` | 接听来电并建立连接 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需第二台真机建立实时通话 | `page/chat/p2p_call_screen/p2p_call_screen_page.dart` | 通话状态机流转与文案切换 | 待重验 | 批次77 | 1 | 0 | 1 | 代码侧闭环（CallPhase×CallSignal 纯逻辑状态机，14 单测+反证）。批次77 评估：状态机流转需 A→B 实时通话各阶段（呼叫/振铃/接通/挂断文案），单设备无法构造对端接听，B 类待双机 |
| 回归复测 | 2026-08-08 | `page/chat/p2p_call_screen/p2p_call_screen_page.dart` | 对端无应答超时自动结束 | 已通过 | 批次71 | 1 | 1 | 0 | 复验通过：两次真机呼叫对端均 60s 超时自动结束回会话页（精确计时 23:25:56 发起 → ~23:26:56 自动关闭，logcat 干净）；修复（起臂位置改 _initData）生效，勿回退 |
| 回归复测 | 2026-08-08 | `page/chat/p2p_call_screen/p2p_call_screen_page.dart` | 通话结束写入本地通话记录 | 已通过 | 批次71 | 1 | 1 | 0 | 复验通过：超时结束后 leeyi 会话出现「117 我发送的语音通话」气泡（MessageRepo.save 直写路径生效），勿回退 |
| 回归复测 | 2026-08-08 | `page/chat/p2p_call_screen/p2p_call_screen_page.dart` | 切换麦克风静音状态 | 已通过 | 批次71 | 0 | 0 | 0 | 真机通话页点麦克风开关 checked→未勾选（静音切换生效，无需对端） |
| 阻塞 | 解阻塞条件：需第二台真机建立通话 | `page/chat/p2p_call_screen/p2p_call_screen_page.dart` | 切换摄像头开关状态 | 未测 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-08 | `page/chat/p2p_call_screen/p2p_call_screen_page.dart` | 切换扬声器与前后镜头 | 部分通过 | 批次71 | 0 | 0 | 0 | 真机通话页扩音器开关 checked→未勾选（扬声器切换生效）；前后镜头切换需视频通话+对端另验 |
| 阻塞 | 解阻塞条件：需第二台真机建立通话 | `page/chat/p2p_call_screen/p2p_call_screen_page.dart` | 点挂断键结束通话 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 解阻塞条件：需第二台真机建立视频通话 | `page/chat/p2p_call_screen/p2p_call_screen_page.dart` | 拖拽小窗并交换主次画面 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 解阻塞条件：需第二台真机建立通话 | `page/chat/p2p_call_screen/p2p_call_screen_page.dart` | 最小化为悬浮窗并复原全屏 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 解阻塞条件：需第二台真机 + 可控弱网/拒权限环境 | `page/chat/p2p_call_screen/p2p_call_screen_page.dart` | 展示重连横幅与权限错误横幅 | 未测 | - | 0 | 0 | 0 | |
