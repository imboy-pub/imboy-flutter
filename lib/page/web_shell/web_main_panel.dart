/// Web Shell 右栏主内容面板（按 sealed selection 分发）。
///
/// 内容类型由 [WebSelection] 穷尽分发，切换使用短促淡入与轻微位移；系统启用
/// “减少动态效果”时自动取消动画。
library;

import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_duration.dart';

import 'web_shell_state.dart';

/// Web Shell 右栏主内容面板。
class WebMainPanel extends StatelessWidget {
  /// 当前选中项（null = 显示欢迎屏）。
  final WebSelection? selection;

  /// 欢迎屏 widget（selection=null 时显示）。
  final Widget welcome;

  /// ChatSelection 时构造右栏内容。
  final Widget Function(ChatSelection sel) chatBuilder;

  /// ContactSelection 时构造右栏内容。
  final Widget Function(ContactSelection sel) contactBuilder;

  /// ChannelSelection 时构造右栏内容。
  final Widget Function(ChannelSelection sel) channelBuilder;

  /// MineSelection 时构造右栏内容。
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
    final duration = AppDuration.respectReducedMotion(
      MediaQuery.disableAnimationsOf(context),
      AppDuration.normal,
    );
    return Container(
      color: colorScheme.surface,
      // sealed switch 强制穷尽：未来新增 WebSelection 变体时此处编译失败。
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final offset = Tween<Offset>(
            begin: const Offset(0.012, 0),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offset, child: child),
          );
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
