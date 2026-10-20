/// 组织详情页（ENT-APP-01 Organization 聚合增量）：
/// 企业头信息卡 + 五域入口（成员/部门/群/频道/工具）+ 管理员区
/// （PermissionGate hide）+ danger zone。
///
/// - 四态（Empty/Loading/Error/Permission）经 ENT-FND-02 的
///   [OrgAsyncAdapter] 渲染：catch 的原始异常原样直传，403 分型为权限
///   终态（无重试），其余透传 wire message；
/// - 权限分层：治理类入口（成员治理/邀请管理/企业管理）收进管理员区，
///   [PermissionGate] hide——member 看不到管理员动作；直达路由仍可达，
///   服务端 403 仍是唯一裁决（与 GZAPP-05 口径一致）；
/// - 五域入口全部指向**既有页面**（directory/departments/manage/
///   /workspace），本页只做聚合入口，不新建业务模型；
/// - archived（C16）：整页只读提示，入口区/管理员区不展示；restore 是
///   唯一放行写入口（服务端裁决，客户端只隐藏入口）；
/// - 删除预检（C17）：只读展示本人删除被依赖域 block 的情况；503 =
///   事实不可用即拒，App 原样提示不做降级。
library;

import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoListTile, CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/permission_gate.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/modules/customer_service/presentation/cs_workspace_routes.dart'
    show csGovernancePath;
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/infrastructure/organization_cache.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/modules/organization/presentation/organization_entry_provider.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/modules/organization/presentation/org_async_state.dart';
import 'package:imboy/modules/organization/presentation/organization_routes.dart';
import 'package:imboy/modules/organization/presentation/organization_ui.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/component/ui/resource_entry_tile.dart';

import 'organization_resources_page.dart';

/// 工作区切换器（工具域入口目标）：承载工作区/项目/任务等协同工具。
const String kWorkspacePickerPath = '/workspace';

class OrganizationDetailPage extends StatefulWidget {
  const OrganizationDetailPage({
    super.key,
    required this.orgId,
    this.accountKey,
  });

  final EntityId orgId;

  /// 缓存账号键；测试可注入。缺省取当前登录账号。
  final String? accountKey;

  @override
  State<OrganizationDetailPage> createState() => _OrganizationDetailPageState();
}

class _OrganizationDetailPageState extends State<OrganizationDetailPage> {
  final OrganizationApi _api = OrganizationApi();

  Organization? _org;
  DefaultWorkspaceRef? _defaultWs;
  bool _loading = false;
  bool _leaving = false;
  bool _departed = false;

  /// 原始异常（catch 直传）：403/500 分型交给 [OrgAsyncAdapter]，页面不
  /// 自行解析错误字符串（ENT-FND-02 契约）。
  Object? _error;

  String get _accountKey => widget.accountKey ?? UserRepoLocal.to.currentUid;

