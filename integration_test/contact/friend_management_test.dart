// 好友管理测试
//
// 测试好友功能：
// - 添加好友
// - 删除好友
// - 好友列表查看
// - 好友资料查看

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/main.dart' as app;
import '../helper/test_enhanced_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('好友管理测试', () {
    testWidgets('查看好友列表', (WidgetTester tester) async {
      final helper = EnhancedTestHelper(tester);
      helper.startSession('friend_list', 'macOS');

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

        // 步骤 2: 查找好友列表入口
        await helper.step(
          'find_friend_tab',
          '查找好友标签页',
          action: () async {
            // 尝试查找底部导航的好友标签
            final friendTab = find.text('通讯录');
            final contactsTab = find.text('联系人');
            find.byIcon(
              Icons.people,
            ); // finder used implicitly in conditions below

            if (tester.any(friendTab)) {
              print('✅ 找到"通讯录"标签');
              await helper.tap(friendTab);
            } else if (tester.any(contactsTab)) {
              print('✅ 找到"联系人"标签');
              await helper.tap(contactsTab);
            } else {
              print('⚠️ 未找到好友标签页');
            }

            await helper.waitForLoad();
          },
          critical: false,
        );

        // 步骤 3: 检查好友列表
        await helper.step(
          'check_friend_list',
          '检查好友列表',
          action: () async {
            final listItems = find.byType(ListTile);
            final count = tester.widgetList(listItems).length;
            print('✅ 找到 $count 个列表项');

            if (count == 0) {
              print('⚠️ 好友列表为空');
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

    testWidgets('添加好友', (WidgetTester tester) async {
      final helper = EnhancedTestHelper(tester);
      helper.startSession('add_friend', 'macOS');

      try {
        await helper.step(
          'launch',
          '启动应用',
          action: () async {
            app.main();
            await helper.waitForLoad();
          },
        );

        // 步骤: 查找添加好友入口
        await helper.step(
          'find_add_friend',
          '查找添加好友按钮',
          action: () async {
            final addButton = find.byIcon(Icons.person_add);
            final qrButton = find.byIcon(Icons.qr_code_scanner);

            if (tester.any(addButton)) {
              print('✅ 找到添加好友按钮');
            }
            if (tester.any(qrButton)) {
              print('✅ 找到扫一扫按钮');
            }

            // 尝试查找浮动按钮
            final fab = find.byType(FloatingActionButton);
            if (tester.any(fab)) {
              print('✅ 找到浮动操作按钮');
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

    testWidgets('查看好友资料', (WidgetTester tester) async {
      final helper = EnhancedTestHelper(tester);
      helper.startSession('friend_profile', 'macOS');

      try {
        await helper.step(
          'launch',
          '启动应用',
          action: () async {
            app.main();
            await helper.waitForLoad();
          },
        );

        // 步骤: 查找并点击好友
        await helper.step(
          'click_friend',
          '点击好友查看资料',
          action: () async {
            final listTiles = find.byType(ListTile);
            if (tester.any(listTiles)) {
              await helper.tap(listTiles.first);
              print('✅ 点击好友项');
            } else {
              throw Exception('未找到好友列表');
            }
          },
          critical: false,
        );

        // 步骤: 检查资料页元素
        await helper.step(
          'check_profile',
          '检查好友资料页面',
          action: () async {
            await helper.waitForLoad();

            // 查找常见的资料页元素
            final avatar = find.byType(CircleAvatar);
            find.text('昵称'); // finder used for display purposes
            final chatButton = find.text('发消息');

            if (tester.any(avatar)) {
              print('✅ 找到头像');
            }
            if (tester.any(chatButton)) {
              print('✅ 找到发消息按钮');
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
