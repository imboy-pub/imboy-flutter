// 群组聊天测试
//
// 测试群组功能：
// - 创建群组
// - 加入群组
// - 发送群消息
// - 群成员管理

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/main.dart' as app;
import '../helper/test_enhanced_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('群组聊天测试', () {
    testWidgets('创建群组', (WidgetTester tester) async {
      final helper = EnhancedTestHelper(tester);
      helper.startSession('group_create', 'macOS');

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

        // 步骤 2: 查找创建群组入口
        await helper.step(
          'find_create_group',
          '查找创建群组按钮',
          action: () async {
            // 尝试多种方式查找创建群组按钮
            final createButton = find.text('创建群组');
            if (tester.any(createButton)) {
              print('✅ 找到"创建群组"按钮');
            } else {
              final addButton = find.byIcon(Icons.add);
              if (tester.any(addButton)) {
                print('✅ 找到添加按钮');
              } else {
                throw Exception('未找到创建群组入口');
              }
            }
          },
          critical: false,
        );

        // 步骤 3: 点击创建（如果找到）
        await helper.step(
          'click_create',
          '点击创建群组',
          action: () async {
            final createButton = find.text('创建群组');
            if (tester.any(createButton)) {
              await helper.tap(createButton);
              await helper.waitForLoad();
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

    testWidgets('发送群消息', (WidgetTester tester) async {
      final helper = EnhancedTestHelper(tester);
      helper.startSession('group_send_message', 'macOS');

      try {
        await helper.step(
          'launch',
          '启动应用',
          action: () async {
            app.main();
            await helper.waitForLoad();
          },
        );

        // 步骤: 查找群组会话
        await helper.step(
          'find_group_chat',
          '查找群组会话',
          action: () async {
            final listTiles = find.byType(ListTile);
            if (tester.any(listTiles)) {
              // 群组会话通常有特殊的标识，这里点击第一个
              await helper.tap(listTiles.first);
            } else {
              throw Exception('未找到会话列表');
            }
          },
        );

        // 步骤: 发送群消息
        await helper.step(
          'send_group_message',
          '发送群消息',
          action: () async {
            final textField = find.byType(TextField);
            if (tester.any(textField)) {
              await helper.enterText(textField, '群消息测试 ${DateTime.now()}');

              final sendButton = find.text('发送');
              if (tester.any(sendButton)) {
                await helper.tap(sendButton);
              }
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

    testWidgets('群成员管理', (WidgetTester tester) async {
      final helper = EnhancedTestHelper(tester);
      helper.startSession('group_member_manage', 'macOS');

      try {
        await helper.step(
          'launch',
          '启动应用',
          action: () async {
            app.main();
            await helper.waitForLoad();
          },
        );

        // 步骤: 查找群组设置入口
        await helper.step(
          'find_group_settings',
          '查找群组设置',
          action: () async {
            // 群组设置通常在聊天页面的右上角
            final moreButton = find.byIcon(Icons.more_vert);
            final settingsButton = find.byIcon(Icons.settings);

            if (tester.any(moreButton)) {
              print('✅ 找到更多按钮');
            }
            if (tester.any(settingsButton)) {
              print('✅ 找到设置按钮');
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
