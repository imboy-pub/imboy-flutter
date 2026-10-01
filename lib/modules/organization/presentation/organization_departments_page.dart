/// 部门目录页（ORG-04 / ENT-APP-05 生产闭包）：树形浏览 · 详情（含成员
/// 治理）· 管理操作。
///
/// 兼职模型：一人可属多部门；部门 membership 与 Workspace membership
/// 完全独立。管理操作（建/改名/移动/归档/加减成员/局部 admin）入口按
/// 我的组织角色做**入口隐藏**（owner/admin 全量可见；member 仍可浏览
/// 列表——服务端读面与写面同基线：仅限本组织在职成员，非成员/已离场
/// 一律 403，门先于存在性判定）。
///
/// ENT-APP-05 增量：
/// - 部门详情成员列表接通治理面（removeMember / set·unsetAdmin，
///   后端既有路由 `DELETE members/:uid` 与 `PUT members/:uid/admin`）；
///   成员行治理入口经 [PermissionGate] hide——org owner/admin 或**本
///   部门现任 admin** 可见（镜像服务端 is_dept_privileged 授权口径，
///   客户端预隐藏只是体验优化，服务端 403 仍是唯一裁决）；
/// - rename/move 携带 `expected_version`（CAS 乐观锁，后端强制）；
///   409 conflict → 提示并发冲突并刷新最新树（不静默重试）；
/// - 隐藏已知自身/子孙目标；服务端仍裁决 CAS 与成环，错误态透传。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:imboy/component/ui/permission_gate.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/infrastructure/organization_cache.dart';
import 'package:imboy/modules/organization/presentation/organization_ui.dart';

import 'department_parent_picker.dart';

import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

class OrganizationDepartmentsPage extends StatefulWidget {
  const OrganizationDepartmentsPage({
    super.key,
    required this.orgId,
    this.accountKey,
  });

  final EntityId orgId;
  final String? accountKey;

  @override
  State<OrganizationDepartmentsPage> createState() =>
      _OrganizationDepartmentsPageState();
}

