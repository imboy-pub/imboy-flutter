/// R20-A：NtpHelper last-good / 缓存防护 / stale 宽限 / 失败语义测试。
///
/// 不触网：NtpHelper.ntpQuery 注入点替换为 fake；存储用
/// SharedPreferences mock。覆盖：
/// - R20-2：缓存的 offset 量级异常 / device_ts 在未来 / 过期 / 坏 JSON；
/// - last-good：NTP 失败保留既有偏移，不静默归零；
/// - stale：宽限期（24h）内 offset 叠加、过期后退化为纯墙钟；
/// - R20-3：getOffset 全部失败不抛异常（启动路径可安全不 await 的前提）。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/ntp.dart';
import 'package:imboy/component/helper/ntp_query.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

NtpSample _sample(int offsetMs, {int rttMs = 40}) =>
    NtpSample(offsetMs: offsetMs, rttMs: rttMs);

/// 构造 NTP 全失败的注入。
Never _failingQuery(String host, {Duration? timeout}) =>
    throw Exception('offline in test');

void _writeRawCache(String key, Map<String, dynamic> data) {
  StorageService.to.setString(key, json.encode(data));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cacheKey = 'ntp_offset_v2';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    NtpHelper.debugReset();
    NtpHelper.ntpQuery = _failingQuery;
  });

  tearDown(() {
    NtpHelper.ntpQuery = queryNtp;
  });

  int wallNow() => DateTime.now().millisecondsSinceEpoch;

  group('R20-2 缓存防护', () {
    test('正常缓存：直接采用，不触网', () async {
      _writeRawCache(cacheKey, {
        'offset': 1500,
        'device_ts': wallNow(),
        'ntp_time': '2026-10-26T00:00:00Z',
      });
      // ntpQuery 为全失败 fake：若走到 NTP 分支会拿到 0 而非 1500。
      final offset = await NtpHelper.getOffset();
      expect(offset, 1500);
    });

    test('缓存的 offset 超过 ±24h：丢弃并清除', () async {
      _writeRawCache(cacheKey, {
        'offset': 25 * 3600 * 1000,
        'device_ts': wallNow(),
      });
      final offset = await NtpHelper.getOffset();
      expect(offset, 0);
      expect(StorageService.to.getString(cacheKey), isEmpty);
    });

    test('缓存的 device_ts 在未来（墙钟回拨污染）：丢弃并清除', () async {
      _writeRawCache(cacheKey, {
        'offset': 800,
        'device_ts': wallNow() + 3600 * 1000,
      });
      final offset = await NtpHelper.getOffset();
      expect(offset, 0);
      expect(StorageService.to.getString(cacheKey), isEmpty);
    });

    test('缓存的 device_ts 轻微在未来（≤60s 容差）：仍可用', () async {
      _writeRawCache(cacheKey, {
        'offset': 900,
        'device_ts': wallNow() + 30 * 1000,
      });
      expect(await NtpHelper.getOffset(), 900);
    });

    test('过期缓存（7 小时前）：不采用，转 NTP', () async {
      _writeRawCache(cacheKey, {
        'offset': 1500,
        'device_ts': wallNow() - 7 * 3600 * 1000,
      });
      NtpHelper.ntpQuery = (_, {timeout = const Duration(seconds: 3)}) async =>
          _sample(-450);
      expect(await NtpHelper.getOffset(), -450);
      // 成功同步覆盖了旧缓存。
      final raw = StorageService.to.getString(cacheKey);
      expect(raw, isNotNull);
      expect(raw, contains('-450'));
    });

    test('坏 JSON：清除后走 NTP', () async {
      await StorageService.to.setString(cacheKey, '{not-json');
      NtpHelper.ntpQuery = (_, {timeout = const Duration(seconds: 3)}) async =>
          _sample(222);
      expect(await NtpHelper.getOffset(), 222);
      expect(StorageService.to.getString(cacheKey), contains('222'));
    });

    test('double 数字（历史写入形态）：num 容错读取', () async {
      _writeRawCache(cacheKey, {
        'offset': 1200.0,
        'device_ts': wallNow() * 1.0,
      });
      expect(await NtpHelper.getOffset(), 1200);
    });
  });

  group('last-good 失败语义', () {
    test('R20-3 无缓存且 NTP 全失败：返回 0（纯墙钟），不抛异常', () async {
      final offset = await NtpHelper.getOffset();
      expect(offset, 0);
    });

    test('NTP 失败保留 last-good（不静默归零）', () async {
      final serverTs = wallNow() + 1200;
      NtpHelper.updateOffsetFromServer(serverTs);
      expect(NtpHelper.offset, greaterThan(1100));

      // 缓存为空 + NTP 全失败 → 仍返回 last-good。
      final offset = await NtpHelper.getOffset();
      expect(offset, greaterThan(1100));
      expect(offset, lessThan(1300));
    });

    test('NTP 成功后 offset 更新并持久化缓存', () async {
      NtpHelper.ntpQuery = (_, {timeout = const Duration(seconds: 3)}) async =>
          _sample(-450, rttMs: 12);
      final offset = await NtpHelper.getOffset();
      expect(offset, -450);
      expect(StorageService.to.getString(cacheKey), contains('-450'));
    });
  });

  group('stale 宽限与 now() 退化', () {
    test('校准后 millisecond() 叠加 offset', () {
      final before = wallNow();
      NtpHelper.updateOffsetFromServer(before + 1500);
      final synced = NtpHelper.millisecond();
      expect(synced - wallNow(), greaterThan(1400));
      expect(synced - wallNow(), lessThan(1600));
    });

    test('宽限期内（23h）offset 仍生效', () {
      NtpHelper.updateOffsetFromServer(wallNow() + 1500);
      NtpHelper.debugAgeLastSync(const Duration(hours: 23));
      expect(NtpHelper.offsetUsable, isTrue);
      expect(NtpHelper.millisecond() - wallNow(), greaterThan(1400));
    });

    test('过期（25h）后退化为纯墙钟，不假装已校准', () {
      NtpHelper.updateOffsetFromServer(wallNow() + 1500);
      NtpHelper.debugAgeLastSync(const Duration(hours: 25));
      expect(NtpHelper.offsetUsable, isFalse);
      // now() 不再叠加旧 offset。
      expect((NtpHelper.millisecond() - wallNow()).abs(), lessThan(1000));
    });

    test('sv_ts 每次成功响应刷新宽限（重新计时）', () {
      NtpHelper.updateOffsetFromServer(wallNow() + 1500);
      NtpHelper.debugAgeLastSync(const Duration(hours: 25));
      expect(NtpHelper.offsetUsable, isFalse);
      // 一次成功 HTTP 响应（sv_ts）到达 → 恢复。
      NtpHelper.updateOffsetFromServer(wallNow() + 1500);
      expect(NtpHelper.offsetUsable, isTrue);
    });

    test('sv_ts 量级异常（>24h）不更新 offset', () {
      NtpHelper.updateOffsetFromServer(wallNow() + 1200);
      final before = NtpHelper.offset;
      NtpHelper.updateOffsetFromServer(wallNow() + 30 * 3600 * 1000);
      expect(NtpHelper.offset, before);
      NtpHelper.updateOffsetFromServer(0);
      NtpHelper.updateOffsetFromServer(-5);
      expect(NtpHelper.offset, before);
    });
  });
}
