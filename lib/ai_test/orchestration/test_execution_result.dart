/// 测试执行结果数据结构
library;

import '../human_simulation/session_simulator.dart';
import '../path_exploration/test_path.dart';

/// 测试执行状态
enum TestExecutionStatus {
  /// 等待中
  pending,

  /// 执行中
  running,

  /// 已完成
  completed,

  /// 失败
  failed,

  /// 跳过
  skipped,

  /// 超时
  timeout,
}

/// 测试错误类型
enum TestErrorType {
  /// 解析错误
  parsing,

  /// 执行错误
  execution,

  /// 断言错误
  assertion,

  /// 超时错误
  timeout,

  /// 网络错误
  network,

  /// 其他错误
  other,
}

/// 测试错误
class TestError {
  /// 错误类型
  final TestErrorType type;

  /// 错误消息
  final String message;

  /// 错误堆栈
  final String? stackTrace;

  /// 错误代码
  final String? errorCode;

  /// 发生时间
  final DateTime timestamp;

  /// 上下文信息
  final Map<String, dynamic> context;

  /// 是否已修复
  bool isFixed;

  TestError({
    required this.type,
    required this.message,
    this.stackTrace,
    this.errorCode,
    DateTime? timestamp,
    this.context = const {},
    this.isFixed = false,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'message': message,
      'stackTrace': stackTrace,
      'errorCode': errorCode,
      'timestamp': timestamp.toIso8601String(),
      'context': context,
      'isFixed': isFixed,
    };
  }

  @override
  String toString() =>
      'TestError($type, $message${isFixed ? ', 已修复' : ''})';
}

/// 自愈结果
class HealingResult {
  /// 是否成功
  final bool success;

  /// 原始错误
  final TestError originalError;

  /// 修复方案
  final String? solution;

  /// 应用的修复
  final String? appliedFix;

  /// 修复时间
  final Duration healingDuration;

  /// 是否需要人工干预
  final bool needsHumanIntervention;

  /// 置信度 (0.0 - 1.0)
  final double confidence;

  const HealingResult({
    required this.success,
    required this.originalError,
    this.solution,
    this.appliedFix,
    required this.healingDuration,
    this.needsHumanIntervention = false,
    this.confidence = 0.5,
  });

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'originalError': originalError.toJson(),
      'solution': solution,
      'appliedFix': appliedFix,
      'healingDuration': healingDuration.inMilliseconds,
      'needsHumanIntervention': needsHumanIntervention,
      'confidence': confidence,
    };
  }
}

/// 测试执行结果
class TestExecutionResult {
  /// 任务 ID
  final String taskId;

  /// 任务描述
  final String taskDescription;

  /// 原始意图
  final String intent;

  /// 解析后的意图
  Map<String, dynamic>? parsedIntent;

  /// 知识库上下文
  Map<String, dynamic>? knowledgeContext;

  /// 探索的路径
  List<TestPath>? exploredPaths;

  /// 覆盖信息
  ExplorationCoverageInfo? coverageInfo;

  /// 人类模拟结果
  SessionResult? simulationResult;

  /// 自愈结果
  HealingResult? healingResult;

  /// 执行状态
  TestExecutionStatus status;

  /// 错误列表
  final List<TestError> errors;

  /// 开始时间
  final DateTime startedAt;

  /// 完成时间
  DateTime? completedAt;

  /// 执行时长
  Duration duration = Duration.zero;

  /// 性能指标
  Map<String, dynamic>? performanceMetrics;

  /// 元数据
  final Map<String, dynamic> metadata;

  TestExecutionResult({
    required this.taskId,
    required this.taskDescription,
    required this.intent,
    this.parsedIntent,
    this.knowledgeContext,
    this.exploredPaths,
    this.coverageInfo,
    this.simulationResult,
    this.healingResult,
    this.status = TestExecutionStatus.pending,
    List<TestError>? errors,
    required this.startedAt,
    this.completedAt,
    this.duration = Duration.zero,
    this.performanceMetrics,
    this.metadata = const {},
  }) : errors = errors ?? [];

  /// 是否成功
  bool get isSuccess => status == TestExecutionStatus.completed && !hasErrors;

  /// 是否失败
  bool get isFailure => status == TestExecutionStatus.failed || hasErrors;

  /// 是否有错误
  bool get hasErrors => errors.any((e) => !e.isFixed);

  /// 是否超时
  bool get isTimeout => status == TestExecutionStatus.timeout;

  /// 成功率 (0.0 - 1.0)
  double get successRate {
    if (simulationResult == null) return isSuccess ? 1.0 : 0.0;
    return simulationResult!.successRate;
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'taskDescription': taskDescription,
      'intent': intent,
      'parsedIntent': parsedIntent,
      'knowledgeContext': knowledgeContext,
      'exploredPaths': exploredPaths?.map((p) => p.toJson()).toList(),
      'coverageInfo': coverageInfo?.toJson(),
      'simulationResult': simulationResult?.toJson(),
      'healingResult': healingResult?.toJson(),
      'status': status.name,
      'errors': errors.map((e) => e.toJson()).toList(),
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'duration': duration.inMilliseconds,
      'performanceMetrics': performanceMetrics,
      'metadata': metadata,
    };
  }

  Map<String, dynamic> toMap() => toJson();

  @override
  String toString() =>
      'TestExecutionResult($taskId, $status, ${hasErrors ? '有错误' : '无错误'})';
}

/// 探索覆盖信息
class ExplorationCoverageInfo {
  /// 总节点数
  final int totalNodes;

  /// 探索节点数
  final int exploredNodes;

  /// 覆盖率
  final double coverageRate;

  /// 未探索节点
  final List<String> unexploredNodes;

  const ExplorationCoverageInfo({
    required this.totalNodes,
    required this.exploredNodes,
    required this.coverageRate,
    this.unexploredNodes = const [],
  });

  factory ExplorationCoverageInfo.fromJson(Map<String, dynamic> json) {
    return ExplorationCoverageInfo(
      totalNodes: json['totalNodes'] as int,
      exploredNodes: json['exploredNodes'] as int,
      coverageRate: (json['coverageRate'] as num).toDouble(),
      unexploredNodes:
          (json['unexploredNodes'] as List?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalNodes': totalNodes,
      'exploredNodes': exploredNodes,
      'coverageRate': coverageRate,
      'unexploredNodes': unexploredNodes,
    };
  }
}
