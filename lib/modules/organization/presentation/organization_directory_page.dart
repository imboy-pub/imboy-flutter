/// 通讯录（GZAPP-04 G10，计划 §5.2）——全员可见视角的合并视图：
/// 部门树 + 成员列表（只读，无任何治理操作）。
///
/// 数据源（展示即事实，ORG-A13）：
/// - 部门树：GET /organizations/:orgId/departments（本组织在职成员可读）；
/// - 全部成员：GET /organizations/:orgId/members 是**治理面**（owner/admin
///   门）——普通成员 403 时本节降级为受限提示（客户端不预判角色，以
///   服务端 200/403 为准）；
/// - 部门成员：逐部门 departmentDetail（含成员 UID；昵称/头像经成员
///   名单投影补全，无名单时展示 UID，镜像部门目录页口径）。
/// - 成员详情：/organization/:orgId/member/:uid（GZAPP-C3 成员详情页，含该成员
///   在本企业内的有权工作区——§5.2）；页内保留通往通用 IM 资料页 /people/:id
///   的次级入口（发消息/加好友等 IM 能力仍在那）。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/helper/func.dart' show avatarImageProvider;
import 'package:imboy/i18n/strings.g.dart';

import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/presentation/organization_ui.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class OrganizationDirectoryPage extends StatefulWidget {
  const OrganizationDirectoryPage({
    super.key,
    required this.orgId,
    this.orgName = '',
  });

  final EntityId orgId;
  final String orgName;

  @override
  State<OrganizationDirectoryPage> createState() =>
      _OrganizationDirectoryPageState();
}

class _OrganizationDirectoryPageState extends State<OrganizationDirectoryPage> {
  final OrganizationApi _api = OrganizationApi();

  List<OrganizationDepartment> _depts = const [];
  List<OrganizationMember> _members = const [];

  /// 部门 → 成员 UID 集合（departmentDetail 合并；兼职模型下一人可属
  /// 多部门，跨部门不去重属正确展示）。
  final Map<EntityId, Set<EntityId>> _deptUserIds = {};

  /// members() 治理面 403 → true（全员名单节降级为受限提示）。
  bool _membersRestricted = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _membersRestricted = false;
    });
    try {
      final depts = await _api.departments(widget.orgId);
      final members = await _loadMembersBestEffort();
      final deptUsers = await _loadDeptUsers(depts);
      if (!mounted) return;
      setState(() {
        _depts = depts;
        _members = members;
        _deptUserIds
          ..clear()
          ..addAll(deptUsers);
      });
    } on OrganizationApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '${e.message} (code=${e.code})';
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

  /// 治理面名单 best-effort：403 → 受限（空名单 + 降级提示）。
  Future<List<OrganizationMember>> _loadMembersBestEffort() async {
    try {
      return (await _api.members(widget.orgId, size: 100)).list;
    } on OrganizationApiException catch (e) {
      if (e.isForbidden) {
        _membersRestricted = true;
        return const <OrganizationMember>[];
      }
      rethrow;
    }
  }

  Future<Map<EntityId, Set<EntityId>>> _loadDeptUsers(
    List<OrganizationDepartment> depts,
  ) async {
    final result = <EntityId, Set<EntityId>>{};
    for (final d in depts) {
      try {
        final (_, members) = await _api.departmentDetail(widget.orgId, d.id);
        result[d.id] = members.map((m) => m.userId).toSet();
      } on Object {
        // 单部门失败不拖垮整页（其余部门照常展示）。
        result[d.id] = const <EntityId>{};
      }
    }
    return result;
  }

  OrganizationMember? _memberByUid(EntityId uid) {
    for (final m in _members) {
      if (m.userId == uid) return m;
    }
    return null;
  }

  List<OrganizationDepartment> _childrenOf(EntityId parentId) =>
      _depts.where((d) => d.parentId == parentId).toList(growable: false);

  Iterable<Widget> _buildDeptNodes(EntityId parentId, int depth) sync* {
    for (final d in _childrenOf(parentId)) {
      yield ListTile(
        dense: true,
        contentPadding: EdgeInsets.only(
          left: AppSpacing.regular + depth * AppSpacing.xLarge,
          right: AppSpacing.regular,
        ),
        leading: const Icon(CupertinoIcons.folder_fill),
        title: Text(
          d.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      );
      final userIds = _deptUserIds[d.id] ?? const <EntityId>{};
      for (final uid in userIds) {
        yield _buildMemberRow(uid, depth + 1, fromDept: true);
      }
      yield* _buildDeptNodes(d.id, depth + 1);
    }
  }

  Widget _buildMemberRow(EntityId uid, int depth, {bool fromDept = false}) {
    final theme = Theme.of(context);
    final m = _memberByUid(uid);
    final name =
        m?.displayName ?? t.organization.departments.memberUidLine(userId: uid);
    return ListTile(
      key: ValueKey('org-directory-member-${fromDept ? 'dept' : 'all'}-$uid'),
      dense: true,
      contentPadding: EdgeInsets.only(
        left: AppSpacing.regular + depth * AppSpacing.xLarge,
        right: AppSpacing.regular,
      ),
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: theme.colorScheme.primaryContainer,
        backgroundImage: (m?.avatar.isNotEmpty ?? false)
            ? avatarImageProvider(m!.avatar)
            : null,
        child: Icon(
          CupertinoIcons.person_fill,
          size: 16,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: m == null
          ? null
          : Text(orgRoleLabel(m.role), style: theme.textTheme.bodySmall),
      trailing: const Icon(CupertinoIcons.chevron_right, size: 14),
      // §5.2：成员详情必须是企业视角（含该成员在本企业内的有权工作区），
      // 通用 IM 资料页没有企业/工作区信息，故不再作为主入口。
      onTap: () => context.push(
        '/organization/${widget.orgId}/member/$uid',
        extra: <String, dynamic>{'member': m, 'orgName': widget.orgName},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.orgName.isEmpty
              ? t.organization.directory.title
              : '${t.organization.directory.title} · ${widget.orgName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: OrgStateView(
          loading: _loading && _depts.isEmpty && _members.isEmpty,
          error: _error,
          empty:
              !_loading && _error == null && _depts.isEmpty && _members.isEmpty,
          emptyText: t.organization.common.noMembers,
          onRetry: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
            children: [
              _sectionHeader(t.organization.directory.deptSection),
              ..._buildDeptNodes('', 0),
              if (_depts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.regular,
                  ),
                  child: Text(
                    t.organization.departments.empty,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              AppSpacing.verticalSmall,
              _sectionHeader(t.organization.directory.allMembersSection),
              if (_membersRestricted)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.regular,
                  ),
                  child: Text(
                    t.organization.directory.membersRestricted,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final m in _members)
                  _buildMemberRow(m.userId, 0, fromDept: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String label) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
