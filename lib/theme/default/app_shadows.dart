import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 阴影 Design Tokens
///
/// iOS 风格极少使用投影。本规范只保留 3 档，更高层级改用
/// 背景色分层（surfaceElevated / surfaceContainer）+ 分隔线替代。
///
/// 使用示例：
/// ```dart
/// Container(
///   decoration: BoxDecoration(
///     boxShadow: AppShadows.card,
///   ),
/// )
/// ```
class AppShadows {
  AppShadows._();

  // ========== 阴影常量 ==========

  /// elevation 0 — 无阴影（默认，iOS 风格主流）
  static const List<BoxShadow> none = [];

  /// elevation 1 — 极淡浮起（Cell、小卡片；大多数情况用背景色分层替代）
  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x0A000000), // black 4%
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  /// elevation 2 — 轻投影（FAB、Toast、Tooltip、浮动按钮）
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x14000000), // black 8%
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// elevation 3 — 弹层（Modal Sheet、Popover、DropdownMenu；Radix 自动处理）
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x1F000000), // black 12%
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  // ========== 暗色模式变体 ==========

  /// 暗色 elevation 2（避免纯黑投影在深色背景上不可见，改用白色 glow）
  static const List<BoxShadow> cardDark = [
    BoxShadow(
      color: Color(0x29000000), // black 16%（暗色背景下投影需加深）
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  // ========== 工具方法 ==========

  /// 根据亮暗模式获取卡片阴影
  static List<BoxShadow> cardForBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? cardDark : card;

  /// 钱包卡片渐变阴影（品牌蓝投影，用于带渐变的卡片）
  static List<BoxShadow> get walletCard => [
    BoxShadow(
      color: AppColors.primaryAlpha20,
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
}
