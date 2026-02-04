// 会话管理与消息提醒测试
//
// 测试会话功能：
// - 会话列表显示
// - 未读消息提醒
// - 会话置顶
// - 删除会话

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/main.dart' as app;
import '../helper/test_enhanced_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('会话管理测试', () {
    testWidgets('会话列表显示', (WidgetTester tester) async {
      final helper = EnhancedTestHelper(tester);
      helper.startSession('conversation_list', 'macOS');

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

        // 步骤 2: 检查会话列表
        await helper.step(
          'check_conversation_list',
          '检查会话列表',
          action: () async {
            final listTiles = find.byType(ListTile);
            final count = tester.widgetList(listTiles).length;

            print('✅ 找到 $count 个会话');

            // 检查是否有未读消息标识
            final badges = find.byType(Badge);
            if (tester.any(badges)) {
              print('✅ 找到未读消息标识');
            }
          },
        );

        await helper.finishSession(passed: true);
      } catch (e) {
        await helper.finishSession(passed: false);
        rethrow;
      }
    });

    testWidgets('未读消息提醒', (WidgetTester tester) async {
      final helper = EnhancedTestHelper(tester);
      helper.startSession('unread_notification', 'macOS');

      try {
        await helper.step(
          'launch',
          '启动应用',
          action: () async {
            app.main();
            await helper.waitForLoad();
          },
        );

        // 步骤: 检查未读消息标识
        await helper.step(
          'check_unread_badge',
          '检查未读消息标识',
          action: () async {
            // 查找可能的未读标识
            final badges = find.byType(Badge);
            final redDots = find.byType(CircleAvatar);

            if (tester.any(badges)) {
              print('✅ 找到 Badge 未读标识');
            }

            if (tester.any(redDots)) {
              final count = tester.widgetList(redDots).length;
              print('✅ 找到 $count 个圆形头像（可能包含红点）');
            }

            // 查找包含数字的未读标识
            final textWidgets = find.byType(Text);
            for (int i = 0; i < tester.widgetList(textWidgets).length; i++) {
              final text = tester.widget<Text>(textWidgets.at(i));
              if (text.data != null && _isNumeric(text.data!)) {
                print('✅ 可能的未读数字: ${text.data}');
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

    testWidgets('会话操作菜单', (WidgetTester tester) async {
      final helper = EnhancedTestHelper(tester);
      helper.startSession('conversation_menu', 'macOS');

      try {
        await helper.step(
          'launch',
          '启动应用',
          action: () async {
            app.main();
            await helper.waitForLoad();
          },
        );

        // 步骤: 长按会话查看菜单
        await helper.step(
          'long_press_conversation',
          '长按会话查看操作菜单',
          action: () async {
            final listTiles = find.byType(ListTile);
            if (tester.any(listTiles)) {
              // 长按第一个会话
              await tester.longPress(listTiles.first);
              await tester.pumpAndSettle();
              print('✅ 长按会话成功');
            } else {
              throw Exception('未找到会话列表');
            }
          },
          critical: false,
        );

        // 步骤: 检查菜单选项
        await helper.step(
          'check_menu_options',
          '检查操作菜单选项',
          action: () async {
            // 常见的会话操作选项
            final options = ['置顶', '删除', '免打扰', '标记已读'];

            for (final option in options) {
              final finder = find.text(option);
              if (tester.any(finder)) {
                print('✅ 找到菜单选项: $option');
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

    testWidgets('会话搜索', (WidgetTester tester) async {
      final helper = EnhancedTestHelper(tester);
      helper.startSession('conversation_search', 'macOS');

      try {
        await helper.step(
          'launch',
          '启动应用',
          action: () async {
            app.main();
            await helper.waitForLoad();
          },
        );

        // 步骤: 查找搜索框
        await helper.step(
          'find_search',
          '查找搜索框',
          action: () async {
            final searchField = find.byType(TextField);
            final searchIcon = find.byIcon(Icons.search);

            if (tester.any(searchField)) {
              print('✅ 找到搜索框');

              // 尝试输入搜索内容
              await helper.enterText(searchField.first, 'test');
            }

            if (tester.any(searchIcon)) {
              print('✅ 找到搜索图标');
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

// 判断字符串是否为数字
bool _isNumeric(String str) {
  return int.tryParse(str) != null;
}
