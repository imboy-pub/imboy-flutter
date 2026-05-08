/// Phase 1.1.f — Web Shell 中间面板（按 currentTab 切换内容）
///
/// 三栏布局的中栏（默认 360px 宽），承载 4 个 Tab 各自的列表内容：
/// 0 会话 / 1 联系人 / 2 频道 / 3 我的（顺序对齐 [WebShellState.currentTab]）。
///
/// 设计原则（与 1.1.d / 1.1.e 一致）：
/// - **无业务依赖**：通过 [tabs] 参数注入 4 个 widget，由调用方（1.1.h）传入实际 page
/// - **state 持久化**：用 [IndexedStack] 让 4 个 tab 同时 mount，切换时不重建（保持
///   滚动位置、列表 state、网络请求缓存等）
/// - **assert 防御**：tabs 长度 + currentIndex 边界
/// - **响应主题**：背景用 surface（与左 nav rail 的 surfaceContainer 区分）
library;

import 'package:flutter/material.dart';

/// Web Shell 中间面板
class WebMiddlePanel extends StatelessWidget {
  /// 当前展示的 tab 索引（必须在 [0, tabs.length) 范围内）
  final int currentTab;

  /// 4 个 tab 各自的内容 widget（按索引顺序）
  final List<Widget> tabs;

  /// 面板宽度（默认 360px，对齐 Telegram Web 中栏典型尺寸）
  final double width;

  /// 是否在 IndexedStack 中保持所有 tab 同时 mount（默认 true）
  ///
  /// - true: 切换 tab 不重建（保持 state）；首次启动 mount 所有 tab，内存换体验
  /// - false: 仅 mount 当前 tab（适合内存敏感场景，但失去 state）
  final bool keepAlive;

  const WebMiddlePanel({
    super.key,
    required this.currentTab,
    required this.tabs,
    this.width = 360,
    this.keepAlive = true,
  }) : assert(tabs.length >= 2, 'WebMiddlePanel 至少需要 2 个 tabs'),
       assert(currentTab >= 0 && currentTab < tabs.length, 'currentTab 越界');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = keepAlive
        ? IndexedStack(index: currentTab, children: tabs)
        : AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: KeyedSubtree(
              key: ValueKey<int>(currentTab),
              child: tabs[currentTab],
            ),
          );

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          right: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: content,
    );
  }
}
