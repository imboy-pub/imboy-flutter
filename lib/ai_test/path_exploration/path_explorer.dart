/// 路径探索器 - 智能发现和探索测试路径
library;

import 'dart:math';
import 'test_path.dart';
import 'coverage_tracker.dart';

/// 探索配置
class ExplorationConfig {
  /// 最大探索深度
  final int maxDepth;

  /// 最大路径数量
  final int maxPaths;

  /// 探索超时（毫秒）
  final int timeout;

  /// 是否启用随机探索
  final bool enableRandom;

  /// 随机探索概率 (0.0 - 1.0)
  final double randomProbability;

  /// 是否启用覆盖率优化
  final bool enableCoverageOptimization;

  /// 最小覆盖率增量
  final double minCoverageIncrement;

  /// 是否启用剪枝
  final bool enablePruning;

  const ExplorationConfig({
    this.maxDepth = 10,
    this.maxPaths = 100,
    this.timeout = 30000,
    this.enableRandom = true,
    this.randomProbability = 0.2,
    this.enableCoverageOptimization = true,
    this.minCoverageIncrement = 0.05,
    this.enablePruning = true,
  });

  /// 默认配置
  static const defaultConfig = ExplorationConfig();

  /// 快速配置
  static const quickConfig = ExplorationConfig(
    maxDepth: 5,
    maxPaths: 20,
    timeout: 10000,
    enableRandom: false,
    enableCoverageOptimization: true,
    enablePruning: true,
  );

  /// 深度配置
  static const deepConfig = ExplorationConfig(
    maxDepth: 20,
    maxPaths: 500,
    timeout: 120000,
    enableRandom: true,
    randomProbability: 0.3,
    enableCoverageOptimization: true,
    minCoverageIncrement: 0.02,
    enablePruning: false,
  );
}

/// 探索结果
class ExplorationResult {
  /// 发现的路径
  final List<TestPath> paths;

  /// 覆盖率信息
  final Map<String, dynamic> coverageInfo;

  /// 探索耗时（毫秒）
  final int duration;

  /// 探索的节点数
  final int exploredNodes;

  /// 剪枝的节点数
  final int prunedNodes;

  /// 是否完成（或因超时/限制终止）
  final bool completed;

  const ExplorationResult({
    required this.paths,
    required this.coverageInfo,
    required this.duration,
    required this.exploredNodes,
    this.prunedNodes = 0,
    this.completed = true,
  });

  /// 获取统计摘要
  Map<String, dynamic> getSummary() {
    return {
      'totalPaths': paths.length,
      'byType': {
        for (final type in TestPathType.values)
          type.name: paths.where((p) => p.type == type).length,
      },
      'totalSteps': paths.fold<int>(0, (sum, p) => sum + p.stepCount),
      'estimatedDuration': paths.fold<int>(
          0, (sum, p) => sum + p.estimatedDuration),
      'coverage': coverageInfo,
      'duration': duration,
      'exploredNodes': exploredNodes,
      'prunedNodes': prunedNodes,
      'completed': completed,
      'efficiency': exploredNodes > 0
          ? (paths.length / exploredNodes * 100).toStringAsFixed(1) + '%'
          : 'N/A',
    };
  }

  @override
  String toString() =>
      'ExplorationResult(${paths.length} paths, ${duration}ms, ${completed ? "completed" : "terminated"})';
}

/// 路径探索器
class PathExplorer {
  final CoverageTracker _coverageTracker;
  final ExplorationConfig _config;
  final Random _random;

  int _exploredNodes = 0;
  int _prunedNodes = 0;
  final List<TestPath> _discoveredPaths = [];
  final Set<String> _visitedStates = {};

  PathExplorer({
    required CoverageTracker coverageTracker,
    ExplorationConfig? config,
    Random? random,
  })  : _coverageTracker = coverageTracker,
        _config = config ?? ExplorationConfig.defaultConfig,
        _random = random ?? Random();

