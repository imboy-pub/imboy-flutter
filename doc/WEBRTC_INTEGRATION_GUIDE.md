# WebRTC 新架构集成指南

> WebRTC 优化方案 - 新架构集成文档
> 最后更新：2026-02-14

---

## 目录

1. [架构概览](#架构概览)
2. [ICE 配置优化](#ice-配置优化)
3. [快速开始](#快速开始)
4. [迁移步骤](#迁移步骤)
5. [API 参考](#api-参考)
6. [常见问题](#常见问题)
7. [故障排查](#故障排查)

---

## 架构概览

### 技术栈

| 组件 | 技术 | 说明 |
|------|------|------|
| 前端 | flutter_webrtc ^1.3.0 | 跨平台 WebRTC 实现 |
| 信令 | WebSocket | 复用现有连接 |
| 后端 | Erlang (webrtc_ws_logic.erl) | 信令转发 |
| TURN/STUN | eturnal (Erlang) | NAT 穿透服务 |

### 架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                      Flutter 客户端                              │
│  flutter_webrtc: ^1.3.0                                         │
│  lib/page/chat/p2p_call_screen/                                 │
│  lib/component/webrtc/                                          │
└──────────────────────────┬──────────────────────────────────────┘
                           │ WebSocket 信令
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Erlang 后端                                 │
│  webrtc_ws_logic.erl (信令转发)                                  │
│  user_ds.erl (TURN 凭证生成)                                     │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                   eturnal TURN/STUN 服务器                       │
│  端口: 3478 (TCP/UDP), 50000-50200 (中继)                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## ICE 配置优化

### ⚠️ 关键修复：NAT 穿透问题

**问题**：移动网络（联通、移动）经常连接不通，局域网正常。

**原因**：移动运营商使用对称型 NAT，STUN 无法穿透，必须依赖 TURN 中继。

### ICE 配置最佳实践

```dart
// p2p_call_screen_provider.dart
Future<Map<String, dynamic>?> _getIceConf() async {
  final turnCredential = await userApi.turnCredential();

  // 解析 TURN URL 并生成 TCP 版本
  final turnUrls = turnCredential['turn_urls'];
  String turnTcpUrl = '';
  if (turnUrls is String && turnUrls.contains('udp')) {
    turnTcpUrl = turnUrls.replaceAll('udp', 'tcp');
  }

  return {
    'iceServers': [
      // STUN 服务器
      {'urls': turnCredential['stun_urls']},
      // Google STUN 作为备用
      {'urls': 'stun:stun.l.google.com:19302'},
      // TURN UDP
      {
        'urls': turnUrls,
        'username': turnCredential['username'],
        'credential': turnCredential['credential'],
      },
      // 🔥 TURN TCP（关键：用于 UDP 被封锁的场景）
      if (turnTcpUrl.isNotEmpty)
        {
          'urls': turnTcpUrl,
          'username': turnCredential['username'],
          'credential': turnCredential['credential'],
        },
    ],
    // 🔥 关键：从 0 改为 10，确保 ICE 候选充分收集
    'iceCandidatePoolSize': 10,
    'iceTransportPolicy': 'all',
    'bundlePolicy': 'balanced',
    'rtcpMuxPolicy': 'require',
    'sdpSemantics': 'unified-plan',
  };
}
```

### ICE 候选类型说明

| 类型 | 说明 | 使用场景 |
|------|------|----------|
| `host` | 本地 IP 候选 | 局域网直连 |
| `srflx` | 服务器反射候选 | STUN 穿透成功 |
| `prflx` | 对等反射候选 | NAT 穿透成功 |
| `relay` | TURN 中继候选 | NAT 穿透失败时使用 |

### ICE 连接状态处理

```dart
pc.onIceConnectionState = (RTCIceConnectionState state) {
  switch (state) {
    case RTCIceConnectionState.RTCIceConnectionStateConnected:
      // 连接成功
      _iceRestartCount = 0;
      break;

    case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
      // 断开后等待 5 秒尝试恢复
      Future.delayed(Duration(seconds: 5), () {
        if (pc.iceConnectionState == RTCIceConnectionStateDisconnected) {
          pc.restartIce();
        }
      });
      break;

    case RTCIceConnectionState.RTCIceConnectionStateFailed:
      // ICE 失败时尝试重启（最多 3 次）
      if (_iceRestartCount < 3) {
        _iceRestartCount++;
        pc.restartIce();
      } else {
        // 超过重试次数，通知连接失败
        onCallStateChange?.call(session, WebRTCCallState.callStateBye);
      }
      break;

    default:
      break;
  }
};
```

---

## 快速开始

### 旧架构问题

```
┌─────────────────────────────────────────────────────────┐
│                    旧架构 (存在问题)                      │
├─────────────────────────────────────────────────────────┤
│  • 全局 webRTCSessions Map → 内存泄漏风险               │
│  • 分散的状态管理 → 竞态条件                            │
│  • 缺少重连机制 → 连接不稳定                            │
│  • 无质量监控 → 用户体验差                              │
│  • 信令格式不统一 → 兼容性问题                          │
└─────────────────────────────────────────────────────────┘
```

### 新架构设计

```
┌─────────────────────────────────────────────────────────────────┐
│                        新架构 (模块化)                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────┐    ┌──────────────────┐                  │
│  │ ConnectionManager│───▶│ WebRTCConnection │                  │
│  │   (Singleton)    │    │  (生命周期管理)   │                  │
│  └──────────────────┘    └────────┬─────────┘                  │
│                                   │                             │
│          ┌────────────────────────┼──────────────────┐         │
│          ▼                        ▼                  ▼         │
│  ┌──────────────┐      ┌──────────────┐    ┌──────────────┐  │
│  │ StateMachine │      │ ReconnectMgr │    │QualityMonitor │  │
│  │  (状态管理)   │      │  (智能重连)   │    │  (质量监控)   │  │
│  └──────────────┘      └──────────────┘    └──────────────┘  │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │             Signaling Protocol v2.0                      │   │
│  │  (心跳 | 重连 | 质量报告 | 错误通知)                      │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 新架构优势

| 特性 | 旧架构 | 新架构 |
|------|--------|--------|
| 内存管理 | 手动清理 Map | 自动生命周期管理 |
| 状态一致性 | 分散管理 | 统一状态机 |
| 断线恢复 | 无 | 智能重连 + 心跳 |
| 网络质量 | 无监控 | 实时监控 + 自适应码率 |
| 信令协议 | 不统一 | 标准化 v2.0 协议 |

---

## 快速开始

### 1. 导入新模块

```dart
// 导入完整的 WebRTC 模块
import 'package:imboy/component/webrtc/webrtc_barrel.dart';

// 或导入特定子模块
import 'package:imboy/component/webrtc/connection/connection_barrel.dart';
import 'package:imboy/component/webrtc/quality/quality_barrel.dart';
```

### 2. 创建连接

```dart
// 通过 ConnectionManager 创建连接（推荐）
final connection = await WebRTCConnectionManager.instance.createConnection(
  sessionId: 'session-123',
  peerId: 'user-456',
  mediaType: WebRTCMediaType.video,
);

// 或手动创建连接
final connection = WebRTCConnection(
  sessionId: 'session-123',
  peerId: 'user-456',
  mediaType: WebRTCMediaType.video,
);
await connection.initialize();
```

### 3. 监听状态

```dart
// 监听连接状态
connection.stateStream.listen((event) {
  print('状态变化: ${event.previousState} → ${event.state}');
  if (event.error != null) {
    print('错误信息: ${event.error}');
  }
});

// 监听远程流
connection.remoteStreamStream.listen((stream) {
  print('收到远程流');
  // 更新 UI 显示远程视频
});

// 监听网络质量
connection.qualityScoreStream.listen((score) {
  print('网络质量评分: $score/100');
});
```

### 4. 建立通话

```dart
// 作为发起方
final offer = await connection.createOffer();
// 通过信令服务器发送 offer...

// 作为接收方
await connection.initialize();
final answer = await connection.createAnswer(offer);
// 通过信令服务器发送 answer...

// 添加 ICE 候选
connection.iceCandidateStream.listen((candidate) {
  // 通过信令服务器发送候选...
});
```

### 5. 清理资源

```dart
// 关闭单个连接
await connection.close(reason: '通话结束');

// 或通过管理器关闭
await WebRTCConnectionManager.instance.closeConnection('session-123');

// 关闭所有连接
await WebRTCConnectionManager.instance.closeAll();
```

---

## 迁移步骤

### 阶段 1: 替换 Session 管理

**旧代码：**
```dart
// lib/page/chat/p2p_call_screen/p2p_call_screen_page.dart
import 'package:imboy/component/webrtc/session.dart';

WebRTCSession session = WebRTCSession(
  peerId: peer.userId,
  sid: sessionId,
);
session.pc = await createPeerConnection(...);
```

**新代码：**
```dart
import 'package:imboy/component/webrtc/webrtc_barrel.dart';

// 通过管理器创建连接
final connection = await WebRTCConnectionManager.instance.createConnection(
  sessionId: sessionId,
  peerId: peer.userId,
  mediaType: WebRTCMediaType.video,
);

// 连接已自动初始化，无需手动创建 PeerConnection
```

### 阶段 2: 替换状态管理

**旧代码：**
```dart
// 分散的状态管理
String callState = 'idle';
Map<String, WebRTCSession> sessions = {};

// 手动状态转换
if (callState == 'idle' && incomingCall) {
  callState = 'ringing';
}
```

**新代码：**
```dart
import 'package:imboy/component/webrtc/state/state_barrel.dart';

// 使用状态机
final stateMachine = WebRTCCallStateMachine(
  callId: callId,
  callType: WebRTCCallType.video,
  direction: WebRTCCallDirection.incoming,
);

// 状态转换（带验证）
await stateMachine.ringing();
await stateMachine.answer();
await stateMachine.hangup();

// 监听状态变化
stateMachine.stateStream.listen((event) {
  print('通话状态: ${event.state}');
});
```

### 阶段 3: 添加 UI 组件

**新代码：**
```dart
import 'package:imboy/page/chat/p2p_call_screen/widgets/connection_status_widget.dart';
import 'package:imboy/page/chat/p2p_call_screen/widgets/network_quality_indicator.dart';

// 在通话页面添加状态指示器
Widget build(BuildContext context) {
  return Scaffold(
    body: Stack(
      children: [
        // 远程视频
        RTCVideoView(remoteRenderer),

        // 状态指示器
        Positioned(
          top: 16,
          left: 16,
          child: WebRTCConnectionStatusWidget(
            state: connection.state,
            errorMessage: error,
          ),
        ),

        // 网络质量指示器
        Positioned(
          top: 16,
          right: 16,
          child: WebRTCNetworkQualityIndicator(
            sessionId: connection.sessionId,
          ),
        ),
      ],
    ),
  );
}
```

### 阶段 4: 使用新的信令协议

**旧代码：**
```dart
// 自定义信令格式
final message = {
  'type': 'webrtc_offer',
  'from': myId,
  'to': peerId,
  'payload': {'sd': sdp},
};
```

**新代码：**
```dart
import 'package:imboy/component/webrtc/signaling/signaling_barrel.dart';

// 使用标准化的信令构建器
final message = WebRTCSignalingBuilder.buildOffer(
  msgId: generateUUID(),
  from: myId,
  to: peerId,
  sdp: offerSdp,
  mediaType: 'video',
  sessionId: sessionId,
);

// 解析接收到的信令
final signaling = WebRTCSignalingModel.fromJson(message);
switch (signaling.type) {
  case WebRTCSignalingType.offer:
    // 处理 offer
    break;
  case WebRTCSignalingType.answer:
    // 处理 answer
    break;
  case WebRTCSignalingType.candidate:
    // 处理 ICE 候选
    break;
  case WebRTCSignalingType.heartbeat:
    // 处理心跳
    break;
  // ...
}
```

---

## API 参考

### WebRTCConnectionManager

单例管理器，负责创建和跟踪所有 WebRTC 连接。

```dart
class WebRTCConnectionManager {
  /// 单例实例
  static final WebRTCConnectionManager instance = ...;

  /// 创建新连接
  Future<WebRTCConnection> createConnection({
    required String sessionId,
    required String peerId,
    required WebRTCMediaType mediaType,
  });

  /// 获取连接
  WebRTCConnection? getConnection(String sessionId);

  /// 获取用户的会话 ID
  String? getUserSession(String userId);

  /// 关闭连接
  Future<void> closeConnection(String sessionId, {String? reason});

  /// 关闭所有连接
  Future<void> closeAll({String? reason});
}
```

### WebRTCConnection

单个 WebRTC 连接的生命周期管理。

```dart
class WebRTCConnection {
  /// 会话 ID
  final String sessionId;

  /// 对等端 ID
  final String peerId;

  /// 媒体类型
  final WebRTCMediaType mediaType;

  /// 初始化连接
  Future<void> initialize();

  /// 创建 Offer
  Future<RTCSessionDescription> createOffer();

  /// 创建 Answer
  Future<RTCSessionDescription> createAnswer(RTCSessionDescription offer);

  /// 设置远程描述
  Future<void> setRemoteDescription(RTCSessionDescription description);

  /// 添加 ICE 候选
  Future<void> addIceCandidate(RTCIceCandidate candidate);

  /// 关闭连接
  Future<void> close({String? reason});

  /// 状态流
  Stream<WebRTCConnectionStateEvent> get stateStream;

  /// 质量评分流
  Stream<int> get qualityScoreStream;

  /// 远程流流
  Stream<MediaStream> get remoteStreamStream;
}
```

### WebRTCCallStateMachine

通话状态机，管理通话生命周期。

```dart
class WebRTCCallStateMachine {
  /// 当前状态
  WebRTCCallState get state;

  /// 状态历史
  List<WebRTCCallStateEvent> get history;

  /// 状态流
  Stream<WebRTCCallStateEvent> get stateStream;

  /// 状态转换方法
  Future<void> invite();
  Future<void> ringing();
  Future<void> answer();
  Future<void> hangup({String? reason});
  Future<void> reject({String? reason});

  /// 检查是否可以转换
  bool canTransitionTo(WebRTCCallState targetState);
}
```

---

## 常见问题

### Q: 如何处理重复通话？

**A:** ConnectionManager 会自动跟踪用户会话，防止重复通话：

```dart
// 检查用户是否已在通话中
final existingSession = WebRTCConnectionManager.instance.getUserSession(userId);
if (existingSession != null) {
  // 拒绝新通话或结束旧通话
  await WebRTCConnectionManager.instance.closeConnection(existingSession);
}
```

### Q: 如何自定义重连策略？

**A:** 在创建连接时传入自定义配置：

```dart
final config = WebRTCConnectionConfig(
  reconnectConfig: WebRTCReconnectConfig(
    strategy: ReconnectStrategy.exponential,
    maxRetries: 5,
    initialDelay: const Duration(seconds: 1),
    maxDelay: const Duration(seconds: 30),
    heartbeatInterval: const Duration(seconds: 10),
    heartbeatTimeout: const Duration(seconds: 30),
  ),
);

final connection = await WebRTCConnectionManager.instance.createConnection(
  sessionId: sessionId,
  peerId: peerId,
  mediaType: WebRTCMediaType.video,
);
```

### Q: 如何禁用质量监控？

**A:** 在配置中禁用：

```dart
final config = WebRTCConnectionConfig(
  qualityConfig: WebRTCQualityConfig(
    enabled: false,
  ),
);
```

### Q: 如何与现有信令系统集成？

**A:** 使用新的信令模型进行转换：

```dart
// 接收旧格式信令，转换为新模式
final newSignaling = WebRTCSignalingModel.fromJson(legacyMessage);

// 处理后转换回旧格式（如果需要）
final legacyMessage = newSignaling.toJson();
```

---

## 迁移检查清单

- [ ] 替换 `WebRTCSession` 为 `WebRTCConnection`
- [ ] 使用 `WebRTCConnectionManager` 替代全局 Map
- [ ] 集成 `WebRTCCallStateMachine` 进行状态管理
- [ ] 添加 UI 组件（状态指示器、质量指示器）
- [ ] 更新信令消息格式到 v2.0
- [ ] 测试重连机制
- [ ] 测试质量监控
- [ ] 验证内存泄漏修复

---

## 相关文件

| 文件 | 描述 |
|------|------|
| `lib/component/webrtc/connection/` | 连接管理模块 |
| `lib/component/webrtc/reconnect/` | 重连机制模块 |
| `lib/component/webrtc/quality/` | 质量监控模块 |
| `lib/component/webrtc/state/` | 状态机模块 |
| `lib/component/webrtc/signaling/` | 信令协议模块 |
| `lib/page/chat/p2p_call_screen/widgets/` | UI 组件 |

---

## 故障排查

### 连接失败诊断步骤

#### 1. 检查 TURN 服务器

```bash
# 测试 STUN 服务器
stunclient your-server.com 3478

# 测试 TURN 服务器
turnutils_uclient -u username -p password your-server.com

# 检查端口开放
nc -zuv your-server.com 3478  # UDP
nc -zv your-server.com 3478   # TCP
```

#### 2. 查看 ICE 候选日志

在客户端日志中查找 ICE 候选类型：

```
> rtc ICE candidate type: host    # 本地候选
> rtc ICE candidate type: srflx   # STUN 候选
> rtc ICE candidate type: relay   # TURN 中继候选
```

**如果只有 `host` 候选**：STUN/TURN 服务器配置有问题
**如果有 `srflx` 但连接失败**：对称型 NAT，需要 TURN
**没有 `relay` 候选**：TURN 服务器未正确配置或不可达

#### 3. 常见问题

| 问题 | 可能原因 | 解决方案 |
|------|----------|----------|
| 局域网正常，移动网络失败 | 对称型 NAT | 确保启用 TURN 服务器 |
| 只有 host 候选 | STUN/TURN 配置错误 | 检查 iceServers 配置 |
| ICE 连接一直 checking | 候选交换失败 | 检查信令通道 |
| 连接后立即断开 | 端口被封锁 | 添加 TURN TCP 传输 |

#### 4. 腾讯云防火墙配置

确保以下端口开放：

```
3478/udp   # STUN/TURN UDP
3478/tcp   # STUN/TURN TCP
50000-50200/udp  # TURN 中继端口范围
```

#### 5. eturnal 配置检查

```yaml
# /etc/eturnal/eturnal.yml
eturnal:
  listen:
    - ip: "0.0.0.0"
      port: 3478
      transport: udp
    - ip: "0.0.0.0"
      port: 3478
      transport: tcp  # 确保启用 TCP

  relay:
    min_port: 50000
    max_port: 50200

  secret: "your-strong-secret"
  log_level: warning
```

### 调试模式

启用详细日志：

```dart
// 在 p2p_call_screen_provider.dart 中
// 所有 ICE 候选都会打印类型信息
iPrint('> rtc ICE candidate type: $candidateType, candidate: ${candidate.candidate}');
```

