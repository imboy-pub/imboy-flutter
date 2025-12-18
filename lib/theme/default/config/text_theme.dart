import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 文本主题配置
class TextThemeConfig {
  TextThemeConfig._();

  /// 亮色主题 - 文本主题配置（静态版本，向后兼容）
  static TextTheme get lightTheme => getLightTheme();

  /// 暗色主题 - 文本主题配置（静态版本，向后兼容）
  static TextTheme get darkTheme => getDarkTheme();

  /// 获取亮色主题文本配置（支持动态字体缩放）
  ///
  /// [fontScale] 字体缩放比例，默认为 1.0
  /// [context] 构建上下文，用于响应式缩放（可选）
  static TextTheme getLightTheme({
    double fontScale = 1.0,
    BuildContext? context,
  }) {
    return _buildTextTheme(
      isDark: false,
      fontScale: fontScale,
      context: context,
    );
  }

  /// 获取暗色主题文本配置（支持动态字体缩放）
  ///
  /// [fontScale] 字体缩放比例，默认为 1.0
  /// [context] 构建上下文，用于响应式缩放（可选）
  static TextTheme getDarkTheme({
    double fontScale = 1.0,
    BuildContext? context,
  }) {
    return _buildTextTheme(
      isDark: true,
      fontScale: fontScale,
      context: context,
    );
  }

  /// 根据 FontSizeOption 获取亮色主题
  static TextTheme getLightThemeFromOption(
    FontSizeOption option, {
    BuildContext? context,
  }) {
    return getLightTheme(fontScale: option.scale, context: context);
  }

  /// 根据 FontSizeOption 获取暗色主题
  static TextTheme getDarkThemeFromOption(
    FontSizeOption option, {
    BuildContext? context,
  }) {
    return getDarkTheme(fontScale: option.scale, context: context);
  }

