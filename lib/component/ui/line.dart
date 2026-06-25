import 'package:flutter/material.dart';
import 'package:imboy/theme/theme_manager.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 水平线组件 - 使用优化后的主题系统
class HorizontalLine extends StatelessWidget {
  final double height;
  final Color? color;
  final double horizontal;
  final EdgeInsetsGeometry? margin;
  final double opacity;

  const HorizontalLine({
    super.key,
    this.height = 0.5,
    this.color,
    this.horizontal = 0.0,
    this.margin,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    // 使用优化后的主题色彩系统
    final effectiveColor =
        color ??
        (ThemeManager.instance.isDarkMode
            ? AppColors.darkBorder
            : AppColors.lightBorder);

    return Container(
      height: height,
      color: effectiveColor.withValues(alpha: opacity),
      margin: margin ?? EdgeInsets.symmetric(horizontal: horizontal),
    );
  }
}
