/// ChannelModel / ChannelType / ChannelUserRole 解析契约测试（CMO-1 ~ CMO-4）
///
/// CMO-1  ChannelType 枚举 — index / fromJson 解析
/// CMO-2  ChannelUserRole 枚举 — fromInt / toInt / 计算属性
/// CMO-3  ChannelModel.fromJson — 标准字段 / creator_uid 兼容 / tags 解析
/// CMO-4  ChannelModel.toMap / fromMap 往返 / copyWith / == / hashCode
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/channel_model.dart';

// ─── 测试工厂 ───────────────────────────────────────────────────────────────

ChannelModel _channel({
  int id = 1,
  String name = 'Test',
  ChannelType type = ChannelType.public,
  int creatorId = 100,
  ChannelUserRole userRole = ChannelUserRole.none,
  bool isSubscribed = false,
  bool isVerified = false,
  int subscriberCount = 0,
  List<String>? tags,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final now = DateTime.utc(2025, 1, 1);
  return ChannelModel(
    id: id,
    name: name,
    type: type,
    creatorId: creatorId,
    userRole: userRole,
    isSubscribed: isSubscribed,
    isVerified: isVerified,
    subscriberCount: subscriberCount,
    tags: tags,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
  );
}

void main() {
  // ── CMO-1  ChannelType ─────────────────────────────────────────────────────
  group('CMO-1 ChannelType', () {
    test('index 与枚举顺序对应', () {
      expect(ChannelType.public.index, 0);
      expect(ChannelType.private.index, 1);
      expect(ChannelType.paid.index, 2);
    });

    test('fromJson — 整数 0/1/2 正确解析', () {
      expect(
        ChannelModel.fromJson({
          'id': 1,
          'name': 'x',
          'type': 1,
          'created_at': 0,
          'updated_at': 0,
        }).type,
        ChannelType.private,
      );
      expect(
        ChannelModel.fromJson({
          'id': 1,
          'name': 'x',
          'type': 2,
          'created_at': 0,
          'updated_at': 0,
        }).type,
        ChannelType.paid,
      );
    });

    test('fromJson — 越界值降级为 public', () {
      final model = ChannelModel.fromJson({
        'id': 1,
        'name': 'x',
        'type': 99,
        'created_at': 0,
        'updated_at': 0,
      });
      expect(model.type, ChannelType.public);
    });

    test('fromJson — null 降级为 public', () {
      final model = ChannelModel.fromJson({
        'id': 1,
        'name': 'x',
        'created_at': 0,
        'updated_at': 0,
      });
      expect(model.type, ChannelType.public);
    });
  });

  // ── CMO-2  ChannelUserRole ─────────────────────────────────────────────────
  group('CMO-2 ChannelUserRole', () {
    test('fromInt — 0/1/2/3 正确映射', () {
      expect(ChannelUserRole.fromInt(0), ChannelUserRole.none);
      expect(ChannelUserRole.fromInt(1), ChannelUserRole.editor);
      expect(ChannelUserRole.fromInt(2), ChannelUserRole.admin);
      expect(ChannelUserRole.fromInt(3), ChannelUserRole.creator);
    });

    test('fromInt — null / 未知值 → none', () {
      expect(ChannelUserRole.fromInt(null), ChannelUserRole.none);
      expect(ChannelUserRole.fromInt(99), ChannelUserRole.none);
    });

    test('toInt — 各角色返回正确整数', () {
      expect(ChannelUserRole.none.toInt(), 0);
      expect(ChannelUserRole.subscriber.toInt(), 0);
      expect(ChannelUserRole.editor.toInt(), 1);
      expect(ChannelUserRole.admin.toInt(), 2);
      expect(ChannelUserRole.creator.toInt(), 3);
    });

    test('canPublish — editor/admin/creator 可发布，none/subscriber 不可', () {
      expect(ChannelUserRole.editor.canPublish, isTrue);
      expect(ChannelUserRole.admin.canPublish, isTrue);
      expect(ChannelUserRole.creator.canPublish, isTrue);
      expect(ChannelUserRole.none.canPublish, isFalse);
      expect(ChannelUserRole.subscriber.canPublish, isFalse);
    });

    test('canManage — admin/creator 可管理，其余不可', () {
      expect(ChannelUserRole.admin.canManage, isTrue);
      expect(ChannelUserRole.creator.canManage, isTrue);
      expect(ChannelUserRole.editor.canManage, isFalse);
      expect(ChannelUserRole.none.canManage, isFalse);
    });

    test('isCreator — 仅 creator 返回 true', () {
      expect(ChannelUserRole.creator.isCreator, isTrue);
      expect(ChannelUserRole.admin.isCreator, isFalse);
    });

    test('isAdmin — admin 与 creator 均为 true', () {
      expect(ChannelUserRole.admin.isAdmin, isTrue);
      expect(ChannelUserRole.creator.isAdmin, isTrue);
      expect(ChannelUserRole.editor.isAdmin, isFalse);
    });

    test('displayName — 各角色返回预期文本', () {
      expect(ChannelUserRole.creator.displayName, '创建者');
      expect(ChannelUserRole.admin.displayName, '管理员');
      expect(ChannelUserRole.editor.displayName, '编辑');
      expect(ChannelUserRole.subscriber.displayName, '订阅者');
      expect(ChannelUserRole.none.displayName, '订阅者');
    });
  });

  // ── CMO-3  ChannelModel.fromJson ───────────────────────────────────────────
  group('CMO-3 ChannelModel.fromJson', () {
    final baseMs = 1_750_000_000_000;

    test('标准字段映射', () {
      final model = ChannelModel.fromJson({
        'id': 42,
        'name': 'Tech News',
        'description': 'Daily tech updates',
        'avatar': 'https://img/a.png',
        'type': 0,
        'custom_id': 'tech_news',
        'creator_id': 7,
        'subscriber_count': 500,
        'is_verified': 1,
        'tags': ['tech', 'news'],
        'created_at': baseMs,
        'updated_at': baseMs,
        'user_role': 3,
        'is_subscribed': 1,
      });

      expect(model.id, 42);
      expect(model.name, 'Tech News');
      expect(model.description, 'Daily tech updates');
      expect(model.avatar, 'https://img/a.png');
      expect(model.type, ChannelType.public);
      expect(model.customId, 'tech_news');
      expect(model.creatorId, 7);
      expect(model.subscriberCount, 500);
      expect(model.isVerified, isTrue);
      expect(model.tags, ['tech', 'news']);
      expect(model.createdAt.millisecondsSinceEpoch, baseMs);
      expect(model.userRole, ChannelUserRole.creator);
      expect(model.isSubscribed, isTrue);
    });

    test('creator_uid 优先于 creator_id', () {
      final model = ChannelModel.fromJson({
        'id': 1,
        'name': 'x',
        'creator_uid': 99,
        'creator_id': 10,
        'created_at': baseMs,
        'updated_at': baseMs,
      });
      expect(model.creatorId, 99);
    });

    test('creator_uid 缺失时回退到 creator_id', () {
      final model = ChannelModel.fromJson({
        'id': 1,
        'name': 'x',
        'creator_id': 55,
        'created_at': baseMs,
        'updated_at': baseMs,
      });
      expect(model.creatorId, 55);
    });

    test('nullable 字段缺失时为 null', () {
      final model = ChannelModel.fromJson({
        'id': 1,
        'name': 'x',
        'created_at': baseMs,
        'updated_at': baseMs,
      });
      expect(model.description, isNull);
      expect(model.avatar, isNull);
      expect(model.customId, isNull);
      expect(model.tags, isNull);
    });

    test('tags 为 JSON 字符串时正确解析', () {
      final model = ChannelModel.fromJson({
        'id': 1,
        'name': 'x',
        'tags': jsonEncode(['a', 'b']),
        'created_at': baseMs,
        'updated_at': baseMs,
      });
      expect(model.tags, ['a', 'b']);
    });

    test('is_verified / is_subscribed 为 0 时为 false', () {
      final model = ChannelModel.fromJson({
        'id': 1,
        'name': 'x',
        'is_verified': 0,
        'is_subscribed': 0,
        'created_at': baseMs,
        'updated_at': baseMs,
      });
      expect(model.isVerified, isFalse);
      expect(model.isSubscribed, isFalse);
    });

    test('user_role 缺失时默认 none', () {
      final model = ChannelModel.fromJson({
        'id': 1,
        'name': 'x',
        'created_at': baseMs,
        'updated_at': baseMs,
      });
      expect(model.userRole, ChannelUserRole.none);
    });
  });

  // ── CMO-4  toMap / fromMap / copyWith / == / hashCode ─────────────────────
  group('CMO-4 toMap / fromMap / copyWith / == / hashCode', () {
    test('toMap → fromMap 可重建', () {
      final original = _channel(
        id: 10,
        name: 'My Channel',
        type: ChannelType.private,
        creatorId: 5,
        subscriberCount: 100,
        isVerified: true,
        isSubscribed: true,
        tags: ['flutter', 'dart'],
        userRole: ChannelUserRole.admin,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1_750_000_000_000),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1_750_000_100_000),
      );

      final map = original.toMap();
      final rebuilt = ChannelModel.fromMap(map);

      expect(rebuilt.id, original.id);
      expect(rebuilt.name, original.name);
      expect(rebuilt.type, original.type);
      expect(rebuilt.creatorId, original.creatorId);
      expect(rebuilt.subscriberCount, original.subscriberCount);
      expect(rebuilt.isVerified, original.isVerified);
      expect(rebuilt.isSubscribed, original.isSubscribed);
      expect(rebuilt.tags, original.tags);
      expect(rebuilt.userRole, original.userRole);
      expect(
        rebuilt.createdAt.millisecondsSinceEpoch,
        original.createdAt.millisecondsSinceEpoch,
      );
    });

    test('toMap — tags 编码为 JSON 字符串', () {
      final map = _channel(tags: ['x', 'y']).toMap();
      expect(map['tags'], isA<String>());
      expect(jsonDecode(map['tags'] as String), ['x', 'y']);
    });

    test('toMap — null tags → null', () {
      final map = _channel().toMap();
      expect(map['tags'], isNull);
    });

    test('toMap — is_verified/is_subscribed 编码为 0/1', () {
      final mapT = _channel(isVerified: true, isSubscribed: true).toMap();
      final mapF = _channel(isVerified: false, isSubscribed: false).toMap();
      expect(mapT['is_verified'], 1);
      expect(mapT['is_subscribed'], 1);
      expect(mapF['is_verified'], 0);
      expect(mapF['is_subscribed'], 0);
    });

    test('isManaged — admin/creator 为 true，其余为 false', () {
      expect(_channel(userRole: ChannelUserRole.admin).isManaged, isTrue);
      expect(_channel(userRole: ChannelUserRole.creator).isManaged, isTrue);
      expect(_channel(userRole: ChannelUserRole.editor).isManaged, isFalse);
      expect(_channel(userRole: ChannelUserRole.none).isManaged, isFalse);
    });

    test('canPublish — editor/admin/creator 为 true', () {
      expect(_channel(userRole: ChannelUserRole.editor).canPublish, isTrue);
      expect(_channel(userRole: ChannelUserRole.admin).canPublish, isTrue);
      expect(_channel(userRole: ChannelUserRole.creator).canPublish, isTrue);
      expect(_channel(userRole: ChannelUserRole.none).canPublish, isFalse);
    });

    test('copyWith — 覆盖指定字段', () {
      final original = _channel(id: 5, name: 'Old', subscriberCount: 10);
      final updated = original.copyWith(name: 'New', subscriberCount: 99);
      expect(updated.id, 5);
      expect(updated.name, 'New');
      expect(updated.subscriberCount, 99);
    });

    test('== — 同 id 则相等', () {
      final a = _channel(id: 7, name: 'A');
      final b = _channel(id: 7, name: 'B');
      expect(a == b, isTrue);
    });

    test('== — 不同 id 则不相等', () {
      expect(_channel(id: 1) == _channel(id: 2), isFalse);
    });

    test('hashCode — 等于 id.hashCode', () {
      final ch = _channel(id: 33);
      expect(ch.hashCode, 33.hashCode);
    });
  });
}
