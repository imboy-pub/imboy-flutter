// AppUpgradeOrchestrator 集成测试
// AppUpgradeOrchestrator integration tests
//
// 覆盖 APP 启动时版本轨迹 → 降级事件上报的完整链路（子链路 A），
// 使用 FakeStorage + FakeUpgradeReporter 替换真实依赖，无网络、无磁盘 I/O。
//
// Covers the end-to-end "version tracking → downgrade reporting" flow
// (sub-chain A) using in-memory fakes. No network, no disk I/O.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/app_upgrade_orchestrator.dart';
import 'package:imboy/service/app_version_tracker.dart';
import 'package:imboy/store/model/app_version_model.dart';

import '../helpers/fake_downgrade_cleaner.dart';
import '../helpers/fake_storage.dart';
import '../helpers/fake_upgrade_reporter.dart';

// 构造 AppVersionInfo 测试夹具
// Build AppVersionInfo test fixture
AppVersionInfo _makeInfo({
  String vsn = '2.0.0',
  bool updatable = true,
  String upgradeType = 'recommend',
}) => AppVersionInfo.fromJson({
      'vsn': vsn,
      'download_url': 'https://example.com/$vsn.apk',
      'upgrade_type': upgradeType,
      'updatable': updatable,
    });

void main() {
  group('AppUpgradeOrchestrator.onAppStart', () {
    late FakeStorage storage;
    late FakeUpgradeReporter reporter;
    late FakeDowngradeCleaner cleaner;
    late AppUpgradeOrchestrator orchestrator;

    setUp(() {
      storage = FakeStorage();
      reporter = FakeUpgradeReporter();
      cleaner = FakeDowngradeCleaner();
      orchestrator = AppUpgradeOrchestrator(
        tracker: AppVersionTracker(storage: storage),
        reporter: reporter,
        cleaner: cleaner,
      );
    });

    test(
      '首次启动不上报事件 / firstLaunch does not report',
      () async {
        final transition = await orchestrator.onAppStart('1.0.0');

        expect(transition.isFirstLaunch, isTrue);
        expect(reporter.events, isEmpty);
      },
    );

    test(
      '版本未变时不上报 / unchanged does not report',
      () async {
        storage.setString(AppVersionTracker.lastRunVsnKey, '1.0.0');

        final transition = await orchestrator.onAppStart('1.0.0');

        expect(transition.isUnchanged, isTrue);
        expect(reporter.events, isEmpty);
      },
    );

    test(
      '升级时不上报（仅日志）/ upgrade does not report',
      () async {
        storage.setString(AppVersionTracker.lastRunVsnKey, '1.0.0');

        final transition = await orchestrator.onAppStart('1.1.0');

        expect(transition.isUpgrade, isTrue);
        expect(reporter.events, isEmpty);
      },
    );

    test(
      '降级时上报 downgrade 事件 / downgrade reports event',
      () async {
        storage.setString(AppVersionTracker.lastRunVsnKey, '1.2.0');

        final transition = await orchestrator.onAppStart('1.0.0');

        expect(transition.isDowngrade, isTrue);
        expect(reporter.events, hasLength(1));
        final evt = reporter.events.single;
        expect(evt.event, 'downgrade');
        expect(evt.targetVsn, '1.0.0');
        expect(evt.extra, {'from_vsn': '1.2.0'});
      },
    );

    test(
      '降级后 tracker 已 commit 当前版本 / tracker commits currentVsn after downgrade',
      () async {
        storage.setString(AppVersionTracker.lastRunVsnKey, '2.0.0');

        await orchestrator.onAppStart('1.5.0');

        expect(
          storage.getString(AppVersionTracker.lastRunVsnKey),
          '1.5.0',
          reason: '降级后必须持久化新版本，避免下次启动重复上报',
        );
      },
    );

    test(
      '连续两次降级启动只在第一次上报 / successive downgrade starts report once each',
      () async {
        storage.setString(AppVersionTracker.lastRunVsnKey, '3.0.0');

        await orchestrator.onAppStart('2.0.0'); // 3.0.0 → 2.0.0 降级
        await orchestrator.onAppStart('2.0.0'); // 2.0.0 → 2.0.0 unchanged

        expect(reporter.events, hasLength(1));
        expect(reporter.events.single.targetVsn, '2.0.0');
        expect(reporter.events.single.extra?['from_vsn'], '3.0.0');
      },
    );

    test(
      'patch 级降级也上报 / patch-level downgrade reports',
      () async {
        storage.setString(AppVersionTracker.lastRunVsnKey, '1.0.5');

        final transition = await orchestrator.onAppStart('1.0.3');

        expect(transition.isDowngrade, isTrue);
        expect(reporter.events, hasLength(1));
        expect(reporter.events.single.extra?['from_vsn'], '1.0.5');
      },
    );

    test(
      'reporter 抛异常不影响启动主流程 / reporter error does not break startup',
      () async {
        storage.setString(AppVersionTracker.lastRunVsnKey, '2.0.0');
        reporter.nextError = Exception('network down');

        // 不应抛出——编排器必须隔离上报失败
        // Must not throw — orchestrator must isolate reporter failures
        final transition = await orchestrator.onAppStart('1.0.0');

        expect(transition.isDowngrade, isTrue);
        expect(
          storage.getString(AppVersionTracker.lastRunVsnKey),
          '1.0.0',
          reason: '上报失败不能阻止版本提交，否则下次启动会重复触发降级流程',
        );
      },
    );

    // -------------------------------------------------------------
    // 降级副作用清理（本批次新增 / new in this batch）
    // Downgrade side-effect cleanup
    // -------------------------------------------------------------

    test(
      '降级时调用 cleaner 一次 / cleaner invoked once on downgrade',
      () async {
        storage.setString(AppVersionTracker.lastRunVsnKey, '2.0.0');

        await orchestrator.onAppStart('1.0.0');

        expect(cleaner.calls, hasLength(1));
        expect(cleaner.calls.single.fromVsn, '2.0.0');
        expect(cleaner.calls.single.toVsn, '1.0.0');
      },
    );

    test(
      'firstLaunch 不调用 cleaner / firstLaunch does not invoke cleaner',
      () async {
        await orchestrator.onAppStart('1.0.0');
        expect(cleaner.calls, isEmpty);
      },
    );

    test(
      '升级不调用 cleaner / upgrade does not invoke cleaner',
      () async {
        storage.setString(AppVersionTracker.lastRunVsnKey, '1.0.0');
        await orchestrator.onAppStart('2.0.0');
        expect(cleaner.calls, isEmpty);
      },
    );

    test(
      '未变不调用 cleaner / unchanged does not invoke cleaner',
      () async {
        storage.setString(AppVersionTracker.lastRunVsnKey, '1.0.0');
        await orchestrator.onAppStart('1.0.0');
        expect(cleaner.calls, isEmpty);
      },
    );

    test(
      'cleaner 抛异常不影响启动主流程与 reporter 调用 / '
      'cleaner error does not block startup nor reporter',
      () async {
        storage.setString(AppVersionTracker.lastRunVsnKey, '2.0.0');
        cleaner.nextError = Exception('storage failure');

        // 不应抛出
        final transition = await orchestrator.onAppStart('1.0.0');

        expect(transition.isDowngrade, isTrue);
        expect(
          storage.getString(AppVersionTracker.lastRunVsnKey),
          '1.0.0',
          reason: '清理失败不能阻止版本提交',
        );
        expect(
          reporter.events,
          hasLength(1),
          reason: '清理失败不能阻止降级上报（两条独立错误隔离线）',
        );
      },
    );

    test(
      '清理在上报之前执行 / cleaner runs before reporter',
      () async {
        storage.setString(AppVersionTracker.lastRunVsnKey, '2.0.0');
        // 记录全局调用顺序
        // Record global call order
        final order = <String>[];
        cleaner = _OrderingCleaner(order);
        reporter = _OrderingReporter(order);
        orchestrator = AppUpgradeOrchestrator(
          tracker: AppVersionTracker(storage: storage),
          reporter: reporter,
          cleaner: cleaner,
        );

        await orchestrator.onAppStart('1.0.0');

        expect(order, ['clean', 'report']);
      },
    );
  });

  // -------------------------------------------------------------
  // S2C 推送决策 (β1) / S2C push action decision
  // -------------------------------------------------------------
  group('AppUpgradeOrchestrator.decideS2CAction', () {
    late FakeStorage storage;
    late AppUpgradeOrchestrator orchestrator;

    setUp(() {
      storage = FakeStorage();
      orchestrator = AppUpgradeOrchestrator(
        tracker: AppVersionTracker(storage: storage),
        reporter: FakeUpgradeReporter(),
        cleaner: FakeDowngradeCleaner(),
      );
    });

    test('updatable=false 返回 NoAction / non-updatable → NoAction', () {
      final action = orchestrator.decideS2CAction(
        _makeInfo(updatable: false, upgradeType: 'recommend'),
        isDismissed: false,
      );
      expect(action, isA<S2CNoAction>());
    });

    test('upgradeType=none 返回 NoAction / type none → NoAction', () {
      final action = orchestrator.decideS2CAction(
        _makeInfo(upgradeType: 'none'),
        isDismissed: false,
      );
      expect(action, isA<S2CNoAction>());
    });

    test(
      'silent 返回 SilentUpdateAvailable / silent → SilentUpdateAvailable',
      () {
        final info = _makeInfo(upgradeType: 'silent');
        final action = orchestrator.decideS2CAction(
          info,
          isDismissed: false,
        );
        expect(action, isA<S2CSilentUpdateAvailable>());
        expect((action as S2CSilentUpdateAvailable).info.vsn, info.vsn);
      },
    );

    test('force 始终返回 ShowUpgradePage / force → ShowUpgradePage', () {
      final info = _makeInfo(upgradeType: 'force');
      // 即使 isDismissed=true，force 仍应弹窗
      final action = orchestrator.decideS2CAction(info, isDismissed: true);
      expect(action, isA<S2CShowUpgradePage>());
      expect((action as S2CShowUpgradePage).info.isForceUpgrade, isTrue);
    });

    test(
      'recommend 未 dismiss 返回 ShowUpgradePage / recommend not dismissed',
      () {
        final action = orchestrator.decideS2CAction(
          _makeInfo(upgradeType: 'recommend'),
          isDismissed: false,
        );
        expect(action, isA<S2CShowUpgradePage>());
      },
    );

    test(
      'recommend 已 dismiss 返回 NoAction（不同于手动检查）/ '
      'recommend dismissed → NoAction (S2C push is never manual)',
      () {
        final action = orchestrator.decideS2CAction(
          _makeInfo(upgradeType: 'recommend'),
          isDismissed: true,
        );
        expect(action, isA<S2CNoAction>());
      },
    );
  });
}

// 辅助：验证调用顺序的桩
// Helpers: stubs for verifying call order
class _OrderingCleaner extends FakeDowngradeCleaner {
  _OrderingCleaner(this._order);
  final List<String> _order;

  @override
  Future<void> onDowngrade({
    required String fromVsn,
    required String toVsn,
  }) async {
    _order.add('clean');
    await super.onDowngrade(fromVsn: fromVsn, toVsn: toVsn);
  }
}

class _OrderingReporter extends FakeUpgradeReporter {
  _OrderingReporter(this._order);
  final List<String> _order;

  @override
  Future<void> report({
    required String event,
    required String targetVsn,
    Map<String, dynamic>? extra,
  }) async {
    _order.add('report');
    await super.report(event: event, targetVsn: targetVsn, extra: extra);
  }
}
