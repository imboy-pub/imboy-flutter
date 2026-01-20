import 'package:flutter/material.dart';

/// 应用动画曲线 Design Tokens
///
/// 定义应用中所有动画曲线（easing functions），遵循 Material Design 规范。
/// 动画曲线控制动画的速度变化，使动画更自然流畅。
///
/// 使用示例：
/// ```dart
/// // 直接使用常量
/// AnimationController(
///   duration: AppDurations.standard,
///   vsync: this,
/// )..forward();
///
/// // 用于动画组件
/// SlideTransition(
///   position: animation.drive(
///     Tween(begin: Offset(0, 0), end: Offset(1, 0))
///       .chain(CurveTween(curve: AppCurves.easeInOut)),
///   ),
/// )
///
/// // 用于 TweenAnimationBuilder
/// TweenAnimationBuilder(
///   tween: Tween<double>(begin: 0, end: 1),
///   curve: AppCurves.standard,
///   // ...
/// )
/// ```
///
/// 曲线类型：
/// - linear: 线性 - 匀速运动
/// - ease: 缓动 - 自然加速和减速
/// - easeIn: 进入缓动 - 慢速开始
/// - easeOut: 退出缓动 - 快速开始，慢速结束
/// - easeInOut: 进出缓动 - 慢速开始和结束
class AppCurves {
  AppCurves._();

  // ==================== 基础曲线定义 ====================

  /// 线性曲线 - 匀速
  ///
  /// 使用场景：
  /// - 加载动画
  /// - 进度条
  /// - 需要匀速运动的情况
  /// ⚠️ 谨慎使用：匀速运动看起来不自然
  static const Curve linear = Curves.linear;

  /// 标准缓动曲线 - easeInOutCubic
  ///
  /// 使用场景：
  /// - **大多数动画**（默认推荐）
  /// - **页面切换**
  /// - **对话框弹出**
  /// - **淡入淡出**
  ///
  /// 最常用的曲线，提供自然的加速和减速
  static const Curve standard = Curves.easeInOutCubic;

  /// 进入曲线 - easeInCubic
  ///
  /// 使用场景：
  /// - 元素进入屏幕
  /// - 从小变大
  /// - 慢速开始，快速结束
  static const Curve easeIn = Curves.easeInCubic;

  /// 退出曲线 - easeOutCubic
  ///
  /// 使用场景：
  /// - 元素离开屏幕
  /// - 从大变小
  /// - 快速开始，慢速结束
  static const Curve easeOut = Curves.easeOutCubic;

  /// 进出曲线 - easeInOutCubic
  ///
  /// 使用场景：
  /// - **元素进入和退出**
  /// - **展开/收起动画**
  /// - **状态变化**
  static const Curve easeInOut = Curves.easeInOutCubic;

  // ==================== Material Design 标准曲线 ====================

  /// Material Design 标准曲线
  static const Curve materialStandard = Curves.easeInOut;

  /// Material Design 强调曲线 - 更强调进入效果
  static const Curve materialEmphasized = Curves.easeInOutCubicEmphasized;

  /// Material Design 退出曲线 - 快速开始，慢速结束
  /// 使用 easeOutCubic 作为替代（Flutter 标准曲线）
  static const Curve materialDecelerate = Curves.easeOutCubic;

  /// Material Design 进入曲线 - 慢速开始，快速结束
  /// 使用 easeInCubic 作为替代（Flutter 标准曲线）
  static const Curve materialAccelerate = Curves.easeInCubic;

  // ==================== 快速曲线 ====================

  /// 快速曲线 - easeOutQuart
  ///
  /// 使用场景：
  /// - **按钮点击反馈**
  /// - **开关切换**
  /// - 需要快速响应的交互动画
  static const Curve fast = Curves.easeOutQuart;

  /// 快速进入曲线 - easeInQuart
  ///
  /// 使用场景：
  /// - 需要快速出现的元素
  static const Curve fastEaseIn = Curves.easeInQuart;

  /// 快速退出曲线 - easeOutQuart
  ///
  /// 使用场景：
  /// - 需要快速消失的元素
  static const Curve fastEaseOut = Curves.easeOutQuart;

