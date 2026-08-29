/// W2 (ZC-04/ZC-06) — 项目内容聚合页（四聚合：Pinned/Resources/Activity/
/// Related Posts）
///
/// 每个 Tab 独立三态（加载/空/错误齐全）；403 越权给明确无权限态；
/// pinned/activity 分页（size 10 + 加载更多，多页聚合模式与 W0 列表页
/// 一致），resources/related_posts 为后端有界数组直出（单页展示）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/model/project_w2_model.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/page/workspace/project/w2/project_w2_providers.dart';
import 'package:imboy/page/workspace/project/w2/project_w2_view_widgets.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class ProjectInsightsPage extends ConsumerWidget {
  final EntityId projectId;
  final EntityId workspaceId;

  const ProjectInsightsPage({
    super.key,
    required this.projectId,
    this.workspaceId = '',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.workspace.projectInsightsEntry),
          bottom: TabBar(
            tabs: [
              Tab(
                key: const ValueKey('project-insights-tab-pinned'),
                text: t.workspace.projectInsightsTabPinned,
              ),
              Tab(
                key: const ValueKey('project-insights-tab-resources'),
                text: t.workspace.projectInsightsTabResources,
              ),
              Tab(
                key: const ValueKey('project-insights-tab-activity'),
                text: t.workspace.projectInsightsTabActivity,
              ),
              Tab(
                key: const ValueKey('project-insights-tab-posts'),
                text: t.workspace.projectInsightsTabPosts,
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PinnedTab(projectId: projectId),
            _ResourcesTab(projectId: projectId),
            _ActivityTab(projectId: projectId),
            _PostsTab(projectId: projectId),
          ],
        ),
      ),
    );
  }
}

