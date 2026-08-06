// 测试辅助：降级清理器的内存假实现
// Test helper: in-memory fake for AppDowngradeCleaner
//
// 捕获 onDowngrade 调用以供断言。不做任何 I/O。
// Captures onDowngrade invocations for assertions. No I/O.
library;

import 'package:imboy/service/app_downgrade_cleaner.dart';

class FakeDowngradeCleaner implements AppDowngradeCleaner {
  final List<DowngradeCall> calls = <DowngradeCall>[];

  /// 若设置，下一次 onDowngrade 调用会抛此错误。
  /// If set, the next onDowngrade call throws this error.
  Object? nextError;

  @override
  Future<void> onDowngrade({
    required String fromVsn,
    required String toVsn,
  }) async {
    if (nextError != null) {
      final err = nextError!;
      nextError = null;
      throw err;
    }
    calls.add(DowngradeCall(fromVsn: fromVsn, toVsn: toVsn));
  }

  void clear() => calls.clear();
}

class DowngradeCall {
  const DowngradeCall({required this.fromVsn, required this.toVsn});

  final String fromVsn;
  final String toVsn;
}
