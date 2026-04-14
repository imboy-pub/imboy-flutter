// 测试辅助：升级事件上报器的内存假实现
// Test helper: in-memory fake for AppUpgradeReporter
//
// 捕获 report 调用，供测试断言。不做任何网络请求。
// Captures report() invocations for tests to assert. No network I/O.
library;

import 'package:imboy/service/app_upgrade_reporter.dart';

class FakeUpgradeReporter implements AppUpgradeReporter {
  final List<ReportedEvent> events = <ReportedEvent>[];

  /// 若设置，下一次 report() 会抛出此异常（用于测试错误隔离）。
  /// If set, the next report() call throws this error (for error-isolation tests).
  Object? nextError;

  @override
  Future<void> report({
    required String event,
    required String targetVsn,
    Map<String, dynamic>? extra,
  }) async {
    if (nextError != null) {
      final err = nextError!;
      nextError = null;
      throw err;
    }
    events.add(
      ReportedEvent(event: event, targetVsn: targetVsn, extra: extra),
    );
  }

  void clear() => events.clear();
}

class ReportedEvent {
  const ReportedEvent({
    required this.event,
    required this.targetVsn,
    this.extra,
  });

  final String event;
  final String targetVsn;
  final Map<String, dynamic>? extra;
}