  /// 构建文本主题的核心方法
  static TextTheme _buildTextTheme({
    required bool isDark,
    double fontScale = 1.0,
    BuildContext? context,
  }) {
    // 获取颜色配置
    final primaryColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final secondaryColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final disabledColor = isDark
        ? AppColors.darkTextDisabled
        : AppColors.lightTextDisabled;

    // 应用安全的字体缩放
    final safeScale = FontScaleCalculator.getSafeScale(fontScale);

    return TextTheme(
      // Material 3 Display 样式 - 大标题
      displayLarge: TextStyle(
        fontSize: FontScaleCalculator.calculateScaledSize(
          57, // Material 3 标准
          safeScale,
          context: context,
        ),
        fontWeight: FontWeight.w400, // Material 3 Regular
        color: primaryColor,
        fontFamily: 'PingFang SC',
        height: 1.12, // Material 3 行高
        letterSpacing: -0.25,
      ),
      displayMedium: TextStyle(
        fontSize: FontScaleCalculator.calculateScaledSize(
          45, // Material 3 标准
          safeScale,
          context: context,
        ),
        fontWeight: FontWeight.w400, // Material 3 Regular
        color: primaryColor,
        fontFamily: 'PingFang SC',
        height: 1.16, // Material 3 行高
        letterSpacing: 0,
      ),
      displaySmall: TextStyle(
        fontSize: FontScaleCalculator.calculateScaledSize(
          36, // Material 3 标准
          safeScale,
          context: context,
        ),
        fontWeight: FontWeight.w400, // Material 3 Regular
        color: primaryColor,
        fontFamily: 'PingFang SC',
        height: 1.22, // Material 3 行高
        letterSpacing: 0,
      ),

      // Material 3 Headline 样式 - 标题
      headlineLarge: TextStyle(
        fontSize: FontScaleCalculator.calculateScaledSize(
          32, // Material 3 标准
          safeScale,
          context: context,
        ),
        fontWeight: FontWeight.w400, // Material 3 Regular
        color: primaryColor,
        fontFamily: 'PingFang SC',
        height: 1.25, // Material 3 行高
        letterSpacing: 0,
      ),
      headlineMedium: TextStyle(
        fontSize: FontScaleCalculator.calculateScaledSize(
          28, // Material 3 标准
          safeScale,
          context: context,
        ),
        fontWeight: FontWeight.w400, // Material 3 Regular
        color: primaryColor,
        fontFamily: 'PingFang SC',
        height: 1.29, // Material 3 行高
        letterSpacing: 0,
      ),
      headlineSmall: TextStyle(
        fontSize: FontScaleCalculator.calculateScaledSize(
          24, // Material 3 标准
          safeScale,
          context: context,
        ),
        fontWeight: FontWeight.w400, // Material 3 Regular
        color: primaryColor,
        fontFamily: 'PingFang SC',
        height: 1.33, // Material 3 行高
        letterSpacing: 0,
      ),

      // Material 3 Title 样式 - 小标题
      titleLarge: TextStyle(
        fontSize: FontScaleCalculator.calculateScaledSize(
          22, // Material 3 标准
          safeScale,
          context: context,
        ),
        fontWeight: FontWeight.w400, // Material 3 Regular
        color: primaryColor,
        fontFamily: 'PingFang SC',
        height: 1.27, // Material 3 行高
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        fontSize: FontScaleCalculator.calculateScaledSize(
          16, // Material 3 标准
          safeScale,
          context: context,
        ),
        fontWeight: FontWeight.w500, // Material 3 Medium
        color: primaryColor,
        fontFamily: 'PingFang SC',
        height: 1.50, // Material 3 行高
        letterSpacing: 0.15,
      ),
      titleSmall: TextStyle(
        fontSize: FontScaleCalculator.calculateScaledSize(
          14, // Material 3 标准
          safeScale,
          context: context,
        ),
        fontWeight: FontWeight.w500, // Material 3 Medium
        color: primaryColor,
        fontFamily: 'PingFang SC',
        height: 1.43, // Material 3 行高
        letterSpacing: 0.1,
      ),

      // Material 3 Body 样式 - 正文
      bodyLarge: TextStyle(
        fontSize: FontScaleCalculator.calculateScaledSize(
          16, // Material 3 标准
          safeScale,
          context: context,
        ),
        fontWeight: FontWeight.w400, // Material 3 Regular
        color: primaryColor,
        fontFamily: 'PingFang SC',
        height: 1.50, // Material 3 行高
        letterSpacing: 0.5,
      ),
      bodyMedium: TextStyle(
        fontSize: FontScaleCalculator.calculateScaledSize(
          14, // Material 3 标准
          safeScale,
          context: context,
        ),
        fontWeight: FontWeight.w400, // Material 3 Regular
        color: primaryColor,
        fontFamily: 'PingFang SC',
        height: 1.43, // Material 3 行高
        letterSpacing: 0.25,
      ),
      bodySmall: TextStyle(
        fontSize: FontScaleCalculator.calculateScaledSize(
          12, // Material 3 标准
          safeScale,
          context: context,
        ),
        fontWeight: FontWeight.w400, // Material 3 Regular
        color: secondaryColor,
        fontFamily: 'PingFang SC',
        height: 1.33, // Material 3 行高
        letterSpacing: 0.4,
      ),

      // Material 3 Label 样式 - 标签
      labelLarge: TextStyle(
        fontSize: FontScaleCalculator.calculateScaledSize(
          14, // Material 3 标准
          safeScale,
          context: context,
        ),
        fontWeight: FontWeight.w500, // Material 3 Medium
        color: primaryColor,
        fontFamily: 'PingFang SC',
        height: 1.43, // Material 3 行高
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        fontSize: FontScaleCalculator.calculateScaledSize(
          12, // Material 3 标准
          safeScale,
          context: context,
        ),
        fontWeight: FontWeight.w500, // Material 3 Medium
        color: secondaryColor,
        fontFamily: 'PingFang SC',
        height: 1.33, // Material 3 行高
        letterSpacing: 0.5,
      ),
      labelSmall: TextStyle(
        fontSize: FontScaleCalculator.calculateScaledSize(
          11, // Material 3 标准
          safeScale,
          context: context,
        ),
        fontWeight: FontWeight.w500, // Material 3 Medium
        color: disabledColor,
        fontFamily: 'PingFang SC',
        height: 1.45, // Material 3 行高
        letterSpacing: 0.5,
      ),
    );
  }

