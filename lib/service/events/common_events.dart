/// 常用事件定义
///
/// 包含项目中常用的系统事件，开发者可以直接使用这些事件，
/// 也可以参考这些事件的结构创建自定义事件
library;

import 'package:imboy/service/events/base_event.dart';

// ============================================================================
// 用户相关事件
// ============================================================================

/// 用户登录事件
///
/// 当用户成功登录后发布
///
/// 示例：
/// ```dart
/// AppEventBus().fire(UserLoginEvent(
///   userId: '123',
///   username: 'imboy',
/// ));
/// ```
final class UserLoginEvent extends AppEvent {
  /// 用户ID
  final String userId;

  /// 用户名
  final String username;

  const UserLoginEvent({required this.userId, required this.username});

  @override
  List<Object> get props => [userId, username];
}

/// 用户登出事件
///
/// 当用户主动登出或Token过期时发布
final class UserLogoutEvent extends AppEvent {
  /// 用户ID
  final String userId;

  /// 登出原因
  final String? reason;

  const UserLogoutEvent({required this.userId, this.reason});

  @override
  List<Object?> get props => [userId, reason];
}

/// 用户信息更新事件
///
/// 当用户信息（昵称、头像等）更新时发布
final class UserInfoUpdateEvent extends AppEvent {
  /// 用户ID
  final String userId;

  /// 更新的字段
  final Map<String, dynamic> updatedFields;

  const UserInfoUpdateEvent({
    required this.userId,
    required this.updatedFields,
  });

  @override
  List<Object> get props => [userId, updatedFields];
}

// ============================================================================
// 消息相关事件
// ============================================================================

/// 消息发送事件
///
/// 当消息成功发送时发布
final class MessageSendEvent extends AppEvent {
  /// 消息ID
  final String messageId;

  /// 会话ID
  final String conversationId;

  /// 消息类型（C2C, C2G等）
  final String messageType;

  /// 是否成功
  final bool success;

  const MessageSendEvent({
    required this.messageId,
    required this.conversationId,
    required this.messageType,
    required this.success,
  });

  @override
  List<Object> get props => [messageId, conversationId, messageType, success];
}

/// 消息接收事件
///
/// 当接收到新消息时发布
final class MessageReceiveEvent extends AppEvent {
  /// 消息ID
  final String messageId;

  /// 会话ID
  final String conversationId;

  /// 发送者ID
  final String senderId;

  /// 消息类型
  final String messageType;

  /// 消息内容
  final Map<String, dynamic>? payload;

  const MessageReceiveEvent({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.messageType,
    this.payload,
  });

  @override
  List<Object?> get props => [
    messageId,
    conversationId,
    senderId,
    messageType,
    payload,
  ];
}

/// 消息撤回事件
///
/// 当消息被撤回时发布
final class MessageRevokeEvent extends AppEvent {
  /// 消息ID
  final String messageId;

  /// 会话ID
  final String conversationId;

  /// 操作者ID
  final String operatorId;

  const MessageRevokeEvent({
    required this.messageId,
    required this.conversationId,
    required this.operatorId,
  });

  @override
  List<Object> get props => [messageId, conversationId, operatorId];
}

/// 消息已读事件（批量）
///
/// 当多条消息被批量标记为已读时发布
final class MessagesReadEvent extends AppEvent {
  /// 消息ID列表
  final List<String> messageIds;

  /// 会话ID
  final String conversationId;

  /// 阅读者ID
  final String readerId;

  const MessagesReadEvent({
    required this.messageIds,
    required this.conversationId,
    required this.readerId,
  });

  @override
  List<Object> get props => [messageIds, conversationId, readerId];
}

// ============================================================================
// 会话相关事件
// ============================================================================

/// 当前活动会话变化事件
///
/// 当用户打开或切换到某个聊天会话时发布
/// 用于跟踪用户当前正在浏览的会话，以便正确管理未读数
final class ChatActiveEvent extends AppEvent {
  /// 会话唯一标识符 (conversation_uk3)
  final String conversationUk3;

  /// 会话类型（C2C, C2G）
  final String conversationType;

