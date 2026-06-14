/// 常用事件定义
///
/// 包含项目中常用的系统事件，开发者可以直接使用这些事件，
/// 也可以参考这些事件的结构创建自定义事件
library;

import 'package:imboy/service/events/base_event.dart';

// 导出拆分的事件文件
export 'user_events.dart';
export 'channel_events.dart';
export 'message_operation_events.dart';

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
  List<Object> get props => [
    conversationUk3,
    conversationType,
    peerId,
    isActive,
  ];

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

/// 会话权威同步来源事件
///
/// 用于观测会话列表是否按约定走“服务端权威拉取”链路。
final class ConversationAuthoritySyncEvent extends AppEvent {
  /// 触发来源（page_init/websocket_connected/manual 等）
  final String trigger;

  /// 来源标记（固定：server_authoritative_pull）
  final String source;

  /// 拉取到的服务端条目数
  final int fetchedCount;

  /// 同步写入本地的条目数
  final int syncedCount;

  /// 是否成功
  final bool success;

  const ConversationAuthoritySyncEvent({
    required this.trigger,
    required this.source,
    required this.fetchedCount,
    required this.syncedCount,
    required this.success,
  });

  @override
  List<Object> get props => [
    trigger,
    source,
    fetchedCount,
    syncedCount,
    success,
  ];
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
// 通用数据事件
// ============================================================================

/// 通用数据包装事件
///
/// 用于包装非 AppEvent 类型的数据，使其可以通过事件总线传递
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
