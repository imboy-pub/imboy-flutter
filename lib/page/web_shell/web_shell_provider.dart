/// Phase 1.1.c — Web Shell Riverpod 状态管理
///
/// 持有 [WebShellState]，提供 5 个动作：
/// - [WebShellNotifier.switchTab]：切 Tab，自动清空 selectedItem（避免跨 Tab 选中状态串扰）
/// - [WebShellNotifier.selectItem]：设置选中项（不动 currentTab，由 UI 调用方负责同步）
/// - [WebShellNotifier.openChat]：原子切换消息 Tab 并选择会话
/// - [WebShellNotifier.clearSelection]：清空选中项（回欢迎屏）
/// - [WebShellNotifier.replaceState]：路由恢复或测试，整体替换 state
///
/// 设计要点：
/// - 手写 [Notifier] + [NotifierProvider]（Riverpod 3 公开 API），避免 codegen 副作用
/// - 同 tab 切换 / null clear 已在 NoOp 短路（避免触发不必要 rebuild）
/// - 守卫非法 tab（< 0 或 > 3）：静默 no-op，不抛异常（UI 层守住边界更合适）
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

import 'web_shell_state.dart';

/// Web Shell 全局状态 NotifierProvider
final webShellProvider = NotifierProvider<WebShellNotifier, WebShellState>(
  WebShellNotifier.new,
);

/// Web Shell Notifier：管理 currentTab + selectedItem 状态机
class WebShellNotifier extends Notifier<WebShellState> {
  /// 合法 Tab 索引上界（0..3 共 4 个 Tab）
  static const int maxTabIndex = 3;

  @override
  WebShellState build() {
    ref.watch(currentUserProvider.select((user) => user?.uid ?? ''));
    return const WebShellState();
  }

  /// 切换 Tab。
  ///
  /// - 非法值（< 0 或 > [maxTabIndex]）静默 no-op
  /// - 同 tab 不动 state（避免无效 rebuild）
  /// - 切 tab 时强制清空 selectedItem（跨 Tab selection 语义不同，避免串扰）
  void switchTab(int tab) {
    if (tab < 0 || tab > maxTabIndex) return;
    if (tab == state.currentTab && state.selectedItem == null) return;
    state = state.copyWith(currentTab: tab, clearSelection: true);
  }

  /// 设置选中项（不动 currentTab）。
  ///
  /// 调用方负责确保 sel 与当前 Tab 语义一致（如 ChatSelection 应在 Tab 0 设置）。
  void selectItem(WebSelection sel) {
    if (state.selectedItem == sel) return;
    state = state.copyWith(selectedItem: sel);
  }

  /// 从联系人等入口开始聊天，一次更新 Tab 和选择，避免路由桥回写中间态。
  void openChat(ChatSelection selection) {
    final next = WebShellState(currentTab: 0, selectedItem: selection);
    if (state == next) return;
    state = next;
  }

  /// 清空选中项（不动 currentTab）。已经为 null 时 no-op。
  void clearSelection() {
    if (state.selectedItem == null) return;
    state = state.copyWith(clearSelection: true);
  }

  /// 整体替换 state（用于深链恢复和测试）。
  ///
  /// 生产代码优先使用 [switchTab] / [openChat] / [selectItem] / [clearSelection]。
  void replaceState(WebShellState newState) {
    state = newState;
  }
}
