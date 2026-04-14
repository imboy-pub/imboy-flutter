// APP 降级副作用清理器抽象（纯 Dart，无传递依赖）
// AppDowngradeCleaner interface (pure Dart, zero transitive deps)
//
// 当检测到 APP 版本降级（用户安装旧版 APK/IPA）时调用，用于清理可能与新版本
// 协议/缓存结构不兼容的本地状态（如 WS 消息队列、升级提示 dismiss 记录）。
//
// 保持此文件零依赖，以便测试代码可导入接口而不拉入生产 Storage/HTTP 链。
// 生产实现在 `default_app_downgrade_cleaner.dart`。
//
// Called when the orchestrator detects an APP version downgrade (user
// installed an older APK/IPA). Purges local state that may be incompatible
// with older protocol/cache structures (WS message queue, upgrade dismiss
// record, etc.).
//
// Dependency-free so tests can import without pulling in production Storage
// or HTTP chains. Production impl lives in default_app_downgrade_cleaner.dart.
library;

abstract interface class AppDowngradeCleaner {
  /// 当检测到降级（[fromVsn] > [toVsn]）时被 orchestrator 调用。
  /// Invoked by the orchestrator when a downgrade is detected.
  ///
  /// 实现必须幂等；异常会被 orchestrator 隔离（不阻塞启动）。
  /// Implementations must be idempotent; errors are isolated by the caller.
  Future<void> onDowngrade({required String fromVsn, required String toVsn});
}
