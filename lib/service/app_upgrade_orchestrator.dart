// APP 升级编排器（纯业务逻辑，零 Flutter 依赖）
// APP upgrade orchestrator (pure business logic, zero Flutter deps)
//
// 职责（SRP）：协调版本轨迹检测与事件上报，不依赖 UI/网络/定时器。
// 作为 AppUpgradeService 的可测核心，构造注入所有外部依赖（DIP）。
//
// 刻意保持此文件只依赖 `app_upgrade_reporter.dart` 和 `app_version_tracker.dart`
// （两者都是纯 Dart 接口），让测试可在不加载 Flutter widget 链与生产 HTTP 链的
// 前提下完整覆盖启动集成路径。
//
// Responsibility (SRP): orchestrates version-transition detection and
// event reporting. No UI/network/timer dependencies. Acts as the testable
// core of AppUpgradeService with all external dependencies injected (DIP).
//
// Intentionally only depends on the two pure-Dart interface files so tests
// cover the full startup-integration path without loading the Flutter widget
// layer or the production HTTP chain.
library;

import 'package:imboy/service/app_downgrade_cleaner.dart';
import 'package:imboy/service/app_upgrade_reporter.dart';
import 'package:imboy/service/app_version_tracker.dart';

/// 日志回调签名（注入式，避免耦合 `iPrint`/`logger` 等实现）。
/// Logger callback (injectable; avoids coupling to `iPrint` / `logger`).
typedef UpgradeLogger = void Function(String message);

void _noopLogger(String _) {}

/// 无操作清理器（当宿主不关心降级副作用时用作默认值）。
/// No-op cleaner (used when the host has no side-effects to purge).
class _NoopDowngradeCleaner implements AppDowngradeCleaner {
  const _NoopDowngradeCleaner();

  @override
  Future<void> onDowngrade({
    required String fromVsn,
    required String toVsn,
  }) async {}
}

class AppUpgradeOrchestrator {
  AppUpgradeOrchestrator({
    required AppVersionTracker tracker,
    required AppUpgradeReporter reporter,
    AppDowngradeCleaner? cleaner,
    UpgradeLogger? logger,
  })  : _tracker = tracker,
        _reporter = reporter,
        _cleaner = cleaner ?? const _NoopDowngradeCleaner(),
        _log = logger ?? _noopLogger;

  final AppVersionTracker _tracker;
  final AppUpgradeReporter _reporter;
  final AppDowngradeCleaner _cleaner;
  final UpgradeLogger _log;

  /// 启动时协调版本检测与事件上报。
  ///
  /// 契约：
  /// - 返回本次版本转换结果（firstLaunch/upgraded/downgraded/unchanged）
  /// - 检测与持久化原子完成（[AppVersionTracker.detectAndCommit]）
  /// - 降级时上报 `downgrade` 事件，上报失败不抛出（错误隔离）
  /// - 升级/首启/未变不上报（仅日志）
  ///
  /// Contract:
  /// - Returns the detected version transition
  /// - Detection and persistence are atomic via detectAndCommit
  /// - On downgrade, reports a `downgrade` event; reporter errors are
  ///   swallowed (isolation)
  /// - Upgrade / first launch / unchanged do not report (log only)
  Future<VersionTransitionResult> onAppStart(String currentVsn) async {
    final transition = _tracker.detectAndCommit(currentVsn: currentVsn);

    if (transition.isDowngrade) {
      _log(
        'AppUpgradeOrchestrator: downgrade detected '
        '${transition.previousVsn} → ${transition.currentVsn}',
      );
      // 1) 先清理本地副作用（本地 I/O，优先完成避免协议不兼容残留）
      // 2) 再上报事件（远程 I/O，失败概率更高）
      // 两条路径独立错误隔离，互不阻塞。
      // 1) Cleanup local side-effects first (local I/O; avoid residual
      //    protocol-incompatible state)
      // 2) Then report the event (remote I/O; more failure-prone)
      // Both paths are independently error-isolated.
      try {
        await _cleaner.onDowngrade(
          fromVsn: transition.previousVsn,
          toVsn: transition.currentVsn,
        );
      } catch (e, st) {
        _log('AppUpgradeOrchestrator: cleaner error $e\n$st');
      }
      try {
        await _reporter.report(
          event: 'downgrade',
          targetVsn: transition.currentVsn,
          extra: <String, dynamic>{'from_vsn': transition.previousVsn},
        );
      } catch (e, st) {
        // 上报失败不能阻塞启动流程，也不能让版本提交回滚
        // Reporter failure must not block startup nor revert the commit
        _log('AppUpgradeOrchestrator: report error $e\n$st');
      }
    } else if (transition.isUpgrade) {
      _log(
        'AppUpgradeOrchestrator: upgrade detected '
        '${transition.previousVsn} → ${transition.currentVsn}',
      );
    } else if (transition.isFirstLaunch) {
      _log('AppUpgradeOrchestrator: first launch ${transition.currentVsn}');
    }

    return transition;
  }
}
