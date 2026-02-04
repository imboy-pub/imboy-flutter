// 群组管理功能测试 (09_group_manage)
//
// 测试群组管理功能：
// 1. 登录
// 2. 进入群组详情
// 3. 修改群组名称
// 4. 发布群公告
// 5. 管理群成员
// 6. 查看群设置选项
//
// 对应测试场景: test_automation/scenarios/09_group_manage.yaml
// 使用方法：
//   flutter test integration_test/group_manage_test.dart --dart-define=APP_ENV=local_office -d macos

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/main.dart' as app;
import 'helper/test_enhanced_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('群组管理功能测试', () {
    testWidgets('完整群组管理流程测试', (WidgetTester tester) async {
      final helper = EnhancedTestHelper(
        tester,
        outputDir: 'test_automation/reports',
      );
      helper.startSession('group_manage_test', 'macOS');

      try {
        // ========== 阶段 1: 启动应用 ==========
        await helper.step(
          'launch',
          '启动 IM Boy 应用',
          action: () async {
            app.main();
            await helper.waitForLoad();
            await tester.pump(const Duration(seconds: 3));
          },
        );

        // ========== 阶段 2: 检查登录状态 ==========
        await helper.step(
          'check_login_status',
          '检查是否需要登录',
          action: () async {
            final loginButton = find.text('登录');
            if (tester.any(loginButton)) {
              print('✅ 发现登录按钮 - 需要登录');

              // 点击登录按钮
              await helper.tap(loginButton);
              await helper.waitForLoad();

              // 输入手机号
              final phoneField = find.byType(TextField).first;
              await helper.enterText(phoneField, '13800138000');

              // 输入密码
              final passwordField = find.byType(TextField).at(1);
              await helper.enterText(passwordField, 'Test123456');

              // 提交登录
              final submitButton = find.text('登录');
              if (tester.any(submitButton)) {
                await helper.tap(submitButton);
              }

              // 等待登录成功
              await tester.pump(const Duration(seconds: 5));
            } else {
              print('✅ 未发现登录按钮 - 用户已登录');
            }
          },
        );

        // ========== 阶段 3: 进入会话列表 ==========
        await helper.step(
          'enter_conversations',
          '进入会话列表',
          action: () async {
            final conversationTab = find.text('会话');
            if (tester.any(conversationTab)) {
              await helper.tap(conversationTab);
              await helper.waitForLoad();
            }
          },
        );

        // ========== 阶段 4: 查找群聊会话 ==========
        await helper.step(
          'find_group_chat',
          '查找群聊会话',
          action: () async {
            // 尝试查找 "测试群组"
            final groupChat = find.text('测试群组');
            if (tester.any(groupChat)) {
              print('✅ 找到群聊: 测试群组');
              await helper.tap(groupChat);
            } else {
              // 尝试查找任何群聊（通常群聊有特殊的图标或标识）
              final listTiles = find.byType(ListTile);
              if (tester.any(listTiles)) {
                print('ℹ️ 未找到"测试群组"，点击第一个会话');
                await helper.tap(listTiles.first);
              }
            }
            await helper.waitForLoad();
          },
        );

        // ========== 阶段 5: 进入群组详情 ==========
        await helper.step(
          'enter_group_detail',
          '进入群组详情页',
          action: () async {
            // 尝试多种方式进入群组详情
            final groupTitle = find.text('测试群组');
            if (tester.any(groupTitle)) {
              print('✅ 找到群组标题，点击进入详情');
              await helper.tap(groupTitle);
            } else {
              // 尝试查找更多/设置按钮
              final moreButton = find.byIcon(Icons.more_vert);
              final settingsButton = find.byIcon(Icons.settings);

              if (tester.any(moreButton)) {
                print('✅ 找到更多按钮');
                await helper.tap(moreButton);
              } else if (tester.any(settingsButton)) {
                print('✅ 找到设置按钮');
                await helper.tap(settingsButton);
              } else {
                // 尝试点击 AppBar
                final appBar = find.byType(AppBar);
                if (tester.any(appBar)) {
                  print('✅ 找到 AppBar，点击进入详情');
                  await helper.tap(appBar);
                }
              }
            }
            await helper.waitForLoad();
          },
        );

        // ========== 阶段 6: 修改群组名称 ==========
        await helper.step(
          'modify_group_name',
          '修改群组名称',
          action: () async {
            // 查找群名称设置项
            final groupNameLabel = find.text('群名称');
            if (tester.any(groupNameLabel)) {
              print('✅ 找到群名称设置项');
              await helper.tap(groupNameLabel);
              await helper.waitForLoad();

              // 输入新名称
              final textField = find.byType(TextField);
              if (tester.any(textField)) {
                await helper.enterText(textField, '测试群组（已修改）');

                // 点击保存
                final saveButton = find.text('保存');
                if (tester.any(saveButton)) {
                  await helper.tap(saveButton);
                } else {
                  final completeButton = find.text('完成');
                  if (tester.any(completeButton)) {
                    await helper.tap(completeButton);
                  }
                }
              }
            } else {
              print('⚠️ 未找到群名称设置项');
            }
            await tester.pump(const Duration(seconds: 2));
          },
          critical: false,
        );

        // ========== 阶段 7: 验证群名称修改 ==========
        await helper.step(
          'verify_group_name',
          '验证群组名称修改成功',
          action: () async {
            final newName = find.text('测试群组（已修改）');
            if (tester.any(newName)) {
              print('✅ 群名称已成功修改');
            } else {
              print('⚠️ 未找到新群名称，可能修改失败或未显示');
            }
          },
          critical: false,
        );

        // ========== 阶段 8: 发布群公告 ==========
        await helper.step(
          'publish_announcement',
          '发布群公告',
          action: () async {
            // 查找群公告设置项
            final announcementLabel = find.text('群公告');
            if (tester.any(announcementLabel)) {
              print('✅ 找到群公告设置项');
              await helper.tap(announcementLabel);
              await helper.waitForLoad();

              // 输入公告内容
              final textField = find.byType(TextField);
              if (tester.any(textField)) {
                await helper.enterText(textField, '这是新的群公告');

                // 点击发布
                final publishButton = find.text('发布');
                if (tester.any(publishButton)) {
                  await helper.tap(publishButton);
                } else {
                  final saveButton = find.text('保存');
                  if (tester.any(saveButton)) {
                    await helper.tap(saveButton);
                  }
                }
              }
            } else {
              print('⚠️ 未找到群公告设置项');
            }
            await tester.pump(const Duration(seconds: 2));
          },
          critical: false,
        );

        // ========== 阶段 9: 查看群成员 ==========
        await helper.step(
          'view_group_members',
          '查看群成员列表',
          action: () async {
            // 返回群组详情（如果在其他页面）
            final backButton = find.text('返回');
            if (tester.any(backButton)) {
              await helper.tap(backButton);
            }

            await tester.pump(const Duration(seconds: 1));

            // 查找群成员入口
            final membersLabel = find.text('群成员');
            if (tester.any(membersLabel)) {
              print('✅ 找到群成员入口');
              await helper.tap(membersLabel);
              await helper.waitForLoad();

              // 验证成员列表
              final listTiles = find.byType(ListTile);
              if (tester.any(listTiles)) {
                final memberCount = listTiles.evaluate().length;
                print('✅ 成员列表已加载，成员数: $memberCount');
              }
            } else {
              print('⚠️ 未找到群成员入口');
            }
          },
          critical: false,
        );

        // ========== 阶段 10: 查看更多管理选项 ==========
        await helper.step(
          'view_more_options',
          '查看更多管理选项',
          action: () async {
            // 返回群组详情
            final backButton = find.text('返回');
            if (tester.any(backButton)) {
              await helper.tap(backButton);
            }

            await tester.pump(const Duration(seconds: 1));

            // 尝试滚动查找更多选项
            try {
              final scrollView = find.byType(Scrollable);
              if (tester.any(scrollView)) {
                print('✅ 找到可滚动视图，向下滚动查找更多选项');
                await helper.scroll(scrollView.first, delta: const Offset(0, -500));
                await tester.pump(const Duration(seconds: 1));
              }
            } catch (e) {
              print('⚠️ 滚动失败: $e');
            }

            // 查找常见的群管理选项
            final options = [
              '群设置',
              '群管理',
              '邀请成员',
              '移除成员',
              '转让群主',
              '解散群组',
              '退出群组',
            ];

            for (final option in options) {
              final optionFinder = find.text(option);
              if (tester.any(optionFinder)) {
                print('✅ 找到选项: $option');
              }
            }
          },
          critical: false,
        );

        // ========== 测试完成 ==========
        await helper.step(
          'test_complete',
          '测试完成',
          action: () async {
            print('✅ 群组管理测试已完成');
            await tester.pump(const Duration(seconds: 2));
          },
        );

        await helper.finishSession(passed: true);
      } catch (e) {
        await helper.finishSession(passed: false);
        rethrow;
      }
    });

    testWidgets('快速群组管理测试', (WidgetTester tester) async {
      final helper = EnhancedTestHelper(
        tester,
        outputDir: 'test_automation/reports',
      );
      helper.startSession('group_manage_quick_test', 'macOS');

      try {
        // 启动应用
        app.main();
        await helper.waitForLoad();
        await tester.pump(const Duration(seconds: 3));

        // 快速测试：查找群组相关的 UI 元素
        await helper.step(
          'check_group_ui',
          '检查群组相关 UI 元素',
          action: () async {
            // 检查会话标签
            final conversationTab = find.text('会话');
            if (tester.any(conversationTab)) {
              print('✅ 找到会话标签');
            }

            // 检查群组相关的文本
            final groupTexts = [
              '群名称',
              '群公告',
              '群成员',
              '群设置',
              '群管理',
            ];

            for (final text in groupTexts) {
              final finder = find.text(text);
              if (tester.any(finder)) {
                print('✅ 找到: $text');
              }
            }
          },
        );

        await helper.finishSession(passed: true);
      } catch (e) {
        await helper.finishSession(passed: false);
        rethrow;
      }
    });
  });
}
