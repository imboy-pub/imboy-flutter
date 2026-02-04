/// 模式学习器 - 从测试历史中学习失败模式
library;

import 'dart:convert';
import 'dart:math';
import 'test_history.dart';
import 'similarity_matcher.dart';

/// 失败模式
class FailurePattern {
  /// 模式 ID
  final String id;

  /// 模式名称
  final String name;

  /// 模式描述
  final String description;

  /// 触发条件（关键词列表）
  final List<String> triggerKeywords;

  /// 推荐的愈合策略
  final String recommendedStrategy;

  /// 置信度 (0.0 - 1.0)
  final double confidence;

  /// 出现次数
  final int occurrenceCount;

  /// 成功愈合次数
  final int successCount;

  /// 最后更新时间
  final DateTime lastUpdated;

  const FailurePattern({
    required this.id,
    required this.name,
    required this.description,
    required this.triggerKeywords,
    required this.recommendedStrategy,
    required this.confidence,
    required this.occurrenceCount,
    required this.successCount,
    required this.lastUpdated,
  });

  /// 获取成功率
  double get successRate {
    return occurrenceCount > 0 ? successCount / occurrenceCount : 0.0;
  }

  /// 是否匹配
  bool matches(String errorMessage) {
    final lowerMessage = errorMessage.toLowerCase();
    return triggerKeywords.any((keyword) =>
        lowerMessage.contains(keyword.toLowerCase()));
  }

