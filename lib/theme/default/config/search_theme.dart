import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 搜索框主题配置
/// 提供统一的搜索框样式，包括搜索栏、搜索建议、搜索结果等组件的主题配置
class SearchThemeConfig {
  SearchThemeConfig._();

  // ==================== 亮色主题搜索配置 ====================

  /// 亮色主题 - 搜索框装饰
  static InputDecoration getLightSearchDecoration({
    String? hintText,
    String? labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool showBorder = true,
  }) {
    return InputDecoration(
      hintText: hintText ?? '搜索...',
      labelText: labelText,
      hintStyle: const TextStyle(
        color: AppColors.lightTextDisabled,
        fontSize: 16,
        fontFamily: 'PingFang SC',
      ),
      labelStyle: const TextStyle(
        color: AppColors.lightTextSecondary,
        fontSize: 14,
        fontFamily: 'PingFang SC',
      ),
      prefixIcon: prefixIcon ?? const Icon(
        Icons.search,
        color: AppColors.lightTextDisabled,
        size: 20,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.lightSurface,
      border: showBorder ? OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(
          color: AppColors.lightBorder,
          width: 1,
        ),
      ) : InputBorder.none,
      enabledBorder: showBorder ? OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(
          color: AppColors.lightBorder,
          width: 1,
        ),
      ) : InputBorder.none,
      focusedBorder: showBorder ? OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(
          color: AppColors.primaryGreen,
          width: 2,
        ),
      ) : InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      isDense: true,
    );
  }

  /// 亮色主题 - 搜索建议列表样式
  static BoxDecoration get lightSuggestionListDecoration => BoxDecoration(
    color: AppColors.lightSurface,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(
      color: AppColors.lightBorder,
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.lightBorder.withValues(alpha: 0.3),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  /// 亮色主题 - 搜索建议项样式
  static BoxDecoration get lightSuggestionItemDecoration => const BoxDecoration(
    color: Colors.transparent,
    border: Border(
      bottom: BorderSide(
        color: AppColors.lightBorder,
        width: 0.5,
      ),
    ),
  );

  /// 亮色主题 - 搜索建议项悬停样式
  static BoxDecoration get lightSuggestionItemHoverDecoration => BoxDecoration(
    color: AppColors.lightBorder.withValues(alpha: 0.1),
    border: const Border(
      bottom: BorderSide(
        color: AppColors.lightBorder,
        width: 0.5,
      ),
    ),
  );

  /// 亮色主题 - 搜索结果高亮文本样式
  static TextStyle get lightHighlightTextStyle => const TextStyle(
    color: AppColors.primaryGreen,
    fontWeight: FontWeight.w600,
    fontSize: 14,
    fontFamily: 'PingFang SC',
  );

  /// 亮色主题 - 搜索结果普通文本样式
  static TextStyle get lightNormalTextStyle => const TextStyle(
    color: AppColors.lightTextPrimary,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    fontFamily: 'PingFang SC',
  );

  // ==================== 暗色主题搜索配置 ====================

  /// 暗色主题 - 搜索框装饰
  static InputDecoration getDarkSearchDecoration({
    String? hintText,
    String? labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool showBorder = true,
  }) {
    return InputDecoration(
      hintText: hintText ?? '搜索...',
      labelText: labelText,
      hintStyle: const TextStyle(
        color: AppColors.darkTextDisabled,
        fontSize: 16,
        fontFamily: 'PingFang SC',
      ),
      labelStyle: const TextStyle(
        color: AppColors.darkTextSecondary,
        fontSize: 14,
        fontFamily: 'PingFang SC',
      ),
      prefixIcon: prefixIcon ?? const Icon(
        Icons.search,
        color: AppColors.darkTextDisabled,
        size: 20,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.darkSurface,
      border: showBorder ? OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(
          color: AppColors.darkBorder,
          width: 1,
        ),
      ) : InputBorder.none,
      enabledBorder: showBorder ? OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(
          color: AppColors.darkBorder,
          width: 1,
        ),
      ) : InputBorder.none,
      focusedBorder: showBorder ? OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(
          color: AppColors.primaryGreenLight,
          width: 2,
        ),
      ) : InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      isDense: true,
    );
  }

  /// 暗色主题 - 搜索建议列表样式
  static BoxDecoration get darkSuggestionListDecoration => BoxDecoration(
    color: AppColors.darkSurface,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(
      color: AppColors.darkBorder,
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.darkBorder.withValues(alpha: 0.3),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  /// 暗色主题 - 搜索建议项样式
  static BoxDecoration get darkSuggestionItemDecoration => const BoxDecoration(
    color: Colors.transparent,
    border: Border(
      bottom: BorderSide(
        color: AppColors.darkBorder,
        width: 0.5,
      ),
    ),
  );

  /// 暗色主题 - 搜索建议项悬停样式
  static BoxDecoration get darkSuggestionItemHoverDecoration => BoxDecoration(
    color: AppColors.darkBorder.withValues(alpha: 0.1),
    border: const Border(
      bottom: BorderSide(
        color: AppColors.darkBorder,
        width: 0.5,
      ),
    ),
  );

  /// 暗色主题 - 搜索结果高亮文本样式
  static TextStyle get darkHighlightTextStyle => const TextStyle(
    color: AppColors.primaryGreenLight,
    fontWeight: FontWeight.w600,
    fontSize: 14,
    fontFamily: 'PingFang SC',
  );

  /// 暗色主题 - 搜索结果普通文本样式
  static TextStyle get darkNormalTextStyle => const TextStyle(
    color: AppColors.darkTextPrimary,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    fontFamily: 'PingFang SC',
  );

  // ==================== 通用搜索配置方法 ====================

  /// 根据主题模式获取搜索框装饰
  static InputDecoration getSearchDecoration({
    required bool isDark,
    String? hintText,
    String? labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool showBorder = true,
  }) {
    return isDark 
        ? getDarkSearchDecoration(
            hintText: hintText,
            labelText: labelText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            showBorder: showBorder,
          )
        : getLightSearchDecoration(
            hintText: hintText,
            labelText: labelText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            showBorder: showBorder,
          );
  }

  /// 根据主题模式获取搜索建议列表装饰
  static BoxDecoration getSuggestionListDecoration({required bool isDark}) {
    return isDark ? darkSuggestionListDecoration : lightSuggestionListDecoration;
  }

  /// 根据主题模式获取搜索建议项装饰
  static BoxDecoration getSuggestionItemDecoration({
    required bool isDark,
    bool isHovered = false,
  }) {
    if (isDark) {
      return isHovered ? darkSuggestionItemHoverDecoration : darkSuggestionItemDecoration;
    } else {
      return isHovered ? lightSuggestionItemHoverDecoration : lightSuggestionItemDecoration;
    }
  }

  /// 根据主题模式获取高亮文本样式
  static TextStyle getHighlightTextStyle({required bool isDark}) {
    return isDark ? darkHighlightTextStyle : lightHighlightTextStyle;
  }

  /// 根据主题模式获取普通文本样式
  static TextStyle getNormalTextStyle({required bool isDark}) {
    return isDark ? darkNormalTextStyle : lightNormalTextStyle;
  }

  // ==================== 搜索框变体 ====================

  /// 紧凑型搜索框装饰（用于导航栏等空间有限的地方）
  static InputDecoration getCompactSearchDecoration({
    required bool isDark,
    String? hintText,
  }) {
    return getSearchDecoration(
      isDark: isDark,
      hintText: hintText ?? '搜索',
      showBorder: false,
    ).copyWith(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      prefixIcon: const Icon(
        Icons.search,
        size: 18,
      ),
    );
  }

  /// 全屏搜索框装饰（用于专门的搜索页面）
  static InputDecoration getFullScreenSearchDecoration({
    required bool isDark,
    String? hintText,
    VoidCallback? onClear,
  }) {
    return getSearchDecoration(
      isDark: isDark,
      hintText: hintText ?? '请输入搜索关键词',
      suffixIcon: onClear != null ? IconButton(
        icon: const Icon(Icons.clear),
        onPressed: onClear,
      ) : null,
    ).copyWith(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
    );
  }

  /// 聊天搜索框装饰（用于聊天记录搜索）
  static InputDecoration getChatSearchDecoration({
    required bool isDark,
    String? hintText,
  }) {
    return getSearchDecoration(
      isDark: isDark,
      hintText: hintText ?? '搜索聊天记录',
      prefixIcon: const Icon(
        Icons.search,
        size: 20,
      ),
    ).copyWith(
      filled: true,
      fillColor: isDark 
          ? AppColors.darkCardBackground 
          : AppColors.lightCardBackground,
    );
  }
}

/// 搜索主题扩展方法
extension SearchThemeExtension on BuildContext {
  /// 快速获取搜索框装饰
  InputDecoration searchDecoration({
    String? hintText,
    String? labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool showBorder = true,
  }) => SearchThemeConfig.getSearchDecoration(
    isDark: Theme.of(this).brightness == Brightness.dark,
    hintText: hintText,
    labelText: labelText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    showBorder: showBorder,
  );

  /// 快速获取紧凑型搜索框装饰
  InputDecoration compactSearchDecoration({String? hintText}) => 
    SearchThemeConfig.getCompactSearchDecoration(
      isDark: Theme.of(this).brightness == Brightness.dark,
      hintText: hintText,
    );

  /// 快速获取全屏搜索框装饰
  InputDecoration fullScreenSearchDecoration({
    String? hintText,
    VoidCallback? onClear,
  }) => SearchThemeConfig.getFullScreenSearchDecoration(
    isDark: Theme.of(this).brightness == Brightness.dark,
    hintText: hintText,
    onClear: onClear,
  );

  /// 快速获取聊天搜索框装饰
  InputDecoration chatSearchDecoration({String? hintText}) => 
    SearchThemeConfig.getChatSearchDecoration(
      isDark: Theme.of(this).brightness == Brightness.dark,
      hintText: hintText,
    );

  /// 快速获取搜索建议列表装饰
  BoxDecoration get searchSuggestionListDecoration => 
    SearchThemeConfig.getSuggestionListDecoration(
      isDark: Theme.of(this).brightness == Brightness.dark,
    );

  /// 快速获取搜索建议项装饰
  BoxDecoration searchSuggestionItemDecoration({bool isHovered = false}) => 
    SearchThemeConfig.getSuggestionItemDecoration(
      isDark: Theme.of(this).brightness == Brightness.dark,
      isHovered: isHovered,
    );

  /// 快速获取搜索高亮文本样式
  TextStyle get searchHighlightTextStyle => 
    SearchThemeConfig.getHighlightTextStyle(
      isDark: Theme.of(this).brightness == Brightness.dark,
    );

  /// 快速获取搜索普通文本样式
  TextStyle get searchNormalTextStyle => 
    SearchThemeConfig.getNormalTextStyle(
      isDark: Theme.of(this).brightness == Brightness.dark,
    );
}