// 增强的集成测试辅助类
//
// 功能：
// - 自动截图
// - 日志记录
// - 错误捕获
// - 测试报告生成
// - 智能等待

import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// 测试步骤记录
class TestStep {
  final String name;
  final String description;
  final DateTime timestamp;
  final bool success;
  final String? errorMessage;
  final String? screenshotPath;

  TestStep({
    required this.name,
    required this.description,
    required this.timestamp,
    this.success = true,
    this.errorMessage,
    this.screenshotPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'success': success,
      'errorMessage': errorMessage,
      'screenshotPath': screenshotPath,
    };
  }
}

/// 测试会话记录
class TestSession {
  final String testName;
  final String platform;
  final DateTime startTime;
  final List<TestStep> steps = [];
  DateTime? endTime;
  bool? passed;

  TestSession({
    required this.testName,
    required this.platform,
    required this.startTime,
  });

  void addStep(TestStep step) {
    steps.add(step);
  }

  void finish({bool? result}) {
    endTime = DateTime.now();
    passed = result;
  }

  Map<String, dynamic> toJson() {
    return {
      'testName': testName,
      'platform': platform,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'duration': endTime?.difference(startTime).inMilliseconds,
      'passed': passed,
      'steps': steps.map((s) => s.toJson()).toList(),
    };
  }
}

/// 增强的测试辅助类
class EnhancedTestHelper {
  final WidgetTester tester;
  final String testOutputDir;
  final String screenshotsDir;
  final String logsDir;

  late final TestSession _session;
  bool _hasError = false;

  EnhancedTestHelper(this.tester, {String? outputDir})
    : testOutputDir = outputDir ?? 'test_output',
      screenshotsDir = '${outputDir ?? 'test_output'}/screenshots',
      logsDir = '${outputDir ?? 'test_output'}/logs' {
    _initDirectories();
  }

  /// 初始化目录
  void _initDirectories() {
    Directory(testOutputDir).createSync(recursive: true);
    Directory(screenshotsDir).createSync(recursive: true);
    Directory(logsDir).createSync(recursive: true);
  }

  /// 开始测试会话
  void startSession(String testName, String platform) {
    _session = TestSession(
      testName: testName,
      platform: platform,
      startTime: DateTime.now(),
    );
    _log('🚀 测试开始: $testName ($platform)');
  }

  /// 结束测试会话
  Future<void> finishSession({bool? passed}) async {
    _session.finish(result: passed ?? !_hasError);
    _saveReport();
    _log(
      '🏁 测试结束: ${_session.testName} - ${passed != false ? '✅ 通过' : '❌ 失败'}',
    );
  }

  /// 记录测试步骤
  Future<void> step(
    String name,
    String description, {
    Future<void> Function()? action,
    bool critical = true,
  }) async {
    final startTime = DateTime.now();
    _log('📍 [$name] $description');

    String? screenshotPath;
    bool success = true;
    String? errorMessage;
    Object? caughtException;

    try {
      if (action != null) {
        await action();
      }
      // 步骤完成后截图
      screenshotPath = await screenshot('${_session.testName}_$name');
      _log('  ✅ 步骤完成');
    } catch (e, stackTrace) {
      success = false;
      errorMessage = e.toString();
      caughtException = e;
      if (critical) {
        _hasError = true;
      }
      _log('  ❌ 步骤失败: $e');
      _log('  堆栈: $stackTrace');

      // 失败时也截图
      screenshotPath = await screenshot('${_session.testName}_${name}_error');
    }

    final step = TestStep(
      name: name,
      description: description,
      timestamp: startTime,
      success: success,
      errorMessage: errorMessage,
      screenshotPath: screenshotPath,
    );

    _session.addStep(step);

    if (!success && critical && caughtException != null) {
      throw caughtException;
    }
  }

  /// 截图
  Future<String> screenshot(String name) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = '${name}_$timestamp.png';
      final path = '$screenshotsDir/$filename';

