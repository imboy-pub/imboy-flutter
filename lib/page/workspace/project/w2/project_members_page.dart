/// W2 (ZC-02/ZC-06) — 项目成员页（Project Members）
///
/// 权限模型（服务端唯一真相，project_member_logic 文件头对齐）：
/// - 读：Project Owner / Workspace Owner / active 项目成员；非成员直访
///   403 → [ProjectForbiddenView] 明确无权限态（不缓存豁免）；
/// - 邀请/转移：仅 Project Owner；移除：Project Owner 或 Workspace Owner；
/// - Workspace Guest 只读（写入口隐藏 + 只读说明行）；
/// - archived 工作区写入口禁用（980 服务端兜底）。
///
/// 幂等反馈（后端 status_flag）：invite created|existing；remove
/// removed|already_removed——重复操作给明确幂等 toast，不报错。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/workspace_api.dart' show WorkspaceApiException;
import 'package:imboy/store/model/project_w2_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/page/workspace/project/project_data_providers.dart';
import 'package:imboy/page/workspace/project/w2/project_w2_providers.dart';
import 'package:imboy/page/workspace/project/w2/project_w2_view_widgets.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class ProjectMembersPage extends ConsumerStatefulWidget {
  final EntityId projectId;

  /// 路由携带的工作区 id（角色判定在成员列表加载完成前即可用）。
  final EntityId workspaceId;

  const ProjectMembersPage({
    super.key,
    required this.projectId,
    this.workspaceId = '',
  });

  @override
  ConsumerState<ProjectMembersPage> createState() => _ProjectMembersPageState();
}

class _ProjectMembersPageState extends ConsumerState<ProjectMembersPage> {
  int _pages = 1;
  bool _mutating = false;

