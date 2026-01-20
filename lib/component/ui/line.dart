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

/// 垂直线组件 - 使用优化后的主题系统
class VerticalLine extends StatelessWidget {
  final double width;
  final double height;
  final Color? color;
  final double vertical;
  final EdgeInsetsGeometry? margin;
  final double opacity;

  const VerticalLine({
    super.key,
    this.width = 1.0,
    this.height = 25,
    this.color,
    this.vertical = 0.0,
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
      width: width,
      height: height,
      color: effectiveColor.withValues(alpha: opacity),
      margin: margin ?? EdgeInsets.symmetric(vertical: vertical),
    );
  }
}

/// 现代化的分割线组件 - 使用优化后的主题系统
class ModernDivider extends StatelessWidget {
  const ModernDivider({
    super.key,
    this.height = 1.0,
    this.thickness = 0.5,
    this.indent = 0.0,
    this.endIndent = 0.0,
    this.color,
    this.margin,
  });

  final double height;
  final double thickness;
  final double indent;
  final double endIndent;
  final Color? color;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Divider(
        height: height,
        thickness: thickness,
        indent: indent,
        endIndent: endIndent,
        color:
            color ??
            Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
      ),
    );
  }
}

/// 渐变分割线组件 - 使用优化后的主题系统
class GradientLine extends StatelessWidget {
  const GradientLine({
    super.key,
    this.height = 1.0,
    this.colors,
    this.begin = Alignment.centerLeft,
    this.end = Alignment.centerRight,
    this.margin,
  });

  final double height;
  final List<Color>? colors;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final defaultColors = ThemeManager.instance.isDarkMode
        ? [
            AppColors.darkBorder.withValues(alpha: 0.0),
            AppColors.darkBorder,
            AppColors.darkBorder.withValues(alpha: 0.0),
          ]
        : [
            AppColors.lightBorder.withValues(alpha: 0.0),
            AppColors.lightBorder,
            AppColors.lightBorder.withValues(alpha: 0.0),
          ];

    return Container(
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors ?? defaultColors,
          begin: begin,
          end: end,
        ),
      ),
    );
  }
}

/// 装饰性分割线组件 - 使用优化后的主题系统
class DecorativeLine extends StatelessWidget {
  const DecorativeLine({
    super.key,
    this.height = 2.0,
    this.width = 40.0,
    this.color,
    this.borderRadius = 1.0,
    this.margin,
  });

  final double height;
  final double width;
  final Color? color;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? AppColors.primary,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: (color ?? AppColors.primary).withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}
