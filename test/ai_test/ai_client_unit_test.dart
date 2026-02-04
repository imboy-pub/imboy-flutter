/// AI 测试框架单元测试 - 快速验证
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/ai_test/intent/intent_parser.dart';
import 'package:imboy/ai_test/core/ai_client.dart';

void main() {
  group('AI 测试框架 - 单元测试', () {
    group('AIClient - 无 API Key 模式', () {
      test('应该返回模拟测试数据', () async {
        final client = AIClient();

        // 当没有 API Key 时，应该返回模拟数据
        final result = await client.generateTestsFromUserStory('发送消息');

        expect(result, contains('test_cases'));
        expect(result, contains('用户发送文本消息'));
      });

      test('应该返回模拟失败分析', () async {
        final client = AIClient();

        final analysis = await client.analyzeFailure(
          testName: '测试失败',
          errorMessage: '元素未找到',
          stackTrace: 'stack trace here',
        );

        expect(analysis.type, FailureType.selectorHealing);
        expect(analysis.confidence, greaterThan(0));
      });
    });

    group('IntentParser', () {
      test('应该解析用户故事为测试用例', () async {
        final parser = IntentParser();

        final testCases = await parser.parseFromUserStory('''
          作为用户，我想要发送消息给好友
        ''');

        expect(testCases, isNotEmpty);
        expect(testCases.first.name, isNotEmpty);
      });

      test('应该解析 JSON 格式的测试用例', () async {
        final parser = IntentParser();

        final testCases = await parser.parseFromUserStory('dummy story');

        expect(testCases.length, greaterThan(0));
        expect(testCases.first.name, '用户发送文本消息');
        expect(testCases.first.type, 'normal');
      });
    });
  });
}
