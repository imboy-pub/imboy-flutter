/// AI 测试编排系统单元测试
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/ai_test/orchestration/test_orchestrator.dart';
import 'package:imboy/ai_test/orchestration/test_execution_result.dart';
import 'package:imboy/ai_test/orchestration/performance_monitor.dart';
import 'package:imboy/ai_test/orchestration/report_generator.dart';

void main() {
  group('编排系统 - 单元测试', () {
    late PerformanceMonitor monitor;
    late ReportGenerator generator;

    setUp(() {
      monitor = PerformanceMonitor();
      generator = ReportGenerator();
    });

    group('TestConfiguration', () {
      test('默认配置', () {
        final config = const TestConfiguration();

        expect(config.enableIntentParser, isTrue);
        expect(config.enableSelfHealing, isTrue);
        expect(config.enableKnowledgeBase, isTrue);
        expect(config.maxExecutionTime, equals(300));
        expect(config.coverageGoal, equals(0.8));
      });

      test('快速配置', () {
        final config = TestConfiguration.quick;

        expect(config.enablePathExplorer, isFalse);
        expect(config.enableHumanSimulation, isFalse);
        expect(config.generateDetailedReport, isFalse);
        expect(config.maxExecutionTime, equals(60));
      });

      test('完整配置', () {
        final config = TestConfiguration.full;

        expect(config.enableIntentParser, isTrue);
        expect(config.enablePathExplorer, isTrue);
        expect(config.enableHumanSimulation, isTrue);
        expect(config.maxExecutionTime, equals(600));
        expect(config.coverageGoal, equals(0.9));
      });
    });

    group('TestTask', () {
      test('创建任务', () {
        final task = const TestTask(
          id: 'task_1',
          description: '测试用户登录',
          intent: '验证用户能够使用正确的用户名和密码登录',
        );

        expect(task.id, equals('task_1'));
        expect(task.description, equals('测试用户登录'));
        expect(task.priority, equals(0.5));
        expect(task.timeout, equals(60));
      });

      test('创建高优先级任务', () {
        final task = const TestTask(
          id: 'critical_task',
          description: '关键路径测试',
          intent: '测试核心功能',
          priority: 0.9,
          timeout: 120,
          tags: ['critical', 'smoke'],
        );

        expect(task.priority, equals(0.9));
        expect(task.timeout, equals(120));
        expect(task.tags, contains('critical'));
      });
    });

    group('TestError', () {
      test('创建错误', () {
        final error = TestError(
          type: TestErrorType.execution,
          message: '元素未找到',
          stackTrace: '  at Test.main\n  at Test.run',
        );

        expect(error.type, equals(TestErrorType.execution));
        expect(error.message, equals('元素未找到'));
        expect(error.isFixed, isFalse);
      });

      test('JSON 序列化', () {
        final error = TestError(
          type: TestErrorType.assertion,
          message: '断言失败',
          errorCode: 'ASSERT_001',
        );

        final json = error.toJson();
        expect(json['type'], equals('assertion'));
        expect(json['message'], equals('断言失败'));
        expect(json['errorCode'], equals('ASSERT_001'));
      });

      test('修复错误', () {
        final error = TestError(
          type: TestErrorType.execution,
          message: '点击失败',
        );

        expect(error.isFixed, isFalse);
        error.isFixed = true;
        expect(error.isFixed, isTrue);
      });
    });

    group('HealingResult', () {
      test('创建自愈结果', () {
        final error = TestError(
          type: TestErrorType.execution,
          message: '元素未找到',
        );

        final result = HealingResult(
          success: true,
          originalError: error,
          solution: '使用备用选择器',
          appliedFix: '通过 data-testid 定位元素',
          healingDuration: const Duration(milliseconds: 500),
          confidence: 0.9,
        );

        expect(result.success, isTrue);
        expect(result.solution, equals('使用备用选择器'));
        expect(result.confidence, equals(0.9));
        expect(result.needsHumanIntervention, isFalse);
      });

      test('需要人工干预', () {
        final error = TestError(
          type: TestErrorType.execution,
          message: '复杂错误',
        );

        final result = HealingResult(
          success: false,
          originalError: error,
          healingDuration: const Duration(milliseconds: 100),
          needsHumanIntervention: true,
          confidence: 0.3,
        );

        expect(result.success, isFalse);
        expect(result.needsHumanIntervention, isTrue);
        expect(result.confidence, lessThan(0.5));
      });
    });

    group('TestExecutionResult', () {
      test('创建成功结果', () {
        final result = TestExecutionResult(
          taskId: 'task_1',
          taskDescription: '测试登录',
          intent: '验证登录功能',
          startedAt: DateTime.now(),
        );

        result.status = TestExecutionStatus.completed;
        result.completedAt = DateTime.now();
        result.duration = const Duration(seconds: 5);

        expect(result.isSuccess, isTrue);
        expect(result.isFailure, isFalse);
        expect(result.hasErrors, isFalse);
      });

      test('创建失败结果', () {
        final result = TestExecutionResult(
          taskId: 'task_2',
          taskDescription: '测试登录',
          intent: '验证登录功能',
          startedAt: DateTime.now(),
        );

        result.status = TestExecutionStatus.failed;
        result.errors.add(TestError(
          type: TestErrorType.execution,
          message: '登录失败',
        ));

        expect(result.isSuccess, isFalse);
        expect(result.isFailure, isTrue);
        expect(result.hasErrors, isTrue);
      });

      test('JSON 序列化', () {
        final result = TestExecutionResult(
          taskId: 'task_1',
          taskDescription: '测试',
          intent: '意图',
          startedAt: DateTime.now(),
          status: TestExecutionStatus.completed,
        );

        final json = result.toJson();
        expect(json['taskId'], equals('task_1'));
        expect(json['status'], equals('completed'));
      });
    });

    group('PerformanceMonitor', () {
      test('监控操作', () async {
        monitor.startOperation('test_operation');
        expect(monitor.isRunning, isTrue);
        expect(monitor.currentOperation, equals('test_operation'));

        // 添加微小延迟确保有可测量的时间
        await Future.delayed(const Duration(milliseconds: 1));
        monitor.endOperation('test_operation');
        expect(monitor.isRunning, isFalse);

        final metric = monitor.getMetric('test_operation');
        expect(metric, isNotNull);
        expect(metric!.isCompleted, isTrue);
        expect(metric.duration, greaterThanOrEqualTo(0));
      });

      test('获取性能指标', () {
        monitor.startOperation('op1');
        monitor.endOperation('op1');

        monitor.startOperation('op2');
        // 模拟一些处理
        for (var i = 0; i < 1000; i++) {}
        monitor.endOperation('op2');

        final metrics = monitor.getMetrics();
        expect(metrics, isNotEmpty);
        expect(metrics.containsKey('op1'), isTrue);
        expect(metrics.containsKey('op2'), isTrue);
      });

      test('计算总耗时', () async {
        monitor.startOperation('op1');
        await Future.delayed(const Duration(milliseconds: 1));
        monitor.endOperation('op1');

        monitor.startOperation('op2');
        await Future.delayed(const Duration(milliseconds: 1));
        monitor.endOperation('op2');

        final total = monitor.getTotalDuration();
        expect(total, greaterThanOrEqualTo(0));
      });

      test('获取最慢操作', () {
        monitor.startOperation('fast');
        monitor.endOperation('fast');

        monitor.startOperation('slow');
        // 模拟慢操作
        final stopwatch = Stopwatch()..start();
        while (stopwatch.elapsedMilliseconds < 10) {}
        stopwatch.stop();
        monitor.endOperation('slow');

        final slowest = monitor.getSlowestOperation();
        expect(slowest, isNotNull);
        expect(slowest!.operation, equals('slow'));
      });

      test('生成性能报告', () {
        monitor.startOperation('op1');
        monitor.endOperation('op1');

        monitor.startOperation('op2');
        monitor.endOperation('op2');

        final report = monitor.generateReport();
        expect(report['totalOperations'], equals(2));
        expect(report['operations'], isNotEmpty);
      });

      test('清空指标', () {
        monitor.startOperation('op');
        monitor.endOperation('op');

        expect(monitor.allMetrics, isNotEmpty);

        monitor.clear();
        expect(monitor.allMetrics, isEmpty);
      });
    });

    group('ReportGenerator', () {
      test('生成摘要报告', () {
        final results = [
          TestExecutionResult(
            taskId: 'task_1',
            taskDescription: '测试1',
            intent: '意图1',
            startedAt: DateTime.now(),
            status: TestExecutionStatus.completed,
          ),
          TestExecutionResult(
            taskId: 'task_2',
            taskDescription: '测试2',
            intent: '意图2',
            startedAt: DateTime.now(),
            status: TestExecutionStatus.completed,
          ),
        ];

        final report = generator.generateSummaryReport(results);

        expect(report, isNotNull);
        expect(report.results, equals(results));
        expect(report.summary['totalTests'], equals(2));
      });

      test('生成详细报告', () {
        final results = [
          TestExecutionResult(
            taskId: 'task_1',
            taskDescription: '测试',
            intent: '意图',
            startedAt: DateTime.now(),
            status: TestExecutionStatus.completed,
          ),
        ];

        final report = generator.generateDetailedReport(results);

        expect(report, isNotNull);
        expect(report.performance, isNotNull);
        expect(report.suggestions, isNotNull);
      });

      test('统计摘要计算', () {
        final now = DateTime.now();
        final results = [
          TestExecutionResult(
            taskId: 'task_1',
            taskDescription: '成功测试',
            intent: '意图',
            startedAt: now,
            status: TestExecutionStatus.completed,
          ),
          TestExecutionResult(
            taskId: 'task_2',
            taskDescription: '失败测试',
            intent: '意图',
            startedAt: now,
            status: TestExecutionStatus.failed,
            errors: [
              TestError(
                type: TestErrorType.execution,
                message: '错误',
              ),
            ],
          ),
        ];

        final report = generator.generateSummaryReport(results);
        final summary = report.summary;

        expect(summary['totalTests'], equals(2));
        expect(summary['passed'], equals(1));
        expect(summary['failed'], equals(1));
        expect(summary['successRate'], equals(0.5));
      });

      test('导出为 JSON', () {
        final report = TestReport(
          id: 'report_1',
          generatedAt: DateTime.now(),
          results: const [],
          summary: {'totalTests': 0},
        );

        final json = generator.exportToJson(report);
        expect(json, isNotEmpty);
        expect(json.contains('"id"'), isTrue);
        expect(json.contains('"report_1"'), isTrue);
      });

      test('导出为 Markdown', () {
        final report = TestReport(
          id: 'report_1',
          generatedAt: DateTime.now(),
          results: const [],
          summary: {
            'totalTests': 10,
            'passed': 8,
            'failed': 2,
            'successRate': 0.8,
            'totalDuration': 60,
          },
          suggestions: ['建议1', '建议2'],
        );

        final markdown = generator.exportToMarkdown(report);

        expect(markdown, contains('# AI 测试报告'));
        expect(markdown, contains('## 📊 测试摘要'));
        expect(markdown, contains('## 💡 建议'));
        expect(markdown, contains('建议1'));
      });

      test('导出为 HTML', () {
        final report = TestReport(
          id: 'report_1',
          generatedAt: DateTime.now(),
          results: const [],
          summary: {
            'totalTests': 10,
            'passed': 8,
            'failed': 2,
            'successRate': 0.8,
          },
        );

        final html = generator.exportToHtml(report);

        expect(html, contains('<!DOCTYPE html>'));
        expect(html, contains('AI 测试报告'));
        expect(html, contains('10')); // 检查实际值而不是键名
        expect(html, contains('success'));
      });

      test('导出为文本', () {
        final report = TestReport(
          id: 'report_1',
          generatedAt: DateTime.now(),
          results: const [],
          summary: {
            'totalTests': 10,
            'passed': 8,
            'failed': 2,
          },
        );

        final text = generator.exportToText(report);

        expect(text, contains('AI 测试报告'));
        expect(text, contains('测试摘要'));
        expect(text, contains('总测试数: 10'));
        expect(text, contains('通过数: 8'));
      });
    });

    group('AITestOrchestrator', () {
      late AITestOrchestrator orchestrator;

      setUp(() {
        orchestrator = AITestOrchestrator(
          config: TestConfiguration.quick,
        );
      });

      tearDown(() async {
        await orchestrator.dispose();
      });

      test('初始化组件', () {
        expect(orchestrator.config, isNotNull);
        expect(orchestrator.monitor, isNotNull);
        expect(orchestrator.knowledgeBase, isNotNull);
      });

      test('获取统计摘要（空历史）', () {
        final stats = orchestrator.getStatistics();

        expect(stats['totalTests'], equals(0));
        expect(stats['successRate'], equals(0.0));
        expect(stats['averageDuration'], equals(0));
      });

      test('执行简单任务', () async {
        final task = const TestTask(
          id: 'task_1',
          description: '简单测试',
          intent: '测试基本功能',
        );

        final result = await orchestrator.executeTask(task);

        expect(result, isNotNull);
        expect(result.taskId, equals('task_1'));
        expect(result.status, isNotNull);
      });

      test('批量执行任务', () async {
        final tasks = [
          const TestTask(
            id: 'task_1',
            description: '测试1',
            intent: '意图1',
            priority: 0.9,
          ),
          const TestTask(
            id: 'task_2',
            description: '测试2',
            intent: '意图2',
            priority: 0.5,
          ),
          const TestTask(
            id: 'task_3',
            description: '测试3',
            intent: '意图3',
            priority: 0.7,
          ),
        ];

        final results = await orchestrator.executeTasks(tasks);

        expect(results, hasLength(3));
        expect(results.every((r) => r.taskId.isNotEmpty), isTrue);
      });

      test('生成测试报告', () async {
        final task = const TestTask(
          id: 'task_1',
          description: '测试',
          intent: '意图',
        );

        await orchestrator.executeTask(task);
        final report = await orchestrator.generateReport();

        expect(report, isNotNull);
        expect(report.results, isNotEmpty);
        expect(report.summary, isNotNull);
      });

      test('获取智能建议', () {
        final suggestions = orchestrator.getSuggestions();

        expect(suggestions, isNotNull);
        // 由于没有执行历史，默认应该有成功率为 0% 的建议
        expect(suggestions.any((s) => s.contains('成功率')), isTrue);
      });

      test('清空执行历史', () async {
        final task = const TestTask(
          id: 'task_1',
          description: '测试',
          intent: '意图',
        );

        await orchestrator.executeTask(task);
        expect(orchestrator.executionHistory, isNotEmpty);

        orchestrator.clearHistory();
        expect(orchestrator.executionHistory, isEmpty);
      });
    });

    group('集成测试', () {
      late AITestOrchestrator orchestrator;

      setUp(() {
        orchestrator = AITestOrchestrator(
          config: TestConfiguration.full,
        );
      });

      tearDown(() async {
        await orchestrator.dispose();
      });

      test('完整的测试流程', () async {
        // 1. 创建测试任务
        final tasks = [
          const TestTask(
            id: 'login_test',
            description: '用户登录测试',
            intent: '验证用户可以使用正确的用户名和密码登录系统',
            priority: 0.9,
            tags: ['auth', 'critical'],
          ),
          const TestTask(
            id: 'message_test',
            description: '发送消息测试',
            intent: '验证用户可以发送文本消息给好友',
            priority: 0.8,
            tags: ['chat'],
          ),
        ];

        // 2. 执行测试
        print('执行测试任务...');
        final results = await orchestrator.executeTasks(tasks);
        print('执行完成: ${results.length} 个任务');

        // 3. 验证结果
        expect(results, hasLength(2));
        expect(
          results.every((r) => r.taskId.isNotEmpty),
          isTrue,
        );

        // 4. 生成报告
        final report = await orchestrator.generateReport(
          results: results,
          includeDetails: true,
        );

        expect(report, isNotNull);
        expect(report.results, hasLength(2));

        // 5. 获取统计
        final stats = orchestrator.getStatistics();
        print('测试统计: $stats');
        expect(stats['totalTests'], equals(2));

        // 6. 获取建议
        final suggestions = orchestrator.getSuggestions();
        print('测试建议:');
        for (final suggestion in suggestions) {
          print('  - $suggestion');
        }
        expect(suggestions, isNotNull);
      });

      test('报告导出测试', () async {
        final task = const TestTask(
          id: 'export_test',
          description: '导出测试',
          intent: '测试报告导出功能',
        );

        await orchestrator.executeTask(task);
        final report = await orchestrator.generateReport();

        // 测试 JSON 导出
        final jsonReport = generator.exportToJson(report);
        expect(jsonReport, isNotEmpty);
        print('JSON 报告长度: ${jsonReport.length} 字符');

        // 测试 Markdown 导出
        final mdReport = generator.exportToMarkdown(report);
        expect(mdReport, contains('# AI 测试报告'));
        print('Markdown 报告长度: ${mdReport.length} 字符');

        // 测试 HTML 导出
        final htmlReport = generator.exportToHtml(report);
        expect(htmlReport, contains('<!DOCTYPE html>'));
        print('HTML 报告长度: ${htmlReport.length} 字符');

        // 测试文本导出
        final textReport = generator.exportToText(report);
        expect(textReport, contains('AI 测试报告'));
        print('文本报告长度: ${textReport.length} 字符');
      });

      test('性能监控集成', () async {
        final task = const TestTask(
          id: 'perf_test',
          description: '性能测试',
          intent: '测试性能监控功能',
        );

        await orchestrator.executeTask(task);

        final perfReport = orchestrator.monitor.generateReport();
        expect(perfReport['totalOperations'], greaterThan(0));

        print('性能报告:');
        print('  总操作数: ${perfReport['totalOperations']}');
        print('  总耗时: ${perfReport['totalDuration']}ms');
        print('  平均耗时: ${perfReport['averageDuration']?.toStringAsFixed(2)}ms');
      });
    });
  });
}
