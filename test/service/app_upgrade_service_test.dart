// APP 升级/降级/回退服务单元测试 / App Upgrade Service Unit Tests
//
// 测试策略 / Test strategy:
//   - AppVersionInfo 纯模型测试（fromJson + getter）
//   - VersionComparator semver 比较逻辑
//   - UpgradeStrategy 纯业务逻辑（changelog 文本构建 + 策略判断）
//   - AppUpgradeService dismiss 状态逻辑（注入 fake StorageService）
//
// 运行方式 / How to run:
//   flutter test test/service/app_upgrade_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/upgrade_strategy.dart';
import 'package:imboy/service/version_comparator.dart';
import 'package:imboy/store/model/app_version_model.dart';

import '../helpers/fake_storage.dart';

// ---------------------------------------------------------------------------
// 辅助函数 / Helper: build AppVersionInfo from partial JSON
// ---------------------------------------------------------------------------
AppVersionInfo _makeInfo({
  String vsn = '2.0.0',
  String upgradeType = 'force',
  bool updatable = true,
  String downloadUrl = 'https://example.com/app.apk',
  String description = '修复若干问题',
  List<Map<String, dynamic>> changelog = const [],
  int fileSize = 0,
  String fileHash = '',
  String minSupportedVsn = '1.0.0',
  int checkIntervalHours = 24,
}) {
  return AppVersionInfo(
    vsn: vsn,
    downloadUrl: downloadUrl,
    description: description,
    upgradeType: upgradeType,
    minSupportedVsn: minSupportedVsn,
    changelog: changelog,
    fileSize: fileSize,
    fileHash: fileHash,
    updatable: updatable,
    checkIntervalHours: checkIntervalHours,
  );
}

