import 'package:imboy/theme/default/font_types.dart';

/// 应用文本大小常量类
///
/// @Deprecated('使用 FontSizeType 代替。此类将在下个版本移除。')
/// 请使用 `FontSizeType` 枚举代替，例如：
/// - `AppTextSize.small` → `FontSizeType.small.size`
/// - `AppTextSize.getFontSizeValue('large')` → `FontSizeType.large.size`
///
/// 迁移示例：
/// ```dart
/// // 旧方式（已废弃）
/// final size = AppTextSize.medium;
///
/// // 新方式（推荐）
/// final size = FontSizeType.medium.size;
/// ```
@Deprecated('使用 FontSizeType 代替。此类将在下个版本移除。')
class AppTextSize {
  AppTextSize._();

  /// 获取当前主题管理器
  static ThemeManager get _themeManager => ThemeManager.instance;

  /// 超小字体 - 10px (基于 FontSizeType.tiny)
  static double get tiny => _themeManager.getScaledFontSize(FontSizeType.tiny);

  /// 小字体 - 12px (基于 FontSizeType.small)
  static double get small =>
      _themeManager.getScaledFontSize(FontSizeType.small);

  /// 普通字体 - 14px (基于 FontSizeType.normal)
  static double get normal =>
      _themeManager.getScaledFontSize(FontSizeType.normal);

  /// 中等字体 - 16px (基于 FontSizeType.medium)
  static double get medium =>
      _themeManager.getScaledFontSize(FontSizeType.medium);

  /// 大字体 - 18px (基于 FontSizeType.large)
  static double get large =>
      _themeManager.getScaledFontSize(FontSizeType.large);

  /// 超大字体 - 20px (基于 FontSizeType.extraLarge)
  static double get extraLarge =>
      _themeManager.getScaledFontSize(FontSizeType.extraLarge);

  /// 标题字体 - 22px (基于 FontSizeType.title)
  static double get title =>
      _themeManager.getScaledFontSize(FontSizeType.title);

  /// 副标题字体 - 18px (基于 FontSizeType.large)
  static double get subTitle =>
      _themeManager.getScaledFontSize(FontSizeType.large);

  /// 大标题字体 - 24px (基于 FontSizeType.largeTitle)
  static double get largeTitle =>
      _themeManager.getScaledFontSize(FontSizeType.largeTitle);

  /// 超大标题字体 - 28px (基于 FontSizeType.extraLargeTitle)
  static double get extraLargeTitle =>
      _themeManager.getScaledFontSize(FontSizeType.extraLargeTitle);

  /// 获取字体大小显示名称（兼容旧版本）
  static String getFontSizeDisplayName(String fontSize) {
    switch (fontSize.toLowerCase()) {
      case 'tiny':
        return '超小';
      case 'small':
        return '小';
      case 'normal':
        return '标准';
      case 'medium':
        return '中等';
      case 'large':
        return '大';
      case 'extralarge':
      case 'extra_large':
        return '超大';
      case 'title':
        return '标题';
      case 'subtitle':
      case 'sub_title':
        return '副标题';
      case 'largetitle':
      case 'large_title':
        return '大标题';
      case 'extralargetitle':
      case 'extra_large_title':
        return '超大标题';
      default:
        return '标准';
    }
  }

  /// 根据字符串获取字体大小值（兼容旧版本）
  static double getFontSizeValue(String fontSize) {
    switch (fontSize.toLowerCase()) {
      case 'tiny':
        return tiny;
      case 'small':
        return small;
      case 'normal':
        return normal;
      case 'medium':
        return medium;
      case 'large':
        return large;
      case 'extralarge':
      case 'extra_large':
        return extraLarge;
      case 'title':
        return title;
      case 'subtitle':
      case 'sub_title':
        return subTitle;
      case 'largetitle':
      case 'large_title':
        return largeTitle;
      case 'extralargetitle':
      case 'extra_large_title':
        return extraLargeTitle;
      default:
        return normal;
    }
  }

  /// 获取所有可用的字体大小选项
  static List<String> get allSizes => [
    'tiny',
    'small',
    'normal',
    'medium',
    'large',
    'extraLarge',
    'title',
    'subTitle',
    'largeTitle',
    'extraLargeTitle',
  ];

  /// 获取所有字体大小的显示名称
  static List<String> get allDisplayNames => [
    '超小',
    '小',
    '标准',
    '中等',
    '大',
    '超大',
    '标题',
    '副标题',
    '大标题',
    '超大标题',
  ];
}
