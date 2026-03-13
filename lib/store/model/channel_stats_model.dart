import 'package:imboy/store/model/model_parse_utils.dart';

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
      channelId: parseModelString(json['channel_id']),
      subscriberCount: parseModelInt(json['subscriber_count']),
      totalMessages: parseModelInt(json['total_messages']),
      totalViews: parseModelInt(json['total_views']),
      totalReactions: parseModelInt(json['total_reactions']),
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
      channelId: parseModelString(json['channel_id']),
      statsDate: parseModelDateTime(json['stats_date']),
      newSubscribers: parseModelInt(json['new_subscribers']),
      unsubscribers: parseModelInt(json['unsubscribers']),
      netSubscribers: parseModelInt(json['net_subscribers']),
      messagesCount: parseModelInt(json['messages_count']),
      totalViews: parseModelInt(json['total_views']),
      totalReactions: parseModelInt(json['total_reactions']),
      activeViewers: parseModelInt(json['active_viewers']),
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
      id: parseModelString(json['id']),
      messageId: parseModelString(json['message_id']),
      channelId: parseModelString(json['channel_id']),
      userId: parseModelString(json['user_id']),
      reactionType: parseModelString(json['reaction_type']),
      createdAt: parseModelDateTime(json['created_at']),
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
