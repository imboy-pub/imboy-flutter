// APP 版本跟踪与回退检测单元测试 / App Version Tracker & Rollback Detection Tests
//
// 测试策略 / Test strategy:
//   - 首次启动：无 lastRun 记录 → firstLaunch
//   - 版本相同：unchanged
//   - 新版本 > 旧版本：upgraded
//   - 新版本 < 旧版本：downgraded (触发回退逻辑)
//   - 所有逻辑为纯函数，注入 FakeStorage，无平台依赖
//
// 运行方式 / How to run:
//   flutter test test/service/app_version_tracker_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/app_version_tracker.dart';

import '../helpers/fake_storage.dart';

// ---------------------------------------------------------------------------
// 测试用例
// ---------------------------------------------------------------------------

void main() {
  late FakeStorage fakeStorage;
  late AppVersionTracker tracker;

  setUp(() {
    fakeStorage = FakeStorage();
    tracker = AppVersionTracker(storage: fakeStorage);
  });

  // =========================================================================
  // 1. VersionTransition 枚举
  // =========================================================================
  group('VersionTransition values', () {
    test('枚举包含所有期望的转换类型 / enum has all expected transitions', () {
      // 确保枚举值存在（编译时保障）
      expect(VersionTransition.firstLaunch, isNotNull);
      expect(VersionTransition.upgraded, isNotNull);
      expect(VersionTransition.downgraded, isNotNull);
      expect(VersionTransition.unchanged, isNotNull);
    });
  });

  // =========================================================================
  // 2. AppVersionTracker.detect
  // =========================================================================
  group('AppVersionTracker.detect', () {
    test('无历史记录时返回 firstLaunch / no history returns firstLaunch', () {
      final result = tracker.detect(currentVsn: '1.0.0');
      expect(result.transition, VersionTransition.firstLaunch);
      expect(result.previousVsn, '');
      expect(result.currentVsn, '1.0.0');
    });

    test('版本相同返回 unchanged / same version returns unchanged', () {
      fakeStorage.setString(AppVersionTracker.lastRunVsnKey, '1.0.0');
      final result = tracker.detect(currentVsn: '1.0.0');
      expect(result.transition, VersionTransition.unchanged);
    });

    test('版本升高返回 upgraded / higher version returns upgraded', () {
      fakeStorage.setString(AppVersionTracker.lastRunVsnKey, '1.0.0');
      final result = tracker.detect(currentVsn: '2.0.0');
      expect(result.transition, VersionTransition.upgraded);
      expect(result.previousVsn, '1.0.0');
      expect(result.currentVsn, '2.0.0');
    });

    test('patch 升高也是 upgraded / patch bump is upgraded', () {
      fakeStorage.setString(AppVersionTracker.lastRunVsnKey, '1.0.1');
      final result = tracker.detect(currentVsn: '1.0.2');
      expect(result.transition, VersionTransition.upgraded);
    });

    test('版本降低返回 downgraded / lower version returns downgraded', () {
      fakeStorage.setString(AppVersionTracker.lastRunVsnKey, '2.0.0');
      final result = tracker.detect(currentVsn: '1.5.0');
      expect(result.transition, VersionTransition.downgraded);
      expect(result.previousVsn, '2.0.0');
      expect(result.currentVsn, '1.5.0');
    });

    test('patch 降低也是 downgraded / patch rollback is downgraded', () {
      fakeStorage.setString(AppVersionTracker.lastRunVsnKey, '1.0.3');
      final result = tracker.detect(currentVsn: '1.0.2');
      expect(result.transition, VersionTransition.downgraded);
    });
  });

  // =========================================================================
  // 3. AppVersionTracker.commit — 持久化当前版本
  // =========================================================================
  group('AppVersionTracker.commit', () {
    test('commit 后 lastRunVsn 更新为当前版本 / commit persists currentVsn', () {
      tracker.commit(vsn: '2.1.0');
      expect(
        fakeStorage.getString(AppVersionTracker.lastRunVsnKey),
        '2.1.0',
      );
    });

    test('连续两次 commit 保存最新版本 / successive commits update to latest', () {
      tracker.commit(vsn: '1.0.0');
      tracker.commit(vsn: '2.0.0');
      expect(
        fakeStorage.getString(AppVersionTracker.lastRunVsnKey),
        '2.0.0',
      );
    });
  });

  // =========================================================================
  // 4. VersionTransitionResult 辅助 getter
  // =========================================================================
  group('VersionTransitionResult helpers', () {
    test('isUpgrade / isDowngrade / isFirstLaunch / isUnchanged 标志正确', () {
      fakeStorage.setString(AppVersionTracker.lastRunVsnKey, '2.0.0');
      final downResult = tracker.detect(currentVsn: '1.0.0');
      expect(downResult.isDowngrade, isTrue);
      expect(downResult.isUpgrade, isFalse);

      fakeStorage.clear();
      final firstResult = tracker.detect(currentVsn: '1.0.0');
      expect(firstResult.isFirstLaunch, isTrue);
      expect(firstResult.isUnchanged, isFalse);

      fakeStorage.setString(AppVersionTracker.lastRunVsnKey, '1.0.0');
      final sameResult = tracker.detect(currentVsn: '1.0.0');
      expect(sameResult.isUnchanged, isTrue);

      fakeStorage.setString(AppVersionTracker.lastRunVsnKey, '1.0.0');
      final upResult = tracker.detect(currentVsn: '2.0.0');
      expect(upResult.isUpgrade, isTrue);
    });
  });

  // =========================================================================
  // 5. detectAndCommit — detect + commit 原子操作
  // =========================================================================
  group('AppVersionTracker.detectAndCommit', () {
    test('detectAndCommit 返回正确结果并持久化版本', () {
      fakeStorage.setString(AppVersionTracker.lastRunVsnKey, '1.0.0');
      final result = tracker.detectAndCommit(currentVsn: '2.0.0');

      expect(result.transition, VersionTransition.upgraded);
      // 提交后存储已更新
      expect(
        fakeStorage.getString(AppVersionTracker.lastRunVsnKey),
        '2.0.0',
      );
    });

    test('firstLaunch 时 detectAndCommit 也持久化版本', () {
      final result = tracker.detectAndCommit(currentVsn: '1.0.0');
      expect(result.transition, VersionTransition.firstLaunch);
      expect(
        fakeStorage.getString(AppVersionTracker.lastRunVsnKey),
        '1.0.0',
      );
    });
  });
}
