import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'default/theme.dart';
import 'default/app_colors.dart';
import 'default/font_types.dart';
import 'default/config/text_theme.dart';
import 'dynamic_color_manager.dart';

/// 主题管理器 - 提供主题切换和字体管理
/// 集成GetX状态管理，支持响应式主题切换
class ThemeManager extends GetxController {
  double mainSpace = 10.0;
  double get mainLineWidth => Get.isDarkMode ? 0.5 : 1.0;

  static ThemeManager? _instance;
  static ThemeManager get instance {
    if (_instance == null) {
      _instance = ThemeManager._();
      Get.put(_instance!);
    }
    return _instance!;
  }

  ThemeManager._();

  // 当前主题模式
  final _isDarkMode = false.obs;
  bool get isDarkMode => _isDarkMode.value;

  // 当前字体大小选项
  final _fontSizeOption = FontSizeOption.normal.obs;
  FontSizeOption get fontSizeOption => _fontSizeOption.value;

  // 是否跟随系统主题
  final _followSystemTheme = false.obs;
  bool get followSystemTheme => _followSystemTheme.value;

  // 是否使用动态颜色（暂未实现，预留用于未来版本）
  final _useDynamicColor = false.obs;
  bool get useDynamicColor => _useDynamicColor.value;

  // 是否支持动态颜色
  final _isDynamicColorSupported = false.obs;
  bool get isDynamicColorSupported => _isDynamicColorSupported.value;

  // 主题切换动画控制
  final _isThemeChanging = false.obs;
  bool get isThemeChanging => _isThemeChanging.value;

  /// 获取亮色主题（支持动态字体缩放）
  ThemeData get lightTheme {
    return AppTheme.getLightThemeFromOption(fontSizeOption);
  }

  /// 获取暗色主题（支持动态字体缩放）
  ThemeData get darkTheme {
    return AppTheme.getDarkThemeFromOption(fontSizeOption);
  }

  /// 获取当前主题
  ThemeData get currentTheme {
    return isDarkMode ? darkTheme : lightTheme;
  }

  /// 切换主题（带动画效果）
  Future<void> toggleTheme({bool? isDark, Duration? duration}) async {
    if (_isThemeChanging.value) return; // 防止重复切换

    _isThemeChanging.value = true;

    try {
      final targetDarkMode = isDark ?? !isDarkMode;

      // 更新主题模式
      _isDarkMode.value = targetDarkMode;

      // 应用主题切换
      _safeChangeTheme(targetDarkMode ? darkTheme : lightTheme);

      // 保存主题设置
      _saveThemePreference();

      // 等待动画完成
      final animationDuration = duration ?? const Duration(milliseconds: 300);
      await Future.delayed(animationDuration);
    } finally {
      _isThemeChanging.value = false;
    }
  }

  /// 根据系统主题自动切换
  void applySystemTheme() {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final systemIsDark = brightness == Brightness.dark;

    if (isDarkMode != systemIsDark) {
      toggleTheme(isDark: systemIsDark);
    }
  }

  // ==================== 私有辅助方法 ====================

  /// 安全地应用主题切换（处理测试环境中的 GetX 未初始化问题）
  void _safeChangeTheme(ThemeData theme) {
    try {
      Get.changeTheme(theme);
    } catch (e) {
      debugPrint('ThemeManager: GetX changeTheme 失败（可能在测试环境中）- $e');
    }
  }

