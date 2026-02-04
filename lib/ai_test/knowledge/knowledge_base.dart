/// 知识库管理器 - 整合测试历史、模式学习和相似度匹配
library;

import 'dart:convert';
import 'test_history.dart';
import 'similarity_matcher.dart';
import 'pattern_learner.dart';

/// 知识库查询结果
class KnowledgeQueryResult {
  /// 相似的失败记录
  final List<SimilarityMatch> similarFailures;

  /// 匹配的模式
  final List<FailurePattern> matchedPatterns;

  /// 推荐的解决方案
  final List<String> recommendedSolutions;

  /// 置信度 (0.0 - 1.0)
  final double confidence;

  const KnowledgeQueryResult({
    this.similarFailures = const [],
    this.matchedPatterns = const [],
    this.recommendedSolutions = const [],
    required this.confidence,
  });

  /// 是否有结果
  bool get hasResults =>
      similarFailures.isNotEmpty ||
      matchedPatterns.isNotEmpty ||
      recommendedSolutions.isNotEmpty;

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'similarFailures': similarFailures.map((m) => m.toJson()).toList(),
      'matchedPatterns': matchedPatterns.map((p) => p.toJson()).toList(),
      'recommendedSolutions': recommendedSolutions,
      'confidence': confidence,
      'hasResults': hasResults,
    };
  }

  @override
  String toString() =>
      'KnowledgeQueryResult(${hasResults ? "有" : "无"}结果, '
      '置信度: ${(confidence * 100).toStringAsFixed(0)}%)';
}

/// 知识库配置
class KnowledgeBaseConfig {
  /// 是否启用模式学习
  final bool enablePatternLearning;

  /// 是否启用相似度匹配
  final bool enableSimilarityMatching;

  /// 是否自动学习
  final bool autoLearn;

  /// 学习间隔（执行多少次测试后学习一次）
  final int learnInterval;

  /// 最大存储记录数
  final int maxRecords;

  const KnowledgeBaseConfig({
    this.enablePatternLearning = true,
    this.enableSimilarityMatching = true,
    this.autoLearn = true,
    this.learnInterval = 10,
    this.maxRecords = 10000,
  });

  /// 默认配置
  static const defaultConfig = KnowledgeBaseConfig();

  /// 轻量级配置
  static const lightweightConfig = KnowledgeBaseConfig(
    enablePatternLearning: false,
    enableSimilarityMatching: true,
    autoLearn: false,
    maxRecords: 1000,
  );

  /// 完整配置
  static const fullConfig = KnowledgeBaseConfig(
    enablePatternLearning: true,
    enableSimilarityMatching: true,
    autoLearn: true,
    learnInterval: 5,
    maxRecords: 50000,
  );
}

/// 知识库管理器
class KnowledgeBase {
  final TestHistoryStorage _history;
  final SimilarityMatcher _similarityMatcher;
  final PatternLearner _patternLearner;
  final KnowledgeBaseConfig _config;

  int _executionCount = 0;

  KnowledgeBase({
    TestHistoryStorage? history,
    SimilarityMatcher? similarityMatcher,
    PatternLearner? patternLearner,
    KnowledgeBaseConfig? config,
  })  : _history = history ?? TestHistoryStorage(),
        _similarityMatcher = similarityMatcher ?? SimilarityMatcher(history: history),
        _patternLearner = patternLearner ?? PatternLearner(history: history),
        _config = config ?? KnowledgeBaseConfig.defaultConfig;

  /// 记录测试执行
  void recordTestExecution({
    required String testName,
    required bool success,
    required int duration,
    String? failureMessage,
    String? stackTrace,
    String? healingSessionId,
    String testType = 'integration',
    List<String> tags = const [],
    Map<String, dynamic> metadata = const {},
  }) {
    final record = success
        ? TestExecutionRecord.success(
            testName: testName,
            duration: duration,
            testType: testType,
            tags: tags,
            metadata: metadata,
          )
        : TestExecutionRecord.failure(
            testName: testName,
            duration: duration,
            failureMessage: failureMessage!,
            stackTrace: stackTrace,
            healingSessionId: healingSessionId,
            testType: testType,
            tags: tags,
            metadata: metadata,
          );

    _history.addRecord(record);

    // 检查是否需要自动学习
    if (_config.autoLearn && ++_executionCount % _config.learnInterval == 0) {
      _autoLearn();
    }

    // 限制存储大小
    _enforceMaxRecords();
  }

  /// 查询知识库
  KnowledgeQueryResult query({
    required String testName,
    String? errorMessage,
    String? stackTrace,
    int maxResults = 5,
    double minScore = 0.3,
  }) {
    final similarFailures = <SimilarityMatch>[];
    final matchedPatterns = <FailurePattern>[];
    final recommendedSolutions = <String>[];
    var confidence = 0.0;

    // 1. 相似度匹配
    if (_config.enableSimilarityMatching && errorMessage != null) {
      final matches = _similarityMatcher.findSimilarFailures(
        testName: testName,
        errorMessage: errorMessage,
        stackTrace: stackTrace,
        maxResults: maxResults,
        minScore: minScore,
      );
      similarFailures.addAll(matches);
    }

    // 2. 模式匹配
    if (_config.enablePatternLearning && errorMessage != null) {
      final patterns = _patternLearner.matchPatterns(errorMessage!);
      matchedPatterns.addAll(patterns);
    }

    // 3. 查找成功解决方案
    if (errorMessage != null) {
      final solutions = _similarityMatcher.findSuccessfulSolutions(errorMessage!);
      recommendedSolutions.addAll(solutions);
    }

    // 计算综合置信度
    if (similarFailures.isNotEmpty) {
      confidence += similarFailures.first.score * 0.5;
    }
    if (matchedPatterns.isNotEmpty) {
      confidence += matchedPatterns.first.confidence * 0.3;
    }
    if (recommendedSolutions.isNotEmpty) {
      confidence += 0.2;
    }

    return KnowledgeQueryResult(
      similarFailures: similarFailures,
      matchedPatterns: matchedPatterns,
      recommendedSolutions: recommendedSolutions,
      confidence: confidence.clamp(0.0, 1.0),
    );
  }

