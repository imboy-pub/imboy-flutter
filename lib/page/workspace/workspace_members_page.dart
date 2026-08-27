/// T9 (WP5) — Workspace Members 视图（工作区成员管理，§4.2 IA）
///
/// 术语约束：本页是「工作区成员」（Workspace Member）管理页，与群成员
/// （Group Member）/频道订阅者（Channel Subscriber）是三种独立关系
/// （I14：加入工作区不自动入群/订阅）。
///
/// 治理动作（仅 Owner；archived 时禁用，服务端 980 兜底）：
/// - 邀请（→ 邀请向导：三条独立结果）
/// - 移除（409 冲突清单由服务端消息透出）
/// - 改角色（Owner/Member/Guest；最后 Owner 保护在服务端）
/// - 主 Owner 转移（目标须为非 Guest active 成员）
/// - Branding 编辑 / 归档 / 恢复（入口在页面底部治理区）
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class WorkspaceMembersPage extends ConsumerStatefulWidget {
  const WorkspaceMembersPage({super.key});

  @override
  ConsumerState<WorkspaceMembersPage> createState() =>
      _WorkspaceMembersPageState();
}

class _WorkspaceMembersPageState extends ConsumerState<WorkspaceMembersPage> {
  bool _mutating = false;

  /// 当前用户在当前工作区的角色（从成员列表推导；无记录 → null 视为只读）。
  WorkspaceMemberRole? _myRole(
    List<WorkspaceMemberModel> members,
    EntityId myUid,
  ) {
    for (final m in members) {
      if (m.userId == myUid) return m.role;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final ws = ref.watch(currentWorkspaceProvider);
    final wsId = ws?.id ?? '';
    if (wsId.isEmpty) {
      return WorkspaceEmptyView(
        icon: CupertinoIcons.person_crop_circle,
        title: t.workspace.membersTitle,
        subtitle: t.workspace.emptyNoWorkspace,
      );
    }
    final archived = ws?.isArchived ?? false;
    final members = ref.watch(workspaceMembersProvider(wsId));
    final myUid = UserRepoLocal.to.currentUid;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          if (archived) const WorkspaceArchivedBanner(),
          Expanded(
            child: members.when(
              loading: () => const WorkspaceLoadingView(),
              error: (e, _) => WorkspaceErrorView(
                message: workspaceErrorMessage(e),
                onRetry: () => ref.invalidate(workspaceMembersProvider(wsId)),
              ),
              data: (page) {
                final isOwner =
                    _myRole(page.list, myUid) == WorkspaceMemberRole.owner;
                return _MembersBody(
                  wsId: wsId,
                  members: page.list,
                  archived: archived,
                  isOwner: isOwner,
                  myUid: myUid,
                  onRemove: (m) => _confirmRemove(m),
                  onRoleChange: (m, role) => _changeRole(m, role),
                  onTransfer: (m) => _confirmTransfer(m),
                  onArchiveToggle: () => _confirmArchiveToggle(archived),
                  onInvite: () =>
                      context.push('/workspace/$wsId/members/invite'),
                  onBranding: () => context.push('/workspace/$wsId/branding'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 治理写操作统一入口：archived 禁用（按钮已 disabled，这里兜底）+
  /// 失败透传服务端消息（409 冲突清单 / 980 归档）。
  Future<void> _guardRun(Future<void> Function() action) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      await action();
    } on WorkspaceApiException catch (e) {
      AppLoading.showBackendError(e.message);
    } catch (e) {
      AppLoading.showError(e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _confirmRemove(WorkspaceMemberModel m) async {
    final t = context.t;
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(t.workspace.removeMemberTitle(name: m.nickname)),
        message: Text(t.workspace.removeMemberDesc),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.workspace.removeMemberConfirm),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(t.common.cancel),
        ),
      ),
    );
    if (confirmed != true) return;
    final wsId = ref.read(currentWorkspaceProvider)?.id ?? '';
    await _guardRun(() async {
      await ref
          .read(workspaceApiProvider)
          .removeMember(workspaceId: wsId, userId: m.userId);
      // 服务端 409（membership_conflict）时不会走到这里：冲突清单文本
      // 已由 WorkspaceApiException.message 原样透出（含未完成任务列表）。
      ref.invalidate(workspaceMembersProvider(wsId));
      ref.invalidate(workspaceOverviewProvider(wsId));
    });
  }

  Future<void> _changeRole(
    WorkspaceMemberModel m,
    WorkspaceMemberRole role,
  ) async {
    final wsId = ref.read(currentWorkspaceProvider)?.id ?? '';
    await _guardRun(() async {
      await ref
          .read(workspaceApiProvider)
          .changeRole(workspaceId: wsId, userId: m.userId, role: role);
      ref.invalidate(workspaceMembersProvider(wsId));
    });
  }

  Future<void> _confirmTransfer(WorkspaceMemberModel m) async {
    final t = context.t;
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(t.workspace.transferTitle(name: m.nickname)),
        message: Text(t.workspace.transferDesc),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.workspace.transferConfirm),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(t.common.cancel),
        ),
      ),
    );
    if (confirmed != true) return;
    final wsId = ref.read(currentWorkspaceProvider)?.id ?? '';
    await _guardRun(() async {
      await ref
          .read(workspaceApiProvider)
          .transferOwner(workspaceId: wsId, userId: m.userId);
      ref.invalidate(workspaceMembersProvider(wsId));
    });
  }

