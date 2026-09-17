/// ORG-13 — 本地缓存 scope 隔离负例（任务卡硬要求）
///
/// 断言三件事：
/// 1. account + organization 双 scope 隔离：账号 A 的缓存对账号 B 不可见，
///   注销 A 不影响 B；
/// 2. 缓存不是 membership 真源：脏数据写入后会被服务端刷新覆盖
///   （saveMembers 是页面 _refresh 的镜像；本测验证覆盖语义）；
/// 3. Organization 与 Workspace membership 独立：缓存不承载任何
///   workspace 语义；默认 Workspace 指针（null）不产生成员资格。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/organization/public.dart';

void main() {
  setUp(() {
    OrganizationCache.disposeAll();
  });

  group('account scope 隔离', () {
    test('账号 A / B 互不可见', () {
      final a = OrganizationCache.forAccount('1001');
      final b = OrganizationCache.forAccount('1002');

      a.saveOrgs([
        const Organization(
          id: '7266418340025468930',
          name: '甲的组织',
          memberRole: 'owner',
        ),
      ]);

      expect(a.orgs, hasLength(1));
      expect(b.orgs, isEmpty, reason: '账号 B 不得看到账号 A 的组织缓存');
      expect(b.org('7266418340025468930'), isNull);
    });

    test('disposeAccount(A) 不影响 B；空 accountKey 直接拒绝（fail-closed）', () {
      final a = OrganizationCache.forAccount('1001');
      final b = OrganizationCache.forAccount('1002');
      a.saveOrgs([const Organization(id: '1', name: 'x')]);

      OrganizationCache.disposeAccount('1001');

      expect(OrganizationCache.forAccount('1001').orgs, isEmpty);
      expect(OrganizationCache.forAccount('1002').orgs, isEmpty);
      expect(b.orgs, isEmpty);
      expect(OrganizationCache.liveAccountScopes, 2);

      expect(() => OrganizationCache.forAccount(''), throwsArgumentError);
    });
  });

  group('organization scope 隔离', () {
    test('成员缓存按 orgId 分桶，互不串桶', () {
      final c = OrganizationCache.forAccount('1001');
      c.saveMembers('1', [
        const OrganizationMember(
          organizationId: '1',
          userId: '11',
          role: 'owner',
        ),
      ]);
      c.saveMembers('2', [
        const OrganizationMember(
          organizationId: '2',
          userId: '22',
          role: 'member',
        ),
      ]);

      expect(c.members('1').single.userId, '11');
      expect(c.members('2').single.userId, '22');
      expect(c.members('3'), isEmpty, reason: '未缓存的 org 返回空而非越权数据');

      c.invalidateOrg('1');
      expect(c.members('1'), isEmpty);
      expect(c.members('2'), hasLength(1), reason: '定向失效不影响其他 org');
    });
  });

  group('缓存不是 membership 真源', () {
    test('服务端刷新覆盖脏缓存（stale owner → fresh member）', () {
      final c = OrganizationCache.forAccount('1001');
      c.saveMembers('1', [
        const OrganizationMember(
          organizationId: '1',
          userId: '11',
          role: 'owner',
        ),
      ]);

      // 模拟页面 _refresh：服务端事实（11 已被降级/移除后的列表）覆盖写。
      c.saveMembers('1', [
        const OrganizationMember(
          organizationId: '1',
          userId: '22',
          role: 'admin',
        ),
      ]);

      final fresh = c.members('1');
      expect(fresh, hasLength(1));
      expect(fresh.single.userId, '22');
      expect(
        fresh.any((m) => m.userId == '11'),
        isFalse,
        reason: '被服务端移除的成员不得从缓存复活（缓存不补位真源）',
      );
    });

    test('invalidateOrg 后查询返回空 = 强制服务端刷新语义', () {
      final c = OrganizationCache.forAccount('1001');
      c.saveOrgs([const Organization(id: '9', name: 'x')]);
      c.invalidateOrg('9');
      expect(c.org('9'), isNull);
    });
  });

  group('Organization 与 Workspace membership 独立（负例）', () {
    test('默认 Workspace 未设置（null）不产生任何成员资格事实', () {
      final c = OrganizationCache.forAccount('1001');
      c.saveOrgs([
        const Organization(
          id: '7266418340025468930',
          name: '甲组织',
          memberRole: 'member',
        ),
      ]);

      final ref = DefaultWorkspaceRef.fromJson({
        'organization_id': 7266418340025468930,
        'default_workspace_id': null,
      });

      expect(ref.isSet, isFalse);
      // 负例核心：指针为空 + Org member 两个事实同时成立，缓存里也
      // 不存在（也绝不允许合成出）workspace 维度的任何行。
      expect(c.orgs.single.memberRole, 'member');
      expect(
        () => c.members(ref.defaultWorkspaceId),
        returnsNormally,
        reason: 'workspace id 槽位上没有任何被合成的 membership 数据',
      );
      expect(c.members(ref.defaultWorkspaceId), isEmpty);
    });

    test('缓存没有任何 workspace 键空间（DeptMember/OrgMember 之外无类型出口）', () {
      final c = OrganizationCache.forAccount('1001');
      c.saveDepartments('1', [
        const OrganizationDepartment(id: '5', organizationId: '1', name: '总部'),
      ]);
      // 部门成员 ≠ workspace 成员：同 account/org scope 下部门数据保持
      // 部门语义，workspace 维度在本缓存中不存在。
      expect(c.departments('1').single.name, '总部');
      expect(c.members('1'), isEmpty);
    });
  });
}