  /// 使用 copyWith 方法动态调整现有 TextTheme 的字体大小
  ///
  /// [baseTheme] 基础文本主题
  /// [fontScale] 字体缩放比例
  /// [context] 构建上下文（可选）
  static TextTheme scaleTextTheme(
    TextTheme baseTheme,
    double fontScale, {
    BuildContext? context,
  }) {
    final safeScale = FontScaleCalculator.getSafeScale(fontScale);

    return baseTheme.copyWith(
      displayLarge: (baseTheme.displayLarge ?? const TextStyle()).copyWith(
        fontSize: FontScaleCalculator.calculateScaledSize(
          baseTheme.displayLarge?.fontSize ?? 32,
          safeScale,
          context: context,
        ),
      ),
      displayMedium: (baseTheme.displayMedium ?? const TextStyle()).copyWith(
        fontSize: FontScaleCalculator.calculateScaledSize(
          baseTheme.displayMedium?.fontSize ?? 28,
          safeScale,
          context: context,
        ),
      ),
      displaySmall: (baseTheme.displaySmall ?? const TextStyle()).copyWith(
        fontSize: FontScaleCalculator.calculateScaledSize(
          baseTheme.displaySmall?.fontSize ?? 24,
          safeScale,
          context: context,
        ),
      ),
      headlineLarge: (baseTheme.headlineLarge ?? const TextStyle()).copyWith(
        fontSize: FontScaleCalculator.calculateScaledSize(
          baseTheme.headlineLarge?.fontSize ?? 22,
          safeScale,
          context: context,
        ),
      ),
      headlineMedium: (baseTheme.headlineMedium ?? const TextStyle()).copyWith(
        fontSize: FontScaleCalculator.calculateScaledSize(
          baseTheme.headlineMedium?.fontSize ?? 20,
          safeScale,
          context: context,
        ),
      ),
      headlineSmall: (baseTheme.headlineSmall ?? const TextStyle()).copyWith(
        fontSize: FontScaleCalculator.calculateScaledSize(
          baseTheme.headlineSmall?.fontSize ?? 18,
          safeScale,
          context: context,
        ),
      ),
      titleLarge: (baseTheme.titleLarge ?? const TextStyle()).copyWith(
        fontSize: FontScaleCalculator.calculateScaledSize(
          baseTheme.titleLarge?.fontSize ?? 16,
          safeScale,
          context: context,
        ),
      ),
      titleMedium: (baseTheme.titleMedium ?? const TextStyle()).copyWith(
        fontSize: FontScaleCalculator.calculateScaledSize(
          baseTheme.titleMedium?.fontSize ?? 14,
          safeScale,
          context: context,
        ),
      ),
      titleSmall: (baseTheme.titleSmall ?? const TextStyle()).copyWith(
        fontSize: FontScaleCalculator.calculateScaledSize(
          baseTheme.titleSmall?.fontSize ?? 12,
          safeScale,
          context: context,
        ),
      ),
      bodyLarge: (baseTheme.bodyLarge ?? const TextStyle()).copyWith(
        fontSize: FontScaleCalculator.calculateScaledSize(
          baseTheme.bodyLarge?.fontSize ?? 16,
          safeScale,
          context: context,
        ),
      ),
      bodyMedium: (baseTheme.bodyMedium ?? const TextStyle()).copyWith(
        fontSize: FontScaleCalculator.calculateScaledSize(
          baseTheme.bodyMedium?.fontSize ?? 14,
          safeScale,
          context: context,
        ),
      ),
      bodySmall: (baseTheme.bodySmall ?? const TextStyle()).copyWith(
        fontSize: FontScaleCalculator.calculateScaledSize(
          baseTheme.bodySmall?.fontSize ?? 12,
          safeScale,
          context: context,
        ),
      ),
      labelLarge: (baseTheme.labelLarge ?? const TextStyle()).copyWith(
        fontSize: FontScaleCalculator.calculateScaledSize(
          baseTheme.labelLarge?.fontSize ?? 14,
          safeScale,
          context: context,
        ),
      ),
      labelMedium: (baseTheme.labelMedium ?? const TextStyle()).copyWith(
        fontSize: FontScaleCalculator.calculateScaledSize(
          baseTheme.labelMedium?.fontSize ?? 12,
          safeScale,
          context: context,
        ),
      ),
      labelSmall: (baseTheme.labelSmall ?? const TextStyle()).copyWith(
        fontSize: FontScaleCalculator.calculateScaledSize(
          baseTheme.labelSmall?.fontSize ?? 12, // 改为12以符合可访问性标准
          safeScale,
          context: context,
        ),
      ),
    );
  }

  /// 验证文本主题的可访问性
  ///
  /// [textTheme] 要验证的文本主题
  /// 返回不符合可访问性标准的样式名称列表
  static List<String> validateAccessibility(TextTheme textTheme) {
    final issues = <String>[];

    final styles = {
      'displayLarge': textTheme.displayLarge,
      'displayMedium': textTheme.displayMedium,
      'displaySmall': textTheme.displaySmall,
      'headlineLarge': textTheme.headlineLarge,
      'headlineMedium': textTheme.headlineMedium,
      'headlineSmall': textTheme.headlineSmall,
      'titleLarge': textTheme.titleLarge,
      'titleMedium': textTheme.titleMedium,
      'titleSmall': textTheme.titleSmall,
      'bodyLarge': textTheme.bodyLarge,
      'bodyMedium': textTheme.bodyMedium,
      'bodySmall': textTheme.bodySmall,
      'labelLarge': textTheme.labelLarge,
      'labelMedium': textTheme.labelMedium,
      'labelSmall': textTheme.labelSmall,
    };

    styles.forEach((name, style) {
      if (style?.fontSize != null &&
          !FontScaleCalculator.isAccessibleSize(style!.fontSize!)) {
        issues.add(name);
      }
    });

    return issues;
  }
}
