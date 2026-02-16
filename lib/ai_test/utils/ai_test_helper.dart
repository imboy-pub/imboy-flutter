/// AI 测试工具类
library;

import 'dart:convert';
import 'dart:io';
// ignore: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import '../intent/intent_parser.dart';

/// AI 测试工具类
class AITestHelper {
  final IntentParser _parser;

  AITestHelper() : _parser = IntentParser();

  /// 从文本文件读取用户故事并生成测试
  Future<List<GeneratedTestCase>> fromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('文件不存在: $filePath');
    }

    final userStory = await file.readAsString();
    return await _parser.parseFromUserStory(userStory);
  }

  /// 从字符串生成测试
  Future<List<GeneratedTestCase>> fromString(String userStory) async {
    return await _parser.parseFromUserStory(userStory);
  }

  /// 生成测试并导出为 JSON 文件
  Future<void> generateAndExport(
    String userStory,
    String outputPath, {
    bool pretty = true,
  }) async {
    final tests = await fromString(userStory);
    final json = _exportTestsToJson(tests, pretty: pretty);

    final file = File(outputPath);
    await file.writeAsString(json);
    print('✅ 测试用例已导出到: $outputPath');
    print('   共生成 ${tests.length} 个测试用例');
  }

  /// 导出测试用例为 JSON
  String _exportTestsToJson(List<GeneratedTestCase> tests, {bool pretty = true}) {
    final json = {
      'test_cases': tests.map((t) => t.toJson()).toList(),
      'generated_at': DateTime.now().toIso8601String(),
      'total_count': tests.length,
      'metadata': {
        'version': '1.0.0',
        'framework': 'AI Test Framework',
      }
    };
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(json)
        : jsonEncode(json);
  }

  /// 从 JSON 导入测试用例
  Future<List<GeneratedTestCase>> importTestsFromJson(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('文件不存在: $filePath');
    }

    final jsonString = await file.readAsString();
    return IntentParser.importFromJson(jsonString);
  }

  /// 统计测试用例
  Map<String, dynamic> statistics(List<GeneratedTestCase> tests) {
    final typeCount = <String, int>{};
    final priorityCount = <String, int>{};

    for (final test in tests) {
      typeCount[test.type] = (typeCount[test.type] ?? 0) + 1;
      priorityCount[test.priority] = (priorityCount[test.priority] ?? 0) + 1;
    }

    return {
      'total': tests.length,
      'by_type': typeCount,
      'by_priority': priorityCount,
      'average_steps': tests.isEmpty
          ? 0
          : tests.fold<int>(0, (sum, t) => sum + t.steps.length) / tests.length,
    };
  }

  /// 打印测试用例摘要
  void printSummary(List<GeneratedTestCase> tests) {
    print('\n📊 测试用例摘要');
    print('━' * 60);
    print('总数: ${tests.length}');

    final stats = statistics(tests);
    print('\n按类型:');
    stats['by_type'].forEach((type, count) {
      print('  $type: $count');
    });

    print('\n按优先级:');
    stats['by_priority'].forEach((priority, count) {
      print('  $priority: $count');
    });

    print('\n平均步骤数: ${stats['average_steps'].toStringAsFixed(1)}');
    print('━' * 60);

    for (final test in tests) {
      print('  • ${test.name} (${test.type}, ${test.priority})');
    }
  }

  /// 验证测试用例质量
  List<String> validateQuality(List<GeneratedTestCase> tests) {
    final issues = <String>[];

    for (final test in tests) {
      // 检查名称
      if (test.name.trim().isEmpty) {
        issues.add('测试 #${tests.indexOf(test) + 1}: 缺少名称');
      }

      // 检查描述
      if (test.description.trim().isEmpty) {
        issues.add('${test.name}: 缺少描述');
      }

      // 检查步骤
      if (test.steps.isEmpty) {
        issues.add('${test.name}: 没有测试步骤');
      }

      // 检查类型
      if (!['normal', 'edge', 'error'].contains(test.type)) {
        issues.add('${test.name}: 无效的测试类型 "${test.type}"');
      }

      // 检查优先级
      if (!['high', 'medium', 'low'].contains(test.priority)) {
        issues.add('${test.name}: 无效的优先级 "${test.priority}"');
      }
    }

    return issues;
  }
}
