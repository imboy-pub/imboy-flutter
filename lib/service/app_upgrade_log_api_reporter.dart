// AppUpgradeReporter 的生产实现
// Production implementation of AppUpgradeReporter
//
// 委托给 AppUpgradeLogApi 静态方法。此文件刻意与接口分离，
// 避免测试代码在导入接口时拉入 HTTP/Flutter 配置链（见 app_upgrade_reporter.dart）。
//
// Delegates to the static AppUpgradeLogApi.report. Kept separate from the
// interface file so tests can import the interface without dragging in the
// HTTP/Flutter config chain (see app_upgrade_reporter.dart).
library;

import 'package:imboy/service/app_upgrade_reporter.dart';
import 'package:imboy/store/api/app_upgrade_log_api.dart';

class AppUpgradeLogApiReporter implements AppUpgradeReporter {
  const AppUpgradeLogApiReporter();

  @override
  Future<void> report({
    required String event,
    required String targetVsn,
    Map<String, dynamic>? extra,
  }) => AppUpgradeLogApi.report(
        event: event,
        targetVsn: targetVsn,
        extra: extra,
      );
}
