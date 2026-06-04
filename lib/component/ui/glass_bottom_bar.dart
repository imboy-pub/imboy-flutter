import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// iOS 风格毛玻璃底部导航栏 - iOS 17 Premium 风格
class GlassBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  final List<GlassBottomBarItem> items;
  final double height;
  final double blur;

  const GlassBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.height = 50.0, // iOS 标准约为 49-50
    this.blur = 25.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 背景色：亮色纯白，暗色 darkSurfaceGrouped，透明度 0.8
    final backgroundColor =
        (isDark ? AppColors.darkSurfaceGrouped : Colors.white).withValues(
          alpha: 0.8,
        );
    final separatorColor = AppColors.getIosSeparator(
      theme.brightness,
    ).withValues(alpha: 0.5);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          height: height + MediaQuery.of(context).padding.bottom,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(top: BorderSide(color: separatorColor, width: 0.33)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = currentIndex == index;

              return Expanded(
                key: item.tabKey,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 图标
                      SizedBox(
                        height: 28,
                        child: item.iconBuilder != null
                            ? item.iconBuilder!(isSelected)
                            : Icon(
                                isSelected
                                    ? (item.activeIcon ?? item.icon)
                                    : item.icon,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.iosGray,
                                size: 26,
                              ),
                      ),
                      const SizedBox(height: 1),
                      // 标签
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.2,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.iosGray,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class GlassBottomBarItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final Widget Function(bool)? iconBuilder;

  /// 测试用语义 Key，传给对应的 Expanded tap 节点
  final Key? tabKey;

  GlassBottomBarItem({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.iconBuilder,
    this.tabKey,
  });
}
