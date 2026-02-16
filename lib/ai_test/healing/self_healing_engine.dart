/// 自愈合引擎
library;

// ignore: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'failure_analyzer.dart';
import 'healing_strategy.dart';
import '../core/test_generator.dart';

/// 愈合尝试结果
class HealingAttempt {
  /// 尝试次数
  final int attemptNumber;

  /// 使用的策略
  final HealingStrategy strategy;

  /// 是否成功
  final bool success;

  /// 执行时间（毫秒）
  final int duration;

  /// 错误消息（如果失败）
  final String? error;

  const HealingAttempt({
    required this.attemptNumber,
    required this.strategy,
    required this.success,
    required this.duration,
    this.error,
  });

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'attemptNumber': attemptNumber,
      'strategy': strategy.toJson(),
      'success': success,
      'duration': duration,
      'error': error,
    };
  }

  @override
  String toString() =>
      'Attempt #$attemptNumber: ${strategy.type} -> ${success ? "成功" : "失败"} '
      '(${duration}ms)';
}

/// 愈合会话
class HealingSession {
  /// 会话 ID
  final String id;

  /// 失败详情
  final FailureDetails failure;

  /// 分析结果
  final AnalysisResult analysis;

  /// 愈合尝试历史
  final List<HealingAttempt> attempts;

  /// 开始时间
  final DateTime startTime;

  /// 结束时间
  final DateTime? endTime;

  /// 是否已解决
  bool get isResolved => attempts.any((a) => a.success);

  /// 总耗时（毫秒）
  int get totalDuration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime).inMilliseconds;
  }

  const HealingSession({
    required this.id,
    required this.failure,
    required this.analysis,
    this.attempts = const [],
    required this.startTime,
    this.endTime,
  });

  /// 创建新会话
  factory HealingSession.create({
    required String id,
    required FailureDetails failure,
    required AnalysisResult analysis,
  }) {
    return HealingSession(
      id: id,
      failure: failure,
      analysis: analysis,
      startTime: DateTime.now(),
    );
  }

  /// 添加尝试记录
  HealingSession withAttempt(HealingAttempt attempt) {
    return HealingSession(
      id: id,
      failure: failure,
      analysis: analysis,
      attempts: [...attempts, attempt],
      startTime: startTime,
      endTime: attempt.success ? DateTime.now() : endTime,
    );
  }

  /// 标记为完成
  HealingSession completed() {
    return HealingSession(
      id: id,
      failure: failure,
      analysis: analysis,
      attempts: attempts,
      startTime: startTime,
      endTime: DateTime.now(),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'failure': failure.toJson(),
      'analysis': analysis.toJson(),
      'attempts': attempts.map((a) => a.toJson()).toList(),
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'isResolved': isResolved,
      'totalDuration': totalDuration,
    };
  }

  @override
  String toString() =>
      'HealingSession($id, ${isResolved ? "已解决" : "未解决"}, '
      '${attempts.length} 次尝试, ${totalDuration}ms)';
}

/// 自愈合引擎配置
class SelfHealingConfig {
  /// 最大愈合尝试次数
  final int maxHealingAttempts;

  /// 单次尝试超时时间（毫秒）
  final int attemptTimeout;

  /// 是否启用 AI 分析
  final bool enableAiAnalysis;

  /// 是否自动应用愈合策略
  final bool autoApplyStrategies;

  /// 是否记录详细的愈合日志
  final bool verboseLogging;

  /// 愈合失败时的行为
  final HealingFailureBehavior failureBehavior;

  const SelfHealingConfig({
    this.maxHealingAttempts = 3,
    this.attemptTimeout = 30000,
    this.enableAiAnalysis = true,
    this.autoApplyStrategies = true,
    this.verboseLogging = true,
    this.failureBehavior = HealingFailureBehavior.continueWithWarning,
  });

  /// 默认配置
  static const defaultConfig = SelfHealingConfig();

  /// 快速配置（快速失败）
  static const fastConfig = SelfHealingConfig(
    maxHealingAttempts: 1,
    attemptTimeout: 5000,
    failureBehavior: HealingFailureBehavior.failFast,
  );

