import 'package:flutter/material.dart';

import './config/component_theme_manager.dart';
import './config/text_theme.dart';
import './font_types.dart';

import 'app_colors.dart';
import '../dynamic_color_manager.dart';

/// 应用主题配置类 - 增强版 (Systematic UI Repair)
class AppTheme {
  AppTheme._();

  static ThemeData getLightTheme({double fontScale = 1.0, BuildContext? context}) {
    return _buildTheme(isDark: false, fontScale: fontScale, context: context);
  }

  static ThemeData getDarkTheme({double fontScale = 1.0, BuildContext? context}) {
    return _buildTheme(isDark: true, fontScale: fontScale, context: context);
  }

  /// 兼容旧代码的方法
  static ThemeData getLightThemeFromOption(FontSizeOption option, {BuildContext? context}) {
    return getLightTheme(fontScale: option.scale, context: context);
  }

  /// 兼容旧代码的方法
  static ThemeData getDarkThemeFromOption(FontSizeOption option, {BuildContext? context}) {
    return getDarkTheme(fontScale: option.scale, context: context);
  }

  static ThemeData _buildTheme({required bool isDark, double fontScale = 1.0, BuildContext? context}) {
    final baseTheme = isDark ? _baseDarkTheme : _baseLightTheme;
    final textTheme = isDark
        ? TextThemeConfig.getDarkTheme(fontScale: fontScale, context: context)
        : TextThemeConfig.getLightTheme(fontScale: fontScale, context: context);

    return baseTheme.copyWith(textTheme: textTheme);
  }

  static ThemeData get _baseLightTheme {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.lightSurfaceGrouped,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.iosBlue,
        onSecondary: Colors.white,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        error: AppColors.lightError,
        onError: Colors.white,
        outline: AppColors.iosSeparator,
        surfaceContainerHighest: AppColors.lightSurfaceGrouped,
      ),
      appBarTheme: ComponentThemeManager.getAppBarTheme(isDark: false),
      elevatedButtonTheme: ComponentThemeManager.getElevatedButtonTheme(isDark: false),
      textButtonTheme: ComponentThemeManager.getTextButtonTheme(isDark: false),
      inputDecorationTheme: ComponentThemeManager.getInputDecorationTheme(isDark: false),
      listTileTheme: ComponentThemeManager.getListTileTheme(isDark: false),
      dividerTheme: DividerThemeData(color: AppColors.iosSeparator, thickness: 0.33, space: 1),
    );
  }

  static ThemeData get _baseDarkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.darkSurfaceGrouped,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.iosBlueDark,
        onSecondary: Colors.white,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        error: AppColors.darkError,
        onError: Colors.white,
        outline: AppColors.iosSeparatorDark,
        surfaceContainerHighest: AppColors.darkSurfaceGrouped,
      ),
      appBarTheme: ComponentThemeManager.getAppBarTheme(isDark: true),
      elevatedButtonTheme: ComponentThemeManager.getElevatedButtonTheme(isDark: true),
      textButtonTheme: ComponentThemeManager.getTextButtonTheme(isDark: true),
      inputDecorationTheme: ComponentThemeManager.getInputDecorationTheme(isDark: true),
      listTileTheme: ComponentThemeManager.getListTileTheme(isDark: true),
      dividerTheme: DividerThemeData(color: AppColors.iosSeparatorDark, thickness: 0.33, space: 1),
    );
  }
}
