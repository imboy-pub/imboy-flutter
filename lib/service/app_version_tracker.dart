import 'package:imboy/service/version_comparator.dart';

/// 版本转换类型 / Version transition type
enum VersionTransition {
  /// 首次安装，无历史记录 / First install, no prior version stored
  firstLaunch,

  /// 版本升高（正向升级）/ Version increased (forward upgrade)
  upgraded,

  /// 版本降低（回退/降级）/ Version decreased (rollback / downgrade)
  downgraded,

  /// 版本未变 / Version unchanged
  unchanged,
}

/// 版本转换检测结果 / Result of a version transition detection
class VersionTransitionResult {
  final VersionTransition transition;
  final String previousVsn;
  final String currentVsn;

  const VersionTransitionResult({
    required this.transition,
    required this.previousVsn,
    required this.currentVsn,
  });

  bool get isFirstLaunch => transition == VersionTransition.firstLaunch;
  bool get isUpgrade => transition == VersionTransition.upgraded;
  bool get isDowngrade => transition == VersionTransition.downgraded;
  bool get isUnchanged => transition == VersionTransition.unchanged;
}

/// APP 版本跟踪器 / App version tracker
///
/// 检测每次启动时的版本转换方向，用于触发对应的迁移或回退逻辑。
/// Detects the version transition direction on each launch to trigger
/// appropriate migration or rollback logic.
///
/// 使用示例 / Usage:
/// ```dart
/// final tracker = AppVersionTracker(storage: StorageService.to);
/// final result = tracker.detectAndCommit(currentVsn: appVsn);
///
/// if (result.isDowngrade) {
///   // 触发 DB 降级 / Trigger DB downgrade
/// } else if (result.isUpgrade) {
///   // 可在此上报升级事件 / Optionally report upgrade event
/// }
/// ```
class AppVersionTracker {
  /// 上次运行版本的存储 key
  static const String lastRunVsnKey = 'app_version_last_run_vsn';

  final dynamic _storage; // duck-typed: getString(key) + setString(key, value)

  const AppVersionTracker({required dynamic storage}) : _storage = storage;

  /// 检测当前版本与上次运行版本的转换关系。
  ///
  /// 不修改存储状态 — 调用 [commit] 或 [detectAndCommit] 来持久化。
  /// Does not modify storage — call [commit] or [detectAndCommit] to persist.
  VersionTransitionResult detect({required String currentVsn}) {
    final previousVsn = '${_storage.getString(lastRunVsnKey)}';

    if (previousVsn.isEmpty) {
      return VersionTransitionResult(
        transition: VersionTransition.firstLaunch,
        previousVsn: '',
        currentVsn: currentVsn,
      );
    }

    final cmp = VersionComparator.compare(currentVsn, previousVsn);
    final transition = cmp > 0
        ? VersionTransition.upgraded
        : cmp < 0
            ? VersionTransition.downgraded
            : VersionTransition.unchanged;

    return VersionTransitionResult(
      transition: transition,
      previousVsn: previousVsn,
      currentVsn: currentVsn,
    );
  }

  /// 将 [vsn] 写入存储，标记为本次运行的版本。
  /// Persist [vsn] as the current run version.
  void commit({required String vsn}) {
    _storage.setString(lastRunVsnKey, vsn);
  }

  /// [detect] + [commit] 原子操作：检测后立即持久化当前版本。
  ///
  /// [detect] + [commit] atomic operation: detect then immediately persist.
  VersionTransitionResult detectAndCommit({required String currentVsn}) {
    final result = detect(currentVsn: currentVsn);
    commit(vsn: currentVsn);
    return result;
  }
}
