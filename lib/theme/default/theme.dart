import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import './config/component_theme_manager.dart';
import './config/text_theme.dart';
import './font_types.dart';

import 'app_colors.dart';

/// 应用主题配置类 - 增强版 (Systematic UI Repair)
class AppTheme {
  AppTheme._();

  static ThemeData getLightTheme({
    double fontScale = 1.0,
    BuildContext? context,
  }) {
    return _buildTheme(isDark: false, fontScale: fontScale, context: context);
  }

  static ThemeData getDarkTheme({
    double fontScale = 1.0,
    BuildContext? context,
  }) {
    return _buildTheme(isDark: true, fontScale: fontScale, context: context);
  }

  /// 兼容旧代码的方法
  static ThemeData getLightThemeFromOption(
    FontSizeOption option, {
    BuildContext? context,
  }) {
    return getLightTheme(fontScale: option.scale, context: context);
  }

  /// 兼容旧代码的方法
  static ThemeData getDarkThemeFromOption(
    FontSizeOption option, {
    BuildContext? context,
  }) {
    return getDarkTheme(fontScale: option.scale, context: context);
  }

  static ThemeData _buildTheme({
    required bool isDark,
    double fontScale = 1.0,
    BuildContext? context,
  }) {
    final baseTheme = isDark ? _baseDarkTheme : _baseLightTheme;
    final textTheme = isDark
        ? TextThemeConfig.getDarkTheme(fontScale: fontScale, context: context)
        : TextThemeConfig.getLightTheme(fontScale: fontScale, context: context);

    // F5（PERF-05）：TextThemeConfig 构建的样式不带 fontFamilyFallback，
    // copyWith 覆盖后 ThemeData 级回退链会丢——这里对最终 TextTheme 逐样式
    // 再挂一次，保证 NotoSansSC 子集在全部 role 生效。
    return baseTheme.copyWith(
      textTheme: textTheme.apply(fontFamilyFallback: kAppFontFamilyFallback),
    );
  }

  static ThemeData get _baseLightTheme {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      // F5（PERF-05）：全局字体回退链首位挂内嵌 NotoSansSC 中文子集，
      // 阻断 CanvasKit 对 fonts.gstatic 的动态字体拉取（见 kAppFontFamilyFallback）。
      fontFamilyFallback: kAppFontFamilyFallback,
      scaffoldBackgroundColor: AppColors.lightSurfaceGrouped,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.iosBlue,
        onSecondary: Colors.white,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        onSurfaceVariant: AppColors.lightTextSecondary,
        error: AppColors.lightError,
        onError: Colors.white,
        outline: AppColors.iosSeparator,
        outlineVariant: AppColors.lightDivider,
        surfaceContainerLow: AppColors.lightSurfaceContainerLow,
        surfaceContainer: AppColors.lightSurfaceContainer,
        surfaceContainerHighest: AppColors.lightSurfaceGrouped,
      ),
      appBarTheme: ComponentThemeManager.getAppBarTheme(isDark: false),
      elevatedButtonTheme: ComponentThemeManager.getElevatedButtonTheme(
        isDark: false,
      ),
      textButtonTheme: ComponentThemeManager.getTextButtonTheme(isDark: false),
      inputDecorationTheme: ComponentThemeManager.getInputDecorationTheme(
        isDark: false,
      ),
      listTileTheme: ComponentThemeManager.getListTileTheme(isDark: false),
      dividerTheme: DividerThemeData(
        color: AppColors.iosSeparator,
        thickness: 0.33,
        space: 1,
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        // DSN-03 DEV-1/DEV-2（属主裁决 2026-11-16「三项全修」）：Cupertino 系
        // 主色（登录 CTA 填充、CupertinoDialogAction 默认动作等）改 primaryDark
        // （#1565C0 on #FFFFFF = 5.746 ≥ 4.5）；Material 侧保持品牌蓝 primary。
        primaryColor: AppColors.primaryDark,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightBackground,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get _baseDarkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      // F5（PERF-05）：同亮色主题，全局挂内嵌 NotoSansSC 中文子集回退。
      fontFamilyFallback: kAppFontFamilyFallback,
      scaffoldBackgroundColor: AppColors.darkSurfaceGrouped,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.iosBlueDark,
        onSecondary: Colors.white,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        onSurfaceVariant: AppColors.darkTextSecondary,
        error: AppColors.darkError,
        onError: Colors.white,
        outline: AppColors.iosSeparatorDark,
        outlineVariant: AppColors.darkDivider,
        surfaceContainerLow: AppColors.darkSurface,
        surfaceContainer: AppColors.darkSurfaceContainer,
        surfaceContainerHighest: AppColors.darkSurfaceContainerHighest,
      ),
      appBarTheme: ComponentThemeManager.getAppBarTheme(isDark: true),
      elevatedButtonTheme: ComponentThemeManager.getElevatedButtonTheme(
        isDark: true,
      ),
      textButtonTheme: ComponentThemeManager.getTextButtonTheme(isDark: true),
      inputDecorationTheme: ComponentThemeManager.getInputDecorationTheme(
        isDark: true,
      ),
      listTileTheme: ComponentThemeManager.getListTileTheme(isDark: true),
      dividerTheme: DividerThemeData(
        color: AppColors.iosSeparatorDark,
        thickness: 0.33,
        space: 1,
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        // 同亮色主题注释：Cupertino 主色统一 primaryDark（DEV-1/DEV-2）。
        primaryColor: AppColors.primaryDark,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkSurfaceGrouped,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }
}
