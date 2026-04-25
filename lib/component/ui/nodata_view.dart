import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 无数据视图组件 - 使用优化后的主题系统
class NoDataView extends StatelessWidget {
  final String text;
  final VoidCallback? onTop;
  final IconData? icon;
  final String? description;

  /// 图标圆形容器固定尺寸。null = 使用 padding:16 自适应（向后兼容默认）；
  /// 非 null 时容器渲染为 iconBgSize × iconBgSize 的固定尺寸圆形（对齐手写空态的 80/120 尺寸惯例）。
  final double? iconBgSize;

  /// 图标尺寸。默认 48（原值，向后兼容）。
  final double iconSize;

  /// 图标容器形状。null = BoxShape.circle（向后兼容默认）；非 null 时容器渲染为
  /// 带 borderRadius 的矩形，形状由传入的 BorderRadiusGeometry 决定（对齐 user_device 等矩形空态）。
  final BorderRadiusGeometry? iconBgBorderRadius;

  /// 重试按钮文案。null = t.buttonRetry（向后兼容默认）；非 null 时覆盖默认"重试"文本
  /// （对齐 e2ee_social_recover 等需要自定义"重新加载分片"等语义的场景）。
  final String? retryLabel;

  const NoDataView({
    super.key,
    required this.text,
    this.onTop,
    this.icon,
    this.description,
    this.iconBgSize,
    this.iconSize = 48,
    this.iconBgBorderRadius,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    // F-38: 使用 Theme.of(context).colorScheme.onSurfaceVariant 替代硬编码
    // AppColors.textSecondary。后者 getter 永远返回 lightTextSecondary，暗色模式失效。
    // theme.dart 已配置 onSurfaceVariant → lightTextSecondary / darkTextSecondary，
    // 通过 ColorScheme 访问可正确随主题切换。
    final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: InkWell(
        onTap: onTop,
        borderRadius: AppRadius.borderRadiusMedium, // 添加圆角点击效果
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标 - 使用主题色
              if (icon != null)
                Container(
                  width: iconBgSize,
                  height: iconBgSize,
                  padding: iconBgSize == null ? const EdgeInsets.all(16) : null,
                  alignment: iconBgSize == null ? null : Alignment.center,
                  decoration: BoxDecoration(
                    color: secondaryColor.withValues(alpha: 0.1),
                    shape: iconBgBorderRadius == null
                        ? BoxShape.circle
                        : BoxShape.rectangle,
                    borderRadius: iconBgBorderRadius,
                  ),
                  child: Icon(
                    icon!,
                    size: iconSize,
                    color: secondaryColor, // 使用主题次要文字色
                  ),
                ),
              if (icon != null) const SizedBox(height: 16),

              // 主要文本 - 使用优化后的主题样式
              Text(
                text,
                style: ThemeManager.instance.getTextStyle(
                  FontSizeType.medium,
                  fontWeight: FontWeight.w500,
                  color: secondaryColor, // 使用主题次要文字色
                ),
                textAlign: TextAlign.center,
              ),

              // 描述文本 - 使用优化后的主题样式
              if (description != null) ...[
                const SizedBox(height: 8),
                Text(
                  description!,
                  style: ThemeManager.instance.getTextStyle(
                    FontSizeType.small,
                    color: secondaryColor.withValues(alpha: 0.7), // 使用更淡的次要文字色
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              // 点击提示 - 如果有点击事件
              if (onTop != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.borderRadiusRegular,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    retryLabel ?? t.buttonRetry,
                    style: ThemeManager.instance.getTextStyle(
                      FontSizeType.small,
                      color: AppColors.primary, // 使用主题主色
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