  OrganizationCache get _cache => OrganizationCache.forAccount(_accountKey);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (_departed) return;
    final account = _accountKey;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final org = await _api.detail(widget.orgId);
      // 默认 workspace 读取失败不阻断详情（指针事实缺失 ≠ 详情失败）。
      DefaultWorkspaceRef? ws;
      try {
        ws = await _api.defaultWorkspace(widget.orgId);
      } on OrganizationApiException {
        ws = null;
      }
      if (!mounted || _departed || _accountKey != account) return;
      _cache.saveOrgs([org]);
      setState(() {
        _org = org;
        _defaultWs = ws;
      });
    } on Object catch (e) {
      if (!mounted || _departed || _accountKey != account) return;
      setState(() {
        _error = e;
      });
    } finally {
      if (mounted && !_departed && _accountKey == account) {
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
        SnackBar(content: Text('$failureTitle：${e.message} (${e.code})')),
      );
    }
    // 危险操作后一律回到服务端事实。
    await _refresh();
  }

  Future<void> _archive() async {
    final ok = await orgConfirmDangerAction(
      context,
      title: t.organization.detail.archiveOrg,
      consequence: t.organization.detail.archiveConfirmBody,
      confirmText: t.organization.common.confirmArchive,
    );
    if (ok) {
      await _runCommand(
        () => _api.archive(widget.orgId),
        t.organization.detail.archiveFailed,
      );
    }
  }

  Future<void> _leave() async {
    if (_leaving) return;
    final account = _accountKey;
    if (account.isEmpty) return;
    setState(() => _leaving = true);
    try {
      final confirmed = await orgConfirmDangerAction(
        context,
        title: t.organization.detail.leaveOrg,
        consequence: t.organization.detail.leaveOrgBody,
        confirmText: t.organization.detail.leaveOrg,
      );
      if (!confirmed || !mounted || _accountKey != account) return;
      await _api.offboardMember(widget.orgId, account);
      _departed = true;
      OrganizationCache.forAccount(account).invalidateOrg(widget.orgId);
      await _forgetLeftOrganization(account);
      if (mounted && _accountKey == account) context.go(kOrganizationHomePath);
    } on Object catch (e) {
      if (!mounted || _accountKey != account) return;
      final message = e is OrganizationApiException ? e.message : '$e';
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('${t.organization.detail.leaveFailed}：$message'),
        ),
      );
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  Future<void> _forgetLeftOrganization(String account) async {
    if (mounted && _accountKey == account) {
      final container = ProviderScope.containerOf(context, listen: false);
      container
          .read(workspaceShellProvider.notifier)
          .forgetOrganization(widget.orgId);
      container.invalidate(organizationEntryProvider);
    }
    try {
      await CurrentOrganizationStore.forAccount(account).forget(widget.orgId);
    } on Object {
      if (!mounted || _accountKey != account) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(t.organization.detail.leaveCleanupFailed)),
      );
    }
  }

  Future<void> _restore() async {
    final ok = await orgConfirmDangerAction(
      context,
      title: t.organization.detail.restoreOrg,
      consequence: t.organization.detail.restoreConfirmBody,
      confirmText: t.organization.detail.confirmRestore,
    );
    if (ok) {
      await _runCommand(
        () => _api.restore(widget.orgId),
        t.organization.detail.restoreFailed,
      );
    }
  }

  Future<void> _rename() async {
    final name = await orgPromptInput(
      context,
      title: t.organization.detail.renameOrgTitle,
      hint: t.organization.detail.renameOrgLabel,
      initial: _org?.name ?? '',
    );
    if (name == null) return;
    await _runCommand(
      () => _api.update(widget.orgId, name: name),
      t.organization.detail.renameFailed,
    );
  }

  void _showDetails(Organization org) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.8,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.regular),
          children: [
            Text(
              t.organization.experienceUi.enterpriseInfo,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            AppSpacing.verticalRegular,
            Text(org.name),
            Text(
              t.organization.detail.myRoleAndStatus(
                role: orgRoleLabel(org.memberRole),
                status: orgStatusLabel(org.status),
              ),
            ),
            AppSpacing.verticalRegular,
            Text(t.organization.experienceUi.defaultWorkspace),
            Text(
              _defaultWs == null
                  ? t.organization.experienceUi.defaultUnknown
                  : _defaultWs!.isSet
                  ? t.organization.experienceUi.defaultAvailable
                  : t.organization.detail.defaultWsUnset,
            ),
            Text(t.organization.experienceUi.defaultHint),
            AppSpacing.verticalRegular,
            ..._buildDangerZone(org),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final org = _org;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          org?.name ?? t.organization.detail.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (org != null && org.canGovern && !org.isArchived)
            Semantics(
              button: true,
              label: t.organization.detail.renameOrgTitle,
              child: IconButton(
                icon: const Icon(CupertinoIcons.pencil),
                tooltip: t.organization.detail.renameAction,
                onPressed: _rename,
              ),
            ),
        ],
      ),
      backgroundColor: AppColors.getSurfaceGrouped(
        Theme.of(context).brightness,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: OrgAsyncAdapter(
          loading: _loading && _org == null,
          error: _error,
          empty: !_loading && _error == null && _org == null,
          emptyText: t.organization.detail.notFound,
          onRetry: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
            children: [
              if (org != null) _OrgHeaderCard(org: org),
              if (org != null && !org.isArchived) ..._buildZoneEntries(org),
              if (org != null && !org.isArchived) _buildAdminSection(org),
              if (org != null)
                _HubTile(
                  tileKey: const ValueKey('organization-detail-info'),
                  icon: CupertinoIcons.info_circle,
                  title: t.organization.experienceUi.enterpriseInfo,
                  subtitle: orgRoleLabel(org.memberRole),
                  onTap: () => _showDetails(org),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 成员可读的资源入口；治理操作在独立管理区。
  List<Widget> _buildZoneEntries(Organization org) {
    final detailBase = '$kOrganizationHomePath/${org.id}';
    return [
      _sectionHeader(t.organization.hub.sectionResources),
      _HubSection(
        children: [
          _HubTile(
            tileKey: const ValueKey('organization-detail-zone-members'),
            icon: CupertinoIcons.person_2,
            title: t.organization.directory.title,
            subtitle: t.organization.hub.zoneMembersDesc,
            onTap: () => context.push(
              '$detailBase/directory?name=${Uri.encodeQueryComponent(org.name)}',
            ),
          ),
          _HubTile(
            tileKey: const ValueKey('organization-detail-zone-groups'),
            icon: CupertinoIcons.person_3,
            title: t.organization.hub.zoneGroups,
            subtitle: t.organization.experienceUi.collaborationSpace,
            onTap: () => _openResources(org, channels: false),
          ),
          _HubTile(
            tileKey: const ValueKey('organization-detail-zone-channels'),
            icon: CupertinoIcons.dot_radiowaves_left_right,
            title: t.organization.hub.zoneChannels,
            subtitle: t.organization.experienceUi.collaborationSpace,
            onTap: () => _openResources(org, channels: true),
          ),
          // 只列当前企业已授权的工作区项目，深链既有页面。
          _HubTile(
            tileKey: const ValueKey('organization-detail-zone-org-tools'),
            icon: CupertinoIcons.square_grid_2x2_fill,
            title: t.organization.experienceUi.collaborationSpace,
            subtitle: t.organization.hub.zoneOrgToolsDesc,
            onTap: () => context.push('$detailBase/tools'),
          ),
        ],
      ),
    ];
  }

  void _openResources(Organization org, {required bool channels}) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => OrganizationResourcesPage(
          organizationId: org.id,
          channels: channels,
        ),
      ),
    );
  }

  /// 管理员区（owner/admin 才见）：治理类入口经 [PermissionGate] hide
  /// 隐藏；member 直达路由仍可达（页面内给权限态，服务端 403 才是裁决）。
  Widget _buildAdminSection(Organization org) {
    final detailBase = '$kOrganizationHomePath/${org.id}';
    return PermissionGate(
      check: () => org.canGovern,
      behavior: PermissionGateBehavior.hide,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sectionHeader(t.organization.hub.sectionAdmin),
          _HubSection(
            children: [
              _HubTile(
                tileKey: const ValueKey('organization-detail-zone-departments'),
                icon: CupertinoIcons.tree,
                title: t.organization.departments.title,
                subtitle: t.organization.hub.zoneDepartmentsDesc,
                onTap: () => context.push('$detailBase/departments'),
              ),
              _HubTile(
                tileKey: const ValueKey('organization-detail-admin-members'),
                icon: CupertinoIcons.person_crop_circle_badge_checkmark,
                title: t.organization.hub.adminMembers,
                subtitle: t.organization.hub.adminMembersDesc,
                onTap: () => context.push('$detailBase/members'),
              ),
              _HubTile(
                tileKey: const ValueKey(
                  'organization-detail-admin-invitations',
                ),
                icon: CupertinoIcons.mail,
                title: t.organization.hub.adminInvitations,
                subtitle: t.organization.hub.adminInvitationsDesc,
                onTap: () => context.push('$detailBase/invitations'),
              ),
              _HubTile(
                // 保留 GZAPP-05 既有测试锚点 key。
                tileKey: const ValueKey('organization-detail-manage-entry'),
                icon: CupertinoIcons.slider_horizontal_3,
                title: t.organization.hub.adminManage,
                subtitle: t.organization.hub.adminManageDesc,
                onTap: () => context.push('$detailBase/manage'),
              ),
              // CS-APP-03（CS-GOV-02B）：企业自助客服治理入口（席位额度/
              // 坐席启停，租户 Human JWT API）。member 经 PermissionGate 整区
              // 隐藏；直达路由由治理页内 403 终态兜底（服务端唯一裁决）。
              _HubTile(
                tileKey: const ValueKey(
                  'organization-detail-zone-cs-governance',
                ),
                icon: CupertinoIcons.chat_bubble_2,
                title: t.organization.hub.adminCsGovernance,
                subtitle: t.organization.hub.adminCsGovernanceDesc,
                onTap: () => context.push(csGovernancePath(org.id)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.regular,
      AppSpacing.small,
      AppSpacing.regular,
      AppSpacing.tiny,
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w600),
    ),
  );

  List<Widget> _buildDangerZone(Organization org) => [
    CupertinoListTile(
      key: const ValueKey('organization-detail-leave'),
      leading: Icon(
        CupertinoIcons.square_arrow_right,
        color: AppColors.getIosRed(Theme.of(context).brightness),
      ),
      title: Text(
        t.organization.detail.leaveOrg,
        style: TextStyle(
          color: AppColors.getIosRed(Theme.of(context).brightness),
        ),
      ),
      subtitle: Text(
        org.memberRole == 'owner'
            ? t.organization.detail.leaveOwnerHint
            : t.organization.detail.leaveOrgBody,
      ),
      onTap: _leaving || org.memberRole == 'owner' ? null : _leave,
    ),
    if (!org.isArchived && org.canGovern)
      ListTile(
        leading: Icon(
          CupertinoIcons.archivebox,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(
          t.organization.detail.archiveOrg,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        subtitle: Text(t.organization.detail.archiveEntrySubtitle),
        onTap: _archive,
      ),
    if (org.isArchived && org.canGovern)
      ListTile(
        leading: const Icon(CupertinoIcons.tray),
        title: Text(t.organization.detail.restoreOrg),
        subtitle: Text(t.organization.detail.restoreEntrySubtitle),
        onTap: _restore,
      ),
  ];
}

class _HubSection extends StatelessWidget {
  const _HubSection({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(
      horizontal: AppSpacing.regular,
      vertical: AppSpacing.small,
    ),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppSpacing.medium),
    ),
    child: Column(children: children),
  );
}

/// 聚合入口行（ENT-APP-01）：图标 + 标题 + 一句话说明 + chevron。
class _HubTile extends StatelessWidget {
  const _HubTile({
    this.tileKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Key? tileKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ResourceEntryTile(
      key: tileKey,
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}

/// 企业头信息卡（ENT-APP-01）：组织名 + 我的角色/状态 + archived 提示 +
/// 默认 Workspace 指针。事实内容与旧版 ListTile 完全一致，只改容器形态。
class _OrgHeaderCard extends StatelessWidget {
  const _OrgHeaderCard({required this.org});

  final Organization org;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = org.memberRole.isEmpty ? 'member' : org.memberRole;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.all(AppSpacing.regular),
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    CupertinoIcons.building_2_fill,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                AppSpacing.horizontalSmall,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        org.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      AppSpacing.verticalTiny,
                      Text(
                        t.organization.detail.myRoleAndStatus(
                          role: orgRoleLabel(role),
                          status: orgStatusLabel(org.status),
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (org.isArchived) ...[
              AppSpacing.verticalSmall,
              Row(
                children: [
                  Icon(
                    CupertinoIcons.lock,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  AppSpacing.horizontalTiny,
                  Expanded(
                    child: Text(
                      '${t.organization.detail.archivedBadge}：'
                      '${t.organization.detail.archivedHint}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
