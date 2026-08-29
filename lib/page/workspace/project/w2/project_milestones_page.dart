/// W2 (ZC-03/ZC-06) — 项目里程碑页（Milestones）
///
/// 轻量计划实体：name/due_date/status（+reached_at 审计）；状态机
/// planned→reached 单向，唯一流转入口 POST /milestones/:id/reach：
/// - planned 行提供「标记达成」；reached 行只读徽标（不可回退提示）；
/// - 重复 reach 幂等（already_reached → 明确反馈 toast，不报错）；
/// - status 筛选（all/planned/reached）变化时 page 重置 1（分页契约）；
/// - 后端列表 envelope 仅 {list,page,size}（无 total）→ 以「满页可能
///   有下一页」启发式提供加载更多。
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
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 每页条数（与 provider 固定 size:10 一致；加载更多启发式依据）。
const int _pageSize = 10;

final RegExp _dueDateRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');

class ProjectMilestonesPage extends ConsumerStatefulWidget {
  final EntityId projectId;
  final EntityId workspaceId;

  const ProjectMilestonesPage({
    super.key,
    required this.projectId,
    this.workspaceId = '',
  });

  @override
  ConsumerState<ProjectMilestonesPage> createState() =>
      _ProjectMilestonesPageState();
}

class _ProjectMilestonesPageState extends ConsumerState<ProjectMilestonesPage> {
  /// 筛选（all|planned|reached）；变化即 page 重置 1（换 family arg）。
  String _status = 'all';
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

  void _invalidatePages() {
    for (var p = 1; p <= _pages; p++) {
      ref.invalidate(
        projectMilestonePageProvider((widget.projectId, _status, p)),
      );
    }
  }

  Future<void> _create() async {
    final t = context.t;
    final nameCtrl = TextEditingController();
    final dueCtrl = TextEditingController();
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.workspace.projectMilestoneCreateTitle),
        content: Column(
          children: [
            const SizedBox(height: AppSpacing.tiny),
            CupertinoTextField(
              key: const ValueKey('project-milestone-name-field'),
              controller: nameCtrl,
              autofocus: true,
              placeholder: t.workspace.projectMilestoneNameLabel,
            ),
            const SizedBox(height: AppSpacing.small),
            CupertinoTextField(
              key: const ValueKey('project-milestone-due-field'),
              controller: dueCtrl,
              placeholder: t.workspace.projectMilestoneDueDateLabel,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.common.cancel),
          ),
          CupertinoDialogAction(
            key: const ValueKey('project-milestone-create-submit'),
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.workspace.projectMilestoneCreateSubmit),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final name = nameCtrl.text.trim();
    final due = dueCtrl.text.trim();
    if (name.isEmpty) {
      AppLoading.showBackendError(t.workspace.projectMilestoneNameRequired);
      return;
    }
    if (due.isNotEmpty && !_dueDateRe.hasMatch(due)) {
      AppLoading.showBackendError(t.workspace.projectMilestoneDueDateInvalid);
      return;
    }
    await _runWrite(() async {
      await ref
          .read(milestoneApiProvider)
          .create(projectId: widget.projectId, name: name, dueDate: due);
      if (mounted) {
        AppLoading.showSuccess(t.workspace.projectMilestoneCreatedToast);
      }
      _invalidatePages();
    });
  }

  Future<void> _reach(MilestoneModel ms) async {
    await _runWrite(() async {
      final result = await ref.read(milestoneApiProvider).reach(ms.id);
      if (!mounted) return;
      // 幂等反馈：planned→reached 单向，重复 reach 不报错
      AppLoading.showSuccess(
        result.isAlreadyReached
            ? t.workspace.projectMilestoneAlreadyReachedToast
            : t.workspace.projectMilestoneReachedToast,
      );
      _invalidatePages();
    });
  }

