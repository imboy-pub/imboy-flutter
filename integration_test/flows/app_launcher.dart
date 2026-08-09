// integration_test/flows/app_launcher.dart
//
// 统一 App 启动管理，确保 app.main() 在整个测试进程内只执行一次。
// 避免重复调用导致的全局单例（WebSocket、DB、ProviderContainer）状态污染。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/main.dart' as app;

import 'test_utils.dart';

bool _launched = false;

/// 启动 App 并等待首帧稳定。
///
/// - 首次调用：执行 `app.main()` + settle
/// - 后续调用：仅 settle（App 已在进程中运行）
///
/// 用法（替代裸 `app.main()`）：
/// ```dart
/// testWidgets('某个测试', (tester) async {
///   await ensureAppLaunched(tester);
///   if (!await checkPreconditions(tester)) return;
///   // ... 断言
/// });
/// ```
Future<void> ensureAppLaunched(
  WidgetTester tester, {
  int maxSeconds = 5,
}) async {
  // integration_test 的每个 testWidgets 可能拥有独立的 tester 树；
  // 仅用进程级标志复用 app.main() 会让后续用例看不到已挂载的 MaterialApp。
  // 只有当前 tester 确实还有 App 树时才复用，否则重新挂载入口。
  final hasAppTree = tester.any(find.byType(MaterialApp));
  if (!_launched || !hasAppTree) {
    final firstLaunch = !_launched;
    app.main();
    _launched = true;
    flowLog(firstLaunch ? 'App 首次启动' : 'App 入口重新挂载');
  }
  await settle(tester, maxSeconds: maxSeconds);
}
