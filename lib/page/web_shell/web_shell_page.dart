/// Phase 1.1.h.2 — Web Shell 三栏整合 widget（无 i18n 依赖）
///
/// 把 1.1.a~m 的 11 个组件整合为可消费的入口 [WebShellPage]：
/// - 监听 [webShellProvider] 状态
/// - 用 [resolveShellLayout] 决定 mobile / threeColumn 分歧
/// - mobile（< 900px）→ 回退到 [mobileFallback]（调用方传入移动端 entry）
/// - threeColumn（>= 900px）→ 渲染 [WebNavRail] + [WebMiddlePanel] + [WebMainPanel]
/// - 用 [buildWebNavItems] 工厂注入 4 个 nav items（label/badge 由调用方传入）
///
/// 设计原则（保持与 1.1.a~m 一致）：
/// - **无 i18n 依赖**：所有用户可见文案通过 props 注入（调用方负责 slang t.xxx 解析）
/// - **无业务依赖**：4 个 tab 内容 widget + 4 个 selection builder 由调用方传入
/// - **mobile fallback 解耦**：调用方传入移动端 entry（通常是 BottomNavigationPage），
///   避免本 widget 反向依赖 page 层
/// - **响应主题**：背景用 ColorScheme.surface
///
/// 注：本 slice 不修改 app_router / 其他业务代码。集成入路由是 1.1.i 切片的工作。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'web_shell.dart';

/// Web Shell 三栏整合页面
class WebShellPage extends ConsumerWidget {
  // === i18n 标签（由调用方注入 slang 解析后的字符串） ===

  /// Tab 0 标签（"消息" / "Messages"）
  final String tabMessageLabel;

  /// Tab 1 标签（"联系人" / "Contacts"）
  final String tabContactLabel;

  /// Tab 2 标签（"频道" / "Channels"）
  final String tabChannelLabel;

  /// Tab 3 标签（"我的" / "Me"）
  final String tabMineLabel;

  /// 欢迎屏标题（默认 selectedItem=null 时显示）
  final String welcomeTitle;

  /// 欢迎屏副标题（可选）
  final String? welcomeSubtitle;

  // === Tab 中栏内容（由调用方注入实际 page widget） ===

  final Widget messageTab;
  final Widget contactTab;
  final Widget channelTab;
  final Widget mineTab;

  // === 右栏 sealed selection builder（由调用方注入） ===

  final Widget Function(ChatSelection sel) chatBuilder;
  final Widget Function(ContactSelection sel) contactBuilder;
  final Widget Function(ChannelSelection sel) channelBuilder;
  final Widget Function(MineSelection sel) mineBuilder;

  // === Mobile fallback（< 900px 时渲染） ===

  /// 当浏览器宽度 < 900px 时降级渲染的 widget
  ///
  /// 通常调用方传入 `BottomNavigationPage()` 或类似移动端入口
  final Widget mobileFallback;

  // === 角标计数（可选，0 时不显示） ===

  /// 消息 Tab 未读数
  final int messageBadgeCount;

  /// 联系人 Tab 角标（如新好友请求数）
  final int contactBadgeCount;

  /// 频道 Tab 未读数
  final int channelBadgeCount;

  const WebShellPage({
    super.key,
    required this.tabMessageLabel,
    required this.tabContactLabel,
    required this.tabChannelLabel,
    required this.tabMineLabel,
    required this.welcomeTitle,
    this.welcomeSubtitle,
    required this.messageTab,
    required this.contactTab,
    required this.channelTab,
    required this.mineTab,
    required this.chatBuilder,
    required this.contactBuilder,
    required this.channelBuilder,
    required this.mineBuilder,
    required this.mobileFallback,
    this.messageBadgeCount = 0,
    this.contactBadgeCount = 0,
    this.channelBadgeCount = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shellState = ref.watch(webShellProvider);
    final width = MediaQuery.of(context).size.width;
    final layout = resolveShellLayout(width);

    // mobile 分支：直接渲染 fallback
    if (layout == WebShellLayout.mobile) {
      return mobileFallback;
    }

    // 构造 nav items（i18n + badge 通过工厂注入）
    final navItems = buildWebNavItems(
      messageLabel: tabMessageLabel,
      contactLabel: tabContactLabel,
      channelLabel: tabChannelLabel,
      mineLabel: tabMineLabel,
      messageBadgeCount: messageBadgeCount,
      contactBadgeCount: contactBadgeCount,
      channelBadgeCount: channelBadgeCount,
    );

    final colorScheme = Theme.of(context).colorScheme;
    final notifier = ref.read(webShellProvider.notifier);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Row(
        children: [
          // 左栏：NavRail（72px）
          WebNavRail(
            items: navItems,
            currentIndex: shellState.currentTab,
            onTap: notifier.switchTab,
          ),
          // 中栏：IndexedStack 4 tabs（默认 360px）
          WebMiddlePanel(
            currentTab: shellState.currentTab,
            tabs: [messageTab, contactTab, channelTab, mineTab],
          ),
          // 右栏：sealed switch 分发（剩余空间）
          Expanded(
            child: WebMainPanel(
              selection: shellState.selectedItem,
              welcome: WebWelcomePanel(
                title: welcomeTitle,
                subtitle: welcomeSubtitle,
              ),
              chatBuilder: chatBuilder,
              contactBuilder: contactBuilder,
              channelBuilder: channelBuilder,
              mineBuilder: mineBuilder,
            ),
          ),
        ],
      ),
    );
  }
}
