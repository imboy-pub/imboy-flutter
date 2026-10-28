/// T8 (WP5) — Workspace 体验壳断点层（纯函数，零依赖）
///
/// 镜像 `chat_shell_breakpoint.dart`：宽度自适应分发，与 ChatShell /
/// WebShell 的 900px 阈值保持一致（同一 App 内两个体验壳共用一套断点
/// 心智，不引入第三种阈值）。
library;

import 'package:imboy/theme/default/app_breakpoints.dart';

/// Workspace 壳布局形态。
enum WorkspaceShellLayout {
  /// 移动端（< 900px）：底部导航 + 单栏
  mobile,

  /// 桌面端（>= 900px）：侧边导航栏 + 内容区
  desktop,
}

/// 移动/桌面断点（px），与 ChatShell / WebShell 一致。
/// W12：复用 AppBreakpoints 真源（此前 900 重复声明，漂移即分叉）。
const double kWorkspaceShellBreakpoint = AppBreakpoints.wide;

/// 按宽度解析布局形态。
WorkspaceShellLayout resolveWorkspaceShellLayout(double width) {
  return width >= kWorkspaceShellBreakpoint
      ? WorkspaceShellLayout.desktop
      : WorkspaceShellLayout.mobile;
}
