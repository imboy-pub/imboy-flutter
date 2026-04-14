// 升级/降级事件上报器抽象（纯 Dart，无传递依赖）
// AppUpgradeReporter interface (pure Dart, zero transitive dependencies)
//
// 刻意保持此文件零依赖（除 dart:core），以便测试代码可导入
// 而不拉入生产环境的 HTTP / Flutter 配置链（会引入 file_picker 等平台源码）。
//
// Intentionally dependency-free so test code can import this without
// pulling in the production HTTP / Flutter config chain (which drags
// file_picker platform sources through transitive imports).
//
// 生产实现在 `app_upgrade_log_api_reporter.dart`。
// Production implementation lives in `app_upgrade_log_api_reporter.dart`.
library;

/// 上报升级/降级/回退等版本相关事件。
/// Reports upgrade / downgrade / rollback version events.
abstract interface class AppUpgradeReporter {
  Future<void> report({
    required String event,
    required String targetVsn,
    Map<String, dynamic>? extra,
  });
}
