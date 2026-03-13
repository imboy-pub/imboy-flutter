import 'package:flutter/material.dart';

import './config/component_theme_manager.dart';
import './config/text_theme.dart';
import './font_types.dart';

import 'app_colors.dart';
import '../dynamic_color_manager.dart';

/// 应用主题配置类
/// 统一组装各个组件的主题配置，提供完整的亮色/暗色主题
class AppTheme {
  AppTheme._(); // 私有构造函数，防止实例化

  // ==================== 私有辅助方法 ====================

  // ==================== 动态主题方法 ====================

  /// 获取亮色主题（支持动态字体缩放）
  ///
  /// [fontScale] 字体缩放比例，默认为 1.0
  /// [context] 构建上下文，用于响应式缩放（可选）
  static ThemeData getLightTheme({
    double fontScale = 1.0,
    BuildContext? context,
  }) {
    return _buildTheme(isDark: false, fontScale: fontScale, context: context);
  }

  /// 获取暗色主题（支持动态字体缩放）
  ///
  /// [fontScale] 字体缩放比例，默认为 1.0
  /// [context] 构建上下文，用于响应式缩放（可选）
  static ThemeData getDarkTheme({
    double fontScale = 1.0,
    BuildContext? context,
  }) {
    return _buildTheme(isDark: true, fontScale: fontScale, context: context);
  }

  /// 获取带动态颜色的亮色主题
  ///
  /// [fontScale] 字体缩放比例，默认为 1.0
  /// [context] 构建上下文，用于响应式缩放（可选）
  /// [useDynamicColor] 是否使用动态颜色，默认为 true
  static Future<ThemeData> getLightThemeWithDynamicColor({
    double fontScale = 1.0,
    BuildContext? context,
    bool useDynamicColor = true,
  }) async {
    return await _buildThemeWithDynamicColor(
      isDark: false,
      fontScale: fontScale,
      context: context,
      useDynamicColor: useDynamicColor,
    );
  }

  /// 获取带动态颜色的暗色主题
  ///
  /// [fontScale] 字体缩放比例，默认为 1.0
  /// [context] 构建上下文，用于响应式缩放（可选）
  /// [useDynamicColor] 是否使用动态颜色，默认为 true
  static Future<ThemeData> getDarkThemeWithDynamicColor({
    double fontScale = 1.0,
    BuildContext? context,
    bool useDynamicColor = true,
  }) async {
    return await _buildThemeWithDynamicColor(
      isDark: true,
      fontScale: fontScale,
      context: context,
      useDynamicColor: useDynamicColor,
    );
  }

  /// 根据 FontSizeOption 获取亮色主题
  static ThemeData getLightThemeFromOption(
    FontSizeOption option, {
    BuildContext? context,
  }) {
    return getLightTheme(fontScale: option.scale, context: context);
  }

  /// 根据 FontSizeOption 获取暗色主题
  static ThemeData getDarkThemeFromOption(
    FontSizeOption option, {
    BuildContext? context,
  }) {
    return getDarkTheme(fontScale: option.scale, context: context);
  }

  // ==================== 核心主题构建方法 ====================

  /// 构建主题的核心方法
  ///
  /// [isDark] 是否为暗色主题
  /// [fontScale] 字体缩放比例
  /// [context] 构建上下文（可选）
  static ThemeData _buildTheme({
    required bool isDark,
    double fontScale = 1.0,
    BuildContext? context,
  }) {
    // 获取动态文本主题
    final textTheme = isDark
        ? TextThemeConfig.getDarkTheme(fontScale: fontScale, context: context)
        : TextThemeConfig.getLightTheme(fontScale: fontScale, context: context);

    // 获取基础主题
    final baseTheme = isDark ? _baseDarkTheme : _baseLightTheme;

    // 返回带有动态文本主题的完整主题
    return baseTheme.copyWith(textTheme: textTheme);
  }

