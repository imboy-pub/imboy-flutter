/// 组织详情页：事实展示 + 治理入口 + 危险操作（二次确认 + 刷新服务端事实）。
///
/// - archived（C16）：整页只读提示；restore 是唯一放行写入口，仍需
///   owner/admin（服务端裁决，客户端只隐藏入口）；
/// - 默认 Workspace（C05）：只展示指向事实；为空 = 未设置，**不等于**
///   无 workspace membership（两者独立）；
/// - 删除预检（C17）：只读展示本人删除被依赖域 block 的情况；503 =
///   事实不可用即拒，App 原样提示不做降级。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/infrastructure/organization_cache.dart';
import 'package:imboy/modules/organization/presentation/organization_routes.dart';
import 'package:imboy/modules/organization/presentation/organization_ui.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_spacing.dart';

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
  bool _permissionDenied = false;
  String? _error;

  String get _accountKey => widget.accountKey ?? UserRepoLocal.to.currentUid;

  OrganizationCache get _cache => OrganizationCache.forAccount(_accountKey);

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
      final org = await _api.detail(widget.orgId);
      // 默认 workspace 读取失败不阻断详情（指针事实缺失 ≠ 详情失败）。
      DefaultWorkspaceRef? ws;
      try {
        ws = await _api.defaultWorkspace(widget.orgId);
      } on OrganizationApiException {
        ws = null;
      }
      _cache.saveOrgs([org]);
      if (!mounted) return;
      setState(() {
        _org = org;
        _defaultWs = ws;
      });
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

  Future<void> _showPreflight() async {
    try {
      final report = await _api.deletionPreflight();
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t.organization.detail.deletionPreflight),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  t.organization.detail.observedAt(
                    ts: flexTsLabel(report.observedAt),
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
                Text(
                  t.organization.detail.factDomains(
                    domains: report.factDomains.join('、'),
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
                if (report.blockers.isEmpty)
                  Text(t.organization.detail.noBlockers)
                else ...[
                  Text(t.organization.detail.blockers),
                  for (final b in report.blockers)
                    ListTile(
                      dense: true,
                      leading: const Icon(CupertinoIcons.nosign),
                      title: Text(
                        b.code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        b.resourceType,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(t.organization.common.close),
            ),
          ],
        ),
      );
    } on OrganizationApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            e.isFactsUnavailable
                ? t.organization.detail.factUnavailable
                : t.organization.detail.preflightFailed(
                    msg: e.message,
                    code: e.code,
                  ),
          ),
        ),
      );
    }
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
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: OrgStateView(
          loading: _loading && _org == null,
          error: _error,
          permissionDenied: _permissionDenied,
          empty:
              !_loading && _error == null && !_permissionDenied && _org == null,
          emptyText: t.organization.detail.notFound,
          onRetry: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
            children: [
              if (org != null) ..._buildFacts(org),
              if (org != null && !org.isArchived) ..._buildEntries(org),
              if (org != null) ..._buildDangerZone(org),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFacts(Organization org) => [
    ListTile(
      leading: Icon(
        CupertinoIcons.building_2_fill,
        color: org.isArchived ? Theme.of(context).disabledColor : null,
      ),
      title: Text(org.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        t.organization.detail.myRoleAndStatus(
          role: orgRoleLabel(
            org.memberRole.isEmpty ? 'member' : org.memberRole,
          ),
          status: orgStatusLabel(org.status),
        ),
      ),
    ),
    if (org.isArchived)
      ListTile(
        leading: Icon(CupertinoIcons.lock),
        title: Text(t.organization.detail.archivedBadge),
        subtitle: Text(t.organization.detail.archivedHint),
      ),
    ListTile(
      leading: const Icon(CupertinoIcons.square_stack_3d_up),
      title: Text(
        _defaultWs?.isSet == true
            ? t.organization.detail.defaultWsSet(
                id: _defaultWs!.defaultWorkspaceId,
              )
            : t.organization.detail.defaultWsUnset,
      ),
      subtitle: Text(t.organization.detail.defaultWsNote),
    ),
  ];

  List<Widget> _buildEntries(Organization org) {
    final canGovern = org.canGovern;
    return [
      const Divider(),
      ListTile(
        leading: const Icon(CupertinoIcons.person_2),
        title: Text(
          canGovern
              ? t.organization.detail.memberList
              : t.organization.detail.memberListRestricted,
        ),
        trailing: const Icon(CupertinoIcons.chevron_right),
        onTap: () => context.push('$kOrganizationHomePath/${org.id}/members'),
      ),
      ListTile(
        leading: const Icon(CupertinoIcons.mail),
        title: Text(
          canGovern
              ? t.organization.detail.invitationManage
              : t.organization.detail.invitationManageRestricted,
        ),
        trailing: const Icon(CupertinoIcons.chevron_right),
        onTap: () =>
            context.push('$kOrganizationHomePath/${org.id}/invitations'),
      ),
      ListTile(
        leading: const Icon(CupertinoIcons.tree),
        title: Text(
          canGovern
              ? t.organization.detail.deptEntry
              : t.organization.detail.deptEntryRestricted,
        ),
        trailing: const Icon(CupertinoIcons.chevron_right),
        onTap: () =>
            context.push('$kOrganizationHomePath/${org.id}/departments'),
      ),
      // GZAPP-05：企业管理（工作区/群/频道治理）。入口按角色隐藏，
      // 直达路由仍可达——页面自己给只读 + 无权限态（服务端 403 才是裁决）。
      ListTile(
        key: const ValueKey('organization-detail-manage-entry'),
        leading: const Icon(CupertinoIcons.slider_horizontal_3),
        title: Text(
          canGovern
              ? t.organization.manage.entry
              : t.organization.manage.entryRestricted,
        ),
        trailing: const Icon(CupertinoIcons.chevron_right),
        onTap: () => context.push('$kOrganizationHomePath/${org.id}/manage'),
      ),
    ];
  }

  List<Widget> _buildDangerZone(Organization org) => [
    const Divider(),
    ListTile(
      title: Text(
        t.organization.detail.more,
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    ListTile(
      leading: const Icon(Icons.fact_check_outlined),
      title: Text(t.organization.detail.deletionPreflight),
      subtitle: Text(t.organization.detail.deletionPreflightDesc),
      onTap: _showPreflight,
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
