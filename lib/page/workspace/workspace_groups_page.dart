/// T9 (WP5) — Workspace Groups 视图（聊天唯一入口，§4.2 IA / I6）
///
/// 本账号已加入的 workspace 群列表（完整游标分页，scope 严格分区）；
/// 点进**复用现有群聊页面**（/chat/:groupId?type=C2G），不新建聊天 UI。
///
/// W05/F10：日常入口补齐——客户端搜索（关键词保留）、下拉主动刷新、
/// 创建入口（空态 CTA + 搜索行常驻按钮，指向真实工作区成员选择器
/// [WorkspaceGroupCreatePage]）。目录语义不变：仅展示本账号已加入的
/// 本工作区群，不伪称企业全部群（J14.a 准确空态，不越权补资源）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/helper/func.dart' show avatarImageProvider;
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/page/group/file/group_file_page.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_group_create_page.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class WorkspaceGroupsPage extends ConsumerWidget {
  const WorkspaceGroupsPage({
    super.key,
    this.openFiles = false,
    this.workspaceId,
  });

  final bool openFiles;

  final String? workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = ref.watch(currentWorkspaceProvider);
    final wsId = workspaceId ?? ws?.id ?? '';
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
      data: (list) => _GroupList(
        groups: list,
        openFiles: openFiles,
        onRefresh: () async {
          // 主动刷新：invalidate 后 await 新一次取数；失败由 error 分支
          // 呈现（J14.b：失败不显示成功空），搜索关键词由本页 state 保留。
          ref.invalidate(workspaceGroupsProvider(wsId));
          try {
            await ref.read(workspaceGroupsProvider(wsId).future);
          } catch (_) {
            /* watched provider 呈现失败态 */
          }
        },
        onCreateGroup: () => Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) => WorkspaceGroupCreatePage(workspaceId: wsId),
          ),
        ),
      ),
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

class _GroupList extends StatefulWidget {
  final List<GroupModel> groups;

  final bool openFiles;

  /// W05/F10：下拉主动刷新（由宿主提供 invalidate+await）。
  final Future<void> Function() onRefresh;

  /// W05/F10：创建入口（真实工作区成员选择器页）。
  final VoidCallback onCreateGroup;

  const _GroupList({
    required this.groups,
    required this.openFiles,
    required this.onRefresh,
    required this.onCreateGroup,
  });

  @override
  State<_GroupList> createState() => _GroupListState();
}

class _GroupListState extends State<_GroupList> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyword = _search.text.trim().toLowerCase();
    // 客户端过滤（目录已是本工作区已加入群全量）；关键词保留在 state，
    // 刷新不影响（J14.b）。
    final visible = keyword.isEmpty
        ? widget.groups
        : widget.groups
              .where((g) => g.displayTitle.toLowerCase().contains(keyword))
              .toList();
    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: widget.onRefresh),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.regular,
              AppSpacing.regular,
              AppSpacing.regular,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: CupertinoSearchTextField(
                    controller: _search,
                    placeholder: t.common.search,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                AppSpacing.horizontalSmall,
                // W05/F10：创建日常入口（常驻，不只在空态出现）。
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(34, 34),
                  onPressed: widget.onCreateGroup,
                  child: Icon(
                    CupertinoIcons.add_circled,
                    size: 28,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (visible.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: keyword.isNotEmpty
                ? WorkspaceEmptyView(
                    icon: CupertinoIcons.search,
                    title: t.common.searchNoResults,
                    subtitle: '',
                  )
                : WorkspaceEmptyView(
                    icon: CupertinoIcons.person_2,
                    title: t.workspace.groupsEmptyTitle,
                    subtitle: t.workspace.groupsEmptySubtitle,
                    // J14.a：准确空态给合法下一步（不越权补资源）。
                    actions: [
                      RoundedCupertinoButton(
                        text: t.organization.manage.createGroup,
                        highlighted: false,
                        icon: CupertinoIcons.person_2,
                        onPressed: widget.onCreateGroup,
                      ),
                    ],
                  ),
          )
        else
          SliverPadding(
            padding: AppSpacing.allRegular,
            sliver: SliverList.separated(
              itemCount: visible.length,
              separatorBuilder: (_, _) => AppSpacing.verticalSmall,
              itemBuilder: (context, index) {
                final g = visible[index];
                return _GroupTile(
                  group: g,
                  theme: theme,
                  openFiles: widget.openFiles,
                );
              },
            ),
          ),
      ],
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
