import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'default/font_types.dart';
import 'providers/theme_provider.dart';

/// 主题管理器 - 向后兼容层
///
/// 这是一个兼容层，用于逐步迁移从 GetX 到 Riverpod 的代码。
/// 内部使用 Riverpod Provider，但保持旧的 API 不变。
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
///
/// 旧代码可以继续使用：
/// ```dart
/// ThemeManager.instance.lightTheme
/// ThemeManager.instance.toggleTheme(isDark: true);
/// ```
class ThemeManager {
  ThemeManager._();

  static ThemeManager? _instance;
  static ThemeManager get instance {
    _instance ??= ThemeManager._();
    return _instance!;
  }

  ProviderContainer? _container;

  /// 初始化容器（需要在 main 中调用）
  /// 注意：在新架构中，ThemeManager 通过 ProviderScope 访问状态，
  /// 不再需要手动初始化独立的 ProviderContainer
  @Deprecated('不再需要手动初始化，ThemeManager 现在通过 ProviderScope 访问状态')
  void initialize() {
    _container ??= ProviderContainer();
  }

  /// 获取内部 ProviderContainer（向后兼容）
  ProviderContainer get _containerInternal {
    _container ??= ProviderContainer();
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

  /// 获取字体大小（支持动态缩放）
  double getFontSize(FontSizeType type, {BuildContext? context}) {
    return _notifier.getFontSize(type, context: context);
  }

  /// 获取缩放后的字体大小
  double getScaledFontSize(FontSizeType type, {BuildContext? context}) {
    return _notifier.getScaledFontSize(type, context: context);
  }

  /// 获取文本样式（支持动态缩放）
  TextStyle getTextStyle(
    FontSizeType type, {
    FontWeight? fontWeight,
    Color? color,
    BuildContext? context,
  }) {
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

  /// 获取当前字体大小的字符串值（兼容旧版本）
  String get currentFontSizeValue => _notifier.currentFontSizeValue;

  /// 获取所有可用的字体大小选项
  List<FontSizeOption> get availableFontSizes => _notifier.availableFontSizes;

  /// 检查当前字体大小是否符合可访问性标准
  bool get isCurrentFontSizeAccessible => _notifier.isCurrentFontSizeAccessible;

  /// 获取推荐的字体大小选项（基于系统设置）
  FontSizeOption getRecommendedFontSize(BuildContext context) {
    return _notifier.getRecommendedFontSize(context);
  }

  /// ⚠️ GetX 兼容：获取主间距（用于向后兼容）
  ///
  /// Design Token 参考：`lib/theme/default/app_spacing.dart`
  ///
  /// 使用示例：
  /// ```dart
  /// horizontal: ThemeManager.instance.mainSpace * 2,
  /// ```
  @Deprecated('使用 AppSpacing 替代。示例：horizontal: AppSpacing.normal * 2')
  double get mainSpace => _notifier.mainSpace;

  /// ⚠️ GetX 兼容：获取次要间距
  @Deprecated('使用 AppSpacing 替代。示例：padding: AppSpacing.small')
  double get secondarySpace => _notifier.secondarySpace;

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

  /// 获取性能统计信息（兼容旧版本，建议使用 getThemeSettings）
  @Deprecated('使用 getThemeSettings() 替代')
  Map<String, dynamic> getPerformanceStats() => getThemeSettings();

  /// 获取缓存统计信息（兼容旧版本，建议使用 getThemeSettings）
  @Deprecated('使用 getThemeSettings() 替代')
  Map<String, dynamic> getCacheStats() => getThemeSettings();

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

  /// 清理资源
  void dispose() {
    _container?.dispose();
  }
}
