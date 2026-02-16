// 测试辅助工具
//
// 提供常用的测试辅助方法

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class TestHelper {
  /// 等待 Widget 出现
  static Future<void> waitForWidget(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (tester.any(finder)) {
        return;
      }
    }
    // ignore: deprecated_member_use
    throw TimeoutException('等待 Widget 超时: ${finder.description}', timeout);
  }

  /// 等待文本出现
  static Future<void> waitForText(
    WidgetTester tester,
    String text, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await waitForWidget(tester, find.text(text), timeout: timeout);
  }

  /// 安全点击（如果存在则点击）
  static Future<bool> safeTap(WidgetTester tester, Finder finder) async {
    if (tester.any(finder)) {
      await tester.tap(finder);
      await tester.pumpAndSettle();
      return true;
    }
    return false;
  }

  /// 输入文本到指定字段
  static Future<void> enterText(
    WidgetTester tester,
    Finder finder,
    String text,
  ) async {
    await tester.ensureVisible(finder);
    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
  }

  /// 截图并保存
  static Future<void> screenshot(
    WidgetTester tester,
    String name, {
    bool waitForReady = true,
  }) async {
    if (waitForReady) {
      await tester.pumpAndSettle();
    }
    await IntegrationTestWidgetsFlutterBinding.instance.takeScreenshot(name);
  }

  /// 打印测试步骤
  static void log(String message) {
    print('[TEST] $message');
  }

  /// 重试操作
  static Future<T> retry<T>(
    T Function() operation, {
    int maxAttempts = 3,
    Duration delay = const Duration(seconds: 1),
  }) async {
    for (int i = 0; i < maxAttempts; i++) {
      try {
        return operation();
      } catch (e) {
        if (i == maxAttempts - 1) rethrow;
        await Future.delayed(delay);
      }
    }
    throw StateError('重试失败');
  }
}

class TimeoutException implements Exception {
  final String message;
  final Duration duration;

  TimeoutException(this.message, this.duration);

  @override
  String toString() => '$message (超时: ${duration.inSeconds}秒)';
}