  /// 探索应用路径
  ExplorationResult explore({
    required String startingPoint,
    Map<String, dynamic> context = const {},
  }) {
    final stopwatch = Stopwatch()..start();

    try {
      _resetState();

      // 从起点开始探索
      _exploreFrom(
        startingPoint: startingPoint,
        context: context,
        currentDepth: 0,
        currentPath: const <TestPathStep>[],
      );

      // 根据覆盖率优化路径
      if (_config.enableCoverageOptimization) {
        _optimizePathsByCoverage();
      }

      // 随机探索
      if (_config.enableRandom) {
        _randomExplore(
          startingPoint: startingPoint,
          context: context,
        );
      }

      stopwatch.stop();

      return ExplorationResult(
        paths: List.unmodifiable(_discoveredPaths),
        coverageInfo: _coverageTracker.getSummary(),
        duration: stopwatch.elapsedMilliseconds,
        exploredNodes: _exploredNodes,
        prunedNodes: _prunedNodes,
        completed: true,
      );
    } catch (e) {
      stopwatch.stop();
      return ExplorationResult(
        paths: List.unmodifiable(_discoveredPaths),
        coverageInfo: _coverageTracker.getSummary(),
        duration: stopwatch.elapsedMilliseconds,
        exploredNodes: _exploredNodes,
        prunedNodes: _prunedNodes,
        completed: false,
      );
    }
  }

  /// 从指定点探索
  void _exploreFrom({
    required String startingPoint,
    required Map<String, dynamic> context,
    required int currentDepth,
    required List<TestPathStep> currentPath,
  }) {
    // 检查深度限制
    if (currentDepth >= _config.maxDepth) {
      return;
    }

    // 检查路径数量限制
    if (_discoveredPaths.length >= _config.maxPaths) {
      return;
    }

    // 生成当前状态标识
    final stateId = _generateStateId(startingPoint, currentPath);
    if (_visitedStates.contains(stateId)) {
      _prunedNodes++;
      return; // 已访问过，剪枝
    }
    _visitedStates.add(stateId);
    _exploredNodes++;

    // 获取可用的下一步操作
    final nextSteps = _getNextSteps(startingPoint, context, currentDepth);

    for (final step in nextSteps) {
      // 创建新路径
      final newPath = List<TestPathStep>.from(currentPath)..add(step);

      // 尝试完成路径
      if (_shouldCompletePath(newPath, currentDepth)) {
        _createPath(
          steps: newPath,
          type: _determinePathType(newPath),
          priority: _calculatePathPriority(newPath),
        );
      }

      // 继续探索
      _exploreFrom(
        startingPoint: _getNextStartingPoint(step, startingPoint),
        context: _updateContext(context, step),
        currentDepth: currentDepth + 1,
        currentPath: newPath,
      );
    }
  }

  /// 随机探索
  void _randomExplore({
    required String startingPoint,
    required Map<String, dynamic> context,
  }) {
    final randomAttempts = (_config.maxPaths * _config.randomProbability).round();

    for (var i = 0; i < randomAttempts; i++) {
      final randomPath = _generateRandomPath(startingPoint, context);
      if (randomPath.isNotEmpty) {
        _createPath(
          steps: randomPath,
          type: TestPathType.exploratory,
          priority: _random.nextDouble() * 0.5,
        );
      }
    }
  }

  /// 根据覆盖率优化路径
  void _optimizePathsByCoverage() {
    final uncoveredElements = _coverageTracker.getUncoveredElements();

    if (uncoveredElements.isEmpty) {
      return;
    }

    // 为未覆盖的元素生成路径
    for (final selector in uncoveredElements.take(10)) {
      final path = _createPathToElement(selector);
      if (path != null) {
        _discoveredPaths.add(path);
      }
    }

    // 按覆盖率贡献排序
    _discoveredPaths.sort((a, b) => b.coverageContribution.compareTo(a.coverageContribution));
  }