class _OrganizationDepartmentsPageState
    extends State<OrganizationDepartmentsPage> {
  final OrganizationApi _api = OrganizationApi();

  List<OrganizationDepartment> _depts = const [];
  bool _loading = false;
  String? _error;

  /// 非成员/已离场撞上服务端读面 403（组织详情页本应已拦截，
  /// 这里兜底手输路由与「停留期间被移出」两种边缘）。
  bool _forbidden = false;

  /// 浏览展开态：orgId → 已展开的部门 id 集合（本地 UI 态，非事实）。
  final Set<EntityId> _expanded = <EntityId>{};

  String get _accountKey => widget.accountKey ?? UserRepoLocal.to.currentUid;

  bool get _canGovern {
    final org = OrganizationCache.forAccount(_accountKey).org(widget.orgId);
    return org?.canGovern == true;
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _forbidden = false;
    });
    try {
      final depts = await _api.departments(widget.orgId);
      OrganizationCache.forAccount(_accountKey)
          .saveDepartments(widget.orgId, depts);
      if (!mounted) return;
      setState(() {
        _depts = depts;
      });
    } on OrganizationApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _forbidden = e.isForbidden;
        _error = e.isForbidden ? null : e.toString();
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _runCommand(
    Future<void> Function() action,
    String failureTitle,
  ) async {
    try {
      await action();
    } on OrganizationApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(switch (e.code) {
            // CAS 并发碰撞（expected_version 不符）：不静默重试——提示
            // 冲突，随后本方法末尾的 _refresh 已把本地树刷成服务端最
            // 新事实，用户基于新 version 重试即可。文案锚点 = 后端
            // map_dept_error(conflict) 冻结的「部门已被并发修改」；
            // 其余 409（cycle 成环等）是操作错误，透传 wire message。
            409 when e.message.contains('并发修改') =>
              t.organization.departments.casConflictHint,
            403 => t.organization.common.forbidden403,
            _ => '$failureTitle：${e.message} (${e.code})',
          }),
        ),
      );
    }
    await _refresh();
  }

  List<OrganizationDepartment> _childrenOf(EntityId parentId) =>
      _depts.where((d) => d.parentId == parentId).toList(growable: false);

  Iterable<Widget> _buildNodes(EntityId parentId, int depth) sync* {
    for (final d in _childrenOf(parentId)) {
      final hasChildren = _childrenOf(d.id).isNotEmpty;
      final expanded = _expanded.contains(d.id);
      yield ListTile(
        contentPadding: EdgeInsets.only(
          left: AppSpacing.regular + depth * AppSpacing.xLarge,
          right: AppSpacing.regular,
        ),
        leading: hasChildren
            ? _departmentExpander(d, expanded)
            : const Icon(CupertinoIcons.folder),
        title: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: d.isArchived
            ? Text(
                orgStatusLabel(d.status),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: _canGovern && !d.isArchived
            ? IconButton(
                icon: Icon(
                  CupertinoIcons.ellipsis,
                  semanticLabel: t.organization.common.moreActions,
                ),
                onPressed: () => _deptActions(d),
              )
            : null,
        // 行点击一律进详情（含成员治理面）；有子部门的部门同样可达——
        // 展开切换收窄到 leading 图标，不再吞掉行点击。
        onTap: () => _openDeptDetail(d.id),
      );
      if (hasChildren && expanded) {
        yield* _buildNodes(d.id, depth + 1);
      }
    }
  }

  Widget _departmentExpander(OrganizationDepartment d, bool expanded) =>
      Semantics(
        button: true,
        label: expanded
            ? t.organization.departments.collapseNode(name: d.name)
            : t.organization.departments.expandNode(name: d.name),
        child: IconButton(
          icon: Icon(
            expanded ? CupertinoIcons.folder_open : CupertinoIcons.folder_fill,
          ),
          onPressed: () => setState(() {
            expanded ? _expanded.remove(d.id) : _expanded.add(d.id);
          }),
        ),
      );

  Future<void> _openDeptDetail(EntityId departmentId) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _DeptDetailSheet(
        orgId: widget.orgId,
        departmentId: departmentId,
        orgCanGovern: _canGovern,
        myUid: _accountKey,
        onGoverned: _refresh,
      ),
    );
  }

  Future<void> _deptActions(OrganizationDepartment d) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_business_outlined),
              title: Text(t.organization.departments.createSubHere),
              onTap: () => Navigator.of(ctx).pop('create-child'),
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.pencil),
              title: Text(t.organization.common.rename),
              onTap: () => Navigator.of(ctx).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.account_tree_outlined),
              title: Text(t.organization.departments.movePickParent),
              onTap: () => Navigator.of(ctx).pop('move'),
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.person_crop_circle_badge_plus),
              title: Text(t.organization.departments.addMemberByUid),
              onTap: () => Navigator.of(ctx).pop('add-member'),
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.archivebox),
              title: Text(t.organization.departments.archiveDept),
              onTap: () => Navigator.of(ctx).pop('archive'),
            ),
          ],
        ),
      ),
    );
    switch (action) {
      case 'create-child':
        await _createChild(d);
      case 'rename':
        await _rename(d);
      case 'move':
        await _move(d);
      case 'add-member':
        await _addMember(d);
      case 'archive':
        await _archive(d);
    }
  }

  Future<void> _create() async {
    final name = await orgPromptInput(
      context,
      title: t.organization.departments.createRootDept,
      hint: t.organization.departments.deptNameLabel,
    );
    if (name == null) return;
    await _runCommand(
      () => _api.createDepartment(widget.orgId, name: name),
      t.organization.common.createFailed,
    );
  }

  Future<void> _createChild(OrganizationDepartment parent) async {
    final name = await orgPromptInput(
      context,
      title: t.organization.departments.createUnder(parent: parent.name),
      hint: t.organization.departments.deptNameLabel,
    );
    if (name == null) return;
    await _runCommand(
      () =>
          _api.createDepartment(widget.orgId, name: name, parentId: parent.id),
      t.organization.common.createFailed,
    );
  }

  Future<void> _rename(OrganizationDepartment d) async {
    final name = await orgPromptInput(
      context,
      title: t.organization.departments.renameDept,
      hint: t.organization.departments.newNameLabel,
      initial: d.name,
    );
    if (name == null) return;
    await _runCommand(
      () => _api.renameDepartment(
        widget.orgId,
        d.id,
        name: name,
        expectedVersion: d.version,
      ),
      t.organization.departments.renameFailed,
    );
  }

  Future<void> _move(OrganizationDepartment d) async {
    final target = await showDepartmentParentPicker(
      context,
      moving: d,
      departments: _depts,
    );
    if (target == null) return;
    await _runCommand(
      () => _api.moveDepartment(
        widget.orgId,
        d.id,
        newParentId: target,
        expectedVersion: d.version,
      ),
      t.organization.departments.moveFailed,
    );
  }

  Future<void> _addMember(OrganizationDepartment d) async {
    final uidText = await orgPromptInput(
      context,
      title: t.organization.departments.addDeptMember,
      hint: t.organization.common.targetUidHint,
    );
    if (uidText == null) return;
    final uid = int.tryParse(uidText);
    if (uid == null || uid <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(t.organization.common.uidMustBePositive)),
      );
      return;
    }
    await _runCommand(
      () => _api.addDepartmentMember(widget.orgId, d.id, '$uid'),
      t.organization.common.addFailed,
    );
  }

  Future<void> _archive(OrganizationDepartment d) async {
    final ok = await orgConfirmDangerAction(
      context,
      title: t.organization.departments.archiveDept,
      consequence: t.organization.departments.archiveConfirmBody(name: d.name),
      confirmText: t.organization.common.confirmArchive,
    );
    if (ok) {
      await _runCommand(
        () => _api.archiveDepartment(widget.orgId, d.id),
        t.organization.departments.archiveFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.organization.departments.title),
        actions: [
          if (_canGovern)
            Semantics(
              button: true,
              label: t.organization.departments.createRootDept,
              child: IconButton(
                icon: const Icon(CupertinoIcons.add),
                tooltip: t.organization.departments.createRootDept,
                onPressed: _create,
              ),
            ),
        ],
      ),
      body: _forbidden
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.lock, size: 40),
                  const SizedBox(height: AppSpacing.small),
                  Text(t.organization.departments.viewForbidden),
                  const SizedBox(height: AppSpacing.regular),
                  TextButton(
                    onPressed: _refresh,
                    child: Text(t.organization.common.reload),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: OrgStateView(
                loading: _loading && _depts.isEmpty,
                error: _error,
                empty: !_loading && _error == null && _depts.isEmpty,
                emptyText: _canGovern
                    ? t.organization.departments.emptyWithHint
                    : t.organization.departments.empty,
                onRetry: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.small,
                  ),
                  children: [
                    ..._buildNodes('', 0),
                    if (_canGovern)
                      ListTile(
                        dense: true,
                        title: Text(
                          t.organization.departments.emptySubtitle,
                          style: context.textStyle(FontSizeType.small),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// 部门详情底部弹层（ENT-APP-05）：部门行 + 成员列表 + 成员治理面。
///
/// 治理授权口径镜像服务端 `is_dept_privileged`：org owner/admin **或**
/// 本部门现任 admin 可执行成员治理（移除/设·取消局部管理员）；
/// 普通成员只见只读列表（[PermissionGate] hide）。服务端 403 仍是
/// 唯一裁决——预隐藏入口只做体验优化。
class _DeptDetailSheet extends StatefulWidget {
  const _DeptDetailSheet({
    required this.orgId,
    required this.departmentId,
    required this.orgCanGovern,
    required this.myUid,
    required this.onGoverned,
  });

  final EntityId orgId;
  final EntityId departmentId;
  final bool orgCanGovern;

  /// 当前账号 UID（部门局部 admin 判定用）。
  final EntityId myUid;

  /// 任一治理命令成功后的外部树刷新回调。
  final VoidCallback onGoverned;

  @override
  State<_DeptDetailSheet> createState() => _DeptDetailSheetState();
}

class _DeptDetailSheetState extends State<_DeptDetailSheet> {
  final OrganizationApi _api = OrganizationApi();

  OrganizationDepartment? _dept;
  List<DepartmentMember> _members = const [];
  bool _loading = false;
  String? _error;

  /// 读面 403（非本组织在职成员）→ 权限终态。
  bool _forbidden = false;

  /// 我是否本部门现任 admin（服务端事实，随 detail 响应刷新）。
  bool get _iAmDeptAdmin =>
      _members.any((m) => m.userId == widget.myUid && m.isAdmin);

  /// 成员治理可见性：org owner/admin 或本部门现任 admin。
  bool get _canGovernMembers => widget.orgCanGovern || _iAmDeptAdmin;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _forbidden = false;
    });
    try {
      final (dept, members) = await _api.departmentDetail(
        widget.orgId,
        widget.departmentId,
      );
      if (!mounted) return;
      setState(() {
        _dept = dept;
        _members = members;
      });
    } on OrganizationApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _forbidden = e.isForbidden;
        _error = e.isForbidden ? null : e.message;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _runMemberCommand(
    String loadingTitle,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on OrganizationApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            e.isForbidden
                ? t.organization.common.forbidden403
                : '$loadingTitle：${e.message} (${e.code})',
          ),
        ),
      );
    }
    // 成功与失败都重读事实：治理后的成员表/局部 admin 标记以服务端
    // 为准；外部树（缓存）同步刷新。
    await _load();
    widget.onGoverned();
  }

  Future<void> _memberActions(DepartmentMember m) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // archived 部门：移除成员仍放行（离开失效目录属清理事），
            // 设/取消 admin 拒绝（archived 禁新写）——镜像服务端闸门。
            ListTile(
              leading: const Icon(
                CupertinoIcons.person_crop_circle_badge_minus,
              ),
              title: Text(
                t.organization.departments.removeMemberUid(userId: m.userId),
              ),
              onTap: () => Navigator.of(ctx).pop('remove'),
            ),
            if (_dept?.isArchived != true)
              ListTile(
                leading: Icon(
                  m.isAdmin
                      ? CupertinoIcons.shield_lefthalf_fill
                      : CupertinoIcons.shield,
                ),
                title: Text(
                  m.isAdmin
                      ? t.organization.departments.unsetDeptAdmin(
                          userId: m.userId,
                        )
                      : t.organization.departments.setDeptAdmin(
                          userId: m.userId,
                        ),
                ),
                onTap: () => Navigator.of(ctx).pop('toggle-admin'),
              ),
          ],
        ),
      ),
    );
    switch (action) {
      case 'remove':
        if (!mounted) return;
        final ok = await orgConfirmDangerAction(
          context,
          title: t.organization.departments.removeMemberUid(userId: m.userId),
          consequence: t.organization.departments.removeMemberConfirm(
            userId: m.userId,
            name: _dept?.name ?? '',
          ),
          confirmText: t.organization.departments.confirmRemoveMember,
        );
        if (ok) {
          await _runMemberCommand(
            t.organization.departments.removeMemberFailed,
            () => _api.removeDepartmentMember(
              widget.orgId,
              widget.departmentId,
              m.userId,
            ),
          );
        }
      case 'toggle-admin':
        await _runMemberCommand(
          t.organization.departments.setAdminFailed,
          () => _api.setDepartmentAdmin(
            widget.orgId,
            widget.departmentId,
            m.userId,
            admin: !m.isAdmin,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dept = _dept;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dept != null)
              ListTile(
                leading: const Icon(CupertinoIcons.folder),
                title: Text(dept.name),
                subtitle: Text(
                  t.organization.departments.statusLine(
                    status: orgStatusLabel(dept.status),
                  ),
                ),
              ),
            const Divider(height: 1),
            if (_forbidden)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.regular),
                child: Text(t.organization.departments.viewForbiddenDetail),
              )
            else if (_loading && dept == null)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.regular),
                child: CircularProgressIndicator(),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.regular),
                child: Text(
                  t.organization.departments.loadFailedWith(
                    msg: _error ?? '',
                    code: 0,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (_members.isEmpty)
                      ListTile(
                        dense: true,
                        title: Text(t.organization.common.noMembers),
                      )
                    else
                      for (final m in _members)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            m.isAdmin
                                ? CupertinoIcons.shield_fill
                                : CupertinoIcons.person,
                          ),
                          title: Text(
                            t.organization.departments.memberUidLine(
                              userId: m.userId,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // 治理入口分层：org owner/admin 或本部门现任
                          // admin 可见；member 不可见（服务端 403 兜底）。
                          trailing: PermissionGate(
                            check: () => _canGovernMembers,
                            behavior: PermissionGateBehavior.hide,
                            child: IconButton(
                              icon: Icon(
                                CupertinoIcons.ellipsis,
                                semanticLabel: t
                                    .organization
                                    .departments
                                    .memberGovernActions,
                              ),
                              onPressed: () => _memberActions(m),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
