/// AI 客户端 - 封装 LLM API 调用
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

/// AI 客户端异常
class AIClientException implements Exception {
  final String message;
  final int? statusCode;

  AIClientException(this.message, {this.statusCode});

  @override
  String toString() => 'AIClientException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}

/// 失败类型枚举
enum FailureType {
  /// 选择器失效
  selectorHealing,
  /// 超时
  timeout,
  /// 数据错误
  dataError,
  /// 逻辑错误
  logicError,
  /// 网络错误
  networkError,
  /// 其他
  other,
}

/// 测试失败分析结果
class TestFailureAnalysis {
  /// 失败类型
  final FailureType type;
  /// 根本原因描述
  final String rootCause;
  /// 推荐修复方案
  final String recommendedFix;
  /// 置信度 (0-1)
  final double confidence;

  TestFailureAnalysis({
    required this.type,
    required this.rootCause,
    required this.recommendedFix,
    required this.confidence,
  });

  @override
  String toString() =>
      'TestFailureAnalysis(type: $type, cause: $rootCause, fix: $recommendedFix, confidence: ${confidence.toStringAsFixed(2)})';
}

/// AI 客户端 - 封装 LLM 调用
class AIClient {
  final Dio _dio;
  final String _apiKey;
  final String _baseUrl;

