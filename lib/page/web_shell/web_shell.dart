/// Phase 1.1.j — Web Shell 模块统一对外入口（barrel export）
///
/// 将 `lib/page/web_shell/` 下 8 个公共文件的 API 统一聚合，调用方只需一个 import：
///
/// ```dart
/// import 'package:imboy/page/web_shell/web_shell.dart';
///
/// // 直接使用：
/// final layout = resolveShellLayout(width);
/// final state = ref.watch(webShellProvider);
/// final items = buildWebNavItems(...);
/// // ... WebNavRail / WebMiddlePanel / WebMainPanel / WebWelcomePanel
/// ```
///
/// 设计意图（为 Phase 1.1.h.1 整合做准备）：
/// - **单一 import 入口**：1.1.h.1 WebShellPage 整合切片只需 import 此 barrel
/// - **API 边界清晰**：通过 barrel 列表明确暴露的公共 API（隐式契约）
/// - **重构兼容**：未来重命名内部文件，调用方不需改动 import 路径
/// - **零运行时开销**：纯 export 语句，无任何 runtime 行为
///
/// 不导出的内部实现（按需要保持私有）：
/// - 内部 widget（如 `_WebNavRailItem` / `_Badge`）— 已通过 `_` 前缀私有化
library;

// 响应式断点决策（1.1.a）
export 'web_shell_breakpoint.dart';

// 不可变状态 + 4 个 sealed selection 变体（1.1.b）
export 'web_shell_state.dart';

// Riverpod NotifierProvider（1.1.c）
export 'web_shell_provider.dart';

// 默认欢迎屏 widget（1.1.d）
export 'web_welcome_panel.dart';

// 左侧导航条 + WebNavItem data class（1.1.e）
export 'web_nav_rail.dart';

// 中间面板（IndexedStack 模式）（1.1.f）
export 'web_middle_panel.dart';

// 右侧主内容面板（sealed switch 分发）（1.1.g）
export 'web_main_panel.dart';

// NavItems 工厂（i18n + badge 与 widget 解耦）（1.1.h.0）
export 'web_nav_items_factory.dart';
