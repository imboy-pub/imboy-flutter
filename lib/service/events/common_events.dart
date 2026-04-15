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

/// 用户状态变更事件
///
/// 当好友上线、下线、隐身时发布
final class UserStatusChangeEvent extends AppEvent {
  /// 用户ID
  final String userId;

  /// 状态类型：online, offline, hide
  final String status;

  /// 用户昵称（可选，用于提示）
  final String? nickname;

  const UserStatusChangeEvent({
    required this.userId,
    required this.status,
    this.nickname,
  });

  @override
  List<Object?> get props => [userId, status, nickname];
}

/// 用户注销事件
///
/// 当好友账号注销时发布
final class UserCancelEvent extends AppEvent {
  /// 用户ID
  final String userId;

  /// 用户昵称（可选，用于提示）
  final String? nickname;

  const UserCancelEvent({required this.userId, this.nickname});

  @override
  List<Object?> get props => [userId, nickname];
}

/// 用户被禁言事件
///
/// 当后端通过 WebSocket 通知当前用户被禁言时发布
final class UserMutedEvent extends AppEvent {
  /// 禁言到期时间戳（毫秒），0 表示永久禁言
  final int muteUntilMs;

  /// 禁言原因（可选）
  final String? reason;

  /// 会话 ID（可选，表示在哪个会话中被禁言）
  final String? conversationId;

  const UserMutedEvent({
    required this.muteUntilMs,
    this.reason,
    this.conversationId,
  });

  /// 剩余禁言分钟数
  int get remainingMinutes {
    if (muteUntilMs <= 0) return -1; // 永久
    final remaining = muteUntilMs - DateTime.now().millisecondsSinceEpoch;
    if (remaining <= 0) return 0;
    return (remaining / 60000).ceil();
  }

  /// 是否仍在禁言中
  bool get isMuted {
    if (muteUntilMs <= 0) return true; // 永久禁言
    return DateTime.now().millisecondsSinceEpoch < muteUntilMs;
  }

  @override
  List<Object?> get props => [muteUntilMs, reason, conversationId];

  @override
  String toString() {
    return 'UserMutedEvent(muteUntilMs: $muteUntilMs, reason: $reason, conversationId: $conversationId)';
  }
}

/// 用户禁言解除事件
///
/// 当禁言到期或被手动解除时发布
final class UserUnmutedEvent extends AppEvent {
  /// 会话 ID（可选）
  final String? conversationId;

  const UserUnmutedEvent({this.conversationId});

  @override
  List<Object?> get props => [conversationId];
}

/// 群成员被管理员禁言的广播事件（S2C `group_member_mute`）
///
/// 触发时机：群管理员 / 群主禁言某成员后，后端向群内所有成员广播。
///
/// ⚠️ **已知契约缺口**：后端 `group_member_logic:mute_notice/4` 未在
/// payload 中携带被禁言成员的 `user_id`（见
/// `lib/service/group_member_mute_s2c.dart` 顶部注释），因此本事件目前
/// 无法精确定位到具体成员行。UI 层仅做「群内通知」展示；Repo 级 mute_until
/// 写入在 slice-2 或后端补 `user_id` 后再接入。
final class GroupMemberMuteEvent extends AppEvent {
  /// 群 ID
  final int gid;

  /// 禁言到期时间戳（毫秒）
  final int muteUntilMs;

  /// 剩余秒数
  final int remainingSeconds;

  /// 可读禁言时长文案，如 "10分钟"
  final String durationText;

  /// 执行禁言的管理员昵称
  final String adminNickname;

  const GroupMemberMuteEvent({
    required this.gid,
    required this.muteUntilMs,
    required this.remainingSeconds,
    required this.durationText,
    required this.adminNickname,
  });

  @override
  List<Object?> get props => [
        gid,
        muteUntilMs,
        remainingSeconds,
        durationText,
        adminNickname,
      ];

  @override
  String toString() {
    return 'GroupMemberMuteEvent(gid: $gid, muteUntilMs: $muteUntilMs, '
        'remainingSeconds: $remainingSeconds, durationText: $durationText, '
        'adminNickname: $adminNickname)';
  }
}

/// 群成员角色变更的广播事件（S2C `group_member_role`）
///
/// 触发时机：群主/副群主/管理员通过 `update_role` 接口修改某成员的角色后，
/// 后端向群内所有成员广播。
///
/// 角色常量（对齐后端 `group_role.hrl`）：
///   1=普通成员 / 2=嘉宾 / 3=管理员 / 4=群主 / 5=副群主
final class GroupMemberRoleEvent extends AppEvent {
  /// 群 ID
  final int gid;

  /// 被修改角色的成员 ID
  final int userId;

  /// 新角色（1..5）
  final int role;

  /// 角色文案（"普通成员" / "管理员" / ...）
  final String roleText;

  /// 被修改成员昵称
  final String nickname;

  /// 执行操作的管理员昵称
  final String adminNickname;

  /// 后端变更时间戳（秒级 epoch，0 表示后端未带）
  final int updatedAt;

