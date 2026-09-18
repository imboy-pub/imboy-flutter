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
      title: '归档组织',
      consequence:
          '归档后组织进入只读态，全部写操作 fail-closed，仅恢复（restore）可解锁。'
          '成员与数据不会被删除。',
      confirmText: '确认归档',
    );
    if (ok) {
      await _runCommand(() => _api.archive(widget.orgId), '归档失败');
    }
  }

  Future<void> _restore() async {
    final ok = await orgConfirmDangerAction(
      context,
      title: '恢复组织',
      consequence: '恢复后组织回到 active 态，写入口重新开放。',
      confirmText: '确认恢复',
    );
    if (ok) {
      await _runCommand(() => _api.restore(widget.orgId), '恢复失败');
    }
  }

  Future<void> _rename() async {
    final name = await orgPromptInput(
      context,
      title: '修改组织名称',
      hint: '组织名称（1-200 字符）',
      initial: _org?.name ?? '',
    );
    if (name == null) return;
    await _runCommand(() => _api.update(widget.orgId, name: name), '改名失败');
  }

  Future<void> _showPreflight() async {
    try {
      final report = await _api.deletionPreflight();
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('账号删除预检'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text('观察时刻：${flexTsLabel(report.observedAt)}'),
                const SizedBox(height: AppSpacing.small),
                Text('覆盖依赖域：${report.factDomains.join('、')}'),
                const SizedBox(height: AppSpacing.small),
                if (report.blockers.isEmpty)
                  const Text('无阻塞项')
                else ...[
                  const Text('阻塞项：'),
                  for (final b in report.blockers)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.block),
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
              child: const Text('关闭'),
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
                ? '依赖域事实不可用，删除预检被拒绝（fail-closed）'
                : '预检失败：${e.message} (${e.code})',
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
          org?.name ?? '组织详情',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (org != null && org.canGovern && !org.isArchived)
            Semantics(
              button: true,
              label: '修改组织名称',
              child: IconButton(
                icon: const Icon(Icons.edit),
                tooltip: '修改名称',
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
          emptyText: '组织不存在',
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
        '我的角色：${orgRoleLabel(org.memberRole.isEmpty ? 'member' : org.memberRole)}'
        ' · 状态：${orgStatusLabel(org.status)}',
      ),
    ),
    if (org.isArchived)
      const ListTile(
        leading: Icon(Icons.lock_outline),
        title: Text('组织已归档（只读）'),
        subtitle: Text('归档期间全部写操作被拒绝，仅恢复操作可用'),
      ),
    ListTile(
      leading: const Icon(CupertinoIcons.square_stack_3d_up),
      title: Text(
        _defaultWs?.isSet == true
            ? '默认 Workspace：${_defaultWs!.defaultWorkspaceId}'
            : '默认 Workspace：未设置',
      ),
      subtitle: const Text('指向事实，不代表任何 workspace 成员身份'),
    ),
  ];

  List<Widget> _buildEntries(Organization org) {
    final canGovern = org.canGovern;
    return [
      const Divider(),
      ListTile(
        leading: const Icon(CupertinoIcons.person_2),
        title: Text('成员列表${canGovern ? '' : '（仅 owner/admin 可查看）'}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('$kOrganizationHomePath/${org.id}/members'),
      ),
      ListTile(
        leading: const Icon(CupertinoIcons.mail),
        title: Text('邀请管理${canGovern ? '' : '（仅 owner/admin 可管理）'}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            context.push('$kOrganizationHomePath/${org.id}/invitations'),
      ),
      ListTile(
        leading: const Icon(CupertinoIcons.tree),
        title: Text('部门目录${canGovern ? '' : '（管理操作仅限授权者）'}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            context.push('$kOrganizationHomePath/${org.id}/departments'),
      ),
    ];
  }

  List<Widget> _buildDangerZone(Organization org) => [
    const Divider(),
    const ListTile(
      title: Text('更多', style: TextStyle(fontWeight: FontWeight.w600)),
    ),
    ListTile(
      leading: const Icon(Icons.fact_check_outlined),
      title: const Text('账号删除预检'),
      subtitle: const Text('查看本账号被哪些依赖域阻塞删除'),
      onTap: _showPreflight,
    ),
    if (!org.isArchived && org.canGovern)
      ListTile(
        leading: Icon(
          Icons.archive_outlined,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(
          '归档组织',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        subtitle: const Text('进入只读态；可随时恢复'),
        onTap: _archive,
      ),
    if (org.isArchived && org.canGovern)
      ListTile(
        leading: const Icon(Icons.unarchive_outlined),
        title: const Text('恢复组织'),
        subtitle: const Text('回到 active 态'),
        onTap: _restore,
      ),
  ];
}
