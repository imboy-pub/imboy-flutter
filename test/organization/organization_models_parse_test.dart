/// ORG-13 — Organization DTO 解析单测（纯 Dart，无网络）
///
/// 契约依据：后端出站白名单投影（organization_logic public_view /
/// organization_member_logic list / organization_invitation_app view /
/// organization_department_app DEPT_KEYS/MEMBER_KEYS / §1.6 preflight）。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/organization/public.dart';

void main() {
  group('TSID 精度（EntityId = String，绝不回转 int）', () {
    test('Organization：JSON integer ID 解析为无损 string', () {
      final org = Organization.fromJson({
        'id': 7266418340025468930,
        'name': '示例组织',
        'owner_id': 7266418340025468931,
        'status': 'active',
        'branding': {'color': '#fff'},
        'settings': <String, dynamic>{},
        'member_role': 'owner',
        'created_at': '1726451200',
        'updated_at': '1726451200',
      });
      expect(org.id, '7266418340025468930');
      expect(org.ownerId, '7266418340025468931');
      expect(org.name, '示例组织');
      expect(org.iAmOwner, isTrue);
      expect(org.canGovern, isTrue);
      expect(org.branding['color'], '#fff');
    });

    test('Organization：member_role 只能来自服务端投影，缺省为空串', () {
      final org = Organization.fromJson({'id': 1, 'name': 'x'});
      expect(org.memberRole, '');
      expect(org.canGovern, isFalse);
    });

    test('OrgInvitation：invitation_id 解析为 string', () {
      final inv = OrgInvitation.fromJson({
        'invitation_id': 910000020,
        'organization_id': 7266418340025468930,
        'target_user_id': 1002,
        'invited_by': 1001,
        'status': 'pending',
        'expires_at': 1726451200,
      });
      expect(inv.invitationId, '910000020');
      expect(inv.organizationId, '7266418340025468930');
      expect(inv.targetUserId, '1002');
      expect(inv.isPending, isTrue);
      expect(inv.token, '');
    });

    test('OrgInvitation：token 只在 create 响应出现', () {
      final created = OrgInvitation.fromJson({
        'invitation_id': 1,
        'organization_id': 2,
        'target_user_id': 3,
        'invited_by': 4,
        'status': 'pending',
        'token': 'one-time-secret',
      });
      expect(created.token, 'one-time-secret');
    });
  });

  group('状态字段保持 wire 语义（未知值原样保留，不臆造分支）', () {
    test('未知组织状态不触发 archived 只读', () {
      final org = Organization.fromJson({
        'id': 1,
        'name': 'x',
        'status': 'brand-new',
      });
      expect(org.status, 'brand-new');
      expect(org.isArchived, isFalse);
    });

    test('archived 组织识别 + 未知邀请状态原样展示', () {
      final org = Organization.fromJson({
        'id': 1,
        'name': 'x',
        'status': 'archived',
      });
      expect(org.isArchived, isTrue);

      final inv = OrgInvitation.fromJson({
        'invitation_id': 1,
        'organization_id': 2,
        'target_user_id': 3,
        'invited_by': 4,
        'status': 'queued',
      });
      expect(inv.status, 'queued');
      expect(inv.isPending, isFalse);
      expect(inv.isExpired, isFalse);
    });

    test('幂等标记：already_accepted / already_terminal', () {
      final inv = OrgInvitation.fromJson({
        'invitation_id': 1,
        'organization_id': 2,
        'target_user_id': 3,
        'invited_by': 4,
        'status': 'accepted',
        'already_accepted': true,
      });
      expect(inv.alreadyAccepted, isTrue);
      expect(inv.alreadyTerminal, isFalse);
    });
  });

  group('C05：默认 Workspace 是指向事实，不构成 workspace membership', () {
    test('服务端 null（未设置）解析为空串，isSet=false', () {
      final ref = DefaultWorkspaceRef.fromJson({
        'organization_id': 7266418340025468930,
        'default_workspace_id': null,
      });
      expect(ref.defaultWorkspaceId, '');
      expect(ref.isSet, isFalse);
    });

    test('有指向时也只是指针；DTO 不携带任何 workspace 角色字段', () {
      final ref = DefaultWorkspaceRef.fromJson({
        'organization_id': 1,
        'default_workspace_id': 7266418340025468933,
        // 服务端从不携带（也禁止客户端推断）membership 语义；构造入参
        // 里即使混入也不产生字段（DTO 无此成员，解析忽略未知键）。
        'workspace_role': 'owner',
      });
      expect(ref.isSet, isTrue);
      expect(ref.defaultWorkspaceId, '7266418340025468933');
      // 负例：DefaultWorkspaceRef 只有 organizationId / defaultWorkspaceId
      // 两个事实字段（编译期保证），不存在可承载 workspace membership
      // 的状态位 —— 由上方构造仅产出两字段佐证。
      expect(DefaultWorkspaceRef(organizationId: '1').defaultWorkspaceId, '');
    });
  });

  group('成员与部门行解析', () {
    test('OrganizationMember：昵称优先展示，owner 行不可治理', () {
      final owner = OrganizationMember.fromJson({
        'organization_id': 1,
        'user_id': 7266418340025468931,
        'role': 'owner',
        'status': 'active',
        'nickname': '',
        'account': 'alice',
        'joined_at': 1726451200,
      });
      expect(owner.displayName, 'alice');
      expect(owner.isOwner, isTrue);
      expect(owner.isGovernable, isFalse);

      final member = OrganizationMember.fromJson({
        'organization_id': 1,
        'user_id': 2,
        'role': 'admin',
        'nickname': '小明',
      });
      expect(member.displayName, '小明');
      expect(member.isGovernable, isTrue);
    });

    test('OrganizationDepartment：根部门 parentId 为空串', () {
      final root = OrganizationDepartment.fromJson({
        'id': 5,
        'organization_id': 1,
        'parent_id': null,
        'name': '总部',
        'status': 'active',
        'version': 3,
      });
      expect(root.isRoot, isTrue);
      expect(root.version, '3');

      final child = OrganizationDepartment.fromJson({
        'id': 6,
        'organization_id': 1,
        'parent_id': 5,
        'name': '研发',
      });
      expect(child.isRoot, isFalse);
    });

    test('DepartmentMember：is_admin / idempotent 布尔解析', () {
      final m = DepartmentMember.fromJson({
        'organization_id': 1,
        'department_id': 5,
        'user_id': 2,
        'is_admin': true,
        'idempotent': true,
      });
      expect(m.isAdmin, isTrue);
      expect(m.idempotent, isTrue);
    });
  });

  group('§1.6 删除预检报告', () {
    test('blockers / facts 域清单解析', () {
      final report = DeletionPreflightReport.fromJson({
        'subject_user_id': 1001,
        'observed_at': 1726451200123,
        'blockers': [
          {
            'code': 'ORGANIZATION_PRIMARY_OWNER',
            'resource_type': 'organization',
          },
          {'code': 'WORKSPACE_OWNER_ACTIVE', 'resource_type': 'workspace'},
        ],
        'facts': <dynamic>[
          {'domain': 'organization', 'fact_version': 1},
          {'domain': 'workspace', 'fact_version': 1},
          {'domain': 'enterprise_business', 'fact_version': 1},
          {'domain': 'customer_service', 'fact_version': 1},
          {'domain': 'agent', 'fact_version': 1},
        ],
      });
      expect(report.hasBlockers, isTrue);
      expect(report.blockers, hasLength(2));
      expect(report.blockers.first.code, 'ORGANIZATION_PRIMARY_OWNER');
      expect(
        report.factDomains,
        containsAll(<String>['organization', 'agent']),
      );
    });

    test('无阻塞 = hasBlockers false', () {
      final report = DeletionPreflightReport.fromJson({
        'subject_user_id': 1,
        'blockers': <dynamic>[],
        'facts': <dynamic>[],
      });
      expect(report.hasBlockers, isFalse);
    });
  });

  group('时间宽容展示', () {
    test('秒级 / 毫秒级 / 非数字三分支', () {
      expect(flexTsLabel('1726451200'), contains('2024'));
      expect(flexTsLabel('1726451200123'), contains('2024'));
      expect(flexTsLabel('not-a-number'), 'not-a-number');
      expect(flexTsLabel(''), '');
    });
  });
}
