/// ChannelModel / ChannelUserRole 解析契约测试（CMO-1 ~ CMO-4）
///
/// CMO-1  正交三字段 visibility/access_type/join_policy — fromJson 解析
/// CMO-2  ChannelUserRole 枚举 — fromInt / toInt / 计算属性
/// CMO-3  ChannelModel.fromJson — 标准字段 / creator_uid 兼容 / tags 解析
/// CMO-4  ChannelModel.toMap / fromMap 往返 / copyWith / == / hashCode
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/channel_model.dart';

// ─── 测试工厂 ───────────────────────────────────────────────────────────────

ChannelModel _channel({
  int id = 1,
  String name = 'Test',
  int visibility = 0,
  int accessType = 0,
  int? joinPolicy,
  int creatorId = 100,
  int price = 0,
  ChannelUserRole userRole = ChannelUserRole.none,
  bool isSubscribed = false,
  bool hasPurchased = false,
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
    visibility: visibility,
    accessType: accessType,
    joinPolicy: joinPolicy ?? (accessType == 1 ? 3 : (visibility == 1 ? 1 : 0)),
    price: price,
    creatorId: creatorId,
    userRole: userRole,
    isSubscribed: isSubscribed,
    hasPurchased: hasPurchased,
    isVerified: isVerified,
    subscriberCount: subscriberCount,
    tags: tags,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
  );
}

