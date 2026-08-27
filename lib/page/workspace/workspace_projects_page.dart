/// T9 (WP5) → T10a (WP6) — Projects 完整列表页
///
/// T10a 升级点（原 T9 只留只读入口）：分页聚合加载、下拉刷新、创建项目
/// 入口、点击进入项目详情（任务区块见 project/tasks/）；空态保留并可下拉。
///
/// W0 权限模型：当前用户可访问的项目即集合 API 结果（全部 active 工作区
/// 成员可见，服务端做边界校验）；Guest / archived 的写入口禁用（服务端
/// 403/980 兜底）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/project_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart'
    show
        WorkspaceEmptyView,
        WorkspaceErrorView,
        WorkspaceLoadingView,
        workspaceErrorMessage;
import 'package:imboy/page/workspace/project/project_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class WorkspaceProjectsPage extends ConsumerStatefulWidget {
  const WorkspaceProjectsPage({super.key});

  @override
  ConsumerState<WorkspaceProjectsPage> createState() =>
      _WorkspaceProjectsPageState();
}

class _WorkspaceProjectsPageState extends ConsumerState<WorkspaceProjectsPage> {
  int _pages = 1;

  Future<void> _refresh(EntityId wsId) async {
    ref.invalidate(projectListPageProvider((wsId, 1)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final ws = ref.watch(currentWorkspaceProvider);
    final wsId = ws?.id ?? '';
    if (wsId.isEmpty) {
      return WorkspaceEmptyView(
        icon: CupertinoIcons.folder,
        title: t.workspace.navProjects,
        subtitle: t.workspace.emptyNoWorkspace,
      );
    }
    final archived = ws?.isArchived ?? false;

    // 聚合已加载各页：任一 loading 驱动加载指示；第一处 error 且无任何
    // 已成页时给整页错误态；最后一页 totalPage 决定是否还有下一页。
    final pageAsyncs = <AsyncValue<WorkspacePageResult<ProjectModel>>>[
      for (var p = 1; p <= _pages; p++)
        ref.watch(projectListPageProvider((wsId, p))),
    ];
    final hasLoading = pageAsyncs.any((a) => a.isLoading);
    final firstError = pageAsyncs
        .where((a) => a.hasError)
        .map((a) => a.error)
        .firstOrNull;
    final loadedPages = <WorkspacePageResult<ProjectModel>>[
      for (final a in pageAsyncs) ?a.value,
    ];

    Widget body;
    if (firstError != null && loadedPages.isEmpty) {
      body = WorkspaceErrorView(
        message: workspaceErrorMessage(firstError),
        onRetry: () => ref.invalidate(projectListPageProvider((wsId, 1))),
      );
    } else if (hasLoading && loadedPages.isEmpty) {
      body = const WorkspaceLoadingView();
    } else {
      final items = [for (final pg in loadedPages) ...pg.list];
      final totalPage = loadedPages.isEmpty ? 1 : loadedPages.last.totalPage;
      body = CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: () => _refresh(wsId)),
          SliverToBoxAdapter(
            child: _CreateEntry(wsId: wsId, archived: archived),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
            sliver: items.isEmpty
                ? SliverToBoxAdapter(
                    child: WorkspaceEmptyView(
                      icon: CupertinoIcons.folder,
                      title: t.workspace.projectsEmptyTitle,
                      subtitle: t.workspace.projectsEmptySubtitle,
                    ),
                  )
                : SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => AppSpacing.verticalSmall,
                    itemBuilder: (context, index) => _ProjectCard(
                      project: items[index],
                      onTap: () => context.push(
                        '/workspace/$wsId/projects/${items[index].id}',
                      ),
                    ),
                  ),
          ),
          if (!hasLoading && loadedPages.isNotEmpty && totalPage > _pages)
            SliverToBoxAdapter(
              child: Center(
                child: TextButton(
                  key: const ValueKey('workspace-projects-load-more'),
                  onPressed: () => setState(() => _pages += 1),
                  child: Text(t.workspace.projectsLoadMore),
                ),
              ),
            ),
          if (hasLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.regular),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
        ],
      );
    }
    return Scaffold(backgroundColor: Colors.transparent, body: body);
  }
}

class _CreateEntry extends StatelessWidget {
  final EntityId wsId;
  final bool archived;

  const _CreateEntry({required this.wsId, required this.archived});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.regular,
        AppSpacing.small,
        AppSpacing.regular,
        AppSpacing.small,
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              key: const ValueKey('workspace-project-create-entry'),
              // archived：写操作禁用（服务端 980 兜底）
              onPressed: archived
                  ? null
                  : () => context.push('/workspace/$wsId/projects/create'),
              icon: const Icon(CupertinoIcons.add, size: 18),
              label: Text(t.workspace.projectCreateEntry),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final VoidCallback onTap;

  const _ProjectCard({required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = project.status == ProjectStatus.done;
    return Container(
      key: ValueKey('workspace-project-card-${project.id}'),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.regular),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.regular,
            vertical: AppSpacing.tiny,
          ),
          leading: Icon(
            done ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.folder,
            size: 28,
            color: done ? AppColors.success : theme.colorScheme.primary,
          ),
          title: Text(
            project.name,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: project.description.isEmpty
              ? null
              : Text(
                  project.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
          trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
          onTap: onTap,
        ),
      ),
    );
  }
}
