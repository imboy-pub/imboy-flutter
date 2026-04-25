import 'package:flutter/widgets.dart';

/// 应用圆角 Design Tokens
///
/// 定义应用中所有圆角值，使用 4px 基数系统。
/// 所有圆角值均为 4 的倍数，确保视觉一致性。
///
/// 使用示例：
/// ```dart
/// // 直接使用常量
/// BorderRadius.circular(AppRadius.small)
///
/// // 使用便捷方法
/// Container(
///   decoration: BoxDecoration(
///     borderRadius: AppRadius.borderRadiusSmall,
///   ),
/// )
/// ```
///
/// 圆角层级：
/// - none (0px): 无圆角 - 直角
/// - tiny (4px): 极小圆角 - 标签、徽章
/// - small (8px): 小圆角 - 按钮、输入框
/// - cell (10px): iOS Cell 圆角 - InsetGrouped ListTile（iOS HIG 标准，破例不在 4 基数表）
/// - medium (12px): 中圆角 - 卡片、列表项
/// - regular (16px): 常规圆角 - 对话框、底部菜单
/// - large (20px): 大圆角 - 大型卡片
/// - xLarge (24px): 超大圆角 - 特殊组件
/// - circle (50%): 完全圆形 - 头像、按钮
class AppRadius {
  AppRadius._();

  // ==================== 基础圆角常量 ====================

  /// 无圆角 - 直角
  ///
  /// 使用场景：
  /// - 分割线
  /// - 某些特殊卡片
  static const double none = 0.0;

  /// 极小圆角 - 4px
  ///
  /// 使用场景：
  /// - 标签（Tag）
  /// - 徽章（Badge）
  /// - 小型提示
  static const double tiny = 4.0;

  /// 小圆角 - 8px
  ///
  /// 使用场景：
  /// - **按钮**（主要按钮、次要按钮、文本按钮）
  /// - **输入框**（TextField、TextFormField）
  /// - 小型卡片
  static const double small = 8.0;

  /// 中圆角 - 12px
  ///
  /// 使用场景：
  /// - **卡片**（Card）
  /// - **列表项**（ListTile）
  /// - 弹出菜单
  static const double medium = 12.0;

  /// iOS Cell 圆角 - 10px（iOS HIG InsetGrouped 标准）
  ///
  /// 破例不在 4px 基数表内，是 iOS InsetGrouped List 的硬性约束（DESIGN.md §5.1 line 253）。
  ///
  /// 使用场景：
  /// - iOS 风格 Cell / InsetGrouped ListTile
  /// - 设置页 / 个人资料页等系统级列表
  static const double cell = 10.0;

  /// 常规圆角 - 16px
  ///
  /// 使用场景：
  /// - **对话框**（Dialog）
  /// - **底部菜单**（BottomSheet）
  /// - **消息气泡**（聊天消息）
  /// - 标准卡片
  static const double regular = 16.0;

  /// 大圆角 - 20px
  ///
  /// 使用场景：
  /// - 大型卡片
  /// - 特殊容器
  static const double large = 20.0;

  /// 超大圆角 - 24px
  ///
  /// 使用场景：
  /// - 特殊组件
  /// - 装饰性元素
  static const double xLarge = 24.0;

  /// 完全圆形 - 50% 宽高
  ///
  /// 使用场景：
  /// - **头像**（Avatar）
  /// - **圆形按钮**（FloatingActionButton）
  /// - 圆形图标按钮
  ///
  /// 注意：此值为百分比，使用时需要特殊处理
  static const double circle = 50.0;

  // ==================== 便捷 BorderRadius 方法 ====================

  /// 无圆角 - BorderRadius.zero
  static BorderRadius get borderRadiusNone => BorderRadius.zero;

  /// 极小圆角 - 4px
  static BorderRadius get borderRadiusTiny => BorderRadius.circular(tiny);

  /// 小圆角 - 8px
  ///
  /// 用于按钮、输入框等
  static BorderRadius get borderRadiusSmall => BorderRadius.circular(small);

  /// 中圆角 - 12px
  ///
  /// 用于卡片、列表项等
  static BorderRadius get borderRadiusMedium => BorderRadius.circular(medium);

  /// iOS Cell 圆角 - 10px
  ///
  /// 用于 iOS InsetGrouped ListTile / 系统级列表
  static BorderRadius get borderRadiusCell => BorderRadius.circular(cell);

  /// 常规圆角 - 16px
  ///
  /// 用于对话框、底部菜单等
  static BorderRadius get borderRadiusRegular => BorderRadius.circular(regular);

  /// 大圆角 - 20px
  static BorderRadius get borderRadiusLarge => BorderRadius.circular(large);

  /// 超大圆角 - 24px
  static BorderRadius get borderRadiusXLarge => BorderRadius.circular(xLarge);

  // ==================== 特殊圆角 ====================

