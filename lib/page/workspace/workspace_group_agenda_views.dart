/// 企业壳「消息」页 日程 / 待办 内容态（2026-10 改版）：
/// 聚合当前工作区内企业群的群日程与群作业。
///
/// 数据面：GroupScheduleApi.getMySchedules / GroupTaskApi.getMyTasks
/// 是账号级跨群列表，本视图用 workspaceGroupsProvider（本工作区群全集）
/// 做 group_id 交集聚合——只展示企业群里的日程/待办，个人群不混入。
/// 条目点击跳既有群维度详情路由（日程/作业详情页归属群上下文）。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/schedule/group_schedule_ui.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/store/api/group_schedule_api.dart';
import 'package:imboy/store/api/group_task_api.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 本工作区群索引：groupId → 群名（displayTitle）。
final _workspaceGroupNamesProvider = FutureProvider.autoDispose
    .family<Map<String, String>, String>((ref, wsId) async {
      final groups = await ref.watch(workspaceGroupsProvider(wsId).future);
      return {
        for (final group in groups)
          group.groupId.toString(): group.displayTitle,
      };
    });

/// 企业群日程聚合（我的日程 ∩ 本工作区群）。
final workspaceGroupSchedulesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, wsId) async {
      final names = await ref.watch(_workspaceGroupNamesProvider(wsId).future);
      final rows = await GroupScheduleApi().getMySchedules();
      return rows
          .where((row) => names.containsKey(_text(row['group_id'])))
          .toList()
        ..sort(
          (a, b) =>
              _int(a['start_time'] ?? a['start_at'])
                  .compareTo(_int(b['start_time'] ?? b['start_at'])),
        );
    });

/// 企业群待办聚合（我的作业 ∩ 本工作区群；未提交且未截止才算待办）。
final workspaceGroupTodosProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, wsId) async {
      final names = await ref.watch(_workspaceGroupNamesProvider(wsId).future);
      final rows = await GroupTaskApi().getMyTasks();
      return rows.where((row) {
          if (!names.containsKey(_text(row['group_id']))) return false;
          // 同群作业页语义：3 = 已截止；my_assignment.status 2 已提交 /
          // 3 已批改都算「我已完成」，均不入待办。
          if (_int(row['status']) == 3) return false;
          final assignment = row['my_assignment'];
          final myStatus = assignment is Map ? _int(assignment['status']) : 0;
          return myStatus != 2 && myStatus != 3;
        }).toList()
        ..sort((a, b) => _int(a['deadline']).compareTo(_int(b['deadline'])));
    });

String _text(dynamic value) => value?.toString().trim() ?? '';

int _int(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

/// 内容态骨架：工作区未就绪 → 引导；就绪 → 聚合列表。
class WorkspaceGroupAgendaView extends ConsumerWidget {
  const WorkspaceGroupAgendaView({super.key, required this.kind});

  final WorkspaceAgendaKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wsId = ref.watch(currentWorkspaceProvider)?.id ?? '';
    if (wsId.isEmpty) {
      return WorkspaceEmptyView(
        icon: kind == WorkspaceAgendaKind.schedule
            ? CupertinoIcons.calendar
            : CupertinoIcons.checkmark_circle,
        title: t.chat.groupChat,
        subtitle: t.workspace.emptyNoWorkspace,
      );
    }
    final provider = kind == WorkspaceAgendaKind.schedule
        ? workspaceGroupSchedulesProvider(wsId)
        : workspaceGroupTodosProvider(wsId);
    return ref
        .watch(provider)
        .when(
          skipLoadingOnRefresh: false,
          loading: () => const WorkspaceLoadingView(),
          error: (error, _) => WorkspaceErrorView(
            message: error.toString(),
            onRetry: () => ref.invalidate(provider),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return WorkspaceEmptyView(
                icon: kind == WorkspaceAgendaKind.schedule
                    ? CupertinoIcons.calendar
                    : CupertinoIcons.checkmark_circle,
                title: kind == WorkspaceAgendaKind.schedule
                    ? t.groupSchedule.noSchedule
                    : t.groupTask.noTask,
                subtitle: '',
              );
            }
            return CustomScrollView(
              slivers: [
                CupertinoSliverRefreshControl(
                  onRefresh: () async {
                    ref.invalidate(_workspaceGroupNamesProvider(wsId));
                    ref.invalidate(provider);
                    await ref.watch(provider.future);
                  },
                ),
                SliverList.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) =>
                      kind == WorkspaceAgendaKind.schedule
                      ? _ScheduleCard(row: rows[index])
                      : _TodoCard(row: rows[index]),
                ),
              ],
            );
          },
        );
  }
}

