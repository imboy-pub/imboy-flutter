/// ChannelSubscriptionModel 解析契约测试（CSUB-1 ~ CSUB-3）
///
/// CSUB-1  fromJson 字段映射 / 默认值
/// CSUB-2  toMap / fromMap 往返
/// CSUB-3  copyWith / == / hashCode
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/channel_subscription_model.dart';

// ─── 测试工厂 ───────────────────────────────────────────────────────────────

ChannelSubscriptionModel _sub({
  int channelId = 1,
  DateTime? subscribedAt,
  DateTime? lastReadAt,
  int? lastMessageId,
  int unreadCount = 0,
  bool notificationsEnabled = true,
  bool isPinned = false,
  bool isMuted = false,
}) {
  return ChannelSubscriptionModel(
    channelId: channelId,
    subscribedAt: subscribedAt ?? DateTime.utc(2025, 1, 1),
    lastReadAt: lastReadAt,
    lastMessageId: lastMessageId,
    unreadCount: unreadCount,
    notificationsEnabled: notificationsEnabled,
    isPinned: isPinned,
    isMuted: isMuted,
  );
}

void main() {
  final baseMs = 1_750_000_000_000;

  // ── CSUB-1  fromJson ───────────────────────────────────────────────────────
  group('CSUB-1 ChannelSubscriptionModel.fromJson', () {
    test('标准字段映射', () {
      final model = ChannelSubscriptionModel.fromJson({
        'channel_id': 42,
        'subscribed_at': baseMs,
        'last_read_at': baseMs + 1000,
        'last_message_id': 99,
        'unread_count': 5,
        'notifications_enabled': 1,
        'is_pinned': 1,
        'is_muted': 0,
      });

      expect(model.channelId, 42);
      expect(model.subscribedAt.millisecondsSinceEpoch, baseMs);
      expect(model.lastReadAt!.millisecondsSinceEpoch, baseMs + 1000);
      expect(model.lastMessageId, 99);
      expect(model.unreadCount, 5);
      expect(model.notificationsEnabled, isTrue);
      expect(model.isPinned, isTrue);
      expect(model.isMuted, isFalse);
    });

    test('last_read_at 为 null 时 lastReadAt 为 null', () {
      final model = ChannelSubscriptionModel.fromJson({
        'channel_id': 1,
        'subscribed_at': baseMs,
      });
      expect(model.lastReadAt, isNull);
    });

    test('notifications_enabled 缺失时默认 true', () {
      final model = ChannelSubscriptionModel.fromJson({
        'channel_id': 1,
        'subscribed_at': baseMs,
      });
      expect(model.notificationsEnabled, isTrue);
    });

    test('is_pinned / is_muted 缺失时默认 false', () {
      final model = ChannelSubscriptionModel.fromJson({
        'channel_id': 1,
        'subscribed_at': baseMs,
      });
      expect(model.isPinned, isFalse);
      expect(model.isMuted, isFalse);
    });

    test('unread_count 缺失时默认 0', () {
      final model = ChannelSubscriptionModel.fromJson({
        'channel_id': 1,
        'subscribed_at': baseMs,
      });
      expect(model.unreadCount, 0);
    });

    test('last_message_id 缺失时为 null', () {
      final model = ChannelSubscriptionModel.fromJson({
        'channel_id': 1,
        'subscribed_at': baseMs,
      });
      expect(model.lastMessageId, isNull);
    });

    test('notifications_enabled = 0 → false', () {
      final model = ChannelSubscriptionModel.fromJson({
        'channel_id': 1,
        'subscribed_at': baseMs,
        'notifications_enabled': 0,
      });
      expect(model.notificationsEnabled, isFalse);
    });
  });

  // ── CSUB-2  toMap / fromMap ────────────────────────────────────────────────
  group('CSUB-2 toMap / fromMap', () {
    test('toMap → fromMap 可重建（含 lastReadAt）', () {
      final original = _sub(
        channelId: 7,
        subscribedAt: DateTime.fromMillisecondsSinceEpoch(baseMs),
        lastReadAt: DateTime.fromMillisecondsSinceEpoch(baseMs + 5000),
        lastMessageId: 42,
        unreadCount: 3,
        notificationsEnabled: false,
        isPinned: true,
        isMuted: true,
      );

      final map = original.toMap();
      final rebuilt = ChannelSubscriptionModel.fromMap(map);

      expect(rebuilt.channelId, original.channelId);
      expect(
        rebuilt.subscribedAt.millisecondsSinceEpoch,
        original.subscribedAt.millisecondsSinceEpoch,
      );
      expect(
        rebuilt.lastReadAt!.millisecondsSinceEpoch,
        original.lastReadAt!.millisecondsSinceEpoch,
      );
      expect(rebuilt.lastMessageId, original.lastMessageId);
      expect(rebuilt.unreadCount, original.unreadCount);
      expect(rebuilt.notificationsEnabled, original.notificationsEnabled);
      expect(rebuilt.isPinned, original.isPinned);
      expect(rebuilt.isMuted, original.isMuted);
    });

    test('toMap → fromMap — null lastReadAt 保持 null', () {
      final original = _sub(channelId: 1);
      final rebuilt = ChannelSubscriptionModel.fromMap(original.toMap());
      expect(rebuilt.lastReadAt, isNull);
    });

    test('toMap — is_pinned/is_muted/notifications_enabled 编码为 0/1', () {
      final mapT = _sub(
        isPinned: true,
        isMuted: true,
        notificationsEnabled: true,
      ).toMap();
      final mapF = _sub(
        isPinned: false,
        isMuted: false,
        notificationsEnabled: false,
      ).toMap();

      expect(mapT['is_pinned'], 1);
      expect(mapT['is_muted'], 1);
      expect(mapT['notifications_enabled'], 1);
      expect(mapF['is_pinned'], 0);
      expect(mapF['is_muted'], 0);
      expect(mapF['notifications_enabled'], 0);
    });

    test('toMap — last_read_at 为 null 时输出 null', () {
      final map = _sub().toMap();
      expect(map['last_read_at'], isNull);
    });

    test('toMap — subscribedAt 编码为毫秒时间戳', () {
      final ms = DateTime.fromMillisecondsSinceEpoch(baseMs);
      final map = _sub(subscribedAt: ms).toMap();
      expect(map['subscribed_at'], isA<int>());
      expect(map['subscribed_at'], baseMs);
    });
  });

  // ── CSUB-3  copyWith / == / hashCode ──────────────────────────────────────
  group('CSUB-3 copyWith / == / hashCode', () {
    test('copyWith — 覆盖指定字段', () {
      final original = _sub(channelId: 5, unreadCount: 0, isMuted: false);
      final updated = original.copyWith(unreadCount: 10, isMuted: true);

      expect(updated.channelId, 5);
      expect(updated.unreadCount, 10);
      expect(updated.isMuted, isTrue);
    });

    test('copyWith — 未覆盖字段保持不变', () {
      final original = _sub(
        channelId: 5,
        notificationsEnabled: false,
        isPinned: true,
      );
      final copy = original.copyWith(unreadCount: 1);

      expect(copy.notificationsEnabled, isFalse);
      expect(copy.isPinned, isTrue);
    });

    test('== — 同 channelId 则相等', () {
      final a = _sub(channelId: 10, unreadCount: 0);
      final b = _sub(channelId: 10, unreadCount: 99);
      expect(a == b, isTrue);
    });

    test('== — 不同 channelId 则不相等', () {
      expect(_sub(channelId: 1) == _sub(channelId: 2), isFalse);
    });

    test('hashCode — 等于 channelId.hashCode', () {
      final sub = _sub(channelId: 88);
      expect(sub.hashCode, 88.hashCode);
    });
  });
}
