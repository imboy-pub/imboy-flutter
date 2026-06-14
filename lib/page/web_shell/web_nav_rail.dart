/// Phase 1.1.e — Web Shell 左侧导航条（72px NavigationRail）
///
/// Telegram Web 风格的桌面侧导航：固定宽度，顶部 4 个 Tab 图标 + 角标，
/// 选中态以 primary 着色，hover 高亮 surfaceContainerHighest。
///
/// 设计原则（与 [WebWelcomePanel] 1.1.d 一致）：
/// - **无 i18n 依赖**：label 通过参数注入，由调用方（后续 1.1.h WebShellPage）传入 slang 文案
/// - **无业务依赖**：纯 Material widget，不引入 Riverpod 监听
/// - **回调驱动**：[WebNavItem] 列表 + currentIndex + onTap 形成完整 props
/// - **响应主题**：用 ColorScheme 取色，亮暗模式自动适配
library;

import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 单个导航项数据载体（不可变）
class WebNavItem {
  /// 未选中态图标
  final IconData icon;

  /// 选中态图标（高亮版本，通常是 filled 变体）
  final IconData activeIcon;

  /// 文字标签（i18n 化的字符串，由调用方传入）
  final String label;

  /// 角标计数（0 = 不显示，> 99 显示 "99+"）
  final int badgeCount;

  const WebNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebNavItem &&
          other.icon == icon &&
          other.activeIcon == activeIcon &&
          other.label == label &&
          other.badgeCount == badgeCount;

  @override
  int get hashCode => Object.hash(icon, activeIcon, label, badgeCount);
}

/// Web Shell 左侧导航条
class WebNavRail extends StatelessWidget {
  /// 导航项（必须 >= 2 个）
  final List<WebNavItem> items;

  /// 当前选中索引（必须在 [0, items.length) 范围内）
  final int currentIndex;

  /// 切换回调
  final ValueChanged<int> onTap;

  /// 导航条宽度（默认 72px，对齐 Telegram Web）
  final double width;

  const WebNavRail({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.width = 72,
  }) : assert(items.length >= 2, 'WebNavRail 至少需要 2 个 items'),
       assert(
         currentIndex >= 0 && currentIndex < items.length,
         'currentIndex 越界',
       );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      color: colorScheme.surfaceContainer,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            for (var i = 0; i < items.length; i++)
              _WebNavRailItem(
                item: items[i],
                isSelected: i == currentIndex,
                onTap: () => onTap(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _WebNavRailItem extends StatelessWidget {
  final WebNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _WebNavRailItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Tooltip(
      message: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 56,
          height: 56,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withAlpha(31) // ≈ 0.12 alpha
                : AppColors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                isSelected ? item.activeIcon : item.icon,
                color: iconColor,
                size: 26,
              ),
              if (item.badgeCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: _Badge(count: item.badgeCount),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;

  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final text = count > 99 ? '99+' : count.toString();
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: colorScheme.error,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colorScheme.onError,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }
}
