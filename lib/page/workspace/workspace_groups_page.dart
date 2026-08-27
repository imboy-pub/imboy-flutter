/// T9 (WP5) — Workspace Groups 视图（聊天唯一入口，§4.2 IA / I6）
///
/// workspace group 列表（GET /workspaces/:id/groups，scope 严格分区）；
/// 点进**复用现有群聊页面**（/chat/:groupId?type=C2G），不新建聊天 UI。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class WorkspaceGroupsPage extends ConsumerWidget {
  const WorkspaceGroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = ref.watch(currentWorkspaceProvider);
    final wsId = ws?.id ?? '';
    if (wsId.isEmpty) {
      return WorkspaceEmptyView(
        icon: CupertinoIcons.person_2,
        title: t.workspace.navGroups,
        subtitle: t.workspace.emptyNoWorkspace,
      );
    }
    final groups = ref.watch(workspaceGroupsProvider(wsId));
    return groups.when(
      loading: () => const WorkspaceLoadingView(),
      error: (e, _) => WorkspaceErrorView(
        message: workspaceErrorMessage(e),
        onRetry: () => ref.invalidate(workspaceGroupsProvider(wsId)),
      ),
      data: (list) => _GroupList(groups: list),
    );
  }
}

class _GroupList extends StatelessWidget {
  final List<GroupModel> groups;

  const _GroupList({required this.groups});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (groups.isEmpty) {
      return WorkspaceEmptyView(
        icon: CupertinoIcons.person_2,
        title: t.workspace.groupsEmptyTitle,
        subtitle: t.workspace.groupsEmptySubtitle,
      );
    }
    return ListView.separated(
      padding: AppSpacing.allRegular,
      itemCount: groups.length,
      separatorBuilder: (_, _) => AppSpacing.verticalSmall,
      itemBuilder: (context, index) {
        final g = groups[index];
        return _GroupTile(group: g, theme: theme);
      },
    );
  }
}

class _GroupTile extends StatelessWidget {
  final GroupModel group;
  final ThemeData theme;

  const _GroupTile({required this.group, required this.theme});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('workspace-group-tile-${group.groupId}'),
      borderRadius: BorderRadius.circular(AppSpacing.regular),
      // 复用现有群聊页面：与 group_detail / mention_list 同款 /chat 路由
      onTap: () => context.push(
        '/chat/${group.groupId}',
        extra: {
          'type': 'C2G',
          'title': group.displayTitle,
          'avatar': group.avatar,
        },
      ),
      child: Container(
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
              backgroundImage: group.avatar.isNotEmpty
                  ? NetworkImage(group.avatar)
                  : null,
              child: group.avatar.isEmpty
                  ? Icon(
                      CupertinoIcons.person_2,
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
                  Text(
                    group.displayTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AppSpacing.verticalTiny,
                  Text(
                    t.workspace.groupTileSubtitle(
                      count: group.memberCount.toString(),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Group = Discuss（聊天唯一入口）
            const Icon(CupertinoIcons.chat_bubble, size: 18),
          ],
        ),
      ),
    );
  }
}
