import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../default/theme.dart';
import '../default/app_colors.dart';
import '../default/font_types.dart';
import '../default/config/text_theme.dart';
import '../dynamic_color_manager.dart';

part 'theme_provider.g.dart';

/// ThemeMode Provider - 用于 MaterialApp.themeMode
///
/// 这是从本地存储读取的主题模式
@riverpod
class ThemeModeNotifier extends _$ThemeModeNotifier {
  @override
  ThemeMode build() {
    _loadThemeMode();
    return ThemeMode.system;
  }

  /// 从本地存储加载主题模式
  void _loadThemeMode() {
    // 同步加载初始值
    try {
      final prefs = SharedPreferences.getInstance();
      prefs.then((prefs) {
        final followSystem = prefs.getBool('theme_follow_system') ?? false;
        final isDarkMode = prefs.getBool('theme_is_dark_mode') ?? false;

        final mode = followSystem
            ? ThemeMode.system
            : (isDarkMode ? ThemeMode.dark : ThemeMode.light);
        state = mode;
      });
    } catch (e) {}
  }

  /// 设置主题模式
  void setThemeMode(ThemeMode mode) {
    state = mode;
    // 保存到本地存储
    try {
      final prefs = SharedPreferences.getInstance();
      prefs.then((prefs) {
        prefs.setBool('theme_follow_system', mode == ThemeMode.system);
        if (mode != ThemeMode.system) {
          prefs.setBool('theme_is_dark_mode', mode == ThemeMode.dark);
        }
      });
    } catch (e) {}
  }

  /// 切换主题模式
  void toggleTheme(bool isDark) {
    setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  /// 设置跟随系统
  void setFollowSystem(bool follow) {
    setThemeMode(follow ? ThemeMode.system : ThemeMode.light);
  }
}

/// 主题状态
class ThemeState {
  final bool isDarkMode;
  final FontSizeOption fontSizeOption;
  final bool followSystemTheme;
  final bool useDynamicColor;
  final bool isDynamicColorSupported;
  final bool isThemeChanging;

  const ThemeState({
    this.isDarkMode = false,
    this.fontSizeOption = FontSizeOption.normal,
    this.followSystemTheme = false,
    this.useDynamicColor = false,
    this.isDynamicColorSupported = false,
    this.isThemeChanging = false,
  });

  ThemeState copyWith({
    bool? isDarkMode,
    FontSizeOption? fontSizeOption,
    bool? followSystemTheme,
    bool? useDynamicColor,
    bool? isDynamicColorSupported,
    bool? isThemeChanging,
  }) {
    return ThemeState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      fontSizeOption: fontSizeOption ?? this.fontSizeOption,
      followSystemTheme: followSystemTheme ?? this.followSystemTheme,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
      isDynamicColorSupported:
          isDynamicColorSupported ?? this.isDynamicColorSupported,
      isThemeChanging: isThemeChanging ?? this.isThemeChanging,
    );
  }
}

