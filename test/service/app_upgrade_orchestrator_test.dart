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

import '../helpers/fake_storage.dart';
import '../helpers/fake_upgrade_reporter.dart';

void main() {
  group('AppUpgradeOrchestrator.onAppStart', () {
    late FakeStorage storage;
    late FakeUpgradeReporter reporter;
    late AppUpgradeOrchestrator orchestrator;

    setUp(() {
      storage = FakeStorage();
      reporter = FakeUpgradeReporter();
      orchestrator = AppUpgradeOrchestrator(
        tracker: AppVersionTracker(storage: storage),
        reporter: reporter,
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
  });
}
