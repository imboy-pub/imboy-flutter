/// 企业壳「消息」页 日程 / 待办 内容态（2026-10 改版）：
/// 聚合当前工作区内企业群的群日程与群作业。
///
/// 口径（2026-10-16 用户拍板）：
/// - 日程 = 群级：我所在企业群的日程（GroupScheduleApi.getMySchedules，
///   后端 my_list 即群级）；
/// - 待办 = 企业维度全群作业：本工作区（企业）下各企业群的群作业全量
///   列表，不再只看「指派给我」——原实现走 GroupTaskApi.getMyTasks
///   （后端 group_task_logic:my_tasks → assignment_list_by_user_id），
///   老师/未被指派者恒为空，被判定为「查不出东西」。
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

/// 企业群待办聚合（企业维度：本工作区各企业群的群作业全量列表）。
///
/// 实现：按 workspaceGroupsProvider（企业内我加入的群）逐群并发
/// GroupTaskApi.getTasks（成员可读，后端会为每行注入 my_assignment
/// 供展示「我的状态」）。
/// 边界：/group/task/list 要求 viewer 是该群成员（group_task_logic:list/6），
/// 因此覆盖 = 企业内我加入的群；单群失败（已退群/权限变更）只跳过该群。
// TODO 广州第一期交付后实现：后端补「企业级作业聚合端点」，替代前端
// 逐群扇出，并覆盖企业内未加入的群。
final workspaceGroupTodosProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, wsId) async {
      final groups = await ref.watch(workspaceGroupsProvider(wsId).future);
      if (groups.isEmpty) return const <Map<String, dynamic>>[];
      final api = GroupTaskApi();
      final pages = await Future.wait([
        for (final group in groups) _groupTasks(api, group.groupId.toString()),
      ]);
      final rows = <Map<String, dynamic>>[for (final page in pages) ...page];
      // 「待办」视图的组织方式（对标飞书待办的进行中/已完成分区习惯）：
      // 待完成在前（按截止时间升序，无截止排最后），已完成/已截止沉底。
      bool doneOf(Map<String, dynamic> row) {
        if (_int(row['status']) == 3) return true;
        final assignment = row['my_assignment'];
        return assignment is Map && _int(assignment['status']) >= 2;
      }

      int byDeadline(Map<String, dynamic> a, Map<String, dynamic> b) {
        final da = _int(a['deadline']);
        final db = _int(b['deadline']);
        if (da == 0) return db == 0 ? 0 : 1;
        if (db == 0) return -1;
        return da.compareTo(db);
      }

      rows.sort((a, b) {
        final doneA = doneOf(a);
        final doneB = doneOf(b);
        if (doneA != doneB) return doneA ? 1 : -1;
        return byDeadline(a, b);
      });
      return rows;
    });

/// 单群作业列表；失败只跳过该群，不拖垮整个聚合（见上 provider 注释）。
Future<List<Map<String, dynamic>>> _groupTasks(
  GroupTaskApi api,
  String groupId,
) async {
  try {
    return await api.getTasks(groupId: groupId, size: 50);
  } catch (_) {
    return const <Map<String, dynamic>>[];
  }
}

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
                // 待办视图与详情页全量统一「待办」措辞。
                title: kind == WorkspaceAgendaKind.schedule
                    ? t.groupSchedule.noSchedule
                    : t.workspace.todoEmptyTitle,
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

/// 待办卡（企业群作业）：标题 + 我的状态 + 截止时间 + 群名；点击进作业
/// 详情（可提交/可批改）。状态口径同群作业页：作业 1待完成/2进行中/
/// 3已截止；我的 assignment 2已提交/3已批改。
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
    // 作业已截止（status=3）→ 已过期；否则我的提交态（2已提交/3已批改）
    // → 已完成；未指派/未提交 → 待完成。
    final expired = _int(row['status']) == 3;
    final assignment = row['my_assignment'];
    final myStatus = assignment is Map ? _int(assignment['status']) : 0;
    final myLabel = expired
        ? t.groupTask.overdue
        : myStatus >= 2
        ? t.groupTask.completed
        : t.groupTask.pending;
    final done = expired || myStatus >= 2;

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
              done ? CupertinoIcons.checkmark_circle : CupertinoIcons.circle,
              size: 20,
              color: done
                  ? AppColors.iosGray
                  : Theme.of(context).colorScheme.primary,
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
                    '$myLabel'
                    '${deadline == null ? ' · ${t.groupTask.noDeadline}' : ' · ${overdue ? t.groupTask.overdue : t.groupTask.deadline} ${_fmt(deadline)}'}'
                    '${groupName == null ? '' : ' · $groupName'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyle(
                      FontSizeType.footnote,
                      color: overdue && !done
                          ? AppColors.iosRed
                          : AppColors.iosGray,
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
