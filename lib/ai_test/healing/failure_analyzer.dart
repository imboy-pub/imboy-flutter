/// 测试失败分析器
library;

import 'healing_strategy.dart';
import '../core/ai_client.dart';
import '../intent/prompts.dart';

/// 失败类型
enum FailureType {
  /// 元素未找到
  elementNotFound,

  /// 超时
  timeout,

  /// 断言失败
  assertionFailure,

  /// 网络错误
  networkError,

  /// 权限错误
  permissionError,

  /// 选择器失效
  selectorInvalid,

  /// 状态不匹配
  stateMismatch,

  /// 未知错误
  unknown,
}

/// 失败详情
class FailureDetails {
  /// 失败类型
  final FailureType type;

  /// 错误消息
  final String errorMessage;

  /// 堆栈跟踪
  final String? stackTrace;

  /// 发生失败的步骤
  final String? failingStep;

  /// 相关选择器（如果有）
  final String? selector;

  /// 期望值
  final String? expectedValue;

  /// 实际值
  final String? actualValue;

  /// 超时时间（毫秒）
  final int? timeout;

  /// 失败上下文
  final Map<String, dynamic> context;

  const FailureDetails({
    required this.type,
    required this.errorMessage,
    this.stackTrace,
    this.failingStep,
    this.selector,
    this.expectedValue,
    this.actualValue,
    this.timeout,
    this.context = const {},
  });

  /// 从异常创建失败详情
  factory FailureDetails.fromException(
    dynamic exception,
    StackTrace stackTrace, {
    String? failingStep,
    Map<String, dynamic> context = const {},
  }) {
    final errorMessage = exception.toString();
    FailureType type = FailureType.unknown;

    // 分析错误类型
    if (errorMessage.contains('element not found') ||
        errorMessage.contains('Unable to find element')) {
      type = FailureType.elementNotFound;
    } else if (errorMessage.contains('timeout') ||
        errorMessage.contains('Timed out')) {
      type = FailureType.timeout;
    } else if (errorMessage.contains('assertion') ||
        errorMessage.contains('Expected:') ||
        errorMessage.contains('Expected:')) {
      type = FailureType.assertionFailure;
    } else if (errorMessage.contains('network') ||
        errorMessage.contains('SocketException') ||
        errorMessage.contains('HttpException')) {
      type = FailureType.networkError;
    } else if (errorMessage.contains('permission') ||
        errorMessage.contains('Permission denied')) {
      type = FailureType.permissionError;
    } else if (errorMessage.contains('selector') ||
        errorMessage.contains('Invalid selector')) {
      type = FailureType.selectorInvalid;
    } else if (errorMessage.contains('state') ||
        errorMessage.contains('State mismatch')) {
      type = FailureType.stateMismatch;
    }

    // 提取选择器信息
    String? selector;
    final selectorMatch = RegExp(r"selector[:\s]+'([^']+)'").firstMatch(errorMessage);
    if (selectorMatch != null) {
      selector = selectorMatch.group(1);
    }

    return FailureDetails(
      type: type,
      errorMessage: errorMessage,
      stackTrace: stackTrace.toString(),
      failingStep: failingStep,
      selector: selector,
      context: context,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'errorMessage': errorMessage,
      'stackTrace': stackTrace,
      'failingStep': failingStep,
      'selector': selector,
      'expectedValue': expectedValue,
      'actualValue': actualValue,
      'timeout': timeout,
      'context': context,
    };
  }

  @override
  String toString() =>
      'FailureDetails($type: ${errorMessage.substring(0, errorMessage.length > 50 ? 50 : errorMessage.length)}...)';
}

/// 分析结果
class AnalysisResult {
  /// 失败详情
  final FailureDetails failure;

  /// 推荐的愈合策略
  final List<HealingStrategy> strategies;

  /// 置信度 (0.0 - 1.0)
  final double confidence;

  /// 分析说明
  final String explanation;

  /// 是否需要人工干预
  final bool requiresHumanIntervention;

  /// 预计修复时间（毫秒）
  final int? estimatedFixTime;

