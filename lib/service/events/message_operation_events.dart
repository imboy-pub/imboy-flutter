/// 消息操作请求事件定义（ACK / 状态更新 / 焚毁等）
library;

import 'package:imboy/service/events/base_event.dart';

/// ACK 发送请求事件
///
/// ⚠️ 注意：消息接收时的 ACK 已在 websocket.dart 中统一处理
///
/// 此事件用于其他操作场景下的 ACK 确认（如消息已读、表情反应等）
/// 【建议】直接调用 AckManager.to.sendAckDirect() 更高效
final class AckSendRequestedEvent extends AppEvent {
  /// 消息类型（C2C, C2G 等）
  final String messageType;

  /// 要确认的消息 ID
  final String messageId;

  /// ACK 类型（read, received, delivered 等）
  final String ackType;

  const AckSendRequestedEvent({
    required this.messageType,
    required this.messageId,
    this.ackType = 'read',
  });

  @override
  List<Object> get props => [messageType, messageId, ackType];

  @override
  String toString() {
    return 'AckSendRequestedEvent(messageType: $messageType, messageId: $messageId, ackType: $ackType)';
  }
}

/// ACK RTT 指标更新事件
///
/// 用于上报 ACK 确认链路的 RTT 样本和分位统计。
final class AckRttMetricsUpdatedEvent extends AppEvent {
  /// 消息 ID
  final String messageId;

  /// 消息类型（C2C, C2G 等）
  final String messageType;

  /// 本次 ACK RTT（毫秒）
  final int rttMs;

  /// 本次确认前经历的重试次数
  final int retryCount;

  /// 当前样本数
  final int sampleCount;

  /// P50 RTT（毫秒）
  final int p50Ms;

  /// P90 RTT（毫秒）
  final int p90Ms;

  /// P95 RTT（毫秒）
  final int p95Ms;

  /// P99 RTT（毫秒）
  final int p99Ms;

  const AckRttMetricsUpdatedEvent({
    required this.messageId,
    required this.messageType,
    required this.rttMs,
    required this.retryCount,
    required this.sampleCount,
    required this.p50Ms,
    required this.p90Ms,
    required this.p95Ms,
    required this.p99Ms,
  });

  @override
  List<Object> get props => [
    messageId,
    messageType,
    rttMs,
    retryCount,
    sampleCount,
    p50Ms,
    p90Ms,
    p95Ms,
    p99Ms,
  ];

  @override
  String toString() {
    return 'AckRttMetricsUpdatedEvent(messageId: $messageId, messageType: $messageType, rttMs: $rttMs, retryCount: $retryCount, samples: $sampleCount, p50: $p50Ms, p90: $p90Ms, p95: $p95Ms, p99: $p99Ms)';
  }
}

/// ACK 重试命中上限事件
///
/// 用于告警弱网/异常场景下 ACK 重试达到上限，便于运维侧定位链路问题。
final class AckRetryCeilingReachedEvent extends AppEvent {
  /// 消息 ID
  final String messageId;

  /// 消息类型（C2C, C2G 等）
  final String messageType;

  /// 当前重试次数
  final int retryCount;

  /// 最大重试上限
  final int maxRetryCount;

  /// 触发时待确认 ACK 数量
  final int pendingCount;

  /// 触发时间戳（毫秒）
  final int occurredAtMs;

  const AckRetryCeilingReachedEvent({
    required this.messageId,
    required this.messageType,
    required this.retryCount,
    required this.maxRetryCount,
    required this.pendingCount,
    required this.occurredAtMs,
  });

  @override
  List<Object> get props => [
    messageId,
    messageType,
    retryCount,
    maxRetryCount,
    pendingCount,
    occurredAtMs,
  ];

  @override
  String toString() {
    return 'AckRetryCeilingReachedEvent(messageId: $messageId, messageType: $messageType, retry: $retryCount/$maxRetryCount, pendingCount: $pendingCount, occurredAtMs: $occurredAtMs)';
  }
}

/// 消息状态更新请求事件
///
/// 当需要更新消息状态时发布
/// 替代直接调用 MessageService.to.updateStatus()
final class MessageStatusUpdateRequestedEvent extends AppEvent {
  /// 消息 ID
  final String messageId;

  /// 消息类型（C2C, C2G 等）
  final String messageType;

  /// 新状态
  final int newStatus;

  /// 旧状态（可选）
  final int? oldStatus;

  /// 是否需要触发 UI 更新
  final bool notifyUI;

