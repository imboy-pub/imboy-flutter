/// T2 (WP1) — Chat 体验壳页面（纯包装，零业务逻辑）
///
/// 壳提供导航骨架的分发：按响应式断点把内容区交给现有入口 widget——
/// - `mobile`（< 900px）→ [mobileEntry]（移动端底部导航首页 BottomNavigationPage）
/// - `desktop`（>= 900px）→ [desktopEntry]（桌面三栏壳 WebShellBootstrap）
///
/// 设计原则（镜像 `web_shell_page.dart`）：
/// - **无 i18n 依赖**：本壳不渲染用户可见文案
/// - **无业务依赖**：两个入口 widget 由调用方注入，本 widget 不反向感知
///   BottomNavigationPage / WebShellBootstrap 的存在（mobile fallback 解耦）
/// - **纯包装铁律**：不包装 Scaffold、不加导航控件、不改子树生命周期，
///   现有首页的 badges / E2EE 引导 / WebSocket 状态等内部行为原样保留
library;

import 'package:flutter/widgets.dart';

import 'chat_shell_breakpoint.dart';

/// Chat 体验壳整合页面。
///
/// 内容区承载现有页面 widget：调用方（ChatShellBootstrap）注入
/// `BottomNavigationPage` 与 `WebShellBootstrap`，本壳只做宽度自适应分发。
class ChatShellPage extends StatelessWidget {
  /// 移动端（< 900px）渲染的现有入口 widget。
  final Widget mobileEntry;

  /// 桌面端（>= 900px）渲染的现有入口 widget。
  final Widget desktopEntry;

  const ChatShellPage({
    super.key,
    required this.mobileEntry,
    required this.desktopEntry,
  });

  @override
  Widget build(BuildContext context) {
    final layout = resolveChatShellLayout(MediaQuery.sizeOf(context).width);
    return layout == ChatShellLayout.mobile ? mobileEntry : desktopEntry;
  }
}
