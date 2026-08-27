/// T9 (WP5) — Projects 列表视图（占位级：列表入口 + 空态）
///
/// 计划边界：Project 详情 / 任务 / 聚合视图属 WP6（T10a/T10b），本页只
/// 提供 Projects 导航的真实列表与空态，不做 project 详情 UI。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class WorkspaceProjectsPage extends ConsumerWidget {
  const WorkspaceProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = ref.watch(currentWorkspaceProvider);
    final wsId = ws?.id ?? '';
    if (wsId.isEmpty) {
      return WorkspaceEmptyView(
        icon: CupertinoIcons.folder,
        title: t.workspace.navProjects,
        subtitle: t.workspace.emptyNoWorkspace,
      );
    }
    final projects = ref.watch(workspaceProjectsProvider(wsId));
    return projects.when(
      loading: () => const WorkspaceLoadingView(),
      error: (e, _) => WorkspaceErrorView(
        message: workspaceErrorMessage(e),
        onRetry: () => ref.invalidate(workspaceProjectsProvider(wsId)),
      ),
      data: (list) => _ProjectList(wsId: wsId, items: list),
    );
  }
}

class _ProjectList extends StatelessWidget {
  final EntityId wsId;
  final List<WorkspaceProjectItem> items;

  const _ProjectList({required this.wsId, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty) {
      return WorkspaceEmptyView(
        icon: CupertinoIcons.folder,
        title: t.workspace.projectsEmptyTitle,
        subtitle: t.workspace.projectsEmptySubtitle,
      );
    }
    return ListView.separated(
      padding: AppSpacing.allRegular,
      itemCount: items.length,
      separatorBuilder: (_, _) => AppSpacing.verticalSmall,
      itemBuilder: (context, index) {
        final p = items[index];
        return Container(
          padding: AppSpacing.allRegular,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppSpacing.regular),
          ),
          child: Row(
            children: [
              const Icon(CupertinoIcons.folder, size: 28),
              AppSpacing.horizontalRegular,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (p.description.isNotEmpty) ...[
                      AppSpacing.verticalTiny,
                      Text(
                        p.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // WP6（T10a/T10b）落地 Project 详情/任务 UI 前，列表项只读展示
              const Icon(CupertinoIcons.chevron_right, size: 16),
            ],
          ),
        );
      },
    );
  }
}
