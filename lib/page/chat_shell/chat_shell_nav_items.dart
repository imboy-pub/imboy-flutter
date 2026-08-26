/// T2 (WP1) — Chat 体验壳导航项声明层（i18n 与 widget 解耦的纯函数层）
///
/// 镜像 `web_nav_items_factory.dart` 的模式：把 chat 体验导航目的地的构造
/// 从 UI 中抽离成纯函数，i18n 解析（slang `t.xxx`）与特性开关判断发生在
/// 调用方，本文件只负责按固定顺序组装。
///
/// **本期定位（纯包装铁律）**：ChatShell 复用现有入口 widget 的导航 UI
/// （移动端 BottomNavigationPage 底部导航 / 桌面端 WebShellBootstrap 三栏），
/// 不自行渲染导航控件；本声明层是 T8 WorkspaceShell 导航
/// （Overview/Projects/Channels/Groups/Members）的对称镜像点，并为后续
/// 壳层接管导航渲染时提供可单测的数据源。
///
/// 设计要点：
/// - **顺序与 BottomNavigationPage 一致**：会话 / 联系人 / 频道 / 我的，
///   对齐 [ChatShellDestination] 枚举声明顺序
/// - **channel 项可裁剪**：`channelTabEnabled=false` 时不产出频道项
///   （对齐 BottomNavigationPage `_isTabEnabled('channel_tab')` 的特性开关）
/// - **图标与 BottomNavigationPage 逐项一致**（Cupertino 系）
/// - **零业务依赖**：纯函数，可独立单元测试
library;

import 'package:flutter/cupertino.dart';

/// Chat 体验导航目的地（与 BottomNavigationPage 的 4 Tab 语义一一对应）。
enum ChatShellDestination {
  /// 会话列表（消息）
  conversations,

  /// 联系人
  contacts,

  /// 频道（受 channel 特性开关控制）
  channels,

  /// 我的
  mine,
}

/// Chat Shell 导航项总数（4 个：会话 / 联系人 / 频道 / 我的）。
const int kChatShellDestinationCount = 4;

/// 单个导航项数据载体（不可变，镜像 web_shell `WebNavItem` 的字段组织）。
class ChatShellNavItem {
  /// 导航目的地（语义标识，非展示文案）
  final ChatShellDestination destination;

  /// 未选中态图标
  final IconData icon;

  /// 选中态图标（高亮版本，通常是 filled 变体）
  final IconData activeIcon;

  /// 文字标签（i18n 化的字符串，由调用方传入）
  final String label;

  const ChatShellNavItem({
    required this.destination,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatShellNavItem &&
          other.destination == destination &&
          other.icon == icon &&
          other.activeIcon == activeIcon &&
          other.label == label;

  @override
  int get hashCode => Object.hash(destination, icon, activeIcon, label);
}

/// 构造 Chat Shell 导航项列表。
///
/// 由调用方传入已 i18n 解析的 label 与 channel 特性开关结果。
/// 顺序固定：conversations → contacts → channels → mine（与
/// BottomNavigationPage `_buildPageList` 的 4 Tab 顺序对齐）。
///
/// 图标选用与 BottomNavigationPage 保持一致：
/// - 会话：chat_bubble / chat_bubble_fill
/// - 联系人：person_2 / person_2_fill
/// - 频道：antenna_radiowaves_left_right（无 filled 变体，两态同图标）
/// - 我的：person_circle / person_circle_fill
List<ChatShellNavItem> buildChatShellNavItems({
  required String conversationsLabel,
  required String contactsLabel,
  required String channelsLabel,
  required String mineLabel,
  bool channelTabEnabled = true,
}) {
  return [
    ChatShellNavItem(
      destination: ChatShellDestination.conversations,
      icon: CupertinoIcons.chat_bubble,
      activeIcon: CupertinoIcons.chat_bubble_fill,
      label: conversationsLabel,
    ),
    ChatShellNavItem(
      destination: ChatShellDestination.contacts,
      icon: CupertinoIcons.person_2,
      activeIcon: CupertinoIcons.person_2_fill,
      label: contactsLabel,
    ),
    if (channelTabEnabled)
      ChatShellNavItem(
        destination: ChatShellDestination.channels,
        icon: CupertinoIcons.antenna_radiowaves_left_right,
        activeIcon: CupertinoIcons.antenna_radiowaves_left_right,
        label: channelsLabel,
      ),
    ChatShellNavItem(
      destination: ChatShellDestination.mine,
      icon: CupertinoIcons.person_circle,
      activeIcon: CupertinoIcons.person_circle_fill,
      label: mineLabel,
    ),
  ];
}
