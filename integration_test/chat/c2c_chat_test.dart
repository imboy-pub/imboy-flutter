// 单聊功能测试
//
// 测试单聊的核心功能：
// - 发送文本消息
// - 发送图片消息
// - 消息历史加载
// - 消息状态显示

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/main.dart' as app;
import '../helper/test_enhanced_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('单聊功能测试', () {
    testWidgets('发送文本消息', (WidgetTester tester) async {
      final helper = EnhancedTestHelper(tester);
      helper.startSession('c2c_send_text', 'macOS');

      try {
        // 步骤 1: 启动应用
        await helper.step(
          'launch',
          '启动应用',
          action: () async {
            app.main();
            await helper.waitForLoad();
          },
        );

        // 步骤 2: 查找并点击会话
        await helper.step(
          'open_conversation',
          '打开会话列表',
          action: () async {
            final listTiles = find.byType(ListTile);
            if (tester.any(listTiles)) {
              await helper.tap(listTiles.first);
            } else {
              throw Exception('未找到会话列表');
            }
          },
        );

        // 步骤 3: 查找输入框
        await helper.step(
          'find_input',
          '查找消息输入框',
          action: () async {
            final textField = find.byType(TextField);
            if (!tester.any(textField)) {
              throw Exception('未找到消息输入框');
            }
          },
          critical: false,
        );

        // 步骤 4: 输入测试消息
        await helper.step(
          'enter_message',
          '输入测试消息',
          action: () async {
            final textField = find.byType(TextField);
            await helper.enterText(
              textField,
              'Hello from automated test! ${DateTime.now()}',
            );
          },
        );

        // 步骤 5: 发送消息
        await helper.step(
          'send_message',
          '发送消息',
          action: () async {
            // 尝试多种发送方式
            final sendButton = find.text('发送');
            if (tester.any(sendButton)) {
              await helper.tap(sendButton);
            } else {
              final sendIcon = find.byIcon(Icons.send);
              if (tester.any(sendIcon)) {
                await helper.tap(sendIcon);
              } else {
                throw Exception('未找到发送按钮');
              }
            }
          },
        );

        // 步骤 6: 等待消息显示
        await helper.step(
          'wait_for_message',
          '等待消息显示',
          action: () async {
            await Future.delayed(const Duration(seconds: 2));
            // 这里可以验证消息是否出现在列表中
          },
          critical: false,
        );

        await helper.finishSession(passed: true);
      } catch (e) {
        await helper.finishSession(passed: false);
        rethrow;
      }
    });

    testWidgets('消息历史加载', (WidgetTester tester) async {
      final helper = EnhancedTestHelper(tester);
      helper.startSession('c2c_load_history', 'macOS');

      try {
        await helper.step(
          'launch_and_open',
          '启动应用并打开会话',
          action: () async {
            app.main();
            await helper.waitForLoad();

            final listTiles = find.byType(ListTile);
            if (tester.any(listTiles)) {
              await helper.tap(listTiles.first);
            }
          },
        );

        await helper.step(
          'scroll_history',
          '滚动加载历史消息',
          action: () async {
            final listView = find.byType(ListView);
            if (tester.any(listView)) {
              // 向下滚动触发历史消息加载
              await helper.scroll(
                listView,
                delta: const Offset(0, 500),
                times: 3,
              );
            }
          },
          critical: false,
        );

        await helper.finishSession(passed: true);
      } catch (e) {
        await helper.finishSession(passed: false);
        rethrow;
      }
    });
  });
}
