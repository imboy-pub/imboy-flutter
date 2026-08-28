/// T2 (WP1) — Chat 体验壳响应式布局断点决策（纯函数）
///
/// ChatShell 的宽度自适应只有两档（比 web_shell 的三档更粗粒度）：
/// - `<900px` → `mobile`：渲染移动端现有入口（BottomNavigationPage，底部导航）
/// - `>=900px` → `desktop`：渲染桌面端现有入口（WebShellBootstrap，三栏壳；
///   其内部在更窄宽度下也会自行回落 BottomNavigationPage，阈值同源无灰区）
///
/// 设计原则（镜像 `web_shell_breakpoint.dart`）：
/// - 显式枚举分段，断点数值来自 [AppBreakpoints]（唯一断点来源），不引入
///   连续插值，也不在本文件自行定义字面量
/// - 入参为由 BuildContext 派生的 width 值，调用方负责取值（保持纯函数无副作用）
/// - 边界值采用左闭右开分段：900.0 走 desktop
library;

import 'package:imboy/theme/default/app_breakpoints.dart';

/// Chat Shell 布局类型枚举。
///
/// 顺序按宽度递增排列，便于 UI 层做条件渲染。
enum ChatShellLayout {
  /// 移动端布局：底部导航入口（< 900px）
  mobile,

  /// 桌面端布局：三栏壳入口（>= 900px）
  desktop,
}

/// 根据可用宽度解析当前应使用的 Chat Shell 布局。
///
/// 使用左闭右开分段：
/// - `width < 900` → mobile
/// - `width >= 900` → desktop
///
/// 调用方负责传入合法宽度（>= 0）；负数会被归入 mobile 分支（安全默认）。
ChatShellLayout resolveChatShellLayout(double width) {
  return width < AppBreakpoints.wide
      ? ChatShellLayout.mobile
      : ChatShellLayout.desktop;
}
