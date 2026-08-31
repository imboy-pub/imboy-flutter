/// T8 (WP5) — Workspace 体验壳页面（§4.2 IA 唯一权威导航结构）
///
/// 结构（2026-08-31 UX 收敛三轮：头像左置 + 标题居中）：
/// - 顶栏（仅移动端且非会话目的地）：左 = 头像菜单，中 = 当前页面标题
///   （右侧等宽占位保持真居中），右 = 预留动作位；
///   workspace 切换退出顶栏（收进账户 Sheet 工作区列表 + 概览页工作区卡片）
/// - 会话目的地：ConversationPage 自带标题栏（头像经 leading 挂左上、
///   右上保留发起聊天"＋"），壳顶栏不叠加
/// - 内容区：五项导航 IndexedStack（Conversations / Overview / Channels /
///   Groups / Projects；DM 进一级导航排第一）
/// - 导航形态：移动端底部 NavigationBar / 桌面端 NavigationRail
///   （断点 900px，与 ChatShell / WebShell 一致；桌面 rail 顶部保留
///   工作区切换图标——桌面侧栏顶部是切换器的行业惯例位）
/// - archived：顶部归档横幅（写操作禁用由各视图按状态自行落实）
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/conversation/conversation_page.dart';
import 'package:imboy/page/workspace/workspace_channels_page.dart';
import 'package:imboy/page/workspace/workspace_groups_page.dart';
import 'package:imboy/page/workspace/workspace_overview_page.dart';
import 'package:imboy/page/workspace/workspace_projects_page.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/page/workspace_shell/workspace_account_menu.dart';
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
      conversationsLabel: t.chat.titleMessage,
      overviewLabel: t.workspace.navOverview,
      channelsLabel: t.workspace.navChannels,
      groupsLabel: t.workspace.navGroups,
      projectsLabel: t.workspace.navProjects,
    );
    final current = shell.current;
    final archived = current?.isArchived ?? false;
    final layout = resolveWorkspaceShellLayout(
      MediaQuery.sizeOf(context).width,
    );

    final body = Column(
      children: [
        // 移动端全局区：工作区切换 + 头像菜单（会话目的地自带标题栏，
        // 不叠加壳顶栏）
        if (layout == WorkspaceShellLayout.mobile &&
            shell.destination != WorkspaceShellDestination.conversations)
          const _ShellTopBar(),
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

/// 五项内容区（IndexedStack 保活各视图滚动位置；顺序 = 枚举声明顺序）。
/// 会话页左上角挂账户头像（T1 二轮：头像左侧 + 标题居中，YouTube /
/// Apple Music 布局；右上保留发起聊天"＋"）。
class _DestinationStack extends StatelessWidget {
  final int index;

  const _DestinationStack({required this.index});

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      key: const ValueKey('workspace-shell-destination-stack'),
      index: index,
      children: const [
        ConversationPage(leading: WorkspaceAccountButton()),
        WorkspaceOverviewPage(),
        WorkspaceChannelsPage(),
        WorkspaceGroupsPage(),
        WorkspaceProjectsPage(),
      ],
    );
  }
}

/// 顶栏左右锚区宽度（与 IconButton 最小可点域对齐，保证标题视觉居中）。
const double _kTopBarAnchorWidth = 56;

/// 移动端全局区顶栏（T1 页面标题制·头像左置）：左 = 头像菜单，
/// 中 = 当前页面标题（真居中：右侧等宽占位），右 = 预留动作位。
/// 会话目的地不渲染（ConversationPage 自带标题栏，头像经 leading 挂入）。
class _ShellTopBar extends ConsumerWidget {
  const _ShellTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final destination = ref.watch(
      workspaceShellProvider.select((s) => s.destination),
    );
    // 本壳 Scaffold 无 appBar：不包 SafeArea 顶栏会直顶屏幕上沿，
    // 左上角头像按钮落进 iOS 状态栏/刘海区域，视觉被压且点不到
    return SafeArea(
      top: true,
      bottom: false,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: Row(
          children: [
            const SizedBox(
              width: _kTopBarAnchorWidth,
              child: Center(child: WorkspaceAccountButton()),
            ),
            Expanded(
              child: Center(
                child: Text(
                  workspaceShellDestinationTitle(t, destination),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: _kTopBarAnchorWidth),
          ],
        ),
      ),
    );
  }
}

/// 桌面侧边导航栏：顶部工作区切换，底部头像菜单（低频入口沉底）。
class _ShellRail extends ConsumerWidget {
  final List<WorkspaceShellNavItem> items;
  final WorkspaceShellState shell;

  const _ShellRail({required this.items, required this.shell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final current = shell.current;
    return Column(
      children: [
        Expanded(
          child: NavigationRail(
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
                  icon: const Icon(CupertinoIcons.square_grid_2x2),
                  onPressed: () => context.push('/workspace'),
                ),
                if (current != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.small,
                    ),
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
          ),
        ),
        // 账户菜单沉底（设置/退出等低频入口收口）
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.small),
            child: const WorkspaceAccountButton(),
          ),
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