  /// 对端用户 ID 或群组 ID
  final String peerId;

  /// 是否为激活操作（true=进入聊天，false=离开聊天）
  final bool isActive;

  const ChatActiveEvent({
    required this.conversationUk3,
    required this.conversationType,
    required this.peerId,
    this.isActive = true,
  });

  @override
  List<Object> get props => [conversationUk3, conversationType, peerId, isActive];

  @override
  String toString() {
    return 'ChatActiveEvent(conversationUk3: $conversationUk3, conversationType: $conversationType, peerId: $peerId, isActive: $isActive)';
  }
}

/// 会话更新事件
///
/// 当会话信息更新时发布（最后消息、未读数等）
final class ConversationUpdateEvent extends AppEvent {
  /// 会话ID
  final String conversationId;

  /// 会话类型（C2C, C2G）
  final String conversationType;

  /// 对方ID
  final String peerId;

  /// 更新的字段
  final Map<String, dynamic> updatedFields;

  const ConversationUpdateEvent({
    required this.conversationId,
    required this.conversationType,
    required this.peerId,
    required this.updatedFields,
  });

  @override
  List<Object> get props => [
    conversationId,
    conversationType,
    peerId,
    updatedFields,
  ];
}

/// 会话删除事件
///
/// 当会话被删除时发布
final class ConversationDeleteEvent extends AppEvent {
  /// 会话ID
  final String conversationId;

  /// 会话类型（C2C, C2G）
  final String conversationType;

  const ConversationDeleteEvent({
    required this.conversationId,
    required this.conversationType,
  });

  @override
  List<Object> get props => [conversationId, conversationType];
}

// ============================================================================
// 网络相关事件
// ============================================================================

/// 网络连接事件
///
/// 当网络连接状态变化时发布
final class NetworkConnectionEvent extends AppEvent {
  /// 是否已连接
  final bool isConnected;

  /// 网络类型（wifi, mobile, none等）
  final String networkType;

  const NetworkConnectionEvent({
    required this.isConnected,
    required this.networkType,
  });

  @override
  List<Object> get props => [isConnected, networkType];
}

/// WebSocket 连接状态事件
///
/// 当WebSocket连接状态变化时发布
final class WebSocketStatusEvent extends AppEvent {
  /// 连接状态
  final String status; // connecting, connected, disconnected

  /// 错误信息（如果有）
  final String? error;

  const WebSocketStatusEvent({required this.status, this.error});

  @override
  List<Object?> get props => [status, error];
}

// ============================================================================
// 联系人相关事件
// ============================================================================

/// 联系人添加事件
///
/// 当添加新联系人时发布
final class ContactAddEvent extends AppEvent {
  /// 联系人ID
  final String contactId;

  /// 联系人昵称
  final String nickname;

  const ContactAddEvent({required this.contactId, required this.nickname});

  @override
  List<Object> get props => [contactId, nickname];
}

/// 联系人删除事件
///
/// 当删除联系人时发布
final class ContactDeleteEvent extends AppEvent {
  /// 联系人ID
  final String contactId;

  const ContactDeleteEvent({required this.contactId});

  @override
  List<Object> get props => [contactId];
}

// ============================================================================
// 群组相关事件
// ============================================================================

/// 群组创建事件
///
/// 当创建新群组时发布
final class GroupCreateEvent extends AppEvent {
  /// 群组ID
  final String groupId;

  /// 群组名称
  final String groupName;

  const GroupCreateEvent({required this.groupId, required this.groupName});

  @override
  List<Object> get props => [groupId, groupName];
}

/// 群组成员变更事件
///
/// 当群组成员加入或退出时发布
final class GroupMemberUpdateEvent extends AppEvent {
  /// 群组ID
  final String groupId;

  /// 用户ID
  final String userId;

  /// 变更类型（join, leave, kick）
  final String changeType;

  const GroupMemberUpdateEvent({
    required this.groupId,
    required this.userId,
    required this.changeType,
  });

  @override
  List<Object> get props => [groupId, userId, changeType];
}

// ============================================================================
// UI相关事件
// ============================================================================