  Future<void> _runWrite(Future<void> Function() action) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      await action();
    } on WorkspaceApiException catch (e) {
      if (mounted) AppLoading.showBackendError(e.message);
    } catch (e) {
      if (mounted) AppLoading.showError(e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  void _invalidatePages(EntityId projectId) {
    for (var p = 1; p <= _pages; p++) {
      ref.invalidate(projectMemberPageProvider((projectId, p)));
    }
  }

  Future<void> _invite(EntityId projectId) async {
    final t = context.t;
    final controller = TextEditingController();
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.workspace.projectMemberInviteTitle),
        content: Column(
          children: [
            const SizedBox(height: AppSpacing.tiny),
            CupertinoTextField(
              key: const ValueKey('project-member-invite-field'),
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              placeholder: t.workspace.projectMemberInviteFieldHint,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.common.cancel),
          ),
          CupertinoDialogAction(
            key: const ValueKey('project-member-invite-submit'),
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.workspace.projectMemberInviteSubmit),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final uid = controller.text.trim();
    if (uid.isEmpty || int.tryParse(uid) == null) {
      AppLoading.showBackendError(t.workspace.projectMemberInviteInvalidUid);
      return;
    }
    await _runWrite(() async {
      final result = await ref
          .read(projectMemberApiProvider)
          .invite(projectId: projectId, userId: uid);
      if (!mounted) return;
      if (result.isAlreadyMember) {
        // 幂等命中：不报错、不重复入库，给明确反馈
        AppLoading.showSuccess(t.workspace.projectMemberInviteExisting);
      } else {
        AppLoading.showSuccess(t.workspace.projectMemberInviteSuccess);
      }
      _invalidatePages(projectId);
    });
  }

  Future<void> _remove(EntityId projectId, ProjectMemberModel m) async {
    final t = context.t;
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(
          t.workspace.projectMemberRemoveConfirmTitle(name: m.displayName),
        ),
        message: Text(t.workspace.projectMemberRemoveConfirmDesc),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.workspace.projectMemberRemoveSubmit),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(t.common.cancel),
        ),
      ),
    );
    if (confirmed != true) return;
    await _runWrite(() async {
      final result = await ref
          .read(projectMemberApiProvider)
          .remove(projectId: projectId, userId: m.userId);
      if (!mounted) return;
      AppLoading.showSuccess(
        result.isAlreadyRemoved
            ? t.workspace.projectMemberAlreadyRemovedToast
            : t.workspace.projectMemberRemovedToast,
      );
      _invalidatePages(projectId);
    });
  }

  Future<void> _transfer(EntityId projectId, ProjectMemberModel m) async {
    final t = context.t;
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(
          t.workspace.projectMemberTransferTitle(name: m.displayName),
        ),
        message: Text(t.workspace.projectMemberTransferDesc),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.workspace.projectMemberTransferConfirm),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(t.common.cancel),
        ),
      ),
    );
    if (confirmed != true) return;
    await _runWrite(() async {
      await ref
          .read(projectMemberApiProvider)
          .transferOwner(projectId: projectId, newOwnerUid: m.userId);
      if (mounted) {
        AppLoading.showSuccess(t.workspace.projectMemberTransferDoneToast);
      }
      _invalidatePages(projectId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final myUid = UserRepoLocal.to.currentUid;
    final detailAsync = ref.watch(projectDetailProvider(widget.projectId));
    final project = detailAsync.value;
    final wsId = widget.workspaceId.isNotEmpty
        ? widget.workspaceId
        : (project?.workspaceId ?? '');
    final currentWs = ref.watch(currentWorkspaceProvider);
    final archived =
        currentWs != null && currentWs.id == wsId && currentWs.isArchived;
    final membersAsync = wsId.isEmpty
        ? null
        : ref.watch(assigneeCandidatesProvider(wsId));
    // 我的 Workspace 角色（成员列表未就绪时保守只读；无记录 → null）
    WorkspaceMemberRole? myWsRole;
    for (final m in membersAsync?.value ?? const <WorkspaceMemberModel>[]) {
      if (m.userId == myUid) myWsRole = m.role;
    }
    final isGuest = myWsRole == WorkspaceMemberRole.guest;
    final isProjectOwner =
        project != null && project.ownerId == myUid && myUid.isNotEmpty;
    final isWsOwner = myWsRole == WorkspaceMemberRole.owner;
    // 邀请/转移：仅 Project Owner；移除：Project Owner 或 Workspace Owner；
    // Guest 一律隐藏写入口；archived 禁写。
    final canInvite = isProjectOwner && !isGuest && !archived;
    final canRemove = (isProjectOwner || isWsOwner) && !isGuest && !archived;
    final canTransfer = isProjectOwner && !isGuest && !archived;

    final pageAsyncs = <AsyncValue<WorkspacePageResult<ProjectMemberModel>>>[
      for (var p = 1; p <= _pages; p++)
        ref.watch(projectMemberPageProvider((widget.projectId, p))),
    ];
    final hasLoading = pageAsyncs.any((a) => a.isLoading);
    final firstError = pageAsyncs
        .where((a) => a.hasError)
        .map((a) => a.error)
        .firstOrNull;
    final loadedPages = <WorkspacePageResult<ProjectMemberModel>>[
      for (final a in pageAsyncs) ?a.value,
    ];

    Widget body;
    if (firstError != null && loadedPages.isEmpty) {
      body = isProjectForbiddenError(firstError)
          ? ProjectForbiddenView(
              onRetry: () => ref.invalidate(
                projectMemberPageProvider((widget.projectId, 1)),
              ),
            )
          : WorkspaceErrorView(
              message: projectW2ViewMessage(context, firstError),
              onRetry: () => ref.invalidate(
                projectMemberPageProvider((widget.projectId, 1)),
              ),
            );
    } else if (hasLoading && loadedPages.isEmpty) {
      body = const WorkspaceLoadingView();
    } else {
      final items = [for (final pg in loadedPages) ...pg.list];
      final totalPage = loadedPages.isEmpty ? 1 : loadedPages.last.totalPage;
      body = ListView(
        padding: AppSpacing.allRegular,
        children: [
          if (isGuest)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.small),
              child: Text(
                t.workspace.projectGuestReadonly,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (canInvite)
            FilledButton.icon(
              key: const ValueKey('project-member-invite-entry'),
              onPressed: _mutating ? null : () => _invite(widget.projectId),
              icon: const Icon(CupertinoIcons.person_add, size: 18),
              label: Text(t.workspace.projectMemberInviteTitle),
            ),
          if (canInvite) AppSpacing.verticalRegular,
          if (items.isEmpty)
            WorkspaceEmptyView(
              icon: CupertinoIcons.person_crop_circle,
              title: t.workspace.projectMemberEmptyTitle,
              subtitle: t.workspace.projectMemberEmptySubtitle,
            )
          else ...[
            for (final m in items)
              _MemberTile(
                member: m,
                isMe: m.userId == myUid,
                canRemove: canRemove && m.userId != myUid,
                canTransfer: canTransfer && m.userId != myUid,
                mutating: _mutating,
                onRemove: () => _remove(widget.projectId, m),
                onTransfer: () => _transfer(widget.projectId, m),
              ),
          ],
          if (!hasLoading && loadedPages.isNotEmpty && totalPage > _pages) ...[
            AppSpacing.verticalSmall,
            ProjectW2LoadMoreButton(
              onPressed: () => setState(() => _pages += 1),
            ),
          ],
          if (hasLoading && loadedPages.isNotEmpty)
            const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.workspace.projectMembersTitle)),
      body: body,
    );
  }
}

class _MemberTile extends StatelessWidget {
  final ProjectMemberModel member;
  final bool isMe;
  final bool canRemove;
  final bool canTransfer;
  final bool mutating;
  final VoidCallback onRemove;
  final VoidCallback onTransfer;

  const _MemberTile({
    required this.member,
    required this.isMe,
    required this.canRemove,
    required this.canTransfer,
    required this.mutating,
    required this.onRemove,
    required this.onTransfer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: ValueKey('project-member-tile-${member.userId}'),
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
                Text(member.displayName, style: theme.textTheme.titleSmall),
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
              key: ValueKey('project-member-remove-${member.userId}'),
              tooltip: context.t.workspace.projectMemberRemoveSubmit,
              icon: const Icon(CupertinoIcons.delete, size: 18),
              onPressed: mutating ? null : onRemove,
            ),
          if (canTransfer)
            IconButton(
              key: ValueKey('project-member-transfer-${member.userId}'),
              tooltip: context.t.workspace.projectMemberTransferConfirm,
              icon: const Icon(Icons.workspace_premium_outlined, size: 18),
              onPressed: mutating ? null : onTransfer,
            ),
        ],
      ),
    );
  }
}
