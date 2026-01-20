import 'package:flutter/widgets.dart';

/// 应用间距 Design Tokens
///
/// 定义应用中所有间距值，使用 4px 基数系统。
/// 所有间距值均为 4 的倍数，确保视觉一致性。
///
/// 使用示例：
/// ```dart
/// // 直接使用常量
/// Padding(padding: EdgeInsets.all(AppSpacing.small))
///
/// // 使用便捷方法
/// Padding(padding: AppSpacing.pageHorizontal)
/// ```
///
/// 间距层级：
/// - none (0px): 无间距
/// - tiny (4px): 极小间距 - 徽章内边距、图标内边距
/// - small (8px): 小间距 - 卡片间距、列表项间距
/// - medium (12px): 中间距 - 组件内部间距
/// - regular (16px): 常规间距 - 卡片内边距、表单间距
/// - large (20px): 大间距 - 页面水平边距
/// - xLarge (24px): 超大间距 - 组间距、区块间距
/// - xxLarge (32px): 特大间距 - 章节间距
/// - xxxLarge (48px): 极大间距 - 页面级间距
class AppSpacing {
  AppSpacing._();

  // ==================== 基础间距常量 ====================

  /// 无间距 - 紧贴元素
  static const double none = 0.0;

  /// 极小间距 - 4px
  ///
  /// 使用场景：
  /// - 图标内边距
  /// - 徽章内边距
  /// - 标签内边距
  static const double tiny = 4.0;

  /// 小间距 - 8px
  ///
  /// 使用场景：
  /// - 卡片外边距（卡片之间的间距）
  /// - 列表项间距
  /// - 小型组件内部元素间距
  static const double small = 8.0;

  /// 中间距 - 12px
  ///
  /// 使用场景：
  /// - 组件内部元素间距
  /// - 表单元素间距
  /// - 图标和文字间距
  static const double medium = 12.0;

  /// 常规间距 - 16px
  ///
  /// 使用场景：
  /// - 卡片内边距（最常用）
  /// - 表单内边距
  /// - 按钮内边距
  /// - 标准组件内部元素间距
  static const double regular = 16.0;

  /// 大间距 - 20px
  ///
  /// 使用场景：
  /// - **页面水平边距**（主要内容区的左右边距）
  /// - 页面垂直内边距
  static const double large = 20.0;

  /// 超大间距 - 24px
  ///
  /// 使用场景：
  /// - 组间距（卡片组之间的间距）
  /// - 区块间距
  /// - 按钮内边距（大按钮）
  static const double xLarge = 24.0;

  /// 特大间距 - 32px
  ///
  /// 使用场景：
  /// - 章节间距
  /// - 大区块之间的间距
  static const double xxLarge = 32.0;

  /// 极大间距 - 48px
  ///
  /// 使用场景：
  /// - 页面级间距
  /// - 页面顶部和底部的留白
  static const double xxxLarge = 48.0;

  // ==================== 便捷 EdgeInsets 方法 ====================

  /// 全部内边距 - tiny (4px)
  static EdgeInsets get allTiny => EdgeInsets.all(tiny);

  /// 全部内边距 - small (8px)
  static EdgeInsets get allSmall => EdgeInsets.all(small);

  /// 全部内边距 - medium (12px)
  static EdgeInsets get allMedium => EdgeInsets.all(medium);

  /// 全部内边距 - regular (16px)
  static EdgeInsets get allRegular => EdgeInsets.all(regular);

  /// 全部内边边距 - large (20px)
  static EdgeInsets get allLarge => EdgeInsets.all(large);

  /// 全部内边距 - xLarge (24px)
  static EdgeInsets get allXLarge => EdgeInsets.all(xLarge);

  /// 全部内边距 - xxLarge (32px)
  static EdgeInsets get allXXLarge => EdgeInsets.all(xxLarge);

  /// 全部内边距 - xxxLarge (48px)
  static EdgeInsets get allXXXLarge => EdgeInsets.all(xxxLarge);

  /// 对称内边距 - small (8px)
  static EdgeInsets get symmetricSmall =>
      EdgeInsets.symmetric(horizontal: small, vertical: small);

  /// 对称内边距 - medium (12px)
  static EdgeInsets get symmetricMedium =>
      EdgeInsets.symmetric(horizontal: medium, vertical: medium);

  /// 对称内边距 - regular (16px)
  static EdgeInsets get symmetricRegular =>
      EdgeInsets.symmetric(horizontal: regular, vertical: regular);

  /// 对称内边距 - large (20px)
  static EdgeInsets get symmetricLarge =>
      EdgeInsets.symmetric(horizontal: large, vertical: large);

  /// 对称内边距 - xLarge (24px)
  static EdgeInsets get symmetricXLarge =>
      EdgeInsets.symmetric(horizontal: xLarge, vertical: xLarge);

  // ==================== 常用场景间距 ====================

  /// 页面水平内边距 - large (20px)
  ///
  /// 用于页面主要内容区的左右边距
  static EdgeInsets get pageHorizontal =>
      EdgeInsets.symmetric(horizontal: large);

  /// 页面垂直内边距 - regular (16px)
  static EdgeInsets get pageVertical => EdgeInsets.symmetric(vertical: regular);

