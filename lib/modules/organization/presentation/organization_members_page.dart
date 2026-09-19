/// 成员治理页（服务端 owner/admin 门）：
/// 列表 · 角色变更 · 移除 · Owner 转移（危险，二次确认）。
///
/// 普通成员访问列表 = 服务端 403 → 权限态展示（客户端不预判）；
/// Owner 行不可改角色/移除（C04 单 owner 不变量），转移走显式 command。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/infrastructure/organization_cache.dart';
import 'package:imboy/modules/organization/presentation/organization_ui.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class OrganizationMembersPage extends StatefulWidget {
  const OrganizationMembersPage({
    super.key,
    required this.orgId,
    this.accountKey,
  });

  final EntityId orgId;
  final String? accountKey;

  @override
  State<OrganizationMembersPage> createState() =>
      _OrganizationMembersPageState();
}

class _OrganizationMembersPageState extends State<OrganizationMembersPage> {
  final OrganizationApi _api = OrganizationApi();

  final List<OrganizationMember> _members = <OrganizationMember>[];
  int _page = 1;
  int _totalPage = 1;
  bool _loading = false;
  bool _loadingMore = false;
  bool _permissionDenied = false;
  String? _error;

  String get _accountKey => widget.accountKey ?? UserRepoLocal.to.currentUid;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  OrganizationMember? get _me {
    final uid = _accountKey;
    for (final m in _members) {
      if (m.userId == uid) return m;
    }
    return null;
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _permissionDenied = false;
    });
    try {
      final page = await _api.members(widget.orgId);
      // 服务端事实到达后覆盖缓存（缓存不是真源）。
      OrganizationCache.forAccount(_accountKey)
          .saveMembers(widget.orgId, page.list);
      if (!mounted) return;
      setState(() {
        _members
          ..clear()
          ..addAll(page.list);
        _page = page.page <= 0 ? 1 : page.page;
        _totalPage = page.totalPage;
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

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _totalPage) return;
    setState(() {
      _loadingMore = true;
    });
    try {
      final page = await _api.members(widget.orgId, page: _page + 1);
      if (!mounted) return;
      setState(() {
        _members.addAll(page.list);
        _page = page.page <= 0 ? _page : page.page;
        _totalPage = page.totalPage;
      });
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text('加载更多失败：$e')));
    } finally {
      if (mounted) {
        setState(() {
          _loadingMore = false;
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
    await _refresh();
  }

  Future<void> _changeRole(OrganizationMember m) async {
    final target = m.isAdmin ? 'member' : 'admin';
    final ok = await orgConfirmDangerAction(
      context,
      title: '变更角色',
      consequence:
          '将「${m.displayName}」的角色由 ${orgRoleLabel(m.role)} 调整为 ${orgRoleLabel(target)}。',
      confirmText: '确认变更',
    );
    if (ok) {
      await _runCommand(
        () => _api.changeRole(widget.orgId, m.userId, role: target),
        '角色变更失败',
      );
    }
  }

  Future<void> _remove(OrganizationMember m) async {
    final ok = await orgConfirmDangerAction(
      context,
      title: '移除成员',
      consequence: '将「${m.displayName}」移出本组织。该操作不会删除其账号。',
      confirmText: '确认移除',
    );
    if (ok) {
      await _runCommand(
        () => _api.removeMember(widget.orgId, m.userId),
        '移除失败',
      );
    }
  }

  Future<void> _transferOwner(OrganizationMember m) async {
    final ok = await orgConfirmDangerAction(
      context,
      title: '转移所有者',
      consequence:
          '组织有且仅有一个 owner（C04）：确认将「${m.displayName}」设为所有者，'
          '你将降级为普通管理员/成员。该操作直接影响组织控制权。',
      confirmText: '确认转移',
    );
    if (ok) {
      await _runCommand(
        () => _api.transferOwner(widget.orgId, m.userId),
        '转移失败',
      );
    }
  }

  Future<void> _openMemberActions(OrganizationMember m) async {
    final me = _me;
    final iAmOwner = me?.isOwner == true;
    final action = showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.isGovernable)
              ListTile(
                leading: const Icon(CupertinoIcons.arrow_swap),
                title: Text(m.isAdmin ? '降级为成员' : '升级为管理员'),
                onTap: () => Navigator.of(ctx).pop('role'),
              ),
            if (m.isGovernable && iAmOwner)
              ListTile(
                leading: const Icon(CupertinoIcons.shield_fill),
                title: Text('转移所有者给「${m.displayName}」'),
                onTap: () => Navigator.of(ctx).pop('transfer'),
              ),
            if (m.isGovernable)
              ListTile(
                leading: Icon(
                  Icons.person_remove_outlined,
                  color: Theme.of(ctx).colorScheme.error,
                ),
                title: Text(
                  '移除成员',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
                onTap: () => Navigator.of(ctx).pop('remove'),
              ),
            if (!m.isGovernable)
              const ListTile(
                leading: Icon(CupertinoIcons.info),
                title: Text('Owner 不可在此变更；请使用「转移所有者」'),
              ),
          ],
        ),
      ),
    );
    switch (await action) {
      case 'role':
        await _changeRole(m);
      case 'transfer':
        await _transferOwner(m);
      case 'remove':
        await _remove(m);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('成员')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: OrgStateView(
          loading: _loading && _members.isEmpty,
          error: _error,
          permissionDenied: _permissionDenied,
          empty:
              !_loading &&
              !_permissionDenied &&
              _error == null &&
              _members.isEmpty,
          emptyText: '暂无成员',
          onRetry: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
            children: [
              for (final m in _members)
                ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      m.isOwner
                          ? CupertinoIcons.star_fill
                          : CupertinoIcons.person_fill,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    m.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    memberSubtitle(m),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(CupertinoIcons.ellipsis),
                  onTap: () => _openMemberActions(m),
                ),
              if (_page < _totalPage)
                TextButton(
                  onPressed: _loadingMore ? null : _loadMore,
                  child: Text(_loadingMore ? '加载中…' : '加载更多'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
