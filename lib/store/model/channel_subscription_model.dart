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
      channelId: json['channel_id'] as String,
      subscribedAt: json['subscribed_at'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['subscribed_at'] as int)
          : DateTime.parse(json['subscribed_at'] as String),
      lastReadAt: json['last_read_at'] != null
          ? (json['last_read_at'] is int
              ? DateTime.fromMillisecondsSinceEpoch(json['last_read_at'] as int)
              : DateTime.parse(json['last_read_at'] as String))
          : null,
      lastMessageId: json['last_message_id'] as String?,
      unreadCount: json['unread_count'] as int? ?? 0,
      notificationsEnabled: (json['notifications_enabled'] as int? ?? 1) == 1,
      isPinned: (json['is_pinned'] as int? ?? 0) == 1,
      isMuted: (json['is_muted'] as int? ?? 0) == 1,
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
      channelId: map['channel_id'] as String,
      subscribedAt: DateTime.fromMillisecondsSinceEpoch(
          map['subscribed_at'] as int),
      lastReadAt: map['last_read_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_read_at'] as int)
          : null,
      lastMessageId: map['last_message_id'] as String?,
      unreadCount: map['unread_count'] as int? ?? 0,
      notificationsEnabled: (map['notifications_enabled'] as int? ?? 1) == 1,
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
      isMuted: (map['is_muted'] as int? ?? 0) == 1,
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
