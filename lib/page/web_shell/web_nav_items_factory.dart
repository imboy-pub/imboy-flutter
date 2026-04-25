/// Phase 1.1.h.0 — Web Shell 导航项工厂（i18n 与 widget 解耦的纯函数层）
///
/// 把 [WebNavItem] 列表的构造从 UI widget 中抽离：
/// - i18n 解析（slang `t.xxx`）发生在调用方
/// - badge 计数从 Riverpod state 读取发生在调用方
/// - 本工厂只负责把已解析的数据按固定顺序组装成 [WebNavItem] 列表
///
/// 这样 1.1.e [WebNavRail] 完全无 i18n / Riverpod 依赖（widget 测试无需
/// `ProviderScope`），1.1.h Web Shell 整合时只需调用 [buildWebNavItems] 注入
/// label/badge 即可。
///
/// 设计要点：
/// - **图标顺序与 BottomNavigationPage 一致**：消息 / 联系人 / 频道 / 我的，
///   对齐 [WebShellState.currentTab] 0..3 索引语义
/// - **mine badge 不可配**：我的 Tab 不应有未读角标（沿用 BottomNavigationPage
///   惯例，badge 用于其他状态如连接 dot 而非 unread count）
/// - **零业务依赖**：纯函数，可独立单元测试
library;

import 'package:flutter/material.dart';

import 'web_nav_rail.dart' show WebNavItem;

/// Web Shell 导航 Tab 总数（4 个：会话 / 联系人 / 频道 / 我的）
const int kWebNavItemCount = 4;

/// Tab 索引 → 语义常量（避免散落 0/1/2/3 魔数）
const int kWebNavTabMessage = 0;
const int kWebNavTabContact = 1;
const int kWebNavTabChannel = 2;
const int kWebNavTabMine = 3;

/// 构造 Web Shell 4 个导航项的列表
///
/// 由调用方传入已 i18n 解析的 label 与 badge 计数。
///
/// 顺序固定：messages → contacts → channels → mine（与 BottomNavigationPage
/// `_buildPageList` 的 4 Tab 顺序对齐）。
///
/// 图标选用与 BottomNavigationPage 保持一致：
/// - 消息：chat_bubble_outline / chat_bubble
/// - 联系人：people_alt_outlined / people_alt
/// - 频道：campaign_outlined / campaign
/// - 我的：person_outline / person
List<WebNavItem> buildWebNavItems({
  required String messageLabel,
  required String contactLabel,
  required String channelLabel,
  required String mineLabel,
  int messageBadgeCount = 0,
  int contactBadgeCount = 0,
  int channelBadgeCount = 0,
}) {
  return [
    WebNavItem(
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      label: messageLabel,
      badgeCount: messageBadgeCount,
    ),
    WebNavItem(
      icon: Icons.people_alt_outlined,
      activeIcon: Icons.people_alt,
      label: contactLabel,
      badgeCount: contactBadgeCount,
    ),
    WebNavItem(
      icon: Icons.campaign_outlined,
      activeIcon: Icons.campaign,
      label: channelLabel,
      badgeCount: channelBadgeCount,
    ),
    WebNavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: mineLabel,
      // mine tab 不显示 unread badge：连接状态等其他指示器走 NavRail 外的 layer
    ),
  ];
}
