/// Organization 本地缓存（展示加速，**不是 membership 真源**）
///
/// 隔离契约（ORG-13 任务卡）：
/// - 缓存按 `account + organization` 双 scope 隔离：不同登录账号、不同
///   组织互不可见（负例有测试）；
/// - 缓存**永不**作为 membership/role/邀请状态的真源：页面每次进入都从
///   服务端刷新；缓存命中只用于转场期间的即时渲染，服务端响应到达后
///   覆盖写；
/// - 本缓存不承载任何 Workspace membership 语义（Org 与 Workspace
///   membership 独立，C05：default workspace 只是指向事实）。
library;

import 'package:imboy/modules/organization/domain/organization_models.dart';

/// 单账号 scope 的组织缓存。经 [OrganizationCache.forAccount] 取得。
class OrganizationCache {
  OrganizationCache._(this.accountKey);

  /// 归属账号键（登录 UID 字符串；由调用方传入，本类不自行探测）。
  final String accountKey;

  static final Map<String, OrganizationCache> _byAccount =
      <String, OrganizationCache>{};

  /// 取（或建）某账号的缓存 scope。accountKey 为空串时抛 ArgumentError
  /// ——无账号归属的缓存不允许存在（fail-closed）。
  static OrganizationCache forAccount(String accountKey) {
    if (accountKey.isEmpty) {
      throw ArgumentError('accountKey must not be empty');
    }
    return _byAccount.putIfAbsent(
      accountKey,
      () => OrganizationCache._(accountKey),
    );
  }

  /// 注销/切换账号时清理对应 scope（不影响其他账号）。
  static void disposeAccount(String accountKey) {
    _byAccount.remove(accountKey);
  }

  /// 当前存活 scope 数（测试用）。
  static int get liveAccountScopes => _byAccount.length;

  static void disposeAll() => _byAccount.clear();

  final Map<EntityId, Organization> _orgs = <EntityId, Organization>{};
  final Map<EntityId, List<OrganizationMember>> _members =
      <EntityId, List<OrganizationMember>>{};
  final Map<EntityId, List<OrganizationDepartment>> _departments =
      <EntityId, List<OrganizationDepartment>>{};

  // ---- 组织 ----

  void saveOrgs(List<Organization> orgs) {
    for (final o in orgs) {
      if (o.id.isNotEmpty) _orgs[o.id] = o;
    }
  }

  List<Organization> get orgs => _orgs.values.toList(growable: false);

  Organization? org(EntityId orgId) => _orgs[orgId];

  // ---- 成员（展示缓存；真源在服务端 organization_member 表） ----

  void saveMembers(EntityId orgId, List<OrganizationMember> members) {
    _members[orgId] = List.unmodifiable(members);
  }

  List<OrganizationMember> members(EntityId orgId) =>
      _members[orgId] ?? const <OrganizationMember>[];

  // ---- 部门 ----

  void saveDepartments(
    EntityId orgId,
    List<OrganizationDepartment> departments,
  ) {
    _departments[orgId] = List.unmodifiable(departments);
  }

  List<OrganizationDepartment> departments(EntityId orgId) =>
      _departments[orgId] ?? const <OrganizationDepartment>[];

  /// 清空本账号 scope 全部缓存（登出/数据 suspect 时调用）。
  void clear() {
    _orgs.clear();
    _members.clear();
    _departments.clear();
  }

  /// 单组织失效（写操作成功后定向丢弃，下次进入强制服务端刷新）。
  void invalidateOrg(EntityId orgId) {
    _orgs.remove(orgId);
    _members.remove(orgId);
    _departments.remove(orgId);
  }
}
