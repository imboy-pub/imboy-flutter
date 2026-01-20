/// 应用动画时长 Design Tokens
///
/// 定义应用中所有动画时长，遵循 Material Design 动画规范。
/// 动画时长应与动画的复杂度和距离相匹配。
///
/// 使用示例：
/// ```dart
/// // 直接使用常量
/// await Future.delayed(AppDurations.fast);
///
/// // 用于动画控制器
/// AnimationController(
///   duration: AppDurations.medium,
///   vsync: this,
/// )
///
/// // 用于 AnimatedContainer
/// AnimatedContainer(
///   duration: AppDurations.standard,
///   // ...
/// )
/// ```
///
/// 时长层级：
/// - instant (0ms): 即时 - 无动画
/// - fast (150ms): 快速 - 小型交互、状态变化
/// - standard (250ms): 标准 - 常规动画、过渡
/// - medium (350ms): 中等 - 复杂动画、布局变化
/// - slow (500ms): 慢速 - 大型动画、页面切换
/// - slower (750ms): 较慢 - 特殊动画、引导动画
class AppDurations {
  AppDurations._();

  // ==================== 基础时长常量 ====================

  /// 即时 - 0ms
  ///
  /// 使用场景：
  /// - 无动画的即时变化
  /// - 状态切换（不需要视觉反馈）
  static const Duration instant = Duration(milliseconds: 0);

  /// 极快 - 100ms
  ///
  /// 使用场景：
  /// - 微小交互反馈
  /// - 按钮按下效果
  /// - 颜色快速变化
  static const Duration ultraFast = Duration(milliseconds: 100);

  /// 快速 - 150ms
  ///
  /// 使用场景：
  /// - **按钮点击反馈**
  /// - **开关切换**（Switch）
  /// - **复选框动画**（Checkbox）
  /// - 小型图标动画
  static const Duration fast = Duration(milliseconds: 150);

  /// 标准 - 250ms
  ///
  /// 使用场景：
  /// - **展开/收起动画**
  /// - **淡入淡出**
  /// - **颜色过渡**
  /// - 小型组件过渡
  static const Duration standard = Duration(milliseconds: 250);

  /// 中等 - 350ms
  ///
  /// 使用场景：
  /// - **布局变化**
  /// - **滑动动画**
  /// - **弹出菜单**（PopupMenu）
  /// - **下拉刷新**
  static const Duration medium = Duration(milliseconds: 350);

  /// 慢速 - 500ms
  ///
  /// 使用场景：
  /// - **页面切换**
  /// - **对话框弹出**
  /// - **底部菜单**
  /// - **列表项插入/删除**
  static const Duration slow = Duration(milliseconds: 500);

  /// 较慢 - 750ms
  ///
  /// 使用场景：
  /// - **页面转场**
  /// - **复杂引导动画**
  /// - **初次启动动画**
  static const Duration slower = Duration(milliseconds: 750);

  /// 极慢 - 1000ms
  ///
  /// 使用场景：
  /// - 特殊效果动画
  /// - 长距离转场
  static const Duration ultraSlow = Duration(milliseconds: 1000);

  // ==================== Material Design 时长映射 ====================

  /// Material Design 标准时长
  static const Duration materialStandard = standard;

  /// Material Design 对话框动画时长
  static const Duration dialogTransition = medium;

  /// Material Design 页面转场时长
  static const Duration pageTransition = slow;

  // ==================== 组件特定时长 ====================

  /// 按钮动画时长 - fast (150ms)
  ///
  /// 用于按钮点击效果、状态变化
  static const Duration button = fast;

  /// 输入框动画时长 - fast (150ms)
  ///
  /// 用于输入框焦点变化、边框动画
  static const Duration input = fast;

  /// 卡片动画时长 - standard (250ms)
  ///
  /// 用于卡片展开/收起、点击反馈
  static const Duration card = standard;

  /// 列表项动画时长 - medium (350ms)
  ///
  /// 用于列表项插入、删除、滑动
  static const Duration listItem = medium;

