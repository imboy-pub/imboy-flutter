import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 组件主题管理器 - 增强版 (Systematic UI Repair)
class ComponentThemeManager {
  ComponentThemeManager._();

  // ==================== AppBar 主题 ====================
  static AppBarTheme getAppBarTheme({required bool isDark}) {
    return AppBarTheme(
      backgroundColor: (isDark ? AppColors.darkSurface : Colors.white)
          .withValues(alpha: 0.8),
      foregroundColor: isDark
          ? AppColors.darkTextPrimary
          : AppColors.lightTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        letterSpacing: -0.4,
      ),
    );
  }

  // ==================== Button 主题 ====================
  static ElevatedButtonThemeData getElevatedButtonTheme({
    required bool isDark,
  }) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
        elevation: 0,
        minimumSize: const Size(88, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    );
  }

  static TextButtonThemeData getTextButtonTheme({required bool isDark}) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.getIosBlue(
          isDark ? Brightness.dark : Brightness.light,
        ),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w400),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  // ==================== Input 主题 ====================
  static InputDecorationTheme getInputDecorationTheme({required bool isDark}) {
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final hintColor = isDark
        ? AppColors.darkTextSecondary.withValues(alpha: 0.4)
        : AppColors.lightTextSecondary.withValues(alpha: 0.4);

    return InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? AppColors.darkSurfaceGroupedTertiary
          : AppColors.lightBorder.withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(color: hintColor, fontSize: 16),
      labelStyle: TextStyle(color: textColor, fontSize: 16),
    );
  }

  // ==================== ListTile 主题 ====================
  static ListTileThemeData getListTileTheme({required bool isDark}) {
    return ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      ),
      subtitleTextStyle: TextStyle(
        fontSize: 15,
        color: isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
      ),
    );
  }

  // 其他组件按需添加...
  static Map<String, dynamic> getAllComponentThemes({
    required bool isDark,
    BuildContext? context,
    FontSizeOption? fontSizeOption,
  }) {
    return {
      'appBarTheme': getAppBarTheme(isDark: isDark),
      'elevatedButtonTheme': getElevatedButtonTheme(isDark: isDark),
      'textButtonTheme': getTextButtonTheme(isDark: isDark),
      'inputDecorationTheme': getInputDecorationTheme(isDark: isDark),
      'listTileTheme': getListTileTheme(isDark: isDark),
    };
  }
}