// ---------------------------------------------------------------------------
// 测试用例 / Test cases
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // 1. AppVersionInfo 模型测试 / AppVersionInfo model tests
  // =========================================================================
  group('AppVersionInfo — fromJson', () {
    test('解析强制升级 / parses force upgrade', () {
      final info = AppVersionInfo.fromJson({
        'vsn': '2.1.0',
        'download_url': 'https://example.com/v2.1.0.apk',
        'upgrade_type': 'force',
        'updatable': true,
        'description': '重要安全更新',
        'min_supported_vsn': '1.5.0',
        'file_size': 10240000,
        'file_hash': 'abc123',
        'check_interval_hours': 12,
      });

      expect(info.vsn, '2.1.0');
      expect(info.upgradeType, 'force');
      expect(info.updatable, isTrue);
      expect(info.isForceUpgrade, isTrue);
      expect(info.isRecommendUpgrade, isFalse);
      expect(info.isSilentUpgrade, isFalse);
      expect(info.hasUpdate, isTrue);
      expect(info.fileHash, 'abc123');
      expect(info.checkIntervalHours, 12);
    });

    test('解析推荐升级 / parses recommend upgrade', () {
      final info = AppVersionInfo.fromJson({
        'vsn': '2.0.1',
        'download_url': 'https://example.com/v2.0.1.apk',
        'upgrade_type': 'recommend',
        'updatable': true,
      });

      expect(info.isRecommendUpgrade, isTrue);
      expect(info.isForceUpgrade, isFalse);
      expect(info.hasUpdate, isTrue);
    });

    test('解析静默升级 / parses silent upgrade', () {
      final info = AppVersionInfo.fromJson({
        'vsn': '2.0.0',
        'download_url': 'https://example.com/v2.0.0.apk',
        'upgrade_type': 'silent',
        'updatable': true,
      });

      expect(info.isSilentUpgrade, isTrue);
      expect(info.hasUpdate, isTrue);
    });

    test('解析无更新 / parses no update', () {
      final info = AppVersionInfo.fromJson({
        'vsn': '1.0.0',
        'download_url': '',
        'upgrade_type': 'none',
        'updatable': false,
      });

      expect(info.isNoUpgrade, isTrue);
      expect(info.hasUpdate, isFalse);
    });

    test('updatable=false 时 hasUpdate=false / hasUpdate false when updatable=false', () {
      final info = AppVersionInfo.fromJson({
        'vsn': '2.0.0',
        'upgrade_type': 'recommend',
        'updatable': false,
      });

      expect(info.hasUpdate, isFalse);
    });

    test('解析结构化 changelog / parses structured changelog', () {
      final info = AppVersionInfo.fromJson({
        'vsn': '2.0.0',
        'upgrade_type': 'recommend',
        'updatable': true,
        'changelog': [
          {'tag': '新功能', 'text': '支持语音通话'},
          {'tag': '修复', 'text': '修复崩溃问题'},
        ],
      });

      expect(info.changelog, hasLength(2));
      expect(info.changelog[0]['tag'], '新功能');
      expect(info.changelog[1]['text'], '修复崩溃问题');
    });

    test('changelog 非 List 时返回空 / non-List changelog returns empty', () {
      final info = AppVersionInfo.fromJson({
        'vsn': '2.0.0',
        'upgrade_type': 'recommend',
        'updatable': true,
        'changelog': 'not a list',
      });

      expect(info.changelog, isEmpty);
    });
  });

  group('AppVersionInfo — fileSizeText', () {
    test('fileSize=0 返回空串 / zero returns empty', () {
      final info = _makeInfo(fileSize: 0);
      expect(info.fileSizeText, '');
    });

    test('fileSize<1024 返回 B / bytes', () {
      final info = _makeInfo(fileSize: 512);
      expect(info.fileSizeText, '512B');
    });

    test('fileSize 在 KB 范围 / kilobytes', () {
      final info = _makeInfo(fileSize: 2048);
      expect(info.fileSizeText, '2.0KB');
    });

    test('fileSize 在 MB 范围 / megabytes', () {
      final info = _makeInfo(fileSize: 10 * 1024 * 1024);
      expect(info.fileSizeText, '10.0MB');
    });
  });

  // =========================================================================
  // 2. VersionComparator 版本比较测试
  // =========================================================================
  group('VersionComparator', () {
    test('较新版本 compare 返回 1 / newer returns 1', () {
      expect(VersionComparator.compare('2.0.0', '1.0.0'), 1);
    });

    test('较旧版本 compare 返回 -1 / older returns -1', () {
      expect(VersionComparator.compare('1.0.0', '2.0.0'), -1);
    });

    test('相同版本 compare 返回 0 / equal returns 0', () {
      expect(VersionComparator.compare('1.2.3', '1.2.3'), 0);
    });

    test('major 版本优先 / major takes precedence', () {
      expect(VersionComparator.compare('2.0.0', '1.99.99'), 1);
    });

    test('minor 版本比较 / minor comparison', () {
      expect(VersionComparator.compare('1.2.0', '1.1.9'), 1);
      expect(VersionComparator.compare('1.1.0', '1.2.0'), -1);
    });

    test('patch 版本比较 / patch comparison', () {
      expect(VersionComparator.compare('1.0.3', '1.0.2'), 1);
      expect(VersionComparator.compare('1.0.1', '1.0.2'), -1);
    });

    test('isNewer 判断 / isNewer check', () {
      expect(VersionComparator.isNewer('2.0.0', than: '1.9.9'), isTrue);
      expect(VersionComparator.isNewer('1.0.0', than: '2.0.0'), isFalse);
      expect(VersionComparator.isNewer('1.0.0', than: '1.0.0'), isFalse);
    });

    test('isOlder 判断 / isOlder check', () {
      expect(VersionComparator.isOlder('1.0.0', than: '2.0.0'), isTrue);
      expect(VersionComparator.isOlder('2.0.0', than: '1.0.0'), isFalse);
    });

    test('无效版本回退为零分量 / invalid version falls back to zero', () {
      expect(VersionComparator.compare('', '1.0.0'), -1);
      expect(VersionComparator.compare('1.0.0', ''), 1);
      expect(VersionComparator.compare('', ''), 0);
    });

    // pre-release / build metadata 截断行为说明：
    // 本工具只比较 major.minor.patch，pre-release 和 build 标签被截断为与正式版相同。
    // 设计决策：移动端分发中 rc/beta 版本通常作为内测渠道，服务端 vsn 字段始终返回正式版本号，
    // 不需要严格 semver pre-release 顺序。
    //
    // Pre-release / build metadata truncation behaviour (by design):
    // Only major.minor.patch is compared; pre-release and build labels are stripped.
    // Design rationale: in mobile distribution, rc/beta builds are internal-only;
    // the server vsn field always returns a release version string.
    test('pre-release 标签截断后与正式版相等 / pre-release stripped equals release', () {
      expect(VersionComparator.compare('1.0.0-rc.1', '1.0.0'), 0);
      expect(VersionComparator.compare('1.0.0+build.1', '1.0.0'), 0);
      expect(VersionComparator.compare('1.0.0-rc.1+1', '1.0.0'), 0);
    });

    test('pubspec 历史版本回归 / pubspec history regression', () {
      // 项目曾用 1.0.0-rc.1+1，现为 1.0.0+1，语义上等价
      // Project used 1.0.0-rc.1+1, now 1.0.0+1 — semantically equivalent
      expect(VersionComparator.compare('1.0.0-rc.1+1', '1.0.0+1'), 0);
    });
  });

  // =========================================================================
  // 3. UpgradeStrategy 纯业务逻辑测试
  // =========================================================================
  group('UpgradeStrategy.buildChangelogText', () {
    test('有 changelog 时格式化输出 / formats structured changelog', () {
      final info = _makeInfo(
        changelog: [
          {'tag': '新功能', 'text': '支持群作业'},
          {'tag': '修复', 'text': '聊天闪退'},
        ],
        fileSize: 5 * 1024 * 1024,
      );

      final text = UpgradeStrategy.buildChangelogText(info);

      expect(text, contains('[新功能] 支持群作业'));
      expect(text, contains('[修复] 聊天闪退'));
      expect(text, contains('5.0MB'));
    });

    test('changelog 无 tag 时只显示 text / no-tag entry shows only text', () {
      final info = _makeInfo(
        changelog: [
          {'text': '全面优化性能'},
        ],
      );

      final text = UpgradeStrategy.buildChangelogText(info);
      expect(text, contains('全面优化性能'));
      expect(text, isNot(contains('[]')));
    });

    test('没有 changelog 时降级到 description / fallback to description', () {
      final info = _makeInfo(
        changelog: [],
        description: '修复若干问题并优化性能',
      );

      final text = UpgradeStrategy.buildChangelogText(info);
      expect(text, '修复若干问题并优化性能');
    });

    test('fileSize=0 时不显示大小 / no size line when fileSize=0', () {
      final info = _makeInfo(
        changelog: [
          {'tag': '修复', 'text': '修复崩溃'},
        ],
        fileSize: 0,
      );

      final text = UpgradeStrategy.buildChangelogText(info);
      expect(text, isNot(contains('安装包大小')));
    });
  });

  group('UpgradeStrategy.shouldPrompt', () {
    test('force 升级始终提示 / force always prompts', () {
      final info = _makeInfo(upgradeType: 'force', updatable: true);
      expect(UpgradeStrategy.shouldPrompt(info, isDismissed: false, fromManual: false), isTrue);
      expect(UpgradeStrategy.shouldPrompt(info, isDismissed: true, fromManual: false), isTrue);
    });

    test('recommend 未忽略时提示 / recommend prompts when not dismissed', () {
      final info = _makeInfo(upgradeType: 'recommend', updatable: true);
      expect(UpgradeStrategy.shouldPrompt(info, isDismissed: false, fromManual: false), isTrue);
    });

    test('recommend 已忽略时不提示 / recommend suppressed when dismissed', () {
      final info = _makeInfo(upgradeType: 'recommend', updatable: true);
      expect(UpgradeStrategy.shouldPrompt(info, isDismissed: true, fromManual: false), isFalse);
    });

    test('recommend 手动触发时忽略 dismissed 标记 / manual overrides dismissed', () {
      final info = _makeInfo(upgradeType: 'recommend', updatable: true);
      expect(UpgradeStrategy.shouldPrompt(info, isDismissed: true, fromManual: true), isTrue);
    });

    test('silent 始终不提示 / silent never prompts', () {
      final info = _makeInfo(upgradeType: 'silent', updatable: true);
      expect(UpgradeStrategy.shouldPrompt(info, isDismissed: false, fromManual: false), isFalse);
      expect(UpgradeStrategy.shouldPrompt(info, isDismissed: false, fromManual: true), isFalse);
    });

    test('none 不提示 / none does not prompt', () {
      final info = _makeInfo(upgradeType: 'none', updatable: false);
      expect(UpgradeStrategy.shouldPrompt(info, isDismissed: false, fromManual: false), isFalse);
    });

    test('没有更新时不提示 / no prompt when no update', () {
      final info = _makeInfo(upgradeType: 'force', updatable: false);
      expect(UpgradeStrategy.shouldPrompt(info, isDismissed: false, fromManual: false), isFalse);
    });
  });

  // =========================================================================
  // 4. AppUpgradeService dismiss 状态逻辑 / dismiss state logic
  // =========================================================================
  group('AppUpgradeDismissState', () {
    late FakeStorage fakeStorage;
    late AppUpgradeDismissState dismissState;

    setUp(() {
      fakeStorage = FakeStorage();
      dismissState = AppUpgradeDismissState(storage: fakeStorage);
    });

    test('未忽略任何版本时 isDismissed 返回 false / not dismissed by default', () {
      expect(dismissState.isDismissed('2.0.0'), isFalse);
    });

    test('dismiss 某版本后 isDismissed 返回 true / dismissed after setDismissed', () {
      dismissState.setDismissed('2.0.0');
      expect(dismissState.isDismissed('2.0.0'), isTrue);
    });

    test('dismiss 版本 A 不影响版本 B / dismissing A does not affect B', () {
      dismissState.setDismissed('2.0.0');
      expect(dismissState.isDismissed('2.1.0'), isFalse);
    });

    test('dismiss 超过 24 小时后 isDismissed 返回 false / expired after 24h', () {
      // 手动设置一个 25 小时前的时间戳
      // Manually set a timestamp 25 hours ago
      final twentyFiveHoursAgo =
          DateTime.now().subtract(const Duration(hours: 25)).millisecondsSinceEpoch;
      fakeStorage.setString(AppUpgradeDismissState.dismissedVsnKey, '2.0.0');
      fakeStorage.setString(
        AppUpgradeDismissState.lastCheckTimeKey,
        twentyFiveHoursAgo.toString(),
      );

      expect(dismissState.isDismissed('2.0.0'), isFalse);
    });

    test('dismiss 24 小时内 isDismissed 返回 true / within 24h stays dismissed', () {
      final oneHourAgo =
          DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
      fakeStorage.setString(AppUpgradeDismissState.dismissedVsnKey, '2.0.0');
      fakeStorage.setString(
        AppUpgradeDismissState.lastCheckTimeKey,
        oneHourAgo.toString(),
      );

      expect(dismissState.isDismissed('2.0.0'), isTrue);
    });
  });
}
