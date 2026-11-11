/// Web Shell 中间面板（按 currentTab 切换内容）。
///
/// 4 个目的页面始终保留在 [IndexedStack] 中，切换时不丢失滚动位置、列表
/// 状态或请求缓存；当前页仅做非常轻的淡入与水平位移，避免桌面端“硬切”。
library;

import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_duration.dart';

/// Web Shell 中间面板。
class WebMiddlePanel extends StatefulWidget {
  /// 当前展示的 tab 索引（必须在 [0, tabs.length) 范围内）。
  final int currentTab;

  /// 各 tab 内容（按导航索引顺序）。
  final List<Widget> tabs;

  /// 面板宽度（默认 360px，对齐现有三栏布局）。
  final double width;

  /// 是否保持所有 tab 同时 mount（默认 true）。
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
  State<WebMiddlePanel> createState() => _WebMiddlePanelState();
}

class _WebMiddlePanelState extends State<WebMiddlePanel> {
  double _opacity = 1;
  Offset _offset = Offset.zero;
  int _transitionTicket = 0;

  @override
  void didUpdateWidget(covariant WebMiddlePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentTab == widget.currentTab) return;

    _opacity = 0.96;
    _offset = Offset(oldWidget.currentTab < widget.currentTab ? 0.012 : -0.012, 0);
    final ticket = ++_transitionTicket;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ticket != _transitionTicket) return;
      setState(() {
        _opacity = 1;
        _offset = Offset.zero;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final transitionDuration = AppDuration.respectReducedMotion(
      reduceMotion,
      AppDuration.fast,
    );

    final Widget content;
    if (widget.keepAlive) {
      content = AnimatedSlide(
        key: const ValueKey('web-middle-panel-transition'),
        duration: transitionDuration,
        curve: Curves.easeOutCubic,
        offset: _offset,
        child: AnimatedOpacity(
          duration: transitionDuration,
          curve: Curves.easeOutCubic,
          opacity: _opacity,
          child: IndexedStack(
            index: widget.currentTab,
            children: widget.tabs,
          ),
        ),
      );
    } else {
      content = AnimatedSwitcher(
        duration: AppDuration.respectReducedMotion(
          reduceMotion,
          AppDuration.normal,
        ),
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
          key: ValueKey<int>(widget.currentTab),
          child: widget.tabs[widget.currentTab],
        ),
      );
    }

    return Container(
      width: widget.width,
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
