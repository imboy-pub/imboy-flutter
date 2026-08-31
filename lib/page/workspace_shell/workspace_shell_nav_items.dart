/// T8 (WP5) — Workspace 壳导航项声明层（i18n 与 widget 解耦的纯函数层）
///
/// 镜像 `chat_shell_nav_items.dart`：导航目的地固定为五项：
///
/// ```text
/// Conversations / Overview / Channels / Groups / Projects
/// ```
///
/// 频率分层（UX 收敛，2026-08-31）：
/// - Conversations（全局 DM）是最高频的用户级能力，进一级导航且排第一
///   （此前挂在壳顶栏小图标上，频率错位）
/// - Members 退出导航：治理低频，入口收敛进 Overview「工作区成员」卡片
///   「查看全部」，页面标题与说明仍用「工作区成员」全称（跨域术语约束）
/// - 设置退出全局区：收进顶栏/侧栏底部头像菜单（镜像 Slack 用户菜单）
///
/// 其他收敛决策（§4.2，防"什么都塞进左侧导航"）：
/// - Files 不做一级导航（聚合能力，入口在 Overview「最近文件」区块）
library;

import 'package:flutter/cupertino.dart';

import 'package:imboy/i18n/strings.g.dart';

/// Workspace 体验导航目的地（顺序 = 底部导航/侧栏展示顺序）。
enum WorkspaceShellDestination {
  /// 会话列表（全局 DM，用户级高频能力；复用 ChatShell 的 ConversationPage）
  conversations,

  /// 导航枢纽：资源摘要 + Channel 置顶内容 + 最近文件 + 成员预览
  overview,

  /// scope=workspace 的频道（内容在这里；含 Announcements）
  channels,

  /// scope=workspace 的群（聊天唯一入口，I6）
  groups,

  /// Project 列表入口（详情/任务 UI 属 WP6）
  projects,
}

/// Workspace Shell 导航项总数（5 项）。
const int kWorkspaceShellDestinationCount = 5;

/// 单个导航项数据载体（不可变，镜像 `ChatShellNavItem`）。
class WorkspaceShellNavItem {
  final WorkspaceShellDestination destination;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const WorkspaceShellNavItem({
    required this.destination,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkspaceShellNavItem &&
          other.destination == destination &&
          other.icon == icon &&
          other.activeIcon == activeIcon &&
          other.label == label;

  @override
  int get hashCode => Object.hash(destination, icon, activeIcon, label);
}

/// 目的地 → 页面标题（T1 页面标题制顶栏消费；与导航 label 同源）。
String workspaceShellDestinationTitle(
  Translations t,
  WorkspaceShellDestination destination,
) {
  return switch (destination) {
    WorkspaceShellDestination.conversations => t.chat.titleMessage,
    WorkspaceShellDestination.overview => t.workspace.navOverview,
    WorkspaceShellDestination.channels => t.workspace.navChannels,
    WorkspaceShellDestination.groups => t.workspace.navGroups,
    WorkspaceShellDestination.projects => t.workspace.navProjects,
  };
}

/// 构造 Workspace Shell 导航项列表（顺序固定 = 频率分层顺序）。
///
/// 图标沿用 Cupertino 系（与 ChatShell / BottomNavigationPage 同源）：
/// - Conversations：气泡 chat_bubble（与 chat 壳会话项同图标）
/// - Overview：仪表盘 dashboard
/// - Channels：电波 antenna（与 chat 壳频道项同图标）
/// - Groups：双人 person_2（群聊 = 人与人讨论）
/// - Projects：文件夹 folder
List<WorkspaceShellNavItem> buildWorkspaceShellNavItems({
  required String conversationsLabel,
  required String overviewLabel,
  required String channelsLabel,
  required String groupsLabel,
  required String projectsLabel,
}) {
  return [
    WorkspaceShellNavItem(
      destination: WorkspaceShellDestination.conversations,
      icon: CupertinoIcons.chat_bubble,
      activeIcon: CupertinoIcons.chat_bubble_fill,
      label: conversationsLabel,
    ),
    WorkspaceShellNavItem(
      destination: WorkspaceShellDestination.overview,
      icon: CupertinoIcons.chart_bar_alt_fill,
      activeIcon: CupertinoIcons.chart_bar_alt_fill,
      label: overviewLabel,
    ),
    WorkspaceShellNavItem(
      destination: WorkspaceShellDestination.channels,
      icon: CupertinoIcons.antenna_radiowaves_left_right,
      activeIcon: CupertinoIcons.antenna_radiowaves_left_right,
      label: channelsLabel,
    ),
    WorkspaceShellNavItem(
      destination: WorkspaceShellDestination.groups,
      icon: CupertinoIcons.person_2,
      activeIcon: CupertinoIcons.person_2_fill,
      label: groupsLabel,
    ),
    WorkspaceShellNavItem(
      destination: WorkspaceShellDestination.projects,
      icon: CupertinoIcons.folder,
      activeIcon: CupertinoIcons.folder_fill,
      label: projectsLabel,
    ),
  ];
}