enum WorkspaceAgendaKind { schedule, todo }

/// 日程卡：iOS 日历风日期块 + 标题/时间/群名 + 状态徽章（复用群日程
/// 组件 ScheduleDateBlock / resolveScheduleTimeState，视觉与群内一致）。
class _ScheduleCard extends ConsumerWidget {
  const _ScheduleCard({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final startAt = _int(row['start_time'] ?? row['start_at']);
    final endAt = _int(row['end_time'] ?? row['end_at']);
    final start = DateTime.fromMillisecondsSinceEpoch(startAt * 1000);
    final state = resolveScheduleTimeState(
      status: _int(row['status']),
      startAtSec: startAt,
      endAtSec: endAt,
      nowSec: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    final cancelled = state == GroupScheduleTimeState.cancelled;
    final groupId = _text(row['group_id']);
    final scheduleId = _text(row['schedule_id']).isNotEmpty
        ? _text(row['schedule_id'])
        : _text(row['id']);
    final groupName = ref
        .watch(
          _workspaceGroupNamesProvider(
            ref.watch(currentWorkspaceProvider)?.id ?? '',
          ),
        )
        .asData
        ?.value[groupId];

    return GestureDetector(
      onTap: () {
        if (groupId.isEmpty || scheduleId.isEmpty) return;
        context.push(
          '/group/$groupId/schedule/${Uri.encodeComponent(scheduleId)}',
        );
      },
      child: Opacity(
        opacity: cancelled ? 0.6 : 1,
        child: Container(
          margin: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.regular,
            AppSpacing.small,
            AppSpacing.regular,
            0,
          ),
          padding: const EdgeInsets.all(AppSpacing.regular),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceGroupedTertiary
                : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              ScheduleDateBlock(dateTime: start, muted: cancelled),
              AppSpacing.horizontalRegular,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _text(row['title']).isEmpty
                                ? t.groupSchedule.untitledSchedule
                                : _text(row['title']),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyle(
                              FontSizeType.subheadline,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                        AppSpacing.horizontalSmall,
                        ScheduleStatusBadge(state: state),
                      ],
                    ),
                    AppSpacing.verticalTiny,
                    Text(
                      '${_hm(start)}'
                      '${endAt > startAt ? ' - ${_hm(DateTime.fromMillisecondsSinceEpoch(endAt * 1000))}' : ''}'
                      '${groupName == null ? '' : ' · $groupName'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyle(
                        FontSizeType.footnote,
                        color: AppColors.iosGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _hm(DateTime dt) =>
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

/// 待办卡：作业标题 + 截止时间 + 群名；点击进作业详情（可提交）。
class _TodoCard extends ConsumerWidget {
  const _TodoCard({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupId = _text(row['group_id']);
    final taskId = _text(row['task_id']).isNotEmpty
        ? _text(row['task_id'])
        : _text(row['id']);
    final groupName = ref
        .watch(
          _workspaceGroupNamesProvider(
            ref.watch(currentWorkspaceProvider)?.id ?? '',
          ),
        )
        .asData
        ?.value[groupId];
    final deadlineAt = _int(row['deadline']);
    final deadline = deadlineAt > 0
        ? DateTime.fromMillisecondsSinceEpoch(deadlineAt * 1000)
        : null;
    final overdue = deadline != null && deadline.isBefore(DateTime.now());

    return GestureDetector(
      onTap: () {
        if (groupId.isEmpty || taskId.isEmpty) return;
        context.push('/group/$groupId/task/${Uri.encodeComponent(taskId)}');
      },
      child: Container(
        margin: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.regular,
          AppSpacing.small,
          AppSpacing.regular,
          0,
        ),
        padding: const EdgeInsets.all(AppSpacing.regular),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceGroupedTertiary
              : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.circle,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            AppSpacing.horizontalRegular,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _text(row['title']).isEmpty
                        ? t.main.unnamed
                        : _text(row['title']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyle(
                      FontSizeType.subheadline,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  AppSpacing.verticalTiny,
                  Text(
                    '${deadline == null
                        ? t.groupTask.noDeadline
                        : overdue
                        ? '${t.groupTask.overdue} · ${_fmt(deadline)}'
                        : '${t.groupTask.deadline} ${_fmt(deadline)}'}'
                    '${groupName == null ? '' : ' · $groupName'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyle(
                      FontSizeType.footnote,
                      color: overdue ? AppColors.iosRed : AppColors.iosGray,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: AppColors.iosGray3,
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}