  /// 获取推荐的修复方案
  List<String> getRecommendedFixes(String errorMessage) {
    final fixes = <String>[];

    // 1. 从模式学习获取
    if (_config.enablePatternLearning) {
      final strategy = _patternLearner.getRecommendedStrategy(errorMessage);
      if (strategy != null) {
        fixes.add('推荐策略: $strategy');
      }
    }

    // 2. 从相似历史获取
    if (_config.enableSimilarityMatching) {
      final solutions = _similarityMatcher.findSuccessfulSolutions(errorMessage);
      fixes.addAll(solutions);
    }

    return fixes;
  }

  /// 手动触发学习
  List<FailurePattern> learn({bool forceUpdate = false}) {
    return _patternLearner.learnFromHistory(forceUpdate: forceUpdate);
  }

  /// 自动学习
  void _autoLearn() {
    if (_config.enablePatternLearning) {
      _patternLearner.learnFromHistory();
    }
  }

  /// 限制存储大小
  void _enforceMaxRecords() {
    final currentSize = _history.getRecords().length;
    if (currentSize > _config.maxRecords) {
      // 删除最旧的记录
      final records = _history.getRecords();
      final toRemove = currentSize - _config.maxRecords;

      // 简化处理：创建新的存储只保留最近的记录
      final recentRecords = records.skip(toRemove).toList();
      _history.clear();
      _history.addRecords(recentRecords);
    }
  }

  /// 获取统计信息
  Map<String, dynamic> getStatistics() {
    final historyStats = _history.getStatistics();
    final patterns = _patternLearner.getPatterns();

    return {
      'history': historyStats,
      'patterns': {
        'total': patterns.length,
        'avgConfidence': patterns.isEmpty
            ? 0.0
            : patterns.fold<double>(0.0, (sum, p) => sum + p.confidence) /
                patterns.length,
        'avgSuccessRate': patterns.isEmpty
            ? 0.0
            : patterns.fold<double>(0.0, (sum, p) => sum + p.successRate) /
                patterns.length,
      },
      'executionCount': _executionCount,
      'config': {
        'autoLearn': _config.autoLearn,
        'learnInterval': _config.learnInterval,
        'maxRecords': _config.maxRecords,
      },
    };
  }

  /// 导出知识库为 JSON
  String exportToJson({bool pretty = true}) {
    final data = {
      'history': jsonDecode(_history.exportToJson(pretty: false)),
      'patterns': jsonDecode(_patternLearner.exportPatternsToJson(pretty: false)),
      'statistics': getStatistics(),
      'exportedAt': DateTime.now().toIso8601String(),
    };

    return pretty
        ? const JsonEncoder.withIndent('  ').convert(data)
        : jsonEncode(data);
  }

  /// 从 JSON 导入知识库
  factory KnowledgeBase.fromJson(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;

    final history = TestHistoryStorage.fromJson(
      jsonEncode(json['history']),
    );

    final knowledgeBase = KnowledgeBase(
      history: history,
      config: KnowledgeBaseConfig.defaultConfig,
    );

    // 导入模式
    // (简化处理，实际应用中需要完整的模式导入逻辑)

    return knowledgeBase;
  }

  /// 打印知识库状态
  void printStatus() {
    final stats = getStatistics();

    print('\n📚 知识库状态');
    print('━' * 60);

    // 历史统计
    final historyStats = stats['history'] as Map<String, dynamic>;
    print('📖 测试历史');
    print('  总记录数: ${historyStats['total']}');
    print('  成功次数: ${historyStats['success']}');
    print('  失败次数: ${historyStats['failure']}');
    print('  成功率: ${historyStats['successRate']}%');

    // 模式统计
    final patternStats = stats['patterns'] as Map<String, dynamic>;
    print('\n🧠 学习模式');
    print('  模式数: ${patternStats['total']}');
    print('  平均置信度: ${(patternStats['avgConfidence'] * 100).toStringAsFixed(0)}%');
    print('  平均成功率: ${(patternStats['avgSuccessRate'] * 100).toStringAsFixed(0)}%');

    // 执行统计
    print('\n⚙️  配置');
    print('  自动学习: ${stats['config']['autoLearn']}');
    print('  学习间隔: ${stats['config']['learnInterval']} 次执行');
    print('  最大记录: ${stats['config']['maxRecords']}');

    print('━' * 60);
  }

  /// 获取历史存储
  TestHistoryStorage get history => _history;

  /// 获取模式学习器
  PatternLearner get patternLearner => _patternLearner;

  /// 获取相似度匹配器
  SimilarityMatcher get similarityMatcher => _similarityMatcher;

  /// 清空知识库
  void clear() {
    _history.clear();
    _executionCount = 0;
  }
}
