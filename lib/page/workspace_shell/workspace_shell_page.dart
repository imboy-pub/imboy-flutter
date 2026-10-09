/// T8 (WP5) — Workspace 体验壳页面（§4.2 IA 唯一权威导航结构）
///
/// 结构（2026-08-31 UX 收敛四轮：左上工作区 chip 常驻 + 右上账户归位）：
/// - 顶栏（仅移动端且非会话目的地）：左 = 工作区切换 chip（恢复切换入口
///   可见性），中 = 当前页面标题（居中），右 = 头像菜单；
///   Slack / Notion 惯例：左上工作区上下文、右上账户
/// - 会话目的地：WorkspaceConversationsPage 自带标题栏（左上 = 切换 chip、
///   右上 = 头像，搜索在本工作区列表内），壳顶栏不叠加
/// - 内容区：五项导航 IndexedStack（Conversations / Overview / Channels /
///   Groups / Projects；工作区群会话排第一）
/// - 导航形态：移动端底部 NavigationBar / 桌面端 NavigationRail
///   （断点 900px，与 ChatShell / WebShell 一致；桌面 rail 顶部保留
///   工作区切换图标——桌面侧栏顶部是切换器的行业惯例位）
/// - archived：顶部归档横幅（写操作禁用由各视图按状态自行落实）
library;

import 'package:imboy/app_core/feature_flags/feature_revision_provider.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/workspace_conversations_page.dart';
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
import 'package:imboy/store/repository/user_repo_provider.dart';

import 'enterprise_shell_page.dart';

class WorkspaceShellPage extends ConsumerWidget {
  const WorkspaceShellPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(featureRevisionProvider);
    final t = context.t;
    final shell = ref.watch(workspaceShellProvider);
    final uid = ref.watch(currentUserProvider)?.uid ?? '';
    if (uid.isNotEmpty &&
        shell.organizationId.isNotEmpty &&
        (shell.current == null ||
            shell.current!.belongsToOrg(shell.organizationId))) {
      return EnterpriseShellPage(
        key: ValueKey((uid, shell.organizationId, shell.currentWorkspaceId)),
        accountKey: uid,
        organizationId: shell.organizationId,
      );
    }
    final items = buildWorkspaceShellNavItems(
      conversationsLabel: t.chat.groupChat,
      overviewLabel: t.workspace.navOverview,
      channelsLabel: t.workspace.navChannels,
      groupsLabel: t.workspace.navGroups,
      projectsLabel: t.workspace.navProjects,
    );
    // 计划 §5.3：project 关闭时「项目」不进导航（正常入口关闭），
    // 直达 route 由 RouteFeatureGuard 按同一个 feature 键拦截。
    final projectEnabled = AppFeatureRegistry.isEnabled(FeatureKeys.project);
    final visibleItems = projectEnabled
        ? items
        : items
              .where((i) => i.destination != WorkspaceShellDestination.projects)
              .toList(growable: false);
    // 上一刻已选中「项目」而功能刚被关闭：回落到消息页。否则内容区会停在
    // 项目页，且 selectedIndex 会越出可见导航项范围（导航栏越界即崩）。
    final effectiveDestination =
        visibleItems.any((i) => i.destination == shell.destination)
        ? shell.destination
        : WorkspaceShellDestination.conversations;
    final selectedIndex = visibleItems.indexWhere(
      (i) => i.destination == effectiveDestination,
    );
    final current = shell.current;
    final archived = current?.isArchived ?? false;
    final layout = resolveWorkspaceShellLayout(
      MediaQuery.sizeOf(context).width,
    );

    final body = Column(
      children: [
        // 移动端全局区：左上工作区切换 chip + 右上头像菜单（会话目的地
        // 自带导航栏且已含 chip/头像，不叠加壳顶栏）
        if (layout == WorkspaceShellLayout.mobile &&
            effectiveDestination != WorkspaceShellDestination.conversations)
          const _ShellTopBar(),
        if (archived) const WorkspaceArchivedBanner(),
        Expanded(child: _DestinationStack(index: effectiveDestination.index)),
      ],
    );

    if (layout == WorkspaceShellLayout.desktop) {
      return Scaffold(
        body: Row(
          children: [
            _ShellRail(
              items: visibleItems,
              shell: shell,
              selectedIndex: selectedIndex,
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: _ShellBottomNav(
        items: visibleItems,
        shell: shell,
        selectedIndex: selectedIndex,
      ),
    );
  }
}

/// 五项内容区（IndexedStack 保活各视图滚动位置；顺序 = 枚举声明顺序）。
/// 会话页导航栏：左上 = 工作区切换 chip（切换入口全页常驻可见），
/// 右上 = 头像，搜索在本工作区列表内。
class _DestinationStack extends StatelessWidget {
  final int index;

  const _DestinationStack({required this.index});

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      key: const ValueKey('workspace-shell-destination-stack'),
      index: index,
      children: [
        const WorkspaceConversationsPage(),
        const WorkspaceOverviewPage(),
        const WorkspaceChannelsPage(),
        const WorkspaceGroupsPage(),
        const WorkspaceProjectsPage(),
      ],
    );
  }
}

/// 移动端全局区顶栏（仅非会话目的地渲染）：左 = 工作区切换 chip，
/// 中 = 当前页面标题（居中），右 = 头像菜单。Slack / Notion 惯例布局：
/// 左上 = 工作区上下文，右上 = 账户入口。
class _ShellTopBar extends ConsumerWidget {
  const _ShellTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(featureRevisionProvider);
    final t = context.t;
    final destination = ref.watch(
      workspaceShellProvider.select((s) => s.destination),
    );
    // 本壳 Scaffold 无 appBar：不包 SafeArea 顶栏会直顶屏幕上沿
    return SafeArea(
      top: true,
      bottom: false,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.small),
              child: const WorkspaceSwitcherChip(),
            ),
            Expanded(
              child: Center(
                child: Text(
                  workspaceShellDestinationTitle(t, destination),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Padding(
              // 头像 44px 按钮盒自带 8px 内缩：外层只留 4px，图标观感
              // 与消息页导航栏（trailing 零边距 + 11px 内缩）对齐
              padding: const EdgeInsets.only(right: AppSpacing.tiny),
              child: const WorkspaceAccountButton(),
            ),
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

  /// 可见导航项内的高亮下标（≠ shell.destination.index：项目关闭时
  /// 可见项少了「项目」，直接用枚举序号会越界）
  final int selectedIndex;

  const _ShellRail({
    required this.items,
    required this.shell,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(featureRevisionProvider);
    final t = context.t;
    final current = shell.current;
    return Column(
      children: [
        Expanded(
          child: NavigationRail(
            key: const ValueKey('workspace-shell-rail'),
            selectedIndex: selectedIndex,
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

  /// 可见导航项内的高亮下标（同 _ShellRail 的说明）
  final int selectedIndex;

  const _ShellBottomNav({
    required this.items,
    required this.shell,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(featureRevisionProvider);
    return NavigationBar(
      key: const ValueKey('workspace-shell-bottom-nav'),
      selectedIndex: selectedIndex,
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
