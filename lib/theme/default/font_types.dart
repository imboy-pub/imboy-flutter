import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart' show t;
import 'package:imboy/theme/theme_manager.dart' show ThemeManager;
// 统一对外导出 ThemeManager，方便其它文件只引入 font_types.dart 即可使用 ThemeManager
export 'package:imboy/theme/theme_manager.dart' show ThemeManager;

/// 字体大小类型枚举
/// 提供类型安全的字体大小定义，避免使用字符串常量
enum FontSizeType {
  /// 超小字体 - 10px
  tiny(10.0, '超小'),

  /// iOS Caption2 - 11px（iOS 保真页 Apple 字号阶）
  caption2(11.0, '注释'),

  /// 小字体 - 12px
  small(12.0, '小'),

  /// iOS Footnote - 13px（iOS 保真页 Apple 字号阶）
  footnote(13.0, '脚注'),

  /// 普通字体 - 14px
  normal(14.0, '普通'),

  /// iOS Subheadline - 15px（iOS 保真页 Apple 字号阶）
  subheadline(15.0, '副标题'),

  /// 中等字体 - 16px
  medium(16.0, '中等'),

  /// iOS Body - 17px（iOS 保真页 Apple 字号阶）
  body(17.0, '正文'),

  /// 大字体 - 18px
  large(18.0, '大'),

  /// 超大字体 - 20px
  extraLarge(20.0, '超大'),

  /// 标题字体 - 22px
  title(22.0, '标题'),

  /// 大标题字体 - 24px
  largeTitle(24.0, '大标题'),

  /// 超大标题字体 - 28px
  extraLargeTitle(28.0, '超大标题');

  const FontSizeType(this.size, this.displayName);

  /// 字体大小值
  final double size;

  /// 显示名称（用于UI显示）
  final String displayName;

  /// 获取所有可用的字体大小选项
  static List<FontSizeType> get allSizes => FontSizeType.values;

  /// 根据字符串名称获取字体类型（兼容旧版本）
  static FontSizeType? fromString(String name) {
    switch (name.toLowerCase()) {
      case 'tiny':
      case '超小':
        return FontSizeType.tiny;
      case 'small':
      case '小':
        return FontSizeType.small;
      case 'normal':
      case '普通':
      case 'default':
        return FontSizeType.normal;
      case 'medium':
      case '中等':
        return FontSizeType.medium;
      case 'large':
      case '大':
        return FontSizeType.large;
      case 'extra_large':
      case '超大':
        return FontSizeType.extraLarge;
      case 'title':
      case '标题':
        return FontSizeType.title;
      case 'large_title':
      case '大标题':
        return FontSizeType.largeTitle;
      case 'extra_large_title':
      case '超大标题':
        return FontSizeType.extraLargeTitle;
      case 'caption2':
      case '注释':
        return FontSizeType.caption2;
      case 'footnote':
      case '脚注':
        return FontSizeType.footnote;
      case 'subheadline':
      case '副标题':
        return FontSizeType.subheadline;
      case 'body':
      case '正文':
        return FontSizeType.body;
      default:
        return null;
    }
  }

  /// 转换为字符串（用于存储和序列化）
  @override
  String toString() => name;
}

/// 字体大小选项枚举
/// 定义用户可选择的字体大小级别，包含缩放比例
enum FontSizeOption {
  /// 小字体 - 0.9倍缩放
  small(0.9, '小', 'small'),

  /// 标准字体 - 1.0倍缩放（基准）
  normal(1.0, '标准', 'normal'),

  /// 中等字体 - 1.1倍缩放
  medium(1.1, '中', 'medium'),

  /// 大字体 - 1.2倍缩放
  large(1.2, '大', 'large'),

  /// 特大字体 - 1.3倍缩放
  extraLarge(1.3, '特大', 'extraLarge'),

  /// 超大字体 - 1.4倍缩放
  huge(1.4, '超大', 'huge');

  const FontSizeOption(this.scale, this.displayName, this.value);

  /// 缩放比例
  final double scale;

  /// 显示名称（中文兜底；UI 显示请用 [localizedName]，QA#23）
  final String displayName;

  /// 字符串值（用于存储和兼容性）
  final String value;

  /// 本地化显示名（跟随当前 locale）
  String get localizedName => switch (this) {
    FontSizeOption.small => t.common.fontSizeOptionSmall,
    FontSizeOption.normal => t.common.fontSizeOptionNormal,
    FontSizeOption.medium => t.common.fontSizeOptionMedium,
    FontSizeOption.large => t.common.fontSizeOptionLarge,
    FontSizeOption.extraLarge => t.common.fontSizeOptionExtraLarge,
    FontSizeOption.huge => t.common.fontSizeOptionHuge,
  };

  /// 获取所有可用的字体大小选项
  static List<FontSizeOption> get allOptions => FontSizeOption.values;

  /// 根据字符串值获取字体大小选项
  static FontSizeOption? fromValue(String value) {
    for (final option in FontSizeOption.values) {
      if (option.value == value) {
        return option;
      }
    }
    return null;
  }

