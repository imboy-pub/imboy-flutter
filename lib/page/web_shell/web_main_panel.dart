/// Phase 1.1.g — Web Shell 右栏主内容面板（按 sealed selection 分发）
///
/// 三栏布局的右栏：根据 [WebShellState.selectedItem] 渲染不同内容。
/// - `null` → 显示 [welcome] 欢迎屏（由调用方传入 [WebWelcomePanel]）
/// - [ChatSelection] → 调 [chatBuilder]（Phase 2 注入实际 chat panel）
/// - [ContactSelection] → 调 [contactBuilder]
/// - [ChannelSelection] → 调 [channelBuilder]
/// - [MineSelection] → 调 [mineBuilder]
///
/// 设计原则（与 1.1.d/e/f 一致）：
/// - **无业务依赖**：通过 4 个 builder 注入实际内容，调用方（1.1.h）传入业务 widget
/// - **类型安全分发**：用 sealed [WebSelection] + switch expression，编译器强制
///   未来新增 selection 变体时所有消费侧同步更新
/// - **无 i18n 依赖**：欢迎屏作为 widget 参数注入，文案完全外部化
/// - **响应主题**：用 ColorScheme.surface 背景
library;

import 'package:flutter/material.dart';

import 'web_shell_state.dart';

/// Web Shell 右栏主内容面板
class WebMainPanel extends StatelessWidget {
  /// 当前选中项（null = 显示欢迎屏）
  final WebSelection? selection;

  /// 欢迎屏 widget（selection=null 时显示）
  final Widget welcome;

  /// ChatSelection 时构造右栏内容
  final Widget Function(ChatSelection sel) chatBuilder;

  /// ContactSelection 时构造右栏内容
  final Widget Function(ContactSelection sel) contactBuilder;

  /// ChannelSelection 时构造右栏内容
  final Widget Function(ChannelSelection sel) channelBuilder;

  /// MineSelection 时构造右栏内容
  final Widget Function(MineSelection sel) mineBuilder;

  const WebMainPanel({
    super.key,
    required this.selection,
    required this.welcome,
    required this.chatBuilder,
    required this.contactBuilder,
    required this.channelBuilder,
    required this.mineBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surface,
      // sealed switch 强制穷尽：未来新增 WebSelection 变体时此处编译失败
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: KeyedSubtree(
          key: ValueKey(selection.hashCode),
          child: switch (selection) {
            null => welcome,
            final ChatSelection s => chatBuilder(s),
            final ContactSelection s => contactBuilder(s),
            final ChannelSelection s => channelBuilder(s),
            final MineSelection s => mineBuilder(s),
          },
        ),
      ),
    );
  }
}
