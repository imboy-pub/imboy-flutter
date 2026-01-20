import 'package:flutter/widgets.dart';

/// 应用阴影 Design Tokens
///
/// 定义应用中所有阴影效果，符合 Material Design 3 规范。
/// 阴影用于表达元素的高度（elevation）和层级关系。
///
/// 使用示例：
/// ```dart
/// // 直接使用常量
/// Container(
///   decoration: BoxDecoration(
///     boxShadow: [AppShadows.small],
///   ),
/// )
///
/// // 使用便捷方法
/// Container(
///   decoration: BoxDecoration(
///     boxShadow: AppShadows.elevation(2),
///   ),
/// )
/// ```
///
/// 阴影层级：
/// - none: 无阴影
/// - tiny (1): 极小阴影 - 按钮、标签
/// - small (2): 小阴影 - 卡片、列表项
/// - medium (4): 中阴影 - 弹出菜单、对话框
/// - large (8): 大阴影 - 底部菜单、抽屉
/// - xLarge (16): 超大阴影 - 模态对话框
class AppShadows {
  AppShadows._();

  // ==================== 基础阴影定义 ====================

  /// 无阴影
  ///
  /// 使用场景：
  /// - 扁平元素
  /// - 与背景融合的卡片
  static const List<BoxShadow> none = [];