/// 主题管理器 Provider
///
/// 使用 Riverpod 管理主题状态，支持亮色/暗色模式切换、字体缩放等功能
@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  // 用于存储加载前的初始主题
  late ThemeData _cachedLightTheme;
  late ThemeData _cachedDarkTheme;

  @override
  ThemeState build() {
    // 缓存初始主题
    _cachedLightTheme = AppTheme.getLightThemeFromOption(FontSizeOption.normal);
    _cachedDarkTheme = AppTheme.getDarkThemeFromOption(FontSizeOption.normal);

    // 异步初始化主题设置
    _initializeTheme();

    return const ThemeState();
  }

  /// 初始化主题系统
  Future<void> _initializeTheme() async {
    try {
      // 检测动态颜色支持
      await detectDynamicColorSupport();

      // 加载主题设置
      await loadThemePreference();

      // 如果设置为跟随系统主题，则应用系统主题
      if (state.followSystemTheme) {
        applySystemTheme();
      }
    } catch (e) {}
  }

  /// 获取亮色主题（支持动态字体缩放）
  ThemeData get lightTheme {
    return AppTheme.getLightThemeFromOption(state.fontSizeOption);
  }

  /// 获取暗色主题（支持动态字体缩放）
  ThemeData get darkTheme {
    return AppTheme.getDarkThemeFromOption(state.fontSizeOption);
  }

  /// 获取当前主题
  ThemeData get currentTheme {
    return state.isDarkMode ? darkTheme : lightTheme;
  }

  /// 获取缓存的亮色主题（用于初始化）
  ThemeData get cachedLightTheme => _cachedLightTheme;

  /// 获取缓存的暗色主题（用于初始化）
  ThemeData get cachedDarkTheme => _cachedDarkTheme;

  /// 切换主题（带动画效果）
  Future<void> toggleTheme({bool? isDark, Duration? duration}) async {
    if (state.isThemeChanging) return; // 防止重复切换

    state = state.copyWith(isThemeChanging: true);

    try {
      final targetDarkMode = isDark ?? !state.isDarkMode;

      // 更新主题模式
      state = state.copyWith(isDarkMode: targetDarkMode);

      // 保存主题设置
      await _saveThemePreference();

      // 等待动画完成
      final animationDuration = duration ?? const Duration(milliseconds: 300);
      await Future<dynamic>.delayed(animationDuration);
    } finally {
      state = state.copyWith(isThemeChanging: false);
    }
  }

  /// 根据系统主题自动切换
  void applySystemTheme() {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final systemIsDark = brightness == Brightness.dark;

    if (state.isDarkMode != systemIsDark) {
      toggleTheme(isDark: systemIsDark);
    }
  }

  /// 保存主题设置到本地存储
  Future<void> _saveThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('theme_is_dark_mode', state.isDarkMode);
      await prefs.setString('theme_font_size', state.fontSizeOption.value);
      await prefs.setBool('theme_follow_system', state.followSystemTheme);
      await prefs.setBool('theme_use_dynamic_color', state.useDynamicColor);
    } catch (e) {}
  }

  /// 从本地存储加载主题设置
  Future<void> loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 加载所有主题设置
      final isDarkMode = prefs.getBool('theme_is_dark_mode') ?? false;
      final fontSizeValue = prefs.getString('theme_font_size') ?? 'normal';
      final fontSizeOption =
          FontSizeOption.fromValue(fontSizeValue) ?? FontSizeOption.normal;
      final followSystemTheme = prefs.getBool('theme_follow_system') ?? false;
      final useDynamicColor = prefs.getBool('theme_use_dynamic_color') ?? false;

      // 更新状态
      state = state.copyWith(
        isDarkMode: isDarkMode,
        fontSizeOption: fontSizeOption,
        followSystemTheme: followSystemTheme,
        useDynamicColor: useDynamicColor,
      );

      // 更新缓存的主题
      _cachedLightTheme = AppTheme.getLightThemeFromOption(fontSizeOption);
      _cachedDarkTheme = AppTheme.getDarkThemeFromOption(fontSizeOption);
    } catch (e) {
      // 使用默认设置
      state = const ThemeState();
    }
  }

  /// 获取当前主题的颜色
  Color getThemeColor(String colorKey) {
    switch (colorKey) {
      case 'primary':
        return state.isDarkMode ? AppColors.primaryLight : AppColors.primary;
      case 'surface':
        if (state.isDarkMode) {
          return AppColors.getDarkSurface(false, Brightness.dark);
        }
        return AppColors.lightSurface;
      case 'background':
        if (state.isDarkMode) {
          return AppColors.getDarkBackground(false, Brightness.dark);
        }
        return AppColors.lightBackground;
      case 'textPrimary':
        if (state.isDarkMode) {
          return AppColors.darkTextPrimary;
        }
        return AppColors.lightTextPrimary;
      case 'textSecondary':
        if (state.isDarkMode) {
          return AppColors.darkTextSecondary;
        }
        return AppColors.lightTextSecondary;
      case 'border':
        return state.isDarkMode ? AppColors.darkBorder : AppColors.lightBorder;
      case 'error':
        return state.isDarkMode ? AppColors.darkError : AppColors.lightError;
      default:
        return getThemeColor('textPrimary');
    }
  }

  /// 获取聊天相关颜色
  Color getChatColor(String colorKey) {
    switch (colorKey) {
      case 'sendMessageBg':
        return state.isDarkMode
            ? AppColors.darkSentMessageBackground
            : AppColors.lightSentMessageBackground;
      case 'receivedMessageBg':
        return state.isDarkMode
            ? AppColors.darkReceivedMessageBackground
            : AppColors.lightReceivedMessageBackground;
      case 'sentMessageText':
        return AppColors.sentMessageText;
      case 'receivedMessageText':
        return state.isDarkMode
            ? AppColors.darkReceivedMessageText
            : AppColors.lightReceivedMessageText;
      default:
        return getThemeColor(colorKey);
    }
  }

  /// 获取字体大小（支持动态缩放）
  double getFontSize(FontSizeType type, {BuildContext? context}) {
    return getScaledFontSize(type, context: context);
  }

  /// 获取缩放后的字体大小
  double getScaledFontSize(FontSizeType type, {BuildContext? context}) {
    return FontScaleCalculator.calculateFinalSize(
      type,
      state.fontSizeOption,
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
      fontFamilyFallback: const [
        'PingFang SC',
        'Heiti SC',
        'Microsoft YaHei',
        'sans-serif',
      ],
    );
  }

  /// 根据当前设置获取动态 TextTheme
  TextTheme getTextTheme({BuildContext? context}) {
    if (state.isDarkMode) {
      return TextThemeConfig.getDarkThemeFromOption(
        state.fontSizeOption,
        context: context,
      );
    } else {
      return TextThemeConfig.getLightThemeFromOption(
        state.fontSizeOption,
        context: context,
      );
    }
  }

  /// 更新字体大小选项并刷新主题
  Future<void> updateFontSize(String fontSizeValue) async {
    final option =
        FontSizeOption.fromValue(fontSizeValue) ?? FontSizeOption.normal;

    state = state.copyWith(fontSizeOption: option);

    // 更新缓存的主题
    _cachedLightTheme = AppTheme.getLightThemeFromOption(option);
    _cachedDarkTheme = AppTheme.getDarkThemeFromOption(option);

    // 保存设置
    await _saveThemePreference();
  }

  /// 更新字体大小选项
  Future<void> updateFontSizeOption(FontSizeOption option) async {
    state = state.copyWith(fontSizeOption: option);

    // 更新缓存的主题
    _cachedLightTheme = AppTheme.getLightThemeFromOption(option);
    _cachedDarkTheme = AppTheme.getDarkThemeFromOption(option);

    // 保存设置
    await _saveThemePreference();
  }

  /// 获取当前字体大小的字符串值（兼容旧版本）
  String get currentFontSizeValue => state.fontSizeOption.value;

  /// 获取所有可用的字体大小选项
  List<FontSizeOption> get availableFontSizes => FontSizeOption.allOptions;

  /// 检查当前字体大小是否符合可访问性标准
  bool get isCurrentFontSizeAccessible {
    final sampleSize = FontScaleCalculator.calculateFinalSize(
      FontSizeType.normal,
      state.fontSizeOption,
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

  /// 获取当前主题设置（用于调试和监控）
  Map<String, dynamic> getThemeSettings() {
    return {
      'isDarkMode': state.isDarkMode,
      'fontSizeOption': state.fontSizeOption.value,
      'followSystemTheme': state.followSystemTheme,
      'useDynamicColor': state.useDynamicColor,
      'isDynamicColorSupported': state.isDynamicColorSupported,
    };
  }

  /// 更新跟随系统主题设置
  Future<void> updateFollowSystemTheme(bool followSystem) async {
    state = state.copyWith(followSystemTheme: followSystem);
    await _saveThemePreference();
  }

  /// 更新动态颜色设置
  Future<void> updateUseDynamicColor(bool useDynamic) async {
    state = state.copyWith(useDynamicColor: useDynamic);
    await _saveThemePreference();
  }

  /// 检测动态颜色支持
  Future<void> detectDynamicColorSupport() async {
    try {
      final isSupported = await DynamicColorManager.instance
          .isDynamicColorSupported();
      state = state.copyWith(isDynamicColorSupported: isSupported);

      // 如果不支持动态颜色，禁用动态颜色设置
      if (!isSupported && state.useDynamicColor) {
        state = state.copyWith(useDynamicColor: false);
      }
    } catch (e) {
      state = state.copyWith(isDynamicColorSupported: false);
      if (state.useDynamicColor) {
        state = state.copyWith(useDynamicColor: false);
      }
    }
  }

  /// 获取动态颜色信息（用于调试）
  Future<Map<String, dynamic>> getDynamicColorInfo() async {
    return await DynamicColorManager.instance.getDynamicColorInfo();
  }
}