  /// 对话框动画时长 - medium (350ms)
  ///
  /// 用于 Dialog、AlertDialog 弹出/关闭
  static const Duration dialog = medium;

  /// 底部菜单动画时长 - medium (350ms)
  ///
  /// 用于 BottomSheet、ModalBottomSheet
  static const Duration bottomSheet = medium;

  /// 侧边抽屉动画时长 - slow (500ms)
  ///
  /// 用于 Drawer 打开/关闭
  static const Duration drawer = slow;

  /// 标签页切换时长 - standard (250ms)
  ///
  /// 用于 TabBar、TabBarView 切换
  static const Duration tabSwitch = standard;

  /// 工具提示动画时长 - fast (150ms)
  ///
  /// 用于 Tooltip 显示/隐藏
  static const Duration tooltip = fast;

  /// Snackbar 动画时长 - medium (350ms)
  ///
  /// 用于 SnackBar 显示/隐藏
  static const Duration snackbar = medium;

  /// 进度条动画时长 - standard (250ms)
  ///
  /// 用于 LinearProgressIndicator、CircularProgressIndicator
  static const Duration progress = standard;

  /// 聊天消息动画时长 - standard (250ms)
  ///
  /// 用于消息插入、更新
  static const Duration messageBubble = standard;

  /// 头像动画时长 - fast (150ms)
  ///
  /// 用于头像加载、切换
  static const Duration avatar = fast;

  /// 淡入淡出时长 - standard (250ms)
  ///
  /// 用于元素显示/隐藏过渡
  static const Duration fade = standard;

  /// 缩放动画时长 - fast (150ms)
  ///
  /// 用于按钮点击缩放效果
  static const Duration scale = fast;

  /// 滑动动画时长 - medium (350ms)
  ///
  /// 用于页面滑动、手势操作
  static const Duration slide = medium;

  // ==================== 特殊场景时长 ====================

  /// 下拉刷新时长 - medium (350ms)
  ///
  /// 用于 RefreshIndicator 刷新动画
  static const Duration refresh = medium;

  /// 加载动画时长 - slow (500ms)
  ///
  /// 用于加载指示器循环动画
  static const Duration loading = slow;

  /// 骨架屏动画时长 - slow (500ms)
  ///
  /// 用于骨架屏闪烁效果
  static const Duration skeleton = slow;

  /// 页面进入动画时长 - medium (350ms)
  ///
  /// 用于页面进入动画
  static const Duration pageEnter = medium;

  /// 页面退出动画时长 - standard (250ms)
  ///
  /// 用于页面退出动画（通常快于进入）
  static const Duration pageExit = standard;

  /// 状态变化时长 - fast (150ms)
  ///
  /// 用于组件状态切换
  static const Duration stateChange = fast;

  // ==================== 辅助方法 ====================

  /// 创建自定义时长
  ///
  /// [milliseconds] 毫秒数
  static Duration custom(int milliseconds) {
    return Duration(milliseconds: milliseconds);
  }

  /// 根据距离计算合适的动画时长
  ///
  /// [distance] 像素距离
  /// 返回与距离成比例的动画时长
  /// 遵循 Material Design 动画速度建议
  static Duration fromDistance(double distance) {
    // Material Design 建议：标准动画速度为每秒 300-400px
    const standardSpeed = 350.0; // 每秒像素数
    final duration = (distance / standardSpeed * 1000).round();

    // 限制在 fast (150ms) 到 slow (500ms) 之间
    return Duration(
      milliseconds: duration.clamp(fast.inMilliseconds, slow.inMilliseconds),
    );
  }

  /// 获取动画时长配置
  ///
  /// 返回常用动画时长的映射表
  static const Map<String, Duration> allDurations = {
    'instant': instant,
    'ultraFast': ultraFast,
    'fast': fast,
    'standard': standard,
    'medium': medium,
    'slow': slow,
    'slower': slower,
    'ultraSlow': ultraSlow,
  };

  /// 根据名称获取时长
  ///
  /// [name] 时长名称
  /// 返回对应的 Duration，如果不存在返回 standard
  static Duration getByName(String name) {
    return allDurations[name] ?? standard;
  }
}
