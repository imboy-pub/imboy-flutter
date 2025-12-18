import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/theme/default/font_types.dart';
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(25),
        boxShadow: highlighted && onPressed != null
            ? [
                BoxShadow(
                  color: AppColors.primaryGreen.withValues(alpha: 0.3),
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
                    highlighted ? Colors.white : AppColors.primaryGreen,
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
                    style: ThemeManager.instance.getTextStyle(
                      FontSizeType.medium,
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
      backgroundColor: AppColors.primaryGreen,
      foregroundColor: Colors.white,
      minimumSize: size ?? const Size(88, 48),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(25),
      ),
      elevation: 2,
      shadowColor: AppColors.primaryGreen.withValues(alpha: 0.3),
    );
  }

  /// 次要按钮样式
  ButtonStyle _secondaryButtonStyle(BuildContext context, Size? size) {
    return ElevatedButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: AppColors.primaryGreen,
      minimumSize: size ?? const Size(88, 48),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(25),
        side: BorderSide(
          color: AppColors.primaryGreen.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      elevation: 0,
    );
  }
}

/// 浅绿色按钮样式 - 使用优化后的主题色彩
ButtonStyle lightGreenButtonStyle(
  Size? s, {
  WidgetStateProperty<Color?>? backgroundColor,
  double borderRadius = 25.0,
}) {
  return ButtonStyle(
    backgroundColor:
        backgroundColor ??
        WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.primaryGreen.withValues(alpha: 0.5);
          }
          if (states.contains(WidgetState.pressed)) {
            return AppColors.primaryGreen.withValues(alpha: 0.8);
          }
          return AppColors.primaryGreen;
        }),
    foregroundColor: WidgetStateProperty.resolveWith<Color>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.disabled)) {
        return Colors.white.withValues(alpha: 0.7);
      }
      return Colors.white;
    }),
    minimumSize: WidgetStateProperty.all(s ?? Size(Get.width - 20, 50)),
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
      AppColors.primaryGreen.withValues(alpha: 0.3),
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
        return AppColors.primaryGreen.withValues(alpha: 0.05);
      }
      return Colors.white;
    }),
    foregroundColor: WidgetStateProperty.all<Color>(AppColors.primaryGreen),
    minimumSize: WidgetStateProperty.all(s ?? const Size(88, 48)),
    padding: WidgetStateProperty.all(
      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
    shape: WidgetStateProperty.all<OutlinedBorder>(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: BorderSide(
          color: AppColors.primaryGreen.withValues(alpha: 0.2),
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
        return AppColors.primaryGreen.withValues(alpha: 0.1);
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
      ThemeManager.instance.getTextStyle(FontSizeType.medium, fontWeight: FontWeight.w500, context: context),
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
  final effectiveBorderColor = borderColor ?? AppColors.primaryGreen;
  final effectiveForegroundColor = foregroundColor ?? AppColors.primaryGreen;

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
      ThemeManager.instance.getTextStyle(FontSizeType.medium, fontWeight: FontWeight.w600, context: context),
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
