/// 测试路径 - 表示一个测试执行路径
library;

import 'dart:convert';
import 'dart:math' as math;

/// 测试路径步骤
class TestPathStep {
  /// 步骤 ID
  final String id;

  /// 步骤描述
  final String description;

  /// 目标元素（选择器）
  final String? targetSelector;

  /// 操作类型
  final PathActionType actionType;

  /// 预期结果
  final String? expectedResult;

  /// 超时时间（毫秒）
  final int timeout;

  /// 是否必需步骤
  final bool isRequired;

  /// 步骤权重（用于优先级计算）
  final double weight;

  /// 相关标签
  final List<String> tags;

  /// 额外元数据
  final Map<String, dynamic> metadata;

  const TestPathStep({
    required this.id,
    required this.description,
    this.targetSelector,
    required this.actionType,
    this.expectedResult,
    this.timeout = 5000,
    this.isRequired = true,
    this.weight = 1.0,
    this.tags = const [],
    this.metadata = const {},
  });

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'targetSelector': targetSelector,
      'actionType': actionType.name,
      'expectedResult': expectedResult,
      'timeout': timeout,
      'isRequired': isRequired,
      'weight': weight,
      'tags': tags,
      'metadata': metadata,
    };
  }

  /// 从 JSON 创建
  factory TestPathStep.fromJson(Map<String, dynamic> json) {
    return TestPathStep(
      id: json['id'] as String,
      description: json['description'] as String,
      targetSelector: json['targetSelector'] as String?,
      actionType: PathActionType.values.firstWhere(
        (e) => e.name == json['actionType'] as String?,
        orElse: () => PathActionType.unknown,
      ),
      expectedResult: json['expectedResult'] as String?,
      timeout: json['timeout'] as int? ?? 5000,
      isRequired: json['isRequired'] as bool? ?? true,
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  /// 创建副本
  TestPathStep copyWith({
    String? id,
    String? description,
    String? targetSelector,
    PathActionType? actionType,
    String? expectedResult,
    int? timeout,
    bool? isRequired,
    double? weight,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) {
    return TestPathStep(
      id: id ?? this.id,
      description: description ?? this.description,
      targetSelector: targetSelector ?? this.targetSelector,
      actionType: actionType ?? this.actionType,
      expectedResult: expectedResult ?? this.expectedResult,
      timeout: timeout ?? this.timeout,
      isRequired: isRequired ?? this.isRequired,
      weight: weight ?? this.weight,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() =>
      'TestPathStep($description, ${actionType.name}, weight: $weight)';
}

/// 路径操作类型
enum PathActionType {
  /// 点击
  tap,

  /// 输入文本
  enterText,

  /// 滚动
  scroll,

  /// 等待
  wait,

  /// 验证
  verify,

  /// 导航
  navigate,

  /// 返回
  back,

  /// 自定义
  custom,

  /// 未知
  unknown,
}

/// 测试路径
class TestPath {
  /// 路径 ID
  final String id;

  /// 路径名称
  final String name;

  /// 路径描述
  final String description;

  /// 路径步骤
  final List<TestPathStep> steps;

  /// 路径优先级 (0.0 - 1.0)
  final double priority;

  /// 预期覆盖率贡献 (0.0 - 1.0)
  final double coverageContribution;

  /// 预计执行时间（毫秒）
  final int estimatedDuration;

  /// 路径类型
  final TestPathType type;

  /// 相关功能模块
  final List<String> modules;

  /// 依赖的其他路径 ID
  final List<String> dependencies;

  /// 路径状态
  final PathStatus status;

  /// 执行统计
  final PathStatistics? statistics;

  /// 创建时间
  final DateTime createdAt;

  /// 最后更新时间
  final DateTime updatedAt;

  const TestPath({
    required this.id,
    required this.name,
    required this.description,
    required this.steps,
    this.priority = 0.5,
    this.coverageContribution = 0.1,
    this.estimatedDuration = 30000,
    this.type = TestPathType.userFlow,
    this.modules = const [],
    this.dependencies = const [],
    this.status = PathStatus.pending,
    this.statistics,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 获取步骤总数
  int get stepCount => steps.length;

  /// 获取必需步骤数
  int get requiredStepCount => steps.where((s) => s.isRequired).length;

  /// 是否可以执行
  bool get canExecute => status == PathStatus.pending || status == PathStatus.ready;

  /// 是否已完成
  bool get isCompleted => status == PathStatus.completed;

  /// 计算路径权重
  double get weight {
    var score = 0.0;

    // 优先级贡献 (40%)
    score += priority * 0.4;

    // 覆盖率贡献 (30%)
    score += coverageContribution * 0.3;

    // 步骤权重平均 (20%)
    final avgStepWeight = steps.isEmpty
        ? 0.0
        : steps.fold<double>(0.0, (sum, s) => sum + s.weight) / steps.length;
    score += avgStepWeight.clamp(0.0, 1.0) * 0.2;

    // 类型加成 (10%)
    final typeBonus = switch (type) {
      TestPathType.critical => 1.0,
      TestPathType.userFlow => 0.8,
      TestPathType.edgeCase => 0.6,
      TestPathType.exploratory => 0.4,
    };
    score += typeBonus * 0.1;

    return score.clamp(0.0, 1.0);
  }

  /// 创建成功状态的路径
  TestPath completed({PathStatistics? stats}) {
    return TestPath(
      id: id,
      name: name,
      description: description,
      steps: steps,
      priority: priority,
      coverageContribution: coverageContribution,
      estimatedDuration: estimatedDuration,
      type: type,
      modules: modules,
      dependencies: dependencies,
      status: PathStatus.completed,
      statistics: stats ?? statistics,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// 创建失败状态的路径
  TestPath failed({PathStatistics? stats}) {
    return TestPath(
      id: id,
      name: name,
      description: description,
      steps: steps,
      priority: priority,
      coverageContribution: coverageContribution,
      estimatedDuration: estimatedDuration,
      type: type,
      modules: modules,
      dependencies: dependencies,
      status: PathStatus.failed,
      statistics: stats ?? statistics,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'steps': steps.map((s) => s.toJson()).toList(),
      'priority': priority,
      'coverageContribution': coverageContribution,
      'estimatedDuration': estimatedDuration,
      'type': type.name,
      'modules': modules,
      'dependencies': dependencies,
      'status': status.name,
      'statistics': statistics?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// 从 JSON 创建
  factory TestPath.fromJson(Map<String, dynamic> json) {
    return TestPath(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      steps: (json['steps'] as List?)
              ?.map((s) => TestPathStep.fromJson(s as Map<String, dynamic>))
              .toList() ??
          const [],
      priority: (json['priority'] as num?)?.toDouble() ?? 0.5,
      coverageContribution: (json['coverageContribution'] as num?)?.toDouble() ?? 0.1,
      estimatedDuration: json['estimatedDuration'] as int? ?? 30000,
      type: TestPathType.values.firstWhere(
        (e) => e.name == json['type'] as String?,
        orElse: () => TestPathType.userFlow,
      ),
      modules: (json['modules'] as List?)?.cast<String>() ?? const [],
      dependencies: (json['dependencies'] as List?)?.cast<String>() ?? const [],
      status: PathStatus.values.firstWhere(
        (e) => e.name == json['status'] as String?,
        orElse: () => PathStatus.pending,
      ),
      statistics: json['statistics'] != null
          ? PathStatistics.fromJson(json['statistics'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  String toString() =>
      'TestPath($name, ${steps.length} steps, priority: $priority, status: ${status.name})';
}

/// 测试路径类型
enum TestPathType {
  /// 关键路径
  critical,

  /// 用户流程
  userFlow,

  /// 边界情况
  edgeCase,

  /// 探索性测试
  exploratory,
}

/// 路径状态
enum PathStatus {
  /// 待执行
  pending,

  /// 就绪
  ready,

  /// 执行中
  running,

  /// 已完成
  completed,

  /// 失败
  failed,

  /// 跳过
  skipped,
}

/// 路径执行统计
class PathStatistics {
  /// 执行次数
  final int executionCount;

  /// 成功次数
  final int successCount;

  /// 失败次数
  final int failureCount;

  /// 平均执行时间（毫秒）
  final int avgDuration;

  /// 最短执行时间
  final int minDuration;

  /// 最长执行时间
  final int maxDuration;

  /// 最后执行时间
  final DateTime? lastExecutedAt;

  /// 成功率
  double get successRate =>
      executionCount > 0 ? successCount / executionCount : 0.0;

  const PathStatistics({
    this.executionCount = 0,
    this.successCount = 0,
    this.failureCount = 0,
    this.avgDuration = 0,
    this.minDuration = 0,
    this.maxDuration = 0,
    this.lastExecutedAt,
  });

  /// 更新统计
  PathStatistics withExecution({
    required bool success,
    required int duration,
  }) {
    final newExecutionCount = executionCount + 1;
    final newSuccessCount = successCount + (success ? 1 : 0);
    final newFailureCount = failureCount + (success ? 0 : 1);

    final newAvgDuration = executionCount > 0
        ? ((avgDuration * executionCount) + duration) / newExecutionCount
        : duration;

    return PathStatistics(
      executionCount: newExecutionCount,
      successCount: newSuccessCount,
      failureCount: newFailureCount,
      avgDuration: newAvgDuration.round(),
      minDuration: minDuration == 0 ? duration : math.min(minDuration, duration),
      maxDuration: math.max(maxDuration, duration),
      lastExecutedAt: DateTime.now(),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'executionCount': executionCount,
      'successCount': successCount,
      'failureCount': failureCount,
      'avgDuration': avgDuration,
      'minDuration': minDuration,
      'maxDuration': maxDuration,
      'lastExecutedAt': lastExecutedAt?.toIso8601String(),
      'successRate': successRate,
    };
  }

  /// 从 JSON 创建
  factory PathStatistics.fromJson(Map<String, dynamic> json) {
    return PathStatistics(
      executionCount: json['executionCount'] as int? ?? 0,
      successCount: json['successCount'] as int? ?? 0,
      failureCount: json['failureCount'] as int? ?? 0,
      avgDuration: json['avgDuration'] as int? ?? 0,
      minDuration: json['minDuration'] as int? ?? 0,
      maxDuration: json['maxDuration'] as int? ?? 0,
      lastExecutedAt: json['lastExecutedAt'] != null
          ? DateTime.parse(json['lastExecutedAt'] as String)
          : null,
    );
  }

  @override
  String toString() =>
      'PathStatistics($executionCount runs, ${(successRate * 100).toStringAsFixed(0)}% success)';
}

/// 路径集合
class TestPathSet {
  final List<TestPath> _paths = [];

  /// 添加路径
  void addPath(TestPath path) {
    _paths.add(path);
  }

  /// 批量添加路径
  void addPaths(List<TestPath> paths) {
    _paths.addAll(paths);
  }

  /// 获取所有路径
  List<TestPath> getPaths() {
    return List.unmodifiable(_paths);
  }

  /// 按优先级排序获取路径
  List<TestPath> getPathsByPriority() {
    final sorted = List<TestPath>.from(_paths)
      ..sort((a, b) => b.weight.compareTo(a.weight));
    return List.unmodifiable(sorted);
  }

  /// 获取可执行路径
  List<TestPath> getExecutablePaths() {
    return _paths.where((p) => p.canExecute).toList();
  }

  /// 按 ID 获取路径
  TestPath? getPathById(String id) {
    try {
      return _paths.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 按模块获取路径
  List<TestPath> getPathsByModule(String module) {
    return _paths.where((p) => p.modules.contains(module)).toList();
  }

  /// 按类型获取路径
  List<TestPath> getPathsByType(TestPathType type) {
    return _paths.where((p) => p.type == type).toList();
  }

  /// 获取已完成路径
  List<TestPath> getCompletedPaths() {
    return _paths.where((p) => p.isCompleted).toList();
  }

  /// 获取失败路径
  List<TestPath> getFailedPaths() {
    return _paths.where((p) => p.status == PathStatus.failed).toList();
  }

  /// 计算总体统计
  Map<String, dynamic> getStatistics() {
    final total = _paths.length;
    final completed = getCompletedPaths().length;
    final failed = getFailedPaths().length;
    final pending = getExecutablePaths().length;

    final totalSteps = _paths.fold<int>(0, (sum, p) => sum + p.stepCount);
    final estimatedTotalDuration =
        _paths.fold<int>(0, (sum, p) => sum + p.estimatedDuration);

    return {
      'totalPaths': total,
      'completed': completed,
      'failed': failed,
      'pending': pending,
      'completionRate': total > 0 ? (completed / total * 100).round() : 0,
      'totalSteps': totalSteps,
      'estimatedTotalDuration': estimatedTotalDuration,
      'byType': {
        for (final type in TestPathType.values)
          type.name: getPathsByType(type).length,
      },
    };
  }

  /// 清空路径
  void clear() {
    _paths.clear();
  }

  /// 导出为 JSON
  String exportToJson({bool pretty = true}) {
    final data = {
      'paths': _paths.map((p) => p.toJson()).toList(),
      'statistics': getStatistics(),
      'exportedAt': DateTime.now().toIso8601String(),
    };

    return pretty
        ? const JsonEncoder.withIndent('  ').convert(data)
        : jsonEncode(data);
  }
}