  /// 保存主题设置到本地存储
  Future<void> _saveThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('theme_is_dark_mode', isDarkMode);
      await prefs.setString('theme_font_size', fontSizeOption.value);
      await prefs.setBool('theme_follow_system', followSystemTheme);
      await prefs.setBool('theme_use_dynamic_color', useDynamicColor);
    } catch (e) {
      debugPrint('ThemeManager: 保存主题设置失败 - $e');
    }
  }

  // ==================== 颜色获取方法 ====================

  /// 获取当前主题的颜色
  Color getThemeColor(String colorKey) {
    switch (colorKey) {
      case 'primary':
        return isDarkMode
            ? AppColors.primaryGreenLight
            : AppColors.primaryGreen;
      case 'surface':
        if (isDarkMode) {
          return AppColors.getDarkSurface(false, Brightness.dark);
        }
        return AppColors.lightSurface;
      case 'background':
        if (isDarkMode) {
          return AppColors.getDarkBackground(false, Brightness.dark);
        }
        return AppColors.lightBackground;
      case 'textPrimary':
        if (isDarkMode) {
          return AppColors.darkTextPrimary;
        }
        return AppColors.lightTextPrimary;
      case 'textSecondary':
        if (isDarkMode) {
          return AppColors.darkTextSecondary;
        }
        return AppColors.lightTextSecondary;
      case 'border':
        return isDarkMode ? AppColors.darkBorder : AppColors.lightBorder;
      case 'error':
        return isDarkMode ? AppColors.darkError : AppColors.lightError;
      default:
        return getThemeColor('textPrimary');
    }
  }

  /// 获取聊天相关颜色
  Color getChatColor(String colorKey) {
    switch (colorKey) {
      case 'sendMessageBg':
        return isDarkMode
            ? AppColors.darkSentMessageBackground
            : AppColors.lightSentMessageBackground;
      case 'receivedMessageBg':
        return isDarkMode
            ? AppColors.darkReceivedMessageBackground
            : AppColors.lightReceivedMessageBackground;
      case 'sentMessageText':
        return AppColors.sentMessageText;
      case 'receivedMessageText':
        return isDarkMode
            ? AppColors.darkReceivedMessageText
            : AppColors.lightReceivedMessageText;
      default:
        return getThemeColor(colorKey);
    }
  }

  // ==================== 字体管理方法 ====================

  /// 获取字体大小（支持动态缩放）
  double getFontSize(FontSizeType type, {BuildContext? context}) {
    return getScaledFontSize(type, context: context);
  }

  /// 获取缩放后的字体大小
  double getScaledFontSize(FontSizeType type, {BuildContext? context}) {
    return FontScaleCalculator.calculateFinalSize(
      type,
      fontSizeOption,
      context: context,
    );
  }

  /// 获取文本样式（支持动态缩放）
  TextStyle getTextStyle(
    FontSizeType type, {
    FontWeight? fontWeight,
    Color? color,
    BuildContext? context,
  }) {
    return TextStyle(
      fontSize: getScaledFontSize(type, context: context),
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
      fontFamily: 'PingFang SC',
    );
  }

  /// 根据当前设置获取动态 TextTheme
  TextTheme getTextTheme({BuildContext? context}) {
    if (isDarkMode) {
      return TextThemeConfig.getDarkThemeFromOption(
        fontSizeOption,
        context: context,
      );
    } else {
      return TextThemeConfig.getLightThemeFromOption(
        fontSizeOption,
        context: context,
      );
    }
  }

  /// 更新字体大小选项并刷新主题
  Future<void> updateFontSize(String fontSizeValue) async {
    final option =
        FontSizeOption.fromValue(fontSizeValue) ?? FontSizeOption.normal;
    _fontSizeOption.value = option;

    // 应用新主题并保存
    _safeChangeTheme(currentTheme);
    await _saveThemePreference();
  }

  /// 更新字体大小选项
  Future<void> updateFontSizeOption(FontSizeOption option) async {
    _fontSizeOption.value = option;

    // 应用新主题并保存
    _safeChangeTheme(currentTheme);
    await _saveThemePreference();
  }

  /// 获取当前字体大小的字符串值（兼容旧版本）
  String get currentFontSizeValue => fontSizeOption.value;

  /// 获取所有可用的字体大小选项
  List<FontSizeOption> get availableFontSizes => FontSizeOption.allOptions;

  /// 检查当前字体大小是否符合可访问性标准
  bool get isCurrentFontSizeAccessible {
    final sampleSize = FontScaleCalculator.calculateFinalSize(
      FontSizeType.normal,
      fontSizeOption,
    );
    return FontScaleCalculator.isAccessibleSize(sampleSize);
  }

  /// 获取推荐的字体大小选项（基于系统设置）
  FontSizeOption getRecommendedFontSize(BuildContext context) {
    return FontScaleCalculator.getRecommendedOption(context);
  }

  /// 预览指定字体大小选项的效果
  Map<String, dynamic> previewFontSize(
    FontSizeOption option, {
    BuildContext? context,
  }) {
    return FontScaleCalculator.generatePreviewInfo(
      FontSizeType.normal,
      option,
      context: context,
    );
  }

  // ==================== 性能监控方法 ====================

  /// 获取当前主题设置（用于调试和监控）
  Map<String, dynamic> getThemeSettings() {
    return {
      'isDarkMode': isDarkMode,
      'fontSizeOption': fontSizeOption.value,
      'followSystemTheme': followSystemTheme,
      'useDynamicColor': useDynamicColor,
      'isDynamicColorSupported': isDynamicColorSupported,
    };
  }

  /// 获取性能统计信息（兼容旧版本，建议使用 getThemeSettings）
  @Deprecated('使用 getThemeSettings() 替代')
  Map<String, dynamic> getPerformanceStats() => getThemeSettings();

  /// 获取缓存统计信息（兼容旧版本，建议使用 getThemeSettings）
  @Deprecated('使用 getThemeSettings() 替代')
  Map<String, dynamic> getCacheStats() => getThemeSettings();

  /// 更新跟随系统主题设置
  Future<void> updateFollowSystemTheme(bool followSystem) async {
    _followSystemTheme.value = followSystem;
    await _saveThemePreference();
  }

  /// 更新动态颜色设置
  Future<void> updateUseDynamicColor(bool useDynamic) async {
    _useDynamicColor.value = useDynamic;
    await _saveThemePreference();
  }

  /// 检测动态颜色支持
  Future<void> detectDynamicColorSupport() async {
    try {
      final isSupported = await DynamicColorManager.instance.isDynamicColorSupported();
      _isDynamicColorSupported.value = isSupported;

      // 如果不支持动态颜色，禁用动态颜色设置
      if (!isSupported && useDynamicColor) {
        _useDynamicColor.value = false;
      }
    } catch (e) {
      debugPrint('ThemeManager: 检测动态颜色支持失败 - $e');
      _isDynamicColorSupported.value = false;
      if (useDynamicColor) {
        _useDynamicColor.value = false;
      }
    }
  }

  /// 获取动态颜色信息（用于调试）
  Future<Map<String, dynamic>> getDynamicColorInfo() async {
    return await DynamicColorManager.instance.getDynamicColorInfo();
  }

  /// 从本地存储加载主题设置
  Future<void> loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 加载所有主题设置
      _isDarkMode.value = prefs.getBool('theme_is_dark_mode') ?? false;
      final fontSizeValue = prefs.getString('theme_font_size') ?? 'normal';
      _fontSizeOption.value =
          FontSizeOption.fromValue(fontSizeValue) ?? FontSizeOption.normal;
      _followSystemTheme.value = prefs.getBool('theme_follow_system') ?? false;
      _useDynamicColor.value = prefs.getBool('theme_use_dynamic_color') ?? false;

      // 应用加载的主题
      _safeChangeTheme(isDarkMode ? darkTheme : lightTheme);
    } catch (e) {
      debugPrint('ThemeManager: 加载主题设置失败 - $e');
      // 使用默认设置
      _isDarkMode.value = false;
      _fontSizeOption.value = FontSizeOption.normal;
      _followSystemTheme.value = false;
      _useDynamicColor.value = false;
    }
  }

  /// 重置实例（用于测试）
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }

  @override
  void onInit() {
    super.onInit();
    // 初始化时加载主题设置
    _initializeTheme();
  }

  /// 初始化主题系统
  Future<void> _initializeTheme() async {
    try {
      // 检测动态颜色支持
      await detectDynamicColorSupport();

      // 加载主题设置
      await loadThemePreference();

      // 如果设置为跟随系统主题，则应用系统主题
      if (followSystemTheme) {
        applySystemTheme();
      }
    } catch (e) {
      debugPrint('ThemeManager: 初始化主题系统失败 - $e');
    }
  }
}
