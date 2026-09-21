/// 企业管理页（GZAPP-05）：把「组织 → 工作区 → 群/频道」的治理动作
/// 收在一处，避免治理能力散落在各业务页里各写一套权限判断。
///
/// 权限口径（与后端一致，客户端只做减法）：
/// - 进页前用 `organization/detail` 的 `member_role` 投影判定：非
///   owner/admin 不给治理动作（直达路由也只看到只读事实 + 无权限提示）；
///   真正的裁决始终是服务端 403。
/// - 工作区动作权限仍是「该工作区的 Owner」；组织 owner/admin 不等于
///   工作区 owner，所以工作区行的 Owner 专属动作按 `ownerId` 再裁一次。
///   归档/恢复的具体拒绝（如默认工作区未指定替代时后端拒）原样透出，
///   由用户先设替代再归档。
/// - 群/频道动作权限是「群主/创建者 **或** 本企业 owner/admin」
///   （GZAPP-03 双授权源），客户端不做区分，一律可点，失败按服务端文案。
///
/// 数据来源与已知边界（展示即事实，不臆造）：
/// - 工作区列表 = `workspaces/mine` 里 `organization_id` 等于本企业的项。
///   服务端没有「某企业的工作区」App 面端点（`/adm/...` 是管理后台），
///   因此**只能列出我加入的工作区**——本企业里我没加入的工作区不出现，
///   页面上有说明。这不是权限裁剪，是数据源边界。
/// - 群/频道列表 = `workspaces/:id/groups|channels`（scope=workspace）。
///   频道额外拉一次 `status=archived` 得到归档集合，恢复入口才可达。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:imboy/i18n/strings.g.dart';

import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/presentation/organization_ui.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class OrganizationManagePage extends StatefulWidget {
  const OrganizationManagePage({
    super.key,
    required this.orgId,
    this.accountKey,
  });

  final EntityId orgId;

  /// 缓存账号键；测试可注入。缺省取当前登录账号。
  final String? accountKey;

  @override
  State<OrganizationManagePage> createState() => _OrganizationManagePageState();
}

class _OrganizationManagePageState extends State<OrganizationManagePage> {
  final OrganizationApi _orgApi = OrganizationApi();
  final WorkspaceApi _wsApi = WorkspaceApi();
  final GroupApi _groupApi = GroupApi();
  final ChannelApi _channelApi = ChannelApi();

  Organization? _org;
  List<WorkspaceModel> _workspaces = const [];
  DefaultWorkspaceRef? _defaultWs;

  /// 当前选中治理的工作区（群/频道区的作用域）。
  EntityId _activeWsId = '';

  List<GroupModel> _groups = const [];
  List<ChannelModel> _activeChannels = const [];
  List<ChannelModel> _archivedChannels = const [];
  bool _resourcesLoading = false;
  String? _resourcesError;

  bool _loading = false;
  bool _permissionDenied = false;
  String? _error;

