/// ChannelStatsModel / ChannelDailyStatsModel / ChannelReactionModel /
/// ChannelReactionType 解析契约测试（CS-1 ~ CS-4）
///
/// CS-1  ChannelStatsModel.fromJson / toJson
/// CS-2  ChannelDailyStatsModel.fromJson / toJson
/// CS-3  ChannelReactionModel.fromJson / toJson
/// CS-4  ChannelReactionType.getIcon 纯函数契约
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/channel_stats_model.dart';

void main() {
  // ── CS-1  ChannelStatsModel ─────────────────────────────────────────────────
  group('CS-1 ChannelStatsModel', () {
    test('fromJson — 标准字段映射', () {
      final model = ChannelStatsModel.fromJson({
        'channel_id': 42,
        'subscriber_count': 100,
        'total_messages': 200,
        'total_views': 3000,
        'total_reactions': 50,
      });
      expect(model.channelId, 42);
      expect(model.subscriberCount, 100);
      expect(model.totalMessages, 200);
      expect(model.totalViews, 3000);
      expect(model.totalReactions, 50);
    });

    test('fromJson — 字符串数字兼容（parseModelInt）', () {
      final model = ChannelStatsModel.fromJson({
        'channel_id': '7',
        'subscriber_count': '10',
        'total_messages': '20',
        'total_views': '30',
        'total_reactions': '5',
      });
      expect(model.channelId, 7);
      expect(model.subscriberCount, 10);
    });

    test('fromJson — null 字段降级为 0', () {
      final model = ChannelStatsModel.fromJson({});
      expect(model.channelId, 0);
      expect(model.subscriberCount, 0);
      expect(model.totalMessages, 0);
      expect(model.totalViews, 0);
      expect(model.totalReactions, 0);
    });

    test('toJson — 字段名与 fromJson 对称', () {
      final model = ChannelStatsModel(
        channelId: 1,
        subscriberCount: 2,
        totalMessages: 3,
        totalViews: 4,
        totalReactions: 5,
      );
      final json = model.toJson();
      expect(json['channel_id'], 1);
      expect(json['subscriber_count'], 2);
      expect(json['total_messages'], 3);
      expect(json['total_views'], 4);
      expect(json['total_reactions'], 5);
    });

    test('fromJson → toJson 可重建', () {
      final original = {
        'channel_id': 10,
        'subscriber_count': 20,
        'total_messages': 30,
        'total_views': 40,
        'total_reactions': 50,
      };
      final json = ChannelStatsModel.fromJson(original).toJson();
      expect(json, equals(original));
    });
  });

  // ── CS-2  ChannelDailyStatsModel ────────────────────────────────────────────
  group('CS-2 ChannelDailyStatsModel', () {
    final isoDate = '2025-06-15T00:00:00.000Z';

    test('fromJson — 标准字段映射', () {
      final model = ChannelDailyStatsModel.fromJson({
        'channel_id': 1,
        'stats_date': isoDate,
        'new_subscribers': 5,
        'unsubscribers': 2,
        'net_subscribers': 3,
        'messages_count': 100,
        'total_views': 200,
        'total_reactions': 30,
        'active_viewers': 50,
      });
      expect(model.channelId, 1);
      expect(model.newSubscribers, 5);
      expect(model.unsubscribers, 2);
      expect(model.netSubscribers, 3);
      expect(model.statsDate, isA<DateTime>());
    });

    test('fromJson — null 数值字段降级为 0', () {
      final model = ChannelDailyStatsModel.fromJson({'stats_date': isoDate});
      expect(model.newSubscribers, 0);
      expect(model.unsubscribers, 0);
    });

    test('toJson — stats_date 编码为 ISO-8601 字符串', () {
      final date = DateTime.utc(2025, 6, 15);
      final model = ChannelDailyStatsModel(
        channelId: 1,
        statsDate: date,
        newSubscribers: 0,
        unsubscribers: 0,
        netSubscribers: 0,
        messagesCount: 0,
        totalViews: 0,
        totalReactions: 0,
        activeViewers: 0,
      );
      final json = model.toJson();
      expect(json['stats_date'], isA<String>());
      expect(json['stats_date'], contains('2025-06-15'));
    });
  });

  // ── CS-3  ChannelReactionModel ──────────────────────────────────────────────
  group('CS-3 ChannelReactionModel', () {
    final msEpoch = 1_750_000_000_000;
    final isoCreatedAt =
        DateTime.fromMillisecondsSinceEpoch(msEpoch).toIso8601String();

    test('fromJson — 标准字段映射', () {
      final model = ChannelReactionModel.fromJson({
        'id': 1,
        'message_id': 2,
        'channel_id': 3,
        'user_id': 4,
        'reaction_type': 'like',
        'created_at': isoCreatedAt,
      });
      expect(model.id, 1);
      expect(model.messageId, 2);
      expect(model.channelId, 3);
      expect(model.userId, 4);
      expect(model.reactionType, 'like');
      expect(model.createdAt, isA<DateTime>());
    });

    test('fromJson — null 字段降级', () {
      final model = ChannelReactionModel.fromJson({'created_at': isoCreatedAt});
      expect(model.id, 0);
      expect(model.reactionType, '');
    });

    test('toJson — created_at 编码为毫秒时间戳', () {
      final date = DateTime.fromMillisecondsSinceEpoch(msEpoch);
      final model = ChannelReactionModel(
        id: 1,
        messageId: 2,
        channelId: 3,
        userId: 4,
        reactionType: 'heart',
        createdAt: date,
      );
      final json = model.toJson();
      expect(json['created_at'], isA<int>());
      expect(json['created_at'], msEpoch);
    });

    test('toJson — reaction_type 保留原始字符串', () {
      final model = ChannelReactionModel(
        id: 0,
        messageId: 0,
        channelId: 0,
        userId: 0,
        reactionType: 'fire',
        createdAt: DateTime.now(),
      );
      expect(model.toJson()['reaction_type'], 'fire');
    });
  });

  // ── CS-4  ChannelReactionType.getIcon ───────────────────────────────────────
  group('CS-4 ChannelReactionType.getIcon', () {
    test('like → 👍', () {
      expect(ChannelReactionType.getIcon('like'), '👍');
    });

    test('heart → ❤️', () {
      expect(ChannelReactionType.getIcon('heart'), '❤️');
    });

    test('fire → 🔥', () {
      expect(ChannelReactionType.getIcon('fire'), '🔥');
    });

    test('thumbs_up → 👏', () {
      expect(ChannelReactionType.getIcon('thumbs_up'), '👏');
    });

    test('bookmark → 📌', () {
      expect(ChannelReactionType.getIcon('bookmark'), '📌');
    });

    test('未知类型 → 默认 👍', () {
      expect(ChannelReactionType.getIcon('unknown'), '👍');
      expect(ChannelReactionType.getIcon(''), '👍');
    });

    test('all 包含 5 种标准反应类型', () {
      expect(ChannelReactionType.all, hasLength(5));
      expect(
        ChannelReactionType.all,
        containsAll(['like', 'heart', 'fire', 'thumbs_up', 'bookmark']),
      );
    });
  });
}
