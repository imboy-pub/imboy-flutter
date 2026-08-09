// integration_test/app_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'flows/app_launcher.dart';
import 'flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App 基础启动', () {
    testWidgets('MaterialApp 和 Scaffold 可见', (tester) async {
      await ensureAppLaunched(tester, maxSeconds: 5);
      await settle(tester, maxSeconds: 5);
      // 启动早期根 widget 还没挂载，须先等到入口状态再断言（与其余测试一致）
      final entered = await waitForEntryState(tester);
      if (!entered) {
        logEntryDiagnostics(tester);
      }
      expect(
        entered,
        isTrue,
        reason: 'App 应在启动等待窗口内进入登录页或主 Shell',
      );
      expect(
        find.byType(MaterialApp),
        findsOneWidget,
        reason: 'MaterialApp 应唯一存在',
      );
      expect(find.byType(Scaffold), findsWidgets, reason: '启动后应有 Scaffold');
    });

    testWidgets('进入可操作入口（登录页或主 Shell）', (tester) async {
      await ensureAppLaunched(tester, maxSeconds: 5);
      await settle(tester, maxSeconds: 5);
      if (!await ensureBackendAvailable()) {
        markTestSkipped('后端不可达');
        return;
      }
      final entered = await waitForEntryState(tester);
      if (!entered) {
        logEntryDiagnostics(tester);
      }
      expect(
        entered,
        isTrue,
        reason: 'App 应在启动等待窗口内进入登录页或主 Shell',
      );
    });
  });
}
