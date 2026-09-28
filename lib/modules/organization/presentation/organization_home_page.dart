/// 组织入口页：我所在组织（切换）+ 创建 + 我的邀请入口。
///
/// 展示即事实（ORG-A13）：
/// - 「我所在组织」来自服务端 mine 分页；suspended/removed 成员天然
///   不在结果中（服务端 WHERE status='active'），App 不做本地补偿展示；
/// - archived 组织原样列出并打标；点进详情后按角色放行治理入口；
/// - 本地缓存只作转场即时渲染（account+org 双 scope），真源始终是
///   服务端（每次进入都刷新）。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/infrastructure/organization_cache.dart';
import 'package:imboy/modules/organization/presentation/organization_routes.dart';
import 'package:imboy/modules/organization/presentation/organization_ui.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class OrganizationHomePage extends StatefulWidget {
  const OrganizationHomePage({super.key, this.accountKey});

  /// 缓存账号键；测试可注入。缺省取当前登录账号。
  final String? accountKey;

  @override
  State<OrganizationHomePage> createState() => _OrganizationHomePageState();
}

class _OrganizationHomePageState extends State<OrganizationHomePage> {
  final OrganizationApi _api = OrganizationApi();

  List<Organization> _orgs = const [];
  bool _loading = false;
  String? _error;

  /// 待处理邀请数（P1 触达角标；服务端 target 视角 pending 列表长度）。
  int _pendingInvites = 0;

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
    });
    try {
      final page = await _api.mine();
      // 服务端事实到达后覆盖缓存（缓存永不先于真源）。
      _cache.saveOrgs(page.list);
      if (!mounted) return;
      setState(() {
        _orgs = page.list;
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
    // 触达角标（P1）：失败静默归零——角标是增强信息，不与组织列表竞争报错。
    await _refreshPendingInvites();
  }

  Future<void> _createOrg() async {
    final name = await orgPromptInput(
      context,
      title: t.organization.home.createOrg,
      hint: t.organization.home.orgNameLabel,
    );
    if (name == null) return;
    try {
      final org = await _api.create(name: name);
      _cache.invalidateOrg(org.id);
      await _refresh();
      // 创建可能落 pending（待运营审核）：成功 ≠ 立即可用，如实告知。
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(t.organization.home.createSubmittedPendingReview),
        ),
      );
    } on OrganizationApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            t.organization.home.createFailedWith(msg: e.message, code: e.code),
          ),
        ),
      );
    }
  }

  /// 通讯录入口（GZAPP-04 G10）：目标企业 = 当前企业指针，回落列表首个
  /// active 组织；无可进企业时禁用。
  void _openDirectory() {
    Organization? target;
    try {
      target = CurrentOrganizationStore.forAccount(_accountKey).value;
    } on Object {
      target = null;
    }
    target =
        _orgsWhere(target?.id ?? '') ??
        _orgs.where((o) => !o.isArchived).firstOrNull ??
        _orgs.firstOrNull;
    if (target == null) return;
    context.push(
      '$kOrganizationHomePath/${target.id}/directory?name=${Uri.encodeComponent(target.name)}',
    );
  }

  Organization? _orgsWhere(EntityId orgId) {
    if (orgId.isEmpty) return null;
    for (final o in _orgs) {
      if (o.id == orgId) return o;
    }
    return null;
  }

  /// 只重算触达角标（不闪组织列表 loading）。
  Future<void> _refreshPendingInvites() async {
    try {
      final invites = await _api.myInvitations(status: 'pending');
      if (!mounted) return;
      setState(() {
        _pendingInvites = invites.length;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _pendingInvites = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.organization.home.tabOrg),
        actions: [
          Semantics(
            button: true,
            label: t.organization.directory.title,
            child: IconButton(
              key: const ValueKey('organization-home-directory-entry'),
              icon: const Icon(CupertinoIcons.person_3),
              tooltip: t.organization.directory.title,
              onPressed: _openDirectory,
            ),
          ),
          Semantics(
            button: true,
            label: t.organization.home.myInvitations,
            child: IconButton(
              tooltip: t.organization.home.myInvitations,
              onPressed: () async {
                await context.push(
                  '$kOrganizationHomePath/0/invitations?mode=mine',
                );
                // 从邀请页返回后重算角标（可能有接受/拒绝终态变化）
                if (mounted) {
                  await _refreshPendingInvites();
                }
              },
              icon: Badge(
                isLabelVisible: _pendingInvites > 0,
                label: Text(_pendingInvites > 99 ? '99+' : '$_pendingInvites'),
                child: const Icon(CupertinoIcons.mail),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: t.organization.home.createOrg,
            child: IconButton(
              icon: const Icon(CupertinoIcons.add),
              tooltip: t.organization.home.createOrg,
              onPressed: _createOrg,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: OrgStateView(
          loading: _loading && _orgs.isEmpty,
          error: _error,
          empty: !_loading && _error == null && _orgs.isEmpty,
          emptyText: t.organization.home.emptyHint,
          onRetry: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
            children: [
              for (final o in _orgs)
                ListTile(
                  leading: Icon(
                    CupertinoIcons.building_2_fill,
                    color: o.isArchived
                        ? Theme.of(context).disabledColor
                        : null,
                  ),
                  title: Text(
                    o.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: orgListSubtitle(context, o),
                  trailing: const Icon(CupertinoIcons.chevron_right),
                  onTap: () => context.push('$kOrganizationHomePath/${o.id}'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
