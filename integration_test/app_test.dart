// integration_test/app_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/main.dart' as app;
import 'package:integration_test/integration_test.dart';
import 'flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App 基础启动', () {
    testWidgets('MaterialApp 和 Scaffold 可见', (tester) async {
      app.main();
      await settle(tester, maxSeconds: 5);
      expect(find.byType(MaterialApp), findsOneWidget, reason: 'MaterialApp 应唯一存在');
      expect(find.byType(Scaffold), findsWidgets, reason: '启动后应有 Scaffold');
    });

    testWidgets('进入可操作入口（登录页或主 Shell）', (tester) async {
      app.main();
      await settle(tester, maxSeconds: 5);
      if (!await ensureBackendAvailable()) { markTestSkipped('后端不可达'); return; }
      expect(await waitForEntryState(tester), isTrue,
          reason: 'App 应在 20s 内进入登录页或主 Shell');
    });
  });
}
