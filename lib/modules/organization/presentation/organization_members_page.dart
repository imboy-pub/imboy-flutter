/// 成员治理页（服务端 owner/admin 门）：
/// 列表 · 详情 · 角色变更 · 移除 · Owner 转移（危险，二次确认）
/// · 生命周期命令 suspend/restore/offboard（EB-D07/EB-08）。
///
/// 普通成员访问列表 = 服务端 403 → 权限态展示（客户端不预判）；
/// Owner 行不可被任何治理动作触达（C04 单 owner 不变量 + 主 Owner 成员行
/// DB 守卫）：改角色/移除/暂停/离场入口全部隐藏（isGovernable 统一减法，
/// 服务端 409/403 仍是唯一裁决），转移走显式 owner-transfer command。
///
/// 生命周期语义（organization_member_logic）：
/// - suspend：active → suspended（可恢复撤权第一步，不动工作区成员关系
///   与个人账号）；suspended 成员立即失去本 Org 的 mine/directory/workspace
///   授权（服务端逐请求读事实），治理列表也不再返回该行；
/// - restore：suspended → active（仅 suspended 来源；其余 409 不静默成功）；
/// - offboard：active|suspended → removed 终态（被依赖资源引用时 409），
///   唯一恢复路径 = 重新邀请。
library;

import 'package:imboy/component/ui/resource_page_layout.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';

