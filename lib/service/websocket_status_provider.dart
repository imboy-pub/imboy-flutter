import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/events/events.dart';

/// WebSocket 连接状态枚举
enum WebSocketConnectionState { connecting, connected, disconnected }

WebSocketConnectionState _mapSocketStatus(SocketStatus status) =>
    switch (status) {
      SocketStatus.connecting => WebSocketConnectionState.connecting,
      SocketStatus.connected => WebSocketConnectionState.connected,
      SocketStatus.disconnected => WebSocketConnectionState.disconnected,
    };

WebSocketConnectionState _mapEventStatus(String status) =>
    switch (status.toLowerCase()) {
      'connecting' => WebSocketConnectionState.connecting,
      'connected' => WebSocketConnectionState.connected,
      'disconnected' => WebSocketConnectionState.disconnected,
      _ => WebSocketConnectionState.disconnected,
    };

/// WebSocket 状态 Provider
///
/// 监听 WebSocketService 的连接状态变化。
///
/// 关键：使用**非 broadcast** StreamController，并在 [StreamController.onListen]
/// 回调里发送初始状态。broadcast controller 在无订阅者时 add 的事件会被直接丢弃，
/// 导致「连接已 connected → 不再 fire 状态事件 → provider 永远收不到状态」，
/// UI 卡在 disconnected（红点）。onListen 保证订阅建立后才读当前真实状态。
final webSocketStatusProvider = StreamProvider<WebSocketConnectionState>((ref) {
  final controller = StreamController<WebSocketConnectionState>();

  final subscription = AppEventBus.on<WebSocketStatusChangedEvent>().listen((
    event,
  ) {
    if (!controller.isClosed) {
      controller.add(_mapEventStatus(event.status));
    }
  });

  // 订阅建立后立即发送当前真实状态，避免初始状态丢失
  controller.onListen = () {
    if (!controller.isClosed) {
      controller.add(_mapSocketStatus(WebSocketService.to.status));
    }
  };

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});
