import 'package:flutter/animation.dart';

/// 动画曲线 Design Tokens
///
/// 对齐 DESIGN.md §6.2 规范，选用 iOS 风格曲线。
/// 所有动画曲线从此处取值，禁止在 widget 内硬编码 Curves.xxx。
///
/// 使用示例：
/// ```dart
/// AnimatedContainer(
///   duration: AppDuration.normal,
///   curve: AppCurves.standard,
///   height: expanded ? 200 : 60,
/// )
/// ```
class AppCurves {
  AppCurves._();

  // ========== iOS 风格主曲线 ==========

  /// 标准曲线（大多数 UI 过渡）— 类 iOS easeInOutCubic
  static const Curve standard = Cubic(0.25, 0.1, 0.25, 1.0);

  /// 入场曲线（元素滑入、Modal 升起）— 减速
  static const Curve decelerate = Cubic(0.0, 0.0, 0.2, 1.0);

  /// 离场曲线（元素滑出、Modal 收起）— 加速
  static const Curve accelerate = Cubic(0.4, 0.0, 1.0, 1.0);

  /// 弹性曲线（iOS spring 近似，用于 Modal Sheet、列表项弹出）
  static const Curve spring = Cubic(0.32, 0.72, 0.0, 1.0);

  // ========== Flutter 内置别名（语义化封装） ==========

  /// 按钮点击反馈（即时，使用线性）
  static const Curve buttonPress = Curves.linear;

  /// 淡入淡出（opacity 动画）
  static const Curve fade = Curves.easeInOut;

  /// 列表项展开/折叠
  static const Curve listExpand = decelerate;

  /// 页面转场（push/pop）
  static const Curve pageTransition = standard;

  /// Toast / Snackbar 弹出
  static const Curve snackbar = decelerate;

  /// Hero 动画
  static const Curve hero = spring;

  // ========== 特殊场景 ==========

  /// 引导/欢迎页动画（柔和慢速）
  static const Curve onboarding = Curves.easeOutCubic;

  /// 错误抖动（水平 shake）
  static const Curve errorShake = Curves.elasticOut;

  /// 折叠卡片（手风琴）
  static const Curve accordion = decelerate;
}
