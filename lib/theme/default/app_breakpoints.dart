/// 统一响应式断点 Design Tokens
///
/// 唯一断点来源。此前 web_shell（900/1200）与 contact/conversation/登录页
/// （硬编码 800）各自维护阈值，产生 800–899px 的判定灰区：`/web_shell` 下
/// 该区间被 [resolveShellLayout]（见 `web_shell_breakpoint.dart`）判为
/// mobile（回退 BottomNavigationPage），但 contact/conversation 页仍按
/// `width > 800` 派发到 split view provider，因无消费者而"点击无反应"。
/// 全部改用本文件常量后阈值统一为 900，灰区消失。
library;

/// 应用断点常量类。
class AppBreakpoints {
  AppBreakpoints._();

  /// 移动端断点 - 600px（平板 NavigationRail 起始点，见
  /// `bottom_navigation_page.dart` 的 tablet 模式判定）
  static const double mobile = 600.0;

  /// 宽屏断点 - 900px（Web Shell 双栏起始点，见
  /// `web_shell_breakpoint.dart` 的 [resolveShellLayout]）
  static const double wide = 900.0;

  /// 超宽屏断点 - 1200px（Web Shell 三栏起始点）
  static const double ultraWide = 1200.0;

  /// 是否达到宽屏（`width >= wide`）。
  ///
  /// 用于 split view / Web 登录页等"移动端单栏 vs 宽屏双栏"二选一判定，
  /// 与 [resolveShellLayout] 的 mobile/非 mobile 分界保持同一阈值，
  /// 避免灰区。
  static bool isWide(double width) => width >= wide;
}
