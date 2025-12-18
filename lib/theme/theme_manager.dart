import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'default/theme.dart';
import 'default/app_colors.dart';
import 'default/font_types.dart';
import 'default/config/text_theme.dart';
import 'models/theme_settings.dart';
import 'storage/theme_storage_handler.dart';
import 'cache/lru_cache.dart';
import 'dynamic_color_manager.dart';

/// 优化版主题管理器 - 提供高效的主题缓存、切换功能和字体管理
/// 集成GetX状态管理，支持响应式主题切换
/// 使用 LRU 缓存优化内存使用和性能
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

  ThemeManager._() {
    // 初始化高级缓存系统
    _themeCache = LRUCache<String, ThemeData>(_maxThemeCacheSize);
    _fontSizeCache = TTLLRUCache<String, double>(_maxFontCacheSize, _cacheTTL);
    _textStyleCache = TTLLRUCache<String, TextStyle>(
      _maxTextStyleCacheSize,
      _cacheTTL,
    );
  }

  // ==================== 高级缓存系统 ====================
  // 主题数据缓存 - 使用 LRU 缓存优化内存使用
  late final LRUCache<String, ThemeData> _themeCache;
  late final TTLLRUCache<String, double> _fontSizeCache;
  late final TTLLRUCache<String, TextStyle> _textStyleCache;

  // 当前主题设置
  final _themeSettings = ThemeSettings.defaultSettings.obs;
  ThemeSettings get themeSettings => _themeSettings.value;

  // 当前主题模式
  bool get isDarkMode => _themeSettings.value.isDarkMode;

  // 当前字体大小选项
  FontSizeOption get fontSizeOption => _themeSettings.value.fontSizeOption;

  ///// 是否跟随系统主题
  bool get followSystemTheme => _themeSettings.value.followSystemTheme;

  /// 是否使用动态颜色
  bool get useDynamicColor => _themeSettings.value.useDynamicColor;

  /// 是否支持动态颜色
  bool get isDynamicColorSupported => _isDynamicColorSupported.value;

  /// 是否启用OLED优化模式
  bool get isOLEDMode => _themeSettings.value.isOLEDMode;

  /// 是否启用护眼模式
  bool get isEyeCareMode => _themeSettings.value.isEyeCareMode;

  // 动态颜色是否可用
  final _isDynamicColorSupported = false.obs;

  // 主题切换动画控制
  final _isThemeChanging = false.obs;
  bool get isThemeChanging => _isThemeChanging.value;

  // 缓存配置
  static const int _maxThemeCacheSize = 20;
  static const int _maxFontCacheSize = 100;
  static const int _maxTextStyleCacheSize = 200;
  static const Duration _cacheTTL = Duration(minutes: 30);

  // 缓存清理定时器
  Timer? _cacheCleanupTimer;

  // 性能监控数据
  final Map<String, int> _cacheHits = {};
  final Map<String, int> _cacheMisses = {};
  final Map<String, List<int>> _themeBuildTimes = {};
  final Map<String, List<int>> _themeSwitchTimes = {};

  /// 获取亮色主题（支持动态字体缩放和动态颜色）
  ThemeData get lightTheme {
    final cacheKey = 'light_${fontSizeOption.value}_${useDynamicColor ? 'dynamic' : 'static'}_${isEyeCareMode ? 'eyecare' : 'normal'}';

    // 尝试从缓存获取
    var theme = _themeCache.get(cacheKey);
    if (theme != null) {
      _recordCacheHit('lightTheme');
      return theme;
    }

    // 构建新主题并缓存
    final startTime = DateTime.now();
    theme = _buildLightTheme();
    _themeCache.put(cacheKey, theme);
    
    // 记录性能指标
    final buildTime = DateTime.now().difference(startTime).inMilliseconds;
    _recordThemeBuildTime('lightTheme', buildTime);
    _recordCacheMiss('lightTheme');

    return theme;
  }

  /// 获取暗色主题（支持动态字体缩放和动态颜色）
  ThemeData get darkTheme {
    final cacheKey = 'dark_${fontSizeOption.value}_${useDynamicColor ? 'dynamic' : 'static'}_${isOLEDMode ? 'oled' : 'normal'}_${isEyeCareMode ? 'eyecare' : 'normal'}';

    // 尝试从缓存获取
    var theme = _themeCache.get(cacheKey);
    if (theme != null) {
      _recordCacheHit('darkTheme');
      return theme;
    }

    // 构建新主题并缓存
    final startTime = DateTime.now();
    theme = _buildDarkTheme();
    _themeCache.put(cacheKey, theme);
    
    // 记录性能指标
    final buildTime = DateTime.now().difference(startTime).inMilliseconds;
    _recordThemeBuildTime('darkTheme', buildTime);
    _recordCacheMiss('darkTheme');

    return theme;
  }

  /// 获取当前主题
  ThemeData get currentTheme {
    return isDarkMode ? darkTheme : lightTheme;
  }

  /// 构建亮色主题（使用 AppTheme 配置）
  ThemeData _buildLightTheme() {
    // 注意：动态颜色主题需要异步获取，这里返回静态主题
    // 动态颜色主题通过 updateDynamicColor 方法异步应用
    return AppTheme.getLightThemeFromOption(fontSizeOption);
  }

  /// 构建暗色主题（使用 AppTheme 配置）
  ThemeData _buildDarkTheme() {
    // 注意：动态颜色主题需要异步获取，这里返回静态主题
    // 动态颜色主题通过 updateDynamicColor 方法异步应用
    return AppTheme.getDarkThemeFromOption(fontSizeOption);
  }

  /// 切换主题（带动画效果）
  Future<void> toggleTheme({bool? isDark, Duration? duration}) async {
    if (_isThemeChanging.value) return; // 防止重复切换

    _isThemeChanging.value = true;

    try {
      final targetDarkMode = isDark ?? !isDarkMode;

      // 更新主题设置
      await updateThemeSettings(
        _themeSettings.value.copyWith(isDarkMode: targetDarkMode),
      );

      // 应用主题切换（仅在非测试环境）
      try {
        Get.changeTheme(targetDarkMode ? darkTheme : lightTheme);
      } catch (e) {
        // 在测试环境中忽略 GetX 错误
        debugPrint('ThemeManager: GetX changeTheme 失败（可能在测试环境中）- $e');
      }

      // 等待动画完成
      final animationDuration =
          duration ??
          Duration(milliseconds: _themeSettings.value.animationDuration);
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

  /// 切换OLED优化模式
  Future<void> toggleOLEDMode({bool? enabled}) async {
    final targetOLEDMode = enabled ?? !isOLEDMode;
    
    // 如果状态没有变化，直接返回
    if (targetOLEDMode == isOLEDMode) return;
    
    // 清除相关缓存以确保使用新的OLED设置
    _clearOLEDRelatedCache();
    
    await updateThemeSettings(
      _themeSettings.value.copyWith(isOLEDMode: targetOLEDMode),
    );
    
    // 如果当前是深色模式，重新应用主题
    if (isDarkMode) {
      try {
        final startTime = DateTime.now();
        Get.changeTheme(darkTheme);
        final switchTime = DateTime.now().difference(startTime).inMilliseconds;
        _recordThemeSwitchTime('OLED_toggle', switchTime);
      } catch (e) {
        debugPrint('ThemeManager: GetX changeTheme 失败（可能在测试环境中）- $e');
      }
    }
  }

  /// 切换护眼模式
  Future<void> toggleEyeCareMode({bool? enabled}) async {
    final targetEyeCareMode = enabled ?? !isEyeCareMode;
    
    // 如果状态没有变化，直接返回
    if (targetEyeCareMode == isEyeCareMode) return;
    
    // 清除相关缓存以确保使用新的护眼设置
    _clearEyeCareRelatedCache();
    
    await updateThemeSettings(
      _themeSettings.value.copyWith(isEyeCareMode: targetEyeCareMode),
    );
    
    // 重新应用当前主题
    try {
      final startTime = DateTime.now();
      Get.changeTheme(currentTheme);
      final switchTime = DateTime.now().difference(startTime).inMilliseconds;
      _recordThemeSwitchTime('eyecare_toggle', switchTime);
    } catch (e) {
      debugPrint('ThemeManager: GetX changeTheme 失败（可能在测试环境中）- $e');
    }
  }

  /// 获取当前主题的颜色（支持OLED和护眼模式）
  Color getThemeColor(String colorKey) {
    switch (colorKey) {
      case 'primary':
        return isDarkMode
            ? AppColors.primaryGreenLight
            : AppColors.primaryGreen;
      case 'surface':
        if (isDarkMode) {
          return AppColors.getDarkSurface(isOLEDMode, Brightness.dark);
        }
        return isEyeCareMode ? AppColors.lightSurface : AppColors.lightSurface;
      case 'background':
        if (isDarkMode) {
          if (isEyeCareMode) {
            return AppColors.getEyeCareBackground(true, Brightness.dark);
          }
          return AppColors.getDarkBackground(isOLEDMode, Brightness.dark);
        }
        return isEyeCareMode ? AppColors.getEyeCareBackground(true, Brightness.light) : AppColors.lightBackground;
      case 'textPrimary':
        if (isDarkMode) {
          return isEyeCareMode 
              ? AppColors.getEyeCareTextColor(true, Brightness.dark)
              : AppColors.darkTextPrimary;
        }
        return isEyeCareMode ? AppColors.getEyeCareTextColor(true, Brightness.light) : AppColors.lightTextPrimary;
      case 'textSecondary':
        if (isDarkMode) {
          return isEyeCareMode 
              ? AppColors.getEyeCareTextColor(true, Brightness.dark, isSecondary: true)
              : AppColors.darkTextSecondary;
        }
        return isEyeCareMode ? AppColors.getEyeCareTextColor(true, Brightness.light, isSecondary: true) : AppColors.lightTextSecondary;
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

  /// 获取字体大小（带缓存，支持动态缩放）
  double getFontSize(FontSizeType type, {BuildContext? context}) {
    final cacheKey = _generateFontCacheKey(type, context);

    // 尝试从缓存获取
    var fontSize = _fontSizeCache.get(cacheKey);
    if (fontSize != null) {
      return fontSize;
    }

    // 计算字体大小并缓存
    fontSize = _calculateFontSize(type, context);
    _fontSizeCache.put(cacheKey, fontSize);

    return fontSize;
  }

  /// 获取缩放后的字体大小
  double getScaledFontSize(FontSizeType type, {BuildContext? context}) {
    return FontScaleCalculator.calculateFinalSize(
      type,
      fontSizeOption,
      context: context,
    );
  }

  /// 获取文本样式（带缓存，支持动态缩放）
  TextStyle getTextStyle(
    FontSizeType type, {
    FontWeight? fontWeight,
    Color? color,
    BuildContext? context,
  }) {
    final cacheKey = _generateTextStyleCacheKey(
      type,
      fontWeight,
      color,
      context,
    );

    // 尝试从缓存获取
    var textStyle = _textStyleCache.get(cacheKey);
    if (textStyle != null) {
      return textStyle;
    }

    // 创建文本样式并缓存
    textStyle = TextStyle(
      fontSize: getScaledFontSize(type, context: context),
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
      fontFamily: 'PingFang SC',
    );

    _textStyleCache.put(cacheKey, textStyle);

    return textStyle;
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
    await updateFontSizeOption(option);
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

  /// 生成字体缓存键
  String _generateFontCacheKey(FontSizeType type, BuildContext? context) {
    final screenSize = context != null
        ? MediaQuery.of(context).size.toString()
        : 'default';
    final fontScale = fontSizeOption.scale;
    return '${type.name}_${fontScale}_$screenSize';
  }

  /// 生成文本样式缓存键
  String _generateTextStyleCacheKey(
    FontSizeType type,
    FontWeight? fontWeight,
    Color? color,
    BuildContext? context,
  ) {
    final screenSize = context != null
        ? MediaQuery.of(context).size.toString()
        : 'default';
    final fontScale = fontSizeOption.scale;
    return '${type.name}_${fontWeight?.index ?? 'normal'}_${color?.toARGB32() ?? 'null'}_${fontScale}_$screenSize';
  }

  /// 计算响应式字体大小（使用新的缩放逻辑）
  double _calculateFontSize(FontSizeType type, BuildContext? context) {
    return FontScaleCalculator.calculateFinalSize(
      type,
      fontSizeOption,
      context: context,
    );
  }

  /// 预热字体缓存
  void _preloadFontCache() {
    final preloadData = <String, double>{};

    // 为所有字体类型和常用缩放比例预加载
    for (final type in FontSizeType.values) {
      for (final option in [
        FontSizeOption.small,
        FontSizeOption.normal,
        FontSizeOption.large,
      ]) {
        final key = '${type.name}_${option.scale}_default';
        final size = FontScaleCalculator.calculateFinalSize(type, option);
        preloadData[key] = size;
      }
    }

    // 批量预热缓存
    _fontSizeCache.warmUp(preloadData);
  }

  // ==================== 缓存管理方法 ====================

  /// 清理过期缓存
  void _cleanupExpiredCache() {
    // 清理过期的字体大小缓存
    _fontSizeCache.cleanupExpired();

    // 清理过期的文本样式缓存
    _textStyleCache.cleanupExpired();
  }

  /// 估算缓存内存使用量
  int _estimateCacheMemoryUsage() {
    final themeMemory = _themeCache.length * 5000; // 假设每个主题5KB
    final fontMemory = _fontSizeCache.length * 50; // 假设每个字体大小50字节
    final styleMemory = _textStyleCache.length * 200; // 假设每个样式200字节

    return themeMemory + fontMemory + styleMemory;
  }

  // ==================== 性能监控方法 ====================

  /// 记录缓存命中
  void _recordCacheHit(String cacheType) {
    _cacheHits[cacheType] = (_cacheHits[cacheType] ?? 0) + 1;
  }

  /// 记录缓存未命中
  void _recordCacheMiss(String cacheType) {
    _cacheMisses[cacheType] = (_cacheMisses[cacheType] ?? 0) + 1;
  }

  /// 记录主题构建时间
  void _recordThemeBuildTime(String themeType, int buildTimeMs) {
    _themeBuildTimes[themeType] ??= [];
    _themeBuildTimes[themeType]!.add(buildTimeMs);
    
    // 只保留最近100次记录
    if (_themeBuildTimes[themeType]!.length > 100) {
      _themeBuildTimes[themeType]!.removeAt(0);
    }
  }

  /// 获取性能统计信息
  Map<String, dynamic> getPerformanceStats() {
    final stats = <String, dynamic>{};
    
    // 缓存命中率
    for (final type in _cacheHits.keys) {
      final hits = _cacheHits[type] ?? 0;
      final misses = _cacheMisses[type] ?? 0;
      final total = hits + misses;
      final hitRate = total > 0 ? (hits / total * 100).toStringAsFixed(2) : '0.00';
      
      stats['${type}_cache_hit_rate'] = '$hitRate%';
      stats['${type}_cache_hits'] = hits;
      stats['${type}_cache_misses'] = misses;
    }
    
    // 主题构建时间统计
    for (final type in _themeBuildTimes.keys) {
      final times = _themeBuildTimes[type]!;
      if (times.isNotEmpty) {
        final avgTime = times.reduce((a, b) => a + b) / times.length;
        final maxTime = times.reduce((a, b) => a > b ? a : b);
        final minTime = times.reduce((a, b) => a < b ? a : b);
        
        stats['${type}_avg_build_time_ms'] = avgTime.toStringAsFixed(2);
        stats['${type}_max_build_time_ms'] = maxTime;
        stats['${type}_min_build_time_ms'] = minTime;
        stats['${type}_build_count'] = times.length;
      }
    }
    
    // 主题切换时间统计
    for (final type in _themeSwitchTimes.keys) {
      final times = _themeSwitchTimes[type]!;
      if (times.isNotEmpty) {
        final avgTime = times.reduce((a, b) => a + b) / times.length;
        final maxTime = times.reduce((a, b) => a > b ? a : b);
        final minTime = times.reduce((a, b) => a < b ? a : b);
        
        stats['${type}_avg_switch_time_ms'] = avgTime.toStringAsFixed(2);
        stats['${type}_max_switch_time_ms'] = maxTime;
        stats['${type}_min_switch_time_ms'] = minTime;
        stats['${type}_switch_count'] = times.length;
      }
    }
    
    // 整体性能指标
    stats['cache_memory_usage_bytes'] = _estimateCacheMemoryUsage();
    stats['total_cache_entries'] = _themeCache.length + _fontSizeCache.length + _textStyleCache.length;
    
    return stats;
  }

  /// 重置性能统计
  void resetPerformanceStats() {
    _cacheHits.clear();
    _cacheMisses.clear();
    _themeBuildTimes.clear();
    _themeSwitchTimes.clear();
  }

  /// 记录主题切换时间
  void _recordThemeSwitchTime(String switchType, int switchTimeMs) {
    _themeSwitchTimes[switchType] ??= [];
    _themeSwitchTimes[switchType]!.add(switchTimeMs);
    
    // 只保留最近50次记录
    if (_themeSwitchTimes[switchType]!.length > 50) {
      _themeSwitchTimes[switchType]!.removeAt(0);
    }
  }

  /// 清除OLED相关缓存
  void _clearOLEDRelatedCache() {
    final keysToRemove = <String>[];
    
    // 查找包含OLED相关的缓存键
    for (final key in _themeCache.keys) {
      if (key.contains('oled') || key.contains('dark_')) {
        keysToRemove.add(key);
      }
    }
    
    // 移除相关缓存
    for (final key in keysToRemove) {
      _themeCache.remove(key);
    }
  }

  /// 清除护眼模式相关缓存
  void _clearEyeCareRelatedCache() {
    final keysToRemove = <String>[];
    
    // 查找包含护眼模式相关的缓存键
    for (final key in _themeCache.keys) {
      if (key.contains('eyecare')) {
        keysToRemove.add(key);
      }
    }
    
    // 移除相关缓存
    for (final key in keysToRemove) {
      _themeCache.remove(key);
    }
  }

  /// 清除所有缓存（用于主题更新后刷新）
  void clearCache() {
    // 清除所有缓存
    _themeCache.clear();
    _fontSizeCache.clear();
    _textStyleCache.clear();
  }

  /// 预热所有缓存（在应用启动时调用）
  void preloadThemes() {
    // 预加载当前字体大小的主题
    final lightThemeKey = 'light_${fontSizeOption.value}';
    final darkThemeKey = 'dark_${fontSizeOption.value}';

    _themeCache.put(
      lightThemeKey,
      AppTheme.getLightThemeFromOption(fontSizeOption),
    );
    _themeCache.put(
      darkThemeKey,
      AppTheme.getDarkThemeFromOption(fontSizeOption),
    );

    // 预加载常用字体大小的主题
    for (final option in [
      FontSizeOption.small,
      FontSizeOption.normal,
      FontSizeOption.large,
    ]) {
      if (option != fontSizeOption) {
        final lightKey = 'light_${option.value}';
        final darkKey = 'dark_${option.value}';
        _themeCache.put(lightKey, AppTheme.getLightThemeFromOption(option));
        _themeCache.put(darkKey, AppTheme.getDarkThemeFromOption(option));
      }
    }

    // 预加载常用字体大小
    _preloadFontCache();
  }

  /// 更新主题设置
  Future<void> updateThemeSettings(ThemeSettings newSettings) async {
    try {
      // 验证设置有效性
      final safeSettings = newSettings.getSafeSettings();

      // 检查是否需要刷新主题
      final needsThemeRefresh =
          _themeSettings.value.isDarkMode != safeSettings.isDarkMode ||
          _themeSettings.value.fontSizeOption != safeSettings.fontSizeOption;

      // 更新内存中的设置
      _themeSettings.value = safeSettings;

      // 保存到本地存储
      await ThemeStorageHandler.saveThemeSettings(safeSettings);

      // 如果需要，刷新主题和缓存
      if (needsThemeRefresh) {
        clearCache();

        // 应用新主题到 GetX（仅在非测试环境）
        try {
          Get.changeTheme(currentTheme);
        } catch (e) {
          // 在测试环境中忽略 GetX 错误
          debugPrint('ThemeManager: GetX changeTheme 失败（可能在测试环境中）- $e');
        }
      }
    } catch (e) {
      // 记录错误但不抛出异常
      debugPrint('ThemeManager: 更新主题设置失败 - $e');
    }
  }

  /// 更新字体大小选项
  Future<void> updateFontSizeOption(FontSizeOption option) async {
    await updateThemeSettings(
      _themeSettings.value.copyWith(fontSizeOption: option),
    );
  }

  /// 更新跟随系统主题设置
  Future<void> updateFollowSystemTheme(bool followSystem) async {
    await updateThemeSettings(
      _themeSettings.value.copyWith(followSystemTheme: followSystem),
    );
  }

  /// 更新动态颜色设置
  Future<void> updateDynamicColor(bool useDynamic) async {
    await updateThemeSettings(
      _themeSettings.value.copyWith(useDynamicColor: useDynamic),
    );
    
    // 清除缓存以应用新的颜色设置
    clearCache();
    
    // 重新应用主题
    try {
      final newTheme = useDynamic && isDynamicColorSupported
          ? await (isDarkMode 
              ? AppTheme.getDarkThemeWithDynamicColor(fontScale: fontSizeOption.scale)
              : AppTheme.getLightThemeWithDynamicColor(fontScale: fontSizeOption.scale))
          : currentTheme;
      
      Get.changeTheme(newTheme);
    } catch (e) {
      debugPrint('ThemeManager: 应用动态颜色主题失败 - $e');
    }
  }

  /// 检测动态颜色支持
  Future<void> detectDynamicColorSupport() async {
    try {
      final isSupported = await DynamicColorManager.instance.isDynamicColorSupported();
      _isDynamicColorSupported.value = isSupported;
      
      // 如果不支持动态颜色，禁用动态颜色设置
      if (!isSupported && useDynamicColor) {
        await updateThemeSettings(
          _themeSettings.value.copyWith(useDynamicColor: false),
        );
      }
    } catch (e) {
      debugPrint('ThemeManager: 检测动态颜色支持失败 - $e');
      _isDynamicColorSupported.value = false;
      if (useDynamicColor) {
        await updateThemeSettings(
          _themeSettings.value.copyWith(useDynamicColor: false),
        );
      }
    }
  }

  /// 获取动态颜色信息（用于调试）
  Future<Map<String, dynamic>> getDynamicColorInfo() async {
    return await DynamicColorManager.instance.getDynamicColorInfo();
  }

  /// 应用动态颜色主题（内部方法）
  Future<void> _applyDynamicColorTheme() async {
    try {
      final dynamicTheme = isDarkMode 
          ? await AppTheme.getDarkThemeWithDynamicColor(fontScale: fontSizeOption.scale)
          : await AppTheme.getLightThemeWithDynamicColor(fontScale: fontSizeOption.scale);
      
      Get.changeTheme(dynamicTheme);
    } catch (e) {
      debugPrint('ThemeManager: 应用动态颜色主题失败 - $e');
    }
  }

  /// 从本地存储加载主题设置
  Future<void> loadThemePreference() async {
    try {
      final settings = await ThemeStorageHandler.loadThemeSettings();
      _themeSettings.value = settings;

      // 应用加载的主题（仅在非测试环境）
      try {
        Get.changeTheme(settings.isDarkMode ? darkTheme : lightTheme);
      } catch (e) {
        // 在测试环境中忽略 GetX 错误
        debugPrint('ThemeManager: GetX changeTheme 失败（可能在测试环境中）- $e');
      }
    } catch (e) {
      debugPrint('ThemeManager: 加载主题设置失败 - $e');
      // 使用默认设置
      _themeSettings.value = ThemeSettings.defaultSettings;
    }
  }

  /// 重置实例（用于测试）
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStats() {
    return {
      'themeCache': _themeCache.getStats(),
      'fontSizeCache': _fontSizeCache.getStats(),
      'textStyleCache': _textStyleCache.getStats(),
      'totalMemoryUsage': _estimateCacheMemoryUsage(),
    };
  }

  @override
  void onInit() {
    super.onInit();
    // 初始化时加载主题设置
    _initializeTheme();

    // 启动缓存清理定时器
    _startCacheCleanupTimer();
  }

  /// 启动缓存清理定时器
  void _startCacheCleanupTimer() {
    _cacheCleanupTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _cleanupExpiredCache();
    });
  }

  /// 初始化主题系统
  Future<void> _initializeTheme() async {
    try {
      // 迁移旧格式设置
      await ThemeStorageHandler.migrateFromOldFormat();

      // 检测动态颜色支持
      await detectDynamicColorSupport();

      // 加载主题设置
      await loadThemePreference();

      // 预热缓存
      preloadThemes();

      // 如果启用了动态颜色且支持，应用动态颜色主题
      if (useDynamicColor && isDynamicColorSupported) {
        await _applyDynamicColorTheme();
      }

      // 如果设置为跟随系统主题，则应用系统主题
      if (followSystemTheme) {
        applySystemTheme();
      }
    } catch (e) {
      debugPrint('ThemeManager: 初始化主题系统失败 - $e');
      // 使用默认设置
      _themeSettings.value = ThemeSettings.defaultSettings;
      preloadThemes();
    }
  }

  @override
  void onClose() {
    // 停止缓存清理定时器
    _cacheCleanupTimer?.cancel();
    super.onClose();
  }
}
