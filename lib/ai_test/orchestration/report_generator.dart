/// 报告生成器 - 生成各种格式的测试报告
library;

import 'dart:convert';
import 'dart:io';

import 'test_execution_result.dart';

/// 报告格式
enum ReportFormat {
  /// JSON
  json,

  /// Markdown
  markdown,

  /// HTML
  html,

  /// 纯文本
  text,
}

/// 测试报告
class TestReport {
  /// 报告 ID
  final String id;

  /// 生成时间
  final DateTime generatedAt;

  /// 测试结果
  final List<TestExecutionResult> results;

  /// 统计摘要
  final Map<String, dynamic> summary;

  /// 覆盖率信息
  final Map<String, dynamic>? coverage;

  /// 性能指标
  final Map<String, dynamic>? performance;

  /// 建议
  final List<String> suggestions;

  /// 报告格式
  final ReportFormat format;

  /// 元数据
  final Map<String, dynamic> metadata;

  const TestReport({
    required this.id,
    required this.generatedAt,
    required this.results,
    required this.summary,
    this.coverage,
    this.performance,
    this.suggestions = const [],
    this.format = ReportFormat.json,
    this.metadata = const {},
  });

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'generatedAt': generatedAt.toIso8601String(),
      'results': results.map((r) => r.toJson()).toList(),
      'summary': summary,
      'coverage': coverage,
      'performance': performance,
      'suggestions': suggestions,
      'format': format.name,
      'metadata': metadata,
    };
  }
}

/// 报告生成器
class ReportGenerator {
  /// 生成摘要报告
  TestReport generateSummaryReport(List<TestExecutionResult> results) {
    final summary = _generateSummary(results);

    return TestReport(
      id: 'report_${DateTime.now().millisecondsSinceEpoch}',
      generatedAt: DateTime.now(),
      results: results,
      summary: summary,
    );
  }

  /// 生成详细报告
  TestReport generateDetailedReport(List<TestExecutionResult> results) {
    final summary = _generateSummary(results);
    final performance = _generatePerformanceReport(results);
    final suggestions = _generateSuggestions(results, summary);

    return TestReport(
      id: 'report_${DateTime.now().millisecondsSinceEpoch}',
      generatedAt: DateTime.now(),
      results: results,
      summary: summary,
      performance: performance,
      suggestions: suggestions,
      format: ReportFormat.json,
    );
  }

  /// 生成统计摘要
  Map<String, dynamic> _generateSummary(List<TestExecutionResult> results) {
    if (results.isEmpty) {
      return {
        'totalTests': 0,
        'passed': 0,
        'failed': 0,
        'skipped': 0,
        'successRate': 0.0,
        'totalDuration': 0,
      };
    }

    final passed = results.where((r) => r.isSuccess).length;
    final failed = results.where((r) => r.isFailure).length;
    final totalDuration = results.fold<Duration>(
      Duration.zero,
      (sum, r) => sum + r.duration,
    );

    // 统计错误类型
    final errorCounts = <TestErrorType, int>{};
    for (final result in results) {
      for (final error in result.errors) {
        errorCounts[error.type] = (errorCounts[error.type] ?? 0) + 1;
      }
    }

    return {
      'totalTests': results.length,
      'passed': passed,
      'failed': failed,
      'skipped':
          results.where((r) => r.status == TestExecutionStatus.skipped).length,
      'successRate': passed / results.length,
      'totalDuration': totalDuration.inSeconds,
      'averageDuration':
          totalDuration.inMilliseconds ~/ results.length,
      'errorCounts': errorCounts.map(
        (k, v) => MapEntry(k.name, v),
      ),
    };
  }