  /// 极小阴影 - elevation 1
  ///
  /// 使用场景：
  /// - 按钮（RaisedButton）
  /// - 标签（Chip）
  /// - 小型交互元素
  static const List<BoxShadow> tiny = [
    BoxShadow(
      color: Color(0x0F000000), // rgba(0, 0, 0, 0.06)
      offset: Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ];

  /// 小阴影 - elevation 2
  ///
  /// 使用场景：
  /// - **卡片**（Card）
  /// - **列表项**（ListTile）
  /// - 输入框（TextField）
  static const List<BoxShadow> small = [
    BoxShadow(
      color: Color(0x14000000), // rgba(0, 0, 0, 0.08)
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  /// 中阴影 - elevation 4
  ///
  /// 使用场景：
  /// - **弹出菜单**（PopupMenu）
  /// - **下拉菜单**（Dropdown）
  /// - 小型对话框
  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x1F000000), // rgba(0, 0, 0, 0.12)
      offset: Offset(0, 4),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];

  /// 大阴影 - elevation 8
  ///
  /// 使用场景：
  /// - **底部菜单**（BottomSheet）
  /// - **侧边抽屉**（Drawer）
  /// - 中型对话框
  static const List<BoxShadow> large = [
    BoxShadow(
      color: Color(0x26000000), // rgba(0, 0, 0, 0.15)
      offset: Offset(0, 8),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];

  /// 超大阴影 - elevation 16
  ///
  /// 使用场景：
  /// - **模态对话框**（Dialog）
  /// - **全屏菜单**
  /// - 重要提示卡片
  static const List<BoxShadow> xLarge = [
    BoxShadow(
      color: Color(0x33000000), // rgba(0, 0, 0, 0.20)
      offset: Offset(0, 12),
      blurRadius: 24,
      spreadRadius: 0,
    ),
  ];

  // ==================== Material Design Elevation 映射 ====================

  /// 根据 elevation 获取对应的阴影
  ///
  /// [elevation] Material Design elevation 值 (0-16)
  /// 返回对应的阴影列表
  static List<BoxShadow> elevation(int elevation) {
    switch (elevation) {
      case 0:
        return none;
      case 1:
        return tiny;
      case 2:
        return small;
      case 3:
        return _e3;
      case 4:
        return medium;
      case 5:
        return _e5;
      case 6:
        return _e6;
      case 7:
        return _e7;
      case 8:
        return large;
      case 9:
        return _e9;
      case 10:
        return _e10;
      case 11:
        return _e11;
      case 12:
        return _e12;
      case 13:
        return _e13;
      case 14:
        return _e14;
      case 15:
        return _e15;
      case 16:
        return xLarge;
      default:
        return small;
    }
  }

  // ==================== 组件特定阴影 ====================

  /// 卡片阴影 - small (elevation 2)
  ///
  /// 用于 Card 组件
  static const List<BoxShadow> card = small;

  /// 按钮阴影 - tiny (elevation 1)
  ///
  /// 用于 ElevatedButton
  static const List<BoxShadow> button = tiny;

  /// 悬浮按钮阴影 - medium (elevation 4)
  ///
  /// 用于 FloatingActionButton
  static const List<BoxShadow> fab = medium;

  /// 对话框阴影 - large (elevation 8)
  ///
  /// 用于 Dialog、AlertDialog
  static const List<BoxShadow> dialog = large;

  /// 底部菜单阴影 - large (elevation 8)
  ///
  /// 用于 BottomSheet、ModalBottomSheet
  static const List<BoxShadow> bottomSheet = large;

  /// 侧边抽屉阴影 - xLarge (elevation 16)
  ///
  /// 用于 Drawer
  static const List<BoxShadow> drawer = xLarge;

  /// 输入框阴影 - tiny (elevation 1)
  ///
  /// 用于 TextField、TextFormField
  static const List<BoxShadow> input = tiny;

  /// 聊天消息阴影 - tiny (elevation 1)
  ///
  /// 用于消息气泡
  static const List<BoxShadow> messageBubble = tiny;

  /// 工具提示阴影 - small (elevation 2)
  ///
  /// 用于 Tooltip
  static const List<BoxShadow> tooltip = small;

  // ==================== 暗色模式阴影 ====================

  /// 暗色模式下的阴影调整
  ///
  /// 暗色模式下阴影需要调整透明度和颜色
  /// 通常使用更淡的阴影
  static List<BoxShadow> darkMode(List<BoxShadow> lightShadows) {
    return lightShadows.map((shadow) {
      return BoxShadow(
        color: shadow.color.withValues(alpha: 0.5), // 降低透明度
        offset: shadow.offset,
        blurRadius: shadow.blurRadius,
        spreadRadius: shadow.spreadRadius,
      );
    }).toList();
  }

  // ==================== 辅助方法 ====================

  /// 创建自定义阴影
  ///
  /// [color] 阴影颜色
  /// [offset] 偏移量
  /// [blurRadius] 模糊半径
  /// [spreadRadius] 扩散半径
  static List<BoxShadow> custom({
    required Color color,
    required Offset offset,
    required double blurRadius,
    double spreadRadius = 0.0,
  }) {
    return [
      BoxShadow(
        color: color,
        offset: offset,
        blurRadius: blurRadius,
        spreadRadius: spreadRadius,
      ),
    ];
  }

  /// 创建多层阴影
  ///
  /// 用于创建更复杂的深度效果
  static List<BoxShadow> multi(List<BoxShadow> shadows) {
    return shadows;
  }

  // ==================== 私有 elevation 定义 ====================

  static const List<BoxShadow> _e3 = [
    BoxShadow(
      color: Color(0x1A000000), // rgba(0, 0, 0, 0.10)
      offset: Offset(0, 3),
      blurRadius: 6,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> _e5 = [
    BoxShadow(
      color: Color(0x1F000000), // rgba(0, 0, 0, 0.12)
      offset: Offset(0, 5),
      blurRadius: 10,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> _e6 = [
    BoxShadow(
      color: Color(0x24000000), // rgba(0, 0, 0, 0.14)
      offset: Offset(0, 6),
      blurRadius: 12,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> _e7 = [
    BoxShadow(
      color: Color(0x26000000), // rgba(0, 0, 0, 0.15)
      offset: Offset(0, 7),
      blurRadius: 14,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> _e9 = [
    BoxShadow(
      color: Color(0x2B000000), // rgba(0, 0, 0, 0.17)
      offset: Offset(0, 9),
      blurRadius: 18,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> _e10 = [
    BoxShadow(
      color: Color(0x2D000000), // rgba(0, 0, 0, 0.18)
      offset: Offset(0, 10),
      blurRadius: 20,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> _e11 = [
    BoxShadow(
      color: Color(0x2F000000), // rgba(0, 0, 0, 0.19)
      offset: Offset(0, 11),
      blurRadius: 22,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> _e12 = [
    BoxShadow(
      color: Color(0x33000000), // rgba(0, 0, 0, 0.20)
      offset: Offset(0, 12),
      blurRadius: 24,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> _e13 = [
    BoxShadow(
      color: Color(0x34000000), // rgba(0, 0, 0, 0.21)
      offset: Offset(0, 13),
      blurRadius: 26,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> _e14 = [
    BoxShadow(
      color: Color(0x36000000), // rgba(0, 0, 0, 0.22)
      offset: Offset(0, 14),
      blurRadius: 28,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> _e15 = [
    BoxShadow(
      color: Color(0x37000000), // rgba(0, 0, 0, 0.22)
      offset: Offset(0, 15),
      blurRadius: 30,
      spreadRadius: 0,
    ),
  ];
}
