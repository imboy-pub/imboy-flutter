import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'default/app_colors.dart';

/// 动态颜色管理器
/// 
/// 负责检测和应用 Android 12+ 的动态颜色（Material You）
/// 提供动态颜色检测、生成和应用功能
class DynamicColorManager {
  DynamicColorManager._();
  
  static DynamicColorManager? _instance;
  static DynamicColorManager get instance {
    _instance ??= DynamicColorManager._();
    return _instance!;
  }

  // 缓存的动态颜色方案
  ColorScheme? _cachedLightDynamicColorScheme;
  ColorScheme? _cachedDarkDynamicColorScheme;
  
  // 动态颜色是否可用
  bool? _isDynamicColorSupported;
  
  /// 检查设备是否支持动态颜色
  /// 
  /// 返回 true 如果设备支持动态颜色（Android 12+）
  Future<bool> isDynamicColorSupported() async {
    if (_isDynamicColorSupported != null) {
      return _isDynamicColorSupported!;
    }
    
    try {
      // 只有 Android 平台支持动态颜色
      if (!Platform.isAndroid) {
        _isDynamicColorSupported = false;
        return false;
      }
      
      // 尝试获取动态颜色方案来检测支持性
      final corePalette = await DynamicColorPlugin.getCorePalette();
      _isDynamicColorSupported = corePalette != null;
      
      return _isDynamicColorSupported!;
    } catch (e) {
      debugPrint('DynamicColorManager: 检测动态颜色支持失败 - $e');
      _isDynamicColorSupported = false;
      return false;
    }
  }
  
  /// 获取动态颜色方案
  /// 
  /// 返回包含亮色和暗色动态颜色方案的元组
  /// 如果不支持动态颜色，返回 null
  Future<({ColorScheme? light, ColorScheme? dark})?> getDynamicColorSchemes() async {
    try {
      // 检查是否支持动态颜色
      if (!await isDynamicColorSupported()) {
        return null;
      }
      
      // 如果已缓存，直接返回
      if (_cachedLightDynamicColorScheme != null && _cachedDarkDynamicColorScheme != null) {
        return (
          light: _cachedLightDynamicColorScheme,
          dark: _cachedDarkDynamicColorScheme
        );
      }
      
      // 获取动态颜色方案
      final corePalette = await DynamicColorPlugin.getCorePalette();
      if (corePalette == null) {
        return null;
      }
      
      // 生成亮色和暗色方案
      _cachedLightDynamicColorScheme = corePalette.toColorScheme(brightness: Brightness.light);
      _cachedDarkDynamicColorScheme = corePalette.toColorScheme(brightness: Brightness.dark);
      
      return (
        light: _cachedLightDynamicColorScheme,
        dark: _cachedDarkDynamicColorScheme
      );
    } catch (e) {
      debugPrint('DynamicColorManager: 获取动态颜色方案失败 - $e');
      return null;
    }
  }
  
  /// 创建带有动态颜色的颜色方案
  /// 
  /// [isDark] 是否为暗色主题
  /// [useDynamicColor] 是否使用动态颜色
  /// 返回合并了动态颜色的 ColorScheme
  Future<ColorScheme> createColorScheme({
    required bool isDark,
    bool useDynamicColor = true,
  }) async {
    // 获取基础颜色方案
    final baseColorScheme = isDark ? _createBaseDarkColorScheme() : _createBaseLightColorScheme();
    
    // 如果不使用动态颜色或不支持，返回基础方案
    if (!useDynamicColor || !await isDynamicColorSupported()) {
      return baseColorScheme;
    }
    
    try {
      // 获取动态颜色方案
      final dynamicSchemes = await getDynamicColorSchemes();
      if (dynamicSchemes == null) {
        return baseColorScheme;
      }
      
      final dynamicScheme = isDark ? dynamicSchemes.dark : dynamicSchemes.light;
      if (dynamicScheme == null) {
        return baseColorScheme;
      }
      
      // 合并动态颜色和基础颜色
      return _mergeDynamicColors(baseColorScheme, dynamicScheme);
    } catch (e) {
      debugPrint('DynamicColorManager: 创建动态颜色方案失败 - $e');
      return baseColorScheme;
    }
  }
  
  /// 创建基础亮色颜色方案
  ColorScheme _createBaseLightColorScheme() {
    return ColorScheme.light(
      // Primary colors - 主色系
      primary: AppColors.primaryGreen,
      onPrimary: Colors.white,
      primaryContainer: AppColors.greenContainer,
      onPrimaryContainer: AppColors.onGreenContainer,
      
      // Secondary colors - 次要色系
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      
      // Tertiary colors - 第三色系
      tertiary: AppColors.tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: AppColors.onTertiaryContainer,
      
      // Error colors - 错误色系
      error: AppColors.lightError,
      onError: Colors.white,
      errorContainer: AppColors.lightErrorContainer,
      onErrorContainer: AppColors.lightOnErrorContainer,
      
      // Surface colors - 表面色系
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      onSurfaceVariant: AppColors.lightTextSecondary,
      surfaceContainerHighest: AppColors.lightSurfaceContainerHighest,
      
      // Outline colors - 轮廓色系
      outline: AppColors.lightBorder,
      outlineVariant: AppColors.lightDivider,
    );
  }
  
