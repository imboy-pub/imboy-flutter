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
import 'package:imboy/service/upgrade_strategy.dart';
import 'package:imboy/store/model/app_version_model.dart';

/// S2C 推送收到新版本信息后应采取的动作（sealed，便于穷尽 switch）。
/// Action to take after receiving an S2C push upgrade notice.
sealed class S2CUpgradeAction {
  const S2CUpgradeAction();
}

/// 展示升级弹窗（force / recommend-未-dismiss）。
/// Show the upgrade dialog (force / recommend-not-dismissed).
final class S2CShowUpgradePage extends S2CUpgradeAction {
  const S2CShowUpgradePage(this.info);
  final AppVersionInfo info;
}

/// 静默更新可用（只缓存，不弹窗，设置页红点用）。
/// Silent update available — cache info only; settings page shows a badge.
final class S2CSilentUpdateAvailable extends S2CUpgradeAction {
  const S2CSilentUpdateAvailable(this.info);
  final AppVersionInfo info;
}

/// 无动作（无更新 / none 类型 / recommend 已 dismiss）。
/// No-op (no update / type=none / recommend dismissed).
final class S2CNoAction extends S2CUpgradeAction {
  const S2CNoAction();
}

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
  }) : _tracker = tracker,
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

  /// 决策 S2C 推送后的动作（纯函数，无副作用）。
  ///
  /// - `!info.hasUpdate`（不 updatable 或 type=none）→ [S2CNoAction]
  /// - `silent` → [S2CSilentUpdateAvailable]（只缓存，UI 层不弹窗）
  /// - 其余类型经 [UpgradeStrategy.shouldPrompt] 判定：
  ///   - 允许提示 → [S2CShowUpgradePage]
  ///   - 被忽略 → [S2CNoAction]
  ///
  /// 注意：S2C 推送永远不属于 manual 检查（服务端主动下发），所以
  /// [UpgradeStrategy.shouldPrompt] 的 `fromManual` 固定为 false，
  /// `dismissed` 记录会被尊重。
  ///
  /// S2C pushes are never "manual" (server-initiated), so dismissed state
  /// must be respected.
  S2CUpgradeAction decideS2CAction(
    AppVersionInfo info, {
    required bool isDismissed,
  }) {
    if (!info.hasUpdate) return const S2CNoAction();
    if (info.isSilentUpgrade) return S2CSilentUpdateAvailable(info);

    final shouldPrompt = UpgradeStrategy.shouldPrompt(
      info,
      isDismissed: isDismissed,
      fromManual: false,
    );
    return shouldPrompt ? S2CShowUpgradePage(info) : const S2CNoAction();
  }
}