  /// 彻底配置（多次尝试）
  static const thoroughConfig = SelfHealingConfig(
    maxHealingAttempts: 5,
    attemptTimeout: 60000,
    failureBehavior: HealingFailureBehavior.retryAll,
  );
}

/// 愈合失败行为
enum HealingFailureBehavior {
  /// 快速失败
  failFast,

  /// 继续执行但记录警告
  continueWithWarning,

  /// 重试所有策略
  retryAll,

  /// 跳过并继续
  skipAndContinue,
}

/// 自愈合引擎
class SelfHealingEngine {
  final FailureAnalyzer _analyzer;
  final SelfHealingConfig _config;
  // ignore: unused_field
  final TestGenerator _testGenerator;
  final Map<String, HealingSession> _activeSessions = {};

  /// 愈合统计
  int _totalHealings = 0;
  int _successfulHealings = 0;
  int _failedHealings = 0;

  SelfHealingEngine({
    FailureAnalyzer? analyzer,
    SelfHealingConfig? config,
    TestGenerator? testGenerator,
  })  : _analyzer = analyzer ?? FailureAnalyzer(),
        _config = config ?? SelfHealingConfig.defaultConfig,
        _testGenerator = testGenerator ?? TestGenerator();

  /// 获取愈合统计
  Map<String, int> get statistics => {
        'total': _totalHealings,
        'successful': _successfulHealings,
        'failed': _failedHealings,
        'successRate': _totalHealings > 0
            ? ((_successfulHealings / _totalHealings) * 100).round()
            : 0,
      };

  /// 处理测试失败并尝试愈合
  Future<HealingSession> handleFailure(
    dynamic exception,
    StackTrace stackTrace, {
    String? failingStep,
    WidgetTester? tester,
    Map<String, dynamic> context = const {},
  }) async {
    // 1. 创建失败详情
    final failure = FailureDetails.fromException(
      exception,
      stackTrace,
      failingStep: failingStep,
      context: context,
    );

    // 2. 分析失败并生成策略
    final analysis = await _analyzer.analyzeFailure(failure);

    // 3. 创建愈合会话
    final sessionId = _generateSessionId();
    var session = HealingSession.create(
      id: sessionId,
      failure: failure,
      analysis: analysis,
    );

    // 4. 执行愈合策略
    if (_config.autoApplyStrategies && !_isHumanInterventionRequired(analysis)) {
      session = await _executeHealingStrategies(session, tester);
    }

    // 5. 更新统计
    _totalHealings++;
    if (session.isResolved) {
      _successfulHealings++;
    } else {
      _failedHealings++;
    }

    // 6. 记录会话
    _activeSessions[sessionId] = session;

    // 7. 记录日志
    if (_config.verboseLogging) {
      _logHealingSession(session);
    }

    return session;
  }

  /// 执行愈合策略
  Future<HealingSession> _executeHealingStrategies(
    HealingSession session,
    WidgetTester? tester,
  ) async {
    final strategies = session.analysis.strategies;
    var currentSession = session;

    for (var i = 0; i < strategies.length && i < _config.maxHealingAttempts; i++) {
      final strategy = strategies[i];
      final attemptNumber = currentSession.attempts.length + 1;

      final stopwatch = Stopwatch()..start();
      String? error;

      try {
        await _applyStrategy(strategy, tester);
        stopwatch.stop();

        // 成功
        currentSession = currentSession.withAttempt(HealingAttempt(
          attemptNumber: attemptNumber,
          strategy: strategy,
          success: true,
          duration: stopwatch.elapsedMilliseconds,
        ));

        break; // 成功后不再尝试其他策略
      } catch (e) {
        stopwatch.stop();
        error = e.toString();

        // 失败，记录尝试
        currentSession = currentSession.withAttempt(HealingAttempt(
          attemptNumber: attemptNumber,
          strategy: strategy,
          success: false,
          duration: stopwatch.elapsedMilliseconds,
          error: error,
        ));

        // 根据配置决定是否继续
        if (_config.failureBehavior == HealingFailureBehavior.failFast) {
          break;
        }
      }
    }

    return currentSession.completed();
  }