/// 页面导航事件
///
/// 当需要进行页面跳转时发布
final class PageNavigationEvent extends AppEvent {
  /// 目标页面路径
  final String route;

  /// 页面参数
  final Map<String, dynamic>? arguments;

  const PageNavigationEvent({required this.route, this.arguments});

  @override
  List<Object?> get props => [route, arguments];
}

/// Toast 提示事件
///
/// 当需要显示Toast提示时发布
final class ToastEvent extends AppEvent {
  /// 提示消息
  final String message;

  /// 提示类型（info, success, warning, error）
  final String type;

  /// 持续时间（毫秒）
  final int duration;

  const ToastEvent({
    required this.message,
    this.type = 'info',
    this.duration = 2000,
  });

  @override
  List<Object> get props => [message, type, duration];
}

// ============================================================================
// 数据同步相关事件
// ============================================================================

/// 数据同步开始事件
///
/// 当开始数据同步时发布
final class DataSyncStartEvent extends AppEvent {
  /// 同步类型（message, contact, group等）
  final String syncType;

  const DataSyncStartEvent({required this.syncType});

  @override
  List<Object> get props => [syncType];
}

/// 数据同步完成事件
///
/// 当数据同步完成时发布
final class DataSyncCompleteEvent extends AppEvent {
  /// 同步类型
  final String syncType;

  /// 是否成功
  final bool success;

  /// 错误信息（如果失败）
  final String? error;

  const DataSyncCompleteEvent({
    required this.syncType,
    required this.success,
    this.error,
  });

  @override
  List<Object?> get props => [syncType, success, error];
}

// ============================================================================
// 错误相关事件
// ============================================================================

/// 应用错误事件
///
/// 当应用发生错误时发布
final class AppErrorEvent extends AppEvent {
  /// 错误消息
  final String message;

  /// 错误类型
  final String errorType;

  /// 错误堆栈
  final String? stackTrace;

  /// 是否为致命错误
  final bool isFatal;

  const AppErrorEvent({
    required this.message,
    required this.errorType,
    this.stackTrace,
    this.isFatal = false,
  });

  @override
  List<Object?> get props => [message, errorType, stackTrace, isFatal];
}

// ============================================================================
// 通用数据事件（用于兼容旧代码）
// ============================================================================

/// 通用数据包装事件
///
/// 用于包装非 AppEvent 类型的数据，使其可以通过事件总线传递
/// 这是一个临时兼容方案，建议后续逐步迁移到专门的事件类型
final class DataWrapperEvent<T> extends AppEvent {
  /// 包装的数据
  final T data;

  /// 数据类型描述
  final String dataType;

  const DataWrapperEvent({required this.data, required this.dataType});

  @override
  List<Object?> get props => [data, dataType];
}

/// 重新编辑消息事件
final class ReEditMessageEvent extends AppEvent {
  final String text;
  final String? messageId;

  const ReEditMessageEvent({required this.text, this.messageId});

  @override
  List<Object?> get props => [text, messageId];
}

/// 聊天扩展事件（用于群组操作、消息清理等）
final class ChatExtendEvent extends AppEvent {
  final String type;
  final Map<String, dynamic> payload;

  const ChatExtendEvent({required this.type, required this.payload});

  @override
  List<Object> get props => [type, payload];
}

/// WebRTC 信令事件
final class WebRTCSignalingEvent extends AppEvent {
  final Map<String, dynamic> data;

  const WebRTCSignalingEvent({required this.data});

  @override
  List<Object> get props => [data];
}

// ============================================================================
// 消息操作请求事件（用于解耦服务间直接调用）
// ============================================================================

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
/// 替代直接调用 MessageRetry.to.removeFromRetryQueue()
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
/// 替代直接调用 MessageRetry.to.retryFailedMessages()
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
/// 替代直接调用 MessageOfflineService.to.pullOfflineMessages()
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
        message,
        sendToServer,
      ];

  @override
  String toString() {
    return 'ChatMessageAddRequestedEvent(peerId: $peerId, conversationType: $conversationType, sendToServer: $sendToServer)';
  }
}
