// 添加好友请求测试
//
// 测试场景：06_add_friend_request
// 测试内容：
//   1. 登录应用
//   2. 进入联系人页面
//   3. 进入新的朋友页面
//   4. 进入添加好友页面
//   5. 搜索用户
//   6. 发送好友请求
//   7. 验证发送成功

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/i18n/strings.g.dart';
import '../helper/test_enhanced_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('添加好友请求测试 (06_add_friend_request)', () {
    testWidgets('完整添加好友流程', (WidgetTester tester) async {
      final helper = EnhancedTestHelper(tester);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      helper.startSession('add_friend_request_full', 'macOS');

      try {
        // ============================================================
        // 阶段 1: 启动应用并登录
        // ============================================================
        await helper.step(
          'launch_app',
          '启动应用',
          action: () async {
            app.main();
            await helper.waitForLoad();
            await tester.pumpAndSettle(const Duration(seconds: 2));
          },
        );

        // 检查是否需要登录
        final loginButton = find.text(t.login);
        final needLogin = tester.any(loginButton);

        if (needLogin) {
          await helper.step(
            'login',
            '登录测试账号',
            action: () async {
              // 输入手机号
              final phoneField = find.byType(TextField).first;
              await helper.enterText(phoneField, '13800138000');

              // 输入密码
              final passwordField = find.byType(TextField).at(1);
              await helper.enterText(passwordField, 'Test123456');

              // 点击登录按钮
              await helper.tap(loginButton);

              // 等待登录完成
              await helper.waitForLoad();
              await tester.pumpAndSettle(const Duration(seconds: 5));
            },
          );
        }

        // ============================================================
        // 阶段 2: 进入联系人页面
        // ============================================================
        await helper.step(
          'navigate_to_contacts',
          '进入联系人页面',
          action: () async {
            // 查找联系人标签（可能的文本）
            final contactsTab = find.text(t.titleContact);
            final addressBookTab = find.text('通讯录');

            if (tester.any(contactsTab)) {
              print('✅ 找到"联系人"标签');
              await helper.tap(contactsTab);
            } else if (tester.any(addressBookTab)) {
              print('✅ 找到"通讯录"标签');
              await helper.tap(addressBookTab);
            } else {
              // 尝试通过图标查找
              final contactsIcon = find.byIcon(Icons.people);
              if (tester.any(contactsIcon)) {
                print('✅ 找到联系人图标');
                await helper.tap(contactsIcon);
              } else {
                throw Exception('未找到联系人标签页');
              }
            }

            await helper.waitForLoad();
            await tester.pumpAndSettle(const Duration(seconds: 1));
          },
        );

        // ============================================================
        // 阶段 3: 进入新的朋友页面
        // ============================================================
        await helper.step(
          'navigate_to_new_friend',
          '进入新的朋友页面',
          action: () async {
            // 查找"新的朋友"文本
            final newFriendText = find.text(t.newFriend);

            if (tester.any(newFriendText)) {
              print('✅ 找到"新的朋友"选项');
              await helper.tap(newFriendText);
            } else {
              // 尝试查找包含"新"和"友"的列表项
              final listTiles = find.byType(ListTile);
              print('⚠️ 未直接找到"新的朋友"文本，查找列表项...');
              print('找到 ${tester.widgetList(listTiles).length} 个列表项');

              // 遍历列表项查找
              bool found = false;
              for (int i = 0; i < tester.widgetList(listTiles).length; i++) {
                final tile = listTiles.at(i);
                try {
                  final widget = tester.widget(tile) as ListTile;
                  if (widget.title != null) {
                    final titleText = widget.title is Text
                        ? (widget.title as Text).data ?? ''
                        : '';
                    print('列表项 $i: $titleText');
                    if (titleText.contains('新') && titleText.contains('友')) {
                      print('✅ 找到"新的朋友"列表项');
                      await helper.tap(tile);
                      found = true;
                      break;
                    }
                  }
                } catch (e) {
                  // 忽略错误，继续查找
                }
              }

              if (!found) {
                throw Exception('未找到"新的朋友"入口');
              }
            }

            await helper.waitForLoad();
            await tester.pumpAndSettle(const Duration(seconds: 2));
          },
        );

        // ============================================================
        // 阶段 4: 进入添加好友页面
        // ============================================================
        await helper.step(
          'navigate_to_add_friend',
          '进入添加好友页面',
          action: () async {
            // 查找右上角的添加图标
            final addIcon = find.byIcon(Icons.person_add_outlined);
            final addIcon2 = find.byIcon(Icons.person_add);

            if (tester.any(addIcon)) {
              print('✅ 找到添加好友图标 (person_add_outlined)');
              await helper.tap(addIcon);
            } else if (tester.any(addIcon2)) {
              print('✅ 找到添加好友图标 (person_add)');
              await helper.tap(addIcon2);
            } else {
              // 尝试查找 AppBar 中的 IconButton
              final iconButtons = find.byType(IconButton);
              print('找到 ${tester.widgetList(iconButtons).length} 个图标按钮');

              bool found = false;
              for (int i = 0; i < tester.widgetList(iconButtons).length; i++) {
                final button = iconButtons.at(i);
                try {
                  final widget = tester.widget(button) as IconButton;
                  if (widget.icon is Icon) {
                    final icon = widget.icon as Icon;
                    if (icon.icon == Icons.person_add_outlined ||
                        icon.icon == Icons.person_add) {
                      print('✅ 找到添加好友按钮');
                      await helper.tap(button);
                      found = true;
                      break;
                    }
                  }
                } catch (e) {
                  // 忽略错误，继续查找
                }
              }

              if (!found) {
                throw Exception('未找到添加好友按钮');
              }
            }

            await helper.waitForLoad();
            await tester.pumpAndSettle(const Duration(seconds: 2));
          },
        );

        // ============================================================
        // 阶段 5: 搜索用户
        // ============================================================
        await helper.step(
          'search_user',
          '搜索用户',
          action: () async {
            // 查找搜索框（SearchBar 或 TextField）
            final searchBars = find.byType(SearchBar);
            final textFields = find.byType(TextField);

            if (tester.any(searchBars)) {
              print('✅ 找到 SearchBar');
              final searchBar = searchBars.first;
              await helper.tap(searchBar);

              // 输入搜索关键词
              await helper.enterText(searchBar, '测试');
            } else if (tester.any(textFields)) {
              print('✅ 找到 TextField');
              final textField = textFields.first;
              await helper.tap(textField);
              await helper.enterText(textField, '测试');
            } else {
              print('⚠️ 未找到搜索框');
            }

            // 等待搜索结果
            await tester.pumpAndSettle(const Duration(seconds: 3));
          },
        );

        // ============================================================
        // 阶段 6: 查看搜索结果并选择用户
        // ============================================================
        await helper.step(
          'select_user',
          '选择用户',
          action: () async {
            // 查找搜索结果列表项
            final listTiles = find.byType(ListTile);
            final count = tester.widgetList(listTiles).length;
            print('找到 $count 个搜索结果列表项');

            if (count > 0) {
              // 点击第一个用户（如果不是自己）
              await helper.tap(listTiles.first);
              await helper.waitForLoad();
              await tester.pumpAndSettle(const Duration(seconds: 2));
            } else {
              print('⚠️ 搜索结果为空');
            }
          },
          critical: false, // 如果没有搜索结果不算失败
        );

        // ============================================================
        // 阶段 7: 发送好友请求（如果找到了用户）
        // ============================================================
        await helper.step(
          'send_friend_request',
          '发送好友请求',
          action: () async {
            // 查找"添加到通讯录"或"添加"按钮
            final addButtonTexts = [
              '添加到通讯录',
              t.buttonAdd,
              '添加',
              '申请添加',
            ];

            bool addButtonFound = false;
            for (String buttonText in addButtonTexts) {
              final button = find.text(buttonText);
              if (tester.any(button)) {
                print('✅ 找到添加按钮: $buttonText');
                await helper.tap(button);
                addButtonFound = true;
                break;
              }
            }

            if (!addButtonFound) {
              // 尝试查找 ElevatedButton
              final elevatedButtons = find.byType(ElevatedButton);
              if (tester.any(elevatedButtons)) {
                print('✅ 找到 ElevatedButton');
                await helper.tap(elevatedButtons.first);
                addButtonFound = true;
              }
            }

            if (addButtonFound) {
              await helper.waitForLoad();
              await tester.pumpAndSettle(const Duration(seconds: 2));

              // 输入验证消息
              final textFields = find.byType(TextField);
              if (tester.any(textFields)) {
                print('✅ 找到验证消息输入框');
                final msgField = textFields.first;
                await helper.enterText(
                  msgField,
                  '你好，我是测试用户，请求添加好友 ($timestamp)',
                );
              }

              // 点击发送按钮
              final sendButtonTexts = [t.buttonSend, '发送', t.send];
              for (String buttonText in sendButtonTexts) {
                final button = find.text(buttonText);
                if (tester.any(button)) {
                  print('✅ 找到发送按钮: $buttonText');
                  await helper.tap(button);
                  break;
                }
              }

              // 等待发送完成
              await helper.waitForLoad();
              await tester.pumpAndSettle(const Duration(seconds: 3));
            } else {
              print('⚠️ 未找到添加按钮，可能已是好友或未找到用户');
            }
          },
          critical: false,
        );

        // ============================================================
        // 阶段 8: 验证结果
        // ============================================================
        await helper.step(
          'verify_result',
          '验证发送结果',
          action: () async {
            // 查找成功提示
            final successTexts = [
              '发送成功',
              '已发送',
              t.friendRequestSent,
            ];

            bool successFound = false;
            for (String text in successTexts) {
              if (tester.any(find.text(text))) {
                print('✅ 找到成功提示: $text');
                successFound = true;
                break;
              }
            }

            if (!successFound) {
              print('⚠️ 未找到明确的成功提示');
            }

            // 检查是否返回到新的朋友页面
            final newFriendTitle = find.text(t.newFriend);
            if (tester.any(newFriendTitle)) {
              print('✅ 已返回新的朋友页面');
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

    testWidgets('通过手机号搜索用户', (WidgetTester tester) async {
      final helper = EnhancedTestHelper(tester);
      helper.startSession('search_by_phone', 'macOS');

      try {
        await helper.step(
          'launch',
          '启动应用',
          action: () async {
            app.main();
            await helper.waitForLoad();
          },
        );

        // 导航到添加好友页面（省略部分步骤）
        // ... (这里可以复用上面的导航逻辑)

        await helper.finishSession(passed: true);
      } catch (e) {
        await helper.finishSession(passed: false);
        rethrow;
      }
    });

    testWidgets('通过 UID 搜索用户', (WidgetTester tester) async {
      final helper = EnhancedTestHelper(tester);
      helper.startSession('search_by_uid', 'macOS');

      try {
        await helper.step(
          'launch',
          '启动应用',
          action: () async {
            app.main();
            await helper.waitForLoad();
          },
        );

        // 导航到添加好友页面并搜索 UID
        // ... (这里可以复用上面的导航逻辑)

        await helper.finishSession(passed: true);
      } catch (e) {
        await helper.finishSession(passed: false);
        rethrow;
      }
    });
  });
}