  /// 构建带动态颜色的主题
  ///
  /// [isDark] 是否为暗色主题
  /// [fontScale] 字体缩放比例
  /// [context] 构建上下文（可选）
  /// [useDynamicColor] 是否使用动态颜色
  static Future<ThemeData> _buildThemeWithDynamicColor({
    required bool isDark,
    double fontScale = 1.0,
    BuildContext? context,
    bool useDynamicColor = true,
  }) async {
    // 获取动态文本主题
    final textTheme = isDark
        ? TextThemeConfig.getDarkTheme(fontScale: fontScale, context: context)
        : TextThemeConfig.getLightTheme(fontScale: fontScale, context: context);

    // 获取动态颜色方案
    final dynamicColorScheme = await DynamicColorManager.instance
        .createColorScheme(isDark: isDark, useDynamicColor: useDynamicColor);

    // 获取基础主题
    final baseTheme = isDark ? _baseDarkTheme : _baseLightTheme;

    // 返回带有动态颜色和文本主题的完整主题
    return baseTheme.copyWith(
      colorScheme: dynamicColorScheme,
      textTheme: textTheme,
    );
  }

  /// 基础亮色主题（不包含动态文本主题）
  static ThemeData get _baseLightTheme {
    const isDark = false;
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      // 使用系统字体，避免 Flutter Web 加载 Google Fonts CDN 的 Roboto 字体
      fontFamily: '', // 空字符串表示使用系统默认字体
      scaffoldBackgroundColor: AppColors.lightSurface, // 确保Scaffold背景一致
      // 1. Material 3 完整颜色方案
      colorScheme: ColorScheme.light(
        // Primary colors - 主色系
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,

        // Secondary colors - 次要色系
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,

        // Tertiary colors - 第三色系
        tertiary: AppColors.tertiary,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiaryContainer: AppColors.onTertiaryContainer,

        // Error colors - 错误色系
        error: AppColors.lightError,
        onError: Colors.white,
        errorContainer: AppColors.lightErrorContainer,
        onErrorContainer: AppColors.lightOnErrorContainer,

        // Surface colors - 表面色系
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        onSurfaceVariant: AppColors.lightTextSecondary,
        surfaceContainerHighest: AppColors.lightSurfaceContainerHighest,

        // Outline colors - 轮廓色系
        outline: AppColors.lightBorder,
        outlineVariant: AppColors.lightDivider,
      ),

      // 2. 图标主题
      iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
      primaryIconTheme: IconThemeData(color: Colors.white),

      // 3. 应用栏主题
      appBarTheme: ComponentThemeManager.getAppBarTheme(isDark: isDark),

      // 4. 底部导航栏
      bottomNavigationBarTheme:
          ComponentThemeManager.getBottomNavigationBarTheme(
            isDark: isDark,
            fontSizeOption: null,
          ),

      // 5. 按钮主题
      elevatedButtonTheme: ComponentThemeManager.getElevatedButtonTheme(
        isDark: isDark,
      ),
      textButtonTheme: ComponentThemeManager.getTextButtonTheme(isDark: isDark),
      outlinedButtonTheme: ComponentThemeManager.getOutlinedButtonTheme(
        isDark: isDark,
      ),
      floatingActionButtonTheme:
          ComponentThemeManager.getFloatingActionButtonTheme(isDark: isDark),

      // 6. 卡片主题
      cardTheme: ComponentThemeManager.getCardTheme(isDark: isDark),

      // 7. 输入框主题
      inputDecorationTheme: ComponentThemeManager.getInputDecorationTheme(
        isDark: isDark,
      ),

      // 8. 其他组件主题
      dividerTheme: ComponentThemeManager.getDividerTheme(isDark: isDark),
      chipTheme: ComponentThemeManager.getChipTheme(isDark: isDark),
      progressIndicatorTheme: ComponentThemeManager.getProgressIndicatorTheme(
        isDark: isDark,
      ),
      listTileTheme: ComponentThemeManager.getListTileTheme(isDark: isDark),

      // 9. 页面过渡主题 - 启用 iOS 风格的滑动返回
      pageTransitionsTheme: _pageTransitionsTheme,
    );
  }

  /// 基础暗色主题（不包含动态文本主题）
  static ThemeData get _baseDarkTheme {
    const isDark = true;
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      // 使用系统字体，避免 Flutter Web 加载 Google Fonts CDN 的 Roboto 字体
      fontFamily: '', // 空字符串表示使用系统默认字体
      // 1. Material 3 完整颜色方案 - 暗色模式
      colorScheme: ColorScheme.dark(
        // Primary colors - 主色系
        primary: AppColors.primaryLight,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryDark,
        onPrimaryContainer: AppColors.onPrimaryContainer,

        // Secondary colors - 次要色系
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,

        // Tertiary colors - 第三色系
        tertiary: AppColors.tertiary,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiaryContainer: AppColors.onTertiaryContainer,

        // Error colors - 错误色系
        error: AppColors.darkError,
        onError: Colors.black,
        errorContainer: AppColors.darkErrorContainer,
        onErrorContainer: AppColors.darkOnErrorContainer,

        // Surface colors - 表面色系
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        onSurfaceVariant: AppColors.darkTextSecondary,
        surfaceContainerHighest: AppColors.darkSurfaceContainerHighest,

        // Outline colors - 轮廓色系
        outline: AppColors.darkBorder,
        outlineVariant: AppColors.darkDivider,
      ),

      // 2. 图标主题
      iconTheme: IconThemeData(color: AppColors.primaryLight),
      primaryIconTheme: IconThemeData(color: Colors.white),

      // 3. 应用栏主题
      appBarTheme: ComponentThemeManager.getAppBarTheme(isDark: isDark),

      // 4. 底部导航栏
      bottomNavigationBarTheme:
          ComponentThemeManager.getBottomNavigationBarTheme(
            isDark: isDark,
            fontSizeOption: null,
          ),

      // 5. 按钮主题
      elevatedButtonTheme: ComponentThemeManager.getElevatedButtonTheme(
        isDark: isDark,
      ),
      textButtonTheme: ComponentThemeManager.getTextButtonTheme(isDark: isDark),
      outlinedButtonTheme: ComponentThemeManager.getOutlinedButtonTheme(
        isDark: isDark,
      ),
      floatingActionButtonTheme:
          ComponentThemeManager.getFloatingActionButtonTheme(isDark: isDark),

      // 6. 卡片主题
      cardTheme: ComponentThemeManager.getCardTheme(isDark: isDark),

      // 7. 输入框主题
      inputDecorationTheme: ComponentThemeManager.getInputDecorationTheme(
        isDark: isDark,
      ),

      // 8. 其他组件主题
      dividerTheme: ComponentThemeManager.getDividerTheme(isDark: isDark),
      chipTheme: ComponentThemeManager.getChipTheme(isDark: isDark),
      progressIndicatorTheme: ComponentThemeManager.getProgressIndicatorTheme(
        isDark: isDark,
      ),
      listTileTheme: ComponentThemeManager.getListTileTheme(isDark: isDark),
    );
  }

  /// 使用 copyWith 方法动态调整现有主题的字体大小
  ///
  /// [baseTheme] 基础主题
  /// [fontScale] 字体缩放比例
  /// [context] 构建上下文（可选）
  static ThemeData scaleTheme(
    ThemeData baseTheme,
    double fontScale, {
    BuildContext? context,
  }) {
    final scaledTextTheme = TextThemeConfig.scaleTextTheme(
      baseTheme.textTheme,
      fontScale,
      context: context,
    );

    return baseTheme.copyWith(textTheme: scaledTextTheme);
  }

  /// 验证主题的可访问性
  ///
  /// [theme] 要验证的主题
  /// 返回不符合可访问性标准的样式名称列表
  static List<String> validateThemeAccessibility(ThemeData theme) {
    return TextThemeConfig.validateAccessibility(theme.textTheme);
  }

  /// 页面过渡主题 - 统一的 iOS 风格滑动返回
  ///
  /// 为所有平台启用 iOS 风格的页面过渡，提供一致的向右滑动返回体验
  static const PageTransitionsTheme _pageTransitionsTheme =
      PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          // iOS 使用 Cupertino 风格过渡（原生支持右滑返回）
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          // Android 也使用 Cupertino 风格以获得右滑返回支持
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          // 桌面平台也使用 Cupertino 风格
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      );
}
