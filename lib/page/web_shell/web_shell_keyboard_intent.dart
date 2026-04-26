/// Phase 1.1.l — Web Shell 桌面快捷键 → action 映射（纯函数）
///
/// 把按键组合解析为高层语义动作（[WebShellShortcut] sealed 变体），让 UI 层
/// 用 switch expression 消费。这是 Phase 4「桌面增强」中键盘快捷键能力的
/// 决策内核，提前到 Phase 1 落地以备 1.1.h.1 整合切片直接挂载。
///
/// 设计原则：
/// - **纯函数**：仅依赖 `dart:ui` 的 [LogicalKeyboardKey] 集合常量，可独立单测
/// - **平台分歧显式**：通过 [isMacOS] 入参选择 Cmd vs Ctrl 修饰键，不读 Platform
/// - **sealed 变体**：未来新增快捷键时编译器强制所有消费侧穷尽 switch
/// - **保守规则**：未匹配返回 null，由调用方决定是否 swallow（不抛异常）
library;

import 'package:flutter/services.dart' show LogicalKeyboardKey;

/// Web Shell 桌面快捷键的高层语义动作（密封变体）
sealed class WebShellShortcut {
  const WebShellShortcut();
}

/// `Cmd/Ctrl + K`：打开全局搜索（参照 VSCode / Slack / Linear 惯例）
final class OpenGlobalSearchShortcut extends WebShellShortcut {
  const OpenGlobalSearchShortcut();
}

/// `Cmd/Ctrl + N`：新建会话/对话
final class NewChatShortcut extends WebShellShortcut {
  const NewChatShortcut();
}

/// `Esc`：关闭右栏面板（回欢迎屏 / 取消选中）
final class CloseRightPanelShortcut extends WebShellShortcut {
  const CloseRightPanelShortcut();
}

/// `Cmd/Ctrl + ,`：打开设置（参照 macOS / VSCode 惯例）
final class OpenSettingsShortcut extends WebShellShortcut {
  const OpenSettingsShortcut();
}

/// 将当前按下的按键集合解析为快捷键意图
///
/// - **isMacOS=true** → 修饰键用 `meta`（Cmd）
/// - **isMacOS=false** → 修饰键用 `control`（Ctrl）
///
/// 匹配规则：
/// - `mod + K` → [OpenGlobalSearchShortcut]
/// - `mod + N` → [NewChatShortcut]
/// - `mod + ,` → [OpenSettingsShortcut]
/// - `Esc` 单按（无其他修饰）→ [CloseRightPanelShortcut]
/// - 其他组合 → null（调用方决定是否 swallow）
///
/// 边界保护：传入 [Shift] / [Alt] 等额外修饰键时按"严格匹配"原则不响应，
/// 避免与系统/浏览器快捷键冲突（如 Cmd+Shift+K = devtools console）。
WebShellShortcut? resolveShellShortcut({
  required Set<LogicalKeyboardKey> pressed,
  required bool isMacOS,
}) {
  if (pressed.isEmpty) return null;

  // Esc 单按：仅当没有任何修饰键
  if (pressed.length == 1 && pressed.contains(LogicalKeyboardKey.escape)) {
    return const CloseRightPanelShortcut();
  }

  // 严格匹配：必须是恰好 modifier + 一个字母键，不允许多余 Shift/Alt
  final modifier = isMacOS
      ? LogicalKeyboardKey.meta
      : LogicalKeyboardKey.control;

  if (pressed.length != 2 || !pressed.contains(modifier)) {
    return null;
  }

  // mod + K
  if (pressed.contains(LogicalKeyboardKey.keyK)) {
    return const OpenGlobalSearchShortcut();
  }
  // mod + N
  if (pressed.contains(LogicalKeyboardKey.keyN)) {
    return const NewChatShortcut();
  }
  // mod + ,
  if (pressed.contains(LogicalKeyboardKey.comma)) {
    return const OpenSettingsShortcut();
  }

  return null;
}
