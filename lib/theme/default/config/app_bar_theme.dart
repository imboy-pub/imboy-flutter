import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/theme_manager.dart';

/// AppBar 主题配置
/// 支持动态字体缩放和 Material 3 设计规范
class AppBarThemeConfig {
  AppBarThemeConfig._();

  /// 亮色主题 AppBar 配置
  static AppBarTheme get lightTheme => getLightTheme();

  /// 获取亮色主题 AppBar 配置（支持动态字体缩放）
  static AppBarTheme getLightTheme({double? fontScale, BuildContext? context}) {
    final scaledTitleSize = ThemeManager.instance.getScaledFontSize(
      FontSizeType.large,
      context: context,
    );

    return AppBarTheme(
      backgroundColor: AppColors.lightAppBarBackground,
      foregroundColor: AppColors.lightTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.lightBorder,
      surfaceTintColor: AppColors.lightAppBarBackground,
      iconTheme: IconThemeData(color: AppColors.lightTextPrimary, size: 24),
      actionsIconTheme: IconThemeData(
        color: AppColors.lightTextPrimary,
        size: 24,
      ),
      titleTextStyle: TextStyle(
        fontSize: scaledTitleSize,
        fontWeight: FontWeight.w600,
        color: AppColors.lightTextPrimary,
        fontFamily: 'PingFang SC',
      ),
      centerTitle: true,
      toolbarHeight: 56,
    );
  }

  /// 暗色主题 AppBar 配置
  static AppBarTheme get darkTheme => getDarkTheme();

  /// 获取暗色主题 AppBar 配置（支持动态字体缩放）
  static AppBarTheme getDarkTheme({double? fontScale, BuildContext? context}) {
    final scaledTitleSize = ThemeManager.instance.getScaledFontSize(
      FontSizeType.large,
      context: context,
    );

    return AppBarTheme(
      backgroundColor: AppColors.darkAppBarBackground,
      foregroundColor: AppColors.darkTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.darkBorder,
      surfaceTintColor: AppColors.darkAppBarBackground,
      iconTheme: IconThemeData(color: AppColors.darkTextPrimary, size: 24),
      actionsIconTheme: IconThemeData(
        color: AppColors.darkTextPrimary,
        size: 24,
      ),
      titleTextStyle: TextStyle(
        fontSize: scaledTitleSize,
        fontWeight: FontWeight.w600,
        color: AppColors.darkTextPrimary,
        fontFamily: 'PingFang SC',
      ),
      centerTitle: true,
      toolbarHeight: 56,
    );
  }
}
