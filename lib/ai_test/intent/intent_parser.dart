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
      return _getMockTestCases(userStory);
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

  /// 获取模拟测试用例（按用户故事关键词生成，保证离线场景下也有领域覆盖）
  List<GeneratedTestCase> _getMockTestCases(String userStory) {
    final story = userStory.toLowerCase();

    if (story.contains('完整流程') || story.contains('综合')) {
      return [
        GeneratedTestCase(
          name: 'E2EE 综合流程主路径',
          description: '覆盖本地备份、设备传输、社交恢复三种密钥恢复路径',
          type: 'normal',
          priority: 'high',
          preconditions: ['用户已登录并启用 E2EE'],
          steps: [
            TestStep(action: '执行本地备份恢复', expected: 'backup 路径成功'),
            TestStep(action: '执行设备传输恢复', expected: 'transfer 路径成功'),
            TestStep(action: '执行社交恢复流程', expected: '社交恢复路径成功'),
          ],
          testData: {'modes': ['backup', 'transfer', 'social_recovery']},
        ),
        GeneratedTestCase(
          name: 'E2EE 综合异常处理',
          description: '覆盖网络异常与错误口令下的恢复失败提示和重试',
          type: 'edge',
          priority: 'medium',
          preconditions: ['存在恢复任务上下文'],
          steps: [
            TestStep(action: '模拟网络中断', expected: '出现友好错误提示'),
            TestStep(action: '输入错误口令后重试', expected: '提示失败并允许重新操作'),
          ],
          testData: {'network': 'offline'},
        ),
      ];
    }

    if (story.contains('设备间传输') || story.contains('transfer')) {
      return [
        GeneratedTestCase(
          name: '设备传输会话创建',
          description: '验证旧设备可创建传输会话并生成二维码用于设备传输',
          type: 'normal',
          priority: 'high',
          preconditions: ['旧设备已登录', '已存在可用密钥'],
          steps: [
            TestStep(action: '进入设备传输页面并创建会话', expected: '显示可扫描二维码'),
            TestStep(action: '新设备扫描二维码', expected: '进入传输确认流程'),
            TestStep(action: '确认传输', expected: '两端显示传输成功'),
          ],
          testData: {'session': 'transfer_session'},
        ),
        GeneratedTestCase(
          name: '设备传输会话过期校验',
          description: '验证传输会话超时过期后无法继续 transfer',
          type: 'edge',
          priority: 'medium',
          preconditions: ['已创建传输会话'],
          steps: [
            TestStep(action: '等待会话超过有效期', expected: '会话状态变为 expired'),
            TestStep(action: '尝试再次接受传输', expected: '提示会话过期并拒绝操作'),
          ],
          testData: {'ttl_minutes': 5},
        ),
      ];
    }

    if (story.contains('社交恢复') && (story.contains('创建') || story.contains('分片'))) {
      return [
        GeneratedTestCase(
          name: '社交恢复分片创建与下发',
          description: '验证使用 Shamir 算法创建分片并通过好友公钥加密下发',
          type: 'normal',
          priority: 'high',
          preconditions: ['用户已启用 E2EE', '至少 3 位可信好友在线'],
          steps: [
            TestStep(action: '选择代理好友并设置阈值', expected: '通过参数校验'),
            TestStep(action: '创建密钥分片', expected: '生成多个 shard'),
            TestStep(action: '加密并发送分片', expected: '分片以公钥加密方式送达'),
          ],
          testData: {'threshold': 2, 'total_shards': 3},
        ),
        GeneratedTestCase(
          name: '社交恢复参数边界校验',
          description: '验证分片数量与恢复阈值不合法时的错误处理',
          type: 'edge',
          priority: 'medium',
          preconditions: ['用户进入社交恢复创建页'],
          steps: [
            TestStep(action: '输入 total <= threshold', expected: '阻止提交并提示参数错误'),
            TestStep(action: '修正参数重新提交', expected: '成功创建分片任务'),
          ],
          testData: {'threshold': 3, 'total_shards': 3},
        ),
      ];
    }

    if (story.contains('社交恢复') && story.contains('恢复密钥')) {
      return [
        GeneratedTestCase(
          name: '社交恢复收集分片并恢复密钥',
          description: '验证收集达到阈值的分片后可重组并恢复密钥',
          type: 'normal',
          priority: 'high',
          preconditions: ['存在可用恢复分片', '代理可响应请求'],
          steps: [
            TestStep(action: '请求代理返回解密分片', expected: '获得可用分片数据'),
            TestStep(action: '收集达到阈值数量', expected: '满足恢复条件'),
            TestStep(action: '执行恢复', expected: '成功重组并导入密钥'),
          ],
          testData: {'required_shards': 2},
        ),
        GeneratedTestCase(
          name: '社交恢复分片不足错误处理',
          description: '验证分片不足或网络异常时给出可恢复错误提示',
          type: 'error',
          priority: 'medium',
          preconditions: ['仅有部分代理在线'],
          steps: [
            TestStep(action: '请求分片但返回不足', expected: '提示缺少分片'),
            TestStep(action: '网络中断重试', expected: '提示网络异常并允许重试'),
          ],
          testData: {'available_shards': 1},
        ),
      ];
    }

    if (story.contains('本地备份') || story.contains('backup')) {
      return [
        GeneratedTestCase(
          name: '本地备份导出并加密',
          description: '验证可导出加密备份文件并设置口令保护',
          type: 'normal',
          priority: 'high',
          preconditions: ['用户已启用 E2EE'],
          steps: [
            TestStep(action: '进入本地备份页面并导出', expected: '生成 .imboy_backup 文件'),
            TestStep(action: '设置备份口令', expected: '备份文件完成加密'),
            TestStep(action: '校验文件元数据', expected: '格式和版本信息正确'),
          ],
          testData: {'file_ext': '.imboy_backup'},
        ),
        GeneratedTestCase(
          name: '本地备份导入错误口令处理',
          description: '验证错误口令导入时阻止恢复并提示重试',
          type: 'edge',
          priority: 'medium',
          preconditions: ['存在备份文件'],
          steps: [
            TestStep(action: '输入错误口令导入', expected: '提示口令错误'),
            TestStep(action: '输入正确口令重试', expected: '恢复成功'),
          ],
          testData: {'password': 'wrong_password'},
        ),
      ];
    }

    // 通用兜底（仍保持可用）
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
  ///
  /// 实现需要：
  /// - 集成视觉模型 API（如 GPT-4V、Gemini Vision）
  /// - 图像 base64 编码
  /// - UI 元素识别和定位
  ///
  /// 当前返回基础 UI 测试用例作为占位实现
  Future<List<GeneratedTestCase>> parseFromScreenshot(String imagePath) async {
    // TODO(视觉模型集成): 使用 GPT-4V 或 Gemini Vision 分析 UI
    // 需要实现：
    // 1. 将图像编码为 base64
    // 2. 调用视觉模型 API (multimodal chat completion)
    // 3. 解析视觉模型返回的 UI 结构
    //
    // 示例实现方向：
    // final imageBase64 = base64Encode(File(imagePath).readAsBytesSync());
    // final response = await _aiClient.callVisionModel(
    //   image: imageBase64,
    //   prompt: '分析这个 UI 界面，识别所有可交互元素并生成测试用例',
    // );
    // return _parseVisionResponse(response);
    //
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
