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
import 'package:go_router/go_router.dart';

import 'package:imboy/modules/organization/domain/organization_models.dart';
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
  }

  Future<void> _createOrg() async {
    final name = await orgPromptInput(
      context,
      title: '创建组织',
      hint: '组织名称（1-200 字符）',
    );
    if (name == null) return;
    try {
      final org = await _api.create(name: name);
      _cache.invalidateOrg(org.id);
      await _refresh();
    } on OrganizationApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('创建失败：${e.message} (${e.code})')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('组织'),
        actions: [
          Semantics(
            button: true,
            label: '我的邀请',
            child: IconButton(
              icon: const Icon(CupertinoIcons.mail),
              tooltip: '我的邀请',
              onPressed: () => context.push(
                '$kOrganizationHomePath/0/invitations?mode=mine',
              ),
            ),
          ),
          Semantics(
            button: true,
            label: '创建组织',
            child: IconButton(
              icon: const Icon(CupertinoIcons.add),
              tooltip: '创建组织',
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
          emptyText: '尚未加入任何组织\n下拉刷新或点击右上角创建',
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
                  subtitle: Text(
                    '${orgRoleLabel(o.memberRole.isEmpty ? 'member' : o.memberRole)}'
                    '${o.isArchived ? ' · ${orgStatusLabel(o.status)}' : ''}',
                  ),
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