  /// 生成性能报告
  Map<String, dynamic> _generatePerformanceReport(
    List<TestExecutionResult> results,
  ) {
    if (results.isEmpty) {
      return {
        'totalOperations': 0,
        'averageDuration': 0.0,
        'slowestTest': null,
      };
    }

    // 找出最慢的测试
    results.sort((a, b) => b.duration.compareTo(a.duration));
    final slowest = results.first;

    // 计算平均耗时
    final totalDuration = results.fold<int>(
      0,
      (sum, r) => sum + r.duration.inMilliseconds,
    );
    final avgDuration = totalDuration / results.length;

    // 性能分布
    final fastTests = results.where((r) => r.duration.inMilliseconds < 1000).length;
    final mediumTests =
        results.where((r) => r.duration.inMilliseconds >= 1000 && r.duration.inMilliseconds < 5000).length;
    final slowTests = results.where((r) => r.duration.inMilliseconds >= 5000).length;

    return {
      'totalOperations': results.length,
      'averageDuration': avgDuration.round(),
      'slowestTest': {
        'taskId': slowest.taskId,
        'description': slowest.taskDescription,
        'duration': slowest.duration.inMilliseconds,
      },
      'performanceDistribution': {
        'fast': fastTests,
        'medium': mediumTests,
        'slow': slowTests,
      },
    };
  }

  /// 生成建议
  List<String> _generateSuggestions(
    List<TestExecutionResult> results,
    Map<String, dynamic> summary,
  ) {
    final suggestions = <String>[];

    final successRate = summary['successRate'] as double;
    final failedCount = summary['failed'] as int;

    // 成功率建议
    if (successRate < 0.5) {
      suggestions.add('成功率低于 50%，需要立即检查测试环境和被测应用');
    } else if (successRate < 0.8) {
      suggestions.add('成功率低于 80%，建议修复失败的测试用例');
    } else if (successRate < 0.95) {
      suggestions.add('成功率 ${(successRate * 100).toStringAsFixed(0)}%，有几条测试偶尔失败，建议检查不稳定性');
    }

    // 失败测试建议
    if (failedCount > 0) {
      final failedResults = results.where((r) => r.isFailure).toList();
      final errorTypes = <String>{};
      for (final result in failedResults) {
        for (final error in result.errors) {
          errorTypes.add(error.type.name);
        }
      }
      suggestions.add(
        '检测到以下错误类型: ${errorTypes.join(', ')}，'
        '建议针对性优化',
      );
    }

    // 性能建议
    final avgDuration = summary['averageDuration'] as int;
    if (avgDuration > 5000) {
      suggestions.add('平均测试耗时 ${avgDuration}ms，建议优化测试性能或并行执行');
    }

    return suggestions;
  }

  /// 导出为 JSON
  String exportToJson(TestReport report) {
    return jsonEncode(report.toJson());
  }

  /// 导出为 Markdown
  String exportToMarkdown(TestReport report) {
    final buffer = StringBuffer();

    // 标题
    buffer.writeln('# AI 测试报告');
    buffer.writeln('');
    buffer.writeln('**生成时间**: ${report.generatedAt}');
    buffer.writeln('**报告 ID**: ${report.id}');
    buffer.writeln('');

    // 摘要
    buffer.writeln('## 📊 测试摘要');
    buffer.writeln('');
    final summary = report.summary;
    buffer.writeln('| 指标 | 数值 |');
    buffer.writeln('|------|------|');
    buffer.writeln(
      '| 总测试数 | ${summary['totalTests']} |',
    );
    buffer.writeln(
      '| 通过数 | ${summary['passed']} ✅ |',
    );
    buffer.writeln(
      '| 失败数 | ${summary['failed']} ❌ |',
    );
    buffer.writeln(
      '| 跳过数 | ${summary['skipped']} ⏭️ |',
    );
    buffer.writeln(
      '| 成功率 | ${((summary['successRate'] as double) * 100).toStringAsFixed(1)}% |',
    );
    buffer.writeln(
      '| 总耗时 | ${summary['totalDuration']}s |',
    );
    buffer.writeln(
      '| 平均耗时 | ${summary['averageDuration']}ms |',
    );
    buffer.writeln('');

    // 性能
    if (report.performance != null) {
      buffer.writeln('## ⚡ 性能分析');
      buffer.writeln('');
      final perf = report.performance!;
      buffer.writeln(
      '- 平均耗时: ${perf['averageDuration']}ms',
    );
      if (perf['slowestTest'] != null) {
        final slowest = perf['slowestTest'] as Map<String, dynamic>;
        buffer.writeln(
          '- 最慢测试: ${slowest['description']} (${slowest['duration']}ms)',
        );
      }
      buffer.writeln('');
    }

    // 建议
    if (report.suggestions.isNotEmpty) {
      buffer.writeln('## 💡 建议');
      buffer.writeln('');
      for (var i = 0; i < report.suggestions.length; i++) {
        buffer.writeln('${i + 1}. ${report.suggestions[i]}');
      }
      buffer.writeln('');
    }

    // 详细结果
    buffer.writeln('## 📋 详细结果');
    buffer.writeln('');

    for (final result in report.results) {
      final status = result.isSuccess ? '✅' : '❌';
      buffer.writeln('### $status ${result.taskDescription}');
      buffer.writeln('');
      buffer.writeln('- **任务 ID**: ${result.taskId}');
      buffer.writeln('- **意图**: ${result.intent}');
      buffer.writeln('- **状态**: ${result.status.name}');
      buffer.writeln('- **耗时**: ${result.duration.inMilliseconds}ms');
      buffer.writeln(
        '- **成功率**: ${(result.successRate * 100).toStringAsFixed(1)}%',
      );

      if (result.hasErrors) {
        buffer.writeln('');
        buffer.writeln('**错误**:');
        for (final error in result.errors.where((e) => !e.isFixed)) {
          buffer.writeln('  - ${error.type.name}: ${error.message}');
        }
      }

      buffer.writeln('');
    }

    return buffer.toString();
  }

