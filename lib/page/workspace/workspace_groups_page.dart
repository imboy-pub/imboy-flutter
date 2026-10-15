/// T9 (WP5) — Workspace Groups 视图（聊天唯一入口，§4.2 IA / I6）
///
/// 本账号已加入的 workspace 群列表（完整游标分页，scope 严格分区）；
/// 点进**复用现有群聊页面**（/chat/:groupId?type=C2G），不新建聊天 UI。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/helper/func.dart' show avatarImageProvider;
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/page/group/file/group_file_page.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class WorkspaceGroupsPage extends ConsumerWidget {
  const WorkspaceGroupsPage({super.key, this.openFiles = false});

  final bool openFiles;

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
      data: (list) => _GroupList(groups: list, openFiles: openFiles),
    );
  }
}

/// 独立推入形态：嵌入式 [WorkspaceGroupsPage] 无自带 Scaffold（容器由壳
/// Tab 提供），从消息空态 CTA 等入口推入时经本页用 IosPageTemplate 承载。
/// 数据语义仍是"本账号已加入的本工作区群"（scope=workspace 创建后不可
/// 变），不跨域到个人模式的平台公开群发现页。
class WorkspaceGroupsStandalonePage extends ConsumerWidget {
  const WorkspaceGroupsStandalonePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IosPageTemplate(
      title: t.workspace.navGroups,
      body: const WorkspaceGroupsPage(),
    );
  }
}

class _GroupList extends StatelessWidget {
  final List<GroupModel> groups;

  final bool openFiles;

  const _GroupList({required this.groups, required this.openFiles});

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
        return _GroupTile(group: g, theme: theme, openFiles: openFiles);
      },
    );
  }
}

class _GroupTile extends StatelessWidget {
  final GroupModel group;
  final ThemeData theme;

  final bool openFiles;

  const _GroupTile({
    required this.group,
    required this.theme,
    required this.openFiles,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('workspace-group-tile-${group.groupId}'),
      borderRadius: BorderRadius.circular(AppSpacing.regular),
      // 复用现有群聊页面：与 group_detail / mention_list 同款 /chat 路由
      onTap: () => openFiles
          ? Navigator.of(context).push(
              CupertinoPageRoute<void>(
                builder: (_) =>
                    GroupFilePage(groupId: group.groupId.toString()),
              ),
            )
          : context.push(
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
                  ? avatarImageProvider(group.avatar)
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
