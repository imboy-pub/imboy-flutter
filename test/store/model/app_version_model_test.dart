/// Tests for `lib/store/model/app_version_model.dart` `AppVersionInfo`.
///
/// 覆盖：
///   - fromJson 默认值兜底（关键字段缺失/类型不对时仍构造可用对象）
///   - changelog: List 元素被 whereType<Map> 过滤；非 List → 空
///   - 4 个 upgradeType boolean 状态：force / recommend / silent / none
///   - hasUpdate = updatable AND !isNoUpgrade
///   - fileSizeText: B (<1024) / KB (<1MB) / MB (>=1MB) / 0 → 空
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/app_version_model.dart';

void main() {
  group('AppVersionInfo.fromJson defaults', () {
    test('空 JSON → 字段都走默认值', () {
      final v = AppVersionInfo.fromJson(<String, dynamic>{});
      expect(v.vsn, '0.0.0');
      expect(v.downloadUrl, '');
      expect(v.description, '');
      expect(v.upgradeType, 'none');
      expect(v.minSupportedVsn, '0.0.0');
      expect(v.changelog, isEmpty);
      expect(v.fileSize, 0);
      expect(v.fileHash, '');
      expect(v.updatable, isFalse);
      expect(v.checkIntervalHours, 24);
      expect(v.forceUpdate, 2);
    });

    test('完整 JSON → 全部字段被映射', () {
      final v = AppVersionInfo.fromJson({
        'vsn': '1.2.3',
        'download_url': 'https://example.com/app.apk',
        'description': '修复一些 bug',
        'upgrade_type': 'recommend',
        'min_supported_vsn': '1.0.0',
        'changelog': [
          {'tag': '新功能', 'text': 'A'},
          {'tag': 'fix', 'text': 'B'},
        ],
        'file_size': 1024 * 1024 * 5, // 5 MB
        'file_hash': 'sha256:abc',
        'updatable': true,
        'check_interval_hours': 12,
        'force_update': 1,
      });
      expect(v.vsn, '1.2.3');
      expect(v.downloadUrl, 'https://example.com/app.apk');
      expect(v.description, '修复一些 bug');
      expect(v.upgradeType, 'recommend');
      expect(v.minSupportedVsn, '1.0.0');
      expect(v.changelog.length, 2);
      expect(v.changelog[0]['tag'], '新功能');
      expect(v.fileSize, 1024 * 1024 * 5);
      expect(v.fileHash, 'sha256:abc');
      expect(v.updatable, isTrue);
      expect(v.checkIntervalHours, 12);
      expect(v.forceUpdate, 1);
    });
  });

  group('AppVersionInfo.fromJson changelog parsing', () {
    test('changelog 非 List → 空列表', () {
      final v = AppVersionInfo.fromJson({'changelog': 'not_a_list'});
      expect(v.changelog, isEmpty);
    });

    test('changelog null → 空列表', () {
      final v = AppVersionInfo.fromJson({'changelog': null});
      expect(v.changelog, isEmpty);
    });

    test('changelog 含混合类型 → 仅 Map 元素被保留', () {
      final v = AppVersionInfo.fromJson({
        'changelog': [
          {'tag': 'a', 'text': 'b'},
          'string_garbage',
          42,
          {'tag': 'c'},
        ],
      });
      expect(v.changelog.length, 2);
      expect(v.changelog[0]['tag'], 'a');
      expect(v.changelog[1]['tag'], 'c');
    });
  });

  group('AppVersionInfo upgradeType getters', () {
    AppVersionInfo make(String type) =>
        AppVersionInfo(vsn: '1', downloadUrl: '', upgradeType: type);

    test('force 类型', () {
      final v = make('force');
      expect(v.isForceUpgrade, isTrue);
      expect(v.isRecommendUpgrade, isFalse);
      expect(v.isSilentUpgrade, isFalse);
      expect(v.isNoUpgrade, isFalse);
    });

    test('recommend 类型', () {
      final v = make('recommend');
      expect(v.isForceUpgrade, isFalse);
      expect(v.isRecommendUpgrade, isTrue);
      expect(v.isSilentUpgrade, isFalse);
      expect(v.isNoUpgrade, isFalse);
    });

    test('silent 类型', () {
      final v = make('silent');
      expect(v.isForceUpgrade, isFalse);
      expect(v.isRecommendUpgrade, isFalse);
      expect(v.isSilentUpgrade, isTrue);
      expect(v.isNoUpgrade, isFalse);
    });

    test('none 类型（默认）', () {
      final v = make('none');
      expect(v.isForceUpgrade, isFalse);
      expect(v.isRecommendUpgrade, isFalse);
      expect(v.isSilentUpgrade, isFalse);
      expect(v.isNoUpgrade, isTrue);
    });

    test('unknown 类型 → 4 个 boolean 全 false', () {
      final v = make('xx_unknown');
      expect(v.isForceUpgrade, isFalse);
      expect(v.isRecommendUpgrade, isFalse);
      expect(v.isSilentUpgrade, isFalse);
      expect(v.isNoUpgrade, isFalse);
    });
  });

  group('AppVersionInfo.hasUpdate', () {
    test('updatable=true + upgradeType!=none → true', () {
      const v = AppVersionInfo(
        vsn: '1',
        downloadUrl: '',
        updatable: true,
        upgradeType: 'recommend',
      );
      expect(v.hasUpdate, isTrue);
    });

    test('updatable=true + upgradeType=none → false（即使有新版本，none 表示客户端不需提示）',
        () {
      const v = AppVersionInfo(
        vsn: '1',
        downloadUrl: '',
        updatable: true,
        // upgradeType 默认 'none'
      );
      expect(v.hasUpdate, isFalse);
    });

    test('updatable=false → false（无论 upgradeType）', () {
      const v = AppVersionInfo(
        vsn: '1',
        downloadUrl: '',
        // updatable 默认 false
        upgradeType: 'force',
      );
      expect(v.hasUpdate, isFalse);
    });

    test('updatable=true + force 类型 → true', () {
      const v = AppVersionInfo(
        vsn: '1',
        downloadUrl: '',
        updatable: true,
        upgradeType: 'force',
      );
      expect(v.hasUpdate, isTrue);
    });
  });

  group('AppVersionInfo.fileSizeText', () {
    AppVersionInfo make(int size) =>
        AppVersionInfo(vsn: '1', downloadUrl: '', fileSize: size);

    test('size <= 0 → 空字符串', () {
      expect(make(0).fileSizeText, '');
      expect(make(-100).fileSizeText, '');
    });

    test(r'size < 1024 → "${size}B"', () {
      expect(make(1).fileSizeText, '1B');
      expect(make(512).fileSizeText, '512B');
      expect(make(1023).fileSizeText, '1023B');
    });

    test('1024 <= size < 1MB → KB 显示，1 位小数', () {
      expect(make(1024).fileSizeText, '1.0KB');
      expect(make(1536).fileSizeText, '1.5KB');
      expect(make(1024 * 1024 - 1).fileSizeText, '1024.0KB');
    });

    test('size >= 1MB → MB 显示，1 位小数', () {
      expect(make(1024 * 1024).fileSizeText, '1.0MB');
      expect(make(1024 * 1024 * 5).fileSizeText, '5.0MB');
      expect(make((1024 * 1024 * 1.5).toInt()).fileSizeText, '1.5MB');
    });
  });
}