  /// 创建基础暗色颜色方案
  ColorScheme _createBaseDarkColorScheme() {
    return ColorScheme.dark(
      // Primary colors - 主色系
      primary: AppColors.primaryGreenLight,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryGreenDark,
      onPrimaryContainer: AppColors.onGreenContainer,
      
      // Secondary colors - 次要色系
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      
      // Tertiary colors - 第三色系
      tertiary: AppColors.tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: AppColors.onTertiaryContainer,
      
      // Error colors - 错误色系
      error: AppColors.darkError,
      onError: Colors.black,
      errorContainer: AppColors.darkErrorContainer,
      onErrorContainer: AppColors.darkOnErrorContainer,
      
      // Surface colors - 表面色系
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      onSurfaceVariant: AppColors.darkTextSecondary,
      surfaceContainerHighest: AppColors.darkSurfaceContainerHighest,
      
      // Outline colors - 轮廓色系
      outline: AppColors.darkBorder,
      outlineVariant: AppColors.darkDivider,
    );
  }
  
  /// 合并动态颜色和基础颜色
  /// 
  /// [baseScheme] 基础颜色方案
  /// [dynamicScheme] 动态颜色方案
  /// 返回合并后的颜色方案
  ColorScheme _mergeDynamicColors(ColorScheme baseScheme, ColorScheme dynamicScheme) {
    // 使用动态颜色的主要颜色，保留应用特定的表面和错误颜色
    return baseScheme.copyWith(
      // 使用动态颜色的主色系
      primary: dynamicScheme.primary,
      onPrimary: dynamicScheme.onPrimary,
      primaryContainer: dynamicScheme.primaryContainer,
      onPrimaryContainer: dynamicScheme.onPrimaryContainer,
      
      // 使用动态颜色的次要色系
      secondary: dynamicScheme.secondary,
      onSecondary: dynamicScheme.onSecondary,
      secondaryContainer: dynamicScheme.secondaryContainer,
      onSecondaryContainer: dynamicScheme.onSecondaryContainer,
      
      // 使用动态颜色的第三色系
      tertiary: dynamicScheme.tertiary,
      onTertiary: dynamicScheme.onTertiary,
      tertiaryContainer: dynamicScheme.tertiaryContainer,
      onTertiaryContainer: dynamicScheme.onTertiaryContainer,
      
      // 保留应用特定的错误颜色
      // error: baseScheme.error,
      // onError: baseScheme.onError,
      // errorContainer: baseScheme.errorContainer,
      // onErrorContainer: baseScheme.onErrorContainer,
      
      // 使用动态颜色的表面颜色
      surface: dynamicScheme.surface,
      onSurface: dynamicScheme.onSurface,
      surfaceContainerHighest: dynamicScheme.surfaceContainerHighest,
      onSurfaceVariant: dynamicScheme.onSurfaceVariant,
      
      // 使用动态颜色的轮廓颜色
      outline: dynamicScheme.outline,
      outlineVariant: dynamicScheme.outlineVariant,
    );
  }
  
  /// 清除缓存的动态颜色方案
  /// 
  /// 当系统壁纸或主题发生变化时调用
  void clearCache() {
    _cachedLightDynamicColorScheme = null;
    _cachedDarkDynamicColorScheme = null;
    _isDynamicColorSupported = null;
  }
  
  /// 获取动态颜色信息（用于调试）
  /// 
  /// 返回包含动态颜色支持状态和颜色信息的 Map
  Future<Map<String, dynamic>> getDynamicColorInfo() async {
    final isSupported = await isDynamicColorSupported();
    
    if (!isSupported) {
      return {
        'supported': false,
        'platform': Platform.operatingSystem,
        'reason': '设备不支持动态颜色或非 Android 平台',
      };
    }
    
    try {
      final schemes = await getDynamicColorSchemes();
      return {
        'supported': true,
        'platform': Platform.operatingSystem,
        'hasLightScheme': schemes?.light != null,
        'hasDarkScheme': schemes?.dark != null,
        'lightPrimary': schemes?.light?.primary.toString(),
        'darkPrimary': schemes?.dark?.primary.toString(),
      };
    } catch (e) {
      return {
        'supported': true,
        'platform': Platform.operatingSystem,
        'error': e.toString(),
      };
    }
  }
}