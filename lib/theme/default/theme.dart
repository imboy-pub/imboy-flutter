import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import './config/component_theme_manager.dart';
import './config/text_theme.dart';
import './font_types.dart';

import 'app_colors.dart';

/// 应用主题配置类 - 增强版 (Systematic UI Repair)
class AppTheme {
  AppTheme._();

  /// F5（PERF-05 R6b）：Cupertino 全角色文本样式挂 NotoSansSC 子集回退链。
  ///
  /// 逐字段复刻 SDK 默认（cupertino/text_theme.dart 的
  /// `_kDefault*TextStyle` 常量与 `_TextThemeDefaultsBuilder` 派生口径），
  /// 仅补 `fontFamilyFallback` 首位挂内嵌 NotoSansSC 子集。
  ///
  /// 为什么这是 fonts.gstatic 外拉的缺口：'CupertinoSystemText'/'CupertinoSystemDisplay'
  /// 在 web 未注册，且 SDK 各角色默认样式不带任何 fallback——
  /// CupertinoNavigationBar 标题、CupertinoTextField、CupertinoDialog/
  /// DialogAction、CupertinoPicker 等全部 Cupertino 组件的中文文本走
  /// 「字族未命中 → 引擎默认字体 → CanvasKit gstatic Noto 分片」
  /// （netlog 117/118 实锤）。挂链后子集本地命中，外拉归零。
  /// Apple 原生端系统字族照常命中，渲染零变化。
  ///
  /// 必须逐角色提供：CupertinoTextThemeData 的派生样式**不与 textStyle
  /// 合并**（`navTitleTextStyle => _navTitleTextStyle ?? _defaults.navTitleTextStyle`），
  /// 只给 textStyle 时其余角色仍走无链的 SDK 硬编码默认。
  /// 颜色口径：label/inactiveGray 沿用 SDK 动态色（亮暗语义不变）；
  /// action/navAction/actionSmall 按 `_TextThemeDefaultsBuilder` 的
  /// `copyWith(color: primaryColor)` 派生口径用 primaryDark（DSN-03
  /// 主色决策）着色，避免改色回归。
  static CupertinoTextThemeData get _cupertinoTextTheme {
    const chain = kAppFontFamilyFallback;
    const primaryActionColor = AppColors.primaryDark;
    return const CupertinoTextThemeData(
      textStyle: TextStyle(
        inherit: false,
        fontFamily: 'CupertinoSystemText',
        fontSize: 17.0,
        letterSpacing: -0.41,
        color: CupertinoColors.label,
        decoration: TextDecoration.none,
        fontFamilyFallback: chain,
      ),
      tabLabelTextStyle: TextStyle(
        inherit: false,
        fontFamily: 'CupertinoSystemText',
        fontSize: 10.0,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.24,
        color: CupertinoColors.inactiveGray,
        fontFamilyFallback: chain,
      ),
      navTitleTextStyle: TextStyle(
        inherit: false,
        fontFamily: 'CupertinoSystemText',
        fontSize: 17.0,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.41,
        color: CupertinoColors.label,
        fontFamilyFallback: chain,
      ),
      navLargeTitleTextStyle: TextStyle(
        inherit: false,
        fontFamily: 'CupertinoSystemDisplay',
        fontSize: 34.0,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.38,
        color: CupertinoColors.label,
        fontFamilyFallback: chain,
      ),
      pickerTextStyle: TextStyle(
        inherit: false,
        fontFamily: 'CupertinoSystemDisplay',
        fontSize: 21.0,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.6,
        color: CupertinoColors.label,
        fontFamilyFallback: chain,
      ),
      dateTimePickerTextStyle: TextStyle(
        inherit: false,
        fontFamily: 'CupertinoSystemDisplay',
        fontSize: 21.0,
        letterSpacing: 0.4,
        fontWeight: FontWeight.normal,
        color: CupertinoColors.label,
        fontFamilyFallback: chain,
      ),
      actionTextStyle: TextStyle(
        inherit: false,
        fontFamily: 'CupertinoSystemText',
        fontSize: 17.0,
        letterSpacing: -0.41,
        color: primaryActionColor,
        decoration: TextDecoration.none,
        fontFamilyFallback: chain,
      ),
      navActionTextStyle: TextStyle(
        inherit: false,
        fontFamily: 'CupertinoSystemText',
        fontSize: 17.0,
        letterSpacing: -0.41,
        color: primaryActionColor,
        decoration: TextDecoration.none,
        fontFamilyFallback: chain,
      ),
      actionSmallTextStyle: TextStyle(
        inherit: false,
        fontFamily: 'CupertinoSystemText',
        fontSize: 15.0,
        letterSpacing: -0.23,
        color: primaryActionColor,
        decoration: TextDecoration.none,
        fontFamilyFallback: chain,
      ),
    );
  }

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
        // F5（PERF-05 R6b）：Cupertino 全组件文本挂 NotoSansSC 回退链。
        textTheme: _cupertinoTextTheme,
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
        // F5（PERF-05 R6b）：同亮色主题，Cupertino 全组件文本挂回退链。
        textTheme: _cupertinoTextTheme,
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