  const MessageStatusUpdateRequestedEvent({
    required this.messageId,
    required this.messageType,
    required this.newStatus,
    this.oldStatus,
    this.notifyUI = true,
  });

  @override
  List<Object?> get props => [
    messageId,
    messageType,
    newStatus,
    oldStatus,
    notifyUI,
  ];

  @override
  String toString() {
    return 'MessageStatusUpdateRequestedEvent(messageId: $messageId, messageType: $messageType, newStatus: $newStatus, notifyUI: $notifyUI)';
  }
}

/// 从重试队列移除请求事件
///
/// 当需要从重试队列移除消息时发布
/// 替代直接调用 MessageRetry.instance.removeFromRetryQueue()
final class RemoveFromRetryQueueRequestedEvent extends AppEvent {
  /// 消息 ID
  final String messageId;

  /// 消息类型（C2C, C2G 等）
  final String messageType;

  /// 移除原因（success, failed, revoked 等）
  final String reason;

  const RemoveFromRetryQueueRequestedEvent({
    required this.messageId,
    required this.messageType,
    this.reason = 'success',
  });

  @override
  List<Object> get props => [messageId, messageType, reason];

  @override
  String toString() {
    return 'RemoveFromRetryQueueRequestedEvent(messageId: $messageId, messageType: $messageType, reason: $reason)';
  }
}

/// 重试消息请求事件
///
/// 当需要触发失败消息重试时发布
/// 替代直接调用 MessageRetry.instance.retryFailedMessages()
final class RetryMessagesRequestedEvent extends AppEvent {
  /// 触发来源（网络恢复、手动触发等）
  final String source;

  /// 重试原因（网络恢复、应用启动等）
  final String? reason;

  const RetryMessagesRequestedEvent({required this.source, this.reason});

  @override
  List<Object?> get props => [source, reason];

  @override
  String toString() {
    return 'RetryMessagesRequestedEvent(source: $source, reason: $reason)';
  }
}

/// 离线消息拉取请求事件
///
/// 当服务端通知客户端拉取离线消息时发布
/// 替代直接调用 MessageOfflineService.instance.pullOfflineMessages()
final class OfflineMessagesPullRequestedEvent extends AppEvent {
  /// 触发来源（S2C消息、手动触发等）
  final String source;

  /// 拉取原因（服务端通知、应用启动等）
  final String? reason;

  const OfflineMessagesPullRequestedEvent({required this.source, this.reason});

  @override
  List<Object?> get props => [source, reason];

  @override
  String toString() {
    return 'OfflineMessagesPullRequestedEvent(source: $source, reason: $reason)';
  }
}

// ============================================================================
// 事件重试相关事件
// ============================================================================

/// 事件重试失败事件
///
/// 当事件重试达到最大次数仍然失败时发布
/// 用于处理关键事件（如消息发送）的最终失败情况
final class EventRetryFailedEvent extends AppEvent {
  /// 事件 ID
  final String eventId;

  /// 事件类型
  final String eventType;

  /// 尝试次数
  final int attempts;

  const EventRetryFailedEvent({
    required this.eventId,
    required this.eventType,
    required this.attempts,
  });

  @override
  List<Object> get props => [eventId, eventType, attempts];

  @override
  String toString() {
    return 'EventRetryFailedEvent(eventId: $eventId, eventType: $eventType, attempts: $attempts)';
  }
}

// ============================================================================
// 聊天 UI 相关事件
// ============================================================================

/// 聊天消息添加请求事件
///
/// 当服务层需要向聊天界面添加本地消息时发布
/// 用于解耦服务层与 UI 层的依赖（如 WebRTC 消息）
final class ChatMessageAddRequestedEvent extends AppEvent {
  /// 对端用户 ID
  final String peerId;

  /// 对端头像
  final String peerAvatar;

  /// 对端昵称
  final String peerNickname;

  /// 会话类型（C2C, C2G）
  final String conversationType;

  /// 要添加的消息对象
  final dynamic message;

  /// 是否发送到服务器（false 表示仅本地显示）
  final bool sendToServer;

  const ChatMessageAddRequestedEvent({
    required this.peerId,
    required this.peerAvatar,
    required this.peerNickname,
    required this.conversationType,
    required this.message,
    this.sendToServer = false,
  });

  @override
  List<Object> get props => [
    peerId,
    peerAvatar,
    peerNickname,
    conversationType,
    message as Object,
    sendToServer,
  ];

  @override
  String toString() {
    return 'ChatMessageAddRequestedEvent(peerId: $peerId, conversationType: $conversationType, sendToServer: $sendToServer)';
  }
}
