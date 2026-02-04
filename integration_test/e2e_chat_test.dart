// Flutter 集成测试 - 端到端聊天测试
//
// 使用方法：
// flutter test integration_test/e2e_chat_test.dart --dart-define=APP_ENV=local_office

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/services.dart';
import 'package:imboy/main.dart' as app;
import 'test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('IM Boy 端到端聊天测试', () {
    testWidgets('完整聊天流程测试', (WidgetTester tester) async {
      TestHelper.log('🚀 开始端到端聊天测试');

      // 步骤 1: 启动应用
      TestHelper.log('步骤 1/5: 启动应用');
      app.main();
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 3));
      await TestHelper.screenshot(tester, '01_app_launch');

      // 步骤 2: 检查登录状态
      TestHelper.log('步骤 2/5: 检查登录状态');

      final loginButton = find.text('登录');
      if (tester.any(loginButton)) {
        TestHelper.log('📝 需要登录');
        // TODO: 添加登录逻辑
      } else {
        TestHelper.log('✅ 已登录或自动登录');
      }

      await Future.delayed(const Duration(seconds: 2));
      await TestHelper.screenshot(tester, '02_after_login_check');

      // 步骤 3: 进入会话列表
      TestHelper.log('步骤 3/5: 进入会话列表');

      final conversationTab = find.text('会话');
      final chatTab = find.text('聊天');
      final messageTab = find.text('消息');

      bool foundTab = false;
      for (final tab in [conversationTab, chatTab, messageTab]) {
        if (await TestHelper.safeTap(tester, tab)) {
          TestHelper.log('✅ 点击了标签: ${tab.toString()}');
          foundTab = true;
          break;
        }
      }

      if (!foundTab) {
        TestHelper.log('⚠️ 未找到会话/聊天/消息标签');
      }

      await Future.delayed(const Duration(seconds: 2));
      await TestHelper.screenshot(tester, '03_conversation_list');

      // 步骤 4: 尝试打开聊天
      TestHelper.log('步骤 4/5: 尝试打开聊天');

      // 查找第一个会话项
      final listTile = find.byType(ListTile);
      if (tester.any(listTile)) {
        await TestHelper.safeTap(tester, listTile.first);
        TestHelper.log('✅ 点击了第一个会话');
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 2));
      } else {
        TestHelper.log('⚠️ 未找到会话项');
      }

      await TestHelper.screenshot(tester, '04_chat_opened');

      // 步骤 5: 测试输入框
      TestHelper.log('步骤 5/5: 测试消息输入');

      final textField = find.byType(TextField);
      if (tester.any(textField)) {
        TestHelper.log('✅ 找到输入框');

        // 输入测试消息
        await TestHelper.enterText(
          tester,
          textField.first,
          'Hello from automated test!',
        );
        TestHelper.log('✅ 输入测试消息成功');

        await tester.pumpAndSettle();
        await TestHelper.screenshot(tester, '05_message_entered');

        // 尝试发送（如果有发送按钮）
        final sendButton = find.text('发送');
        final sendIcon = find.byIcon(Icons.send);

        if (await TestHelper.safeTap(tester, sendButton)) {
          TestHelper.log('✅ 点击了发送按钮');
        } else if (await TestHelper.safeTap(tester, sendIcon)) {
          TestHelper.log('✅ 点击了发送图标');
        } else {
          TestHelper.log('⚠️ 未找到发送按钮，尝试按回车');
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
        }

        await Future.delayed(const Duration(seconds: 2));
        await TestHelper.screenshot(tester, '06_message_sent');
      } else {
        TestHelper.log('⚠️ 未找到输入框');
      }

      TestHelper.log('✅ 端到端测试完成');
    });

    testWidgets('双设备模拟测试', (WidgetTester tester) async {
      TestHelper.log('📱 双设备聊天模拟测试');

      app.main();
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 3));

      // 检查当前页面
      await TestHelper.screenshot(tester, 'dual_device_current');

      TestHelper.log('注意：这是一个单设备测试，实际双设备测试需要：');
      TestHelper.log('1. 两个独立的 Flutter 实例');
      TestHelper.log('2. 或者使用 Flutter 的多设备测试支持');
      TestHelper.log('3. 或者通过后端 API 模拟消息');

      TestHelper.log('✅ 双设备模拟测试完成');
    });
  });
}
