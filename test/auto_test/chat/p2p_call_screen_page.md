# `page/chat/p2p_call_screen/p2p_call_screen_page.dart`

> 功能点 12 个 | bug 发现 3 / 解决 0 / 待处理 3
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 阻塞 | 解阻塞条件：需第二台真机 + 对端账号在线 | `page/chat/p2p_call_screen/p2p_call_screen_page.dart` | 发起音视频呼叫并邀请对端 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 解阻塞条件：需第二台真机 + 对端账号在线 | `page/chat/p2p_call_screen/p2p_call_screen_page.dart` | 接听来电并建立连接 | 未测 | - | 0 | 0 | 0 | |
| 待复验 | 2026-08-06 | `page/chat/p2p_call_screen/p2p_call_screen_page.dart` | 通话状态机流转与文案切换 | BUG已修待验 | 批次26 | 1 | 0 | 1 | 已修待两端真机：stateTips 全项目无处清空致接通后文案不更新；抽出纯逻辑状态机 CallPhase×CallSignal，14 例单测 + 反证 |
| 待复验 | 2026-08-06 | `page/chat/p2p_call_screen/p2p_call_screen_page.dart` | 对端无应答超时自动结束 | BUG已修待验 | 批次26 | 1 | 0 | 1 | 已修待两端真机：**原判定有误**——60s 超时本就存在，缺口是起臂位置（三种悬挂态收不到 callStateNew）；改到 _initData 统一起臂 |
| 待复验 | 2026-08-06 | `page/chat/p2p_call_screen/p2p_call_screen_page.dart` | 通话结束写入本地通话记录 | BUG已修待验 | 批次26 | 1 | 0 | 1 | 已修待两端真机：ChatMessageAddRequestedEvent 全项目零订阅方，消息从未落库；改为直接 MessageRepo.save + fireData |
| 阻塞 | 解阻塞条件：需第二台真机建立通话 | `page/chat/p2p_call_screen/p2p_call_screen_page.dart` | 切换麦克风静音状态 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 解阻塞条件：需第二台真机建立通话 | `page/chat/p2p_call_screen/p2p_call_screen_page.dart` | 切换摄像头开关状态 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 解阻塞条件：需第二台真机建立通话 | `page/chat/p2p_call_screen/p2p_call_screen_page.dart` | 切换扬声器与前后镜头 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 解阻塞条件：需第二台真机建立通话 | `page/chat/p2p_call_screen/p2p_call_screen_page.dart` | 点挂断键结束通话 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 解阻塞条件：需第二台真机建立视频通话 | `page/chat/p2p_call_screen/p2p_call_screen_page.dart` | 拖拽小窗并交换主次画面 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 解阻塞条件：需第二台真机建立通话 | `page/chat/p2p_call_screen/p2p_call_screen_page.dart` | 最小化为悬浮窗并复原全屏 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 解阻塞条件：需第二台真机 + 可控弱网/拒权限环境 | `page/chat/p2p_call_screen/p2p_call_screen_page.dart` | 展示重连横幅与权限错误横幅 | 未测 | - | 0 | 0 | 0 | |
