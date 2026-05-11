/// WebSocket 相关事件定义
/// WebSocket related events definition
///
/// 此文件定义了 WebSocket 服务使用的所有事件类型，用于解耦 WebSocket 和其他服务之间的依赖
/// This file defines all event types used by WebSocket service to decouple dependencies
///
/// 使用示例：
/// ```dart
/// // 发布事件
/// AppEventBus.fire(WebSocketMessageReceivedEvent(
///   type: 'C2C',
///   data: {'id': '123', 'content': 'Hello'},
/// ));
///
/// // 订阅事件
/// AppEventBus.on<WebSocketMessageReceivedEvent>().listen((event) {
///   print('收到消息: ${event.type}');
/// });
/// ```
library;

import 'package:imboy/service/events/base_event.dart';

// ============================================================================
// WebSocket 消息相关事件
// ============================================================================

/// WebSocket 消息接收事件
///
/// 当 WebSocket 接收到新消息时发布
final class WebSocketMessageReceivedEvent extends AppEvent {
  /// 消息类型 (C2C, C2G, S2C, etc.)
  final String type;

  /// 消息数据
  final Map<String, dynamic> data;

  const WebSocketMessageReceivedEvent({required this.type, required this.data});

  @override
  List<Object> get props => [type, data];
}

// ============================================================================
// WebSocket 连接状态事件
// ============================================================================

/// WebSocket 连接成功事件
///
/// 当 WebSocket 连接成功建立时发布
final class WebSocketConnectedEvent extends AppEvent {
  /// WebSocket URL
  final String? url;

  const WebSocketConnectedEvent({this.url});

  @override
  List<Object?> get props => [url];
}

/// WebSocket 断开连接事件
///
/// 当 WebSocket 连接断开时发布
final class WebSocketDisconnectedEvent extends AppEvent {
  /// 断开原因
  final String reason;

  /// 关闭代码
  final int? closeCode;

  const WebSocketDisconnectedEvent({this.reason = '', this.closeCode});

  @override
  List<Object?> get props => [reason, closeCode];
}

/// WebSocket 错误事件
///
/// 当 WebSocket 遇到错误时发布
final class WebSocketErrorEvent extends AppEvent {
  /// 错误对象
  final dynamic error;

  const WebSocketErrorEvent({required this.error});

  @override
  List<Object> get props => [error as Object];
}

/// WebSocket 连接状态变化事件
///
/// 当 WebSocket 连接状态变化时发布
final class WebSocketStatusChangedEvent extends AppEvent {
  /// 连接状态 (connecting, connected, disconnected, error)
  final String status;

  const WebSocketStatusChangedEvent({required this.status});

  @override
  List<Object> get props => [status];
}

// ============================================================================
// 消息发送相关事件
// ============================================================================

/// WebSocket 消息发送请求事件（低级 API）
///
/// 当需要通过 WebSocket 发送原始 JSON 字符串时使用
/// 注意：这是 WebSocket 层面的低级事件，用于直接发送 JSON 字符串
/// 业务层的消息发送应使用 message_events.dart 中的 MessageSendRequestedEvent
final class WebSocketMessageSendRequestEvent extends AppEvent {
  /// 要发送的消息内容（JSON 字符串）
  final String message;

  /// 消息 ID（可选）
  final String? messageId;

  /// 优先级（可选）
  final int priority;

  const WebSocketMessageSendRequestEvent({
    required this.message,
    this.messageId,
    this.priority = 0,
  });

  @override
  List<Object?> get props => [message, messageId, priority];
}

/// 消息发送成功事件
///
/// 当消息成功发送时发布
final class MessageSentEvent extends AppEvent {
  /// 消息 ID
  final String messageId;

  /// 发送时间戳（毫秒）
  final int eventTime;

  const MessageSentEvent({required this.messageId, required this.eventTime});

  @override
  List<Object> get props => [messageId, eventTime];
}

/// 消息发送失败事件
///
/// 当消息发送失败时发布
final class MessageSendFailedEvent extends AppEvent {
  /// 消息 ID
  final String messageId;

  /// 错误信息
  final String error;

  /// 失败时间戳（毫秒）
  final int eventTime;

  const MessageSendFailedEvent({
    required this.messageId,
    required this.error,
    required this.eventTime,
  });

  @override
  List<Object> get props => [messageId, error, eventTime];
}

/// WebSocket 强制关闭事件
///
/// 当需要强制关闭 WebSocket 连接时发布（如设备被强制下线）
final class WebSocketForceCloseEvent extends AppEvent {
  /// 是否永久关闭（不再重连）
  final bool permanent;

  const WebSocketForceCloseEvent({this.permanent = false});

  @override
  List<Object> get props => [permanent];
}

/// WebSocket 重连请求事件
///
/// 当请求 WebSocket 重连时发布（如网络类型变化、网络恢复等）
final class WebSocketReconnectRequestEvent extends AppEvent {
  /// 重连来源（用于日志追踪）
  final String source;

  /// 是否强制重连（即使已连接）
  final bool force;

  const WebSocketReconnectRequestEvent({
    required this.source,
    this.force = false,
  });

  @override
  List<Object?> get props => [source, force];
}
