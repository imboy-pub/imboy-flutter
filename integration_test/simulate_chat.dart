// 聊天模拟测试 - 模拟发送消息
//
// 使用方法：
// flutter test integration_test/simulate_chat.dart --dart-define=APP_ENV=local_office -d macos

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:imboy/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('聊天模拟测试', () {
    testWidgets('模拟聊天场景', (WidgetTester tester) async {
      print('🚀 开始聊天模拟测试');

      // 启动应用
      app.main();
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 3));

      print('📱 应用已启动');

      // 模拟等待 3 秒
      await Future.delayed(const Duration(seconds: 3));

      // 查找文本输入框
      final textField = find.byType(TextField);
      int messageCount = 0;

      // 模拟发送多条消息
      final messages = [
        'Hello from automated test! 👋',
        '这是自动化测试消息',
        'Test message #3',
        '你好！',
        '测试完成 ✅',
      ];

      for (final msg in messages) {
        print('💬 尝试发送: $msg');

        if (tester.any(textField)) {
          try {
            // 点击输入框
            await tester.tap(textField.first);
            await tester.pumpAndSettle();

            // 输入消息
            await tester.enterText(textField.first, msg);
            await tester.pumpAndSettle();

            // 按回车发送
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pumpAndSettle();

            print('✅ 消息已发送: $msg');
            messageCount++;

            // 等待消息发送完成
            await Future.delayed(const Duration(seconds: 2));
          } catch (e) {
            print('⚠️ 发送失败: $e');
          }
        } else {
          print('⚠️ 未找到输入框，可能需要先进入聊天页面');

          // 尝试查找会话
          final listTile = find.byType(ListTile);
          if (tester.any(listTile)) {
            print('📋 找到会话，尝试打开');
            await tester.tap(listTile.first);
            await tester.pumpAndSettle();
            await Future.delayed(const Duration(seconds: 2));
          }
        }
      }

      print('');
      print('📊 聊天模拟完成');
      print('✅ 发送了 $messageCount 条消息');
    });
  });
}
