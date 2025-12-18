import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 卡片主题配置
class CardThemeConfig {
  CardThemeConfig._();

  /// 亮色主题 - 卡片配置
  static CardThemeData get lightTheme => CardThemeData(
    color: AppColors.lightSurface,
    surfaceTintColor: AppColors.lightSurface,
    shadowColor: AppColors.lightBorder.withValues(alpha: 0.2),
    elevation: 0,
    margin: const EdgeInsets.all(8),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: AppColors.lightBorder,
        width: 1,
      ),
    ),
  );

  /// 暗色主题 - 卡片配置
  static CardThemeData get darkTheme => CardThemeData(
    color: AppColors.darkSurface,
    surfaceTintColor: AppColors.darkSurface,
    shadowColor: AppColors.darkBorder.withValues(alpha: 0.2),
    elevation: 0,
    margin: const EdgeInsets.all(8),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: AppColors.darkBorder,
        width: 1,
      ),
    ),
  );

  /// 获取自定义卡片样式
  static BoxDecoration getCustomCardDecoration({
    bool isDark = false,
    double borderRadius = 12,
    bool hasBorder = true,
    bool hasShadow = false,
  }) {
    return BoxDecoration(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderRadius: BorderRadius.circular(borderRadius),
      border: hasBorder
          ? Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            )
          : null,
      boxShadow: hasShadow
          ? [
              BoxShadow(
              color: (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                  .withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
          : null,
    );
  }
}