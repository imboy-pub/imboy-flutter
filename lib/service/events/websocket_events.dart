import 'base_event.dart';

/// WebSocket 相关事件
///
/// 定义了 WebSocket 连接生命周期中的所有事件类型
/// 包括连接建立、断开、错误和消息接收等事件

/// WebSocket 连接成功事件
///
/// 当 WebSocket 成功连接到服务器时触发
final class WebSocketConnectedEvent extends AppEvent {
  /// WebSocket 服务器 URL
  final String serverUrl;

  /// 连接建立耗时（毫秒）
  final int connectDuration;

  /// 是否为重连成功
  final bool isReconnect;

  const WebSocketConnectedEvent({
    required this.serverUrl,
    required this.connectDuration,
    this.isReconnect = false,
  });

  @override
  List<Object> get props => [serverUrl, connectDuration, isReconnect];

  @override
  String toString() {
    return 'WebSocketConnectedEvent(serverUrl: $serverUrl, connectDuration: ${connectDuration}ms, isReconnect: $isReconnect)';
  }
}

/// WebSocket 断开连接事件
///
/// 当 WebSocket 连接断开时触发
final class WebSocketDisconnectedEvent extends AppEvent {
  /// 断开原因
  final String reason;

  /// 关闭代码（WebSocket 协议定义的关闭码）
  final int? closeCode;

  /// 是否为主动断开（用户主动调用断开方法）
  final bool isIntentional;

  /// 断开前已连接的时长（毫秒）
  final int? connectedDuration;

  const WebSocketDisconnectedEvent({
    required this.reason,
    this.closeCode,
    this.isIntentional = false,
    this.connectedDuration,
  });

  @override
  List<Object?> get props => [reason, closeCode, isIntentional, connectedDuration];

  @override
  String toString() {
    return 'WebSocketDisconnectedEvent(reason: $reason, closeCode: $closeCode, isIntentional: $isIntentional, connectedDuration: ${connectedDuration}ms)';
  }
}

/// WebSocket 错误事件
///
/// 当 WebSocket 连接或通信过程中发生错误时触发
final class WebSocketErrorEvent extends ErrorEvent {
  /// 错误发生时的连接状态
  final String connectionState;

  /// 错误类型（连接错误、发送错误、接收错误等）
  final WebSocketErrorType errorType;

  const WebSocketErrorEvent({
    required super.errorCode,
    required super.errorMessage,
    required this.connectionState,
    required this.errorType,
    super.error,
    super.stackTrace,
  });

  @override
  List<Object?> get props => [...super.props, connectionState, errorType];

  @override
  String toString() {
    return 'WebSocketErrorEvent(errorType: $errorType, connectionState: $connectionState, errorCode: $errorCode, errorMessage: $errorMessage)';
  }
}

/// WebSocket 错误类型枚举
enum WebSocketErrorType {
  /// 连接错误
  connectionError,

  /// 发送消息错误
  sendError,

  /// 接收消息错误
  receiveError,

  /// 解析错误
  parseError,

  /// 超时错误
  timeoutError,

  /// 认证错误
  authError,

  /// 其他错误
  unknown,
}

/// WebSocket 收到消息事件
///
/// 当通过 WebSocket 接收到新消息时触发
final class WebSocketMessageReceivedEvent extends AppEvent {
  /// 消息类型（C2C, C2G, C2S, S2C 等）
  final String messageType;

  /// 消息负载（完整的消息数据）
  final Map<String, dynamic> payload;

  /// 消息 ID（如果有的话）
  final String? messageId;

  /// 发送者 ID
  final String? senderId;

  /// 接收者 ID（或群组 ID）
  final String? receiverId;

  /// 消息数据大小（字节）
  final int dataSize;

  const WebSocketMessageReceivedEvent({
    required this.messageType,
    required this.payload,
    this.messageId,
    this.senderId,
    this.receiverId,
    required this.dataSize,
  });

  @override
  List<Object?> get props => [messageType, payload, messageId, senderId, receiverId, dataSize];

  @override
  String toString() {
    return 'WebSocketMessageReceivedEvent(messageType: $messageType, messageId: $messageId, senderId: $senderId, receiverId: $receiverId, dataSize: $dataSize bytes)';
  }
}

/// WebSocket 消息发送成功事件
///
/// 当消息成功通过 WebSocket 发送时触发
final class WebSocketMessageSentEvent extends AppEvent {
  /// 消息 ID
  final String messageId;

  /// 消息类型
  final String messageType;

  /// 消息内容（用于日志记录）
  final String? messageContent;

  /// 发送耗时（毫秒）
  final int sendDuration;

  const WebSocketMessageSentEvent({
    required this.messageId,
    required this.messageType,
    this.messageContent,
    required this.sendDuration,
  });

  @override
  List<Object?> get props => [messageId, messageType, messageContent, sendDuration];

  @override
  String toString() {
    return 'WebSocketMessageSentEvent(messageId: $messageId, messageType: $messageType, sendDuration: ${sendDuration}ms)';
  }
}

/// WebSocket 重连开始事件
///
/// 当开始尝试重连 WebSocket 时触发
final class WebSocketReconnectingEvent extends AppEvent {
  /// 当前重连次数
  final int currentAttempt;

  /// 最大重连次数
  final int maxAttempts;

  /// 预计重连延迟（毫秒）
  final int retryDelay;

  /// 上一次断开的原因
  final String lastDisconnectReason;

  const WebSocketReconnectingEvent({
    required this.currentAttempt,
    required this.maxAttempts,
    required this.retryDelay,
    required this.lastDisconnectReason,
  });

  @override
  List<Object> get props => [currentAttempt, maxAttempts, retryDelay, lastDisconnectReason];

  @override
  String toString() {
    return 'WebSocketReconnectingEvent(attempt: $currentAttempt/$maxAttempts, retryDelay: ${retryDelay}ms, reason: $lastDisconnectReason)';
  }
}

/// WebSocket 心跳事件
///
/// 当 WebSocket 发送或接收到心跳消息时触发
final class WebSocketPingEvent extends AppEvent {
  /// 心跳类型（send: 发送心跳, receive: 接收心跳响应）
  final WebSocketPingType pingType;

  /// 心跳间隔（毫秒）
  final int interval;

  /// 心跳序号
  final int sequenceNumber;

  const WebSocketPingEvent({
    required this.pingType,
    required this.interval,
    required this.sequenceNumber,
  });

  @override
  List<Object> get props => [pingType, interval, sequenceNumber];

  @override
  String toString() {
    return 'WebSocketPingEvent(pingType: $pingType, interval: ${interval}ms, sequence: $sequenceNumber)';
  }
}

/// WebSocket 心跳类型枚举
enum WebSocketPingType {
  /// 发送心跳
  send,

  /// 接收心跳响应
  receive,
}
