import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/theme_manager.dart';

/// 组件主题管理器
/// 统一管理所有组件主题，支持动态字体缩放和 Material 3 设计规范
class ComponentThemeManager {
  ComponentThemeManager._();

  // ==================== AppBar 主题 ====================

  /// 获取 AppBar 主题
  static AppBarTheme getAppBarTheme({
    required bool isDark,
    BuildContext? context,
  }) {
    final scaledTitleSize = ThemeManager.instance.getScaledFontSize(
      FontSizeType.large,
      context: context,
    );

    return AppBarTheme(
      backgroundColor: isDark
          ? AppColors.darkAppBarBackground
          : AppColors.lightAppBarBackground,
      foregroundColor: isDark
          ? AppColors.darkTextPrimary
          : AppColors.lightTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      surfaceTintColor: isDark
          ? AppColors.darkAppBarBackground
          : AppColors.lightAppBarBackground,
      iconTheme: IconThemeData(
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        size: 24,
      ),
      actionsIconTheme: IconThemeData(
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        size: 24,
      ),
      titleTextStyle: TextStyle(
        fontSize: scaledTitleSize,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        fontFamily: 'PingFang SC',
      ),
      centerTitle: true,
      toolbarHeight: 56,
    );
  }

  // ==================== Button 主题 ====================

