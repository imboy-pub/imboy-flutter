/// 频道统计数据模型
class ChannelStatsModel {
  final String channelId;
  final int subscriberCount;
  final int totalMessages;
  final int totalViews;
  final int totalReactions;

  ChannelStatsModel({
    required this.channelId,
    required this.subscriberCount,
    required this.totalMessages,
    required this.totalViews,
    required this.totalReactions,
  });

  factory ChannelStatsModel.fromJson(Map<String, dynamic> json) {
    return ChannelStatsModel(
      channelId: json['channel_id'] as String,
      subscriberCount: json['subscriber_count'] as int? ?? 0,
      totalMessages: json['total_messages'] as int? ?? 0,
      totalViews: json['total_views'] as int? ?? 0,
      totalReactions: json['total_reactions'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'channel_id': channelId,
      'subscriber_count': subscriberCount,
      'total_messages': totalMessages,
      'total_views': totalViews,
      'total_reactions': totalReactions,
    };
  }
}

/// 频道每日统计模型
class ChannelDailyStatsModel {
  final String channelId;
  final DateTime statsDate;
  final int newSubscribers;
  final int unsubscribers;
  final int netSubscribers;
  final int messagesCount;
  final int totalViews;
  final int totalReactions;
  final int activeViewers;

  ChannelDailyStatsModel({
    required this.channelId,
    required this.statsDate,
    required this.newSubscribers,
    required this.unsubscribers,
    required this.netSubscribers,
    required this.messagesCount,
    required this.totalViews,
    required this.totalReactions,
    required this.activeViewers,
  });

  factory ChannelDailyStatsModel.fromJson(Map<String, dynamic> json) {
    return ChannelDailyStatsModel(
      channelId: json['channel_id'] as String,
      statsDate: DateTime.parse(json['stats_date'] as String),
      newSubscribers: json['new_subscribers'] as int? ?? 0,
      unsubscribers: json['unsubscribers'] as int? ?? 0,
      netSubscribers: json['net_subscribers'] as int? ?? 0,
      messagesCount: json['messages_count'] as int? ?? 0,
      totalViews: json['total_views'] as int? ?? 0,
      totalReactions: json['total_reactions'] as int? ?? 0,
      activeViewers: json['active_viewers'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'channel_id': channelId,
      'stats_date': statsDate.toIso8601String(),
      'new_subscribers': newSubscribers,
      'unsubscribers': unsubscribers,
      'net_subscribers': netSubscribers,
      'messages_count': messagesCount,
      'total_views': totalViews,
      'total_reactions': totalReactions,
      'active_viewers': activeViewers,
    };
  }
}

/// 消息反应模型
class ChannelReactionModel {
  final String id;
  final String messageId;
  final String channelId;
  final String userId;
  final String reactionType;
  final DateTime createdAt;

  ChannelReactionModel({
    required this.id,
    required this.messageId,
    required this.channelId,
    required this.userId,
    required this.reactionType,
    required this.createdAt,
  });

  factory ChannelReactionModel.fromJson(Map<String, dynamic> json) {
    return ChannelReactionModel(
      id: json['id'] as String,
      messageId: json['message_id'] as String,
      channelId: json['channel_id'] as String,
      userId: json['user_id'] as String,
      reactionType: json['reaction_type'] as String,
      createdAt: json['created_at'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int)
          : DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_id': messageId,
      'channel_id': channelId,
      'user_id': userId,
      'reaction_type': reactionType,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
}

/// 反应类型常量
class ChannelReactionType {
  static const String like = 'like';
  static const String heart = 'heart';
  static const String fire = 'fire';
  static const String thumbsUp = 'thumbs_up';
  static const String bookmark = 'bookmark';

  static const List<String> all = [like, heart, fire, thumbsUp, bookmark];

  /// 获取反应类型的显示图标
  static String getIcon(String type) {
    switch (type) {
      case like:
        return '👍';
      case heart:
        return '❤️';
      case fire:
        return '🔥';
      case thumbsUp:
        return '👏';
      case bookmark:
        return '📌';
      default:
        return '👍';
    }
  }
}
