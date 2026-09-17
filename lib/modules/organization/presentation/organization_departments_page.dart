/// 部门目录页（ORG-04）：树形浏览 · 详情（含成员）· 管理操作。
///
/// 兼职模型：一人可属多部门；部门 membership 与 Workspace membership
/// 完全独立。管理操作（建/改名/移动/归档/加减成员/局部 admin）入口按
/// 我的组织角色做**入口隐藏**（owner/admin 全量可见；member 仍可浏览
/// 列表——服务端对读面不设门，对写面 403 兜底）。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/infrastructure/organization_cache.dart';
import 'package:imboy/modules/organization/presentation/organization_ui.dart';
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
    });
    try {
      final depts = await _api.departments(widget.orgId);
      OrganizationCache.forAccount(_accountKey)
          .saveDepartments(widget.orgId, depts);
      if (!mounted) return;
      setState(() {
        _depts = depts;
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
          content: Text(
            e.isForbidden
                ? '无权执行该操作（403）'
                : '$failureTitle：${e.message} (${e.code})',
          ),
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
        leading: Icon(
          hasChildren
              ? (expanded
                    ? CupertinoIcons.folder_open
                    : CupertinoIcons.folder_fill)
              : CupertinoIcons.folder,
        ),
        title: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          d.isArchived ? orgStatusLabel(d.status) : '部门 ${d.id}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _canGovern && !d.isArchived
            ? IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _deptActions(d),
              )
            : null,
        onTap: () => _openDeptDetail(d),
      );
      if (hasChildren && expanded) {
        yield* _buildNodes(d.id, depth + 1);
      }
    }
  }

  Future<void> _openDeptDetail(OrganizationDepartment d) async {
    if (_childrenOf(d.id).isNotEmpty) {
      setState(() {
        _expanded.contains(d.id) ? _expanded.remove(d.id) : _expanded.add(d.id);
      });
      return;
    }
    try {
      final (dept, members) = await _api.departmentDetail(widget.orgId, d.id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(dept.name),
                subtitle: Text('状态：${orgStatusLabel(dept.status)}'),
              ),
              const Divider(),
              if (members.isEmpty)
                const ListTile(title: Text('暂无成员'))
              else
                for (final m in members)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      m.isAdmin
                          ? Icons.admin_panel_settings_outlined
                          : Icons.person_outline,
                    ),
                    title: Text(
                      '成员 ${m.userId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
            ],
          ),
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text('加载部门失败：$e')));
    }
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
              title: const Text('在其下新建子部门'),
              onTap: () => Navigator.of(ctx).pop('create-child'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('重命名'),
              onTap: () => Navigator.of(ctx).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.account_tree_outlined),
              title: const Text('移动（选择新父部门）'),
              onTap: () => Navigator.of(ctx).pop('move'),
            ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_outlined),
              title: const Text('添加成员（按 UID）'),
              onTap: () => Navigator.of(ctx).pop('add-member'),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('归档部门'),
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
    final name = await orgPromptInput(context, title: '新建根部门', hint: '部门名称');
    if (name == null) return;
    await _runCommand(
      () => _api.createDepartment(widget.orgId, name: name),
      '创建失败',
    );
  }

  Future<void> _createChild(OrganizationDepartment parent) async {
    final name = await orgPromptInput(
      context,
      title: '在「${parent.name}」下新建',
      hint: '部门名称',
    );
    if (name == null) return;
    await _runCommand(
      () =>
          _api.createDepartment(widget.orgId, name: name, parentId: parent.id),
      '创建失败',
    );
  }

  Future<void> _rename(OrganizationDepartment d) async {
    final name = await orgPromptInput(
      context,
      title: '重命名部门',
      hint: '新名称',
      initial: d.name,
    );
    if (name == null) return;
    await _runCommand(
      () => _api.renameDepartment(widget.orgId, d.id, name: name),
      '重命名失败',
    );
  }

  Future<void> _move(OrganizationDepartment d) async {
    final target = await orgPromptInput(
      context,
      title: '移动部门',
      hint: '新父部门 ID（留空 = 提为根）',
    );
    if (target == null) return;
    await _runCommand(
      () => _api.moveDepartment(widget.orgId, d.id, newParentId: target),
      '移动失败',
    );
  }

  Future<void> _addMember(OrganizationDepartment d) async {
    final uidText = await orgPromptInput(
      context,
      title: '添加部门成员',
      hint: '对方用户 UID（数字）',
    );
    if (uidText == null) return;
    final uid = int.tryParse(uidText);
    if (uid == null || uid <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(const SnackBar(content: Text('用户 UID 必须是正整数')));
      return;
    }
    await _runCommand(
      () => _api.addDepartmentMember(widget.orgId, d.id, '$uid'),
      '添加失败',
    );
  }

  Future<void> _archive(OrganizationDepartment d) async {
    final ok = await orgConfirmDangerAction(
      context,
      title: '归档部门',
      consequence: '归档「${d.name}」后该部门进入只读态（成员关系保留）。',
      confirmText: '确认归档',
    );
    if (ok) {
      await _runCommand(
        () => _api.archiveDepartment(widget.orgId, d.id),
        '归档失败',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('部门目录'),
        actions: [
          if (_canGovern)
            Semantics(
              button: true,
              label: '新建根部门',
              child: IconButton(
                icon: const Icon(Icons.add),
                tooltip: '新建根部门',
                onPressed: _create,
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: OrgStateView(
          loading: _loading && _depts.isEmpty,
          error: _error,
          empty: !_loading && _error == null && _depts.isEmpty,
          emptyText: _canGovern ? '暂无部门，点击右上角新建' : '暂无部门',
          onRetry: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
            children: [
              ..._buildNodes('', 0),
              if (_canGovern)
                ListTile(
                  dense: true,
                  title: Text(
                    '兼职模型：同一成员可属多个部门；部门成员须先是本组织成员。',
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
