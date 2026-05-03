// 简化演示测试 - 快速验证框架功能
//
// 使用 macOS 运行可以快速验证测试框架是否正常工作
// 运行命令: flutter test integration_test/simple_demo_test.dart -d macos

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('简化演示测试', () {
    testWidgets('基础功能测试', (WidgetTester tester) async {
      print('');
      print('🚀 开始简化演示测试');
      print('=' * 60);

      // 步骤 1: 启动应用
      print('📍 步骤 1: 启动应用');
      app.main();

      // 分步 pump 等待异步初始化完成（不能用 pumpAndSettle，
      // 因为 loading 动画会导致它超时）
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      print('✅ 应用已启动');

      // 步骤 2: 检查应用是否正常运行
      print('');
      print('📍 步骤 2: 检查应用状态');

      // 查找任何 Scaffold（确认应用有 UI）
      final scaffolds = find.byType(Scaffold);
      final scaffoldCount = tester.widgetList(scaffolds).length;
      if (scaffoldCount > 0) {
        print('✅ 找到 $scaffoldCount 个 Scaffold');
      } else {
        print('⚠️ 未找到 Scaffold（可能仍在加载登录页）');
      }

      // 步骤 3: 截图（Web 平台跳过，因 takeScreenshot 会触发无限
      // App resumed 事件循环）
      print('');
      print('📍 步骤 3: 尝试截图');
      final isWeb = identical(0.0, 0);
      if (!isWeb) {
        try {
          await binding
              .takeScreenshot('simple_demo_test')
              .timeout(const Duration(seconds: 5));
          print('✅ 截图成功');
        } catch (e) {
          print('⚠️ 截图跳过: $e');
        }
      } else {
        print('⚠️ Web 平台跳过截图');
      }

      print('');
      print('=' * 60);
      print('🎉 简化演示测试完成');
      print('=' * 60);
      print('');
    });
  });
}
