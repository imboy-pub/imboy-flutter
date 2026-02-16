import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/events/events.dart';

/// WebSocket 连接状态枚举
enum WebSocketConnectionState {
  connecting,
  connected,
  disconnected,
}

/// WebSocket 状态 Provider
///
/// 监听 WebSocketService 的连接状态变化
final webSocketStatusProvider =
    StreamProvider<WebSocketConnectionState>((ref) {
  // 创建一个 StreamController 来广播状态变化
  final controller = StreamController<WebSocketConnectionState>.broadcast();

  // 监听 WebSocket 状态变化事件
  StreamSubscription? subscription;
  subscription = AppEventBus.on<WebSocketStatusChangedEvent>().listen(
    (event) {
      final newState = switch (event.status.toLowerCase()) {
        'connecting' => WebSocketConnectionState.connecting,
        'connected' => WebSocketConnectionState.connected,
        'disconnected' => WebSocketConnectionState.disconnected,
        _ => WebSocketConnectionState.disconnected,
      };
      controller.add(newState);
    },
  );

  // 发送初始状态
  final currentStatus = WebSocketService.to.status;
  final initialState = switch (currentStatus) {
    SocketStatus.connecting => WebSocketConnectionState.connecting,
    SocketStatus.connected => WebSocketConnectionState.connected,
    SocketStatus.disconnected => WebSocketConnectionState.disconnected,
  };
  controller.add(initialState);

  // 清理订阅
  ref.onDispose(() {
    subscription?.cancel();
    controller.close();
  });

  return controller.stream;
});

/// 向后兼容的状态访问器
///
/// 使用 ref.watch(webSocketStatusProvider) 获取当前状态
/// 使用 ref.read(webSocketStatusProvider.stream) 获取数据流
typedef WebSocketStatusProvider = StreamProvider<WebSocketConnectionState>;