  /// 应用愈合策略
  Future<void> _applyStrategy(
    HealingStrategy strategy,
    WidgetTester? tester,
  ) async {
    switch (strategy.type) {
      case HealingStrategyType.wait:
        await Future.delayed(Duration(milliseconds: strategy.retryDelay));
        break;

      case HealingStrategyType.retry:
        // 重试逻辑由外部调用者控制
        break;

      case HealingStrategyType.selectorUpdate:
        if (strategy.requiresAiAnalysis) {
          throw UnimplementedError(
            '选择器更新需要 AI 辅助，请手动处理或实现自动选择器推断',
          );
        }
        break;

      case HealingStrategyType.fallback:
        // 回退策略需要具体场景实现
        break;

      case HealingStrategyType.skip:
        // 跳过策略，不做任何操作
        break;

      case HealingStrategyType.aiSuggestion:
        // AI 建议策略，返回建议供用户参考
        throw UnimplementedError(
          'AI 建议需要人工审查，请查看分析结果',
        );
    }
  }

  /// 检查是否需要人工干预
  bool _isHumanInterventionRequired(AnalysisResult analysis) {
    return analysis.requiresHumanIntervention ||
        _config.failureBehavior == HealingFailureBehavior.failFast;
  }

  /// 生成会话 ID
  String _generateSessionId() {
    return 'healing_${DateTime.now().millisecondsSinceEpoch}_$_totalHealings';
  }

  /// 记录愈合会话日志
  void _logHealingSession(HealingSession session) {
    print('\n${'═' * 70}');
    print('🔧 自愈合会话: ${session.id}');
    print('─' * 70);
    print('失败类型: ${session.failure.type.name}');
    print('错误消息: ${session.failure.errorMessage}');
    print('置信度: ${(session.analysis.confidence * 100).toStringAsFixed(0)}%');
    print('策略数量: ${session.analysis.strategies.length}');
    print('尝试次数: ${session.attempts.length}');
    print('结果: ${session.isResolved ? "✅ 已解决" : "❌ 未解决"}');
    print('耗时: ${session.totalDuration}ms');

    if (session.attempts.isNotEmpty) {
      print('\n尝试历史:');
      for (final attempt in session.attempts) {
        print('  $attempt');
      }
    }

    if (!session.isResolved && session.analysis.requiresHumanIntervention) {
      print('\n⚠️  此失败需要人工干预');
      print('建议: ${session.analysis.explanation}');
    }

    print('${'═' * 70}\n');
  }

  /// 获取愈合会话
  HealingSession? getSession(String sessionId) {
    return _activeSessions[sessionId];
  }

  /// 获取所有活动会话
  List<HealingSession> getActiveSessions() {
    return _activeSessions.values.toList();
  }

  /// 清理已完成的会话
  void cleanupCompletedSessions() {
    _activeSessions.removeWhere((key, session) => session.isResolved);
  }

  /// 生成愈合报告
  Map<String, dynamic> generateReport() {
    return {
      'statistics': statistics,
      'activeSessions': _activeSessions.length,
      'config': {
        'maxAttempts': _config.maxHealingAttempts,
        'attemptTimeout': _config.attemptTimeout,
        'enableAiAnalysis': _config.enableAiAnalysis,
        'autoApplyStrategies': _config.autoApplyStrategies,
      },
      'recentSessions': getActiveSessions().take(10).map((s) => s.toJson()).toList(),
    };
  }

  /// 打印统计信息
  void printStatistics() {
    final stats = statistics;
    print('\n📊 自愈合统计');
    print('━' * 40);
    print('  总次数: ${stats['total']}');
    print('  成功次数: ${stats['successful']}');
    print('  失败次数: ${stats['failed']}');
    print('  成功率: ${stats['successRate']}%');
    print('━' * 40);
  }
}
