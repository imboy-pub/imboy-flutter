/// 钉住 `handleGroupMemberRoleS2C` dispatcher 的副作用分派契约 —— slice-4 RED-13。
///
/// 设计与 `group_edit_s2c` 一致：函数注入替代真实 Repo / EventBus，
/// 穷尽分支而不依赖 sqflite / Flutter binding。
///
/// 契约：
///   1. 合法 payload → 先 `applyRoleUpdate(gid, userId, role, updatedAt)`
///      再 `fireEvent(payload)`
///   2. 非法 payload → 两者都不调用，仅 log
///   3. `applyRoleUpdate` 抛异常 → 吞下 + log，`fireEvent` 仍被调用
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/group_member_role_s2c.dart';

void main() {
  group('handleGroupMemberRoleS2C — 分派契约', () {
    late List<(int, int, int, int)> applyCalls;
    late List<GroupMemberRolePayload> fireCalls;
    late List<String> logs;

    setUp(() {
      applyCalls = [];
      fireCalls = [];
      logs = [];
    });

    Future<void> run(
      Map<String, dynamic> payload, {
      Future<void> Function(int, int, int, int)? applyRoleUpdate,
    }) {
      return handleGroupMemberRoleS2C(
        payload: payload,
        applyRoleUpdate: applyRoleUpdate ??
            (gid, userId, role, updatedAt) async =>
                applyCalls.add((gid, userId, role, updatedAt)),
        fireEvent: fireCalls.add,
        log: logs.add,
      );
    }

    test('合法 payload → 先 applyRoleUpdate 再 fireEvent', () async {
      await run({
        'gid': 10,
        'user_id': 200,
        'role': 3,
        'role_text': '管理员',
        'admin_nickname': 'Owner',
        'updated_at': 1760000000,
      });

      expect(applyCalls, [(10, 200, 3, 1760000000)]);
      expect(fireCalls, hasLength(1));
      expect(fireCalls.first.gid, 10);
      expect(fireCalls.first.userId, 200);
      expect(fireCalls.first.role, 3);
      expect(fireCalls.first.roleText, '管理员');
      expect(fireCalls.first.adminNickname, 'Owner');
    });

    test('非法 payload（invalid_role）→ 两个回调都不调用', () async {
      await run({'gid': 1, 'user_id': 2, 'role': 99});
      expect(applyCalls, isEmpty);
      expect(fireCalls, isEmpty);
      expect(
        logs.any((l) => l.contains('invalid_role')),
        isTrue,
      );
    });

    test('非法 payload（invalid_user_id）→ 两个回调都不调用', () async {
      await run({'gid': 1, 'role': 3});
      expect(applyCalls, isEmpty);
      expect(fireCalls, isEmpty);
    });

    test('applyRoleUpdate 抛异常 → fireEvent 仍被调用（吞异常 + log）', () async {
      await run(
        {'gid': 1, 'user_id': 2, 'role': 4},
        applyRoleUpdate: (_, _, _, _) async {
          throw StateError('db locked');
        },
      );

      expect(applyCalls, isEmpty);
      expect(fireCalls, hasLength(1), reason: '广播不应被本地写失败拖垮');
      expect(
        logs.any((l) => l.contains('apply_failed')),
        isTrue,
      );
    });

    test('updated_at 为 0（后端未带）→ applyRoleUpdate 仍接收到 0', () async {
      await run({'gid': 1, 'user_id': 2, 'role': 1});
      expect(applyCalls, [(1, 2, 1, 0)]);
    });
  });
}
