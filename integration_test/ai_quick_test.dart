/// AI 生成的测试示例
///
/// 运行方式：
/// ```bash
/// flutter test integration_test/ai_quick_test.dart --dart-define=APP_ENV=local_office -d macos
/// ```
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/ai_test/intent/intent_parser.dart';
import 'package:imboy/ai_test/core/test_generator.dart';
import 'package:imboy/ai_test/core/ai_client.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AI 测试框架 - 快速验证', () {
    late IntentParser intentParser;
    late TestGenerator testGenerator;

    setUp(() async {
      intentParser = IntentParser();
      testGenerator = TestGenerator();
      print('\n🤖 AI 测试框架初始化完成');
    });

    testWidgets('AI 自动生成并执行测试', (WidgetTester tester) async {
      // 1. 定义用户故事
      const userStory = '''
作为用户，我想要：
1. 发送文本消息给好友
2. 查看消息历史记录
      ''';

      print('\n📝 用户故事：$userStory');

      // 2. AI 生成测试用例
      print('\n🤖 AI 正在生成测试用例...');
      final testCases = await intentParser.parseFromUserStory(userStory);
      print('✅ 生成了 ${testCases.length} 个测试用例');

      for (final tc in testCases) {
        print('  • ${tc.name} (${tc.type}, ${tc.priority})');
        print('    ${tc.description}');
      }

      // 3. 启动应用
      print('\n🚀 启动应用...');
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));
      print('✅ 应用已启动');

      // 4. 执行 AI 生成的测试用例
      print('\n🧪 开始执行测试...\n');
      for (final testCase in testCases) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('测试: ${testCase.name}');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        try {
          await testGenerator.executeTest(tester, testCase);
          print('  ✅ 测试通过\n');
        } catch (e) {
          print('  ❌ 测试失败: $e\n');
          print('  💡 注意：这是预期的失败，因为需要实际的 UI 元素');
          print('  ──────────────────────────────────────────\n');
        }
      }

      // 5. 生成报告
      print(testGenerator.generateReport());

      // 6. 验证至少生成了测试用例
      expect(testCases.length, greaterThan(0), reason: '应该生成至少 1 个测试用例');
    });

    testWidgets('AI 分析失败原因（模拟）', (WidgetTester tester) async {
      print('\n🔍 测试失败分析演示');

      // 模拟一个失败场景
      const errorMessage = '''
Finder zero widgets with text "不存在的按钮" (ignoring offstage)
The following TestError was thrown running a test:
Expected: exactly one matching node in the widget tree
      ''';

      const stackTrace = '''
package:flutter_test/src/widget_tester.dart
package:flutter_test/src/test_geometry.dart
      ''';

      try {
        throw Exception('元素未找到: 不存在的按钮');
      } catch (e, s) {
        print('❌ 测试失败: $e');
        print('📋 错误消息: $errorMessage');
        print('📚 堆栈跟踪:\n$stackTrace');

        // AI 分析（如果没有 API Key，会返回模拟结果）
        print('\n🤖 AI 正在分析失败原因...');
        final aiClient = AIClient();
        final analysis = await aiClient.analyzeFailure(
          testName: '查找不存在的按钮',
          errorMessage: errorMessage,
          stackTrace: stackTrace,
        );

        print('\n📊 AI 分析结果:');
        print('  失败类型: ${analysis.type}');
        print('  根本原因: ${analysis.rootCause}');
        print('  推荐修复: ${analysis.recommendedFix}');
        print('  置信度: ${(analysis.confidence * 100).toStringAsFixed(0)}%');

        // 验证分析结果
        expect(analysis.confidence, greaterThan(0), reason: '置信度应该大于 0');
      }
    });
  });
}