      await binding.takeScreenshot(path);
      return path;
    } catch (e) {
      _log('⚠️ 截图失败: $e');
      return '';
    }
  }

  /// 智能等待元素出现
  Future<Finder> waitFor(
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
    bool required = true,
  }) async {
    final startTime = DateTime.now();
    // ignore: deprecated_member_use
    _log('🔍 等待元素: ${finder.description}');

    while (DateTime.now().difference(startTime) < timeout) {
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      if (tester.any(finder)) {
        _log('  ✅ 元素已找到');
        return finder;
      }
    }

    if (required) {
      _log('  ❌ 元素未找到（超时）');
      // ignore: deprecated_member_use
      throw TimeoutException('元素未找到: ${finder.description}', timeout);
    } else {
      _log('  ⚠️ 元素未找到（可选）');
      return finder;
    }
  }

  /// 智能等待并点击
  Future<void> tap(
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
    bool required = true,
  }) async {
    await waitFor(finder, timeout: timeout, required: required);
    await tester.tap(finder);
    await tester.pumpAndSettle();
    // ignore: deprecated_member_use
    _log('👆 点击: ${finder.description}');
  }

  /// 智能等待并输入文本
  Future<void> enterText(
    Finder finder,
    String text, {
    Duration timeout = const Duration(seconds: 10),
    bool clearFirst = true,
    bool required = true,
  }) async {
    await waitFor(finder, timeout: timeout, required: required);
    await tester.tap(finder);
    await tester.pumpAndSettle();

    if (clearFirst) {
      await tester.enterText(finder, '');
      await tester.pumpAndSettle();
    }

    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
    _log('⌨️ 输入文本: "$text"');
  }

  /// 滑动操作
  Future<void> scroll(
    Finder finder, {
    Offset delta = const Offset(0, -500),
    int times = 1,
    Duration settle = const Duration(milliseconds: 500),
  }) async {
    for (int i = 0; i < times; i++) {
      await tester.drag(finder, delta);
      await tester.pumpAndSettle(settle);
    }
    _log('📜 滑动: $delta x $times');
  }

  /// 等待页面加载完成
  Future<void> waitForLoad({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    await tester.pumpAndSettle(timeout);
    _log('⏳ 等待页面加载完成');
  }

  /// 日志输出
  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $message';
    print(logMessage);

    // 写入日志文件
    final logFile = File('$logsDir/${_session.testName}.log');
    logFile.writeAsStringSync('$logMessage\n', mode: FileMode.append);
  }

  /// 保存测试报告
  void _saveReport() {
    final reportFile = File('$testOutputDir/${_session.testName}_report.json');
    reportFile.writeAsStringSync(_formatJsonReport());
    _log('📄 测试报告已保存: ${reportFile.path}');
  }

  /// 格式化 JSON 报告
  String _formatJsonReport() {
    final report = {
      'session': _session.toJson(),
      'summary': {
        'totalSteps': _session.steps.length,
        'successfulSteps': _session.steps.where((s) => s.success).length,
        'failedSteps': _session.steps.where((s) => !s.success).length,
      },
    };
    return report.toString();
  }

  /// 获取测试会话
  TestSession get session => _session;

  /// 获取 binding
  static IntegrationTestWidgetsFlutterBinding get binding =>
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();
}

/// 全局测试报告收集器
class TestReportCollector {
  static final List<TestSession> _sessions = [];

  static void addSession(TestSession session) {
    _sessions.add(session);
  }

  static List<TestSession> get sessions => List.unmodifiable(_sessions);

  static void clear() {
    _sessions.clear();
  }

  /// 生成汇总报告
  static String generateSummaryReport() {
    final totalTests = _sessions.length;
    final passedTests = _sessions.where((s) => s.passed == true).length;
    final failedTests = _sessions.where((s) => s.passed == false).length;
    final totalSteps = _sessions.fold(0, (sum, s) => sum + s.steps.length);
    final successfulSteps = _sessions.fold(
      0,
      (sum, s) => sum + s.steps.where((step) => step.success).length,
    );

    final report =
        '''
# 测试汇总报告

## 概览
- 总测试数: $totalTests
- 通过: $passedTests
- 失败: $failedTests
- 总步骤数: $totalSteps
- 成功步骤: $successfulSteps
- 失败步骤: ${totalSteps - successfulSteps}
- 通过率: ${totalTests > 0 ? (passedTests / totalTests * 100).toStringAsFixed(1) : 0}%

## 测试详情

${_sessions.map((s) => '''
### ${s.testName}
- 平台: ${s.platform}
- 状态: ${s.passed == true
            ? '✅ 通过'
            : s.passed == false
            ? '❌ 失败'
            : '⏸️ 未完成'}
- 步骤数: ${s.steps.length}
- 耗时: ${s.endTime?.difference(s.startTime).inSeconds ?? 0}秒

${s.steps.map((step) => '''
- ${step.success ? '✅' : '❌'} **${step.name}**: ${step.description}
  ${step.errorMessage != null ? '  错误: ${step.errorMessage}' : ''}
  ${step.screenshotPath != null ? '  截图: ${step.screenshotPath}' : ''}
''').join('\n')}
''').join('\n')}

---
生成时间: ${DateTime.now().toIso8601String()}
''';

    return report;
  }
}
