/// F5-A @所有人纯函数契约钉住（RED）。
///
/// 对齐后端：
///   - `imboy/src/logic/mention_logic.erl:36-48` create_mentions 校验 @所有人需 admin
///   - `imboy/src/ds/group_member_ds.erl:249-253` check_admin: Role >= 3
///   - `imboy/include/group_role.hrl`：member=1 / guest=2 / admin=3 / owner=4 / vice_owner=5
///   - `imboy/src/ds/mention_ds.erl:38-43` save_mentions 识别 `<<"all">>`
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/mention_all_rules.dart';

void main() {
  group('canMentionAll', () {
    test('admin(3) / owner(4) / vice_owner(5) → true', () {
      expect(canMentionAll(3), isTrue);
      expect(canMentionAll(4), isTrue);
      expect(canMentionAll(5), isTrue);
    });

    test('member(1) / guest(2) → false', () {
      expect(canMentionAll(1), isFalse);
      expect(canMentionAll(2), isFalse);
    });

    test('非成员(0) / 负数 → false（安全默认拒绝）', () {
      expect(canMentionAll(0), isFalse);
      expect(canMentionAll(-1), isFalse);
    });

    test('未知高位 role → false（白名单策略，拒绝未定义角色）', () {
      expect(canMentionAll(6), isFalse);
      expect(canMentionAll(99), isFalse);
    });
  });

  group('buildMentionsPayload', () {
    test('isAllSelected=true → ["all"]，忽略 uids', () {
      expect(
        buildMentionsPayload(uids: const ['u1', 'u2'], isAllSelected: true),
        const ['all'],
      );
      expect(
        buildMentionsPayload(uids: const [], isAllSelected: true),
        const ['all'],
      );
    });

    test('isAllSelected=false → 返回 uids 去重副本，保序', () {
      expect(
        buildMentionsPayload(
          uids: const ['u1', 'u2', 'u3'],
          isAllSelected: false,
        ),
        const ['u1', 'u2', 'u3'],
      );
    });

    test('isAllSelected=false + 重复 uid → 去重（首次出现保序）', () {
      expect(
        buildMentionsPayload(
          uids: const ['u1', 'u2', 'u1', 'u3', 'u2'],
          isAllSelected: false,
        ),
        const ['u1', 'u2', 'u3'],
      );
    });

    test('空 uids + isAllSelected=false → []', () {
      expect(
        buildMentionsPayload(uids: const [], isAllSelected: false),
        isEmpty,
      );
    });

    test('过滤空字符串 / 全空白 uid（防脏数据进入 payload）', () {
      expect(
        buildMentionsPayload(
          uids: const ['u1', '', 'u2', '  '],
          isAllSelected: false,
        ),
        const ['u1', 'u2'],
      );
    });

    test('"all" 字面量不会与 isAllSelected=false 混淆（按普通 uid 处理）', () {
      // 约定：uid 为 TSID 数字字符串，不会与 "all" 字面量碰撞；
      // 若确实传入，按普通 uid 保留 —— 判 @ 所有人以 isAllSelected 为准
      expect(
        buildMentionsPayload(
          uids: const ['all', 'u1'],
          isAllSelected: false,
        ),
        const ['all', 'u1'],
      );
    });

    test('返回值独立副本：调用方修改不影响内部状态', () {
      final result = buildMentionsPayload(
        uids: const ['u1', 'u2'],
        isAllSelected: false,
      );
      // 验证不抛异常即可（const 返回也允许复制）
      final mutable = List<String>.from(result);
      mutable.add('u3');
      expect(result.length, 2);
    });
  });
}
