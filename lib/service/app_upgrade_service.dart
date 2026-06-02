import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/single/upgrade.dart';
import 'package:imboy/service/app_downgrade_cleaner.dart';
import 'package:imboy/service/app_upgrade_log_api_reporter.dart';
import 'package:imboy/service/app_upgrade_orchestrator.dart';
import 'package:imboy/service/app_upgrade_reporter.dart';
import 'package:imboy/service/default_app_downgrade_cleaner.dart';
import 'package:imboy/service/app_version_tracker.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/upgrade_strategy.dart';
import 'package:imboy/service/upgrade_timer_policy.dart';
import 'package:imboy/store/api/app_upgrade_log_api.dart';
import 'package:imboy/store/api/app_version_api.dart';
import 'package:imboy/store/model/app_version_model.dart';

/// APP 升级检查服务
///
/// 实现三级升级策略：
/// - force: 全屏弹窗不可关闭
/// - recommend: 弹窗可关闭，下次启动再提醒
/// - silent: 设置页小红点，不弹窗
///
/// 检查时机：
/// - APP 启动后延迟 3 秒
/// - 定时检查（间隔从服务端获取，默认 24 小时）
/// - 收到 S2C app_upgrade 消息
/// - 设置页手动触发
class AppUpgradeService {
  AppUpgradeService._();
  static final AppUpgradeService _instance = AppUpgradeService._();
  static AppUpgradeService get to => _instance;

  static const String _checkIntervalKey = 'app_upgrade_check_interval_hours';

  /// dismiss 状态管理（委托给 UpgradeStrategy 的 AppUpgradeDismissState）
  /// Dismiss-state manager delegated to AppUpgradeDismissState
  late final AppUpgradeDismissState _dismissState = AppUpgradeDismissState(
    storage: StorageService.to,
  );

  /// 版本转换跟踪器（升级/降级/回退检测）
  /// Version transition tracker (upgrade/downgrade/rollback detection)
  late final AppVersionTracker _versionTracker = AppVersionTracker(
    storage: StorageService.to,
  );

  /// 升级事件上报器（可在测试中覆盖）
  /// Upgrade event reporter (overridable in tests)
  AppUpgradeReporter _reporter = const AppUpgradeLogApiReporter();

  /// 降级副作用清理器（可在测试中覆盖）
  /// Downgrade side-effect cleaner (overridable in tests)
  late AppDowngradeCleaner _cleaner = DefaultAppDowngradeCleaner();

  /// 启动编排器（委托版本检测 + 降级清理 + 降级上报）
  /// Startup orchestrator (version detection + downgrade cleanup + report)
  late final AppUpgradeOrchestrator _orchestrator = AppUpgradeOrchestrator(
    tracker: _versionTracker,
    reporter: _reporter,
    cleaner: _cleaner,
    logger: iPrint,
  );

  /// 测试 seam：注入假的 reporter（仅限测试环境使用）
  /// Test seam: inject a fake reporter (tests only)
  @visibleForTesting
  // ignore: use_setters_to_change_properties
  void debugSetReporter(AppUpgradeReporter reporter) {
    _reporter = reporter;
  }

  /// 测试 seam：注入假的 cleaner（仅限测试环境使用）
  /// Test seam: inject a fake cleaner (tests only)
  @visibleForTesting
  // ignore: use_setters_to_change_properties
  void debugSetCleaner(AppDowngradeCleaner cleaner) {
    _cleaner = cleaner;
  }

  /// 最新版本信息缓存
  AppVersionInfo? _cachedInfo;

  /// 定时检查定时器
  Timer? _periodicTimer;

  /// 是否正在显示升级弹窗（防止重复弹窗）
  bool _isShowingDialog = false;

  /// 获取缓存的版本信息（供设置页红点使用）
  AppVersionInfo? get cachedInfo => _cachedInfo;

  /// 是否有静默更新可用（设置页红点）
  bool get hasSilentUpdate =>
      _cachedInfo != null && _cachedInfo!.isSilentUpgrade;

  /// 是否有任何更新可用
  bool get hasUpdate => _cachedInfo != null && _cachedInfo!.hasUpdate;

  /// APP 启动时调用
  ///
  /// 执行顺序：
  /// 1. 检测本次版本转换（升级/降级/首启）并持久化
  /// 2. 若检测到降级（回退），上报事件
  ///    （DB schema 降级由 SqliteService._onDowngrade →
  ///     MigrationService.migrate(isUpgrade: false) 负责，与此处相互独立）
  /// 3. 延迟 3 秒后异步检查是否有新版本可用
  ///
  /// Execution order:
  /// 1. Detect this launch's version transition and persist it
  /// 2. If a downgrade is detected, report the event
  ///    (DB schema downgrade is handled independently by
  ///     SqliteService._onDowngrade → MigrationService.migrate(isUpgrade: false))
  /// 3. Async version-check after 3-second delay (non-blocking)
  Future<void> init() async {
    // 版本轨迹 + 降级上报委托给 AppUpgradeOrchestrator（可测核心）
    // Version tracking + downgrade reporting delegated to the testable core
    await _orchestrator.onAppStart(appVsn);

    // 延迟 3 秒，不阻塞启动 / Delay 3 s to avoid blocking startup
    unawaited(
      Future<dynamic>.delayed(
        const Duration(seconds: 3),
        checkAndPrompt,
      ).catchError((Object e, StackTrace st) {
        iPrint('AppUpgradeService: checkAndPrompt error $e\n$st');
        return null; // AppVersionInfo?
      }),
    );
  }