  /// 导出为 HTML
  String exportToHtml(TestReport report) {
    final summary = report.summary;
    final successRate = (summary['successRate'] as double) * 100;

    return '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AI 测试报告 - ${report.id}</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f5f5f5;
            padding: 20px;
            line-height: 1.6;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
        }
        .header h1 {
            font-size: 28px;
            margin-bottom: 10px;
        }
        .header .meta {
            opacity: 0.9;
            font-size: 14px;
        }
        .content {
            padding: 30px;
        }
        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .stat-card {
            background: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            text-align: center;
        }
        .stat-card .value {
            font-size: 32px;
            font-weight: bold;
            color: #667eea;
        }
        .stat-card .label {
            color: #6c757d;
            font-size: 14px;
            margin-top: 5px;
        }
        .stat-card.success .value { color: #28a745; }
        .stat-card.danger .value { color: #dc3545; }
        .section {
            margin-bottom: 30px;
        }
        .section h2 {
            font-size: 20px;
            margin-bottom: 15px;
            color: #333;
        }
        .suggestions {
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 15px;
            border-radius: 4px;
        }
        .suggestions ol {
            margin-left: 20px;
        }
        .suggestions li {
            margin-bottom: 8px;
        }
        .test-result {
            border: 1px solid #e9ecef;
            border-radius: 8px;
            margin-bottom: 15px;
            overflow: hidden;
        }
        .test-result .header {
            background: #f8f9fa;
            padding: 15px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .test-result.success .header {
            border-left: 4px solid #28a745;
        }
        .test-result.failed .header {
            border-left: 4px solid #dc3545;
        }
        .test-result .body {
            padding: 15px;
        }
        .badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: bold;
        }
        .badge.success { background: #d4edda; color: #155724; }
        .badge.failed { background: #f8d7da; color: #721c24; }
        .badge.pending { background: #fff3cd; color: #856404; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🤖 AI 测试报告</h1>
            <div class="meta">
                生成时间: ${report.generatedAt.toIso8601String()} |
                报告 ID: ${report.id}
            </div>
        </div>

        <div class="content">
            <div class="summary">
                <div class="stat-card">
                    <div class="value">${summary['totalTests']}</div>
                    <div class="label">总测试数</div>
                </div>
                <div class="stat-card success">
                    <div class="value">${summary['passed']}</div>
                    <div class="label">通过</div>
                </div>
                <div class="stat-card danger">
                    <div class="value">${summary['failed']}</div>
                    <div class="label">失败</div>
                </div>
                <div class="stat-card">
                    <div class="value">${successRate.toStringAsFixed(1)}%</div>
                    <div class="label">成功率</div>
                </div>
            </div>

            ${report.suggestions.isNotEmpty ? '''
            <div class="section">
                <h2>💡 建议</h2>
                <div class="suggestions">
                    <ol>
                        ${report.suggestions.map((s) => '<li>$s</li>').join('')}
                    </ol>
                </div>
            </div>
            ''' : ''}

            <div class="section">
                <h2>📋 测试详情</h2>
                ${report.results.map((r) => '''
                <div class="test-result ${r.isSuccess ? 'success' : 'failed'}">
                    <div class="header">
                        <span>${r.taskDescription}</span>
                        <span class="badge ${r.isSuccess ? 'success' : 'failed'}">
                            ${r.isSuccess ? '✅ 通过' : '❌ 失败'}
                        </span>
                    </div>
                    <div class="body">
                        <p><strong>任务 ID:</strong> ${r.taskId}</p>
                        <p><strong>意图:</strong> ${r.intent}</p>
                        <p><strong>耗时:</strong> ${r.duration.inMilliseconds}ms</p>
                        <p><strong>成功率:</strong> ${(r.successRate * 100).toStringAsFixed(1)}%</p>
                        ${r.hasErrors ? '''
                        <p style="color: #dc3545;"><strong>错误:</strong></p>
                        <ul>
                            ${r.errors.where((e) => !e.isFixed).map((e) => '<li>${e.type.name}: ${e.message}</li>').join('')}
                        </ul>
                        ''' : ''}
                    </div>
                </div>
                ''').join('')}
            </div>
        </div>
    </div>
</body>
</html>
''';
  }

  /// 导出为纯文本
  String exportToText(TestReport report) {
    final buffer = StringBuffer();

    buffer.writeln('═' * 60);
    buffer.writeln('  AI 测试报告');
    buffer.writeln('═' * 60);
    buffer.writeln('生成时间: ${report.generatedAt}');
    buffer.writeln('报告 ID: ${report.id}');
    buffer.writeln('');

    buffer.writeln('─' * 60);
    buffer.writeln('  测试摘要');
    buffer.writeln('─' * 60);
    final summary = report.summary;
    buffer.writeln('总测试数: ${summary['totalTests']}');
    buffer.writeln('通过数: ${summary['passed']} ✅');
    buffer.writeln('失败数: ${summary['failed']} ❌');
    buffer.writeln('跳过数: ${summary['skipped']} ⏭️');
    final successRate = summary['successRate'] as num?;
    buffer.writeln('成功率: ${successRate != null ? (successRate * 100).toStringAsFixed(1) : 'N/A'}%');
    buffer.writeln('总耗时: ${summary['totalDuration']}s');
    buffer.writeln('');

    if (report.suggestions.isNotEmpty) {
      buffer.writeln('─' * 60);
      buffer.writeln('  建议');
      buffer.writeln('─' * 60);
      for (var i = 0; i < report.suggestions.length; i++) {
        buffer.writeln('${i + 1}. ${report.suggestions[i]}');
      }
      buffer.writeln('');
    }

    buffer.writeln('─' * 60);
    buffer.writeln('  测试详情');
    buffer.writeln('─' * 60);
    for (final result in report.results) {
      final status = result.isSuccess ? '✅ 通过' : '❌ 失败';
      buffer.writeln('');
      buffer.writeln('$status ${result.taskDescription}');
      buffer.writeln('  任务 ID: ${result.taskId}');
      buffer.writeln('  意图: ${result.intent}');
      buffer.writeln('  耗时: ${result.duration.inMilliseconds}ms');
      buffer.writeln('  成功率: ${(result.successRate * 100).toStringAsFixed(1)}%');
      if (result.hasErrors) {
        buffer.writeln('  错误:');
        for (final error in result.errors.where((e) => !e.isFixed)) {
          buffer.writeln('    - ${error.type.name}: ${error.message}');
        }
      }
    }

    return buffer.toString();
  }

  /// 导出到文件
  Future<File> exportToFile(
    TestReport report,
    String basePath,
    ReportFormat format,
  ) async {
    String content;
    String extension;

    switch (format) {
      case ReportFormat.json:
        content = exportToJson(report);
        extension = 'json';
        break;
      case ReportFormat.markdown:
        content = exportToMarkdown(report);
        extension = 'md';
        break;
      case ReportFormat.html:
        content = exportToHtml(report);
        extension = 'html';
        break;
      case ReportFormat.text:
        content = exportToText(report);
        extension = 'txt';
        break;
    }

    final filePath = '$basePath.$extension';
    final file = File(filePath);
    await file.writeAsString(content);

    return file;
  }
}