  /// 获取 ElevatedButton 主题
  static ElevatedButtonThemeData getElevatedButtonTheme({
    required bool isDark,
    BuildContext? context,
  }) {
    final scaledFontSize = ThemeManager.instance.getScaledFontSize(
      FontSizeType.medium,
      context: context,
    );

    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark
            ? AppColors.primaryGreenLight
            : AppColors.primaryGreen,
        foregroundColor: Colors.white,
        disabledBackgroundColor: isDark
            ? AppColors.darkTextDisabled
            : AppColors.lightTextDisabled,
        disabledForegroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        minimumSize: const Size(88, 44),
        textStyle: TextStyle(
          fontSize: scaledFontSize,
          fontWeight: FontWeight.w500,
          fontFamily: 'PingFang SC',
        ),
      ),
    );
  }

  /// 获取 TextButton 主题
  static TextButtonThemeData getTextButtonTheme({
    required bool isDark,
    BuildContext? context,
  }) {
    final scaledFontSize = ThemeManager.instance.getScaledFontSize(
      FontSizeType.normal,
      context: context,
    );

    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: isDark
            ? AppColors.primaryGreenLight
            : AppColors.primaryGreen,
        disabledForegroundColor: isDark
            ? AppColors.darkTextDisabled
            : AppColors.lightTextDisabled,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: const Size(64, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: TextStyle(
          fontSize: scaledFontSize,
          fontWeight: FontWeight.w500,
          fontFamily: 'PingFang SC',
        ),
      ),
    );
  }

  /// 获取 OutlinedButton 主题
  static OutlinedButtonThemeData getOutlinedButtonTheme({
    required bool isDark,
    BuildContext? context,
  }) {
    final scaledFontSize = ThemeManager.instance.getScaledFontSize(
      FontSizeType.medium,
      context: context,
    );

    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark
            ? AppColors.primaryGreenLight
            : AppColors.primaryGreen,
        disabledForegroundColor: isDark
            ? AppColors.darkTextDisabled
            : AppColors.lightTextDisabled,
        side: BorderSide(
          color: isDark ? AppColors.primaryGreenLight : AppColors.primaryGreen,
          width: 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        minimumSize: const Size(88, 44),
        textStyle: TextStyle(
          fontSize: scaledFontSize,
          fontWeight: FontWeight.w500,
          fontFamily: 'PingFang SC',
        ),
      ),
    );
  }

  /// 获取 FloatingActionButton 主题
  static FloatingActionButtonThemeData getFloatingActionButtonTheme({
    required bool isDark,
  }) {
    return FloatingActionButtonThemeData(
      backgroundColor: isDark
          ? AppColors.primaryGreenLight
          : AppColors.primaryGreen,
      foregroundColor: Colors.white,
      elevation: 6,
      focusElevation: 8,
      hoverElevation: 8,
      highlightElevation: 12,
      shape: const CircleBorder(),
    );
  }

  // ==================== Card 主题 ====================

  /// 获取 Card 主题
  static CardThemeData getCardTheme({required bool isDark}) {
    return CardThemeData(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      surfaceTintColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shadowColor: (isDark ? AppColors.darkBorder : AppColors.lightBorder)
          .withValues(alpha: 0.2),
      elevation: 0,
      margin: const EdgeInsets.all(8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
    );
  }

  // ==================== Input 主题 ====================

  /// 获取 InputDecoration 主题
  static InputDecorationTheme getInputDecorationTheme({
    required bool isDark,
    BuildContext? context,
  }) {
    final scaledHintSize = ThemeManager.instance.getScaledFontSize(
      FontSizeType.medium,
      context: context,
    );
    final scaledLabelSize = ThemeManager.instance.getScaledFontSize(
      FontSizeType.medium,
      context: context,
    );
    final scaledFloatingLabelSize = ThemeManager.instance.getScaledFontSize(
      FontSizeType.normal,
      context: context,
    );
    final scaledErrorSize = ThemeManager.instance.getScaledFontSize(
      FontSizeType.small,
      context: context,
    );
    final scaledHelperSize = ThemeManager.instance.getScaledFontSize(
      FontSizeType.small,
      context: context,
    );

    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

      // 默认边框
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),

      // 启用状态边框
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),

      // 聚焦状态边框
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? AppColors.primaryGreenLight : AppColors.primaryGreen,
          width: 2,
        ),
      ),

      // 错误状态边框
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? AppColors.darkError : AppColors.lightError,
          width: 1,
        ),
      ),

      // 聚焦错误状态边框
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? AppColors.darkError : AppColors.lightError,
          width: 2,
        ),
      ),

      // 禁用状态边框
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark
              ? AppColors.darkTextDisabled
              : AppColors.lightTextDisabled,
          width: 1,
        ),
      ),

      // 文本样式
      hintStyle: TextStyle(
        color: isDark
            ? AppColors.darkTextDisabled
            : AppColors.lightTextDisabled,
        fontSize: scaledHintSize,
        fontFamily: 'PingFang SC',
      ),
      labelStyle: TextStyle(
        color: isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
        fontSize: scaledLabelSize,
        fontFamily: 'PingFang SC',
      ),
      floatingLabelStyle: TextStyle(
        color: isDark ? AppColors.primaryGreenLight : AppColors.primaryGreen,
        fontSize: scaledFloatingLabelSize,
        fontFamily: 'PingFang SC',
      ),
      errorStyle: TextStyle(
        color: isDark ? AppColors.darkError : AppColors.lightError,
        fontSize: scaledErrorSize,
        fontFamily: 'PingFang SC',
      ),
      helperStyle: TextStyle(
        color: isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
        fontSize: scaledHelperSize,
        fontFamily: 'PingFang SC',
      ),
    );
  }

  // ==================== ListTile 主题 ====================

  /// 获取 ListTile 主题
  static ListTileThemeData getListTileTheme({
    required bool isDark,
    BuildContext? context,
  }) {
    final scaledTitleSize = ThemeManager.instance.getScaledFontSize(
      FontSizeType.medium,
      context: context,
    );
    final scaledSubtitleSize = ThemeManager.instance.getScaledFontSize(
      FontSizeType.normal,
      context: context,
    );

    return ListTileThemeData(
      tileColor: Colors.transparent,
      selectedTileColor:
          (isDark ? AppColors.primaryGreenLight : AppColors.primaryGreen)
              .withValues(alpha: 0.1),
      iconColor: isDark
          ? AppColors.darkTextSecondary
          : AppColors.lightTextSecondary,
      textColor: isDark
          ? AppColors.darkTextPrimary
          : AppColors.lightTextPrimary,
      titleTextStyle: TextStyle(
        fontSize: scaledTitleSize,
        fontWeight: FontWeight.w500,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        fontFamily: 'PingFang SC',
      ),
      subtitleTextStyle: TextStyle(
        fontSize: scaledSubtitleSize,
        fontWeight: FontWeight.w400,
        color: isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
        fontFamily: 'PingFang SC',
      ),
      leadingAndTrailingTextStyle: TextStyle(
        fontSize: scaledSubtitleSize,
        fontWeight: FontWeight.w400,
        color: isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
        fontFamily: 'PingFang SC',
      ),
      dense: false,
      horizontalTitleGap: 16,
      minVerticalPadding: 8,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  // ==================== Chip 主题 ====================

  /// 获取 Chip 主题
  static ChipThemeData getChipTheme({
    required bool isDark,
    BuildContext? context,
  }) {
    final scaledLabelSize = ThemeManager.instance.getScaledFontSize(
      FontSizeType.normal,
      context: context,
    );

    return ChipThemeData(
      backgroundColor: isDark
          ? AppColors.darkCardBackground
          : AppColors.lightCardBackground,
      selectedColor: isDark
          ? AppColors.primaryGreenLight
          : AppColors.primaryGreen,
      disabledColor:
          (isDark ? AppColors.darkTextDisabled : AppColors.lightTextDisabled)
              .withValues(alpha: 0.3),
      deleteIconColor: isDark
          ? AppColors.darkTextSecondary
          : AppColors.lightTextSecondary,
      labelStyle: TextStyle(
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        fontSize: scaledLabelSize,
        fontFamily: 'PingFang SC',
      ),
      secondaryLabelStyle: TextStyle(
        color: Colors.white,
        fontSize: scaledLabelSize,
        fontFamily: 'PingFang SC',
      ),
      brightness: isDark ? Brightness.dark : Brightness.light,
      elevation: 0,
      pressElevation: 2,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
    );
  }

  // ==================== BottomNavigationBar 主题 ====================

  /// 获取 BottomNavigationBar 主题
  static BottomNavigationBarThemeData getBottomNavigationBarTheme({
    required bool isDark,
    BuildContext? context,
  }) {
    final scaledLabelSize = ThemeManager.instance.getScaledFontSize(
      FontSizeType.small,
      context: context,
    );

    return BottomNavigationBarThemeData(
      backgroundColor: isDark
          ? AppColors.darkAppBarBackground
          : AppColors.lightAppBarBackground,
      selectedItemColor: isDark
          ? AppColors.primaryGreenLight
          : AppColors.primaryGreen,
      unselectedItemColor: isDark
          ? AppColors.darkTextDisabled
          : AppColors.lightTextDisabled,
      selectedLabelStyle: TextStyle(
        color: isDark ? AppColors.primaryGreenLight : AppColors.primaryGreen,
        fontSize: scaledLabelSize,
        fontFamily: 'PingFang SC',
      ),
      unselectedLabelStyle: TextStyle(
        color: isDark
            ? AppColors.darkTextDisabled
            : AppColors.lightTextDisabled,
        fontSize: scaledLabelSize,
        fontFamily: 'PingFang SC',
      ),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    );
  }

  // ==================== Divider 主题 ====================

  /// 获取 Divider 主题
  static DividerThemeData getDividerTheme({required bool isDark}) {
    return DividerThemeData(
      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      thickness: 1,
      space: 16,
    );
  }

  // ==================== ProgressIndicator 主题 ====================

  /// 获取 ProgressIndicator 主题
  static ProgressIndicatorThemeData getProgressIndicatorTheme({
    required bool isDark,
  }) {
    return ProgressIndicatorThemeData(
      color: isDark ? AppColors.primaryGreenLight : AppColors.primaryGreen,
      linearTrackColor: (isDark ? AppColors.darkBorder : AppColors.lightBorder)
          .withValues(alpha: 0.3),
      circularTrackColor:
          (isDark ? AppColors.darkBorder : AppColors.lightBorder).withValues(
            alpha: 0.3,
          ),
    );
  }

  // ==================== 便捷方法 ====================

  /// 获取所有组件主题的集合
  static Map<String, dynamic> getAllComponentThemes({
    required bool isDark,
    BuildContext? context,
  }) {
    return {
      'appBarTheme': getAppBarTheme(isDark: isDark, context: context),
      'elevatedButtonTheme': getElevatedButtonTheme(
        isDark: isDark,
        context: context,
      ),
      'textButtonTheme': getTextButtonTheme(isDark: isDark, context: context),
      'outlinedButtonTheme': getOutlinedButtonTheme(
        isDark: isDark,
        context: context,
      ),
      'floatingActionButtonTheme': getFloatingActionButtonTheme(isDark: isDark),
      'cardTheme': getCardTheme(isDark: isDark),
      'inputDecorationTheme': getInputDecorationTheme(
        isDark: isDark,
        context: context,
      ),
      'listTileTheme': getListTileTheme(isDark: isDark, context: context),
      'chipTheme': getChipTheme(isDark: isDark, context: context),
      'bottomNavigationBarTheme': getBottomNavigationBarTheme(
        isDark: isDark,
        context: context,
      ),
      'dividerTheme': getDividerTheme(isDark: isDark),
      'progressIndicatorTheme': getProgressIndicatorTheme(isDark: isDark),
    };
  }
}

/// 组件主题扩展方法
extension ComponentThemeExtension on BuildContext {
  /// 快速获取 AppBar 主题
  AppBarTheme get dynamicAppBarTheme => ComponentThemeManager.getAppBarTheme(
    isDark: Theme.of(this).brightness == Brightness.dark,
    context: this,
  );

  /// 快速获取 ElevatedButton 主题
  ElevatedButtonThemeData get dynamicElevatedButtonTheme =>
      ComponentThemeManager.getElevatedButtonTheme(
        isDark: Theme.of(this).brightness == Brightness.dark,
        context: this,
      );

  /// 快速获取 TextButton 主题
  TextButtonThemeData get dynamicTextButtonTheme =>
      ComponentThemeManager.getTextButtonTheme(
        isDark: Theme.of(this).brightness == Brightness.dark,
        context: this,
      );

  /// 快速获取 OutlinedButton 主题
  OutlinedButtonThemeData get dynamicOutlinedButtonTheme =>
      ComponentThemeManager.getOutlinedButtonTheme(
        isDark: Theme.of(this).brightness == Brightness.dark,
        context: this,
      );

  /// 快速获取 Card 主题
  CardThemeData get dynamicCardTheme => ComponentThemeManager.getCardTheme(
    isDark: Theme.of(this).brightness == Brightness.dark,
  );

  /// 快速获取 InputDecoration 主题
  InputDecorationTheme get dynamicInputDecorationTheme =>
      ComponentThemeManager.getInputDecorationTheme(
        isDark: Theme.of(this).brightness == Brightness.dark,
        context: this,
      );

  /// 快速获取 ListTile 主题
  ListTileThemeData get dynamicListTileTheme =>
      ComponentThemeManager.getListTileTheme(
        isDark: Theme.of(this).brightness == Brightness.dark,
        context: this,
      );

  /// 快速获取 Chip 主题
  ChipThemeData get dynamicChipTheme => ComponentThemeManager.getChipTheme(
    isDark: Theme.of(this).brightness == Brightness.dark,
    context: this,
  );

  /// 快速获取 BottomNavigationBar 主题
  BottomNavigationBarThemeData get dynamicBottomNavigationBarTheme =>
      ComponentThemeManager.getBottomNavigationBarTheme(
        isDark: Theme.of(this).brightness == Brightness.dark,
        context: this,
      );
}
