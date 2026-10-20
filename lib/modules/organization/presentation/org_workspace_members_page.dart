/// ENT-APP-06 — 工作区成员治理面（Organization 治理视角）。
///
/// 与壳内 WorkspaceMembersPage 的边界：那页无参挂载、读壳的
/// currentWorkspaceProvider（当前工作区上下文）；本页由企业管理页按
/// **本企业内选中的工作区**进入，显式携带 workspaceId。两者消费同一组
/// 服务端命令（WorkspaceApi members/invite/removeMember/changeRole/
/// transferOwner），不复制业务语义。
///
/// 权限口径（与后端一致，客户端只做减法）：
/// - 列表：active 工作区成员即可读（服务端门）；
/// - 写动作（改角色/转让/移除/邀请）：仅该工作区 Owner——客户端按
///   detail 的 owner_id 投影裁入口，服务端 403 仍是唯一裁决；
/// - 移除冲突（409：目标仍是项目 Owner / 有未完成任务）时服务端把冲突
///   清单拼进消息，本页原样透出，不做本地绕过。
///
/// 写后一律回到服务端事实（_runGovernance 成功 → _refresh 重读）。
library;

import 'package:imboy/component/ui/resource_page_layout.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';

import 'package:imboy/modules/organization/presentation/org_tool_deep_links.dart';
import 'package:imboy/modules/organization/presentation/organization_ui.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class OrgWorkspaceMembersPage extends StatefulWidget {
  const OrgWorkspaceMembersPage({
    super.key,
    required this.workspaceId,
    this.workspaceName = '',
    this.accountKey,
  });

  final EntityId workspaceId;

  /// 预填标题；页面以 detail 服务端事实为准（预填仅转场即时渲染）。
  final String workspaceName;

  /// 缓存账号键；测试可注入。缺省取当前登录账号。
  final String? accountKey;

  @override
  State<OrgWorkspaceMembersPage> createState() =>
      _OrgWorkspaceMembersPageState();
}

class _OrgWorkspaceMembersPageState extends State<OrgWorkspaceMembersPage> {
  final WorkspaceApi _wsApi = WorkspaceApi();

  WorkspaceModel? _ws;
  List<WorkspaceMemberModel> _members = const [];
  bool _loading = false;
  bool _permissionDenied = false;
  String? _error;

  String get _accountKey => widget.accountKey ?? UserRepoLocal.to.currentUid;