  /// 获取下一步操作
  List<TestPathStep> _getNextSteps(
    String currentPoint,
    Map<String, dynamic> context,
    int depth,
  ) {
    // 这里应该根据应用的实际结构返回可用的操作
    // 简化实现：返回常见操作
    final steps = <TestPathStep>[
      TestPathStep(
        id: 'step_${depth}_tap',
        description: '点击元素',
        targetSelector: '#element_$depth',
        actionType: PathActionType.tap,
        weight: 1.0,
      ),
      TestPathStep(
        id: 'step_${depth}_input',
        description: '输入文本',
        targetSelector: '#input_$depth',
        actionType: PathActionType.enterText,
        weight: 0.8,
      ),
      TestPathStep(
        id: 'step_${depth}_scroll',
        description: '滚动',
        actionType: PathActionType.scroll,
        weight: 0.5,
      ),
      TestPathStep(
        id: 'step_${depth}_verify',
        description: '验证状态',
        actionType: PathActionType.verify,
        weight: 0.6,
      ),
    ];

    // 根据上下文过滤步骤
    return _filterStepsByContext(steps, context);
  }

  /// 根据上下文过滤步骤
  List<TestPathStep> _filterStepsByContext(
    List<TestPathStep> steps,
    Map<String, dynamic> context,
  ) {
    // 简化实现：可以基于上下文过滤不适合的操作
    return steps;
  }

  /// 判断是否应该完成路径
  bool _shouldCompletePath(List<TestPathStep> path, int depth) {
    // 至少包含一定数量的步骤
    if (path.length < 2) return false;

    // 最后一个步骤是验证
    if (path.last.actionType == PathActionType.verify) {
      return true;
    }

    // 随机决定是否完成（避免所有路径都过长）
    return _random.nextDouble() < 0.3;
  }

  /// 确定路径类型
  TestPathType _determinePathType(List<TestPathStep> path) {
    // 检查是否包含关键操作
    final hasCriticalActions = path.any((s) =>
        s.actionType == PathActionType.tap && s.targetSelector?.contains('submit') == true);

    if (hasCriticalActions) {
      return TestPathType.critical;
    }

    // 检查是否是正常流程
    final isNormalFlow = path.length >= 3 &&
        path.first.actionType == PathActionType.navigate &&
        path.last.actionType == PathActionType.verify;

    if (isNormalFlow) {
      return TestPathType.userFlow;
    }

    // 检查是否包含边界操作
    final hasEdgeCase = path.any((s) =>
        s.actionType == PathActionType.back ||
        s.actionType == PathActionType.scroll);

    if (hasEdgeCase) {
      return TestPathType.edgeCase;
    }

    return TestPathType.userFlow;
  }

  /// 计算路径优先级
  double _calculatePathPriority(List<TestPathStep> path) {
    var priority = 0.5;

    // 关键路径优先
    if (_determinePathType(path) == TestPathType.critical) {
      priority += 0.3;
    }

    // 长度适中的路径优先
    if (path.length >= 3 && path.length <= 7) {
      priority += 0.1;
    }

    // 包含验证的路径优先
    if (path.any((s) => s.actionType == PathActionType.verify)) {
      priority += 0.1;
    }

    return priority.clamp(0.0, 1.0);
  }