  /// 根据缩放比例获取最接近的字体大小选项
  static FontSizeOption fromScale(double scale) {
    FontSizeOption closest = FontSizeOption.normal;
    double minDifference = (scale - FontSizeOption.normal.scale).abs();

    for (final option in FontSizeOption.values) {
      final difference = (scale - option.scale).abs();
      if (difference < minDifference) {
        minDifference = difference;
        closest = option;
      }
    }

    return closest;
  }

  /// 转换为字符串（用于存储和序列化）
  @override
  String toString() => value;
}

/// 字体权重类型枚举
///
/// ⚠️ DESIGN.md §3.3 强制规则：
/// - **禁止使用** `thin` (w100) / `extraLight` (w200) / `light` (w300)
///   — 小字号下可读性差，与 iOS HIG 不符
/// - Body 一律 `normal` (w400)；强调用 `semiBold` (w600)；标题用 `semiBold`/`bold`
/// - `medium` (w500) 仅用于 Callout/Subheadline 次强调，不与 `semiBold` 混用
///
/// 保留 thin/extraLight/light 枚举仅为向后兼容，新代码**不得使用**。
enum FontWeightType {
  /// 细体
  @Deprecated('DESIGN.md §3.3 禁用：可读性差，改用 normal(w400)')
  thin(FontWeight.w100, '细体'),

  /// 超轻
  @Deprecated('DESIGN.md §3.3 禁用：可读性差，改用 normal(w400)')
  extraLight(FontWeight.w200, '超轻'),

  /// 轻体
  @Deprecated('DESIGN.md §3.3 禁用：可读性差，改用 normal(w400)')
  light(FontWeight.w300, '轻体'),

  /// 普通
  normal(FontWeight.w400, '普通'),

  /// 中等
  medium(FontWeight.w500, '中等'),

  /// 半粗
  semiBold(FontWeight.w600, '半粗'),

  /// 粗体
  bold(FontWeight.w700, '粗体'),

  /// 超粗
  extraBold(FontWeight.w800, '超粗'),

  /// 黑体
  black(FontWeight.w900, '黑体');

  const FontWeightType(this.weight, this.displayName);

  /// Flutter FontWeight 值
  final FontWeight weight;

  /// 显示名称
  final String displayName;

  /// 根据字符串获取字体权重
  static FontWeightType? fromString(String name) {
    switch (name.toLowerCase()) {
      case 'thin':
      case '细体':
        return FontWeightType.thin;
      case 'extralight':
      case 'extra_light':
      case '超轻':
        return FontWeightType.extraLight;
      case 'light':
      case '轻体':
        return FontWeightType.light;
      case 'normal':
      case '普通':
      case 'regular':
        return FontWeightType.normal;
      case 'medium':
      case '中等':
        return FontWeightType.medium;
      case 'semibold':
      case 'semi_bold':
      case '半粗':
        return FontWeightType.semiBold;
      case 'bold':
      case '粗体':
        return FontWeightType.bold;
      case 'extrabold':
      case 'extra_bold':
      case '超粗':
        return FontWeightType.extraBold;
      case 'black':
      case '黑体':
        return FontWeightType.black;
      default:
        return null;
    }
  }
}

/// 字体缩放计算工具类
/// 提供字体大小计算、验证和边界检查功能
class FontScaleCalculator {
  FontScaleCalculator._();

  /// 最小缩放比例（WCAG 可访问性标准）
  static const double minScale = 0.8;

  /// 最大缩放比例（避免界面布局问题）
  static const double maxScale = 1.6;

  /// 默认缩放比例
  static const double defaultScale = 1.0;

  /// 计算缩放后的字体大小
  ///
  /// [baseSize] 基础字体大小
  /// [scale] 缩放比例
  /// [context] 构建上下文（可选，用于响应式缩放）
  /// 返回缩放后的字体大小，已应用边界检查
  static double calculateScaledSize(
    double baseSize,
    double scale, {
    BuildContext? context,
  }) {
    // 验证输入参数
    if (baseSize <= 0) {
      throw ArgumentError('基础字体大小必须大于0');
    }

    // 应用边界检查
    final clampedScale = scale.clamp(minScale, maxScale);

    // 计算缩放后的大小
    double scaledSize = baseSize * clampedScale;

    // 如果提供了上下文，应用系统文本缩放
    if (context != null) {
      // 用 MediaQuery.textScalerOf 而非 MediaQuery.of(context).textScaler：
      // 后者会让调用方订阅整个 MediaQuery（键盘弹出/旋转/亮度变化都会触发
      // 重建），前者只依赖 textScaler 这一个字段，避免聊天消息列表等高频
      // 重建场景下不必要的 rebuild。
      final textScaler = MediaQuery.textScalerOf(context);
      scaledSize = textScaler.scale(scaledSize);

      // 再次应用边界检查，防止系统缩放导致过大或过小
      scaledSize = scaledSize.clamp(baseSize * minScale, baseSize * maxScale);
    }

    return scaledSize;
  }

