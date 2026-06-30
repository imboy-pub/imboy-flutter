/// 动画时长 Design Tokens
///
/// 对齐 DESIGN.md §6.1 规范。所有动画 duration 从此处取值，
/// 禁止在 widget 内硬编码 Duration(milliseconds: xxx)。
///
/// 使用示例：
/// ```dart
/// AnimatedOpacity(
///   duration: AppDuration.fast,
///   opacity: visible ? 1.0 : 0.0,
///   child: child,
/// )
/// ```
class AppDuration {
  AppDuration._();

  // ========== 基础时长 ==========

  /// 即时反馈（按钮按下 opacity 闪烁）— 100ms
  static const Duration instant = Duration(milliseconds: 100);

  /// 快速过渡（Cell 展开、Tooltip 显现、Badge 出现）— 150ms
  static const Duration fast = Duration(milliseconds: 150);

  /// 标准过渡（页面切换淡入、下拉菜单、开关切换）— 200ms
  static const Duration normal = Duration(milliseconds: 200);

  /// 慢速过渡（Modal Sheet 升起/收起、侧边栏）— 300ms
  static const Duration slow = Duration(milliseconds: 300);

  /// 极慢过渡（引导动画、空状态过渡、欢迎页）— 500ms
  static const Duration xSlow = Duration(milliseconds: 500);

  // ========== 场景别名 ==========

  /// 按钮点击反馈
  static const Duration buttonPress = instant;

  /// 页面切换
  static const Duration pageTransition = normal;

  /// Modal Sheet 弹出
  static const Duration modalSlide = slow;

  /// Snackbar / Toast 显现
  static const Duration snackbar = fast;

  /// 路由 Hero 动画
  static const Duration heroAnimation = slow;

  /// 列表项展开/折叠
  static const Duration listExpand = normal;

  /// 图片/媒体加载淡入
  static const Duration imageFadeIn = normal;

  // ========== 工具方法 ==========

  /// 是否应用简化动画（尊重系统「减少动态效果」设置）
  ///
  /// 用法：
  /// ```dart
  /// final dur = AppDuration.respectReducedMotion(
  ///   context, AppDuration.normal,
  /// );
  /// ```
  static Duration respectReducedMotion(
    bool reduceMotion,
    Duration full, {
    Duration? reduced,
  }) {
    if (!reduceMotion) return full;
    return reduced ?? const Duration(milliseconds: 0);
  }
}
