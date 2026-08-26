import 'package:flutter/cupertino.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 圆角 Cupertino 按钮 - 使用 iOS 风格
///
/// [highlighted] = true：主色填充 + 白字 + 投影；
/// false：浅色底 + 主色描边 + 主色文字（secondary 样式）。
/// [size] 为「最小外框尺寸」语义（与旧 RoundedElevatedButton 的
/// ElevatedButton.minimumSize 一致），长文本可继续撑大不溢出。
class RoundedCupertinoButton extends StatelessWidget {
  final String text;
  final bool highlighted;
  final VoidCallback? onPressed;
  final Size? size;
  final BorderRadius? borderRadius;
  final IconData? icon;
  final bool isLoading;

  const RoundedCupertinoButton({
    super.key,
    required this.text,
    required this.highlighted,
    required this.onPressed,
    this.size,
    this.borderRadius,
    this.icon,
    this.isLoading = false,
  });

  static const double _kHorizontalPadding = 24;
  static const double _kVerticalPadding = 12;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(25);
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final bgColor = highlighted
        ? AppColors.primary
        : (isDark ? AppColors.darkSurface : AppColors.lightSurface);
    // 前景色与背景始终对比：加载指示器/图标/文字同色处理
    final fgColor = highlighted ? AppColors.onPrimary : AppColors.primary;
    // 最小外框尺寸 → 内容区最小约束（减去按钮 padding）
    final minContentWidth = ((size?.width ?? 88) - _kHorizontalPadding * 2)
        .clamp(0.0, double.infinity);
    final minContentHeight = ((size?.height ?? 48) - _kVerticalPadding * 2)
        .clamp(0.0, double.infinity);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: highlighted ? null : Border.all(color: AppColors.primary),
        boxShadow: highlighted && onPressed != null
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: CupertinoButton(
        onPressed: isLoading ? null : onPressed,
        padding: const EdgeInsets.symmetric(
          horizontal: _kHorizontalPadding,
          vertical: _kVerticalPadding,
        ),
        borderRadius: radius,
        color: bgColor,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minContentWidth,
            minHeight: minContentHeight,
          ),
          child: isLoading
              ? Center(child: CupertinoActivityIndicator(color: fgColor))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: fgColor),
                      AppSpacing.horizontalSmall,
                    ],
                    Flexible(
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: FontSizeType.medium.size,
                          color: fgColor,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
