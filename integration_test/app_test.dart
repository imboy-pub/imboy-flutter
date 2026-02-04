// Flutter 集成测试 - 基础功能测试
//
// 使用方法：
// flutter test integration_test/app_test.dart --dart-define=APP_ENV=local_office

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:imboy/main.dart' as app;
import 'test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('IM Boy 基础功能测试', () {
    testWidgets('应用启动测试', (WidgetTester tester) async {
      // 构建应用
      app.main();
      await tester.pumpAndSettle();

      // 验证应用启动
      expect(find.byType(MaterialApp), findsOneWidget);

      print('✅ 应用启动成功');
    });

    testWidgets('查找登录按钮', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 等待启动页加载完成
      await tester.pump(const Duration(seconds: 3));

      // 尝试查找登录按钮
      final loginButton = find.text('登录');

      if (tester.any(loginButton)) {
        print('✅ 找到登录按钮');
        expect(loginButton, findsOneWidget);
      } else {
        print('⚠️ 未找到登录按钮，可能已自动登录');
      }
    });

    testWidgets('截图测试', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));

      // 截图保存
      await TestHelper.screenshot(tester, 'app_launch');
      print('✅ 截图已保存: app_launch.png');
    });
  });
}
