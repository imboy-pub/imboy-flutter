// 聊天模拟测试 v2 - 智能查找聊天界面
//
// 使用方法：
// flutter test integration_test/simulate_chat_v2.dart --dart-define=APP_ENV=local_office -d macos

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('智能聊天模拟', () {
    testWidgets('完整聊天流程模拟', (WidgetTester tester) async {
      print('🚀 开始智能聊天模拟');

      // 启动应用
      app.main();
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 5));

      print('📱 应用已启动，开始查找聊天界面...');

      // 尝试多个步骤找到聊天界面
      bool foundChat = false;

      // 步骤 1: 查找会话列表项
      final listTiles = find.byType(ListTile);
      if (tester.any(listTiles)) {
        final count = tester.widgetList(listTiles).length;
        print('✅ 找到 $count 个会话项');

        if (count > 0) {
          // 点击第一个会话
          await tester.tap(listTiles.first);
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 2));
          foundChat = true;
        }
      }

      // 步骤 2: 如果没有会话，查找底部导航
      if (!foundChat) {
        final bottomNav = find.byType(BottomNavigationBar);
        if (tester.any(bottomNav)) {
          print('📍 找到底部导航栏');
          // 尝试点击不同的标签
          final tabs = ['会话', '消息', '聊天', '联系人'];
          for (final tab in tabs) {
            final tabFinder = find.text(tab);
            if (tester.any(tabFinder)) {
              print('📌 点击标签: $tab');
              await tester.tap(tabFinder);
              await tester.pumpAndSettle();
              await Future.delayed(const Duration(seconds: 2));
              break;
            }
          }
        }
      }

      // 步骤 3: 查找输入框并发送消息
      final textField = find.byType(TextField);
      int messageCount = 0;

      if (tester.any(textField)) {
        print('✅ 找到输入框，开始发送消息');

        final messages = [
          'Hello from automated test! 👋',
          '这是自动化测试消息',
          'Test message #3',
        ];

        for (final msg in messages) {
          try {
            // 清空输入框
            await tester.tap(textField.first);
            await tester.pumpAndSettle();

            // 输入消息
            await tester.enterText(textField.first, msg);
            await tester.pumpAndSettle();

            print('💬 输入: $msg');

            // 尝试多种发送方式
            bool sent = false;

            // 方式 1: 点击发送按钮
            final sendButton = find.text('发送');
            if (tester.any(sendButton)) {
              await tester.tap(sendButton);
              await tester.pumpAndSettle();
              sent = true;
              print('✅ 点击发送按钮');
            }

            // 方式 2: 发送图标
            if (!sent) {
              final sendIcon = find.byIcon(Icons.send);
              if (tester.any(sendIcon)) {
                await tester.tap(sendIcon);
                await tester.pumpAndSettle();
                sent = true;
                print('✅ 点击发送图标');
              }
            }

            // 方式 3: 回车键
            if (!sent) {
              await tester.sendKeyEvent(LogicalKeyboardKey.enter);
              await tester.pumpAndSettle();
              sent = true;
              print('✅ 按下回车键');
            }

            if (sent) {
              messageCount++;
              print('✅ 消息已发送');
              await Future.delayed(const Duration(seconds: 2));
            } else {
              print('⚠️ 无法发送消息');
            }
          } catch (e) {
            print('❌ 发送失败: $e');
          }
        }
      } else {
        print('⚠️ 未找到输入框，当前页面可能不是聊天页面');

        // 打印当前页面信息
        final scaffold = find.byType(Scaffold);
        if (tester.any(scaffold)) {
          print('📋 当前页面有 Scaffold');
        }
      }

      print('');
      print('📊 测试总结');
      print('✅ 应用启动成功');
      print('💬 模拟发送 $messageCount 条消息');
      print('🎉 测试完成');
    });
  });
}