  Future<void> _confirmArchiveToggle(bool archived) async {
    final t = context.t;
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(
          archived ? t.workspace.restoreTitle : t.workspace.archiveTitle,
        ),
        message: Text(
          archived ? t.workspace.restoreDesc : t.workspace.archiveDesc,
        ),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: !archived,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              archived
                  ? t.workspace.restoreConfirm
                  : t.workspace.archiveConfirm,
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(t.common.cancel),
        ),
      ),
    );
    if (confirmed != true) return;
    final ws = ref.read(currentWorkspaceProvider);
    final wsId = ws?.id ?? '';
    if (wsId.isEmpty) return;
    await _guardRun(() async {
      final api = ref.read(workspaceApiProvider);
      if (archived) {
        await api.restore(wsId);
      } else {
        await api.archive(wsId);
      }
      // 轻量同步壳内工作区行（状态 + banner 立即生效）
      final updated = await api.detail(wsId);
      ref.read(workspaceShellProvider.notifier).replaceWorkspace(updated);
      ref.invalidate(workspaceMembersProvider(wsId));
    });
  }
}

/// 成员列表主体（纯展示 + 回调，便于 widget 测试注入）。
class _MembersBody extends StatelessWidget {
  final EntityId wsId;
  final List<WorkspaceMemberModel> members;
  final bool archived;
  final bool isOwner;
  final EntityId myUid;
  final void Function(WorkspaceMemberModel m) onRemove;
  final void Function(WorkspaceMemberModel m, WorkspaceMemberRole role)
  onRoleChange;
  final void Function(WorkspaceMemberModel m) onTransfer;
  final VoidCallback onArchiveToggle;
  final VoidCallback onInvite;
  final VoidCallback onBranding;

