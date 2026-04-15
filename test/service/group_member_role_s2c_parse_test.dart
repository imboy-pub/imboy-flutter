/// 钉住 S2C `group_member_role` payload 的纯函数解析契约 —— slice-4 RED-12。
///
/// 后端合约（`imboy/src/logic/group_member_logic.erl:351-376`
///           `role_change_notice/4`）：
///   Action  = <<"group_member_role">>
///   Payload = #{
///     <<"gid">>            => integer(),
///     <<"user_id">>        => integer(),  // 被修改角色的成员
///     <<"role">>           => 1..5,        // ROLE_MEMBER..ROLE_VICE_OWNER
///     <<"role_text">>      => binary(),    // "普通成员"/"嘉宾"/"管理员"/"群主"/"副群主"
///     <<"nickname">>       => binary(),    // 被修改成员昵称
///     <<"admin_nickname">> => binary(),    // 操作管理员昵称
///     <<"updated_at">>     => integer()    // 秒级时间戳（elib_dt:now/0）
///   }
///
/// 契约：
///   1. `gid` / `user_id` / `role` 为必需字段，支持 int 与数字 String
///   2. `gid <= 0` → `invalid_gid`
///   3. `user_id <= 0` → `invalid_user_id`
///   4. `role` 必须 ∈ [1..5]，否则 → `invalid_role`
///   5. 文本字段缺失时填 '' 默认值（向后兼容）
///   6. `updated_at` 缺失或非法 → 0（由调用方决定是否丢弃写库）
///   7. sealed result 必须穷尽 switch
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/group_member_role_s2c.dart';

void main() {
  group('parseGroupMemberRolePayload — 必需字段校验', () {
    test('完整合法 payload → GroupMemberRolePayload 全量字段', () {
      final r = parseGroupMemberRolePayload({
        'gid': 10,
        'user_id': 200,
        'role': 3,
        'role_text': '管理员',
        'nickname': 'Alice',
        'admin_nickname': 'Owner',
        'updated_at': 1760000000,
      });
      expect(r, isA<GroupMemberRolePayload>());
      final p = r as GroupMemberRolePayload;
      expect(p.gid, 10);
      expect(p.userId, 200);
      expect(p.role, 3);
      expect(p.roleText, '管理员');
      expect(p.nickname, 'Alice');
      expect(p.adminNickname, 'Owner');
      expect(p.updatedAt, 1760000000);
    });

    test('gid / user_id 为数字 String → 正确强转', () {
      final r = parseGroupMemberRolePayload({
        'gid': '10',
        'user_id': '200',
        'role': 1,
      });
      expect(r, isA<GroupMemberRolePayload>());
      final p = r as GroupMemberRolePayload;
      expect(p.gid, 10);
      expect(p.userId, 200);
    });

    test('gid 缺失 → invalid_gid', () {
      final r = parseGroupMemberRolePayload({'user_id': 1, 'role': 1});
      expect(r, isA<GroupMemberRoleParseError>());
      expect((r as GroupMemberRoleParseError).reason, 'invalid_gid');
    });

    test('gid=0 → invalid_gid', () {
      final r = parseGroupMemberRolePayload({
        'gid': 0,
        'user_id': 1,
        'role': 1,
      });
      expect((r as GroupMemberRoleParseError).reason, 'invalid_gid');
    });

    test('user_id 缺失 → invalid_user_id', () {
      final r = parseGroupMemberRolePayload({'gid': 1, 'role': 1});
      expect((r as GroupMemberRoleParseError).reason, 'invalid_user_id');
    });

    test('user_id <= 0 → invalid_user_id', () {
      final r = parseGroupMemberRolePayload({
        'gid': 1,
        'user_id': 0,
        'role': 1,
      });
      expect((r as GroupMemberRoleParseError).reason, 'invalid_user_id');
    });
  });

  group('parseGroupMemberRolePayload — role 合法范围', () {
    test('role=1..5 全部合法（含副群主 5）', () {
      for (final role in [1, 2, 3, 4, 5]) {
        final r = parseGroupMemberRolePayload({
          'gid': 1,
          'user_id': 2,
          'role': role,
        });
        expect(
          r,
          isA<GroupMemberRolePayload>(),
          reason: 'role=$role 应合法（ROLE_MEMBER..ROLE_VICE_OWNER）',
        );
        expect((r as GroupMemberRolePayload).role, role);
      }
    });

    test('role=0 → invalid_role（非群成员）', () {
      final r = parseGroupMemberRolePayload({
        'gid': 1,
        'user_id': 2,
        'role': 0,
      });
      expect((r as GroupMemberRoleParseError).reason, 'invalid_role');
    });

    test('role=6 / 负数 / 缺失 → invalid_role', () {
      for (final bad in [6, -1, 99]) {
        final r = parseGroupMemberRolePayload({
          'gid': 1,
          'user_id': 2,
          'role': bad,
        });
        expect(
          (r as GroupMemberRoleParseError).reason,
          'invalid_role',
          reason: 'role=$bad 超出 1..5',
        );
      }
      final missing = parseGroupMemberRolePayload({
        'gid': 1,
        'user_id': 2,
      });
      expect((missing as GroupMemberRoleParseError).reason, 'invalid_role');
    });
  });

  group('parseGroupMemberRolePayload — 可选字段缺省', () {
    test('缺文本字段 → 默认 ""', () {
      final r = parseGroupMemberRolePayload({
        'gid': 1,
        'user_id': 2,
        'role': 3,
      });
      final p = r as GroupMemberRolePayload;
      expect(p.roleText, '');
      expect(p.nickname, '');
      expect(p.adminNickname, '');
      expect(p.updatedAt, 0);
    });

    test('updated_at 非法（字符串/负数）→ 0', () {
      final r1 = parseGroupMemberRolePayload({
        'gid': 1,
        'user_id': 2,
        'role': 3,
        'updated_at': 'not-a-number',
      });
      expect((r1 as GroupMemberRolePayload).updatedAt, 0);

      final r2 = parseGroupMemberRolePayload({
        'gid': 1,
        'user_id': 2,
        'role': 3,
        'updated_at': -10,
      });
      expect((r2 as GroupMemberRolePayload).updatedAt, 0);
    });
  });

  group('parseGroupMemberRolePayload — sealed 穷尽', () {
    test('switch 覆盖 GroupMemberRolePayload 和 GroupMemberRoleParseError', () {
      final results = <GroupMemberRoleParseResult>[
        parseGroupMemberRolePayload({'gid': 1, 'user_id': 2, 'role': 3}),
        parseGroupMemberRolePayload({'gid': 0}),
      ];
      for (final r in results) {
        final label = switch (r) {
          GroupMemberRolePayload(:final role) => 'ok:$role',
          GroupMemberRoleParseError(:final reason) => 'err:$reason',
        };
        expect(label, isNotEmpty);
      }
    });
  });
}