  const AnalysisResult({
    required this.failure,
    required this.strategies,
    required this.confidence,
    required this.explanation,
    this.requiresHumanIntervention = false,
    this.estimatedFixTime,
  });

  /// 获取最佳策略
  HealingStrategy get bestStrategy {
    if (strategies.isEmpty) {
      return const HealingStrategy.skip();
    }
    // 返回优先级最高的策略
    return strategies.reduce((a, b) {
      final aPriority = a.priority.index;
      final bPriority = b.priority.index;
      return aPriority > bPriority ? a : b;
    });
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'failure': failure.toJson(),
      'strategies': strategies.map((s) => s.toJson()).toList(),
      'confidence': confidence,
      'explanation': explanation,
      'requiresHumanIntervention': requiresHumanIntervention,
      'estimatedFixTime': estimatedFixTime,
    };
  }

  @override
  String toString() =>
      'AnalysisResult(confidence: ${(confidence * 100).toStringAsFixed(0)}%, '
      'bestStrategy: ${bestStrategy.type}, '
      'requiresHuman: $requiresHumanIntervention)';
}

/// 测试失败分析器
class FailureAnalyzer {
  final AIClient _aiClient;

  FailureAnalyzer({AIClient? aiClient}) : _aiClient = aiClient ?? AIClient();

  /// 暴露 AIClient 供愈合引擎使用
  AIClient get aiClient => _aiClient;

  /// 分析测试失败并生成愈合策略
  Future<AnalysisResult> analyzeFailure(FailureDetails failure) async {
    // 基础策略生成（不依赖 AI）
    final baseStrategies = _generateBaseStrategies(failure);

    // 如果有 API Key，使用 AI 增强分析
    if (_aiClient.hasApiKey) {
      try {
        return await _analyzeWithAi(failure, baseStrategies);
      } catch (e) {
        // AI 分析失败，回退到基础分析
        return _createBaseAnalysisResult(failure, baseStrategies);
      }
    }

    return _createBaseAnalysisResult(failure, baseStrategies);
  }

  /// 生成基础策略（不使用 AI）
  List<HealingStrategy> _generateBaseStrategies(FailureDetails failure) {
    final strategies = <HealingStrategy>[];

    switch (failure.type) {
      case FailureType.elementNotFound:
        strategies.addAll([
          const HealingStrategy.wait(priority: HealingPriority.high),
          const HealingStrategy.selectorUpdate(priority: HealingPriority.high),
          const HealingStrategy.retry(priority: HealingPriority.medium, maxRetries: 2),
        ]);
        break;

      case FailureType.timeout:
        strategies.addAll([
          const HealingStrategy.wait(
            priority: HealingPriority.high,
            retryDelay: 5000,
          ),
          const HealingStrategy.retry(
            priority: HealingPriority.medium,
            maxRetries: 2,
            retryDelay: 3000,
          ),
        ]);
        break;

      case FailureType.assertionFailure:
        strategies.addAll([
          const HealingStrategy.wait(priority: HealingPriority.low),
          const HealingStrategy.aiSuggestion(priority: HealingPriority.high),
        ]);
        break;

      case FailureType.networkError:
        strategies.addAll([
          const HealingStrategy.retry(
            priority: HealingPriority.high,
            maxRetries: 5,
            retryDelay: 2000,
          ),
          const HealingStrategy.fallback(
            priority: HealingPriority.medium,
            description: '使用模拟数据或离线模式',
          ),
        ]);
        break;

      case FailureType.permissionError:
        strategies.addAll([
          const HealingStrategy.fallback(
            priority: HealingPriority.high,
            description: '需要请求用户权限',
          ),
          const HealingStrategy.aiSuggestion(priority: HealingPriority.medium),
        ]);
        break;

      case FailureType.selectorInvalid:
        strategies.addAll([
          const HealingStrategy.selectorUpdate(priority: HealingPriority.critical),
          const HealingStrategy.aiSuggestion(priority: HealingPriority.high),
        ]);
        break;

      case FailureType.stateMismatch:
        strategies.addAll([
          const HealingStrategy.wait(priority: HealingPriority.high),
          const HealingStrategy.retry(priority: HealingPriority.medium),
        ]);
        break;

      case FailureType.unknown:
        strategies.addAll([
          const HealingStrategy.aiSuggestion(priority: HealingPriority.high),
          const HealingStrategy.skip(priority: HealingPriority.low),
        ]);
        break;
    }

    return strategies;
  }

