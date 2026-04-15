/// 钉住 GroupMemberModel 的禁言相关契约。
///
/// 背景：后端迁移 `priv/migrations/00000051_group_member_mute.sql` 给
/// `group_member` 增加了 `mute_until TIMESTAMPTZ NULL` 列，API
/// `POST /v1/group_member/mute` 以及 S2C 通知 `group_member_mute` 都
/// 会下发 `mute_until`。客户端必须：
///   1. 能正确持有该字段（nullable，缺省 null 表示未禁言）
///   2. 在 JSON 往返中保持语义（null/int ms/RFC3339 三种输入形态）
///   3. 暴露 `isMuted(nowMs)` 决策方法，作为 UI 与消息发送前拦截的唯一判据
///
/// 关键边界：缺失 `mute_until` 字段必须视为未禁言（不能回退到 now，
/// 否则所有旧数据都会被误判为被禁言中）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/group_member_model.dart';

void main() {
  group('GroupMemberModel.muteUntilMs', () {
    test('默认构造：muteUntilMs 为 null（未禁言）', () {
      final m = GroupMemberModel(
        id: 1,
        groupId: 10,
        userId: 100,
        nickname: 'A',
        avatar: '',
        sign: '',
        account: '',
        alias: '',
        createdAt: 0,
      );

      expect(m.muteUntilMs, isNull);
    });

    test('fromJson：mute_until 缺失 → null（不得回退到 now）', () {
      final json = <String, dynamic>{
        'id': 1,
        'group_id': 10,
        'user_id': 100,
        'created_at': 0,
      };

      final m = GroupMemberModel.fromJson(json);

      expect(m.muteUntilMs, isNull);
    });

    test('fromJson：mute_until 为 null → null', () {
      final json = <String, dynamic>{
        'id': 1,
        'group_id': 10,
        'user_id': 100,
        'mute_until': null,
        'created_at': 0,
      };

      final m = GroupMemberModel.fromJson(json);

      expect(m.muteUntilMs, isNull);
    });

    test('fromJson：mute_until 为 int ms → 原样保留', () {
      final json = <String, dynamic>{
        'id': 1,
        'group_id': 10,
        'user_id': 100,
        'mute_until': 1_700_000_000_000,
        'created_at': 0,
      };

      final m = GroupMemberModel.fromJson(json);

      expect(m.muteUntilMs, 1_700_000_000_000);
    });

    test('fromJson：mute_until 为 RFC3339 string → 解析为 ms', () {
      // 2024-01-01T00:00:00Z = 1704067200000 ms
      final json = <String, dynamic>{
        'id': 1,
        'group_id': 10,
        'user_id': 100,
        'mute_until': '2024-01-01T00:00:00Z',
        'created_at': 0,
      };

      final m = GroupMemberModel.fromJson(json);

      expect(m.muteUntilMs, 1704067200000);
    });

    test('fromJson：mute_until 为非法字符串 → null（不抛异常、不污染）', () {
      final json = <String, dynamic>{
        'id': 1,
        'group_id': 10,
        'user_id': 100,
        'mute_until': 'not-a-date',
        'created_at': 0,
      };

      final m = GroupMemberModel.fromJson(json);

      expect(m.muteUntilMs, isNull);
    });

    test('toJson：muteUntilMs=null → 输出 mute_until: null', () {
      final m = GroupMemberModel(
        id: 1,
        groupId: 10,
        userId: 100,
        nickname: '',
        avatar: '',
        sign: '',
        account: '',
        alias: '',
        createdAt: 0,
      );

      final j = m.toJson();

      expect(j.containsKey('mute_until'), isTrue);
      expect(j['mute_until'], isNull);
    });

    test('toJson：muteUntilMs=非空 → 输出 mute_until: int ms', () {
      final m = GroupMemberModel(
        id: 1,
        groupId: 10,
        userId: 100,
        nickname: '',
        avatar: '',
        sign: '',
        account: '',
        alias: '',
        createdAt: 0,
        muteUntilMs: 1_700_000_000_000,
      );

      final j = m.toJson();

      expect(j['mute_until'], 1_700_000_000_000);
    });
  });

  group('GroupMemberModel.isMuted', () {
    GroupMemberModel buildWith({int? muteUntilMs}) {
      return GroupMemberModel(
        id: 1,
        groupId: 10,
        userId: 100,
        nickname: '',
        avatar: '',
        sign: '',
        account: '',
        alias: '',
        createdAt: 0,
        muteUntilMs: muteUntilMs,
      );
    }

    test('muteUntilMs=null → false（未禁言）', () {
      expect(buildWith().isMuted(nowMs: 1_000_000), isFalse);
    });

    test('muteUntilMs 在 now 之前 → false（已过期）', () {
      final m = buildWith(muteUntilMs: 999);
      expect(m.isMuted(nowMs: 1000), isFalse);
    });

    test('muteUntilMs 等于 now → false（边界：恰好到期视为解禁）', () {
      final m = buildWith(muteUntilMs: 1000);
      expect(m.isMuted(nowMs: 1000), isFalse);
    });

    test('muteUntilMs 在 now 之后 → true（禁言中）', () {
      final m = buildWith(muteUntilMs: 2000);
      expect(m.isMuted(nowMs: 1000), isTrue);
    });

    test('不传 nowMs → 使用 DateTime.now 作为默认', () {
      final future = DateTime.now().millisecondsSinceEpoch + 60_000;
      final past = DateTime.now().millisecondsSinceEpoch - 60_000;

      expect(buildWith(muteUntilMs: future).isMuted(), isTrue);
      expect(buildWith(muteUntilMs: past).isMuted(), isFalse);
    });
  });
}
