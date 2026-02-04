/// AI 测试编排器 - 统一的测试执行引擎
library;

import 'dart:async';
import 'dart:io';

import '../intent/intent_parser.dart';
import '../healing/self_healing_engine.dart';
import '../knowledge/knowledge_base.dart';
import '../path_exploration/path_explorer.dart';
import '../path_exploration/test_path.dart';
import '../path_exploration/coverage_tracker.dart';
import '../human_simulation/human_simulator.dart';
import '../human_simulation/session_simulator.dart';
import 'test_execution_result.dart';
import 'performance_monitor.dart';
import 'report_generator.dart';

/// 测试配置
class TestConfiguration {
  /// 是否启用 AI 意图解析
  final bool enableIntentParser;

  /// 是否启用自愈引擎
  final bool enableSelfHealing;

  /// 是否启用知识库
  final bool enableKnowledgeBase;

  /// 是否启用路径探索
  final bool enablePathExplorer;

  /// 是否启用人类模拟
  final bool enableHumanSimulation;

  /// 最大执行时间（秒）
  final int maxExecutionTime;

  /// 并发测试数
  final int concurrency;

  /// 覆盖率目标 (0.0 - 1.0)
  final double coverageGoal;

  /// 是否生成详细报告
  final bool generateDetailedReport;

  /// 报告输出目录
  final String reportOutputDir;

  /// 人类模拟器配置
  final UserBehaviorConfig? humanBehaviorConfig;

  const TestConfiguration({
    this.enableIntentParser = true,
    this.enableSelfHealing = true,
    this.enableKnowledgeBase = true,
    this.enablePathExplorer = true,
    this.enableHumanSimulation = true,
    this.maxExecutionTime = 300,
    this.concurrency = 3,
    this.coverageGoal = 0.8,
    this.generateDetailedReport = true,
    this.reportOutputDir = 'test_reports',
    this.humanBehaviorConfig,
  });

  /// 快速配置（仅核心功能）
  static const quick = TestConfiguration(
    enablePathExplorer: false,
    enableHumanSimulation: false,
    generateDetailedReport: false,
    maxExecutionTime: 60,
  );

  /// 完整配置（所有功能）
  static const full = TestConfiguration(
    enableIntentParser: true,
    enableSelfHealing: true,
    enableKnowledgeBase: true,
    enablePathExplorer: true,
    enableHumanSimulation: true,
    maxExecutionTime: 600,
    concurrency: 5,
    coverageGoal: 0.9,
  );
}

/// 测试任务
class TestTask {
  /// 任务 ID
  final String id;

  /// 任务描述
  final String description;

  /// 意图（自然语言描述）
  final String intent;

  /// 优先级 (0.0 - 1.0)
  final double priority;

  /// 超时时间（秒）
  final int timeout;

  /// 标签
  final List<String> tags;

  /// 元数据
  final Map<String, dynamic> metadata;

  const TestTask({
    required this.id,
    required this.description,
    required this.intent,
    this.priority = 0.5,
    this.timeout = 60,
    this.tags = const [],
    this.metadata = const {},
  });

  @override
  String toString() => 'TestTask($id, $description)';
}

/// AI 测试编排器
class AITestOrchestrator {
  final TestConfiguration _config;
  final PerformanceMonitor _monitor;

  late final IntentParser _intentParser;
  late final SelfHealingEngine _healingEngine;
  late final KnowledgeBase _knowledgeBase;
  late final PathExplorer _pathExplorer;
  late final HumanSimulator _humanSimulator;
  late final UserSessionSimulator _sessionSimulator;

  /// 执行历史
  final List<TestExecutionResult> _executionHistory = [];

  AITestOrchestrator({
    TestConfiguration? config,
    PerformanceMonitor? monitor,
  })  : _config = config ?? const TestConfiguration(),
        _monitor = monitor ?? PerformanceMonitor() {
    _initializeComponents();
  }

  /// 初始化组件
  void _initializeComponents() {
    _intentParser = IntentParser();
    _healingEngine = SelfHealingEngine();
    _knowledgeBase = KnowledgeBase();
    _pathExplorer = PathExplorer(
      coverageTracker: CoverageTracker(),
    );
    _humanSimulator = HumanSimulator(
      config: _config.humanBehaviorConfig ?? UserBehaviorConfig.normalUser,
    );
    _sessionSimulator = UserSessionSimulator(simulator: _humanSimulator);
  }

  /// 执行单个测试任务
  Future<TestExecutionResult> executeTask(TestTask task) async {
    final startTime = DateTime.now();
    _monitor.startOperation('task_${task.id}');

    final result = TestExecutionResult(
      taskId: task.id,
      taskDescription: task.description,
      intent: task.intent,
      startedAt: startTime,
    );

    try {
      // 1. 解析意图
      if (_config.enableIntentParser) {
        _monitor.startOperation('intent_parsing');
        try {
          final testCases = await _intentParser.parseFromUserStory(
            task.intent,
          );
          result.parsedIntent = {
            'testCases': testCases.map((tc) => tc.toJson()).toList(),
            'parsed': true,
          };
        } catch (e) {
          result.parsedIntent = {
            'error': e.toString(),
            'parsed': false,
          };
        }
        _monitor.endOperation('intent_parsing');

        // 从知识库获取相关信息
        if (_config.enableKnowledgeBase) {
          _monitor.startOperation('knowledge_lookup');
          final context = _knowledgeBase.query(
            testName: task.description,
            maxResults: 3,
          );
          result.knowledgeContext = context.toJson();
          _monitor.endOperation('knowledge_lookup');
        }
      }

      // 2. 探索测试路径
      if (_config.enablePathExplorer) {
        _monitor.startOperation('path_exploration');
        final explorationResult = _pathExplorer.explore(
          startingPoint: task.id,
          context: {'task': task.description},
        );
        result.exploredPaths = explorationResult.paths;
        // 将 Map 转换为 ExplorationCoverageInfo
        result.coverageInfo = _convertToCoverageInfo(explorationResult.coverageInfo);
        _monitor.endOperation('path_exploration');
      }

      // 3. 使用人类模拟执行测试
      if (_config.enableHumanSimulation) {
        _monitor.startOperation('human_simulation');
        final scenario = _sessionSimulator.generateRandomScenario();
        final sessionResult = await _sessionSimulator.runScenario(scenario);
        result.simulationResult = sessionResult;
        _monitor.endOperation('human_simulation');
      }

      result.status = TestExecutionStatus.completed;

    } catch (e, stackTrace) {
      result.status = TestExecutionStatus.failed;
      result.errors.add(TestError(
        type: TestErrorType.execution,
        message: e.toString(),
        stackTrace: stackTrace.toString(),
      ));
    }

    final endTime = DateTime.now();
    result.completedAt = endTime;
    result.duration = endTime.difference(startTime);
    result.performanceMetrics = _monitor.getMetrics();

    _executionHistory.add(result);
    _monitor.endOperation('task_${task.id}');

    return result;
  }