  /// 更新模式
  FailurePattern withOccurrence({bool success = true}) {
    return FailurePattern(
      id: id,
      name: name,
      description: description,
      triggerKeywords: triggerKeywords,
      recommendedStrategy: recommendedStrategy,
      confidence: confidence,
      occurrenceCount: occurrenceCount + 1,
      successCount: successCount + (success ? 1 : 0),
      lastUpdated: DateTime.now(),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'triggerKeywords': triggerKeywords,
      'recommendedStrategy': recommendedStrategy,
      'confidence': confidence,
      'occurrenceCount': occurrenceCount,
      'successCount': successCount,
      'successRate': successRate,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  /// 从 JSON 创建
  factory FailurePattern.fromJson(Map<String, dynamic> json) {
    return FailurePattern(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      triggerKeywords:
          (json['triggerKeywords'] as List?)?.cast<String>() ?? const [],
      recommendedStrategy: json['recommendedStrategy'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      occurrenceCount: json['occurrenceCount'] as int,
      successCount: json['successCount'] as int,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }

  @override
  String toString() =>
      'FailurePattern($name, ${occurrenceCount}次, ${(successRate * 100).toStringAsFixed(0)}% 成功率)';
}

/// 学习配置
class LearningConfig {
  /// 最小出现次数才被认为是模式
  final int minOccurrences;

  /// 最小置信度阈值
  final double minConfidence;

  /// 学习窗口大小（天数）
  final int learningWindowDays;

  /// 是否自动更新模式
  final bool autoUpdate;

  const LearningConfig({
    this.minOccurrences = 3,
    this.minConfidence = 0.6,
    this.learningWindowDays = 30,
    this.autoUpdate = true,
  });

  /// 默认配置
  static const defaultConfig = LearningConfig();

  /// 快速学习配置
  static const fastConfig = LearningConfig(
    minOccurrences: 2,
    minConfidence: 0.5,
    learningWindowDays: 7,
  );

  /// 保守学习配置
  static const conservativeConfig = LearningConfig(
    minOccurrences: 5,
    minConfidence: 0.7,
    learningWindowDays: 60,
  );
}

/// 模式学习器
class PatternLearner {
  final TestHistoryStorage _history;
  final SimilarityMatcher _similarityMatcher;
  final LearningConfig _config;

  final List<FailurePattern> _patterns = [];

  PatternLearner({
    TestHistoryStorage? history,
    SimilarityMatcher? similarityMatcher,
    LearningConfig? config,
  })  : _history = history ?? TestHistoryStorage(),
        _similarityMatcher = similarityMatcher ?? SimilarityMatcher(history: history),
        _config = config ?? LearningConfig.defaultConfig;

  /// 从历史数据中学习模式
  List<FailurePattern> learnFromHistory({
    bool forceUpdate = false,
  }) {
    _patterns.clear();

    // 获取最近的失败记录
    final cutoffDate = DateTime.now().subtract(
      Duration(days: _config.learningWindowDays),
    );
    final recentFailures = _history.getFailureRecords()
        .where((r) => r.timestamp.isAfter(cutoffDate))
        .toList();

    // 按失败类型分组
    final failureGroups = _groupFailures(recentFailures);

    // 为每组创建模式
    for (final entry in failureGroups.entries) {
      final groupName = entry.key;
      final records = entry.value;

      // 检查出现次数
      if (records.length < _config.minOccurrences) {
        continue;
      }

      // 计算成功率（通过后续的成功记录判断）
      final successCount = _calculateSuccessCount(records);

      // 提取关键词
      final keywords = _extractKeywords(records);

      // 计算置信度
      final confidence = _calculateConfidence(
        records.length,
        successCount,
        keywords.length,
      );

      // 检查置信度阈值
      if (confidence < _config.minConfidence) {
        continue;
      }

      // 确定推荐策略
      final strategy = _determineRecommendedStrategy(groupName, records);

      // 创建模式
      final pattern = FailurePattern(
        id: 'pattern_${DateTime.now().millisecondsSinceEpoch}_${_patterns.length}',
        name: groupName,
        description: _generateDescription(groupName, keywords),
        triggerKeywords: keywords,
        recommendedStrategy: strategy,
        confidence: confidence,
        occurrenceCount: records.length,
        successCount: successCount,
        lastUpdated: DateTime.now(),
      );

      _patterns.add(pattern);
    }

    // 按置信度和出现次数排序
    _patterns.sort((a, b) {
      final scoreA = a.confidence * a.occurrenceCount;
      final scoreB = b.confidence * b.occurrenceCount;
      return scoreB.compareTo(scoreA);
    });

    return List.unmodifiable(_patterns);
  }

  /// 分组失败记录
  Map<String, List<TestExecutionRecord>> _groupFailures(
    List<TestExecutionRecord> failures,
  ) {
    final groups = <String, List<TestExecutionRecord>>{};

    for (final record in failures) {
      final key = _getFailureGroupKey(record);
      groups.putIfAbsent(key, () => <TestExecutionRecord>[]).add(record);
    }

    return groups;
  }

  /// 获取失败分组键
  String _getFailureGroupKey(TestExecutionRecord record) {
    final message = record.failureMessage ?? '';

    // 常见失败类型
    if (message.contains('Timeout') || message.contains('Timed out')) {
      return '超时错误';
    }
    if (message.contains('element not found') ||
        message.contains('Unable to find')) {
      return '元素未找到';
    }
    if (message.contains('assertion') || message.contains('Expected')) {
      return '断言失败';
    }
    if (message.contains('network') || message.contains('Socket')) {
      return '网络错误';
    }
    if (message.contains('permission') || message.contains('Permission')) {
      return '权限错误';
    }
    if (message.contains('selector') || message.contains('Invalid selector')) {
      return '选择器失效';
    }
    if (message.contains('state') || message.contains('State')) {
      return '状态不匹配';
    }

    // 提取选择器作为分组键
    final selector = _extractSelector(message);
    if (selector != null) {
      return '选择器:$selector';
    }

    // 使用关键词作为分组键
    final keywords = TestExecutionRecord(
      id: '',
      testName: record.testName,
      timestamp: record.timestamp,
      success: false,
      duration: record.duration,
      failureMessage: message,
    ).failureKeywords;

    if (keywords.isNotEmpty) {
      return keywords.first;
    }

    return '其他错误';
  }

  /// 提取选择器
  String? _extractSelector(String errorMessage) {
    final patterns = [
      RegExp(r'''selector[:\s]+'([^']+)'''),
      RegExp(r'''key[:\s]+["']([^"']+)["']'''),
      RegExp(r'''#[a-zA-Z][\w-]+'''),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(errorMessage);
      if (match != null && match.groupCount > 0) {
        return match.group(1);
      }
    }

    return null;
  }

  /// 计算成功愈合次数
  int _calculateSuccessCount(List<TestExecutionRecord> records) {
    var successCount = 0;

    for (final record in records) {
      // 查找后续的成功记录
      final testName = record.testName;
      final laterRecords = _history.getRecordsByTestName(testName)
          .where((r) => r.timestamp.isAfter(record.timestamp));

      for (final laterRecord in laterRecords) {
        if (laterRecord.success) {
          successCount++;
          break;
        }
      }
    }

    return successCount;
  }

  /// 提取关键词
  List<String> _extractKeywords(List<TestExecutionRecord> records) {
    final allKeywords = <String>[];

    // 收集所有关键词（保留重复）
    for (final record in records) {
      allKeywords.addAll(record.failureKeywords);
    }

    // 如果没有关键词，返回空列表
    if (allKeywords.isEmpty) {
      return [];
    }

    // 统计关键词出现次数
    final keywordCounts = <String, int>{};
    for (final keyword in allKeywords) {
      keywordCounts[keyword] = (keywordCounts[keyword] ?? 0) + 1;
    }

    // 返回至少出现一定次数的关键词
    final minCount = (records.length / 2).ceil().clamp(1, records.length);
    final frequentKeywords = keywordCounts.entries
        .where((e) => e.value >= minCount)
        .map((e) => e.key)
        .toList();

    // 如果仍然没有关键词，返回最常见的几个
    if (frequentKeywords.isEmpty && keywordCounts.isNotEmpty) {
      final sortedEntries = keywordCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return sortedEntries.take(3).map((e) => e.key).toList();
    }

    return frequentKeywords;
  }

  /// 计算置信度
  double _calculateConfidence(
    int occurrenceCount,
    int successCount,
    int keywordCount,
  ) {
    // 基于出现次数的置信度
    final occurrenceScore = (occurrenceCount / 10).clamp(0.0, 0.5);

    // 基于成功率的置信度
    final successRate = occurrenceCount > 0 ? successCount / occurrenceCount : 0;
    final successScore = successRate * 0.3;

    // 基于关键词数量的置信度
    final keywordScore = (keywordCount / 5).clamp(0.0, 0.2);

    return (occurrenceScore + successScore + keywordScore).clamp(0.0, 1.0);
  }

  /// 确定推荐策略
  String _determineRecommendedStrategy(
    String groupName,
    List<TestExecutionRecord> records,
  ) {
    // 根据失败类型推荐策略
    if (groupName.contains('超时') || groupName.contains('Timeout')) {
      return 'wait';
    }
    if (groupName.contains('元素未找到') || groupName.contains('not found')) {
      return 'wait';
    }
    if (groupName.contains('网络') || groupName.contains('Network')) {
      return 'retry';
    }
    if (groupName.contains('选择器') || groupName.contains('selector')) {
      return 'selectorUpdate';
    }

    return 'retry';
  }

  /// 生成描述
  String _generateDescription(String groupName, List<String> keywords) {
    return '在"$groupName"场景中，当出现${keywords.take(3).join('、')}等关键词时触发';
  }

  /// 获取所有模式
  List<FailurePattern> getPatterns() {
    return List.unmodifiable(_patterns);
  }

  /// 根据错误消息匹配模式
  List<FailurePattern> matchPatterns(String errorMessage) {
    return _patterns.where((p) => p.matches(errorMessage)).toList();
  }

  /// 获取推荐的愈合策略
  String? getRecommendedStrategy(String errorMessage) {
    final matchedPatterns = matchPatterns(errorMessage);

    if (matchedPatterns.isEmpty) {
      return null;
    }

    // 返回置信度最高的模式的推荐策略
    matchedPatterns.sort((a, b) => b.confidence.compareTo(a.confidence));
    return matchedPatterns.first.recommendedStrategy;
  }

  /// 添加自定义模式
  void addPattern(FailurePattern pattern) {
    _patterns.add(pattern);
  }

  /// 更新模式统计
  void updatePatternStats(String patternId, {bool success = true}) {
    final index = _patterns.indexWhere((p) => p.id == patternId);
    if (index >= 0) {
      _patterns[index] = _patterns[index].withOccurrence(success: success);
    }
  }

  /// 导出模式为 JSON
  String exportPatternsToJson({bool pretty = true}) {
    final data = {
      'patterns': _patterns.map((p) => p.toJson()).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
      'totalPatterns': _patterns.length,
    };

    return pretty
        ? const JsonEncoder.withIndent('  ').convert(data)
        : jsonEncode(data);
  }

  /// 打印模式摘要
  void printPatternSummary() {
    if (_patterns.isEmpty) {
      print('暂无学习到的模式');
      return;
    }

    print('\n📊 学习到的失败模式');
    print('━' * 60);
    print('总模式数: ${_patterns.length}');

    for (final pattern in _patterns.take(10)) {
      print('\n${pattern.name}');
      print('  出现次数: ${pattern.occurrenceCount}');
      print('  成功率: ${(pattern.successRate * 100).toStringAsFixed(0)}%');
      print('  置信度: ${(pattern.confidence * 100).toStringAsFixed(0)}%');
      print('  推荐策略: ${pattern.recommendedStrategy}');
      print('  触发词: ${pattern.triggerKeywords.take(3).join(', ')}');
    }

    if (_patterns.length > 10) {
      print('\n... 还有 ${_patterns.length - 10} 个模式');
    }

    print('━' * 60);
  }
}