void main() {
  // ── CMO-1  正交三字段 ─────────────────────────────────────────────────────
  group('CMO-1 正交三字段', () {
    test('fromJson — visibility/access_type/join_policy 正确解析', () {
      final model = ChannelModel.fromJson({
        'id': 1,
        'name': 'x',
        'visibility': 1,
        'access_type': 1,
        'join_policy': 3,
        'created_at': 0,
        'updated_at': 0,
      });
      expect(model.visibility, 1);
      expect(model.accessType, 1);
      expect(model.joinPolicy, 3);
    });

    test('fromJson — 缺少访问策略字段时 fail-closed', () {
      final model = ChannelModel.fromJson({
        'id': 1,
        'name': 'x',
        'created_at': 0,
        'updated_at': 0,
      });
      expect(model.visibility, ChannelModel.unknownAccessPolicy);
      expect(model.accessType, ChannelModel.unknownAccessPolicy);
      expect(model.joinPolicy, ChannelModel.unknownAccessPolicy);
      expect(model.hasSupportedAccessPolicy, isFalse);
      expect(model.isPublic, isFalse);
    });

    test('isPublic / isPrivate 正确', () {
      final pub = _channel(visibility: 0);
      expect(pub.isPublic, isTrue);
      expect(pub.isPrivate, isFalse);

      final priv = _channel(visibility: 1);
      expect(priv.isPublic, isFalse);
      expect(priv.isPrivate, isTrue);
    });

    test('isPaid / hasPrice 正确', () {
      final free = _channel(accessType: 0);
      expect(free.isPaid, isFalse);
      expect(free.hasPrice, isFalse);

      final paid = _channel(accessType: 1, price: 990);
      expect(paid.isPaid, isTrue);
      expect(paid.hasPrice, isTrue);

      final paidNoPrice = _channel(accessType: 1, price: 0);
      expect(paidNoPrice.isPaid, isTrue);
      expect(paidNoPrice.hasPrice, isFalse);
    });

    test('未定义组合不被视为可用访问策略', () {
      final unsupported = _channel(visibility: 0, accessType: 1, joinPolicy: 0);
      expect(unsupported.hasSupportedAccessPolicy, isFalse);
      expect(unsupported.isPublic, isFalse);
      expect(unsupported.isPaid, isFalse);
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

    test('标准字段映射（含正交三字段）', () {
      final model = ChannelModel.fromJson({
        'id': 42,
        'name': 'Tech News',
        'description': 'Daily tech updates',
        'avatar': 'https://img/a.png',
        'visibility': 0,
        'access_type': 0,
        'join_policy': 0,
        'custom_id': 'tech_news',
        'creator_id': 7,
        'subscriber_count': 500,
        'is_verified': 1,
        'tags': ['tech', 'news'],
        'created_at': baseMs,
        'updated_at': baseMs,
        'user_role': 3,
        'is_subscribed': 1,
        'has_purchased': 1,
      });

      expect(model.id, 42);
      expect(model.name, 'Tech News');
      expect(model.description, 'Daily tech updates');
      expect(model.avatar, 'https://img/a.png');
      expect(model.visibility, 0);
      expect(model.accessType, 0);
      expect(model.joinPolicy, 0);
      expect(model.customId, 'tech_news');
      expect(model.creatorId, 7);
      expect(model.subscriberCount, 500);
      expect(model.isVerified, isTrue);
      expect(model.tags, ['tech', 'news']);
      expect(model.createdAt.millisecondsSinceEpoch, baseMs);
      expect(model.userRole, ChannelUserRole.creator);
      expect(model.isSubscribed, isTrue);
      expect(model.hasPurchased, isTrue);
    });

    test('creator_uid 优先于 creator_id', () {
      final model = ChannelModel.fromJson({
        'id': 1,
        'name': 'x',
        'creator_uid': 999,
        'creator_id': 111,
        'created_at': 0,
        'updated_at': 0,
      });
      expect(model.creatorId, 999);
    });

    test('tags 解析 — 字符串列表', () {
      final model = ChannelModel.fromJson({
        'id': 1,
        'name': 'x',
        'tags': ['a', 'b'],
        'created_at': 0,
        'updated_at': 0,
      });
      expect(model.tags, ['a', 'b']);
    });

    test('tags 解析 — null 安全', () {
      final model = ChannelModel.fromJson({
        'id': 1,
        'name': 'x',
        'created_at': 0,
        'updated_at': 0,
      });
      expect(model.tags, isNull);
    });

    test('toJson 序列化含正交三字段', () {
      final model = ChannelModel.fromJson({
        'id': 1,
        'name': 'x',
        'visibility': 1,
        'access_type': 1,
        'join_policy': 3,
        'created_at': 0,
        'updated_at': 0,
      });
      final json = model.toJson();
      expect(json['visibility'], 1);
      expect(json['access_type'], 1);
      expect(json['join_policy'], 3);
    });
  });

  // ── CMO-4  toMap / fromMap / copyWith / == / hashCode ────────────────────
  group('CMO-4 序列化与复制', () {
    test('toMap / fromMap 往返', () {
      final original = ChannelModel.fromJson({
        'id': 7,
        'name': 'Go',
        'visibility': 1,
        'access_type': 0,
        'join_policy': 1,
        'creator_id': 3,
        'subscriber_count': 100,
        'created_at': 1_750_000_000_000,
        'updated_at': 1_750_000_000_000,
        'user_role': 2,
        'is_subscribed': 1,
      });
      final map = original.toMap();
      final restored = ChannelModel.fromMap(map);
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.visibility, original.visibility);
      expect(restored.accessType, original.accessType);
      expect(restored.joinPolicy, original.joinPolicy);
      expect(restored.creatorId, original.creatorId);
    });

    test('copyWith 正确复制部分字段', () {
      final original = _channel(name: 'Original');
      final copied = original.copyWith(name: 'Copied', visibility: 1);
      expect(copied.name, 'Copied');
      expect(copied.visibility, 1);
      expect(copied.accessType, original.accessType);
      expect(copied.id, original.id);
    });

    test('== 基于 id 判断相等', () {
      final a = _channel(id: 1);
      final b = _channel(id: 1, name: 'Different');
      final c = _channel(id: 2);
      expect(a == b, isTrue);
      expect(a == c, isFalse);
    });

    test('hashCode 与 == 一致', () {
      final a = _channel(id: 42);
      final b = _channel(id: 42);
      // 相等的对象必须有相同的 hashCode
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  // ── CMO-5  isManaged / canPublish 计算属性 ────────────────────────────────
  group('CMO-5 计算属性', () {
    test('isManaged — admin/creator 为 true', () {
      expect(_channel(userRole: ChannelUserRole.admin).isManaged, isTrue);
      expect(_channel(userRole: ChannelUserRole.creator).isManaged, isTrue);
      expect(_channel(userRole: ChannelUserRole.editor).isManaged, isFalse);
      expect(_channel(userRole: ChannelUserRole.subscriber).isManaged, isFalse);
    });

    test('canPublish — editor/admin/creator 为 true', () {
      expect(_channel(userRole: ChannelUserRole.editor).canPublish, isTrue);
      expect(_channel(userRole: ChannelUserRole.admin).canPublish, isTrue);
      expect(_channel(userRole: ChannelUserRole.creator).canPublish, isTrue);
      expect(_channel(userRole: ChannelUserRole.none).canPublish, isFalse);
    });
  });
}