  /// 仅顶部圆角 - regular (16px)
  ///
  /// 用于底部菜单、弹出面板等
  static BorderRadius get borderRadiusTop => BorderRadius.only(
    topLeft: Radius.circular(regular),
    topRight: Radius.circular(regular),
  );

  /// 仅底部圆角 - regular (16px)
  ///
  /// 用于顶部卡片、弹出面板等
  static BorderRadius get borderRadiusBottom => BorderRadius.only(
    bottomLeft: Radius.circular(regular),
    bottomRight: Radius.circular(regular),
  );

  /// 仅左侧圆角 - regular (16px)
  static BorderRadius get borderRadiusLeft => BorderRadius.only(
    topLeft: Radius.circular(regular),
    bottomLeft: Radius.circular(regular),
  );

  /// 仅右侧圆角 - regular (16px)
  static BorderRadius get borderRadiusRight => BorderRadius.only(
    topRight: Radius.circular(regular),
    bottomRight: Radius.circular(regular),
  );

  /// 消息气泡圆角（发送方）- 仅右侧小圆角
  ///
  /// 用于聊天消息发送方，左上圆角较大
  static BorderRadius get messageBubbleSent => BorderRadius.only(
    topLeft: Radius.circular(regular),
    topRight: Radius.circular(small),
    bottomLeft: Radius.circular(regular),
    bottomRight: Radius.circular(none),
  );

  /// 消息气泡圆角（接收方）- 仅左侧小圆角
  ///
  /// 用于聊天消息接收方，右上圆角较小
  static BorderRadius get messageBubbleReceived => BorderRadius.only(
    topLeft: Radius.circular(small),
    topRight: Radius.circular(regular),
    bottomLeft: Radius.circular(none),
    bottomRight: Radius.circular(regular),
  );

  // ==================== 组件特定圆角 ====================

  /// 按钮圆角 - small (8px)
  ///
  /// 用于所有类型按钮
  static BorderRadius get button => borderRadiusSmall;

  /// 输入框圆角 - small (8px)
  ///
  /// 用于 TextField、TextFormField、SearchField
  static BorderRadius get input => borderRadiusSmall;

  /// 卡片圆角 - medium (12px)
  ///
  /// 用于 Card 组件
  static BorderRadius get card => borderRadiusMedium;

  /// 对话框圆角 - regular (16px)
  ///
  /// 用于 Dialog、AlertDialog
  static BorderRadius get dialog => borderRadiusRegular;

  /// 底部菜单圆角 - 仅顶部 regular (16px)
  ///
  /// 用于 BottomSheet、ModalBottomSheet
  static BorderRadius get bottomSheet => borderRadiusTop;

  /// 列表项圆角 - medium (12px)
  ///
  /// 用于 ListTile、ListItem
  static BorderRadius get listItem => borderRadiusMedium;

  /// 标签圆角 - tiny (4px)
  ///
  /// 用于 Chip、Tag、Badge
  static BorderRadius get tag => borderRadiusTiny;

  /// 头像圆角 - 完全圆形
  ///
  /// 用于 Avatar 组件
  ///
  /// 注意：返回 null，需要在使用时通过 BoxShape.circle 实现
  /// 或使用 borderRadius: AppRadius.circle（50%）
  static BorderRadius? get avatar => null; // 使用 BoxShape.circle

  // ==================== 辅助方法 ====================

  /// 创建自定义圆角
  ///
  /// [value] 圆角值（px）
  /// 返回一个 BorderRadius，四个角均为指定值
  static BorderRadius custom(double value) {
    return BorderRadius.circular(value);
  }

  /// 创建不对称圆角
  ///
  /// [topLeft] 左上角圆角
  /// [topRight] 右上角圆角
  /// [bottomLeft] 左下角圆角
  /// [bottomRight] 右下角圆角
  static BorderRadius customOnly({
    double topLeft = 0.0,
    double topRight = 0.0,
    double bottomLeft = 0.0,
    double bottomRight = 0.0,
  }) {
    return BorderRadius.only(
      topLeft: Radius.circular(topLeft),
      topRight: Radius.circular(topRight),
      bottomLeft: Radius.circular(bottomLeft),
      bottomRight: Radius.circular(bottomRight),
    );
  }

  /// 创建对称圆角
  ///
  /// [horizontal] 水平方向圆角
  /// [vertical] 垂直方向圆角
  static BorderRadius customSymmetric({
    double horizontal = 0.0,
    double vertical = 0.0,
  }) {
    return BorderRadius.vertical(
      top: Radius.circular(vertical),
      bottom: Radius.circular(vertical),
    ).copyWith(
      topLeft: Radius.circular(horizontal),
      topRight: Radius.circular(horizontal),
      bottomLeft: Radius.circular(horizontal),
      bottomRight: Radius.circular(horizontal),
    );
  }
}
