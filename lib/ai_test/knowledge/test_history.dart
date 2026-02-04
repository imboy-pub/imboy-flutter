/// 测试历史记录
library;

import 'dart:convert';
import 'dart:math';

/// 测试执行记录
class TestExecutionRecord {
  /// 记录 ID
  final String id;

  /// 测试名称
  final String testName;

  /// 执行时间
  final DateTime timestamp;

  /// 是否成功
  final bool success;

  /// 执行时长（毫秒）
  final int duration;

  /// 失败信息
  final String? failureMessage;

  /// 堆栈跟踪
  final String? stackTrace;

  /// 相关愈合会话 ID
  final String? healingSessionId;

  /// 测试类型
  final String testType;

  /// 测试标签
  final List<String> tags;

  /// 额外数据
  final Map<String, dynamic> metadata;

  TestExecutionRecord({
    required this.id,
    required this.testName,
    required this.timestamp,
    required this.success,
    required this.duration,
    this.failureMessage,
    this.stackTrace,
    this.healingSessionId,
    this.testType = 'integration',
    this.tags = const [],
    this.metadata = const {},
  });

  /// 创建成功记录
  factory TestExecutionRecord.success({
    required String testName,
    required int duration,
    String testType = 'integration',
    List<String> tags = const [],
    Map<String, dynamic> metadata = const {},
  }) {
    return TestExecutionRecord(
      id: _generateId(),
      testName: testName,
      timestamp: DateTime.now(),
      success: true,
      duration: duration,
      testType: testType,
      tags: tags,
      metadata: metadata,
    );
  }

  /// 创建失败记录
  factory TestExecutionRecord.failure({
    required String testName,
    required int duration,
    required String failureMessage,
    String? stackTrace,
    String? healingSessionId,
    String testType = 'integration',
    List<String> tags = const [],
    Map<String, dynamic> metadata = const {},
  }) {
    return TestExecutionRecord(
      id: _generateId(),
      testName: testName,
      timestamp: DateTime.now(),
      success: false,
      duration: duration,
      failureMessage: failureMessage,
      stackTrace: stackTrace,
      healingSessionId: healingSessionId,
      testType: testType,
      tags: tags,
      metadata: metadata,
    );
  }

  /// 生成 ID
  static String _generateId() {
    return 'test_${DateTime.now().millisecondsSinceEpoch}_${_randomString(6)}';
  }

  /// 生成随机字符串
  static String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().microsecondsSinceEpoch.toInt();
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(chars[(random + i) % chars.length]);
    }
    return buffer.toString();
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'testName': testName,
      'timestamp': timestamp.toIso8601String(),
      'success': success,
      'duration': duration,
      'failureMessage': failureMessage,
      'stackTrace': stackTrace,
      'healingSessionId': healingSessionId,
      'testType': testType,
      'tags': tags,
      'metadata': metadata,
    };
  }

  /// 从 JSON 创建
  factory TestExecutionRecord.fromJson(Map<String, dynamic> json) {
    return TestExecutionRecord(
      id: json['id'] as String,
      testName: json['testName'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      success: json['success'] as bool,
      duration: json['duration'] as int,
      failureMessage: json['failureMessage'] as String?,
      stackTrace: json['stackTrace'] as String?,
      healingSessionId: json['healingSessionId'] as String?,
      testType: json['testType'] as String? ?? 'integration',
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  /// 获取失败关键词
  List<String> get failureKeywords {
    if (success || failureMessage == null) {
      return const [];
    }

    final keywords = <String>[];
    final message = failureMessage!.toLowerCase();

    // 常见失败关键词
    final commonKeywords = [
      'timeout',
      'element not found',
      'assertion',
      'network',
      'permission',
      'selector',
      'state',
      'null',
      'undefined',
      'error',
      'exception',
    ];

    for (final keyword in commonKeywords) {
      if (message.contains(keyword)) {
        keywords.add(keyword);
      }
    }

    return keywords;
  }

  @override
  String toString() =>
      'TestExecutionRecord($testName, ${success ? "成功" : "失败"}, ${duration}ms)';
}

/// 测试历史存储
class TestHistoryStorage {
  final List<TestExecutionRecord> _records = [];

  /// 构造函数
  TestHistoryStorage();

  /// 添加记录
  void addRecord(TestExecutionRecord record) {
    _records.add(record);
  }

  /// 批量添加记录
  void addRecords(List<TestExecutionRecord> records) {
    _records.addAll(records);
  }

  /// 获取所有记录
  List<TestExecutionRecord> getRecords() {
    return List.unmodifiable(_records);
  }

  /// 获取成功的记录
  List<TestExecutionRecord> getSuccessRecords() {
    return _records.where((r) => r.success).toList();
  }

  /// 获取失败的记录
  List<TestExecutionRecord> getFailureRecords() {
    return _records.where((r) => !r.success).toList();
  }

  /// 按测试名称获取记录
  List<TestExecutionRecord> getRecordsByTestName(String testName) {
    return _records.where((r) => r.testName == testName).toList();
  }

  /// 按标签获取记录
  List<TestExecutionRecord> getRecordsByTag(String tag) {
    return _records.where((r) => r.tags.contains(tag)).toList();
  }

  /// 获取最近的记录
  List<TestExecutionRecord> getRecentRecords(int count) {
    final sorted = List<TestExecutionRecord>.from(_records)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(count).toList();
  }

  /// 获取统计信息
  Map<String, dynamic> getStatistics() {
    final total = _records.length;
    final success = _records.where((r) => r.success).length;
    final failure = total - success;
    final successRate = total > 0 ? (success / total * 100).round() : 0;

    // 按测试类型统计
    final typeStats = <String, int>{};
    for (final record in _records) {
      typeStats[record.testType] = (typeStats[record.testType] ?? 0) + 1;
    }

    // 按标签统计
    final tagStats = <String, int>{};
    for (final record in _records) {
      for (final tag in record.tags) {
        tagStats[tag] = (tagStats[tag] ?? 0) + 1;
      }
    }

    return {
      'total': total,
      'success': success,
      'failure': failure,
      'successRate': successRate,
      'byType': typeStats,
      'byTag': tagStats,
    };
  }

  /// 获取失败频率最高的测试
  List<Map<String, dynamic>> getMostFailingTests(int limit) {
    final failureCounts = <String, int>{};

    for (final record in _records) {
      if (!record.success) {
        failureCounts[record.testName] = (failureCounts[record.testName] ?? 0) + 1;
      }
    }

    final sorted = failureCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) => {
      'testName': e.key,
      'failureCount': e.value,
    }).toList();
  }

  /// 清空历史
  void clear() {
    _records.clear();
  }

  /// 导出为 JSON
  String exportToJson({bool pretty = true}) {
    final data = {
      'records': _records.map((r) => r.toJson()).toList(),
      'statistics': getStatistics(),
      'exportedAt': DateTime.now().toIso8601String(),
    };

    return pretty
        ? const JsonEncoder.withIndent('  ').convert(data)
        : jsonEncode(data);
  }

  /// 从 JSON 导入
  factory TestHistoryStorage.fromJson(String jsonString) {
    final storage = TestHistoryStorage();
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    final recordsList = json['records'] as List?;

    if (recordsList != null) {
      for (final recordJson in recordsList) {
        storage.addRecord(TestExecutionRecord.fromJson(recordJson as Map<String, dynamic>));
      }
    }

    return storage;
  }
}
