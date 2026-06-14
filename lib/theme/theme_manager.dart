import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'default/font_types.dart';
import 'providers/theme_provider.dart';

/// 主题管理器
///
/// 统一封装 Riverpod 主题 Provider 的读取入口。
///
/// 推荐新代码直接使用 themeProvider：
/// ```dart
/// // 在 ConsumerWidget 中
/// final state = ref.watch(themeProvider);
/// final themeNotifier = ref.read(themeProvider.notifier);
///
/// // 获取主题
/// ThemeData lightTheme = themeNotifier.lightTheme;
/// ```
class ThemeManager {
  ThemeManager._();

  static ThemeManager? _instance;
  static ThemeManager get instance {
    _instance ??= ThemeManager._();
    return _instance!;
  }

  // 必须通过 setProviderContainer 注入应用级容器，否则主题状态与 UI 不同步
  // 初始值为 null，防止创建与根容器状态不同步的孤立容器
  ProviderContainer? _container;

  /// 注入应用级 ProviderContainer（在 run.dart 中调用）
  void setProviderContainer(ProviderContainer container) {
    _container = container;
  }

  /// 获取已注入的容器，未注入时抛出断言错误
  ProviderContainer get _containerInternal {
    assert(
      _container != null,
      'ThemeManager: ProviderContainer 未注入，请先调用 setProviderContainer',
    );
    return _container!;
  }

  /// 获取内部 Riverpod 状态
  ThemeState get _state => _containerInternal.read(themeProvider);

  /// 获取内部 Riverpod notifier
  ThemeNotifier get _notifier {
    return _containerInternal.read(themeProvider.notifier);
  }

  /// 获取亮色主题（支持动态字体缩放）
  ThemeData get lightTheme => _notifier.lightTheme;

  /// 获取暗色主题（支持动态字体缩放）
  ThemeData get darkTheme => _notifier.darkTheme;

  /// 获取当前主题
  ThemeData get currentTheme => _notifier.currentTheme;

  /// 是否为暗色模式
  bool get isDarkMode => _state.isDarkMode;

  /// 当前字体大小选项
  FontSizeOption get fontSizeOption => _state.fontSizeOption;

  /// 是否跟随系统主题
  bool get followSystemTheme => _state.followSystemTheme;

  /// 是否使用动态颜色
  bool get useDynamicColor => _state.useDynamicColor;

  /// 是否支持动态颜色
  bool get isDynamicColorSupported => _state.isDynamicColorSupported;

  /// 是否正在切换主题
  bool get isThemeChanging => _state.isThemeChanging;

  /// 切换主题（带动画效果）
  Future<void> toggleTheme({bool? isDark, Duration? duration}) async {
    await _notifier.toggleTheme(isDark: isDark, duration: duration);
  }

  /// 根据系统主题自动切换
  void applySystemTheme() {
    _notifier.applySystemTheme();
  }

  /// 获取当前主题的颜色
  Color getThemeColor(String colorKey) {
    return _notifier.getThemeColor(colorKey);
  }

  /// 获取聊天相关颜色
  Color getChatColor(String colorKey) {
    return _notifier.getChatColor(colorKey);
  }

  /// 容器未注入时的字族回退（与 ThemeNotifier.getTextStyle 保持一致）
  static const List<String> _fallbackFontFamily = [
    'PingFang SC',
    'Heiti SC',
    'Microsoft YaHei',
    'sans-serif',
  ];

  /// 容器未注入（widget 测试 / 启动早期）时的降级文本样式。
  ///
  /// 取固定基础字号（不经 FontSizeOption 缩放）——等价于默认设置
  /// （FontSizeOption.normal scale=1.0）下的生产渲染，也等价于迁移前的
  /// 硬编码 `fontSize: type.size`，从而避免 `_notifier` 断言崩溃。
  TextStyle _fallbackTextStyle(
    FontSizeType type, {
    FontWeight? fontWeight,
    Color? color,
  }) {
    return TextStyle(
      fontSize: type.size,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
      fontFamilyFallback: _fallbackFontFamily,
    );
  }

  /// 获取字体大小（支持动态缩放）
  double getFontSize(FontSizeType type, {BuildContext? context}) {
    if (_container == null) return type.size;
    return _notifier.getFontSize(type, context: context);
  }

  /// 获取缩放后的字体大小
  double getScaledFontSize(FontSizeType type, {BuildContext? context}) {
    if (_container == null) return type.size;
    return _notifier.getScaledFontSize(type, context: context);
  }

  /// 获取文本样式（支持动态缩放）
  TextStyle getTextStyle(
    FontSizeType type, {
    FontWeight? fontWeight,
    Color? color,
    BuildContext? context,
  }) {
    if (_container == null) {
      return _fallbackTextStyle(type, fontWeight: fontWeight, color: color);
    }
    return _notifier.getTextStyle(
      type,
      fontWeight: fontWeight,
      color: color,
      context: context,
    );
  }

  /// 根据当前设置获取动态 TextTheme
  TextTheme getTextTheme({BuildContext? context}) {
    return _notifier.getTextTheme(context: context);
  }

  /// 更新字体大小选项并刷新主题
  Future<void> updateFontSize(String fontSizeValue) async {
    await _notifier.updateFontSize(fontSizeValue);
  }

  /// 更新字体大小选项
  Future<void> updateFontSizeOption(FontSizeOption option) async {
    await _notifier.updateFontSizeOption(option);
  }

  /// 获取当前字体大小的字符串值
  String get currentFontSizeValue => _notifier.currentFontSizeValue;

  /// 获取所有可用的字体大小选项
  List<FontSizeOption> get availableFontSizes => _notifier.availableFontSizes;

  /// 检查当前字体大小是否符合可访问性标准
  bool get isCurrentFontSizeAccessible => _notifier.isCurrentFontSizeAccessible;

  /// 获取推荐的字体大小选项（基于系统设置）
  FontSizeOption getRecommendedFontSize(BuildContext context) {
    return _notifier.getRecommendedFontSize(context);
  }

  /// 预览指定字体大小选项的效果
  Map<String, dynamic> previewFontSize(
    FontSizeOption option, {
    BuildContext? context,
  }) {
    return _notifier.previewFontSize(option, context: context);
  }

  /// 获取当前主题设置（用于调试和监控）
  Map<String, dynamic> getThemeSettings() {
    return _notifier.getThemeSettings();
  }

  /// 更新跟随系统主题设置
  Future<void> updateFollowSystemTheme(bool followSystem) async {
    await _notifier.updateFollowSystemTheme(followSystem);
  }

  /// 更新动态颜色设置
  Future<void> updateUseDynamicColor(bool useDynamic) async {
    await _notifier.updateUseDynamicColor(useDynamic);
  }

  /// 检测动态颜色支持
  Future<void> detectDynamicColorSupport() async {
    await _notifier.detectDynamicColorSupport();
  }

  /// 获取动态颜色信息（用于调试）
  Future<Map<String, dynamic>> getDynamicColorInfo() async {
    return await _notifier.getDynamicColorInfo();
  }

  /// 从本地存储加载主题设置
  Future<void> loadThemePreference() async {
    await _notifier.loadThemePreference();
  }

  /// 重置实例（用于测试）
  static void resetInstance() {
    _instance = null;
  }

  /// 清理资源（注入的容器由外部管理，此处仅重置引用）
  void dispose() {
    _container = null;
  }
}