  const _MembersBody({
    required this.wsId,
    required this.members,
    required this.archived,
    required this.isOwner,
    required this.myUid,
    required this.onRemove,
    required this.onRoleChange,
    required this.onTransfer,
    required this.onArchiveToggle,
    required this.onInvite,
    required this.onBranding,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    if (members.isEmpty) {
      return WorkspaceEmptyView(
        icon: CupertinoIcons.person_crop_circle,
        title: t.workspace.membersEmpty,
        subtitle: t.workspace.membersEmptySubtitle,
      );
    }
    return ListView(
      padding: AppSpacing.allRegular,
      children: [
        if (isOwner)
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('workspace-invite-entry'),
                  // archived：写操作禁用（服务端 980 兜底）
                  onPressed: archived ? null : onInvite,
                  icon: const Icon(CupertinoIcons.person_add, size: 18),
                  label: Text(t.workspace.inviteEntry),
                ),
              ),
            ],
          ),
        if (isOwner) AppSpacing.verticalRegular,
        ...[
          for (final m in members)
            _MemberTile(
              member: m,
              isMe: m.userId == myUid,
              isOwnerPanel: isOwner,
              archived: archived,
              onRemove: onRemove,
              onRoleChange: onRoleChange,
              onTransfer: onTransfer,
            ),
        ],
        if (isOwner) ...[
          AppSpacing.verticalRegular,
          WorkspaceSectionCard(
            title: t.workspace.governanceTitle,
            child: Column(
              children: [
                // Material(transparency)：ListTile 需要最近 Material 祖先
                // 渲染水波纹，否则被 WorkspaceSectionCard 的 DecoratedBox
                // 背景遮挡（flutter_test 资产断言）
                Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    key: const ValueKey('workspace-branding-entry'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(CupertinoIcons.paintbrush),
                    title: Text(t.workspace.brandingEntry),
                    onTap: onBranding,
                  ),
                ),
                Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    key: ValueKey(
                      archived
                          ? 'workspace-restore-entry'
                          : 'workspace-archive-entry',
                    ),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      archived
                          ? CupertinoIcons.arrow_clockwise
                          : CupertinoIcons.archivebox,
                      color: archived ? null : AppColors.iosRed,
                    ),
                    title: Text(
                      archived
                          ? t.workspace.restoreEntry
                          : t.workspace.archiveEntry,
                      style: archived
                          ? null
                          : theme.textTheme.bodyLarge?.copyWith(
                              color: AppColors.iosRed,
                            ),
                    ),
                    onTap: onArchiveToggle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  final WorkspaceMemberModel member;
  final bool isMe;
  final bool isOwnerPanel;
  final bool archived;
  final void Function(WorkspaceMemberModel m) onRemove;
  final void Function(WorkspaceMemberModel m, WorkspaceMemberRole role)
  onRoleChange;
  final void Function(WorkspaceMemberModel m) onTransfer;

  const _MemberTile({
    required this.member,
    required this.isMe,
    required this.isOwnerPanel,
    required this.archived,
    required this.onRemove,
    required this.onRoleChange,
    required this.onTransfer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final writable = isOwnerPanel && !archived;
    final canTransfer =
        writable && !isMe && member.role != WorkspaceMemberRole.guest;
    final canRemove = writable && !isMe;
    return Container(
      key: ValueKey('workspace-member-tile-${member.userId}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      padding: AppSpacing.allRegular,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.regular),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primaryContainer,
            backgroundImage: member.avatar.isNotEmpty
                ? NetworkImage(member.avatar)
                : null,
            child: member.avatar.isEmpty
                ? Icon(
                    CupertinoIcons.person_fill,
                    size: 18,
                    color: theme.colorScheme.onPrimaryContainer,
                  )
                : null,
          ),
          AppSpacing.horizontalRegular,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.nickname.isEmpty
                            ? member.account
                            : member.nickname,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    AppSpacing.horizontalSmall,
                    WorkspaceRoleBadge(role: member.role),
                  ],
                ),
                if (member.account.isNotEmpty)
                  Text(
                    '@${member.account}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (canRemove)
            IconButton(
              key: ValueKey('workspace-member-remove-${member.userId}'),
              icon: const Icon(CupertinoIcons.delete, size: 18),
              onPressed: () => onRemove(member),
            ),
          if (writable && !isMe)
            IconButton(
              key: ValueKey('workspace-member-role-${member.userId}'),
              icon: const Icon(Icons.manage_accounts_outlined, size: 18),
              onPressed: () => _showRoleSheet(context, member),
            ),
          if (canTransfer)
            IconButton(
              key: ValueKey('workspace-member-transfer-${member.userId}'),
              icon: const Icon(Icons.workspace_premium_outlined, size: 18),
              onPressed: () => onTransfer(member),
            ),
        ],
      ),
    );
  }

  void _showRoleSheet(BuildContext context, WorkspaceMemberModel m) {
    final t = context.t;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(t.workspace.changeRoleTitle(name: m.nickname)),
        actions: [
          for (final role in WorkspaceMemberRole.values)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                onRoleChange(m, role);
              },
              child: Text(
                role == WorkspaceMemberRole.owner
                    ? t.workspace.roleOwner
                    : role == WorkspaceMemberRole.member
                    ? t.workspace.roleMember
                    : t.workspace.roleGuest,
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(t.common.cancel),
        ),
      ),
    );
  }
}