  // ==================== 慢速曲线 ====================

  /// 慢速曲线 - easeInOutQuint
  ///
  /// 使用场景：
  /// - **页面转场**
  /// - **大型动画**
  /// - 需要优雅过渡的场景
  static const Curve slow = Curves.easeInOutQuint;

  /// 慢速进入曲线 - easeInQuint
  ///
  /// 使用场景：
  /// - 需要缓慢进入的元素
  static const Curve slowEaseIn = Curves.easeInQuint;

  /// 慢速退出曲线 - easeOutQuint
  ///
  /// 使用场景：
  /// - 需要缓慢退出的元素
  static const Curve slowEaseOut = Curves.easeOutQuint;

  // ==================== 特殊效果曲线 ====================

  /// 弹性曲线 - elasticOut
  ///
  /// 使用场景：
  /// - **按钮点击反馈**（弹性效果）
  /// - **开关切换**（Toggle）
  /// - 需要强调的交互反馈
  ///
  /// ⚠️ 谨慎使用：过度使用会显得不专业
  static const Curve elastic = Curves.elasticOut;

  /// 回弹曲线 - bounceOut
  ///
  /// 使用场景：
  /// - **特殊动画效果**
  /// - 引导动画
  /// - 庆祝动画
  ///
  /// ⚠️ 仅在特殊场景使用
  static const Curve bounce = Curves.bounceOut;

  /// 平滑曲线 - easeOutSine
  ///
  /// 使用场景：
  /// - **颜色过渡**
  /// - **透明度变化**
  /// - 需要非常柔和的过渡
  static const Curve smooth = Curves.easeOutSine;

  // ==================== 组件特定曲线 ====================

  /// 按钮动画曲线 - fast (easeOutQuart)
  ///
  /// 用于按钮点击效果、状态变化
  static const Curve button = fast;

  /// 输入框动画曲线 - standard (easeInOutCubic)
  ///
  /// 用于输入框焦点变化、边框动画
  static const Curve input = standard;

  /// 卡片动画曲线 - standard (easeInOutCubic)
  ///
  /// 用于卡片展开/收起、点击反馈
  static const Curve card = standard;

  /// 列表项动画曲线 - easeOut (easeOutCubic)
  ///
  /// 用于列表项插入、删除、滑动
  static const Curve listItem = easeOut;

  /// 对话框动画曲线 - standard (easeInOutCubic)
  ///
  /// 用于 Dialog、AlertDialog 弹出/关闭
  static const Curve dialog = standard;

  /// 底部菜单动画曲线 - easeOut (easeOutCubic)
  ///
  /// 用于 BottomSheet、ModalBottomSheet
  static const Curve bottomSheet = easeOut;

  /// 侧边抽屉动画曲线 - easeOut (easeOutCubic)
  ///
  /// 用于 Drawer 打开/关闭
  static const Curve drawer = easeOut;

  /// 标签页切换曲线 - standard (easeInOutCubic)
  ///
  /// 用于 TabBar、TabBarView 切换
  static const Curve tabSwitch = standard;

  /// 工具提示动画曲线 - fast (easeOutQuart)
  ///
  /// 用于 Tooltip 显示/隐藏
  static const Curve tooltip = fast;

  /// Snackbar 动画曲线 - easeOut (easeOutCubic)
  ///
  /// 用于 SnackBar 显示/隐藏
  static const Curve snackbar = easeOut;

  /// 进度条动画曲线 - linear（匀速）
  ///
  /// 用于 LinearProgressIndicator、CircularProgressIndicator
  static const Curve progress = linear;

  /// 聊天消息动画曲线 - easeOut (easeOutCubic)
  ///
  /// 用于消息插入、更新
  static const Curve messageBubble = easeOut;

  /// 头像动画曲线 - fast (easeOutQuart)
  ///
  /// 用于头像加载、切换
  static const Curve avatar = fast;

  /// 淡入淡出曲线 - smooth (easeOutSine)
  ///
  /// 用于元素显示/隐藏过渡
  static const Curve fade = smooth;