  /// 创建路径
  void _createPath({
    required List<TestPathStep> steps,
    required TestPathType type,
    required double priority,
  }) {
    final path = TestPath(
      id: 'path_${DateTime.now().millisecondsSinceEpoch}_${_discoveredPaths.length}',
      name: _generatePathName(steps, type),
      description: _generatePathDescription(steps),
      steps: steps,
      priority: priority,
      type: type,
      estimatedDuration: steps.fold<int>(
          0, (sum, s) => sum + s.timeout),
      modules: _extractModules(steps),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _discoveredPaths.add(path);
  }

  /// 生成路径名称
  String _generatePathName(List<TestPathStep> steps, TestPathType type) {
    final typePrefix = switch (type) {
      TestPathType.critical => '关键路径',
      TestPathType.userFlow => '用户流程',
      TestPathType.edgeCase => '边界测试',
      TestPathType.exploratory => '探索测试',
    };

    final mainAction = steps.isNotEmpty
        ? steps.first.description
        : '未知操作';

    return '$typePrefix: $mainAction';
  }

  /// 生成路径描述
  String _generatePathDescription(List<TestPathStep> steps) {
    if (steps.isEmpty) return '空路径';

    final actionList = steps
        .take(3)
        .map((s) => s.description)
        .join(' → ');

    return steps.length > 3
        ? '$actionList → ... (${steps.length} 步)'
        : actionList;
  }

  /// 提取模块信息
  List<String> _extractModules(List<TestPathStep> steps) {
    final modules = <String>{};

    for (final step in steps) {
      if (step.targetSelector != null) {
        // 从选择器提取模块名
        final parts = step.targetSelector!.split(RegExp(r'[\[\]#\.]'));
        if (parts.isNotEmpty) {
          modules.add(parts.first);
        }
      }
    }

    return modules.toList();
  }

  /// 生成随机路径
  List<TestPathStep> _generateRandomPath(
    String startingPoint,
    Map<String, dynamic> context,
  ) {
    final path = <TestPathStep>[];
    final length = 2 + _random.nextInt(5);

    for (var i = 0; i < length; i++) {
      final actionType = PathActionType.values[
          _random.nextInt(PathActionType.values.length - 2)]; // 排除 unknown 和 custom

      path.add(TestPathStep(
        id: 'random_step_$i',
        description: '随机操作 ${i + 1}',
        targetSelector: '#random_element_$i',
        actionType: actionType,
        weight: _random.nextDouble(),
      ));
    }

    return path;
  }

  /// 创建到达指定元素的路径
  TestPath? _createPathToElement(String selector) {
    // 简化实现：创建一个直接访问该元素的路径
    final path = TestPath(
      id: 'path_to_$selector',
      name: '访问 $selector',
      description: '直接访问未覆盖元素: $selector',
      steps: [
        TestPathStep(
          id: 'step_1',
          description: '访问目标元素',
          targetSelector: selector,
          actionType: PathActionType.tap,
          isRequired: true,
          weight: 1.0,
        ),
        TestPathStep(
          id: 'step_2',
          description: '验证元素可见',
          targetSelector: selector,
          actionType: PathActionType.verify,
          isRequired: true,
          weight: 0.8,
        ),
      ],
      type: TestPathType.edgeCase,
      priority: 0.7,
      coverageContribution: 0.3,
      modules: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return path;
  }

  /// 获取下一个起点
  String _getNextStartingPoint(TestPathStep step, String currentPoint) {
    if (step.targetSelector != null) {
      return step.targetSelector!;
    }
    return currentPoint;
  }

  /// 更新上下文
  Map<String, dynamic> _updateContext(
    Map<String, dynamic> context,
    TestPathStep step,
  ) {
    final updated = Map<String, dynamic>.from(context);

    // 更新上下文信息
    updated['lastAction'] = step.actionType.name;
    updated['lastTarget'] = step.targetSelector;
    updated['stepCount'] = (context['stepCount'] as int? ?? 0) + 1;

    return updated;
  }

  /// 生成状态 ID
  String _generateStateId(String currentPoint, List<TestPathStep> path) {
    final buffer = StringBuffer();
    buffer.write(currentPoint);
    for (final step in path) {
      buffer.write(':${step.actionType.name}');
      if (step.targetSelector != null) {
        buffer.write('@${step.targetSelector}');
      }
    }
    return buffer.toString();
  }

  /// 重置状态
  void _resetState() {
    _exploredNodes = 0;
    _prunedNodes = 0;
    _discoveredPaths.clear();
    _visitedStates.clear();
  }

  /// 获取覆盖率追踪器
  CoverageTracker get coverageTracker => _coverageTracker;

  /// 获取配置
  ExplorationConfig get config => _config;
}
