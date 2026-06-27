import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 圆角 elevated 按钮 - 使用优化后的主题系统
class RoundedElevatedButton extends StatelessWidget {
  final String text;
  final bool highlighted;
  final VoidCallback? onPressed;
  final Size? size;
  final BorderRadius? borderRadius;
  final IconData? icon;
  final bool isLoading;

  const RoundedElevatedButton({
    super.key,
    required this.text,
    required this.highlighted,
    required this.onPressed,
    this.size,
    this.borderRadius,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(25),
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
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: highlighted
            ? _primaryButtonStyle(context, size)
            : _secondaryButtonStyle(context, size),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    highlighted ? AppColors.onPrimary : AppColors.primary,
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// 主要按钮样式
  ButtonStyle _primaryButtonStyle(BuildContext context, Size? size) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      minimumSize: size ?? const Size(88, 48),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(25),
      ),
      elevation: 2,
      shadowColor: AppColors.primary.withValues(alpha: 0.3),
    );
  }

  /// 次要按钮样式
  ButtonStyle _secondaryButtonStyle(BuildContext context, Size? size) {
    return ElevatedButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: AppColors.primary,
      minimumSize: size ?? const Size(88, 48),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(25),
        side: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      elevation: 0,
    );
  }
}
