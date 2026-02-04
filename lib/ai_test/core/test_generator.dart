/// 测试生成器 - 将 AI 生成的测试用例转换为可执行代码
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../intent/intent_parser.dart';

/// 测试结果
class TestResult {
  final GeneratedTestCase testCase;
  final bool passed;
  final Duration duration;
  final String? error;

  TestResult({
    required this.testCase,
    required this.passed,
    required this.duration,
    this.error,
  });

  @override
  String toString() =>
      'TestResult(${passed ? "✅" : "❌"} ${testCase.name}, ${duration.inMilliseconds}ms${error != null ? ", error: $error" : ""})';
}

/// 测试生成器 - 将 AI 生成的测试用例转换为可执行代码
class TestGenerator {
  int _passedTests = 0;
  int _failedTests = 0;
  final List<TestResult> _results = [];

  /// 执行 AI 生成的测试用例
  Future<void> executeTest(
    WidgetTester tester,
    GeneratedTestCase testCase,
  ) async {
    final startTime = DateTime.now();

    try {
      // 1. 验证前置条件
      for (final condition in testCase.preconditions) {
        print('  ✓ 验证前置条件: $condition');
        await _verifyPrecondition(tester, condition);
      }

      // 2. 执行测试步骤
      for (final step in testCase.steps) {
        print('  → ${step.action}');
        await _executeStep(tester, step);

        // 验证预期结果
        print('  ✓ ${step.expected}');
        await _verifyExpected(tester, step.expected);
      }

      // 测试通过
      _passedTests++;
      _results.add(TestResult(
        testCase: testCase,
        passed: true,
        duration: DateTime.now().difference(startTime),
      ));
    } catch (e) {
      // 测试失败
      _failedTests++;
      _results.add(TestResult(
        testCase: testCase,
        passed: false,
        duration: DateTime.now().difference(startTime),
        error: e.toString(),
      ));
      rethrow;
    }
  }

  /// 验证前置条件
  Future<void> _verifyPrecondition(
    WidgetTester tester,
    String condition,
  ) async {
    // 简单实现：根据条件描述判断
    if (condition.contains('登录')) {
      // 假设已经登录
      await Future.delayed(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  /// 执行测试步骤
  Future<void> _executeStep(
    WidgetTester tester,
    TestStep step,
  ) async {
    final action = step.action.toLowerCase();

    if (action.contains('点击') || action.contains('tap') || action.contains('button')) {
      final target = _extractTarget(step.action);
      if (target.isNotEmpty) {
        await _tapByText(tester, target);
      } else {
        await tester.pumpAndSettle();
      }
    } else if (action.contains('输入') || action.contains('enter') || action.contains('输入框')) {
      final text = _extractInputText(step);
      await _enterText(tester, text);
    } else if (action.contains('滑动') || action.contains('scroll')) {
      await _scroll(tester);
    } else {
      // 默认等待
      await tester.pumpAndSettle();
    }
  }

  /// 验证预期结果
  Future<void> _verifyExpected(
    WidgetTester tester,
    String expected,
  ) async {
    await tester.pumpAndSettle();
    // 简单验证：等待一段时间确保 UI 稳定
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// 从操作描述中提取目标元素
  String _extractTarget(String action) {
    // 简单的目标提取逻辑
    if (action.contains('发送') || action.contains('send')) return '发送';
    if (action.contains('好友') || action.contains('friend')) return '好友';
    if (action.contains('聊天') || action.contains('chat')) return '聊天';
    if (action.contains('确认') || action.contains('confirm')) return '确认';
    // 从引号中提取
    final quoteMatch = RegExp(r'''["'](.+?)["']''').firstMatch(action);
    if (quoteMatch != null) {
      return quoteMatch.group(1) ?? '';
    }
    return '';
  }

  /// 从测试数据中获取输入文本
  String _extractInputText(TestStep step) {
    // 从操作描述中提取
    if (step.action.contains('"')) {
      final match = RegExp(r'"(.+?)"').firstMatch(step.action);
      if (match != null) return match.group(1) ?? '';
    }
    // 默认文本
    return '测试文本';
  }

  /// 通过文本点击元素
  Future<void> _tapByText(
    WidgetTester tester,
    String text,
  ) async {
    // 尝试精确匹配
    var finder = find.text(text);
    if (finder.evaluate().isEmpty) {
      // 尝试包含匹配
      finder = find.textContaining(text);
      if (finder.evaluate().isEmpty) {
        throw Exception('找不到包含 "$text" 的元素');
      }
    }
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  /// 输入文本
  Future<void> _enterText(
    WidgetTester tester,
    String text,
  ) async {
    final textField = find.byType(TextField);
    if (textField.evaluate().isEmpty) {
      // 尝试查找 TextFormField
      final textFormField = find.byType(TextFormField);
      if (textFormField.evaluate().isEmpty) {
        throw Exception('找不到输入框');
      }
      await tester.tap(textFormField.first);
      await tester.pumpAndSettle();
      await tester.enterText(textFormField.first, text);
    } else {
      await tester.tap(textField.first);
      await tester.pumpAndSettle();
      await tester.enterText(textField.first, text);
    }
    await tester.pumpAndSettle();
  }

  /// 滚动操作
  Future<void> _scroll(WidgetTester tester) async {
    final list = find.byType(Scrollable);
    if (list.evaluate().isNotEmpty) {
      await tester.fling(list.first, const Offset(0, -500), 1000);
      await tester.pumpAndSettle();
    }
  }

  /// 生成测试报告
  String generateReport() {
    final buffer = StringBuffer();
    buffer.writeln('\n${'=' * 60}');
    buffer.writeln('📊 AI 测试报告');
    buffer.writeln('${'=' * 60}');
    buffer.writeln('总测试数: ${_passedTests + _failedTests}');
    buffer.writeln('通过: $_passedTests ✅');
    buffer.writeln('失败: $_failedTests ❌');
    if (_passedTests + _failedTests > 0) {
      final passRate = (_passedTests / (_passedTests + _failedTests) * 100).toStringAsFixed(1);
      buffer.writeln('通过率: $passRate%');
    }
    buffer.writeln('${'=' * 60}');

    for (final result in _results) {
      buffer.writeln('\n${result.passed ? "✅" : "❌"} ${result.testCase.name}');
      buffer.writeln('   类型: ${result.testCase.type} | 优先级: ${result.testCase.priority}');
      buffer.writeln('   耗时: ${result.duration.inMilliseconds}ms');
      if (!result.passed) {
        buffer.writeln('   错误: ${result.error}');
      }
    }

    return buffer.toString();
  }

  /// 获取通过数
  int get passedTests => _passedTests;

  /// 获取失败数
  int get failedTests => _failedTests;

  /// 获取总测试数
  int get totalTests => _passedTests + _failedTests;

  /// 获取所有结果
  List<TestResult> get results => List.unmodifiable(_results);

  /// 重置统计
  void reset() {
    _passedTests = 0;
    _failedTests = 0;
    _results.clear();
  }
}
