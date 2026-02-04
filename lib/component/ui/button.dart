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
                    highlighted ? Colors.white : AppColors.primary,
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
      foregroundColor: Colors.white,
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

/// 浅绿色按钮样式 - 使用优化后的主题色彩
/// 新版本：需要传入 BuildContext 以获取屏幕宽度
ButtonStyle lightGreenButtonStyle(
  BuildContext context,
  Size? s, {
  WidgetStateProperty<Color?>? backgroundColor,
  double borderRadius = 25.0,
}) {
  // 使用 MediaQuery 获取屏幕宽度，替代 Get.width
  final screenWidth = MediaQuery.of(context).size.width;

  return ButtonStyle(
    backgroundColor:
        backgroundColor ??
        WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.primary.withValues(alpha: 0.5);
          }
          if (states.contains(WidgetState.pressed)) {
            return AppColors.primary.withValues(alpha: 0.8);
          }
          return AppColors.primary;
        }),
    foregroundColor: WidgetStateProperty.resolveWith<Color>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.disabled)) {
        return Colors.white.withValues(alpha: 0.7);
      }
      return Colors.white;
    }),
    minimumSize: WidgetStateProperty.all(s ?? Size(screenWidth - 20, 50)),
    padding: WidgetStateProperty.all(
      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    ),
    shape: WidgetStateProperty.all<OutlinedBorder>(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
    ),
    elevation: WidgetStateProperty.resolveWith<double>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.pressed)) {
        return 1;
      }
      return 3;
    }),
    shadowColor: WidgetStateProperty.all(
      AppColors.primary.withValues(alpha: 0.3),
    ),
    overlayColor: WidgetStateProperty.resolveWith<Color?>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.pressed)) {
        return Colors.white.withValues(alpha: 0.1);
      }
      return null;
    }),
  );
}

/// 白色绿色按钮样式 - 使用优化后的主题色彩
ButtonStyle whiteGreenButtonStyle(Size? s, {double borderRadius = 8.0}) {
  return ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith<Color>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.pressed)) {
        return AppColors.primary.withValues(alpha: 0.05);
      }
      return Colors.white;
    }),
    foregroundColor: WidgetStateProperty.all<Color>(AppColors.primary),
    minimumSize: WidgetStateProperty.all(s ?? const Size(88, 48)),
    padding: WidgetStateProperty.all(
      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
    shape: WidgetStateProperty.all<OutlinedBorder>(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
    ),
    elevation: WidgetStateProperty.resolveWith<double>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.pressed)) {
        return 0;
      }
      return 1;
    }),
    shadowColor: WidgetStateProperty.all(Colors.black.withValues(alpha: 0.1)),
    overlayColor: WidgetStateProperty.resolveWith<Color?>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.pressed)) {
        return AppColors.primary.withValues(alpha: 0.1);
      }
      return null;
    }),
  );
}

/// 现代化的 elevated 按钮样式 - 使用优化后的主题系统
ButtonStyle modernElevatedButtonStyle(
  BuildContext context, {
  Color? backgroundColor,
  Color? foregroundColor,
  double borderRadius = 12.0,
}) {
  final textTheme = Theme.of(context).textTheme;

  return ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith<Color>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.disabled)) {
        return (backgroundColor ?? Theme.of(context).colorScheme.surface)
            .withValues(alpha: 0.5);
      }
      if (states.contains(WidgetState.pressed)) {
        return (backgroundColor ?? Theme.of(context).colorScheme.surface)
            .withValues(alpha: 0.8);
      }
      return backgroundColor ?? Theme.of(context).colorScheme.surface;
    }),
    foregroundColor: WidgetStateProperty.resolveWith<Color>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.disabled)) {
        return (foregroundColor ?? Theme.of(context).colorScheme.onSurface)
            .withValues(alpha: 0.5);
      }
      return foregroundColor ?? Theme.of(context).colorScheme.onSurface;
    }),
    elevation: WidgetStateProperty.resolveWith<double>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.pressed)) {
        return 1;
      }
      return 2;
    }),
    padding: WidgetStateProperty.all(
      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
    textStyle: WidgetStateProperty.all(
      textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
    ),
    shape: WidgetStateProperty.all<OutlinedBorder>(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
    ),
    shadowColor: WidgetStateProperty.all(Colors.black.withValues(alpha: 0.1)),
    overlayColor: WidgetStateProperty.resolveWith<Color?>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.pressed)) {
        return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05);
      }
      return null;
    }),
  );
}

/// 现代化的 outlined 按钮样式 - 使用优化后的主题系统
ButtonStyle modernOutlinedButtonStyle(
  BuildContext context, {
  Color? borderColor,
  Color? foregroundColor,
  double borderRadius = 12.0,
  double borderWidth = 1.5,
}) {
  final textTheme = Theme.of(context).textTheme;
  final effectiveBorderColor = borderColor ?? AppColors.primary;
  final effectiveForegroundColor = foregroundColor ?? AppColors.primary;

  return ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith<Color>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.disabled)) {
        return effectiveForegroundColor.withValues(alpha: 0.5);
      }
      return effectiveForegroundColor;
    }),
    backgroundColor: WidgetStateProperty.resolveWith<Color?>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.pressed)) {
        return effectiveBorderColor.withValues(alpha: 0.05);
      }
      if (states.contains(WidgetState.hovered)) {
        return effectiveBorderColor.withValues(alpha: 0.02);
      }
      return Colors.transparent;
    }),
    side: WidgetStateProperty.resolveWith<BorderSide>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.disabled)) {
        return BorderSide(
          color: effectiveBorderColor.withValues(alpha: 0.3),
          width: borderWidth,
        );
      }
      if (states.contains(WidgetState.pressed)) {
        return BorderSide(
          color: effectiveBorderColor.withValues(alpha: 0.8),
          width: borderWidth,
        );
      }
      return BorderSide(color: effectiveBorderColor, width: borderWidth);
    }),
    shape: WidgetStateProperty.all<OutlinedBorder>(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
    ),
    padding: WidgetStateProperty.all(
      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    ),
    textStyle: WidgetStateProperty.all(
      textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    overlayColor: WidgetStateProperty.resolveWith<Color?>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.pressed)) {
        return effectiveBorderColor.withValues(alpha: 0.1);
      }
      return null;
    }),
  );
}
