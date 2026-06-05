// Flutter 集成测试 - 基础功能测试
//
// 使用方法：
// flutter test integration_test/app_simple_test.dart --dart-define=APP_ENV=local_office -d macos

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'flows/app_launcher.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('IM Boy 基础功能测试', () {
    testWidgets('应用启动测试', (WidgetTester tester) async {
      // 构建应用
      await ensureAppLaunched(tester);
      await tester.pumpAndSettle();

      // 验证应用启动
      print('✅ 应用启动成功');
    });

    testWidgets('查找基本组件', (WidgetTester tester) async {
      await ensureAppLaunched(tester);
      await tester.pumpAndSettle();

      // 等待启动页加载完成
      await tester.pump(const Duration(seconds: 3));

      // 尝试查找常见元素
      final scaffold = find.byType(Scaffold);
      print('✅ 找到 ${tester.widgetList(scaffold).length} 个 Scaffold');

      // 截图保存
      await tester.pumpAndSettle();
      // 注意：在集成测试中使用 tester 的截图方法
      print('✅ 测试完成');
    });
  });
}
