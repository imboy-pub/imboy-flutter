/// WP6 (T10b) — 项目任务区块：四态筛选列表（轻量，非看板非拖拽）
///
/// §三 边界：Task 只有 title/assignee/status/sort；无拖拽看板、无甘特图、
/// 无估点、无依赖、无子任务。流转操作每次都有明确反馈：成功 toast /
/// 失败 toast 带服务端错误信息（400 非法流转消息原样透出；禁止静默失败）。
///
/// 状态机契约源 imboy `project_task_logic.erl`：
/// - 前向仅相邻一步：todo→doing→review→done
/// - 回退任意更低 rank 态；同态与跳级前向由服务端 400 拒绝
///   （本 UI 只提供合法按钮，服务端拒绝即 toast 显示其消息）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/workspace_api.dart' show WorkspaceApiException;
import 'package:imboy/store/model/project_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/page/workspace/project/project_data_providers.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 详情页内嵌的任务区块（T10a ↔ T10b 衔接点）。
class ProjectTasksSection extends ConsumerWidget {
  final ProjectModel project;
  final bool writable;

  const ProjectTasksSection({
    super.key,
    required this.project,
    required this.writable,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return WorkspaceSectionCard(
      title: t.workspace.projectTasksSection,
      trailing: writable
          ? IconButton(
              key: const ValueKey('project-task-new-entry'),
              tooltip: t.workspace.taskNewEntry,
              iconSize: 20,
              icon: const Icon(CupertinoIcons.add_circled),
              onPressed: () => context.push(
                '/workspace/${project.workspaceId}'
                '/projects/${project.id}/tasks/new',
              ),
            )
          : null,
      child: ProjectTasksView(project: project, writable: writable),
    );
  }
}

/// 任务四态视图（筛选条 + 轻量列表）。
class ProjectTasksView extends ConsumerStatefulWidget {
  final ProjectModel project;
  final bool writable;

  const ProjectTasksView({
    super.key,
    required this.project,
    required this.writable,
  });

  @override
  ConsumerState<ProjectTasksView> createState() => _ProjectTasksViewState();
}

class _ProjectTasksViewState extends ConsumerState<ProjectTasksView> {
  /// 本地筛选条选中态（all | todo | doing | review | done）。
  String _filter = 'all';

  /// 正在流转的任务 id 集合（防抖：同一任务重复点击只发一次请求）。
  final Set<EntityId> _mutatingIds = <EntityId>{};

  void _refresh(EntityId projectId) =>
      ref.invalidate(projectTasksProvider(projectId));