  AIClient({String? apiKey, String? baseUrl})
      : _apiKey = apiKey ?? '',
        _baseUrl = baseUrl ?? 'https://api.openai.com/v1',
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 30),
        )) {
    // 配置 Dio
    if (_apiKey.isNotEmpty) {
      _dio.options.headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      };
    }
  }

  /// 从环境创建
  factory AIClient.fromEnv() {
    // 从环境变量读取
    final apiKey = const String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');
    return AIClient(apiKey: apiKey);
  }

  /// 检查是否有可用的 API Key
  bool get hasApiKey => _apiKey.isNotEmpty;

  /// 从用户故事生成测试用例
  Future<String> generateTestsFromUserStory(String userStory) async {
    if (_apiKey.isEmpty) {
      // 返回模拟数据用于测试
      return _getMockTestCases(userStory);
    }

    final prompt = '''
你是一个专业的测试工程师。请分析以下用户故事，生成全面的测试用例。

用户故事：
$userStory

请生成以下类型的测试用例：
1. 正常路径测试（Happy Path）
2. 边缘情况测试（Edge Cases）
3. 异常处理测试（Error Handling）

输出格式要求 JSON：
{
  "test_cases": [
    {
      "name": "测试名称",
      "description": "测试描述",
      "type": "normal|edge|error",
      "priority": "high|medium|low",
      "preconditions": ["前置条件1", "前置条件2"],
      "steps": [
        {"action": "操作描述", "expected": "预期结果"}
      ],
      "test_data": {"key": "value"}
    }
  ]
}

只输出 JSON，不要其他内容。
''';

    try {
      final response = await _dio.post(
        '$_baseUrl/chat/completions',
        data: {
          'model': 'gpt-4o-mini', // 使用性价比高的模型
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.7,
        },
      );

      final content = response.data['choices'][0]['message']['content'] as String;
      return content;
    } on DioException catch (e) {
      throw AIClientException(
        '调用 LLM API 失败: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw AIClientException('生成测试用例失败: $e');
    }
  }

  /// 通用 LLM 调用方法
  /// 调用视觉模型分析截图（支持 GPT-4V 兼容 API）
  ///
  /// 将图片 base64 编码后作为多模态消息发送，适用于 UI 截图解析
  ///
  /// [imagePath] 本地图片文件路径
  /// [prompt] 分析指令
  /// [systemPrompt] 可选系统提示
  Future<String> callVisionModel(
    String imagePath,
    String prompt, {
    String? systemPrompt,
    String model = 'gpt-4o-mini',
  }) async {
    if (_apiKey.isEmpty) {
      throw AIClientException('无 API Key，无法调用视觉模型');
    }

    final file = File(imagePath);
    if (!file.existsSync()) {
      throw AIClientException('图片文件不存在: $imagePath');
    }

    final imageBytes = await file.readAsBytes();
    final imageBase64 = base64Encode(imageBytes);

    // 根据扩展名确定 MIME 类型
    final ext = imagePath.split('.').last.toLowerCase();
    final mimeType = switch (ext) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/png',
    };

    final messages = <Map<String, dynamic>>[];
    if (systemPrompt != null) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({
      'role': 'user',
      'content': [
        {
          'type': 'image_url',
          'image_url': {'url': 'data:$mimeType;base64,$imageBase64'},
        },
        {'type': 'text', 'text': prompt},
      ],
    });

    try {
      final response = await _dio.post(
        '$_baseUrl/chat/completions',
        data: {
          'model': model,
          'messages': messages,
          'max_tokens': 2000,
        },
      );
      return response.data['choices'][0]['message']['content'] as String;
    } catch (e) {
      throw AIClientException('视觉模型调用失败: $e');
    }
  }

  Future<String> callLLM(String prompt, {String? systemPrompt}) async {
    if (_apiKey.isEmpty) {
      throw AIClientException('无 API Key，无法调用 LLM');
    }

    final messages = <Map<String, String>>[];
    if (systemPrompt != null) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': prompt});

    try {
      final response = await _dio.post(
        '$_baseUrl/chat/completions',
        data: {
          'model': 'gpt-4o-mini',
          'messages': messages,
          'temperature': 0.7,
        },
      );

      return response.data['choices'][0]['message']['content'] as String;
    } catch (e) {
      throw AIClientException('LLM 调用失败: $e');
    }
  }

  /// 分析测试失败原因
  Future<TestFailureAnalysis> analyzeFailure({
    required String testName,
    required String errorMessage,
    required String stackTrace,
    String? screenshotPath,
  }) async {
    if (_apiKey.isEmpty) {
      // 返回模拟分析
      return TestFailureAnalysis(
        type: FailureType.selectorHealing,
        rootCause: 'UI 元素选择器失效',
        recommendedFix: '使用更稳定的选择器或 Key',
        confidence: 0.75,
      );
    }

    final prompt = '''
分析以下测试失败信息，提供根本原因分析：

测试名称：$testName
错误信息：$errorMessage
堆栈跟踪：
$stackTrace

请提供：
1. 失败类型（选择器失效/超时/数据错误/逻辑错误/网络错误/其他）
2. 根本原因描述
3. 推荐修复方案

输出 JSON 格式：
{
  "type": "selectorHealing|timeout|dataError|logicError|networkError|other",
  "rootCause": "根本原因描述",
  "recommendedFix": "推荐修复方案",
  "confidence": 0.8
}
''';

    try {
      final response = await _dio.post(
        '$_baseUrl/chat/completions',
        data: {
          'model': 'gpt-4o-mini',
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.3,
        },
      );

      final content = response.data['choices'][0]['message']['content'] as String;

      // 尝试解析 JSON 响应
      try {
        // 提取 JSON 内容（可能包含在 markdown 代码块中）
        String jsonStr = content.trim();
        if (jsonStr.contains('```json')) {
          jsonStr = jsonStr.replaceAll(RegExp(r'```json\s*'), '').replaceAll(RegExp(r'\s*```'), '').trim();
        } else if (jsonStr.contains('```')) {
          jsonStr = jsonStr.replaceAll(RegExp(r'```\s*'), '').replaceAll(RegExp(r'\s*```'), '').trim();
        }

        final json = jsonDecode(jsonStr) as Map<String, dynamic>;

        // 解析失败类型
        FailureType type;
        final typeStr = json['type'] as String? ?? 'other';
        switch (typeStr) {
          case 'selectorHealing':
            type = FailureType.selectorHealing;
            break;
          case 'timeout':
            type = FailureType.timeout;
            break;
          case 'dataError':
            type = FailureType.dataError;
            break;
          case 'logicError':
            type = FailureType.logicError;
            break;
          case 'networkError':
            type = FailureType.networkError;
            break;
          default:
            type = FailureType.other;
        }

        return TestFailureAnalysis(
          type: type,
          rootCause: json['rootCause'] as String? ?? content,
          recommendedFix: json['recommendedFix'] as String? ?? '请参考 AI 分析结果',
          confidence: (json['confidence'] as num?)?.toDouble() ?? 0.8,
        );
      } catch (e) {
        // JSON 解析失败，返回原始内容
        return TestFailureAnalysis(
          type: FailureType.other,
          rootCause: content,
          recommendedFix: '请参考 AI 分析结果',
          confidence: 0.7,
        );
      }
    } catch (e) {
      // 返回默认分析
      return TestFailureAnalysis(
        type: FailureType.other,
        rootCause: '分析失败: $e',
        recommendedFix: '请人工检查',
        confidence: 0.5,
      );
    }
  }

  /// 获取模拟测试用例（用于无 API Key 时测试）
  String _getMockTestCases(String userStory) {
    return '''
{
  "test_cases": [
    {
      "name": "用户发送文本消息",
      "description": "验证用户可以成功发送文本消息给好友",
      "type": "normal",
      "priority": "high",
      "preconditions": ["用户已登录", "已有好友会话"],
      "steps": [
        {"action": "点击会话列表中的好友", "expected": "进入聊天页面"},
        {"action": "在输入框输入文本", "expected": "文本显示在输入框"},
        {"action": "点击发送按钮", "expected": "消息出现在聊天列表"}
      ],
      "test_data": {"message": "测试消息"}
    },
    {
      "name": "发送空消息验证",
      "description": "验证发送空消息时的处理",
      "type": "edge",
      "priority": "medium",
      "preconditions": ["用户已登录", "在聊天页面"],
      "steps": [
        {"action": "不输入任何内容", "expected": "输入框为空"},
        {"action": "点击发送按钮", "expected": "发送按钮禁用或提示输入内容"}
      ],
      "test_data": {"message": ""}
    }
  ]
}
''';
  }
}