  /// 根据 FontSizeOption 计算缩放后的字体大小
  static double calculateSizeFromOption(
    double baseSize,
    FontSizeOption option, {
    BuildContext? context,
  }) {
    return calculateScaledSize(baseSize, option.scale, context: context);
  }

  /// 根据 FontSizeType 和 FontSizeOption 计算最终字体大小
  static double calculateFinalSize(
    FontSizeType type,
    FontSizeOption option, {
    BuildContext? context,
  }) {
    return calculateScaledSize(type.size, option.scale, context: context);
  }

  /// 验证字体大小是否在安全范围内
  ///
  /// [fontSize] 要验证的字体大小
  /// 返回是否符合 WCAG 可访问性标准（最小10px，推荐12px）
  static bool isAccessibleSize(double fontSize) {
    // 放宽标准到10px，因为某些UI元素可能需要更小的字体
    return fontSize >= 10.0;
  }

  /// 验证缩放比例是否在允许范围内
  static bool isValidScale(double scale) {
    return scale >= minScale && scale <= maxScale;
  }

  /// 获取安全的缩放比例（应用边界检查）
  static double getSafeScale(double scale) {
    return scale.clamp(minScale, maxScale);
  }

  /// 计算两个字体大小之间的缩放比例
  static double calculateScaleRatio(double originalSize, double targetSize) {
    if (originalSize <= 0) {
      throw ArgumentError('原始字体大小必须大于0');
    }
    return targetSize / originalSize;
  }

  /// 获取推荐的字体大小选项（基于当前系统设置）
  static FontSizeOption getRecommendedOption(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final systemScale = textScaler.scale(1.0);

    // 根据系统缩放推荐合适的选项
    if (systemScale <= 0.9) {
      return FontSizeOption.small;
    } else if (systemScale <= 1.1) {
      return FontSizeOption.normal;
    } else if (systemScale <= 1.2) {
      return FontSizeOption.medium;
    } else if (systemScale <= 1.3) {
      return FontSizeOption.large;
    } else if (systemScale <= 1.4) {
      return FontSizeOption.extraLarge;
    } else {
      return FontSizeOption.huge;
    }
  }

  /// 生成字体大小预览信息
  static Map<String, dynamic> generatePreviewInfo(
    FontSizeType type,
    FontSizeOption option, {
    BuildContext? context,
  }) {
    final baseSize = type.size;
    final scaledSize = calculateFinalSize(type, option, context: context);
    final isAccessible = isAccessibleSize(scaledSize);

    return {
      'baseSize': baseSize,
      'scaledSize': scaledSize,
      'scale': option.scale,
      'isAccessible': isAccessible,
      'typeName': type.displayName,
      'optionName': option.displayName,
    };
  }
}

/// 文本样式预设
class AppTextStyles {
  AppTextStyles._();

  /// 获取标题样式
  static TextStyle titleStyle(
    BuildContext context, {
    FontSizeType size = FontSizeType.title,
    FontWeightType weight = FontWeightType.bold,
    Color? color,
  }) {
    return ThemeManager.instance.getTextStyle(
      size,
      fontWeight: weight.weight,
      color: color ?? Theme.of(context).textTheme.titleLarge?.color,
      context: context,
    );
  }

  /// 获取正文样式
  static TextStyle bodyStyle(
    BuildContext context, {
    FontSizeType size = FontSizeType.normal,
    FontWeightType weight = FontWeightType.normal,
    Color? color,
  }) {
    return ThemeManager.instance.getTextStyle(
      size,
      fontWeight: weight.weight,
      color: color ?? Theme.of(context).textTheme.bodyMedium?.color,
      context: context,
    );
  }

  /// 获取标签样式
  static TextStyle labelStyle(
    BuildContext context, {
    FontSizeType size = FontSizeType.small,
    FontWeightType weight = FontWeightType.medium,
    Color? color,
  }) {
    return ThemeManager.instance.getTextStyle(
      size,
      fontWeight: weight.weight,
      color: color ?? Theme.of(context).textTheme.labelMedium?.color,
      context: context,
    );
  }

  /// 获取按钮文本样式
  static TextStyle buttonStyle(
    BuildContext context, {
    FontSizeType size = FontSizeType.medium,
    FontWeightType weight = FontWeightType.medium,
    Color? color,
  }) {
    return ThemeManager.instance.getTextStyle(
      size,
      fontWeight: weight.weight,
      color: color ?? Theme.of(context).colorScheme.onPrimary,
      context: context,
    );
  }
}

/// BuildContext 主题便捷扩展
extension BuildContextThemeAccess on BuildContext {
  /// 获取指定字号与权重的文本样式
  TextStyle textStyle(
    FontSizeType type, {
    FontWeight? fontWeight,
    Color? color,
  }) {
    return ThemeManager.instance.getTextStyle(
      type,
      fontWeight: fontWeight,
      color: color,
      context: this,
    );
  }

  /// 根据主题令牌获取颜色（如 'primary'、'outline' 等）
  Color themeColor(String token) {
    return ThemeManager.instance.getThemeColor(token);
  }

  /// 获取 ThemeManager 单例
  ThemeManager get themeManager => ThemeManager.instance;
}
