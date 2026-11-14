// integration_test/flows/app_launcher.dart
//
// 统一 App 启动管理，在当前 App 树可复用时避免重复启动。
// 避免重复调用导致的全局单例（WebSocket、DB、ProviderContainer）状态污染。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/main.dart' as app;

import 'test_utils.dart';

bool _launched = false;

/// 启动 App 并等待首帧稳定。
///
/// 首次启动或 App 树卸载后调用入口；已有 App 树时仅等待稳定。
/// owned 旅程可传入现有异步启动器，启动失败不会标记为已启动。
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
  Future<void> Function(WidgetTester)? launch,
}) async {
  // integration_test 的每个 testWidgets 可能拥有独立的 tester 树；
  // 仅用进程级标志复用 app.main() 会让后续用例看不到已挂载的 MaterialApp。
  // 只有当前 tester 确实还有 App 树时才复用，否则重新挂载入口。
  final hasAppTree = tester.any(find.byType(MaterialApp));
  if (!_launched || !hasAppTree) {
    final firstLaunch = !_launched;
    _launched = false;
    if (launch == null) {
      app.main();
    } else {
      await launch(tester);
    }
    _launched = true;
    flowLog(firstLaunch ? 'App 首次启动' : 'App 入口重新挂载');
  }
  await settle(tester, maxSeconds: maxSeconds);
}
