// 升级功能边界测试集
// Upgrade feature edge-case tests
//
// 覆盖真实世界输入下的容错：
//   - 定时器 intervalHours <= 0 必须不启动（防死循环）
//   - VersionComparator 处理 "1.0" 两段、空串、v 前缀、超长段
//   - AppVersionInfo.fromJson 字段缺失/类型错误不崩溃
//
// Covers robustness for real-world inputs:
//   - intervalHours <= 0 MUST NOT start a timer (prevents tight loop)
//   - VersionComparator handles "1.0" two-segment, empty, v-prefix, huge seg
//   - AppVersionInfo.fromJson tolerates missing / malformed fields
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/upgrade_timer_policy.dart';
import 'package:imboy/service/version_comparator.dart';
import 'package:imboy/store/model/app_version_model.dart';

void main() {
  group('UpgradeTimerPolicy.computeInterval', () {
    test(
      'intervalHours=0 返回 null（不启动定时器，防死循环）/ '
      'returns null to disable timer (prevents tight loop)',
      () {
        expect(UpgradeTimerPolicy.computeInterval(0), isNull);
      },
    );

    test(
      'intervalHours<0 返回 null / negative returns null',
      () {
        expect(UpgradeTimerPolicy.computeInterval(-1), isNull);
        expect(UpgradeTimerPolicy.computeInterval(-24), isNull);
      },
    );

    test(
      'intervalHours=1 返回 1 小时 / 1 returns Duration(hours: 1)',
      () {
        expect(
          UpgradeTimerPolicy.computeInterval(1),
          const Duration(hours: 1),
        );
      },
    );

    test(
      'intervalHours=24（默认）返回 24 小时 / default 24 returns 24 h',
      () {
        expect(
          UpgradeTimerPolicy.computeInterval(24),
          const Duration(hours: 24),
        );
      },
    );

    test(
      'intervalHours=168（1 周）返回 168 小时 / 168 returns one week',
      () {
        expect(
          UpgradeTimerPolicy.computeInterval(168),
          const Duration(hours: 168),
        );
      },
    );
  });

  group('VersionComparator 边界 / edge cases', () {
    test(
      '"1.0" 两段式补齐为 1.0.0 / two-segment pads to 1.0.0',
      () {
        expect(VersionComparator.compare('1.0', '1.0.0'), 0);
        expect(VersionComparator.compare('1.0', '1.0.1'), -1);
        expect(VersionComparator.compare('2.0', '1.9.9'), 1);
      },
    );

    test(
      '"1" 单段式补齐为 1.0.0 / single-segment pads to 1.0.0',
      () {
        expect(VersionComparator.compare('1', '1.0.0'), 0);
        expect(VersionComparator.compare('2', '1.9.9'), 1);
      },
    );

    test(
      '空字符串视为 0.0.0 / empty treated as 0.0.0',
      () {
        expect(VersionComparator.compare('', '0.0.0'), 0);
        expect(VersionComparator.compare('', '0.0.1'), -1);
        expect(VersionComparator.compare('1.0.0', ''), 1);
      },
    );

    test(
      '带 "v" 前缀不识别为数字，视为 0 / "v" prefix parses as 0',
      () {
        // 当前实现：int.tryParse("v1") 返回 null → 回退为 0
        // Current behavior: "v1.0.0" is parsed as [0, 0, 0]
        // 这是契约而非 bug —— 服务端应返回纯数字版本
        // Contract, not a bug — server must send pure numeric versions
        expect(VersionComparator.compare('v1.0.0', '0.0.0'), 0);
        expect(VersionComparator.compare('v1.0.0', '1.0.0'), -1);
      },
    );

    test(
      '超长段数字仍可比较 / large segment numbers compare correctly',
      () {
        expect(
          VersionComparator.compare('999999.0.0', '999998.9.9'),
          1,
        );
        expect(
          VersionComparator.compare('1.0.9999', '1.0.10000'),
          -1,
        );
      },
    );

    test(
      '四段式只比较前三段 / four-segment compares only first three',
      () {
        // "1.0.0.1" → parts = ["1","0","0","1"] → 取前 3
        expect(VersionComparator.compare('1.0.0.1', '1.0.0.9'), 0);
        expect(VersionComparator.compare('1.0.0.9', '1.0.1'), -1);
      },
    );

    test(
      'pre-release 仍被截断 / pre-release still stripped',
      () {
        // 已在原测试覆盖，这里保险断言契约未变
        expect(VersionComparator.compare('1.0.0-rc.1', '1.0.0'), 0);
        expect(VersionComparator.compare('1.0.0-alpha', '0.9.9'), 1);
      },
    );

    test(
      'build metadata 被截断 / build metadata stripped',
      () {
        expect(VersionComparator.compare('1.0.0+build.42', '1.0.0'), 0);
      },
    );
  });

  group('AppVersionInfo.fromJson 容错 / fault tolerance', () {
    test(
      '空 JSON 返回默认值不崩溃 / empty JSON returns defaults without crash',
      () {
        final info = AppVersionInfo.fromJson(<String, dynamic>{});
        expect(info.vsn, '0.0.0');
        expect(info.downloadUrl, '');
        expect(info.description, '');
        expect(info.upgradeType, 'none');
        expect(info.minSupportedVsn, '0.0.0');
        expect(info.changelog, isEmpty);
        expect(info.fileSize, 0);
        expect(info.fileHash, '');
        expect(info.updatable, isFalse);
        expect(info.checkIntervalHours, 24);
        expect(info.forceUpdate, 2);
        expect(info.hasUpdate, isFalse);
      },
    );

    test(
      'null 字段不崩溃 / null fields do not crash',
      () {
        final info = AppVersionInfo.fromJson(<String, dynamic>{
          'vsn': null,
          'download_url': null,
          'description': null,
          'upgrade_type': null,
          'changelog': null,
          'file_size': null,
          'updatable': null,
        });
        expect(info.vsn, '0.0.0');
        expect(info.downloadUrl, '');
        expect(info.upgradeType, 'none');
        expect(info.changelog, isEmpty);
        expect(info.fileSize, 0);
        expect(info.updatable, isFalse);
      },
    );

    test(
      'changelog 是字符串时回退为空列表 / string changelog falls back to empty',
      () {
        // 服务端错误地用 JSON 字符串（应该是 List）
        // Server mistakenly sends JSON string (should be List)
        final info = AppVersionInfo.fromJson(<String, dynamic>{
          'vsn': '1.0.0',
          'changelog': '[{"tag":"feat","text":"x"}]',
        });
        expect(info.changelog, isEmpty);
      },
    );

    test(
      'changelog List 内含非 Map 元素被过滤 / non-Map items filtered out',
      () {
        final info = AppVersionInfo.fromJson(<String, dynamic>{
          'vsn': '1.0.0',
          'changelog': [
            {'tag': 'feat', 'text': 'ok'},
            'invalid string',
            42,
            null,
            {'tag': 'fix', 'text': 'bugs'},
          ],
        });
        expect(info.changelog, hasLength(2));
        expect(info.changelog[0]['tag'], 'feat');
        expect(info.changelog[1]['tag'], 'fix');
      },
    );

    test(
      'hasUpdate 要求 updatable=true 且 upgradeType!="none" / '
      'hasUpdate requires updatable=true AND type!=none',
      () {
        final a = AppVersionInfo.fromJson({
          'updatable': true,
          'upgrade_type': 'none',
        });
        expect(a.hasUpdate, isFalse, reason: 'none 类型不算更新');

        final b = AppVersionInfo.fromJson({
          'updatable': false,
          'upgrade_type': 'recommend',
        });
        expect(b.hasUpdate, isFalse, reason: 'updatable=false 不算更新');

        final c = AppVersionInfo.fromJson({
          'updatable': true,
          'upgrade_type': 'recommend',
        });
        expect(c.hasUpdate, isTrue);
      },
    );

    test(
      'fileSize 为负数时 fileSizeText 返回空 / negative fileSize returns empty text',
      () {
        final info = AppVersionInfo.fromJson({'file_size': -1024});
        // parseModelInt 对负数的处理：保留原值（不会回退为默认）
        // 但 fileSizeText 的契约是 <=0 返回空
        expect(info.fileSizeText, isEmpty);
      },
    );

    test(
      'fileSize 边界 1023 / 1024 / 1024*1024 / boundary sizes',
      () {
        expect(
          AppVersionInfo.fromJson({'file_size': 1023}).fileSizeText,
          '1023B',
        );
        expect(
          AppVersionInfo.fromJson({'file_size': 1024}).fileSizeText,
          '1.0KB',
        );
        expect(
          AppVersionInfo.fromJson({'file_size': 1024 * 1024}).fileSizeText,
          '1.0MB',
        );
      },
    );
  });
}