  const GroupMemberRoleEvent({
    required this.gid,
    required this.userId,
    required this.role,
    required this.roleText,
    required this.nickname,
    required this.adminNickname,
    required this.updatedAt,
  });

  @override
  List<Object?> get props =>
      [gid, userId, role, roleText, nickname, adminNickname, updatedAt];

  @override
  String toString() =>
      'GroupMemberRoleEvent(gid: $gid, userId: $userId, role: $role, '
      'roleText: $roleText, adminNickname: $adminNickname)';
}

/// 群资料编辑的广播事件（S2C `group_edit`）
///
/// 触发时机：群主/管理员通过 `POST /group/edit` 更新群资料
/// （title / avatar / introduction / type / join_limit /
/// content_limit / member_max / status 等）后，后端向所有群成员广播。
///
/// `updates` 是本次变更的字段集合（已剔除 gid），可能为空（表示仅
/// 触发「群被编辑」信号，无实际字段变化，一般不会出现，仅为兼容）。
final class GroupEditEvent extends AppEvent {
  /// 群 ID
  final int gid;

  /// 本次变更的字段集合（不含 gid）
  final Map<String, dynamic> updates;

  const GroupEditEvent({required this.gid, required this.updates});

  @override
  List<Object?> get props => [gid, updates];

  @override
  String toString() => 'GroupEditEvent(gid: $gid, updates: $updates)';
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
// 频道相关事件
// ============================================================================

/// 频道未读计数更新事件
///
/// 当频道未读消息数变化时发布
final class ChannelUnreadCountUpdatedEvent extends AppEvent {
  /// 频道ID
  final String channelId;

  /// 未读消息数
  final int unreadCount;

  const ChannelUnreadCountUpdatedEvent({
    required this.channelId,
    required this.unreadCount,
  });

  @override
  List<Object> get props => [channelId, unreadCount];

  @override
  String toString() {
    return 'ChannelUnreadCountUpdatedEvent(channelId: $channelId, unreadCount: $unreadCount)';
  }
}

/// 频道新消息事件
///
/// 当订阅的频道发布新消息时发布
final class ChannelNewMessageEvent extends AppEvent {
  /// 频道ID
  final String channelId;

  /// 消息数据
  final Map<String, dynamic> message;

  const ChannelNewMessageEvent({
    required this.channelId,
    required this.message,
  });

  @override
  List<Object> get props => [channelId, message];

  @override
  String toString() {
    return 'ChannelNewMessageEvent(channelId: $channelId, messageId: ${message['id']})';
  }
}

/// 频道消息移除事件
///
/// 当频道消息被删除或撤回时发布。
final class ChannelMessageDeletedEvent extends AppEvent {
  final String channelId;
  final String messageId;
  final String reason;

  const ChannelMessageDeletedEvent({
    required this.channelId,
    required this.messageId,
    required this.reason,
  });

  @override
  List<Object> get props => [channelId, messageId, reason];
}

/// 频道状态变更事件
///
/// 用于频道资料更新、邀请、支付、订阅状态变化后的 UI 同步。
final class ChannelStateChangedEvent extends AppEvent {
  final String channelId;
  final String action;
  final Map<String, dynamic> payload;

  const ChannelStateChangedEvent({
    required this.channelId,
    required this.action,
    required this.payload,
  });

  @override
  List<Object> get props => [channelId, action, payload];
}

/// 朋友圈时间线变更事件
///
/// 用于接收 `moment_new/moment_like/moment_comment/moment_deleted` 推送后，
/// 通知页面刷新数据。
final class MomentTimelineChangedEvent extends AppEvent {
  /// S2C action
  final String action;

  /// 朋友圈动态 ID
  final String momentId;

  /// 原始 payload
  final Map<String, dynamic> payload;

  const MomentTimelineChangedEvent({
    required this.action,
    required this.momentId,
    required this.payload,
  });

  @override
  List<Object> get props => [action, momentId, payload];

  @override
  String toString() {
    return 'MomentTimelineChangedEvent(action: $action, momentId: $momentId)';
  }
}

/// 频道未读汇总同步来源事件
///
/// 用于观测未读是否按约定走“服务端 pull 汇总 + 本地对账”链路。
final class ChannelUnreadSummarySyncEvent extends AppEvent {
  /// 触发来源（channel_list_load/ws_connected/cache_start/manual 等）
  final String trigger;

  /// 来源标记（固定：server_unread_summary_pull）
  final String source;

  /// 服务端汇总总未读
  final int totalUnread;

  /// 本地订阅表本次变更条目数
  final int changedSubscriptions;

  /// 是否成功
  final bool success;

  const ChannelUnreadSummarySyncEvent({
    required this.trigger,
    required this.source,
    required this.totalUnread,
    required this.changedSubscriptions,
    required this.success,
  });

  @override
  List<Object> get props => [
    trigger,
    source,
    totalUnread,
    changedSubscriptions,
    success,
  ];
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
    message,
    sendToServer,
  ];

  @override
  String toString() {
    return 'ChatMessageAddRequestedEvent(peerId: $peerId, conversationType: $conversationType, sendToServer: $sendToServer)';
  }
}
