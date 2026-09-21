/// FULL-05 — 企业群治理契约与状态测试（能力项 2 / INT-18..21）。
///
/// 钉住的语义全部来自后端真库套件已证明的事实：
/// 角色白名单（OA 只能分配 1/2/3/5）、群主不可改、归档单向、空更新拒绝、
/// 成员超限**拒绝而非截断**。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/enterprise_app/public.dart';

Map<String, dynamic> detailJson({
  Object? origin = const <String, dynamic>{
    'application_id': '7001',
    'workspace_id': '12',
    'status': 'active',
    'mine': true,
  },
  List<Map<String, dynamic>>? members,
}) => <String, dynamic>{
  'group_id': '555',
  'workspace_id': '12',
  'title': '研发一群',
  'owner_user_id': '1001',
  'member_count': 3,
  'members':
      members ??
      <Map<String, dynamic>>[
        <String, dynamic>{'user_id': '1001', 'role': 4, 'status': 1},
        <String, dynamic>{'user_id': '1002', 'role': 1, 'status': 1},
        <String, dynamic>{'user_id': '1003', 'role': 3, 'status': 1},
      ],
  'origin': origin,
};

void main() {
  group('角色枚举与 OA 分配白名单', () {
    test('数值 → 枚举逐条对齐 group_member.role', () {
      expect(EnterpriseGroupRole.tryParse(0), EnterpriseGroupRole.undefined);
      expect(EnterpriseGroupRole.tryParse(1), EnterpriseGroupRole.member);
      expect(EnterpriseGroupRole.tryParse(2), EnterpriseGroupRole.guest);
      expect(EnterpriseGroupRole.tryParse(3), EnterpriseGroupRole.admin);
      expect(EnterpriseGroupRole.tryParse(4), EnterpriseGroupRole.owner);
      expect(EnterpriseGroupRole.tryParse(5), EnterpriseGroupRole.viceOwner);
      expect(EnterpriseGroupRole.tryParse(6), isNull, reason: '表外值非法');
      expect(EnterpriseGroupRole.tryParse('x'), isNull);
    });

    test('可分配集合恰为 {1,2,3,5}（群主 4 与未定义 0 排除）', () {
      expect(
        EnterpriseGroupRole.assignableRoles.map((r) => r.value).toList(),
        <int>[1, 2, 3, 5],
      );
      expect(EnterpriseGroupRole.owner.assignableFromApplication, isFalse);
      expect(EnterpriseGroupRole.undefined.assignableFromApplication, isFalse);
      expect(EnterpriseGroupRole.owner.isLocked, isTrue);
    });

    test('分配项校验：空 external_user_id / 群主 / 未定义一律拒', () {
      expect(
        const EnterpriseGroupRoleAssignment(
          externalUserId: '',
          role: EnterpriseGroupRole.member,
        ).validate(),
        'missing_external_user_id',
      );
      for (final EnterpriseGroupRole role in <EnterpriseGroupRole>[
        EnterpriseGroupRole.owner,
        EnterpriseGroupRole.undefined,
      ]) {
        expect(
          EnterpriseGroupRoleAssignment(
            externalUserId: 'ext-1',
            role: role,
          ).validate(),
          'role_not_assignable',
          reason: role.labelKey,
        );
      }
      expect(
        const EnterpriseGroupRoleAssignment(
          externalUserId: 'ext-1',
          role: EnterpriseGroupRole.viceOwner,
        ).validate(),
        isNull,
      );
    });

    test('toWire 只发 external_user_id + role（不夹带 TSID 之外的字段）', () {
      final Map<String, dynamic> wire = const EnterpriseGroupRoleAssignment(
        externalUserId: 'ext-1',
        role: EnterpriseGroupRole.admin,
      ).toWire();
      expect(wire.keys.toSet(), <String>{'external_user_id', 'role'});
      expect(wire['role'], 3);
    });
  });

  group('更新草稿校验（INT-19）', () {
    test('空更新拒绝（不产生无意义写入）', () {
      expect(const EnterpriseGroupUpdateDraft().validate(), 'empty_update');
      expect(const EnterpriseGroupUpdateDraft().isEmpty, isTrue);
    });

    test('title 长度边界：1 与 200 通过，201 与空串拒绝', () {
      expect(EnterpriseGroupUpdateDraft(title: 'a').validate(), isNull);
      expect(
        EnterpriseGroupUpdateDraft(
          title: 'a' * EnterpriseGroupUpdateDraft.maxTitleLength,
        ).validate(),
        isNull,
      );
      expect(
        EnterpriseGroupUpdateDraft(
          title: 'a' * (EnterpriseGroupUpdateDraft.maxTitleLength + 1),
        ).validate(),
        'invalid_title',
      );
      expect(EnterpriseGroupUpdateDraft(title: '').validate(), 'invalid_title');
    });

    test('introduction ≤2000；2010 拒绝', () {
      expect(
        EnterpriseGroupUpdateDraft(introduction: 'i' * 2000).validate(),
        isNull,
      );
      expect(
        EnterpriseGroupUpdateDraft(introduction: 'i' * 2010).validate(),
        'invalid_introduction',
      );
    });

    test('partial update：只发给出字段（不把缺省写成空串）', () {
      expect(
        const EnterpriseGroupUpdateDraft(title: '新名').toWire(),
        <String, dynamic>{'title': '新名'},
      );
      expect(
        const EnterpriseGroupUpdateDraft(introduction: '简介').toWire(),
        <String, dynamic>{'introduction': '简介'},
      );
    });
  });

  group('群详情（INT-18）', () {
    test('解析归属行 → 可归档（本 app + 未归档）', () {
      final EnterpriseGroupDetail detail = EnterpriseGroupDetail.fromJson(
        detailJson(),
      );
      expect(detail.groupId, '555');
      expect(detail.isApplicationOwned, isTrue);
      expect(detail.origin!.mine, isTrue);
      expect(detail.canArchive, isTrue);
      expect(detail.isArchived, isFalse);
      expect(detail.hasOwner, isTrue);
    });

    test('无归属行（人类自建群）→ 不可归档', () {
      final EnterpriseGroupDetail detail = EnterpriseGroupDetail.fromJson(
        detailJson(origin: null),
      );
      expect(detail.isApplicationOwned, isFalse);
      expect(detail.origin, isNull);
      expect(detail.canArchive, isFalse);
    });

    test('他人 app 归属 → 不可归档；已归档 → 不可归档（单向）', () {
      final EnterpriseGroupDetail otherApp = EnterpriseGroupDetail.fromJson(
        detailJson(
          origin: <String, dynamic>{
            'application_id': '9999',
            'status': 'active',
            'mine': false,
          },
        ),
      );
      expect(otherApp.canArchive, isFalse);

      final EnterpriseGroupDetail archived = EnterpriseGroupDetail.fromJson(
        detailJson(
          origin: <String, dynamic>{
            'application_id': '7001',
            'status': 'archived',
            'mine': true,
          },
        ),
      );
      expect(archived.isArchived, isTrue);
      expect(archived.canArchive, isFalse);
    });

    test('成员行保留 user_id/role/status 三键（最小字段不丢）', () {
      final EnterpriseGroupDetail detail = EnterpriseGroupDetail.fromJson(
        detailJson(),
      );
      expect(detail.members.first.rawFields.keys.toSet(), <String>{
        'user_id',
        'role',
        'status',
      });
      expect(detail.members[0].role, EnterpriseGroupRole.owner);
      expect(detail.members[2].role, EnterpriseGroupRole.admin);
    });

    test('成员数为 0 / 缺 members → 空列表而不是异常', () {
      final EnterpriseGroupDetail detail = EnterpriseGroupDetail.fromJson(
        <String, dynamic>{'group_id': '1', 'members': null},
      );
      expect(detail.members, isEmpty);
      expect(detail.hasOwner, isFalse);
    });

    test('超限 detail 常量与硬上限同源', () {
      expect(kDetailOverLimit, 'members_over_limit');
      expect(kEnterpriseGroupMaxDetailMembers, 200);
    });
  });

  group('归档结果（INT-21）', () {
    test('首次归档 archived=true / already=false', () {
      final EnterpriseGroupArchiveOutcome out =
          EnterpriseGroupArchiveOutcome.fromJson(<String, dynamic>{
            'archived': true,
          });
      expect(out.archived, isTrue);
      expect(out.already, isFalse);
    });

    test('幂等命中 already=true', () {
      final EnterpriseGroupArchiveOutcome out =
          EnterpriseGroupArchiveOutcome.fromJson(<String, dynamic>{
            'archived': true,
            'already': true,
          });
      expect(out.already, isTrue);
    });
  });
}
