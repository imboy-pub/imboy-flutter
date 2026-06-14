/// 频道相关事件定义
library;

import 'package:imboy/service/events/base_event.dart';

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

/// 朋友圈通知中心未读数变更事件
///
/// 在以下时机触发：
///   - S2C 新通知落库成功后（moment_like / moment_comment）
///   - 用户点击通知 → 标记已读后
///   - 用户执行"全部已读" / "清空全部" 后
///
/// 订阅方：底部导航"发现"入口红点、通知中心列表页、朋友圈入口红点。
final class MomentNotifyUnreadChangedEvent extends AppEvent {
  /// 当前用户未读总数。
  final int unreadCount;

  /// 触发来源（供 UI debug/埋点使用）：
  /// - `s2c_like` / `s2c_comment` — 新通知入库
  /// - `mark_read` — 单条已读
  /// - `mark_all_read` — 全部已读
  /// - `clear_all` — 清空全部
  /// - `refresh` — UI 主动刷新
  final String trigger;

  const MomentNotifyUnreadChangedEvent({
    required this.unreadCount,
    required this.trigger,
  });

  @override
  List<Object> get props => [unreadCount, trigger];

  @override
  String toString() {
    return 'MomentNotifyUnreadChangedEvent(unread: $unreadCount, trigger: $trigger)';
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
