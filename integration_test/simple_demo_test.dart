// 简化演示测试 - 快速验证框架功能
//
// 使用 Chrome 运行可以快速验证测试框架是否正常工作
// 运行命令: flutter test integration_test/simple_demo_test.dart -d chrome

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
      await tester.pumpAndSettle();
      print('✅ 应用已启动');

      // 等待应用完全加载
      await Future.delayed(const Duration(seconds: 2));
      print('✅ 应用加载完成');

      // 步骤 2: 检查应用是否正常运行
      print('');
      print('📍 步骤 2: 检查应用状态');

      // 查找任何 Scaffold（确认应用有 UI）
      final scaffolds = find.byType(Scaffold);
      expect(scaffolds, findsAtLeastNWidgets(1), reason: '应用应该有至少一个 Scaffold');
      print('✅ 找到 ${tester.widgetList(scaffolds).length} 个 Scaffold');

      // 步骤 3: 截图（如果平台支持）
      print('');
      print('📍 步骤 3: 尝试截图');
      try {
        await binding.takeScreenshot('simple_demo_test');
        print('✅ 截图成功');
      } catch (e) {
        print('⚠️ 截图跳过（平台不支持）: $e');
      }

      // 步骤 4: 测试总结
      print('');
      print('=' * 60);
      print('📊 测试总结');
      print('✅ 应用启动成功');
      print('✅ UI 渲染正常');
      print('✅ 测试框架工作正常');
      print('🎉 测试完成！');
      print('=' * 60);
      print('');
    });

    testWidgets('Widget 查找测试', (WidgetTester tester) async {
      print('');
      print('🔍 开始 Widget 查找测试');
      print('=' * 60);

      // 启动应用
      app.main();
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 1));

      // 测试不同的 Widget 查找方法
      print('');
      print('📍 测试 Widget 查找方法：');

      // 1. 按类型查找
      final allScaffolds = find.byType(Scaffold);
      final scaffoldCount = tester.widgetList(allScaffolds).length;
      print('  - Scaffold: $scaffoldCount 个');

      // 2. 查找文本
      final allTexts = find.byType(Text);
      final textCount = tester.widgetList(allTexts).length;
      print('  - Text: $textCount 个');

      // 3. 查找容器
      final allContainers = find.byType(Container);
      final containerCount = tester.widgetList(allContainers).length;
      print('  - Container: $containerCount 个');

      print('');
      print('✅ Widget 查找测试完成');
      print('=' * 60);
    });

    testWidgets('基本交互测试', (WidgetTester tester) async {
      print('');
      print('👆 开始基本交互测试');
      print('=' * 60);

      // 启动应用
      app.main();
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 2));

      print('');
      print('📍 尝试查找可交互元素：');

      // 查找按钮
      final buttons = find.byType(ElevatedButton);
      final buttonCount = tester.widgetList(buttons).length;
      print('  - ElevatedButton: $buttonCount 个');

      // 查找图标按钮
      final iconButtons = find.byType(IconButton);
      final iconButtonCount = tester.widgetList(iconButtons).length;
      print('  - IconButton: $iconButtonCount 个');

      // 查找文本框
      final textFields = find.byType(TextField);
      final textFieldCount = tester.widgetList(textFields).length;
      print('  - TextField: $textFieldCount 个');

      // 如果有按钮，尝试点击
      if (buttonCount > 0) {
        print('');
        print('📍 尝试点击第一个按钮...');
        try {
          await tester.tap(buttons.first);
          await tester.pumpAndSettle();
          print('✅ 按钮点击成功');
        } catch (e) {
          print('⚠️ 按钮点击失败: $e');
        }
      } else {
        print('');
        print('⚠️ 没有找到可点击的按钮');
      }

      print('');
      print('✅ 基本交互测试完成');
      print('=' * 60);
    });
  });

  // 测试完成后的汇总
  tearDownAll(() {
    print('');
    print('🎉 所有简化测试完成！');
    print('💡 提示：这个简化测试用于快速验证框架功能');
    print('💡 要测试完整功能，请运行 enhanced_chat_test.dart');
    print('');
  });
}
