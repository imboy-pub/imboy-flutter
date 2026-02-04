/// 相似度匹配器
library;

import 'dart:convert';
import 'dart:math';
import 'test_history.dart';
import '../healing/failure_analyzer.dart';

/// 相似度匹配结果
class SimilarityMatch {
  /// 匹配的记录
  final TestExecutionRecord record;

  /// 相似度分数 (0.0 - 1.0)
  final double score;

  /// 匹配原因
  final String reason;

  /// 推荐的修复方案
  final String? recommendedFix;

  /// 是否使用了愈合
  final bool wasHealed;

  const SimilarityMatch({
    required this.record,
    required this.score,
    required this.reason,
    this.recommendedFix,
    this.wasHealed = false,
  });

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'record': record.toJson(),
      'score': score,
      'reason': reason,
      'recommendedFix': recommendedFix,
      'wasHealed': wasHealed,
    };
  }

  @override
  String toString() =>
      'SimilarityMatch(${(score * 100).toStringAsFixed(0)}%, $reason)';
}

/// 相似度匹配器
class SimilarityMatcher {
  final TestHistoryStorage _history;

  SimilarityMatcher({TestHistoryStorage? history})
      : _history = history ?? TestHistoryStorage();

  /// 查找相似的失败记录
  List<SimilarityMatch> findSimilarFailures({
    required String testName,
    required String errorMessage,
    String? stackTrace,
    int maxResults = 5,
    double minScore = 0.3,
  }) {
    final matches = <SimilarityMatch>[];

    // 获取所有失败的记录
    final failureRecords = _history.getFailureRecords();

    for (final record in failureRecords) {
      // 跳过同一测试的记录（避免匹配自己）
      if (record.testName == testName &&
          record.timestamp.isAfter(DateTime.now().subtract(const Duration(minutes: 1)))) {
        continue;
      }

      // 计算相似度
      final score = _calculateSimilarity(
        testName: testName,
        errorMessage: errorMessage,
        record: record,
      );

      if (score >= minScore) {
        matches.add(SimilarityMatch(
          record: record,
          score: score,
          reason: _generateMatchReason(score, record),
          recommendedFix: _extractRecommendedFix(record),
          wasHealed: record.healingSessionId != null,
        ));
      }
    }

    // 按相似度排序
    matches.sort((a, b) => b.score.compareTo(a.score));

    return matches.take(maxResults).toList();
  }

  /// 查找成功解决方案
  List<String> findSuccessfulSolutions(String errorMessage) {
    final solutions = <String>[];

    // 获取有愈合会话的失败记录
    final healedFailures = _history.getFailureRecords()
        .where((r) => r.healingSessionId != null)
        .toList();

    for (final record in healedFailures) {
      // 检查错误消息相似度
      if (_errorMessageSimilarity(errorMessage, record.failureMessage ?? '') > 0.5) {
        // 假设后续的同一测试的成功记录意味着愈合有效
        final testName = record.testName;
        final laterRecords = _history.getRecordsByTestName(testName)
            .where((r) => r.timestamp.isAfter(record.timestamp));

        for (final laterRecord in laterRecords) {
          if (laterRecord.success) {
            solutions.add(
              '${laterRecord.testName} 在 ${laterRecord.timestamp.difference(record.timestamp).inMinutes} 分钟后成功运行',
            );
            break;
          }
        }
      }
    }

    return solutions;
  }

  /// 计算相似度
  double _calculateSimilarity({
    required String testName,
    required String errorMessage,
    required TestExecutionRecord record,
  }) {
    var score = 0.0;

    // 1. 测试名称相似度 (30%)
    final nameSimilarity = _stringSimilarity(testName, record.testName);
    score += nameSimilarity * 0.3;

    // 2. 错误消息相似度 (50%)
    final errorSimilarity = _errorMessageSimilarity(
      errorMessage,
      record.failureMessage ?? '',
    );
    score += errorSimilarity * 0.5;

    // 3. 失败关键词匹配 (20%)
    final keywordScore = _keywordMatch(errorMessage);
    score += keywordScore * 0.2;

    return score.clamp(0.0, 1.0);
  }

  /// 字符串相似度（简化版 Jaccard）
  double _stringSimilarity(String str1, String str2) {
    final set1 = str1.toLowerCase().split(' ').toSet();
    final set2 = str2.toLowerCase().split(' ').toSet();

    if (set1.isEmpty && set2.isEmpty) {
      return 1.0;
    }
    if (set1.isEmpty || set2.isEmpty) {
      return 0.0;
    }

    final intersection = set1.intersection(set2).length;
    final union = set1.union(set2).length;

    return union > 0 ? intersection / union : 0.0;
  }

  /// 错误消息相似度
  double _errorMessageSimilarity(String error1, String error2) {
    if (error1 == error2) {
      return 1.0;
    }

    // 检查关键错误类型
    final errorTypes = [
      'TimeoutException',
      'Element not found',
      'AssertionError',
      'SocketException',
      'Permission denied',
    ];

    for (final type in errorTypes) {
      if (error1.contains(type) && error2.contains(type)) {
        return 0.8;
      }
    }

    // 检查选择器匹配
    final selector1 = _extractSelector(error1);
    final selector2 = _extractSelector(error2);
    if (selector1 != null && selector1 == selector2) {
      return 0.7;
    }

    // 默认使用字符串相似度
    return _stringSimilarity(error1, error2);
  }

  /// 提取选择器
  String? _extractSelector(String errorMessage) {
    // 尝试提取各种格式的选择器
    final patterns = [
      RegExp(r'''selector[:\s]+'([^']+)'''),
      RegExp(r'''key[:\s]+["']([^"']+)["']'''),
      RegExp(r'''find\.([^.]+)\([^)]*\)'''),
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

  /// 关键词匹配
  double _keywordMatch(String errorMessage) {
    final keywords = TestExecutionRecord(
      id: '',
      testName: '',
      timestamp: DateTime.now(),
      success: false,
      duration: 0,
      failureMessage: errorMessage,
    ).failureKeywords;

    // 如果有关键词，返回较高分数
    return keywords.isNotEmpty ? 0.7 : 0.0;
  }

  /// 生成匹配原因
  String _generateMatchReason(double score, TestExecutionRecord record) {
    final reasons = <String>[];

    if (score > 0.8) {
      reasons.add('高度相似');
    } else if (score > 0.6) {
      reasons.add('较为相似');
    } else {
      reasons.add('部分相似');
    }

    if (record.healingSessionId != null) {
      reasons.add('有愈合历史');
    }

    if (reasons.isEmpty) {
      reasons.add('基本匹配');
    }

    return reasons.join('，');
  }

  /// 提取推荐的修复方案
  String? _extractRecommendedFix(TestExecutionRecord record) {
    if (record.healingSessionId != null) {
      // 从愈合会话中提取修复信息
      return '使用愈合策略: ${record.metadata['strategy'] ?? '默认策略'}';
    }

    // 从元数据中提取
    return record.metadata['recommendedFix'] as String?;
  }
}
