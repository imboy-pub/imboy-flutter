/// 意图解析器 - 将用户需求转换为测试用例
library;

import 'dart:convert';
import '../core/ai_client.dart';
import 'prompts.dart' show Prompts;

/// 解析异常
class ParseException implements Exception {
  final String message;
  ParseException(this.message);

  @override
  String toString() => 'ParseException: $message';
}

/// 测试步骤
class TestStep {
  final String action;
  final String expected;

  TestStep({required this.action, required this.expected});

  factory TestStep.fromJson(Map<String, dynamic> json) {
    return TestStep(
      action: json['action'] as String? ?? '',
      expected: json['expected'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'action': action, 'expected': expected};
  }

  @override
  String toString() => 'TestStep(action: $action, expected: $expected)';
}

/// 生成的测试用例
class GeneratedTestCase {
  final String name;
  final String description;
  final String type;
  final String priority;
  final List<String> preconditions;
  final List<TestStep> steps;
  final Map<String, dynamic> testData;

  GeneratedTestCase({
    required this.name,
    required this.description,
    required this.type,
    required this.priority,
    required this.preconditions,
    required this.steps,
    required this.testData,
  });

  factory GeneratedTestCase.fromJson(Map<String, dynamic> json) {
    return GeneratedTestCase(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      type: json['type'] as String? ?? 'normal',
      priority: json['priority'] as String? ?? 'medium',
      preconditions: (json['preconditions'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      steps: (json['steps'] as List?)
              ?.map((e) => TestStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      testData: json['test_data'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'type': type,
      'priority': priority,
      'preconditions': preconditions,
      'steps': steps.map((s) => s.toJson()).toList(),
      'test_data': testData,
    };
  }

  @override
  String toString() =>
      'GeneratedTestCase(name: $name, type: $type, priority: $priority, steps: ${steps.length})';
}

/// 意图解析器 - 将用户需求转换为测试用例
class IntentParser {
  final AIClient _aiClient;

  IntentParser({AIClient? aiClient}) : _aiClient = aiClient ?? AIClient();

  /// 从用户故事生成测试用例
  Future<List<GeneratedTestCase>> parseFromUserStory(String userStory) async {
    // 如果没有 API Key，直接返回模拟数据
    if (!_aiClient.hasApiKey) {
      return _getMockTestCases();
    }

    final prompt = Prompts.generateTestsFromUserStory(userStory);

    try {
      // 调用 AI 生成
      final response = await _aiClient.callLLM(
        prompt,
        systemPrompt: '你是一位专业的测试工程师。',
      );

      // 解析响应
      return _parseTestCasesResponse(response);
    } catch (e) {
      throw ParseException('解析测试用例失败: $e');
    }
  }

  /// 获取模拟测试用例
  List<GeneratedTestCase> _getMockTestCases() {
    return [
      GeneratedTestCase(
        name: '用户发送文本消息',
        description: '验证用户可以成功发送文本消息给好友',
        type: 'normal',
        priority: 'high',
        preconditions: ['用户已登录', '已有好友会话'],
        steps: [
          TestStep(action: '点击会话列表中的好友', expected: '进入聊天页面'),
          TestStep(action: '在输入框输入文本', expected: '文本显示在输入框'),
          TestStep(action: '点击发送按钮', expected: '消息出现在聊天列表'),
        ],
        testData: {'message': '测试消息'},
      ),
      GeneratedTestCase(
        name: '发送空消息验证',
        description: '验证发送空消息时的处理',
        type: 'edge',
        priority: 'medium',
        preconditions: ['用户已登录', '在聊天页面'],
        steps: [
          TestStep(action: '不输入任何内容', expected: '输入框为空'),
          TestStep(action: '点击发送按钮', expected: '发送按钮禁用或提示输入内容'),
        ],
        testData: {'message': ''},
      ),
    ];
  }

  /// 解析测试用例响应
  List<GeneratedTestCase> _parseTestCasesResponse(String response) {
    // 提取 JSON（处理可能的 Markdown 代码块）
    String jsonStr = response.trim();
    if (jsonStr.startsWith('```')) {
      final lines = jsonStr.split('\n');
      jsonStr = lines
          .skipWhile((l) => !l.startsWith('```json'))
          .skip(1)
          .takeWhile((l) => !l.startsWith('```'))
          .join('\n');
    }

    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    final testCasesList = json['test_cases'] as List?;

    if (testCasesList == null || testCasesList.isEmpty) {
      throw ParseException('未找到测试用例');
    }

    return testCasesList
        .map((tc) => GeneratedTestCase.fromJson(tc as Map<String, dynamic>))
        .toList();
  }

  /// 从 API 文档生成测试用例
  Future<List<GeneratedTestCase>> parseFromApiDoc(String apiDoc) async {
    final prompt = Prompts.generateTestsFromApiDoc(apiDoc);

    try {
      final response = await _aiClient.callLLM(
        prompt,
        systemPrompt: '你是一位资深的 API 测试工程师。',
      );

      return _parseTestCasesResponse(response);
    } catch (e) {
      throw ParseException('从 API 文档生成测试失败: $e');
    }
  }

  /// 从 UI 截图生成测试用例
  Future<List<GeneratedTestCase>> parseFromScreenshot(String imagePath) async {
    // TODO: 使用视觉模型分析 UI
    // 目前返回一些基础的 UI 测试用例
    return [
      GeneratedTestCase(
        name: 'UI 响应式布局测试',
        description: '验证 UI 在不同屏幕尺寸下的响应式表现',
        type: 'normal',
        priority: 'high',
        preconditions: ['应用已启动'],
        steps: [
          TestStep(action: '调整窗口大小', expected: 'UI 自适应调整'),
          TestStep(action: '检查关键元素可见性', expected: '所有重要元素都可见'),
        ],
        testData: {'window_sizes': ['small', 'medium', 'large']},
      ),
    ];
  }

  /// 优化现有测试用例
  Future<List<GeneratedTestCase>> optimizeTests(
    List<GeneratedTestCase> existingTests, {
    String? testGoals,
  }) async {
    if (!_aiClient.hasApiKey) {
      // 无 API Key 时返回原测试
      return existingTests;
    }

    // 将现有测试序列化为 JSON
    final testsJson = jsonEncode({
      'existing_tests': existingTests.map((t) => t.toJson()).toList(),
      'test_goals': testGoals ?? '提高测试覆盖率和质量',
    });

    final prompt = Prompts.optimizeTests(testsJson, testGoals ?? '');

    try {
      final response = await _aiClient.callLLM(
        prompt,
        systemPrompt: '你是一位资深的测试架构师。',
      );

      final json = jsonDecode(response) as Map<String, dynamic>;
      final optimizedTests = json['optimized_tests'] as List?;

      if (optimizedTests != null) {
        return optimizedTests
            .map((tc) => GeneratedTestCase.fromJson(tc as Map<String, dynamic>))
            .toList();
      }

      return existingTests;
    } catch (e) {
      // 解析失败时返回原测试
      return existingTests;
    }
  }

  /// 批量生成测试用例
  Future<List<GeneratedTestCase>> generateBatch(
    List<String> userStories,
  ) async {
    final allTests = <GeneratedTestCase>[];

    for (final story in userStories) {
      try {
        final tests = await parseFromUserStory(story);
        allTests.addAll(tests);
      } catch (e) {
        // 记录错误但继续处理其他故事
        print('⚠️ 生成测试失败，跳过: $story');
      }
    }

    return allTests;
  }

  /// 导出测试用例为 JSON
  String exportToJson(List<GeneratedTestCase> tests) {
    final json = {
      'test_cases': tests.map((t) => t.toJson()).toList(),
      'generated_at': DateTime.now().toIso8601String(),
      'total_count': tests.length,
    };
    return const JsonEncoder.withIndent('  ').convert(json);
  }

  /// 从 JSON 导入测试用例
  static List<GeneratedTestCase> importFromJson(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    final testCasesList = json['test_cases'] as List?;
    if (testCasesList == null) {
      throw ParseException('无效的 JSON 格式');
    }
    return testCasesList
        .map((tc) => GeneratedTestCase.fromJson(tc as Map<String, dynamic>))
        .toList();
  }
}
