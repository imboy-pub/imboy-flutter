/// T8 (WP5) — Workspace 体验壳页面（§4.2 IA 唯一权威导航结构）
///
/// 结构：
/// - 顶栏（全局区）：工作区切换入口 + **全局 DM 入口**（复用现有会话列表
///   /conversation，DM 不进五项导航——§4.2 收敛决策 2）
/// - 内容区：五项导航 IndexedStack（Overview / Projects / Channels /
///   Groups / Members）
/// - 导航形态：移动端底部 NavigationBar / 桌面端 NavigationRail
///   （断点 900px，与 ChatShell / WebShell 一致）
/// - archived：顶部归档横幅（写操作禁用由各视图按状态自行落实）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/workspace_channels_page.dart';
import 'package:imboy/page/workspace/workspace_groups_page.dart';
import 'package:imboy/page/workspace/workspace_members_page.dart';
import 'package:imboy/page/workspace/workspace_overview_page.dart';
import 'package:imboy/page/workspace/workspace_projects_page.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_breakpoint.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_nav_items.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class WorkspaceShellPage extends ConsumerWidget {
  const WorkspaceShellPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final shell = ref.watch(workspaceShellProvider);
    final items = buildWorkspaceShellNavItems(
      overviewLabel: t.workspace.navOverview,
      projectsLabel: t.workspace.navProjects,
      channelsLabel: t.workspace.navChannels,
      groupsLabel: t.workspace.navGroups,
      membersLabel: t.workspace.navMembers,
    );
    final current = shell.current;
    final archived = current?.isArchived ?? false;
    final layout = resolveWorkspaceShellLayout(
      MediaQuery.sizeOf(context).width,
    );

    final body = Column(
      children: [
        // 移动端全局区（桌面端在侧栏 leading）：工作区切换 + DM 入口
        if (layout == WorkspaceShellLayout.mobile) const _ShellTopBar(),
        if (archived) const WorkspaceArchivedBanner(),
        Expanded(child: _DestinationStack(index: shell.destination.index)),
      ],
    );

    if (layout == WorkspaceShellLayout.desktop) {
      return Scaffold(
        body: Row(
          children: [
            _ShellRail(items: items, shell: shell),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: _ShellBottomNav(items: items, shell: shell),
    );
  }
}

/// 五项内容区（IndexedStack 保活各视图滚动位置；§4.2 权威顺序）。
class _DestinationStack extends StatelessWidget {
  final int index;

  const _DestinationStack({required this.index});

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      key: const ValueKey('workspace-shell-destination-stack'),
      index: index,
      children: const [
        WorkspaceOverviewPage(),
        WorkspaceProjectsPage(),
        WorkspaceChannelsPage(),
        WorkspaceGroupsPage(),
        WorkspaceMembersPage(),
      ],
    );
  }
}

/// 移动端全局区顶栏：当前工作区名（点击切换）+ DM 入口。
class _ShellTopBar extends ConsumerWidget {
  const _ShellTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final current = ref.watch(workspaceShellProvider.select((s) => s.current));
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: const ValueKey('workspace-shell-switcher'),
              onTap: () => context.push('/workspace'),
              child: Padding(
                padding: AppSpacing.allMedium,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        current?.name ?? t.workspace.pickerTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(Icons.unfold_more, size: 16),
                  ],
                ),
              ),
            ),
          ),
          // 全局 DM 入口（复用现有会话列表；DM 不进五项导航）
          IconButton(
            key: const ValueKey('workspace-shell-dm-entry'),
            tooltip: t.workspace.dmEntry,
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.push('/conversation'),
          ),
        ],
      ),
    );
  }
}

/// 桌面侧边导航栏（含全局区：工作区切换 + DM 入口）。
class _ShellRail extends ConsumerWidget {
  final List<WorkspaceShellNavItem> items;
  final WorkspaceShellState shell;

  const _ShellRail({required this.items, required this.shell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final current = shell.current;
    return NavigationRail(
      key: const ValueKey('workspace-shell-rail'),
      selectedIndex: shell.destination.index,
      onDestinationSelected: (i) => ref
          .read(workspaceShellProvider.notifier)
          .selectDestination(items[i].destination),
      leading: Column(
        children: [
          AppSpacing.verticalSmall,
          // 工作区切换入口
          IconButton(
            key: const ValueKey('workspace-shell-switcher'),
            tooltip: t.workspace.pickerTitle,
            icon: const Icon(Icons.dashboard_customize_outlined),
            onPressed: () => context.push('/workspace'),
          ),
          // 全局 DM 入口（复用现有会话列表；DM 不进五项导航）
          IconButton(
            key: const ValueKey('workspace-shell-dm-entry'),
            tooltip: t.workspace.dmEntry,
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.push('/conversation'),
          ),
          if (current != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
              child: Text(
                current.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
      destinations: [
        for (final item in items)
          NavigationRailDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.activeIcon),
            label: Text(item.label),
          ),
      ],
    );
  }
}

/// 移动端底部导航（五项）。
class _ShellBottomNav extends ConsumerWidget {
  final List<WorkspaceShellNavItem> items;
  final WorkspaceShellState shell;

  const _ShellBottomNav({required this.items, required this.shell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NavigationBar(
      key: const ValueKey('workspace-shell-bottom-nav'),
      selectedIndex: shell.destination.index,
      onDestinationSelected: (i) => ref
          .read(workspaceShellProvider.notifier)
          .selectDestination(items[i].destination),
      destinations: [
        for (final item in items)
          NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.activeIcon),
            label: item.label,
          ),
      ],
    );
  }
}
