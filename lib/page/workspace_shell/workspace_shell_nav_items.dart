/// T8 (WP5) — Workspace 壳导航项声明层（i18n 与 widget 解耦的纯函数层）
///
/// 镜像 `chat_shell_nav_items.dart`：导航目的地按计划 §4.2 Workspace IA
/// （唯一权威导航结构）固定为五项：
///
/// ```text
/// Overview / Projects / Channels / Groups / Members
/// ```
///
/// 收敛决策（§4.2，防"什么都塞进左侧导航"）：
/// - Files 不做一级导航（聚合能力，入口在 Overview「最近文件」区块）
/// - Direct Messages 不进 Workspace 导航（用户级能力，由壳的全局区承载，
///   复用现有单聊入口，见 shell page 的 DM 按钮）
/// - Members 导航可简写「成员」，页面标题与说明必须出现「工作区成员」
///   全称（跨域术语约束，不改 Group Member / Channel Subscriber 命名）
library;

import 'package:flutter/cupertino.dart';

/// Workspace 体验导航目的地（§4.2 IA 唯一权威顺序）。
enum WorkspaceShellDestination {
  /// 导航枢纽：资源摘要 + Channel 置顶内容 + 最近文件 + 成员预览
  overview,

  /// Project 列表入口（详情/任务 UI 属 WP6，本期仅列表 + 空态）
  projects,

  /// scope=workspace 的频道（内容在这里；含 Announcements）
  channels,

  /// scope=workspace 的群（聊天唯一入口，I6）
  groups,

  /// Workspace Member（工作区成员）与角色管理
  members,
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

/// 构造 Workspace Shell 导航项列表（顺序固定 = §4.2 IA 权威顺序）。
///
/// 图标沿用 Cupertino 系（与 ChatShell / BottomNavigationPage 同源）：
/// - Overview：仪表盘 dashboard
/// - Projects：文件夹 folder
/// - Channels：电波 antenna（与 chat 壳频道项同图标）
/// - Groups：双人 person_2（群聊 = 人与人讨论）
/// - Members：联系人名片 person_crop_circle（工作区成员管理）
List<WorkspaceShellNavItem> buildWorkspaceShellNavItems({
  required String overviewLabel,
  required String projectsLabel,
  required String channelsLabel,
  required String groupsLabel,
  required String membersLabel,
}) {
  return [
    WorkspaceShellNavItem(
      destination: WorkspaceShellDestination.overview,
      icon: CupertinoIcons.chart_bar_alt_fill,
      activeIcon: CupertinoIcons.chart_bar_alt_fill,
      label: overviewLabel,
    ),
    WorkspaceShellNavItem(
      destination: WorkspaceShellDestination.projects,
      icon: CupertinoIcons.folder,
      activeIcon: CupertinoIcons.folder_fill,
      label: projectsLabel,
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
      destination: WorkspaceShellDestination.members,
      icon: CupertinoIcons.person_crop_circle,
      activeIcon: CupertinoIcons.person_crop_circle_badge_checkmark,
      label: membersLabel,
    ),
  ];
}
