/// Web Shell 左侧导航条。
///
/// 桌面端实际渲染复用 [DesktopNavigationRail]：macOS、Windows、Linux 与 Web
/// 使用同一套展开/收起、hover、选中态、角标和键盘交互。此文件保留 Web Shell
/// 既有 API，并负责导航展开偏好的本地持久化。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:imboy/component/ui/desktop_navigation_rail.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/storage.dart';

/// 单个导航项数据载体（不可变）。
class WebNavItem {
  /// 未选中态图标。
  final IconData icon;

  /// 选中态图标（通常是 filled 变体）。
  final IconData activeIcon;

  /// 文字标签（由调用方注入已解析的 i18n 文案）。
  final String label;

  /// 角标计数（0 = 不显示，> 99 显示 "99+"）。
  final int badgeCount;

  /// 在线/连接状态点，与未读数字角标语义区分。
  final Color? statusColor;

  /// 展开/收起状态下保持稳定的自动化入口。
  final Key? controlKey;

  const WebNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount = 0,
    this.statusColor,
    this.controlKey,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebNavItem &&
          other.icon == icon &&
          other.activeIcon == activeIcon &&
          other.label == label &&
          other.badgeCount == badgeCount &&
          other.statusColor == statusColor &&
          other.controlKey == controlKey;

  @override
  int get hashCode =>
      Object.hash(icon, activeIcon, label, badgeCount, statusColor, controlKey);
}

/// Web Shell 及紧凑桌面个人壳共用的可折叠导航条。
class WebNavRail extends StatefulWidget {
  /// 导航项（必须 >= 2 个）。
  final List<WebNavItem> items;

  /// 当前选中索引（必须在 [0, items.length) 范围内）。
  final int currentIndex;

  /// 切换回调。
  final ValueChanged<int> onTap;

  /// 收起宽度。保留原 API 名称，默认 72px。
  final double width;

  /// 展开宽度。常规桌面默认 176px，紧凑窗口可传 144px。
  final double expandedWidth;

  /// 独立于业务 tab 的全局入口（例如当前空间）。
  final Widget? leading;

  /// 无已保存偏好时的初始展开状态。
  final bool initiallyExpanded;

  /// 是否把展开状态写入本地偏好。
  final bool persistExpandedState;

  /// 最后一个目的地固定在底部（默认用于“我”）。
  final bool pinLastItemToBottom;

  /// 展开状态变化回调，供宿主测试或扩展埋点使用。
  final ValueChanged<bool>? onExpandedChanged;

  const WebNavRail({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.width = kDesktopNavigationCollapsedWidth,
    this.expandedWidth = kDesktopNavigationExpandedWidth,
    this.leading,
    this.initiallyExpanded = true,
    this.persistExpandedState = true,
    this.pinLastItemToBottom = true,
    this.onExpandedChanged,
  }) : assert(items.length >= 2, 'WebNavRail 至少需要 2 个 items'),
       assert(
         currentIndex >= 0 && currentIndex < items.length,
         'currentIndex 越界',
       );

  @override
  State<WebNavRail> createState() => _WebNavRailState();
}

class _WebNavRailState extends State<WebNavRail> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    if (widget.persistExpandedState) {
      try {
        _expanded =
            StorageService.to.getBool(
              kDesktopNavigationExpandedPreferenceKey,
            ) ??
            _expanded;
      } on Object {
        // 纯 widget 测试可能未初始化 StorageService；使用构造默认值即可。
      }
    }
  }

  @override
  void didUpdateWidget(covariant WebNavRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.persistExpandedState &&
        oldWidget.initiallyExpanded != widget.initiallyExpanded) {
      _expanded = widget.initiallyExpanded;
    }
  }

  void _toggleExpanded() {
    final next = !_expanded;
    setState(() => _expanded = next);
    widget.onExpandedChanged?.call(next);
    if (!widget.persistExpandedState) return;
    try {
      unawaited(
        StorageService.to.setBool(
          kDesktopNavigationExpandedPreferenceKey,
          next,
        ),
      );
    } on Object {
      // 本地偏好失败不应阻断当前会话内的导航交互。
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopNavigationRail(
      items: widget.items
          .map(
            (item) => DesktopNavigationItem(
              icon: item.icon,
              activeIcon: item.activeIcon,
              label: item.label,
              badgeCount: item.badgeCount,
              statusColor: item.statusColor,
              controlKey: item.controlKey,
            ),
          )
          .toList(growable: false),
      selectedIndex: widget.currentIndex,
      onSelected: widget.onTap,
      expanded: _expanded,
      onToggleExpanded: _toggleExpanded,
      collapseLabel: t.common.collapse,
      expandLabel: t.common.expandFull,
      leading: widget.leading,
      collapsedWidth: widget.width,
      expandedWidth: widget.expandedWidth,
      pinLastItemToBottom: widget.pinLastItemToBottom,
    );
  }
}