  /// 流转统一入口：成功 toast + 失败透传服务端消息（400/403/980），
  /// 禁止静默失败。
  Future<void> _transition(ProjectTaskModel task, TaskStatus to) async {
    if (_mutatingIds.contains(task.id)) return; // 防抖
    setState(() => _mutatingIds.add(task.id));
    try {
      await ref.read(projectApiProvider).changeTaskStatus(task.id, to);
      _refresh(widget.project.id);
      if (!mounted) return;
      AppLoading.showSuccess(
        context.t.workspace.taskStatusMovedToast(
          status: _statusLabel(context.t, to),
        ),
      );
    } on WorkspaceApiException catch (e) {
      if (mounted) AppLoading.showBackendError(e.message);
    } catch (e) {
      if (mounted) AppLoading.showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _mutatingIds.remove(task.id));
      }
    }
  }

  Future<void> _confirmFallback(ProjectTaskModel task) async {
    final t = context.t;
    final targets = task.status.fallbackTargets;
    if (targets.isEmpty || !widget.writable) return;
    final picked = await showCupertinoModalPopup<TaskStatus>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(t.workspace.taskFallbackMenuTitle(title: task.title)),
        actions: [
          for (final target in targets)
            CupertinoActionSheetAction(
              key: ValueKey('project-task-fallback-${target.wireName}'),
              onPressed: () => Navigator.of(ctx).pop(target),
              child: Text(_statusLabel(t, target)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(t.common.cancel),
        ),
      ),
    );
    if (picked == null) return;
    await _transition(task, picked);
  }

  String _statusLabel(Translations t, TaskStatus s) => switch (s) {
    TaskStatus.todo => t.workspace.taskStatusTodo,
    TaskStatus.doing => t.workspace.taskStatusDoing,
    TaskStatus.review => t.workspace.taskStatusReview,
    TaskStatus.done => t.workspace.taskStatusDone,
  };

  Color _statusColor(TaskStatus s) => switch (s) {
    TaskStatus.todo => AppColors.slateText,
    TaskStatus.doing => AppColors.primary,
    TaskStatus.review => AppColors.warning,
    TaskStatus.done => AppColors.success,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final tasksAsync = ref.watch(projectTasksProvider(widget.project.id));

    // 服务端任务的候选回退链由 TaskStatus.fallbackTargets 决定；
    // assignee 昵称从成员候选中解析（W0：active Workspace Member）。
    final wsId = widget.project.workspaceId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: t.workspace.taskFilterAll,
                selected: _filter == 'all',
                onTap: () => setState(() => _filter = 'all'),
              ),
              for (final s in TaskStatus.values)
                _FilterChip(
                  label: _statusLabel(t, s),
                  selected: _filter == s.wireName,
                  color: _statusColor(s),
                  onTap: () => setState(() => _filter = s.wireName),
                ),
            ],
          ),
        ),
        AppSpacing.verticalSmall,
        tasksAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.regular),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Column(
            children: [
              Text(
                workspaceErrorMessage(e),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              AppSpacing.verticalTiny,
              OutlinedButton(
                key: const ValueKey('project-task-retry'),
                onPressed: () => _refresh(widget.project.id),
                child: Text(t.common.buttonRetry),
              ),
            ],
          ),
          data: (tasks) {
            final visible = tasks
                .where(
                  (task) => _filter == 'all' || task.status.wireName == _filter,
                )
                .toList(growable: false);
            if (visible.isEmpty) {
              // tasks 为空 = 项目还没有任务；有任务但被筛选掉 = 该态下暂无
              return Text(
                tasks.isEmpty
                    ? '${t.workspace.taskEmptyTitle}\n${t.workspace.taskEmptySubtitle}'
                    : t.workspace.taskEmptyTitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              );
            }
            final members = wsId.isEmpty
                ? const <WorkspaceMemberModel>[]
                : (ref.watch(assigneeCandidatesProvider(wsId)).value ??
                      const <WorkspaceMemberModel>[]);
            return Column(
              children: [
                for (final task in visible)
                  _TaskTile(
                    task: task,
                    assigneeName: _memberName(members, task.assigneeId),
                    writable: widget.writable,
                    mutating: _mutatingIds.contains(task.id),
                    onAdvance: () {
                      final to = task.status.nextForward;
                      if (to != null) _transition(task, to);
                    },
                    onFallback: () => _confirmFallback(task),
                    onEdit: () => context.push(
                      '/workspace/$wsId/projects/${widget.project.id}'
                      '/tasks/${task.id}/edit',
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  String? _memberName(List<WorkspaceMemberModel> members, EntityId userId) {
    if (userId.isEmpty) return null;
    for (final m in members) {
      if (m.userId == userId) {
        return m.nickname.isEmpty ? m.account : m.nickname;
      }
    }
    return null;
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.small),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        labelStyle: TextStyle(
          fontSize: FontSizeType.small.size,
          color: selected ? theme.colorScheme.onPrimary : null,
        ),
        selectedColor: color ?? theme.colorScheme.primary,
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final ProjectTaskModel task;
  final String? assigneeName;
  final bool writable;
  final bool mutating;
  final VoidCallback onAdvance;
  final VoidCallback onFallback;
  final VoidCallback onEdit;

  const _TaskTile({
    required this.task,
    required this.assigneeName,
    required this.writable,
    required this.mutating,
    required this.onAdvance,
    required this.onFallback,
    required this.onEdit,
  });

  String _statusLabelOf(Translations t, TaskStatus s) => switch (s) {
    TaskStatus.todo => t.workspace.taskStatusTodo,
    TaskStatus.doing => t.workspace.taskStatusDoing,
    TaskStatus.review => t.workspace.taskStatusReview,
    TaskStatus.done => t.workspace.taskStatusDone,
  };

  Color _colorOf(TaskStatus s) => switch (s) {
    TaskStatus.todo => AppColors.slateText,
    TaskStatus.doing => AppColors.primary,
    TaskStatus.review => AppColors.warning,
    TaskStatus.done => AppColors.success,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final color = _colorOf(task.status);
    final canForward = writable && !mutating && task.status.nextForward != null;
    final canFallback =
        writable && !mutating && task.status.fallbackTargets.isNotEmpty;
    return Container(
      key: ValueKey('project-task-tile-${task.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      padding: AppSpacing.allMedium,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.medium),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: writable ? onEdit : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  AppSpacing.verticalTiny,
                  Wrap(
                    spacing: AppSpacing.small,
                    runSpacing: AppSpacing.tiny,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        key: ValueKey(
                          'project-task-status-badge-${task.id}-${task.status.wireName}',
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.small,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.tiny * 3,
                          ),
                        ),
                        child: Text(
                          _statusLabelOf(t, task.status),
                          style: TextStyle(
                            fontSize: FontSizeType.caption2.size,
                            color: color,
                          ),
                        ),
                      ),
                      if (assigneeName != null)
                        Text(
                          '@$assigneeName',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: FontSizeType.caption2.size,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (canForward)
            IconButton(
              key: ValueKey(
                'project-task-forward-${task.id}-${task.status.wireName}',
              ),
              tooltip: t.workspace.taskAdvanceTo(
                status: _statusLabelOf(t, task.status.nextForward!),
              ),
              iconSize: 20,
              icon: const Icon(CupertinoIcons.arrow_right_circle),
              onPressed: mutating ? null : onAdvance,
            ),
          if (canFallback)
            IconButton(
              key: ValueKey('project-task-fallback-menu-${task.id}'),
              tooltip: t.workspace.taskFallbackMenuTitle(title: task.title),
              iconSize: 20,
              icon: const Icon(CupertinoIcons.arrow_uturn_left_circle),
              onPressed: mutating ? null : onFallback,
            ),
          if (mutating)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}
