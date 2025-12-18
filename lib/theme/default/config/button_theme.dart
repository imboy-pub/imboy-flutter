import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/theme_manager.dart';

/// 按钮主题配置
/// 支持动态字体缩放和 Material 3 设计规范
class ButtonThemeConfig {
  ButtonThemeConfig._();

  // ==================== 亮色主题按钮配置 ====================

  /// 亮色主题 - 主要按钮（ElevatedButton）
  static ElevatedButtonThemeData get lightElevatedButtonTheme =>
      getLightElevatedButtonTheme();

  /// 获取亮色主题 - 主要按钮（支持动态字体缩放）- Material 3适配
  static ElevatedButtonThemeData getLightElevatedButtonTheme({
    BuildContext? context,
  }) {
    final scaledFontSize = ThemeManager.instance.getScaledFontSize(
      FontSizeType.medium,
      context: context,
    );

    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        // Material 3 颜色系统
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.lightTextDisabled,
        disabledForegroundColor: AppColors.lightTextSecondary,
        // Material 3 高度系统
        elevation: 1, // Material 3 标准高度
        shadowColor: AppColors.lightBorder.withValues(alpha: 0.3),
        // Material 3 形状系统 - 使用统一的圆角
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // Material 3 标准
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        minimumSize: const Size(64, 40), // Material 3 最小尺寸
        textStyle: TextStyle(
          fontSize: scaledFontSize,
          fontWeight: FontWeight.w500, // Material 3 Medium
          fontFamily: 'PingFang SC',
          letterSpacing: 0.1, // Material 3 字母间距
        ),
      ),
    );
  }

  // 静态版本已移除，现在使用 ComponentThemeManager 中的动态版本

  /// 亮色主题 - 文本按钮（TextButton）- Material 3适配
  static TextButtonThemeData get lightTextButtonTheme => TextButtonThemeData(
    style: TextButton.styleFrom(
      // Material 3 颜色系统
      foregroundColor: AppColors.primaryGreen,
      disabledForegroundColor: AppColors.lightTextDisabled,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      minimumSize: const Size(48, 40), // Material 3 最小尺寸
      // Material 3 形状系统
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500, // Material 3 Medium
        fontFamily: 'PingFang SC',
        letterSpacing: 0.1, // Material 3 字母间距
      ),
    ),
  );

  /// 亮色主题 - 轮廓按钮（OutlinedButton）- Material 3适配
  static OutlinedButtonThemeData get lightOutlinedButtonTheme =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          // Material 3 颜色系统
          foregroundColor: AppColors.primaryGreen,
          disabledForegroundColor: AppColors.lightTextDisabled,
          side: BorderSide(color: AppColors.lightBorder, width: 1), // Material 3 轮廓颜色
          // Material 3 形状系统
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          minimumSize: const Size(64, 40), // Material 3 最小尺寸
          textStyle: const TextStyle(
            fontSize: 14, // Material 3 标准
            fontWeight: FontWeight.w500, // Material 3 Medium
            fontFamily: 'PingFang SC',
            letterSpacing: 0.1, // Material 3 字母间距
          ),
        ),
      );

  /// 亮色主题 - 浮动操作按钮（FloatingActionButton）- Material 3适配
  static FloatingActionButtonThemeData get lightFloatingActionButtonTheme =>
      const FloatingActionButtonThemeData(
        // Material 3 颜色系统
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        // Material 3 高度系统
        elevation: 6, // Material 3 标准高度
        focusElevation: 8,
        hoverElevation: 8,
        highlightElevation: 12,
        // Material 3 形状系统 - 保持圆形
        shape: CircleBorder(),
      );

  // ==================== 暗色主题按钮配置 ====================

  /// 暗色主题 - 主要按钮（ElevatedButton）- Material 3适配
  static ElevatedButtonThemeData get darkElevatedButtonTheme =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // Material 3 颜色系统
          backgroundColor: AppColors.primaryGreenLight,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.darkTextDisabled,
          disabledForegroundColor: AppColors.darkTextSecondary,
          // Material 3 高度系统
          elevation: 1, // Material 3 标准高度
          shadowColor: AppColors.darkBorder.withValues(alpha: 0.3),
          // Material 3 形状系统
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          minimumSize: const Size(64, 40), // Material 3 最小尺寸
          textStyle: const TextStyle(
            fontSize: 14, // Material 3 标准
            fontWeight: FontWeight.w500, // Material 3 Medium
            fontFamily: 'PingFang SC',
            letterSpacing: 0.1, // Material 3 字母间距
          ),
        ),
      );

  /// 暗色主题 - 文本按钮（TextButton）- Material 3适配
  static TextButtonThemeData get darkTextButtonTheme => TextButtonThemeData(
    style: TextButton.styleFrom(
      // Material 3 颜色系统
      foregroundColor: AppColors.primaryGreenLight,
      disabledForegroundColor: AppColors.darkTextDisabled,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      minimumSize: const Size(48, 40), // Material 3 最小尺寸
      // Material 3 形状系统
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500, // Material 3 Medium
        fontFamily: 'PingFang SC',
        letterSpacing: 0.1, // Material 3 字母间距
      ),
    ),
  );

  /// 暗色主题 - 轮廓按钮（OutlinedButton）- Material 3适配
  static OutlinedButtonThemeData get darkOutlinedButtonTheme =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          // Material 3 颜色系统
          foregroundColor: AppColors.primaryGreenLight,
          disabledForegroundColor: AppColors.darkTextDisabled,
          side: BorderSide(color: AppColors.darkBorder, width: 1), // Material 3 轮廓颜色
          // Material 3 形状系统
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          minimumSize: const Size(64, 40), // Material 3 最小尺寸
          textStyle: const TextStyle(
            fontSize: 14, // Material 3 标准
            fontWeight: FontWeight.w500, // Material 3 Medium
            fontFamily: 'PingFang SC',
            letterSpacing: 0.1, // Material 3 字母间距
          ),
        ),
      );

  /// 暗色主题 - 浮动操作按钮（FloatingActionButton）- Material 3适配
  static FloatingActionButtonThemeData get darkFloatingActionButtonTheme =>
      const FloatingActionButtonThemeData(
        // Material 3 颜色系统
        backgroundColor: AppColors.primaryGreenLight,
        foregroundColor: Colors.white,
        // Material 3 高度系统
        elevation: 6, // Material 3 标准高度
        focusElevation: 8,
        hoverElevation: 8,
        highlightElevation: 12,
        // Material 3 形状系统 - 保持圆形
        shape: CircleBorder(),
      );
}
