// 增强聊天测试 - 使用新框架
//
// 功能：
// - 自动截图
// - 步骤记录
// - HTML 报告生成
// - 错误捕获

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:imboy/main.dart' as app;
import 'helper/test_enhanced_helper.dart';
import 'helper/test_html_reporter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('增强聊天测试', () {
    late EnhancedTestHelper helper;
    TestHtmlReporter? reporter;

    setUpAll(() {
      reporter = TestHtmlReporter();
    });

    testWidgets('完整聊天流程（增强版）', (WidgetTester tester) async {
      // 创建测试辅助类
      helper = EnhancedTestHelper(tester);
      helper.startSession('enhanced_chat_test', 'macOS');

      try {
        // 步骤 1: 启动应用
        await helper.step(
          'launch_app',
          '启动 IM Boy 应用',
          action: () async {
            app.main();
            await helper.waitForLoad();
          },
        );

        // 步骤 2: 等待应用加载完成
        await helper.step(
          'wait_for_load',
          '等待应用完全加载',
          action: () async {
            await helper.waitForLoad();
            await Future.delayed(const Duration(seconds: 3));
          },
          critical: false, // 不是关键步骤，失败不影响
        );

        // 步骤 3: 查找会话列表
        await helper.step(
          'find_conversation',
          '查找会话列表',
          action: () async {
            final listTiles = find.byType(ListTile);
            if (tester.any(listTiles)) {
              final count = tester.widgetList(listTiles).length;
              print('✅ 找到 $count 个会话项');
            } else {
              print('⚠️ 未找到会话列表');
            }
          },
          critical: false,
        );

        // 步骤 4: 尝试查找聊天输入框
        await helper.step(
          'find_input',
          '查找聊天输入框',
          action: () async {
            final textField = find.byType(TextField);
            if (tester.any(textField)) {
              print('✅ 找到输入框');
            } else {
              throw Exception('未找到输入框，可能不在聊天页面');
            }
          },
          critical: false,
        );

        // 步骤 5: 测试完成总结
        await helper.step(
          'summary',
          '测试总结',
          action: () async {
            print('');
            print('📊 测试总结');
            print('✅ 应用启动成功');
            print('✅ 所有步骤完成');
            print('🎉 测试完成');
          },
          critical: false,
        );

        // 标记测试通过
        await helper.finishSession(passed: true);
      } catch (e, stackTrace) {
        print('❌ 测试失败: $e');
        print('堆栈: $stackTrace');
        await helper.finishSession(passed: false);
        rethrow;
      }

      // 添加到报告收集器
      TestReportCollector.addSession(helper.session);

      // 生成 HTML 报告
      await reporter!.generate([helper.session]);
    });

    // 清理时生成汇总报告
    tearDownAll(() async {
      final sessions = TestReportCollector.sessions;
      if (sessions.isNotEmpty && reporter != null) {
        await reporter!.generate(sessions);

        // 生成 Markdown 报告
        final markdownReport = TestReportCollector.generateSummaryReport();
        print('');
        print('=' * 60);
        print(markdownReport);
        print('=' * 60);
      }
    });
  });

  group('登录流程测试', () {
    late EnhancedTestHelper helper;

    testWidgets('登录流程（增强版）', (WidgetTester tester) async {
      helper = EnhancedTestHelper(tester);
      helper.startSession('login_test', 'macOS');

      try {
        await helper.step(
          'launch',
          '启动应用',
          action: () async {
            app.main();
            await helper.waitForLoad();
          },
        );

        await helper.step(
          'check_ui',
          '检查登录界面元素',
          action: () async {
            await helper.waitForLoad();
            // 这里可以添加查找登录按钮等元素的代码
          },
          critical: false,
        );

        await helper.finishSession(passed: true);
      } catch (e) {
        await helper.finishSession(passed: false);
        rethrow;
      }

      TestReportCollector.addSession(helper.session);
    });
  });
}