  /// 缩放动画曲线 - fast (easeOutQuart)
  ///
  /// 用于按钮点击缩放效果
  static const Curve scale = fast;

  /// 滑动动画曲线 - standard (easeInOutCubic)
  ///
  /// 用于页面滑动、手势操作
  static const Curve slide = standard;

  // ==================== 特殊场景曲线 ====================

  /// 下拉刷新曲线 - easeOut (easeOutCubic)
  ///
  /// 用于 RefreshIndicator 刷新动画
  static const Curve refresh = easeOut;

  /// 加载动画曲线 - linear（匀速循环）
  ///
  /// 用于加载指示器循环动画
  static const Curve loading = linear;

  /// 骨架屏动画曲线 - linear（匀速闪烁）
  ///
  /// 用于骨架屏闪烁效果
  static const Curve skeleton = linear;

  /// 页面进入动画曲线 - easeOut (easeOutCubic)
  ///
  /// 用于页面进入动画
  static const Curve pageEnter = easeOut;

  /// 页面退出动画曲线 - easeIn (easeInCubic)
  ///
  /// 用于页面退出动画（快速退出）
  static const Curve pageExit = easeIn;

  /// 状态变化曲线 - standard (easeInOutCubic)
  ///
  /// 用于组件状态切换
  static const Curve stateChange = standard;

  // ==================== 辅助方法 ====================

  /// 创建自定义曲线
  ///
  /// 使用 Cubic 自定义贝塞尔曲线
  /// [controlPoint1X] 第一个控制点 X 坐标 (0-1)
  /// [controlPoint1Y] 第一个控制点 Y 坐标 (0-1)
  /// [controlPoint2X] 第二个控制点 X 坐标 (0-1)
  /// [controlPoint2Y] 第二个控制点 Y 坐标 (0-1)
  static Cubic custom({
    required double controlPoint1X,
    required double controlPoint1Y,
    required double controlPoint2X,
    required double controlPoint2Y,
  }) {
    return Cubic(
      controlPoint1X,
      controlPoint1Y,
      controlPoint2X,
      controlPoint2Y,
    );
  }

  /// 创建反向曲线
  ///
  /// [curve] 原始曲线
  /// 返回时间反向的曲线（用于反向动画）
  static Curve reverse(Curve curve) {
    return FlippedCurve(curve);
  }

  /// 创建延迟曲线
  ///
  /// [curve] 原始曲线
  /// [delay] 延迟时间（0-1 之间的小数，表示总时间的比例）
  static Curve delayed(Curve curve, double delay) {
    return Interval(delay, 1.0, curve: curve);
  }

  /// 获取所有曲线配置
  ///
  /// 返回常用曲线的映射表
  static const Map<String, Curve> allCurves = {
    'linear': linear,
    'standard': standard,
    'easeIn': easeIn,
    'easeOut': easeOut,
    'easeInOut': easeInOut,
    'fast': fast,
    'slow': slow,
    'elastic': elastic,
    'bounce': bounce,
    'smooth': smooth,
  };

  /// 根据名称获取曲线
  ///
  /// [name] 曲线名称
  /// 返回对应的 Curve，如果不存在返回 standard
  static Curve getByName(String name) {
    return allCurves[name] ?? standard;
  }

  /// 根据动画类型获取推荐的曲线
  ///
  /// [type] 动画类型
  /// 返回推荐的曲线
  static Curve getRecommendedCurve(AnimationType type) {
    switch (type) {
      case AnimationType.enter:
        return easeOut;
      case AnimationType.exit:
        return easeIn;
      case AnimationType.transition:
        return standard;
      case AnimationType.feedback:
        return fast;
      case AnimationType.loading:
        return linear;
      case AnimationType.highlight:
        return smooth;
    }
  }
}

/// 动画类型枚举
enum AnimationType {
  /// 进入动画 - 元素进入屏幕
  enter,

  /// 退出动画 - 元素离开屏幕
  exit,

  /// 过渡动画 - 状态变化
  transition,

  /// 反馈动画 - 用户交互反馈
  feedback,

  /// 加载动画 - 加载中状态
  loading,

  /// 强调动画 - 引起注意
  highlight,
}
