import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/app_sizes.dart';

/// 组件主题管理器
/// 统一管理所有组件主题，支持动态字体缩放和 Material 3 设计规范
class ComponentThemeManager {
  ComponentThemeManager._();

  // ==================== AppBar 主题 ====================

  /// 获取 AppBar 主题
  static AppBarTheme getAppBarTheme({
    required bool isDark,
    BuildContext? context,
    FontSizeOption? fontSizeOption,
  }) {
    // 使用固定字体大小，避免循环依赖
    final scaledTitleSize = fontSizeOption != null
        ? FontSizeType.large.size * fontSizeOption.scale
        : FontSizeType.large.size;

    return AppBarTheme(
      backgroundColor: isDark
          ? AppColors.darkAppBarBackground
          : AppColors.lightAppBarBackground,
      foregroundColor: isDark
          ? AppColors.darkTextPrimary
          : AppColors.lightTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
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
      toolbarHeight: AppSizes.appBarHeight,
    );
  }

  // ==================== Button 主题 ====================

  /// 获取 ElevatedButton 主题
  static ElevatedButtonThemeData getElevatedButtonTheme({
    required bool isDark,
    BuildContext? context,
    FontSizeOption? fontSizeOption,
  }) {
    final scaledFontSize = fontSizeOption != null
        ? FontSizeType.medium.size * fontSizeOption.scale
        : FontSizeType.medium.size;

    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: isDark
            ? AppColors.darkTextDisabled
            : AppColors.lightTextDisabled,
        disabledForegroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderRadiusSmall,
        ),
        padding: AppSpacing.buttonPadding,
        minimumSize: Size(AppSizes.buttonMinWidth, AppSizes.buttonHeightLarge),
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
    FontSizeOption? fontSizeOption,
  }) {
    final scaledFontSize = fontSizeOption != null
        ? FontSizeType.normal.size * fontSizeOption.scale
        : FontSizeType.normal.size;

    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
        disabledForegroundColor: isDark
            ? AppColors.darkTextDisabled
            : AppColors.lightTextDisabled,
        padding: AppSpacing.buttonSmallPadding,
        minimumSize: Size(AppSizes.buttonMinWidth, AppSizes.buttonHeightSmall),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderRadiusSmall,
        ),
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
    FontSizeOption? fontSizeOption,
  }) {
    final scaledFontSize = fontSizeOption != null
        ? FontSizeType.medium.size * fontSizeOption.scale
        : FontSizeType.medium.size;

    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
        disabledForegroundColor: isDark
            ? AppColors.darkTextDisabled
            : AppColors.lightTextDisabled,
        side: BorderSide(
          color: isDark ? AppColors.primaryLight : AppColors.primary,
          width: 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderRadiusSmall,
        ),
        padding: AppSpacing.buttonPadding,
        minimumSize: Size(AppSizes.buttonMinWidth, AppSizes.buttonHeightLarge),
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
      backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
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
      margin: AppSpacing.cardMarginSmall,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderRadiusMedium,
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
    FontSizeOption? fontSizeOption,
  }) {
    final scaledHintSize = fontSizeOption != null
        ? FontSizeType.medium.size * fontSizeOption.scale
        : FontSizeType.medium.size;
    final scaledLabelSize = fontSizeOption != null
        ? FontSizeType.medium.size * fontSizeOption.scale
        : FontSizeType.medium.size;
    final scaledFloatingLabelSize = fontSizeOption != null
        ? FontSizeType.normal.size * fontSizeOption.scale
        : FontSizeType.normal.size;
    final scaledErrorSize = fontSizeOption != null
        ? FontSizeType.small.size * fontSizeOption.scale
        : FontSizeType.small.size;
    final scaledHelperSize = fontSizeOption != null
        ? FontSizeType.small.size * fontSizeOption.scale
        : FontSizeType.small.size;

    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      contentPadding: AppSpacing.inputPadding,

      // 默认边框
      border: OutlineInputBorder(
        borderRadius: AppRadius.borderRadiusSmall,
        borderSide: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),

      // 启用状态边框
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.borderRadiusSmall,
        borderSide: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),

      // 聚焦状态边框
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.borderRadiusSmall,
        borderSide: BorderSide(
          color: isDark ? AppColors.primaryLight : AppColors.primary,
          width: 2,
        ),
      ),

      // 错误状态边框
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.borderRadiusSmall,
        borderSide: BorderSide(
          color: isDark ? AppColors.darkError : AppColors.lightError,
          width: 1,
        ),
      ),

      // 聚焦错误状态边框
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.borderRadiusSmall,
        borderSide: BorderSide(
          color: isDark ? AppColors.darkError : AppColors.lightError,
          width: 2,
        ),
      ),

      // 禁用状态边框
      disabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.borderRadiusSmall,
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
        color: isDark ? AppColors.primaryLight : AppColors.primary,
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
    FontSizeOption? fontSizeOption,
  }) {
    final scaledTitleSize = fontSizeOption != null
        ? FontSizeType.medium.size * fontSizeOption.scale
        : FontSizeType.medium.size;
    final scaledSubtitleSize = fontSizeOption != null
        ? FontSizeType.normal.size * fontSizeOption.scale
        : FontSizeType.normal.size;

    return ListTileThemeData(
      tileColor: Colors.transparent,
      selectedTileColor: (isDark ? AppColors.primaryLight : AppColors.primary)
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
      horizontalTitleGap: AppSpacing.regular,
      minVerticalPadding: AppSpacing.small,
      contentPadding: AppSpacing.listItemPadding,
    );
  }

  // ==================== Chip 主题 ====================

  /// 获取 Chip 主题
  static ChipThemeData getChipTheme({
    required bool isDark,
    BuildContext? context,
    FontSizeOption? fontSizeOption,
  }) {
    final scaledLabelSize = fontSizeOption != null
        ? FontSizeType.normal.size * fontSizeOption.scale
        : FontSizeType.normal.size;

    return ChipThemeData(
      backgroundColor: isDark
          ? AppColors.darkCardBackground
          : AppColors.lightCardBackground,
      selectedColor: isDark ? AppColors.primaryLight : AppColors.primary,
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
      padding: AppSpacing.chipPadding,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderRadiusRegular,
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
    FontSizeOption? fontSizeOption,
  }) {
    // 使用固定字体大小，避免循环依赖
    final scaledLabelSize = fontSizeOption != null
        ? FontSizeType.small.size * fontSizeOption.scale
        : FontSizeType.small.size;

    return BottomNavigationBarThemeData(
      backgroundColor: isDark
          ? AppColors.darkAppBarBackground
          : const Color(0xFFF7F7F7), // 微信风格底部导航栏背景略亮于AppBar
      selectedItemColor: isDark ? AppColors.primaryLight : AppColors.primary,
      unselectedItemColor: isDark
          ? AppColors.darkTextDisabled
          : AppColors.lightTextSecondary, // 使用次要文本颜色
      selectedLabelStyle: TextStyle(
        color: isDark ? AppColors.primaryLight : AppColors.primary,
        fontSize: scaledLabelSize,
        fontFamily: 'PingFang SC',
        fontWeight: FontWeight.w500,
      ),
      unselectedLabelStyle: TextStyle(
        color: isDark
            ? AppColors.darkTextDisabled
            : AppColors.lightTextSecondary,
        fontSize: scaledLabelSize,
        fontFamily: 'PingFang SC',
        fontWeight: FontWeight.w500,
      ),
      type: BottomNavigationBarType.fixed,
      elevation: 0, // 移除阴影
      showSelectedLabels: true,
      showUnselectedLabels: true,
    );
  }

  // ==================== Divider 主题 ====================

  /// 获取 Divider 主题
  static DividerThemeData getDividerTheme({required bool isDark}) {
    return DividerThemeData(
      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      thickness: 1,
      space: AppSpacing.regular,
    );
  }

  // ==================== ProgressIndicator 主题 ====================

  /// 获取 ProgressIndicator 主题
  static ProgressIndicatorThemeData getProgressIndicatorTheme({
    required bool isDark,
  }) {
    return ProgressIndicatorThemeData(
      color: isDark ? AppColors.primaryLight : AppColors.primary,
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
    FontSizeOption? fontSizeOption,
  }) {
    return {
      'appBarTheme': getAppBarTheme(
        isDark: isDark,
        context: context,
        fontSizeOption: fontSizeOption,
      ),
      'elevatedButtonTheme': getElevatedButtonTheme(
        isDark: isDark,
        context: context,
        fontSizeOption: fontSizeOption,
      ),
      'textButtonTheme': getTextButtonTheme(
        isDark: isDark,
        context: context,
        fontSizeOption: fontSizeOption,
      ),
      'outlinedButtonTheme': getOutlinedButtonTheme(
        isDark: isDark,
        context: context,
        fontSizeOption: fontSizeOption,
      ),
      'floatingActionButtonTheme': getFloatingActionButtonTheme(isDark: isDark),
      'cardTheme': getCardTheme(isDark: isDark),
      'inputDecorationTheme': getInputDecorationTheme(
        isDark: isDark,
        context: context,
        fontSizeOption: fontSizeOption,
      ),
      'listTileTheme': getListTileTheme(
        isDark: isDark,
        context: context,
        fontSizeOption: fontSizeOption,
      ),
      'chipTheme': getChipTheme(
        isDark: isDark,
        context: context,
        fontSizeOption: fontSizeOption,
      ),
      'bottomNavigationBarTheme': getBottomNavigationBarTheme(
        isDark: isDark,
        context: context,
        fontSizeOption: fontSizeOption,
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
