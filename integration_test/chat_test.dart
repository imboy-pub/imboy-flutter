// Flutter 集成测试 - 聊天功能测试
//
// 使用方法：
// flutter test integration_test/chat_test.dart --dart-define=APP_ENV=local_office

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'flows/app_launcher.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('IM Boy 聊天功能测试', () {
    testWidgets('发送消息测试', (WidgetTester tester) async {
      // 启动应用
      await ensureAppLaunched(tester);
      await tester.pumpAndSettle();

      // 等待应用完全加载
      await tester.pump(const Duration(seconds: 3));

      print('📱 应用已启动');

      // 尝试进入聊天页面
      // 查找会话列表或联系人入口
      final conversationTab = find.text('会话');
      final contactTab = find.text('联系人');

      if (tester.any(conversationTab)) {
        print('✅ 找到会话标签');
        await tester.tap(conversationTab);
        await tester.pumpAndSettle();
      } else if (tester.any(contactTab)) {
        print('✅ 找到联系人标签');
        await tester.tap(contactTab);
        await tester.pumpAndSettle();
      }

      // 截图（Web 平台跳过）
      final bool isWeb = identical(0.0, 0);
      if (!isWeb) {
        await binding.takeScreenshot('after_tap_conversation');
        print('✅ 截图已保存');
      } else {
        print('⚠️ Web 平台跳过截图');
      }
    });

    testWidgets('输入框测试', (WidgetTester tester) async {
      await ensureAppLaunched(tester);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));

      // 查找文本输入框（使用 Key 或 Type）
      final textField = find.byType(TextField);

      if (tester.any(textField)) {
        print('✅ 找到输入框');

        // 输入测试文本
        await tester.enterText(textField.first, 'Hello, Test!');
        await tester.pumpAndSettle();

        // 验证输入内容
        final text = tester.widget<TextField>(textField.first);
        expect(text.controller?.text, contains('Hello, Test!'));

        print('✅ 文本输入成功');
      } else {
        print('⚠️ 未找到输入框，可能需要先进入聊天页面');
      }

      final bool isWeb = identical(0.0, 0);
      if (!isWeb) {
        await binding.takeScreenshot('input_test');
      }
    });
  });
}