  String get _accountKey => widget.accountKey ?? UserRepoLocal.to.currentUid;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  // ==================== 数据加载 ====================

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _permissionDenied = false;
    });
    try {
      final org = await _orgApi.detail(widget.orgId);
      final page = await _wsApi.mine(size: 100);
      final mine = page.list
          .where((w) => w.belongsToOrg(widget.orgId))
          .toList();
      DefaultWorkspaceRef? defaultWs;
      try {
        defaultWs = await _orgApi.defaultWorkspace(widget.orgId);
      } on OrganizationApiException {
        // 指针事实缺失 ≠ 企业详情失败，不阻断整页。
        defaultWs = null;
      }
      if (!mounted) return;
      setState(() {
        _org = org;
        _workspaces = mine;
        _defaultWs = defaultWs;
        _activeWsId = _pickActiveWs(mine, _activeWsId);
      });
      if (_activeWsId.isNotEmpty) {
        await _loadResources(_activeWsId);
      }
    } on OrganizationApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _permissionDenied = e.isForbidden;
        _error = e.isForbidden ? null : '${e.message} (code=${e.code})';
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

  /// 选中工作区：保持原选择 → 默认工作区 → 首个未归档 → 首个。
  EntityId _pickActiveWs(List<WorkspaceModel> list, EntityId current) {
    for (final w in list) {
      if (w.id == current) return current;
    }
    final defaultId = _defaultWs?.defaultWorkspaceId ?? '';
    for (final w in list) {
      if (w.id == defaultId) return w.id;
    }
    for (final w in list) {
      if (!w.isArchived) return w.id;
    }
    return list.isEmpty ? '' : list.first.id;
  }

  Future<void> _loadResources(EntityId wsId) async {
    setState(() {
      _resourcesLoading = true;
      _resourcesError = null;
    });
    try {
      final groups = await _wsApi.groups(wsId);
      final active = await _wsApi.channels(wsId);
      final archived = await _wsApi.channels(wsId, status: 'archived');
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _activeChannels = active;
        _archivedChannels = archived;
      });
    } on WorkspaceApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _resourcesError = '${e.message} (code=${e.code})';
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _resourcesError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _resourcesLoading = false;
        });
      }
    }
  }

  // ==================== 反馈 ====================

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(text)));
  }

  /// 治理动作统一收口：执行 → 服务端文案透出（不叠兜底）→ 回到服务端事实。
  Future<void> _runGovernance(
    Future<String?> Function() action,
    String failurePrefix,
  ) async {
    String? failure;
    try {
      failure = await action();
    } on WorkspaceApiException catch (e) {
      failure = '${e.message} (code=${e.code})';
    } on OrganizationApiException catch (e) {
      failure = '${e.message} (code=${e.code})';
    } on Object catch (e) {
      failure = e.toString();
    }
    if (failure != null) {
      _toast('$failurePrefix：$failure');
      return;
    }
    await _refresh();
  }

  // ==================== 工作区动作 ====================

  Future<void> _createWorkspace() async {
    final name = await orgPromptInput(
      context,
      title: t.organization.manage.createWorkspace,
      hint: t.organization.manage.workspaceNameHint,
    );
    if (name == null) return;
    // request_id 幂等键：同一意图重试不产生第二个工作区（服务端 Template
    // 初始化是重操作）。用「org + 名称 + 秒级时间」拼装，冲突窗口足够小。
    final requestId =
        'gzapp5-${widget.orgId}-${DateTime.now().millisecondsSinceEpoch}';
    await _runGovernance(() async {
      await _wsApi.create(
        name: name,
        requestId: requestId,
        organizationId: widget.orgId,
      );
      return null;
    }, t.organization.manage.createWorkspace);
  }

  Future<void> _archiveWorkspace(WorkspaceModel ws) async {
    final ok = await orgConfirmDangerAction(
      context,
      title: t.organization.manage.archiveWorkspaceTitle(name: ws.name),
      consequence: t.organization.manage.archiveWorkspaceBody,
    );
    if (!ok) return;
    await _runGovernance(() async {
      await _wsApi.archive(ws.id);
      return null;
    }, t.organization.manage.archiveWorkspace);
  }

  Future<void> _restoreWorkspace(WorkspaceModel ws) async {
    await _runGovernance(() async {
      await _wsApi.restore(ws.id);
      return null;
    }, t.organization.manage.restoreWorkspace);
  }

  Future<void> _setDefaultWorkspace(WorkspaceModel ws) async {
    await _runGovernance(() async {
      await _orgApi.setDefaultWorkspace(widget.orgId, ws.id);
      return null;
    }, t.organization.manage.setDefault);
  }

  bool _isWsOwner(WorkspaceModel ws) => ws.ownerId == _accountKey;

  // ==================== 群 / 频道动作 ====================

  Future<void> _createGroup() async {
    if (_activeWsId.isEmpty) return;
    final title = await orgPromptInput(
      context,
      title: t.organization.manage.createGroup,
      hint: t.organization.manage.groupNameHint,
    );
    if (title == null) return;
    await _runGovernance(() async {
      final created = await _groupApi.createWorkspaceGroup(
        workspaceId: _activeWsId,
        memberUserIds: const [],
      );
      if (created.error != null) return created.error;
      // 建群接口不接群名，补一次改名；补名失败不回滚建群（群已存在是事实），
      // 只把失败说出来。
      if (title.isNotEmpty) {
        final renameErr = await _groupApi.editTitle(
          gid: created.gid,
          title: title,
        );
        if (renameErr != null) return renameErr;
      }
      return null;
    }, t.organization.manage.createGroup);
  }

  Future<void> _dissolveGroup(GroupModel g) async {
    final ok = await orgConfirmDangerAction(
      context,
      title: t.organization.manage.dissolveGroupTitle(name: g.displayTitle),
      consequence: t.organization.manage.dissolveGroupBody,
    );
    if (!ok) return;
    await _runGovernance(
      () => _groupApi.dissolveWithReason(gid: '${g.groupId}'),
      t.organization.manage.dissolveGroup,
    );
  }

  Future<void> _createChannel() async {
    if (_activeWsId.isEmpty) return;
    final name = await orgPromptInput(
      context,
      title: t.organization.manage.createChannel,
      hint: t.organization.manage.channelNameHint,
    );
    if (name == null) return;
    await _runGovernance(() async {
      // 企业频道固定「免费 + 非公开」：内部治理面不该产生付费/公开发现面
      // （GZ-J07「企业频道免费且不公开发现」）。
      final created = await _channelApi.createChannel(
        name: name,
        visibility: 1,
        accessType: 0,
        joinPolicy: 1,
      );
      return created == null ? t.organization.manage.createChannelFailed : null;
    }, t.organization.manage.createChannel);
  }

  Future<void> _archiveChannel(ChannelModel c) async {
    final ok = await orgConfirmDangerAction(
      context,
      title: t.organization.manage.archiveChannelTitle(name: c.name),
      consequence: t.organization.manage.archiveChannelBody,
    );
    if (!ok) return;
    await _runGovernance(
      () => _channelApi.archiveChannel('${c.id}'),
      t.organization.manage.archiveChannel,
    );
  }

  Future<void> _restoreChannel(ChannelModel c) async {
    await _runGovernance(
      () => _channelApi.restoreChannel('${c.id}'),
      t.organization.manage.restoreChannel,
    );
  }

  // ==================== 渲染 ====================

  @override
  Widget build(BuildContext context) {
    final org = _org;
    final canGovern = org?.canGovern ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          t.organization.manage.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: OrgStateView(
          loading: _loading && org == null,
          error: _error,
          permissionDenied: _permissionDenied,
          empty:
              !_loading && _error == null && !_permissionDenied && org == null,
          emptyText: t.organization.manage.orgNotFound,
          onRetry: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
            children: [
              if (org != null)
                ListTile(
                  leading: const Icon(CupertinoIcons.building_2_fill),
                  title: Text(
                    org.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    canGovern
                        ? t.organization.manage.roleLine(
                            role: orgRoleLabel(
                              org.memberRole.isEmpty
                                  ? 'member'
                                  : org.memberRole,
                            ),
                          )
                        : t.organization.manage.readOnlyHint,
                  ),
                ),
              if (org != null && !canGovern) const _ManageForbiddenCard(),
              if (org != null && canGovern) ...[
                const Divider(),
                ..._buildWorkspaceSection(),
                const Divider(),
                ..._buildResourceSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildWorkspaceSection() {
    final defaultId = _defaultWs?.defaultWorkspaceId ?? '';
    return [
      _SectionHeader(
        icon: CupertinoIcons.square_stack_3d_up,
        title: t.organization.manage.workspaceSection,
        action: TextButton(
          key: const ValueKey('org-manage-create-workspace'),
          onPressed: _createWorkspace,
          child: Text(t.organization.manage.createWorkspace),
        ),
      ),
      if (_workspaces.isEmpty)
        ListTile(
          title: Text(t.organization.manage.workspaceEmpty),
          subtitle: Text(t.organization.manage.workspaceEmptyHint),
        )
      else
        for (final ws in _workspaces)
          ListTile(
            key: ValueKey('org-manage-ws-${ws.id}'),
            leading: Icon(
              ws.isArchived
                  ? CupertinoIcons.archivebox
                  : CupertinoIcons.square_stack_3d_up,
              color: ws.isArchived ? Theme.of(context).disabledColor : null,
            ),
            title: Text(ws.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [
                ws.id == defaultId
                    ? t.organization.manage.defaultBadge
                    : t.organization.manage.notDefaultBadge,
                if (ws.isArchived) t.organization.manage.archivedBadge,
                if (_isWsOwner(ws))
                  t.organization.manage.ownerBadge
                else
                  t.organization.manage.memberBadge,
              ].join(' · '),
            ),
            trailing: _wsTrailing(ws, defaultId),
          ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
        child: Text(
          t.organization.manage.workspaceScopeNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ];
  }

  Widget _wsTrailing(WorkspaceModel ws, EntityId defaultId) {
    final items = <PopupMenuEntry<String>>[];
    if (_isWsOwner(ws) && !ws.isArchived && ws.id != defaultId) {
      items.add(
        PopupMenuItem<String>(
          value: 'default',
          child: Text(t.organization.manage.setDefault),
        ),
      );
    }
    if (_isWsOwner(ws) && !ws.isArchived) {
      items.add(
        PopupMenuItem<String>(
          value: 'archive',
          child: Text(t.organization.manage.archiveWorkspace),
        ),
      );
    }
    if (_isWsOwner(ws) && ws.isArchived) {
      items.add(
        PopupMenuItem<String>(
          value: 'restore',
          child: Text(t.organization.manage.restoreWorkspace),
        ),
      );
    }
    if (items.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      key: ValueKey('org-manage-ws-menu-${ws.id}'),
      tooltip: t.organization.common.moreActions,
      onSelected: (value) {
        switch (value) {
          case 'default':
            _setDefaultWorkspace(ws);
          case 'archive':
            _archiveWorkspace(ws);
          case 'restore':
            _restoreWorkspace(ws);
        }
      },
      itemBuilder: (_) => items,
    );
  }

  List<Widget> _buildResourceSection() => [
    _SectionHeader(
      icon: CupertinoIcons.chat_bubble_2,
      title: t.organization.manage.resourceSection,
    ),
    if (_workspaces.isEmpty)
      ListTile(title: Text(t.organization.manage.resourceNeedsWorkspace))
    else ...[
      _wsSelector(),
      if (_resourcesError != null)
        ListTile(
          leading: const Icon(CupertinoIcons.exclamationmark_triangle),
          title: Text(
            t.organization.manage.resourceLoadFailed(err: _resourcesError!),
          ),
          trailing: TextButton(
            onPressed: () => _loadResources(_activeWsId),
            child: Text(t.organization.manage.retry),
          ),
        ),
      if (_resourcesLoading)
        const Padding(
          padding: EdgeInsets.all(AppSpacing.regular),
          child: Center(child: CircularProgressIndicator()),
        )
      else ...[
        _groupBlock(),
        _channelBlock(),
      ],
    ],
  ];

  Widget _wsSelector() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
    child: Wrap(
      spacing: AppSpacing.small,
      children: [
        for (final ws in _workspaces)
          ChoiceChip(
            key: ValueKey('org-manage-ws-chip-${ws.id}'),
            label: Text(ws.name),
            selected: ws.id == _activeWsId,
            onSelected: (_) {
              setState(() {
                _activeWsId = ws.id;
              });
              _loadResources(ws.id);
            },
          ),
      ],
    ),
  );

  Widget _groupBlock() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SubHeader(
        title: t.organization.manage.groupSection,
        actionLabel: t.organization.manage.createGroup,
        actionKey: const ValueKey('org-manage-create-group'),
        onAction: _createGroup,
      ),
      if (_groups.isEmpty)
        ListTile(title: Text(t.organization.manage.groupEmpty))
      else
        for (final g in _groups)
          ListTile(
            key: ValueKey('org-manage-group-${g.groupId}'),
            leading: const Icon(CupertinoIcons.person_2),
            title: Text(
              g.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              t.organization.manage.groupMembers(count: g.memberCount),
            ),
            trailing: IconButton(
              key: ValueKey('org-manage-dissolve-${g.groupId}'),
              icon: const Icon(CupertinoIcons.trash),
              color: Theme.of(context).colorScheme.error,
              tooltip: t.organization.manage.dissolveGroup,
              onPressed: () => _dissolveGroup(g),
            ),
          ),
    ],
  );

  Widget _channelBlock() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SubHeader(
        title: t.organization.manage.channelSection,
        actionLabel: t.organization.manage.createChannel,
        actionKey: const ValueKey('org-manage-create-channel'),
        onAction: _createChannel,
      ),
      ListTile(
        dense: true,
        leading: const Icon(CupertinoIcons.info),
        title: Text(t.organization.manage.channelPolicyNote),
      ),
      if (_activeChannels.isEmpty)
        ListTile(title: Text(t.organization.manage.channelEmpty))
      else
        for (final c in _activeChannels)
          ListTile(
            key: ValueKey('org-manage-channel-${c.id}'),
            leading: const Icon(CupertinoIcons.speaker_3),
            title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              t.organization.manage.channelSubscribers(
                count: c.subscriberCount,
              ),
            ),
            trailing: IconButton(
              key: ValueKey('org-manage-archive-${c.id}'),
              icon: const Icon(CupertinoIcons.archivebox),
              tooltip: t.organization.manage.archiveChannel,
              onPressed: () => _archiveChannel(c),
            ),
          ),
      if (_archivedChannels.isNotEmpty) ...[
        const Divider(),
        _SubHeader(title: t.organization.manage.archivedChannelSection),
        for (final c in _archivedChannels)
          ListTile(
            key: ValueKey('org-manage-archived-channel-${c.id}'),
            leading: Icon(
              CupertinoIcons.archivebox,
              color: Theme.of(context).disabledColor,
            ),
            title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(t.organization.manage.archivedBadge),
            trailing: TextButton(
              key: ValueKey('org-manage-restore-${c.id}'),
              onPressed: () => _restoreChannel(c),
              child: Text(t.organization.manage.restoreChannel),
            ),
          ),
      ],
    ],
  );
}

/// 非 owner/admin 直达本页时的明确态（不是错误，也没有可重试的动作）。
class _ManageForbiddenCard extends StatelessWidget {
  const _ManageForbiddenCard();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: const ValueKey('org-manage-forbidden'),
      leading: const Icon(CupertinoIcons.lock),
      title: Text(t.organization.manage.forbiddenTitle),
      subtitle: Text(t.organization.manage.forbiddenBody),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title, this.action});

  final IconData icon;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _SubHeader extends StatelessWidget {
  const _SubHeader({
    required this.title,
    this.actionLabel,
    this.actionKey,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
          if (actionLabel != null)
            TextButton(
              key: actionKey,
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