  /// 上次运行版本（供设置页或诊断使用）
  /// Previous run version (for settings page or diagnostics)
  String get lastRunVsn =>
      StorageService.to.getString(AppVersionTracker.lastRunVsnKey);

  /// 停止定时检查
  void dispose() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// 检查版本并根据策略提示用户
  ///
  /// [fromManual] 是否手动触发（手动触发时忽略"稍后提醒"记录）
  Future<AppVersionInfo?> checkAndPrompt({bool fromManual = false}) async {
    final info = await _fetchVersionInfo();
    if (info == null) return null;

    _cachedInfo = info;
    _setupPeriodicCheck(info.checkIntervalHours);

    // 上报 check 事件
    AppUpgradeLogApi.report(
      event: 'check',
      targetVsn: info.hasUpdate ? info.vsn : '',
      upgradeType: info.upgradeType,
    );

    if (!info.hasUpdate) return info;

    if (info.isSilentUpgrade) {
      // 静默提示：只缓存信息，不弹窗；设置页通过 hasSilentUpdate 展示红点
      // Silent update: cache info only; settings page shows a badge via hasSilentUpdate
      iPrint('AppUpgradeService: silent update available ${info.vsn}');
    } else if (UpgradeStrategy.shouldPrompt(
      info,
      isDismissed: _dismissState.isDismissed(info.vsn),
      fromManual: fromManual,
    )) {
      await _showUpgradePage(info);
    }

    return info;
  }

  /// 手动检查（设置页"检查更新"按钮）
  Future<AppVersionInfo?> manualCheck() async {
    return checkAndPrompt(fromManual: true);
  }

  /// S2C 推送触发的检查
  Future<void> onS2CUpgradeNotice(Map<String, dynamic> payload) async {
    // S2C 推送直接携带了版本信息，可以直接使用
    // S2C push carries version info; parse directly
    final info = AppVersionInfo.fromJson(payload);
    _cachedInfo = info;

    // 策略决策委托给可测的 orchestrator（纯函数，无副作用）
    // Decision logic delegated to orchestrator (pure, testable)
    final action = _orchestrator.decideS2CAction(
      info,
      isDismissed: _dismissState.isDismissed(info.vsn),
    );
    switch (action) {
      case S2CShowUpgradePage(info: final i):
        await _showUpgradePage(i);
      case S2CSilentUpdateAvailable():
        iPrint('AppUpgradeService: silent update available ${info.vsn}');
      case S2CNoAction():
        break;
    }
  }

  /// 从服务端获取版本信息
  Future<AppVersionInfo?> _fetchVersionInfo() async {
    try {
      final api = AppVersionApi();
      final json = await api.check(appVsn);
      if (json.isEmpty) return null;
      return AppVersionInfo.fromJson(json);
    } catch (e) {
      iPrint('AppUpgradeService: check failed $e');
      return null;
    }
  }

  /// 显示升级页面
  Future<void> _showUpgradePage(AppVersionInfo info) async {
    if (_isShowingDialog) return;
    if (info.downloadUrl.isEmpty) return;

    final context = navigatorKey.currentState?.overlay?.context;
    if (context == null) return;

    _isShowingDialog = true;

    // 上报 prompted 事件
    AppUpgradeLogApi.report(
      event: 'prompted',
      targetVsn: info.vsn,
      upgradeType: info.upgradeType,
    );

    try {
      await Navigator.of(context).push(
        CupertinoPageRoute<dynamic>(
          builder: (_) => UpgradePage(
            version: info.vsn,
            downLoadUrl: info.downloadUrl,
            message: UpgradeStrategy.buildChangelogText(info),
            isForce: info.isForceUpgrade,
            fileHash: info.fileHash,
          ),
        ),
      );

      // 如果是推荐升级且用户关闭了弹窗，记录已忽略
      if (info.isRecommendUpgrade) {
        _setDismissed(info.vsn);
      }
    } finally {
      _isShowingDialog = false;
    }
  }

  /// 设置定时检查
  ///
  /// 若 [intervalHours] <= 0，不启动定时器（防止 Timer.periodic(Duration.zero)
  /// 的紧循环死锁）。保存到本地的值仍是原始值，便于诊断。
  ///
  /// When [intervalHours] <= 0, skip timer (prevents Timer.periodic tight loop).
  void _setupPeriodicCheck(int intervalHours) {
    _periodicTimer?.cancel();
    _periodicTimer = null;

    final interval = UpgradeTimerPolicy.computeInterval(intervalHours);
    if (interval == null) {
      iPrint(
        'AppUpgradeService: skip periodic check '
        '(invalid intervalHours=$intervalHours)',
      );
    } else {
      _periodicTimer = Timer.periodic(interval, (_) {
        checkAndPrompt();
      });
    }
    // 保存间隔到本地（诊断用，不受非法值影响）
    // Persist for diagnostics, even when invalid
    StorageService.to.setString(_checkIntervalKey, intervalHours.toString());
  }

  void _setDismissed(String vsn) => _dismissState.setDismissed(vsn);
}
