import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/theme/models/theme_settings.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 主题存储处理器
/// 负责主题设置的持久化存储和读取，使用 SharedPreferences
class ThemeStorageHandler {
  ThemeStorageHandler._();

  // SharedPreferences 键名常量
  static const String _keyThemeSettings = 'theme_settings';
  static const String _keyIsDarkMode = 'theme_is_dark_mode';
  static const String _keyFontSizeOption = 'theme_font_size_option';
  static const String _keyFollowSystemTheme = 'theme_follow_system';
  static const String _keyAnimationDuration = 'theme_animation_duration';

  /// 保存完整的主题设置
  ///
  /// [settings] 要保存的主题设置
  /// 返回是否保存成功
  static Future<bool> saveThemeSettings(ThemeSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 验证设置有效性
      final safeSettings = settings.getSafeSettings();

      // 保存为 JSON 字符串
      final success = await prefs.setString(
        _keyThemeSettings,
        safeSettings.toJson(),
      );

      // 同时保存单独的键值对（用于向后兼容和快速访问）
      await Future.wait([
        prefs.setBool(_keyIsDarkMode, safeSettings.isDarkMode),
        prefs.setString(_keyFontSizeOption, safeSettings.fontSizeOption.value),
        prefs.setBool(_keyFollowSystemTheme, safeSettings.followSystemTheme),
        prefs.setInt(_keyAnimationDuration, safeSettings.animationDuration),
      ]);

      return success;
    } catch (e) {
      // 记录错误但不抛出异常
      _logError('保存主题设置失败', e);
      return false;
    }
  }

  /// 加载完整的主题设置
  ///
  /// 返回加载的主题设置，失败时返回默认设置
  static Future<ThemeSettings> loadThemeSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 首先尝试从 JSON 字符串加载
      final jsonString = prefs.getString(_keyThemeSettings);
      if (jsonString != null && jsonString.isNotEmpty) {
        final settings = ThemeSettings.fromJson(jsonString);
        if (settings.isValid()) {
          return settings;
        }
      }

      // 如果 JSON 加载失败，尝试从单独的键值对加载
      return _loadFromIndividualKeys(prefs);
    } catch (e) {
      _logError('加载主题设置失败', e);
      return ThemeSettings.defaultSettings;
    }
  }

  /// 保存暗色主题偏好
  static Future<bool> saveDarkModePreference(bool isDarkMode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool(_keyIsDarkMode, isDarkMode);
    } catch (e) {
      _logError('保存暗色主题偏好失败', e);
      return false;
    }
  }

  /// 加载暗色主题偏好
  static Future<bool> loadDarkModePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyIsDarkMode) ?? false;
    } catch (e) {
      _logError('加载暗色主题偏好失败', e);
      return false;
    }
  }

  /// 保存字体大小选项
  static Future<bool> saveFontSizeOption(String fontSizeOption) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_keyFontSizeOption, fontSizeOption);
    } catch (e) {
      _logError('保存字体大小选项失败', e);
      return false;
    }
  }

  /// 加载字体大小选项
  static Future<String> loadFontSizeOption() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyFontSizeOption) ?? 'normal';
    } catch (e) {
      _logError('加载字体大小选项失败', e);
      return 'normal';
    }
  }

  /// 保存跟随系统主题设置
  static Future<bool> saveFollowSystemTheme(bool followSystem) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool(_keyFollowSystemTheme, followSystem);
    } catch (e) {
      _logError('保存跟随系统主题设置失败', e);
      return false;
    }
  }

  /// 加载跟随系统主题设置
  static Future<bool> loadFollowSystemTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyFollowSystemTheme) ?? false;
    } catch (e) {
      _logError('加载跟随系统主题设置失败', e);
      return false;
    }
  }

  /// 清除所有主题设置
  static Future<bool> clearAllSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await Future.wait([
        prefs.remove(_keyThemeSettings),
        prefs.remove(_keyIsDarkMode),
        prefs.remove(_keyFontSizeOption),
        prefs.remove(_keyFollowSystemTheme),
        prefs.remove(_keyAnimationDuration),
      ]);

      return true;
    } catch (e) {
      _logError('清除主题设置失败', e);
      return false;
    }
  }

  /// 检查是否存在主题设置
  static Future<bool> hasThemeSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_keyThemeSettings) ||
          prefs.containsKey(_keyIsDarkMode);
    } catch (e) {
      _logError('检查主题设置存在性失败', e);
      return false;
    }
  }

  /// 获取存储统计信息
  static Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return {
        'hasThemeSettings': prefs.containsKey(_keyThemeSettings),
        'hasDarkMode': prefs.containsKey(_keyIsDarkMode),
        'hasFontSize': prefs.containsKey(_keyFontSizeOption),
        'hasFollowSystem': prefs.containsKey(_keyFollowSystemTheme),
        'hasAnimationDuration': prefs.containsKey(_keyAnimationDuration),
        'settingsSize': prefs.getString(_keyThemeSettings)?.length ?? 0,
      };
    } catch (e) {
      _logError('获取存储统计信息失败', e);
      return <String, dynamic>{};
    }
  }

  /// 从单独的键值对加载设置（向后兼容）
  static Future<ThemeSettings> _loadFromIndividualKeys(
    SharedPreferences prefs,
  ) async {
    try {
      final isDarkMode = prefs.getBool(_keyIsDarkMode) ?? false;
      final fontSizeOptionStr = prefs.getString(_keyFontSizeOption) ?? 'normal';
      final followSystemTheme = prefs.getBool(_keyFollowSystemTheme) ?? false;
      final animationDuration = prefs.getInt(_keyAnimationDuration) ?? 300;

      // 解析字体大小选项
      final fontSizeOption =
          FontSizeOption.fromValue(fontSizeOptionStr) ?? FontSizeOption.normal;

      return ThemeSettings(
        isDarkMode: isDarkMode,
        fontSizeOption: fontSizeOption,
        followSystemTheme: followSystemTheme,
        animationDuration: animationDuration,
      );
    } catch (e) {
      _logError('从单独键值对加载设置失败', e);
      return ThemeSettings.defaultSettings;
    }
  }

  /// 安全的错误日志记录
  static void _logError(String message, dynamic error) {
    // 在生产环境中，这里可以集成到日志系统
    // 目前只是简单的调试输出
    debugPrint('ThemeStorageHandler Error: $message - $error');
  }

  /// 迁移旧版本的设置格式
  static Future<bool> migrateFromOldFormat() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 检查是否需要迁移
      if (prefs.containsKey(_keyThemeSettings)) {
        return true; // 已经是新格式
      }

      // 如果存在旧的单独键值对，将其合并为新格式
      if (prefs.containsKey(_keyIsDarkMode) ||
          prefs.containsKey(_keyFontSizeOption)) {
        final settings = await _loadFromIndividualKeys(prefs);
        return await saveThemeSettings(settings);
      }

      return true; // 没有需要迁移的数据
    } catch (e) {
      _logError('迁移设置格式失败', e);
      return false;
    }
  }
}