/// Tab 三态通用骨架：loading → 加载态；403 → 无权限态；其余 error →
/// 错误态；空列表 → 空态；否则渲染 [items]。
Widget _tabBody(
  BuildContext context, {
  required bool loading,
  required Object? error,
  required int itemCount,
  required VoidCallback onRetry,
  required String emptyTitle,
  required String emptySubtitle,
  required List<Widget> items,
}) {
  if (loading && itemCount == 0) {
    return const WorkspaceLoadingView();
  }
  if (error != null && itemCount == 0) {
    if (isProjectForbiddenError(error)) {
      return ProjectForbiddenView(onRetry: onRetry);
    }
    return WorkspaceErrorView(
      message: projectW2ViewMessage(context, error),
      onRetry: onRetry,
    );
  }
  if (itemCount == 0) {
    return WorkspaceEmptyView(
      icon: CupertinoIcons.doc_text_search,
      title: emptyTitle,
      subtitle: emptySubtitle,
    );
  }
  return RefreshIndicator(
    onRefresh: () async => onRetry(),
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.allRegular,
      children: [
        ...items,
        if (loading)
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

/// Pinned 聚合（分页多页聚合；页数据独立缓存）。
class _PinnedTab extends ConsumerStatefulWidget {
  final EntityId projectId;

  const _PinnedTab({required this.projectId});

  @override
  ConsumerState<_PinnedTab> createState() => _PinnedTabState();
}

class _PinnedTabState extends ConsumerState<_PinnedTab> {
  int _pages = 1;

  @override
  Widget build(BuildContext context) {
    final pageAsyncs = <AsyncValue<WorkspacePageResult<AggPostModel>>>[
      for (var p = 1; p <= _pages; p++)
        ref.watch(projectPinnedPageProvider((widget.projectId, p))),
    ];
    final firstError = pageAsyncs
        .where((a) => a.hasError)
        .map((a) => a.error)
        .firstOrNull;
    final posts = [for (final a in pageAsyncs) ...?a.value?.list];
    final totalPage = pageAsyncs.lastOrNull?.value?.totalPage ?? 0;
    return _tabBody(
      context,
      loading: pageAsyncs.any((a) => a.isLoading),
      error: firstError,
      itemCount: posts.length,
      onRetry: () =>
          ref.invalidate(projectPinnedPageProvider((widget.projectId, 1))),
      emptyTitle: t.workspace.projectInsightsPinnedEmpty,
      emptySubtitle: t.workspace.projectChannelEmptySubtitle,
      items: [
        for (final post in posts) _PostTile(post: post),
        if (!pageAsyncs.any((a) => a.isLoading) &&
            firstError == null &&
            totalPage > _pages)
          ProjectW2LoadMoreButton(onPressed: () => setState(() => _pages += 1)),
      ],
    );
  }
}

/// Resources 聚合（project.links 有界数组直出，单页）。
class _ResourcesTab extends ConsumerWidget {
  final EntityId projectId;

  const _ResourcesTab({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final async = ref.watch(projectResourcesProvider(projectId));
    final links = async.value?.list ?? const <ProjectLinkModel>[];
    return _tabBody(
      context,
      loading: async.isLoading,
      error: async.hasError ? async.error : null,
      itemCount: links.length,
      onRetry: () => ref.invalidate(projectResourcesProvider(projectId)),
      emptyTitle: t.workspace.projectInsightsResourcesEmpty,
      emptySubtitle: t.workspace.projectChannelEmptySubtitle,
      items: [for (final link in links) _LinkTile(link: link)],
    );
  }
}

/// Activity 聚合（project_event 元数据流；分页多页聚合）。
class _ActivityTab extends ConsumerStatefulWidget {
  final EntityId projectId;

  const _ActivityTab({required this.projectId});

  @override
  ConsumerState<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends ConsumerState<_ActivityTab> {
  int _pages = 1;

  @override
  Widget build(BuildContext context) {
    final pageAsyncs = <AsyncValue<WorkspacePageResult<ActivityEventModel>>>[
      for (var p = 1; p <= _pages; p++)
        ref.watch(projectActivityPageProvider((widget.projectId, p))),
    ];
    final firstError = pageAsyncs
        .where((a) => a.hasError)
        .map((a) => a.error)
        .firstOrNull;
    final events = [for (final a in pageAsyncs) ...?a.value?.list];
    final totalPage = pageAsyncs.lastOrNull?.value?.totalPage ?? 0;
    return _tabBody(
      context,
      loading: pageAsyncs.any((a) => a.isLoading),
      error: firstError,
      itemCount: events.length,
      onRetry: () =>
          ref.invalidate(projectActivityPageProvider((widget.projectId, 1))),
      emptyTitle: t.workspace.projectInsightsActivityEmpty,
      emptySubtitle: t.workspace.projectChannelEmptySubtitle,
      items: [
        for (final event in events) _EventTile(event: event),
        if (!pageAsyncs.any((a) => a.isLoading) &&
            firstError == null &&
            totalPage > _pages)
          ProjectW2LoadMoreButton(onPressed: () => setState(() => _pages += 1)),
      ],
    );
  }
}

/// Related Posts 聚合（有界摘要，单页）。
class _PostsTab extends ConsumerWidget {
  final EntityId projectId;

  const _PostsTab({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final async = ref.watch(projectRelatedPostsProvider(projectId));
    final posts = async.value?.list ?? const <AggPostModel>[];
    return _tabBody(
      context,
      loading: async.isLoading,
      error: async.hasError ? async.error : null,
      itemCount: posts.length,
      onRetry: () => ref.invalidate(projectRelatedPostsProvider(projectId)),
      emptyTitle: t.workspace.projectInsightsPostsEmpty,
      emptySubtitle: t.workspace.projectChannelEmptySubtitle,
      items: [for (final post in posts) _PostTile(post: post)],
    );
  }
}

/// 置顶消息 / 相关帖子摘要行（元数据：作者 + 时间；无正文）。
class _PostTile extends StatelessWidget {
  final AggPostModel post;

  const _PostTile({required this.post});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final author = post.authorName.isNotEmpty
        ? t.workspace.projectInsightsPostAuthor(name: post.authorName)
        : post.msgType;
    return Container(
      key: ValueKey('project-insights-post-${post.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      padding: AppSpacing.allRegular,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.regular),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.pin, size: 18),
          AppSpacing.horizontalRegular,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  author.isEmpty ? post.msgType : author,
                  style: theme.textTheme.titleSmall,
                ),
                if (post.createdAtText.isNotEmpty)
                  Text(
                    post.createdAtText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 资源链接行（name + url；url 文本只读展示）。
class _LinkTile extends StatelessWidget {
  final ProjectLinkModel link;

  const _LinkTile({required this.link});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: ValueKey('project-insights-link-${link.url}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      padding: AppSpacing.allRegular,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.regular),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(link.name, style: theme.textTheme.titleSmall),
          if (link.url.isNotEmpty)
            Text(
              link.url,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// 项目动态事件行（event_type + 时间；payload 元数据不展开）。
class _EventTile extends StatelessWidget {
  final ActivityEventModel event;

  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: ValueKey('project-insights-event-${event.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      padding: AppSpacing.allRegular,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.regular),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.time, size: 18),
          AppSpacing.horizontalRegular,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.eventType, style: theme.textTheme.titleSmall),
                if (event.createdAtText.isNotEmpty)
                  Text(
                    event.createdAtText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