  /// 我是否该工作区 Owner（detail 事实投影；服务端仍是裁决）。
  bool get _isOwner => _ws?.ownerId == _accountKey && _ws != null;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _permissionDenied = false;
    });
    try {
      final ws = await _wsApi.detail(widget.workspaceId);
      final page = await _wsApi.members(widget.workspaceId, size: 100);
      if (!mounted) return;
      setState(() {
        _ws = ws;
        _members = page.list;
      });
    } on WorkspaceApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _permissionDenied = e.code == 403;
        _error = e.code == 403 ? null : '${e.message} (code=${e.code})';
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

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(text)));
  }

  /// 治理命令统一收口：失败原样透出服务端文案（不叠兜底），成功后回到
  /// 服务端事实（重新拉取 detail + members）。
  Future<void> _runGovernance(
    Future<void> Function() action,
    String failurePrefix,
  ) async {
    String? failure;
    try {
      await action();
    } on WorkspaceApiException catch (e) {
      failure = '${e.message} (code=${e.code})';
    } on Object catch (e) {
      failure = e.toString();
    }
    if (failure != null) {
      _toast('$failurePrefix：$failure');
      // 写失败也要回读：服务端可能已部分生效（如最后 Owner 保护回滚），
      // 以服务端事实收敛 UI，不维持本地乐观状态。
    }
    await _refresh();
  }

  Future<void> _invite() async {
    context.push(orgWorkspaceInvitePath(widget.workspaceId));
  }

  Future<void> _changeRole(WorkspaceMemberModel m, WorkspaceMemberRole role) =>
      _runGovernance(
        () => _wsApi.changeRole(
          workspaceId: widget.workspaceId,
          userId: m.userId,
          role: role,
        ),
        t.organization.wsMembers.changeRole,
      );

  Future<void> _transferOwner(WorkspaceMemberModel m) async {
    final ok = await orgConfirmDangerAction(
      context,
      title: t.organization.wsMembers.transferOwnerTitle(
        name: m.nickname.isNotEmpty ? m.nickname : m.userId,
      ),
      consequence: t.organization.wsMembers.transferOwnerBody,
    );
    if (!ok) return;
    await _runGovernance(
      () => _wsApi.transferOwner(
        workspaceId: widget.workspaceId,
        userId: m.userId,
      ),
      t.organization.wsMembers.transferOwner,
    );
  }

  Future<void> _removeMember(WorkspaceMemberModel m) async {
    final ok = await orgConfirmDangerAction(
      context,
      title: t.organization.wsMembers.removeTitle(
        name: m.nickname.isNotEmpty ? m.nickname : m.userId,
      ),
      consequence: t.organization.wsMembers.removeBody,
    );
    if (!ok) return;
    await _runGovernance(
      () => _wsApi.removeMember(
        workspaceId: widget.workspaceId,
        userId: m.userId,
      ),
      t.organization.wsMembers.removeMember,
    );
  }

  // ==================== 渲染 ====================

  @override
  Widget build(BuildContext context) {
    final ws = _ws;
    final title = ws?.name.isNotEmpty == true ? ws!.name : widget.workspaceName;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          t.organization.wsMembers.title(ws: title),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ResourcePageLayout(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: OrgStateView(
            loading: _loading && ws == null,
            error: _error,
            permissionDenied: _permissionDenied,
            empty:
                !_loading && _error == null && !_permissionDenied && ws == null,
            emptyText: t.organization.wsMembers.notFound,
            onRetry: _refresh,
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
    children: [
      ..._governanceHeader(),
      ListTile(
        dense: true,
        title: Text(
          t.organization.wsMembers.memberCount(count: _members.length),
        ),
      ),
      if (_isOwner && _ws!.isArchived)
        ListTile(
          dense: true,
          leading: const Icon(CupertinoIcons.archivebox),
          title: Text(t.organization.wsMembers.archivedReadOnly),
        ),
      ..._memberRows(),
    ],
  );

  /// 治理头区：Owner 给邀请入口；非 Owner 给只读说明。
  List<Widget> _governanceHeader() => _isOwner
      ? [
          ListTile(
            key: const ValueKey('org-ws-invite'),
            leading: const Icon(CupertinoIcons.person_add),
            title: Text(t.organization.wsMembers.invite),
            subtitle: Text(t.organization.wsMembers.inviteHint),
            onTap: _invite,
          ),
          const Divider(),
        ]
      : [
          ListTile(
            dense: true,
            leading: const Icon(CupertinoIcons.lock),
            title: Text(t.organization.wsMembers.readOnlyHint),
          ),
        ];

  List<Widget> _memberRows() => [
    for (final m in _members)
      ListTile(
        key: ValueKey('org-ws-member-${m.userId}'),
        leading: CircleAvatar(child: Text(_avatarChar(m))),
        title: Text(
          m.nickname.isNotEmpty ? m.nickname : m.userId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(_memberSubtitle(m)),
        trailing: _isOwner && m.role != WorkspaceMemberRole.owner
            ? _memberMenu(m)
            : null,
      ),
  ];

  /// 头像字符：昵称/ID 首字；两者皆空（服务端坏行防御）用占位符。
  String _avatarChar(WorkspaceMemberModel m) {
    final label = m.nickname.isNotEmpty ? m.nickname : m.userId;
    return label.isEmpty ? '?' : label.substring(0, 1);
  }

  String _memberSubtitle(WorkspaceMemberModel m) =>
      [_roleLabel(m.role), if (m.account.isNotEmpty) m.account].join(' · ');

  String _roleLabel(WorkspaceMemberRole role) => switch (role) {
    WorkspaceMemberRole.owner => t.organization.wsMembers.roleOwner,
    WorkspaceMemberRole.member => t.organization.wsMembers.roleMember,
    WorkspaceMemberRole.guest => t.organization.wsMembers.roleGuest,
  };

  Widget _memberMenu(WorkspaceMemberModel m) => PopupMenuButton<String>(
    key: ValueKey('org-ws-member-menu-${m.userId}'),
    tooltip: t.organization.common.moreActions,
    onSelected: (value) {
      switch (value) {
        case 'role-member':
          _changeRole(m, WorkspaceMemberRole.member);
        case 'role-guest':
          _changeRole(m, WorkspaceMemberRole.guest);
        case 'transfer':
          _transferOwner(m);
        case 'remove':
          _removeMember(m);
      }
    },
    itemBuilder: (_) => [
      if (m.role != WorkspaceMemberRole.member)
        PopupMenuItem<String>(
          value: 'role-member',
          child: Text(t.organization.wsMembers.setRoleMember),
        ),
      if (m.role != WorkspaceMemberRole.guest)
        PopupMenuItem<String>(
          value: 'role-guest',
          child: Text(t.organization.wsMembers.setRoleGuest),
        ),
      if (!_ws!.isArchived) ...[
        PopupMenuItem<String>(
          value: 'transfer',
          child: Text(t.organization.wsMembers.transferOwner),
        ),
        PopupMenuItem<String>(
          value: 'remove',
          child: Text(t.organization.wsMembers.removeMember),
        ),
      ],
    ],
  );
}
