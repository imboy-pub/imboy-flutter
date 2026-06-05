// integration_test/flows/app_launcher.dart
//
// 统一 App 启动管理，确保 app.main() 在整个测试进程内只执行一次。
// 避免重复调用导致的全局单例（WebSocket、DB、ProviderContainer）状态污染。

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
///   await checkPreconditions(tester);
///   // ... 断言
/// });
/// ```
Future<void> ensureAppLaunched(
  WidgetTester tester, {
  int maxSeconds = 5,
}) async {
  if (!_launched) {
    app.main();
    _launched = true;
    flowLog('App 首次启动');
  }
  await settle(tester, maxSeconds: maxSeconds);
}