  /// 卡片外边距 - small (8px)
  ///
  /// 用于卡片之间的间距
  static EdgeInsets get cardMargin => EdgeInsets.all(small);

  /// 卡片内边距 - regular (16px)
  ///
  /// 用于卡片内部元素的内边距
  static EdgeInsets get cardPadding => EdgeInsets.all(regular);

  /// 列表项内边距 - regular horizontal + medium vertical
  ///
  /// 用于 ListTile 类组件的内边距
  static EdgeInsets get listItemPadding =>
      EdgeInsets.symmetric(horizontal: regular, vertical: medium);

  /// 按钮内边距（中号按钮）- xLarge horizontal + medium vertical
  ///
  /// 用于 ElevatedButton、OutlinedButton 的内边距
  static EdgeInsets get buttonPadding =>
      EdgeInsets.symmetric(horizontal: xLarge, vertical: medium);

  /// 按钮内边距（小号按钮）- regular horizontal + small vertical
  static EdgeInsets get buttonSmallPadding =>
      EdgeInsets.symmetric(horizontal: regular, vertical: small);

  /// 输入框内边距 - regular horizontal + small vertical
  ///
  /// 用于 TextField、TextFormField 的内边距
  static EdgeInsets get inputPadding =>
      EdgeInsets.symmetric(horizontal: regular, vertical: small);

  /// 芯片内边距 - medium horizontal + small vertical
  ///
  /// 用于 Chip、InputChip 的内边距
  static EdgeInsets get chipPadding =>
      EdgeInsets.symmetric(horizontal: medium, vertical: small);

  // ==================== 外边距方法 ====================

  /// 卡片外边距 - small (8px)
  static EdgeInsets get cardMarginSmall => EdgeInsets.all(small);

  /// 卡片外边距 - regular (16px)
  static EdgeInsets get cardMarginRegular => EdgeInsets.all(regular);

  /// 列表项外边距 - 对称
  static EdgeInsets get listItemMargin =>
      EdgeInsets.symmetric(horizontal: large, vertical: small);

  // ==================== 垂直间距方法 ====================

  /// 极小垂直间距 - tiny (4px)
  static SizedBox get verticalTiny => SizedBox(height: tiny);

  /// 小垂直间距 - small (8px)
  static SizedBox get verticalSmall => SizedBox(height: small);

  /// 中垂直间距 - medium (12px)
  static SizedBox get verticalMedium => SizedBox(height: medium);

  /// 常规垂直间距 - regular (16px)
  static SizedBox get verticalRegular => SizedBox(height: regular);

  /// 大垂直间距 - large (20px)
  static SizedBox get verticalLarge => SizedBox(height: large);

  /// 超大垂直间距 - xLarge (24px)
  static SizedBox get verticalXLarge => SizedBox(height: xLarge);

  /// 特大垂直间距 - xxLarge (32px)
  static SizedBox get verticalXXLarge => SizedBox(height: xxLarge);

  /// 极大垂直间距 - xxxLarge (48px)
  static SizedBox get verticalXXXLarge => SizedBox(height: xxxLarge);

  // ==================== 水平间距方法 ====================

  /// 极小水平间距 - tiny (4px)
  static SizedBox get horizontalTiny => SizedBox(width: tiny);

  /// 小水平间距 - small (8px)
  static SizedBox get horizontalSmall => SizedBox(width: small);

  /// 中水平间距 - medium (12px)
  static SizedBox get horizontalMedium => SizedBox(width: medium);

  /// 常规水平间距 - regular (16px)
  static SizedBox get horizontalRegular => SizedBox(width: regular);

  /// 大水平间距 - large (20px)
  static SizedBox get horizontalLarge => SizedBox(width: large);

  /// 超大水平间距 - xLarge (24px)
  static SizedBox get horizontalXLarge => SizedBox(width: xLarge);

  /// 特大水平间距 - xxLarge (32px)
  static SizedBox get horizontalXXLarge => SizedBox(width: xxLarge);

  /// 极大水平间距 - xxxLarge (48px)
  static SizedBox get horizontalXXXLarge => SizedBox(width: xxxLarge);

  // ==================== 组间距方法 ====================

  /// 卡片组间距 - small (8px)
  static SizedBox get cardGroupGap => verticalSmall;

  /// 区块组间距 - large (20px)
  static SizedBox get sectionGroupGap => verticalLarge;

  /// 章节组间距 - xxLarge (32px)
  static SizedBox get chapterGroupGap => verticalXXLarge;

  // ==================== 辅助方法 ====================

  /// 根据上下文获取自适应间距
  ///
  /// 用于响应式布局，根据屏幕宽度调整间距
  static double adaptive(
    BuildContext context, {
    double small = 12.0,
    double medium = 20.0,
    double large = 32.0,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) {
      return small;
    } else if (width < 900) {
      return medium;
    } else {
      return large;
    }
  }

  /// 创建自定义间距
  ///
  /// [value] 间距值（px）
  /// 返回一个 SizedBox，高度和宽度都为指定值
  static Widget custom(double value) {
    return SizedBox(width: value, height: value);
  }

  /// 创建自定义垂直间距
  static Widget customVertical(double value) {
    return SizedBox(height: value);
  }

  /// 创建自定义水平间距
  static Widget customHorizontal(double value) {
    return SizedBox(width: value);
  }
}
