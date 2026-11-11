import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 个人与企业共用的移动端底栏，统一主题、触达与底部安全区。
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
        (isDark ? AppColors.darkSurfaceGrouped : AppColors.lightSurface)
            .withValues(alpha: 0.8);
    final separatorColor = AppColors.getIosSeparator(theme.brightness)
        .withValues(alpha: 0.5);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(top: BorderSide(color: separatorColor, width: 0.33)),
          ),
          child: SafeArea(
            top: false,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isSelected = currentIndex == index;

                  return Expanded(
                    key: item.tabKey,
                    // 不设 label：标签 Text 已提供，避免双标签重复读屏。
                    child: Semantics(
                      button: true,
                      selected: isSelected,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTap(index),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: height),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.tiny),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // 图标
                                SizedBox(
                                  height:
                                      AppSizes.iconSizeMedium + AppSpacing.tiny,
                                  child: item.iconBuilder != null
                                      ? IconTheme(
                                          data: IconThemeData(
                                            size: AppSizes.iconSizeMedium,
                                            color: isSelected
                                                ? theme.colorScheme.primary
                                                : theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                          ),
                                          child: item.iconBuilder!(isSelected),
                                        )
                                      : Icon(
                                          isSelected
                                              ? (item.activeIcon ?? item.icon)
                                              : item.icon,
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                              : theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                          size: AppSizes.iconSizeMedium,
                                        ),
                                ),
                                const SizedBox(height: AppSpacing.tiny / 2),
                                // 标签
                                Text(
                                  item.label,
                                  style: context
                                      .textStyle(
                                        FontSizeType.tiny,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                      )
                                      .copyWith(
                                        height: 1.2,
                                        letterSpacing: -0.2,
                                      ),
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
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
