import 'package:imboy/store/model/model_parse_utils.dart';

/// 频道订阅关系模型
///
/// 存储当前用户对频道的订阅信息，包括：
/// - 订阅时间
/// - 未读消息计数
/// - 最后阅读位置
/// - 通知设置
class ChannelSubscriptionModel {
  final String channelId;
  final DateTime subscribedAt;
  final DateTime? lastReadAt;
  final String? lastMessageId;
  final int unreadCount;
  final bool notificationsEnabled;
  final bool isPinned;
  final bool isMuted;

  ChannelSubscriptionModel({
    required this.channelId,
    required this.subscribedAt,
    this.lastReadAt,
    this.lastMessageId,
    this.unreadCount = 0,
    this.notificationsEnabled = true,
    this.isPinned = false,
    this.isMuted = false,
  });

  factory ChannelSubscriptionModel.fromJson(Map<String, dynamic> json) {
    return ChannelSubscriptionModel(
      channelId: parseModelString(json['channel_id']),
      subscribedAt: parseModelDateTime(json['subscribed_at']),
      lastReadAt: json['last_read_at'] != null
          ? parseModelDateTime(json['last_read_at'])
          : null,
      lastMessageId: parseModelNullableString(json['last_message_id']),
      unreadCount: parseModelInt(json['unread_count']),
      notificationsEnabled: parseModelBool(
        json['notifications_enabled'],
        defaultValue: true,
      ),
      isPinned: parseModelBool(json['is_pinned']),
      isMuted: parseModelBool(json['is_muted']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'channel_id': channelId,
      'subscribed_at': subscribedAt.millisecondsSinceEpoch,
      'last_read_at': lastReadAt?.millisecondsSinceEpoch,
      'last_message_id': lastMessageId,
      'unread_count': unreadCount,
      'notifications_enabled': notificationsEnabled ? 1 : 0,
      'is_pinned': isPinned ? 1 : 0,
      'is_muted': isMuted ? 1 : 0,
    };
  }

  /// 从 SQLite Map 创建
  factory ChannelSubscriptionModel.fromMap(Map<String, dynamic> map) {
    return ChannelSubscriptionModel(
      channelId: parseModelString(map['channel_id']),
      subscribedAt: parseModelDateTime(map['subscribed_at']),
      lastReadAt: map['last_read_at'] != null
          ? parseModelDateTime(map['last_read_at'])
          : null,
      lastMessageId: parseModelNullableString(map['last_message_id']),
      unreadCount: parseModelInt(map['unread_count']),
      notificationsEnabled: parseModelBool(
        map['notifications_enabled'],
        defaultValue: true,
      ),
      isPinned: parseModelBool(map['is_pinned']),
      isMuted: parseModelBool(map['is_muted']),
    );
  }

  /// 转换为 SQLite Map
  Map<String, dynamic> toMap() {
    return {
      'channel_id': channelId,
      'subscribed_at': subscribedAt.millisecondsSinceEpoch,
      'last_read_at': lastReadAt?.millisecondsSinceEpoch,
      'last_message_id': lastMessageId,
      'unread_count': unreadCount,
      'notifications_enabled': notificationsEnabled ? 1 : 0,
      'is_pinned': isPinned ? 1 : 0,
      'is_muted': isMuted ? 1 : 0,
    };
  }

  /// 复制并修改部分字段
  ChannelSubscriptionModel copyWith({
    String? channelId,
    DateTime? subscribedAt,
    DateTime? lastReadAt,
    String? lastMessageId,
    int? unreadCount,
    bool? notificationsEnabled,
    bool? isPinned,
    bool? isMuted,
  }) {
    return ChannelSubscriptionModel(
      channelId: channelId ?? this.channelId,
      subscribedAt: subscribedAt ?? this.subscribedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      unreadCount: unreadCount ?? this.unreadCount,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
    );
  }

  @override
  String toString() {
    return 'ChannelSubscriptionModel(channelId: $channelId, unreadCount: $unreadCount, isPinned: $isPinned)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChannelSubscriptionModel && other.channelId == channelId;
  }

  @override
  int get hashCode => channelId.hashCode;
}