  /// 使用 AI 分析失败
  Future<AnalysisResult> _analyzeWithAi(
    FailureDetails failure,
    List<HealingStrategy> baseStrategies,
  ) async {
    final prompt = Prompts.analyzeFailure(failure);

    try {
      final response = await _aiClient.callLLM(
        prompt,
        systemPrompt: '你是一位资深的测试工程师和调试专家。',
      );

      // 解析 AI 响应并增强基础策略
      return _parseAiAnalysisResponse(failure, response, baseStrategies);
    } catch (e) {
      // AI 调用失败，回退到基础分析
      return _createBaseAnalysisResult(failure, baseStrategies);
    }
  }

  /// 解析 AI 分析响应
  AnalysisResult _parseAiAnalysisResponse(
    FailureDetails failure,
    String response,
    List<HealingStrategy> baseStrategies,
  ) {
    // 这里简化处理，实际应用中需要更复杂的解析
    final confidence = response.toLowerCase().contains('high')
        ? 0.8
        : response.toLowerCase().contains('medium')
            ? 0.6
            : 0.4;

    return AnalysisResult(
      failure: failure,
      strategies: baseStrategies,
      confidence: confidence,
      explanation: 'AI 分析结果：$response',
      requiresHumanIntervention: confidence < 0.5,
      estimatedFixTime: confidence > 0.7 ? 5000 : 15000,
    );
  }

  /// 创建基础分析结果
  AnalysisResult _createBaseAnalysisResult(
    FailureDetails failure,
    List<HealingStrategy> strategies,
  ) {
    // 根据失败类型确定置信度
    double confidence;
    bool requiresHumanIntervention;

    switch (failure.type) {
      case FailureType.elementNotFound:
      case FailureType.timeout:
      case FailureType.stateMismatch:
        confidence = 0.7;
        requiresHumanIntervention = false;
        break;

      case FailureType.selectorInvalid:
        confidence = 0.5;
        requiresHumanIntervention = true;
        break;

      case FailureType.assertionFailure:
      case FailureType.permissionError:
        confidence = 0.4;
        requiresHumanIntervention = true;
        break;

      case FailureType.networkError:
        confidence = 0.8;
        requiresHumanIntervention = false;
        break;

      case FailureType.unknown:
        confidence = 0.2;
        requiresHumanIntervention = true;
        break;
    }

    return AnalysisResult(
      failure: failure,
      strategies: strategies,
      confidence: confidence,
      explanation: _generateExplanation(failure, strategies),
      requiresHumanIntervention: requiresHumanIntervention,
      estimatedFixTime: confidence > 0.6 ? 3000 : 10000,
    );
  }

  /// 生成分析说明
  String _generateExplanation(FailureDetails failure, List<HealingStrategy> strategies) {
    final buffer = StringBuffer();

    buffer.write('检测到 ${_getFailureTypeName(failure.type)}：');
    buffer.write(failure.errorMessage);

    if (strategies.isNotEmpty) {
      buffer.write('\n\n推荐策略：\n');
      for (final strategy in strategies) {
        buffer.write('  - ${strategy.description} (${strategy.priority.name})\n');
      }
    }

    if (failure.selector != null) {
      buffer.write('\n相关选择器：${failure.selector}');
    }

    return buffer.toString();
  }

  /// 获取失败类型名称
  String _getFailureTypeName(FailureType type) {
    switch (type) {
      case FailureType.elementNotFound:
        return '元素未找到';
      case FailureType.timeout:
        return '超时';
      case FailureType.assertionFailure:
        return '断言失败';
      case FailureType.networkError:
        return '网络错误';
      case FailureType.permissionError:
        return '权限错误';
      case FailureType.selectorInvalid:
        return '选择器失效';
      case FailureType.stateMismatch:
        return '状态不匹配';
      case FailureType.unknown:
        return '未知错误';
    }
  }
}