  /// 将 Map 转换为 ExplorationCoverageInfo
  ExplorationCoverageInfo _convertToCoverageInfo(Map<String, dynamic> map) {
    return ExplorationCoverageInfo(
      totalNodes: map['totalElements'] as int? ?? 0,
      exploredNodes: map['coveredElements'] as int? ?? 0,
      coverageRate: (map['coveragePercent'] as num? ?? 0) / 100,
    );
  }

  /// 批量执行测试任务
  Future<List<TestExecutionResult>> executeTasks(List<TestTask> tasks) async {
    final results = <TestExecutionResult>[];
    final queue = List<TestTask>.from(tasks)..sort((a, b) => b.priority.compareTo(a.priority));

    // 并发执行
    final futures = <Future<TestExecutionResult>>[];
    for (var i = 0; i < queue.length && i < _config.concurrency; i++) {
      final task = queue.removeAt(0);
      futures.add(executeTask(task));
    }

    // 等待所有任务完成
    final batchResults = await Future.wait(futures);
    results.addAll(batchResults);

    // 继续执行剩余任务
    while (queue.isNotEmpty) {
      final task = queue.removeAt(0);
      final result = await executeTask(task);
      results.add(result);
    }

    return results;
  }

  /// 生成测试报告
  Future<TestReport> generateReport({
    List<TestExecutionResult>? results,
    bool includeDetails = true,
  }) async {
    final executionResults = results ?? _executionHistory;
    final generator = ReportGenerator();

    if (includeDetails) {
      return generator.generateDetailedReport(executionResults);
    } else {
      return generator.generateSummaryReport(executionResults);
    }
  }

  /// 获取执行历史
  List<TestExecutionResult> get executionHistory =>
      List.unmodifiable(_executionHistory);

  /// 清空历史
  void clearHistory() {
    _executionHistory.clear();
  }

  /// 获取配置
  TestConfiguration get config => _config;

  /// 获取性能监控
  PerformanceMonitor get monitor => _monitor;

  /// 获取知识库
  KnowledgeBase get knowledgeBase => _knowledgeBase;

  /// 导出测试报告到文件
  Future<File> exportReport(
    TestReport report, {
    String? outputPath,
    ReportFormat format = ReportFormat.json,
  }) async {
    final generator = ReportGenerator();
    final path = outputPath ??
        '${_config.reportOutputDir}/report_${DateTime.now().millisecondsSinceEpoch}';

    return generator.exportToFile(report, path, format);
  }

  /// 获取统计摘要
  Map<String, dynamic> getStatistics() {
    if (_executionHistory.isEmpty) {
      return {
        'totalTests': 0,
        'successRate': 0.0,
        'averageDuration': 0,
      };
    }

    final completed = _executionHistory.where((r) => r.isSuccess).length;
    final failed = _executionHistory.where((r) => r.isFailure).length;
    final totalDuration = _executionHistory.fold<Duration>(
      Duration.zero,
      (sum, r) => sum + r.duration,
    );

    return {
      'totalTests': _executionHistory.length,
      'completed': completed,
      'failed': failed,
      'successRate': completed / _executionHistory.length,
      'averageDuration': totalDuration.inMilliseconds ~/ _executionHistory.length,
      'totalDuration': totalDuration.inSeconds,
    };
  }

  /// 智能测试建议
  List<String> getSuggestions() {
    final suggestions = <String>[];

    final stats = getStatistics();

    // 成功率建议
    final successRate = stats['successRate'] as double;
    if (successRate < 0.5) {
      suggestions.add(
        '成功率低于 50%，需要立即检查测试环境和被测应用',
      );
    } else if (successRate < 0.8) {
      suggestions.add(
        '成功率低于 80%，建议修复失败的测试用例',
      );
    } else if (successRate < 0.95) {
      suggestions.add(
        '成功率 ${(successRate * 100).toStringAsFixed(0)}%，有几条测试偶尔失败，建议检查不稳定性',
      );
    }

    // 性能建议
    final avgDuration = stats['averageDuration'] as int?;
    if (avgDuration != null && avgDuration > 5000) {
      suggestions.add(
        '平均测试耗时 ${avgDuration}ms，建议优化测试性能或调整并发数',
      );
    }

    // 失败测试建议
    final failed = stats['failed'] as int?;
    if (failed != null && failed > 0) {
      suggestions.add(
        '有 $failed 个测试失败，需要关注并修复',
      );
    }

    return suggestions;
  }

  /// 释放资源
  Future<void> dispose() async {
    _monitor.dispose();
  }
}