  void _changeFilter(String status) {
    if (status == _status) return;
    setState(() {
      _status = status;
      _pages = 1; // 筛选变化重置 page=1
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
    WorkspaceMemberRole? myWsRole;
    for (final m in membersAsync?.value ?? const <WorkspaceMemberModel>[]) {
      if (m.userId == myUid) myWsRole = m.role;
    }
    final isGuest = myWsRole == WorkspaceMemberRole.guest;
    final isProjectOwner =
        project != null && project.ownerId == myUid && myUid.isNotEmpty;
    // 写（create/reach）：Project Owner 或 active 非 Guest 项目成员；
    // 角色未就绪时保守只读（服务端 403 兜底）。
    final canWrite =
        !archived &&
        !isGuest &&
        (isProjectOwner ||
            (myWsRole != null && myWsRole != WorkspaceMemberRole.guest));

    final pageAsyncs = <AsyncValue<WorkspacePageResult<MilestoneModel>>>[
      for (var p = 1; p <= _pages; p++)
        ref.watch(projectMilestonePageProvider((widget.projectId, _status, p))),
    ];
    final hasLoading = pageAsyncs.any((a) => a.isLoading);
    final firstError = pageAsyncs
        .where((a) => a.hasError)
        .map((a) => a.error)
        .firstOrNull;
    final loadedPages = <WorkspacePageResult<MilestoneModel>>[
      for (final a in pageAsyncs) ?a.value,
    ];

    Widget body;
    if (firstError != null && loadedPages.isEmpty) {
      body = isProjectForbiddenError(firstError)
          ? ProjectForbiddenView(
              onRetry: () => ref.invalidate(
                projectMilestonePageProvider((widget.projectId, _status, 1)),
              ),
            )
          : WorkspaceErrorView(
              message: projectW2ViewMessage(context, firstError),
              onRetry: () => ref.invalidate(
                projectMilestonePageProvider((widget.projectId, _status, 1)),
              ),
            );
    } else if (hasLoading && loadedPages.isEmpty) {
      body = const WorkspaceLoadingView();
    } else {
      final items = [for (final pg in loadedPages) ...pg.list];
      final mayHaveMore =
          loadedPages.isNotEmpty && items.length >= _pageSize * _pages;
      body = RefreshIndicator(
        onRefresh: () async => _invalidatePages(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.allRegular,
          children: [
            if (canWrite)
              FilledButton.icon(
                key: const ValueKey('project-milestone-create-entry'),
                onPressed: _mutating ? null : _create,
                icon: const Icon(CupertinoIcons.flag, size: 18),
                label: Text(t.workspace.projectMilestoneCreateTitle),
              ),
            AppSpacing.verticalRegular,
            // status 筛选：all / planned / reached（变化即 page 重置 1）
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'all',
                  label: Text(t.workspace.projectMilestoneFilterAll),
                ),
                ButtonSegment(
                  value: 'planned',
                  label: Text(t.workspace.projectMilestoneFilterPlanned),
                ),
                ButtonSegment(
                  value: 'reached',
                  label: Text(t.workspace.projectMilestoneFilterReached),
                ),
              ],
              selected: {_status},
              onSelectionChanged: (selection) => _changeFilter(selection.first),
            ),
            AppSpacing.verticalRegular,
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
            if (items.isEmpty)
              WorkspaceEmptyView(
                icon: CupertinoIcons.flag_circle,
                title: t.workspace.projectMilestoneEmptyTitle,
                subtitle: t.workspace.projectMilestoneEmptySubtitle,
              )
            else ...[
              for (final ms in items)
                _MilestoneTile(
                  milestone: ms,
                  canWrite: canWrite,
                  mutating: _mutating,
                  onReach: () => _reach(ms),
                ),
            ],
            if (!hasLoading && mayHaveMore) ...[
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
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.workspace.projectMilestonesTitle)),
      body: body,
    );
  }
}

class _MilestoneTile extends StatelessWidget {
  final MilestoneModel milestone;
  final bool canWrite;
  final bool mutating;
  final VoidCallback onReach;

  const _MilestoneTile({
    required this.milestone,
    required this.canWrite,
    required this.mutating,
    required this.onReach,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final reached = milestone.isReached;
    final statusColor = reached ? AppColors.success : AppColors.slateText;
    return Container(
      key: ValueKey('project-milestone-tile-${milestone.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      padding: AppSpacing.allRegular,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.regular),
      ),
      child: Row(
        children: [
          Icon(
            reached ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.flag,
            size: 20,
            color: statusColor,
            semanticLabel: reached
                ? t.workspace.projectMilestoneFilterReached
                : t.workspace.projectMilestoneFilterPlanned,
          ),
          AppSpacing.horizontalRegular,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(milestone.name, style: theme.textTheme.titleSmall),
                AppSpacing.verticalTiny,
                Wrap(
                  spacing: AppSpacing.small,
                  runSpacing: AppSpacing.tiny,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      reached
                          ? t.workspace.projectMilestoneReachedHint
                          : t.workspace.projectMilestoneFilterPlanned,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: statusColor,
                      ),
                    ),
                    if (milestone.dueDateText.isNotEmpty)
                      Text(
                        '${t.workspace.projectMilestoneDueLabel} ${milestone.dueDateText}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // planned 可推进 reached；reached 单向终态无操作按钮（不可回退）
          if (canWrite && milestone.status.canAdvance)
            FilledButton.tonal(
              key: ValueKey('project-milestone-reach-${milestone.id}'),
              onPressed: mutating ? null : onReach,
              child: Text(t.workspace.projectMilestoneReach),
            ),
        ],
      ),
    );
  }
}
