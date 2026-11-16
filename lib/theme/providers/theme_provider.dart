import 'package:imboy/service/web_writer_gate.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../default/theme.dart';
import '../default/app_colors.dart';
import '../default/font_types.dart';
import '../default/config/text_theme.dart';
import '../dynamic_color_manager.dart';

part 'theme_provider.g.dart';

/// MaterialApp mode is a projection of the same persisted theme state.
@riverpod
class ThemeModeNotifier extends _$ThemeModeNotifier {
  @override
  ThemeMode build() => ref.watch(
    themeProvider.select(
      (value) => value.followSystemTheme
          ? ThemeMode.system
          : value.isDarkMode
          ? ThemeMode.dark
          : ThemeMode.light,
    ),
  );

  Future<void> setThemeMode(ThemeMode mode) =>
      ref.read(themeProvider.notifier).setThemeMode(mode);

  Future<void> toggleTheme(bool isDark) =>
      setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);

  Future<void> setFollowSystem(bool follow) =>
      setThemeMode(follow ? ThemeMode.system : ThemeMode.light);
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
  late ThemeData _cachedLightTheme;
  late ThemeData _cachedDarkTheme;
  Future<void> _writes = Future<void>.value();
  int _fontRequestRevision = 0;
  bool _preferencesLoaded = false;

  /// Capture before an account restore; a newer explicit choice wins.
  int get fontRequestRevision => _fontRequestRevision;

  @override
  ThemeState build() {
    _cachedLightTheme = AppTheme.getLightThemeFromOption(FontSizeOption.normal);
    _cachedDarkTheme = AppTheme.getDarkThemeFromOption(FontSizeOption.normal);
    // Queue initialization before any user action; a late read cannot overtake it.
    unawaited(
      loadThemePreference().catchError((Object error) {
        debugPrint('[theme] initial preference read: ${error.runtimeType}');
      }),
    );
    return const ThemeState();
  }

  Future<void> _enqueue(
    Future<void> Function() operation, {
    bool loadFirst = true,
  }) {
    final result = _writes.then((_) async {
      if (!ref.mounted) return;
      if (loadFirst && !_preferencesLoaded) await _readPreferences();
      if (ref.mounted) await operation();
    });
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _publishPreferences(ThemeState next) {
    if (!ref.mounted) return;
    state = state.copyWith(
      isDarkMode: next.isDarkMode,
      fontSizeOption: next.fontSizeOption,
      followSystemTheme: next.followSystemTheme,
      useDynamicColor: next.useDynamicColor,
    );
    _cachedLightTheme = AppTheme.getLightThemeFromOption(next.fontSizeOption);
    _cachedDarkTheme = AppTheme.getDarkThemeFromOption(next.fontSizeOption);
  }

  Future<void> _writeValue(
    SharedPreferences prefs,
    String key,
    Object? value,
  ) async {
    requireWebWriter();
    final saved = switch (value) {
      null => await prefs.remove(key),
      bool value => await prefs.setBool(key, value),
      String value => await prefs.setString(key, value),
      _ => throw StateError('Invalid theme preference type'),
    };
    if (!saved) throw StateError('Could not persist theme preference');
  }

  /// SharedPreferences updates its cache optimistically. Compensate partial
  /// multi-key writes and reload on failure; never publish a failed selection.
  Future<void> _commit(
    ThemeState next, {
    Future<bool> Function()? saveAccountFont,
    bool Function()? isCurrent,
  }) async {
    bool current() =>
        isWebWriterReady && ref.mounted && (isCurrent?.call() ?? true);
    if (!current()) throw StateError('Theme preference owner changed');
    final prefs = await SharedPreferences.getInstance();
    if (!current()) throw StateError('Theme preference owner changed');
    final values = <String, Object>{
      'theme_is_dark_mode': next.isDarkMode,
      'theme_font_size': next.fontSizeOption.value,
      'theme_follow_system': next.followSystemTheme,
      'theme_use_dynamic_color': next.useDynamicColor,
    };
    final before = {for (final key in values.keys) key: prefs.get(key)};
    final touched = <String>[];
    try {
      for (final entry in values.entries) {
        if (before[entry.key] == entry.value) continue;
        touched.add(entry.key);
        await _writeValue(prefs, entry.key, entry.value);
        if (!current()) throw StateError('Theme preference owner changed');
      }
      if (saveAccountFont != null && !await saveAccountFont()) {
        throw StateError('Account font preference was not saved');
      }
      if (!current()) throw StateError('Theme preference owner changed');
    } on Object catch (error, stack) {
      Object? rollbackError;
      for (final key in touched.reversed) {
        try {
          await _writeValue(prefs, key, before[key]);
        } on Object catch (error) {
          rollbackError ??= error;
        }
      }
      try {
        await prefs.reload();
      } on Object catch (error) {
        rollbackError ??= error;
      }
      if (rollbackError != null) {
        throw StateError(
          'Theme save failed; durable preference recovery failed',
        );
      }
      Error.throwWithStackTrace(error, stack);
    }
    _publishPreferences(next);
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

  /// A manual toggle commits through the same queue as mode and font changes.
  Future<void> toggleTheme({bool? isDark, Duration? duration}) =>
      _enqueue(() async {
        state = state.copyWith(isThemeChanging: true);
        try {
          await _commit(
            state.copyWith(
              isDarkMode: isDark ?? !state.isDarkMode,
              followSystemTheme: false,
            ),
          );
          await Future<void>.delayed(
            duration ?? const Duration(milliseconds: 300),
          );
        } finally {
          if (ref.mounted) state = state.copyWith(isThemeChanging: false);
        }
      });

  Future<void> setThemeMode(ThemeMode mode) => _enqueue(() async {
    final dark = mode == ThemeMode.system
        ? WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark
        : mode == ThemeMode.dark;
    await _commit(
      state.copyWith(
        isDarkMode: dark,
        followSystemTheme: mode == ThemeMode.system,
      ),
    );
  });

  /// System brightness is effective state, not a new manual preference write.
  void applySystemTheme() {
    unawaited(
      _enqueue(() async {
        if (!state.followSystemTheme) return;
        final dark =
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
        state = state.copyWith(isDarkMode: dark);
      }).catchError((Object error) {
        debugPrint('[theme] system brightness: ${error.runtimeType}');
      }),
    );
  }

  Future<void> loadThemePreference() =>
      _enqueue(_readPreferences, loadFirst: false);

  Future<void> _readPreferences() async {
    final supported = await DynamicColorManager.instance
        .isDynamicColorSupported();
    if (!ref.mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final follow = prefs.getBool('theme_follow_system') ?? false;
    final dark = follow
        ? WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark
        : prefs.getBool('theme_is_dark_mode') ?? false;
    final option =
        FontSizeOption.fromValue(prefs.getString('theme_font_size') ?? '') ??
        FontSizeOption.normal;
    state = state.copyWith(isDynamicColorSupported: supported);
    _publishPreferences(
      state.copyWith(
        isDarkMode: dark,
        fontSizeOption: option,
        followSystemTheme: follow,
        useDynamicColor:
            supported && (prefs.getBool('theme_use_dynamic_color') ?? false),
      ),
    );
    _preferencesLoaded = true;
  }

  /// Startup account font takes precedence over the device fallback, but never
  /// over an explicit choice made during startup. This restoration does no IO write.
  Future<void> restoreAccountFontSize(
    String value, {
    required bool Function() isCurrent,
    int expectedRevision = 0,
  }) => _enqueue(() async {
    if (_fontRequestRevision != expectedRevision || !isCurrent()) return;
    final option = FontSizeOption.fromValue(value) ?? FontSizeOption.normal;
    _publishPreferences(state.copyWith(fontSizeOption: option));
  });

  /// 获取当前主题的颜色
  Color getThemeColor(String colorKey) {
    final isDark = state.followSystemTheme
        ? WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark
        : state.isDarkMode;
    switch (colorKey) {
      case 'primary':
        return isDark ? AppColors.primaryLight : AppColors.primary;
      case 'surface':
        if (isDark) {
          return AppColors.getDarkSurface(false, Brightness.dark);
        }
        return AppColors.lightSurface;
      case 'background':
        if (isDark) {
          return AppColors.getDarkBackground(false, Brightness.dark);
        }
        return AppColors.lightBackground;
      case 'textPrimary':
        if (isDark) {
          return AppColors.darkTextPrimary;
        }
        return AppColors.lightTextPrimary;
      case 'textSecondary':
        if (isDark) {
          return AppColors.darkTextSecondary;
        }
        return AppColors.lightTextSecondary;
      case 'border':
        return isDark ? AppColors.darkBorder : AppColors.lightBorder;
      case 'error':
        return isDark ? AppColors.darkError : AppColors.lightError;
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
      // F5（PERF-05）：首位挂内嵌 NotoSansSC 中文子集，阻断 fonts.gstatic 动态
      // 字体拉取（与 ThemeData.fontFamilyFallback 同源 kAppFontFamilyFallback）。
      fontFamilyFallback: kAppFontFamilyFallback,
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

  Future<void> updateFontSize(String value) => updateFontSizeOption(
    FontSizeOption.fromValue(value) ?? FontSizeOption.normal,
  );

  /// Font callers can bind their existing account-setting write to this same
  /// commit. No other preference action can overtake its save or compensation.
  Future<void> updateFontSizeOption(
    FontSizeOption option, {
    Future<bool> Function()? saveAccountFont,
    bool Function()? isCurrent,
  }) {
    _fontRequestRevision++;
    return _enqueue(
      () => _commit(
        state.copyWith(fontSizeOption: option),
        saveAccountFont: saveAccountFont,
        isCurrent: isCurrent,
      ),
    );
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

  Future<void> updateFollowSystemTheme(bool followSystem) =>
      setThemeMode(followSystem ? ThemeMode.system : ThemeMode.light);

  Future<void> updateUseDynamicColor(bool useDynamic) => _enqueue(
    () => _commit(
      state.copyWith(
        useDynamicColor: useDynamic && state.isDynamicColorSupported,
      ),
    ),
  );

  Future<void> detectDynamicColorSupport() => _enqueue(() async {
    final supported = await DynamicColorManager.instance
        .isDynamicColorSupported();
    if (!ref.mounted) return;
    state = state.copyWith(
      isDynamicColorSupported: supported,
      useDynamicColor: supported && state.useDynamicColor,
    );
  });

  /// 获取动态颜色信息（用于调试）
  Future<Map<String, dynamic>> getDynamicColorInfo() async {
    return await DynamicColorManager.instance.getDynamicColorInfo();
  }
}