import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/infrastructure/organization_cache.dart';
import 'package:imboy/modules/organization/presentation/organization_routes.dart';
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

  /// 命令防重复门：一次治理命令在途时忽略后续触发（网络慢/双击不产生
  /// 第二个请求，也不因连点出现「失败后又成功」的假成功序列）。
  bool _commandInFlight = false;

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
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(t.organization.members.loadMoreFailed(err: e))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingMore = false;
        });
      }
    }
  }

  /// 治理命令统一收口：在途门 → 执行 → 失败 SnackBar 透出服务端文案
  /// （不吞错不假成功）→ 回到服务端事实（成功失败都刷新列表）。
  Future<void> _runCommand(
    Future<void> Function() action,
    String failureTitle,
  ) async {
    if (_commandInFlight) return;
    _commandInFlight = true;
    try {
      await action();
    } on OrganizationApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('$failureTitle：${e.message} (${e.code})')),
      );
    } on Object catch (e) {
      // 网络/序列化等非 envelope 异常同样不假成功。
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text('$failureTitle：$e')));
    } finally {
      _commandInFlight = false;
    }
    await _refresh();
  }

  Future<void> _changeRole(OrganizationMember m) async {
    final target = m.isAdmin ? 'member' : 'admin';
    final ok = await orgConfirmDangerAction(
      context,
      title: t.organization.members.changeRole,
      consequence: t.organization.members.changeRoleBody(
        name: m.displayName,
        from: orgRoleLabel(m.role),
        to: orgRoleLabel(target),
      ),
      confirmText: t.organization.members.confirmChange,
    );
    if (ok) {
      await _runCommand(
        () => _api.changeRole(widget.orgId, m.userId, role: target),
        t.organization.members.changeRoleFailed,
      );
    }
  }

  Future<void> _remove(OrganizationMember m) async {
    final ok = await orgConfirmDangerAction(
      context,
      title: t.organization.members.removeMember,
      consequence: t.organization.members.removeMemberBody(name: m.displayName),
      confirmText: t.organization.members.confirmRemove,
    );
    if (ok) {
      await _runCommand(
        () => _api.removeMember(widget.orgId, m.userId),
        t.organization.members.removeFailed,
      );
    }
  }

  Future<void> _transferOwner(OrganizationMember m) async {
    final ok = await orgConfirmDangerAction(
      context,
      title: t.organization.members.transferOwner,
      consequence: t.organization.members.transferOwnerBody(
        name: m.displayName,
      ),
      confirmText: t.organization.members.confirmTransfer,
    );
    if (ok) {
      await _runCommand(
        () => _api.transferOwner(widget.orgId, m.userId),
        t.organization.members.transferFailed,
      );
    }
  }

  /// 暂停（EB-D07 可恢复撤权第一步）：确认文案写明即时撤权 + 可恢复。
  Future<void> _suspend(OrganizationMember m) async {
    final ok = await orgConfirmDangerAction(
      context,
      title: t.organization.members.suspendMember,
      consequence: t.organization.members.suspendBody(name: m.displayName),
      confirmText: t.organization.members.confirmSuspend,
    );
    if (ok) {
      await _runCommand(
        () => _api.suspendMember(widget.orgId, m.userId),
        t.organization.members.suspendFailed,
      );
    }
  }

  /// 恢复（suspended → active；仅 suspended 来源，其余服务端 409）。
  Future<void> _restore(OrganizationMember m) async {
    final ok = await orgConfirmAction(
      context,
      title: t.organization.members.restoreMember,
      consequence: t.organization.members.restoreBody(name: m.displayName),
      confirmText: t.organization.members.confirmRestoreMember,
    );
    if (ok) {
      await _runCommand(
        () => _api.restoreMember(widget.orgId, m.userId),
        t.organization.members.restoreFailed,
      );
    }
  }

  /// 离场（两步离场 S3：active|suspended → removed 终态，不可恢复）。
  Future<void> _offboard(OrganizationMember m) async {
    final ok = await orgConfirmDangerAction(
      context,
      title: t.organization.members.offboardMember,
      consequence: t.organization.members.offboardBody(name: m.displayName),
      confirmText: t.organization.members.confirmOffboard,
    );
    if (ok) {
      await _runCommand(
        () => _api.offboardMember(widget.orgId, m.userId),
        t.organization.members.offboardFailed,
      );
    }
  }

  Future<void> _openMemberDetail(OrganizationMember m) {
    return context.push(
      '$kOrganizationHomePath/${widget.orgId}/member/${m.userId}',
      extra: <String, dynamic>{'member': m},
    );
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
            ListTile(
              key: ValueKey('org-member-action-detail-${m.userId}'),
              leading: const Icon(CupertinoIcons.person_crop_circle),
              title: Text(t.organization.members.viewDetail),
              onTap: () => Navigator.of(ctx).pop('detail'),
            ),
            if (m.isGovernable && m.isActive)
              ListTile(
                leading: const Icon(CupertinoIcons.arrow_swap),
                title: Text(
                  m.isAdmin
                      ? t.organization.members.demoteToMember
                      : t.organization.members.promoteToAdmin,
                ),
                onTap: () => Navigator.of(ctx).pop('role'),
              ),
            if (m.isGovernable && iAmOwner)
              ListTile(
                leading: const Icon(CupertinoIcons.shield_fill),
                title: Text(
                  t.organization.members.transferOwnerTo(name: m.displayName),
                ),
                onTap: () => Navigator.of(ctx).pop('transfer'),
              ),
            // 生命周期命令只对非 owner 成员开放：主 Owner 成员行受 DB
            // 守卫（suspend 409），客户端入口统一 isGovernable 减法。
            if (m.isGovernable && m.isActive)
              ListTile(
                key: ValueKey('org-member-action-suspend-${m.userId}'),
                leading: const Icon(CupertinoIcons.pause_circle),
                title: Text(t.organization.members.suspendMember),
                onTap: () => Navigator.of(ctx).pop('suspend'),
              ),
            if (m.isGovernable && m.isSuspended)
              ListTile(
                key: ValueKey('org-member-action-restore-${m.userId}'),
                leading: const Icon(CupertinoIcons.play_circle),
                title: Text(t.organization.members.restoreMember),
                onTap: () => Navigator.of(ctx).pop('restore'),
              ),
            if (m.isGovernable)
              ListTile(
                leading: Icon(
                  Icons.person_remove_outlined,
                  color: Theme.of(ctx).colorScheme.error,
                ),
                title: Text(
                  t.organization.members.removeMember,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
                onTap: () => Navigator.of(ctx).pop('remove'),
              ),
            if (m.isGovernable)
              ListTile(
                key: ValueKey('org-member-action-offboard-${m.userId}'),
                leading: Icon(
                  CupertinoIcons.person_crop_circle_badge_xmark,
                  color: Theme.of(ctx).colorScheme.error,
                ),
                title: Text(
                  t.organization.members.offboardMember,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
                onTap: () => Navigator.of(ctx).pop('offboard'),
              ),
            if (!m.isGovernable)
              ListTile(
                leading: Icon(CupertinoIcons.info),
                title: Text(t.organization.members.ownerCannotChangeHere),
              ),
          ],
        ),
      ),
    );
    switch (await action) {
      case 'detail':
        await _openMemberDetail(m);
      case 'role':
        await _changeRole(m);
      case 'transfer':
        await _transferOwner(m);
      case 'remove':
        await _remove(m);
      case 'suspend':
        await _suspend(m);
      case 'restore':
        await _restore(m);
      case 'offboard':
        await _offboard(m);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t.organization.members.title)),
      body: ResourcePageLayout(
        child: RefreshIndicator(
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
            emptyText: t.organization.common.noMembers,
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
                    child: Text(
                      _loadingMore
                          ? t.organization.common.loading
                          : t.organization.common.loadMore,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
